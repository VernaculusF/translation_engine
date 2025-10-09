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

/// Типы слоев в pipeline
enum LayerType {
  preProcessing,
  phraseLookup,
  dictionary,
  grammar,
  wordOrder,
  postProcessing,
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
  
  TranslationPipeline({
    required this.dictionaryRepository,
    required this.phraseRepository,
    required this.userDataRepository,
    required this.cacheManager,
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
  bool get hasDataAccess => true; // All repositories are required in constructor
  
  /// Статистика pipeline
  Map<String, dynamic> get statistics => {
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
    
    try {
      _setState(PipelineState.processing);
      
      // Обработка слоев по приоритету, проверяя возможность на каждом шаге
      final layersToRun = List<TranslationLayer>.from(_layers);
      bool anyLayerProcessed = false;

      for (final layer in layersToRun) {
        if (!layer.isEnabled) {
          continue;
        }
        
        // Проверяем возможность обработки на текущем шаге с учетом уже добавленных метаданных
        if (!layer.canProcess(currentText, context)) {
          continue;
        }
        
        anyLayerProcessed = true;
        final layerStopwatch = Stopwatch()..start();
        
        try {
          final result = await layer.process(currentText, context);
          currentText = result.processedText;
          
          layerStopwatch.stop();
          layerResults.add(result.debugInfo);
          
          // Обновление статистики слоя
          _updateLayerStatistics(layer.layerType, layerStopwatch.elapsed);
          
        } catch (e) {
          layerStopwatch.stop();
          
          // Добавляем ошибку слоя
          layerResults.add(LayerDebugInfo.error(
            layerName: layer.name,
            errorMessage: e.toString(),
            processingTimeMs: layerStopwatch.elapsedMilliseconds,
          ));
          
          // Продолжаем обработку следующими слоями
        }
      }
      
      stopwatch.stop();
      _updateStatistics(stopwatch.elapsed, _layerProcessingTimes);
      
      _setState(PipelineState.completed);
      
      // Если ни один слой не обработал текст, вернуть исходный
      if (!anyLayerProcessed) {
        return TranslationResult.success(
          originalText: text,
          translatedText: text,
          languagePair: context.languagePair,
          confidence: 0.5,
          processingTimeMs: stopwatch.elapsedMilliseconds,
          layerResults: layerResults,
        );
      }
      
      // Вычисляем confidence на основе результатов слоев
      final confidence = _calculateConfidence(layerResults);
      
      return TranslationResult.success(
        originalText: text,
        translatedText: currentText,
        languagePair: context.languagePair,
        confidence: confidence,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        layerResults: layerResults,
      );
      
    } catch (e) {
      stopwatch.stop();
      _lastError = e is Exception ? e : Exception('Pipeline processing failed: $e');
      _setState(PipelineState.error);
      
      return TranslationResult.error(
        originalText: text,
        errorMessage: _lastError!.toString(),
        languagePair: context.languagePair,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        layerResults: layerResults,
      );
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
  
  /// Освободить ресурсы
  Future<void> dispose() async {
    await _stateController.close();
    _layers.clear();
  }
  
  /// Инициализация базовых слоев (пока пустая реализация)
  void _initializeDefaultLayers() {
    // Register adapters for all base layers in correct order
    try {
      // Pre-processing
      registerLayer(LayerAdaptersFactory.preProcessing());

      // Phrase lookup depends on PhraseRepository
      registerLayer(LayerAdaptersFactory.phraseLookup(repo: phraseRepository));

      // Dictionary lookup depends on DictionaryRepository
      registerLayer(LayerAdaptersFactory.dictionary(repo: dictionaryRepository));

      // Grammar, Word order, Post-processing
      registerLayer(LayerAdaptersFactory.grammar());
      registerLayer(LayerAdaptersFactory.wordOrder());
      registerLayer(LayerAdaptersFactory.postProcessing());
    } catch (_) {
      // In case of any initialization issues, leave pipeline without default layers
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
    
    // Простой алгоритм: среднее от всех слоев
    final successfulLayers = layerResults.where((info) => !info.hasError).length;
    final totalLayers = layerResults.length;
    
    if (totalLayers == 0) return 0.0;
    
    final baseConfidence = successfulLayers / totalLayers;
    
    // Корректировка на основе cache hits
    final totalCacheHits = layerResults
        .fold(0, (sum, info) => sum + info.cacheHits);
    final totalItemsProcessed = layerResults
        .fold(0, (sum, info) => sum + info.itemsProcessed);
    
    final cacheHitRate = totalItemsProcessed > 0 
        ? totalCacheHits / totalItemsProcessed 
        : 0.0;
    
    // Увеличиваем confidence при высоком cache hit rate
    final adjustedConfidence = baseConfidence + (cacheHitRate * 0.2);
    
    return adjustedConfidence.clamp(0.0, 1.0);
  }
}