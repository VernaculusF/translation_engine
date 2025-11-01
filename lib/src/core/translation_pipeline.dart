/// Translation Pipeline - конвейер обработки слоев перевода
/// 
/// Управляет последовательным выполнением слоев перевода,
/// состоянием pipeline и обработкой ошибок.
library;

import 'dart:async';

import '../data/dictionary_repository.dart';
import '../data/phrase_repository.dart';
import '../data/user_data_repository.dart';
import '../utils/cache_manager.dart';
import '../models/translation_result.dart';
import '../models/layer_debug_info.dart';
import 'translation_context.dart';
import 'layer_adapters.dart';
import '../data/grammar_rules_repository.dart';
import '../data/word_order_rules_repository.dart';
import '../data/post_processing_rules_repository.dart';
import '../utils/debug_logger.dart';
import '../utils/tracing.dart';
import '../utils/metrics.dart';
import '../utils/layer_health_monitor.dart';
import 'layer_type.dart';

/// Состояния pipeline обработки
enum PipelineState {
  /// Ожидает обработки
  idle,
  
  /// Обрабатывает текст
  processing,
  
  /// Ошибка в обработке
  error,
  
  /// Обработка завершена
  completed,
}

/// Абстрактный интерфейс слоя обработки
abstract class TranslationLayer {
  /// Тип слоя
  LayerType get layerType;
  
  /// Название слоя
  String get name;
  
  /// Приоритет слоя (меньше = выше)
  int get priority;
  
  /// Активен ли слой
  bool get isEnabled;
  
  /// Обработать текст
  /// 
  /// [text] - текст для обработки
  /// [context] - контекст перевода
  /// 
  /// Возвращает обработанный текст и debug информацию
  Future<({String processedText, LayerDebugInfo debugInfo})> process(
    String text,
    TranslationContext context,
  );
  
  /// Проверить, может ли слой обработать данный текст
  bool canProcess(String text, TranslationContext context);
}

/// Translation Pipeline - конвейер обработки слоев
/// 
/// Управляет последовательным выполнением слоев обработки текста.
/// Обеспечивает мониторинг состояния и обработку ошибок.
class TranslationPipeline {
  // Data repositories for layer implementations (Stage 3)
  final DictionaryRepository dictionaryRepository;
  final PhraseRepository phraseRepository;
  final UserDataRepository userDataRepository;
  final CacheManager cacheManager;
  
  // Optional repositories for rule-based layers
  final GrammarRulesRepository? grammarRulesRepository;
  final WordOrderRulesRepository? wordOrderRulesRepository;
  final PostProcessingRulesRepository? postProcessingRulesRepository;
  
  // Pipeline state
  PipelineState _state = PipelineState.idle;
  final StreamController<PipelineState> _stateController = StreamController<PipelineState>.broadcast();
  
  // Registered layers
  final List<TranslationLayer> _layers = [];
  
  // Statistics (Note: repositories used in Stage 3 for layer implementations)
  int _processedTexts = 0;
  Duration _totalProcessingTime = Duration.zero;
  final Map<LayerType, Duration> _layerProcessingTimes = {};
  final Map<LayerType, int> _layerExecutions = {};
  
  // Error handling
  Exception? _lastError;
  
  // Health monitoring for graceful degradation
  LayerHealthMonitor? _healthMonitor;
  
  TranslationPipeline({
    required this.dictionaryRepository,
    required this.phraseRepository,
    required this.userDataRepository,
    required this.cacheManager,
    this.grammarRulesRepository,
    this.wordOrderRulesRepository,
    this.postProcessingRulesRepository,
    bool registerDefaultLayers = false,
  }) {
    if (registerDefaultLayers) {
      _initializeDefaultLayers();
    }
  }
  
  /// Текущее состояние pipeline
  PipelineState get state => _state;
  
  /// Stream состояний pipeline
  Stream<PipelineState> get stateStream => _stateController.stream;
  
  /// Последняя ошибка
  Exception? get lastError => _lastError;
  
  /// Количество зарегистрированных слоев
  int get layersCount => _layers.length;
  
  /// Список зарегистрированных слоев
  List<TranslationLayer> get layers => List.unmodifiable(_layers);
  
  /// Проверить доступность репозиториев для слоев
  bool get hasDataAccess {
    try {
      return dictionaryRepository.storage.rootExists &&
             phraseRepository.storage.rootExists &&
             userDataRepository.storage.rootExists;
    } catch (_) {
      return false;
    }
  }
  
  /// Статистика pipeline
  Map<String, dynamic> get statistics {
    final stats = {
      'processed_texts': _processedTexts,
      'total_processing_time_ms': _totalProcessingTime.inMilliseconds,
      'average_processing_time_ms': _processedTexts > 0
          ? _totalProcessingTime.inMilliseconds / _processedTexts
          : 0,
      'layers_count': _layers.length,
      'data_access_available': hasDataAccess,
      'repositories': {
        'dictionary_ready': true, // Required in constructor
        'phrase_ready': true, // Required in constructor
        'user_data_ready': true, // Required in constructor
        'cache_ready': true, // Required in constructor
      },
      'layer_statistics': _layerProcessingTimes.map(
        (type, time) => MapEntry(
          type.toString(),
          {
            'executions': _layerExecutions[type] ?? 0,
            'total_time_ms': time.inMilliseconds,
            'average_time_ms': (_layerExecutions[type] ?? 0) > 0
                ? time.inMilliseconds / _layerExecutions[type]!
                : 0,
          },
        ),
      ),
    };
    
    // Добавляем информацию о здоровье слоёв, если монитор включён
    if (_healthMonitor != null) {
      stats['health'] = _healthMonitor!.getHealthReport();
    }
    
    return stats;
  }
  
  /// Обработать текст через pipeline
  /// 
  /// [text] - исходный текст
  /// [context] - контекст перевода
  /// 
  /// Возвращает [TranslationResult] с результатом перевода
  Future<TranslationResult> process(
    String text,
    TranslationContext context,
  ) async {
    if (_state == PipelineState.processing) {
      throw StateError('Pipeline is already processing');
    }
    
    final stopwatch = Stopwatch()..start();
    final List<LayerDebugInfo> layerResults = [];
    String currentText = text;
    final traceId = context.getMetadata<String>('trace_id') ?? newTraceId();
    final trace = TraceContext(traceId);
    
    try {
      _setState(PipelineState.processing);
      
      // Обработка слоев по приоритету, проверяя возможность на каждом шаге
      var layersToRun = List<TranslationLayer>.from(_layers);

      // Применение degrade-профиля (если задан)
      final degradeAllowed = context.getMetadata<List>('degrade_allowed');
      if (degradeAllowed is List && degradeAllowed.isNotEmpty) {
        final allowedSet = degradeAllowed.map((e) => e.toString()).toSet();
        final before = layersToRun.length;
        layersToRun = layersToRun
            .where((l) => allowedSet.contains(l.layerType.name))
            .toList();
        DebugLogger.instance.info('pipeline.degrade', fields: {
          'trace_id': trace.traceId,
          'allowed_layers': allowedSet.toList(),
          'filtered': before - layersToRun.length,
        });
      }

      bool anyLayerProcessed = false;

      for (final layer in layersToRun) {
        if (!layer.isEnabled) {
          continue;
        }
        
        // Проверка circuit breaker: отключен ли слой из-за ошибок
        if (_healthMonitor != null && !_healthMonitor!.isLayerAvailable(layer.layerType)) {
          DebugLogger.instance.warning('layer.circuit_open', fields: {
            'trace_id': traceId,
            'layer': layer.layerType.name,
          });
          layerResults.add(LayerDebugInfo(
            layerName: layer.name,
            wasModified: false,
            itemsProcessed: 0,
            cacheHits: 0,
            processingTimeMs: 0,
            errorMessage: 'Layer circuit breaker is OPEN',
          ));
          continue;
        }
        
        // Проверяем возможность обработки на текущем шаге с учетом уже добавленных метаданных
        if (!layer.canProcess(currentText, context)) {
          continue;
        }
        
        anyLayerProcessed = true;
        final layerStopwatch = Stopwatch()..start();
        
        try {
          final span = Span(trace, 'layer.${layer.layerType.name}.${layer.name}');
          DebugLogger.instance.debug('layer.start', fields: {
            'trace_id': traceId,
            'span_id': span.spanId,
            'layer': layer.layerType.name,
            'name': layer.name,
          });
          final result = await layer.process(currentText, context);
          currentText = result.processedText;
          // Обновляем контекст, чтобы последующие слои видели актуальный текст
          context.translatedText = currentText;
          
          layerStopwatch.stop();
          final dur = span.end();
          layerResults.add(result.debugInfo);
          
          // Обновление статистики слоя
          _updateLayerStatistics(layer.layerType, layerStopwatch.elapsed);
          MetricsRegistry.instance.timer('layer.${layer.layerType.name}').observe(dur);
          DebugLogger.instance.debug('layer.end', fields: {
            'trace_id': traceId,
            'layer': layer.layerType.name,
            'name': layer.name,
            'processing_time_ms': layerStopwatch.elapsedMilliseconds,
            'modified': result.debugInfo.wasModified,
          });
          
          // Записываем успешную обработку в health monitor
          _healthMonitor?.recordSuccess(layer.layerType);
          
        } catch (e) {
          layerStopwatch.stop();
          
          // Добавляем ошибку слоя
          layerResults.add(LayerDebugInfo.error(
            layerName: layer.name,
            errorMessage: e.toString(),
            processingTimeMs: layerStopwatch.elapsedMilliseconds,
          ));
          DebugLogger.instance.warning('layer.error', fields: {
            'trace_id': traceId,
            'layer': layer.layerType.name,
            'name': layer.name,
            'error': e.toString(),
          });
          
          // Записываем ошибку в health monitor
          _healthMonitor?.recordError(layer.layerType, e);
          
          // Продолжаем обработку следующими слоями
        }
      }
      
      stopwatch.stop();
      _updateStatistics(stopwatch.elapsed, _layerProcessingTimes);
      
      // Если ни один слой не обработал текст, вернуть исходный
      if (!anyLayerProcessed) {
        final res = TranslationResult.success(
          originalText: text,
          translatedText: text,
          languagePair: context.languagePair,
          confidence: 0.5,
          processingTimeMs: stopwatch.elapsedMilliseconds,
          layerResults: layerResults,
        );
        _setState(PipelineState.completed);
        _setState(PipelineState.idle);
        return res;
      }
      
      // Вычисляем confidence на основе результатов слоев
      final confidence = _calculateConfidence(layerResults);
      
      final res = TranslationResult.success(
        originalText: text,
        translatedText: currentText,
        languagePair: context.languagePair,
        confidence: confidence,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        layerResults: layerResults,
      );
      DebugLogger.instance.info('pipeline.end', fields: {
        'trace_id': traceId,
        'processing_time_ms': stopwatch.elapsedMilliseconds,
      });
      _setState(PipelineState.completed);
      _setState(PipelineState.idle);
      return res;
      
    } catch (e) {
      stopwatch.stop();
      _lastError = e is Exception ? e : Exception('Pipeline processing failed: $e');
      _setState(PipelineState.error);
      DebugLogger.instance.error('pipeline.error', error: e, fields: {
        'trace_id': traceId,
        'processing_time_ms': stopwatch.elapsedMilliseconds,
      });
      
      final res = TranslationResult.error(
        originalText: text,
        errorMessage: _lastError!.toString(),
        languagePair: context.languagePair,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        layerResults: layerResults,
      );
      _setState(PipelineState.error);
      _setState(PipelineState.idle);
      return res;
    }
  }
  
  /// Зарегистрировать новый слой
  void registerLayer(TranslationLayer layer) {
    // Проверяем, нет ли уже слоя такого типа
    _layers.removeWhere((l) => l.layerType == layer.layerType);
    
    _layers.add(layer);
    _sortLayers();
  }
  
  /// Удалить слой по типу
  void unregisterLayer(LayerType layerType) {
    _layers.removeWhere((layer) => layer.layerType == layerType);
  }
  
  /// Очистить все слои
  void clearLayers() {
    _layers.clear();
  }
  
  /// Включить мониторинг здоровья слоёв (graceful degradation)
  void enableHealthMonitoring({
    double errorThreshold = 0.5,
    int minRequests = 10,
    int resetTimeoutSeconds = 60,
    int successThreshold = 3,
    int windowSeconds = 300,
  }) {
    _healthMonitor = LayerHealthMonitor(
      errorThreshold: errorThreshold,
      minRequests: minRequests,
      resetTimeoutSeconds: resetTimeoutSeconds,
      successThreshold: successThreshold,
      windowSeconds: windowSeconds,
    );
    
    DebugLogger.instance.info('pipeline.health_monitor_enabled', fields: {
      'error_threshold': errorThreshold,
      'min_requests': minRequests,
      'reset_timeout_seconds': resetTimeoutSeconds,
    });
  }
  
  /// Отключить мониторинг здоровья слоёв
  void disableHealthMonitoring() {
    _healthMonitor?.dispose();
    _healthMonitor = null;
    DebugLogger.instance.info('pipeline.health_monitor_disabled');
  }
  
  /// Получить health monitor (для расширенного управления)
  LayerHealthMonitor? get healthMonitor => _healthMonitor;
  
  /// Принудительно восстановить слой (закрыть circuit breaker)
  void forceRestoreLayer(LayerType layerType) {
    _healthMonitor?.forceCloseCircuit(layerType);
  }
  
  /// Освободить ресурсы
  Future<void> dispose() async {
    _healthMonitor?.dispose();
    await _stateController.close();
    _layers.clear();
  }
  
  /// Инициализация базовых слоев (пока пустая реализация)
  void _initializeDefaultLayers() {
    // Register adapters for all base layers in correct order, logging any failures
    final errors = <String>[];

    void safeRegister(String name, void Function() action) {
      try {
        action();
      } catch (e) {
        errors.add('$name: $e');
        DebugLogger.instance.warning('pipeline.layer_init_failed', fields: {
          'layer': name,
          'error': e.toString(),
        });
      }
    }

    safeRegister('preProcessing', () => registerLayer(LayerAdaptersFactory.preProcessing()));
    safeRegister('phraseLookup', () => registerLayer(LayerAdaptersFactory.phraseLookup(repo: phraseRepository)));
    safeRegister('dictionary', () => registerLayer(LayerAdaptersFactory.dictionary(repo: dictionaryRepository)));
    safeRegister('grammar', () => registerLayer(LayerAdaptersFactory.grammar(repo: grammarRulesRepository)));
    safeRegister('wordOrder', () => registerLayer(LayerAdaptersFactory.wordOrder(repo: wordOrderRulesRepository)));
    safeRegister('postProcessing', () => registerLayer(LayerAdaptersFactory.postProcessing(repo: postProcessingRulesRepository)));

    if (_layers.isEmpty) {
      // If no layers registered at all, this is a hard error
      final message = 'No default layers registered. Errors: ${errors.join('; ')}';
      DebugLogger.instance.error('pipeline.init_failed', error: message);
      throw StateError(message);
    }
  }
  
  /// Упорядочить слои по приоритету
  void _sortLayers() {
    _layers.sort((a, b) => a.priority.compareTo(b.priority));
  }
  
  /// Установить новое состояние
  void _setState(PipelineState newState) {
    if (_state != newState) {
      _state = newState;
      if (!_stateController.isClosed) {
        _stateController.add(_state);
      }
    }
  }
  
  /// Обновить общую статистику
  void _updateStatistics(
    Duration totalTime,
    Map<LayerType, Duration> layerTimes,
  ) {
    _processedTexts++;
    _totalProcessingTime += totalTime;
  }
  
  /// Обновить статистику слоя
  void _updateLayerStatistics(LayerType layerType, Duration processingTime) {
    _layerProcessingTimes[layerType] = 
        (_layerProcessingTimes[layerType] ?? Duration.zero) + processingTime;
    _layerExecutions[layerType] = (_layerExecutions[layerType] ?? 0) + 1;
  }
  
  /// Вычислить confidence на основе результатов слоев
  double _calculateConfidence(List<LayerDebugInfo> layerResults) {
    if (layerResults.isEmpty) {
      return 0.0;
    }

    final totalLayers = layerResults.length;
    final successfulLayers = layerResults.where((i) => !i.hasError).length;
    final modifiedLayers = layerResults.where((i) => i.wasModified && !i.hasError).length;

    final successRate = totalLayers > 0 ? successfulLayers / totalLayers : 0.0;
    final modifiedRate = totalLayers > 0 ? modifiedLayers / totalLayers : 0.0;

    // Средний уровень изменений на элемент (защита от деления на ноль)
    double modImpact = 0.0;
    int counted = 0;
    for (final info in layerResults) {
      final items = info.itemsProcessed;
      if (items > 0) {
        modImpact += (info.modificationsCount / items).clamp(0.0, 1.0);
        counted++;
      }
    }
    if (counted > 0) modImpact /= counted;

    // Учитываем кэш-хиты
    final totalCacheHits = layerResults.fold(0, (sum, i) => sum + i.cacheHits);
    final totalItemsProcessed = layerResults.fold(0, (sum, i) => sum + i.itemsProcessed);
    final cacheHitRate = totalItemsProcessed > 0 ? totalCacheHits / totalItemsProcessed : 0.0;

    // Взвешенная формула: успешность 40%, модификации 40%, плотность изменений 20%, бонус за кэш 10%
    double c = 0.4 * successRate + 0.4 * modifiedRate + 0.2 * modImpact + 0.1 * cacheHitRate;
    return c.clamp(0.0, 1.0);
  }
}