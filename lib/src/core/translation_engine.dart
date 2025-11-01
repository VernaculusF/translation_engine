/// Translation Engine - главный класс системы перевода
/// 
/// Основной публичный API для работы с движком перевода.
/// Управляет lifecycle системы и интегрируется с Data Layer.
library;

import 'dart:async';
import 'dart:io';

import '../core/engine_config.dart';
import '../data/dictionary_repository.dart';
import '../data/phrase_repository.dart';
import '../data/user_data_repository.dart';
import '../utils/cache_manager.dart';
import '../utils/memory_manager.dart';
import '../models/translation_result.dart';
import 'translation_pipeline.dart';
import 'translation_context.dart';
import '../data/grammar_rules_repository.dart';
import '../data/word_order_rules_repository.dart';
import '../data/post_processing_rules_repository.dart';
import '../utils/debug_logger.dart';
import '../utils/metrics.dart';
import '../utils/rate_limiter.dart';
import '../utils/tracing.dart';
import 'layer_type.dart';
import 'package:path/path.dart' as p;

/// Состояния жизненного цикла TranslationEngine
enum EngineState {
  /// Не инициализирован
  uninitialized,
  
  /// В процессе инициализации
  initializing,
  
  /// Готов к работе
  ready,
  
  /// В процессе перевода
  processing,
  
  /// Ошибка в работе
  error,
  
  /// Освобождение ресурсов
  disposing,
  
  /// Освобожден
  disposed,
}

/// Translation Engine - главный класс системы перевода
/// 
/// Предоставляет высокоуровневый API для выполнения переводов,
/// управляет инициализацией и освобождением ресурсов системы.
/// 
/// Пример использования:
/// ```dart
/// final engine = TranslationEngine();
/// await engine.initialize();
/// 
/// final result = await engine.translate(
///   'Hello world',
///   sourceLanguage: 'en',
///   targetLanguage: 'ru',
/// );
/// 
/// await engine.dispose();
/// ```
class TranslationEngine {
  static TranslationEngine? _instance;
  
  // Core components
  late CacheManager _cacheManager;
  MemoryManager? _memoryManager; // опционально
  late DictionaryRepository _dictionaryRepository;
  late PhraseRepository _phraseRepository;
  late UserDataRepository _userDataRepository;
  late GrammarRulesRepository _grammarRulesRepository;
  late WordOrderRulesRepository _wordOrderRulesRepository;
  late PostProcessingRulesRepository _postProcessingRulesRepository;
  late TranslationPipeline _pipeline;

  // Путь к данным JSONL
  late String _dataPath;
  
  // State management
  EngineState _state = EngineState.uninitialized;
  final StreamController<EngineState> _stateController = StreamController<EngineState>.broadcast();
  
  // Error handling
  Exception? _lastError;
  final StreamController<Exception> _errorController = StreamController<Exception>.broadcast();
  
  // Statistics
  int _translationsCount = 0;
  DateTime? _lastTranslationTime;
  Duration _totalProcessingTime = Duration.zero;

  // Serialization chain for translate calls
  late Future<void> _serializeChain;

  // Rate limiting / queueing
  SimpleRateLimiter? _rateLimiter;
  int _pendingRequests = 0;
  int _maxPendingRequests = 0; // 0 = unlimited
  Duration? _requestTimeout; // null = no timeout

  // Degrade mode
  bool _degradeEnabled = false;
  List<String> _degradeAllowedLayers = const []; // e.g., ['phraseLookup','dictionary']

  // Config

  TranslationEngine._() : _serializeChain = Future.value();
  
  /// Получить singleton instance TranslationEngine
  factory TranslationEngine() {
    return _instance ??= TranslationEngine._();
  }
  
  /// Получить singleton instance с возможностью сброса для тестов (синхронный вариант)
  factory TranslationEngine.instance({bool reset = false}) {
    if (reset) {
      // Внимание: синхронное освобождение ресурсов не гарантируется.
      // Используйте TranslationEngine.create(reset: true) для корректного await-диспоза.
      _instance?._dispose();
      _instance = null;
    }
    return TranslationEngine();
  }

  /// Рекомендуемый способ создать/получить instance с корректным await-диспозом при reset
  static Future<TranslationEngine> create({bool reset = false}) async {
    if (reset && _instance != null) {
      await _instance!._dispose();
      _instance = null;
    }
    return TranslationEngine();
  }
  
  /// Текущее состояние движка
  EngineState get state => _state;
  
  /// Stream изменений состояния движка
  Stream<EngineState> get stateStream => _stateController.stream;
  
  /// Последняя ошибка (если была)
  Exception? get lastError => _lastError;
  
  /// Stream ошибок движка
  Stream<Exception> get errorStream => _errorController.stream;
  
  /// Готов ли движок к работе
  bool get isReady => _state == EngineState.ready;
  
  /// Инициализирован ли движок
  bool get isInitialized => _state != EngineState.uninitialized && _state != EngineState.disposed;
  
  /// Статистика переводов
  Map<String, dynamic> get statistics => {
    'translations_count': _translationsCount,
    'last_translation_time': _lastTranslationTime?.toIso8601String(),
    'total_processing_time_ms': _totalProcessingTime.inMilliseconds,
    'average_processing_time_ms': _translationsCount > 0 
        ? _totalProcessingTime.inMilliseconds / _translationsCount 
        : 0,
    'state': _state.toString(),
  };
  
  /// Инициализация движка перевода
  /// 
  /// [customDatabasePath] - опциональный путь к каталогу данных (JSONL). Совместимость с прежним именем параметра.
  /// [config] - конфигурация движка
  /// 
  /// Бросает [EngineInitializationException] при ошибке инициализации
  Future<void> initialize({
    String? customDatabasePath,
    Map<String, dynamic>? config,
  }) async {
    if (_state == EngineState.initializing) {
      throw const EngineInitializationException('Engine is already being initialized');
    }
    
    if (_state == EngineState.ready) {
      return; // Уже инициализирован
    }
    
    try {
      _setState(EngineState.initializing);
      
      // Инициализация Data Layer компонентов (файловое хранилище)
      _dataPath = await _prepareDataPath(customDatabasePath);
      _cacheManager = CacheManager();
      
      // Инициализация MemoryManager (опционально)
      final memoryCfg = config?['memory'] as Map<String, dynamic>?;
      final memoryEnabled = (memoryCfg?['enabled'] as bool?) ?? true; // по умолчанию включено
      if (memoryEnabled) {
        final maxMemoryMb = (memoryCfg?['max_memory_mb'] as int?) ?? 256;
        final maxPairs = (memoryCfg?['max_language_pairs'] as int?) ?? 50;
        final evictionThreshold = (memoryCfg?['eviction_threshold'] as double?) ?? 0.8;
        _memoryManager = MemoryManager(
          maxMemoryBytes: maxMemoryMb * 1024 * 1024,
          maxLanguagePairs: maxPairs,
          evictionThreshold: evictionThreshold,
        );
      }

      // Инициализация репозиториев (файловые JSONL)
      _dictionaryRepository = DictionaryRepository(
        dataDirPath: _dataPath,
        cacheManager: _cacheManager,
        memoryManager: _memoryManager,
      );
      _phraseRepository = PhraseRepository(
        dataDirPath: _dataPath,
        cacheManager: _cacheManager,
        memoryManager: _memoryManager,
      );
      _userDataRepository = UserDataRepository(
        dataDirPath: _dataPath,
        cacheManager: _cacheManager,
      );

      // Инициализация репозиториев правил
      _grammarRulesRepository = GrammarRulesRepository(
        dataDirPath: _dataPath,
        cacheManager: _cacheManager,
      );
      _wordOrderRulesRepository = WordOrderRulesRepository(
        dataDirPath: _dataPath,
        cacheManager: _cacheManager,
      );
      _postProcessingRulesRepository = PostProcessingRulesRepository(
        dataDirPath: _dataPath,
        cacheManager: _cacheManager,
      );
      
      // Инициализация pipeline
      _pipeline = TranslationPipeline(
        dictionaryRepository: _dictionaryRepository,
        phraseRepository: _phraseRepository,
        userDataRepository: _userDataRepository,
        cacheManager: _cacheManager,
        grammarRulesRepository: _grammarRulesRepository,
        wordOrderRulesRepository: _wordOrderRulesRepository,
        postProcessingRulesRepository: _postProcessingRulesRepository,
        registerDefaultLayers: true,
      );
      
      // Применение конфигурации
      if (config != null) {
        await _applyConfig(config);
      }
      
      _setState(EngineState.ready);
      
    } catch (e) {
      _lastError = e is Exception ? e : Exception('Initialization failed: $e');
      _setState(EngineState.error);
      _errorController.add(_lastError!);
      rethrow;
    }
  }
  
  /// Выполнить перевод текста
  /// 
  /// [text] - текст для перевода
  /// [sourceLanguage] - исходный язык (например, 'en')
  /// [targetLanguage] - целевой язык (например, 'ru')
  /// [context] - дополнительный контекст перевода
  /// 
  /// Возвращает [TranslationResult] с результатом перевода
  /// Бросает [EngineStateException] если движок не готов к работе
  Future<TranslationResult> translate(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
    TranslationContext? context,
  }) async {
    _pendingRequests++;
    final traceId = newTraceId();
    DebugLogger.instance.info('translate.start', fields: {
      'trace_id': traceId,
      'lang_pair': '$sourceLanguage-$targetLanguage',
      'queued': _pendingRequests - 1,
    });

    // Queue limit check (drop policy)
    if (_maxPendingRequests > 0 && _pendingRequests > _maxPendingRequests) {
      DebugLogger.instance.warning('queue.drop', fields: {
        'trace_id': traceId,
        'pending': _pendingRequests,
        'max_pending': _maxPendingRequests,
      });
      _pendingRequests--;
      return TranslationResult.error(
        originalText: text,
        errorMessage: 'Queue is full (max $_maxPendingRequests pending) — request dropped',
        languagePair: '$sourceLanguage-$targetLanguage',
        processingTimeMs: 0,
      );
    }

    try {
      final future = _runSerialized(() async {
        // Rate limiting
        if (_rateLimiter != null) {
          final wait = _rateLimiter!.untilNextAllowed();
          if (wait > Duration.zero) {
            DebugLogger.instance.debug('rate_limit.wait', fields: {
              'trace_id': traceId,
              'wait_ms': wait.inMilliseconds,
            });
          }
          await _rateLimiter!.waitTurn();
        }

        // Валидация состояния
        if (!isReady) {
          throw EngineStateException('Engine is not ready. Current state: $_state');
        }
        
        // Валидация входных данных
        if (text.isEmpty) {
          return TranslationResult.error(
            originalText: text,
            errorMessage: 'Empty text provided',
            languagePair: '$sourceLanguage-$targetLanguage',
            processingTimeMs: 0,
          );
        }
        
        final stopwatch = Stopwatch()..start();
        _setState(EngineState.processing);
        try {
          // Создание контекста перевода если не предоставлен
          final translationContext = context ?? TranslationContext(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
          );
          // propagate trace id
          translationContext.setMetadata('trace_id', traceId);
          // propagate degrade profile
          if (_degradeEnabled && _degradeAllowedLayers.isNotEmpty) {
            translationContext.setMetadata('degrade_allowed', List<String>.from(_degradeAllowedLayers));
          }
          
          // Выполнение перевода через pipeline
          final result = await _pipeline.process(text, translationContext);
          
          // Обновление статистики
          stopwatch.stop();
          _updateStatistics(stopwatch.elapsed);
          MetricsRegistry.instance.timer('engine.translate').observe(stopwatch.elapsed);
          
          DebugLogger.instance.info('translate.end', fields: {
            'trace_id': traceId,
            'processing_time_ms': stopwatch.elapsedMilliseconds,
            'lang_pair': translationContext.languagePair,
          });
          
          return result;
          
        } catch (e, st) {
          stopwatch.stop();
          _lastError = e is Exception ? e : Exception('Translation failed: $e');
          // Не удерживаем движок в состоянии error; публикуем событие ошибки и возвращаем результат.
          if (!_errorController.isClosed) {
            _errorController.add(_lastError!);
          }
          MetricsRegistry.instance.counter('engine.errors').inc();
          DebugLogger.instance.error('translate.error', error: e, stackTrace: st, fields: {
            'trace_id': traceId,
            'processing_time_ms': stopwatch.elapsedMilliseconds,
            'lang_pair': '$sourceLanguage-$targetLanguage',
          });
          
          return TranslationResult.error(
            originalText: text,
            errorMessage: _lastError!.toString(),
            languagePair: '$sourceLanguage-$targetLanguage',
            processingTimeMs: stopwatch.elapsedMilliseconds,
          );
        } finally {
          // Всегда возвращаемся в готовое состояние, если движок не в процессе dispose.
          if (_state != EngineState.disposed && _state != EngineState.disposing) {
            _setState(EngineState.ready);
          }
        }
      });
      if (_requestTimeout != null && _requestTimeout! > Duration.zero) {
        return await future.timeout(_requestTimeout!, onTimeout: () {
          DebugLogger.instance.error('translate.timeout', fields: {
            'trace_id': traceId,
            'timeout_ms': _requestTimeout!.inMilliseconds,
            'lang_pair': '$sourceLanguage-$targetLanguage',
          });
          return TranslationResult.error(
            originalText: text,
            errorMessage: 'Translation timed out after ${_requestTimeout!.inMilliseconds} ms',
            languagePair: '$sourceLanguage-$targetLanguage',
            processingTimeMs: _requestTimeout!.inMilliseconds,
          );
        });
      }
      return await future;
    } finally {
      _pendingRequests--;
    }
  }
  
  /// Получить информацию о состоянии кэша
  Map<String, dynamic> getCacheInfo() {
    if (!isInitialized) {
      return {'error': 'Engine not initialized'};
    }
    final metrics = _cacheManager.metrics;
    metrics['estimated_memory_mb'] =
        ((_cacheManager.estimatedMemoryUsage) / (1024 * 1024)).toStringAsFixed(2);
    return metrics;
  }
  
  /// Очистить кэш
  /// 
  /// [type] - тип кэша для очистки ('words', 'phrases', 'all')
  Future<void> clearCache({String type = 'all'}) async {
    if (!isInitialized) {
      throw const EngineStateException('Engine not initialized');
    }
    
    switch (type.toLowerCase()) {
      case 'words':
        _cacheManager.clearWords();
        break;
      case 'phrases':
        _cacheManager.clearPhrases();
        break;
      case 'all':
      default:
        _cacheManager.clear();
        break;
    }
  }

  // Простая сериализация вызовов translate, чтобы исключить параллельную обработку
  Future<T> _runSerialized<T>(Future<T> Function() action) async {
    final prev = _serializeChain;
    final done = Completer<void>();
    _serializeChain = prev.then((_) => done.future);
    try {
      await prev;
      return await action();
    } finally {
      if (!done.isCompleted) done.complete();
    }
  }
  
  /// Освобождение ресурсов движка
  Future<void> dispose() async {
    if (_state == EngineState.disposed || _state == EngineState.disposing) {
      return;
    }
    
    await _dispose();
  }
  
  /// Сброс состояния ошибок и возврат в готовое состояние (без переинициализации)
  void reset() {
    if (_state == EngineState.disposed || _state == EngineState.disposing) {
      throw const EngineStateException('Cannot reset disposed engine');
    }
    _lastError = null;
    if (_state != EngineState.ready) {
      _setState(EngineState.ready);
    }
  }
  
  /// Внутренний метод освобождения ресурсов
  Future<void> _dispose() async {
    _setState(EngineState.disposing);
    
    try {
      // Очистка MemoryManager
      _memoryManager?.dispose();
      
      // Закрытие stream controllers
      await _stateController.close();
      await _errorController.close();
      
      _setState(EngineState.disposed);
      
    } catch (e) {
      _lastError = e is Exception ? e : Exception('Disposal failed: $e');
      _setState(EngineState.error);
    }
  }
  
  /// Установить новое состояние движка
  void _setState(EngineState newState) {
    if (_state != newState) {
      _state = newState;
      if (!_stateController.isClosed) {
        _stateController.add(_state);
      }
    }
  }
  
  /// Подготовить путь к данным: корректно соединить путь, создать директорию при необходимости
  Future<String> _prepareDataPath(String? customDatabasePath) async {
    try {
      final base = customDatabasePath?.trim().isNotEmpty == true
          ? customDatabasePath!.trim()
          : p.join(Directory.current.path, 'translation_data');
      final dir = Directory(base);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      // Проба записи/чтения (best-effort)
      final probe = File(p.join(base, '.write_probe'));
      await probe.writeAsString('ok', mode: FileMode.write, flush: true);
      await probe.delete();
      return base;
    } catch (e) {
      throw EngineInitializationException('Failed to prepare data directory: $e');
    }
  }

  /// Применить конфигурацию
  Future<void> _applyConfig(Map<String, dynamic> config) async {
    // Cache
    if (config.containsKey('cache')) {
      final cacheConfig = Map<String, dynamic>.from(config['cache'] as Map);
      final wordsLimit = cacheConfig['words_limit'] as int?;
      final phrasesLimit = cacheConfig['phrases_limit'] as int?;
      final ttlSeconds = cacheConfig['ttl_seconds'] as int?;
      _cacheManager.configure(
        wordsLimit: wordsLimit,
        phrasesLimit: phrasesLimit,
        genericLimit: (wordsLimit ?? 10000) + (phrasesLimit ?? 5000),
        ttlMs: ttlSeconds != null ? ttlSeconds * 1000 : null,
      );
    }
    
    // Debugging / logging
    final debugEnabled = (config['debug'] as bool?) ?? false;
    DebugLogger.instance.setEnabled(debugEnabled);
    final levelStr = (config['log_level'] as String?) ?? LogLevel.warning.toString();
    final levelName = levelStr.contains('.') ? levelStr.split('.').last : levelStr;
    final level = LogLevel.values.firstWhere(
      (l) => l.name.toLowerCase() == levelName.toLowerCase(),
      orElse: () => LogLevel.warning,
    );
    DebugLogger.instance.setLevel(level);
    DebugLogger.instance.setStructured(true);
    
    // Rate limiting / queue / timeouts
    final security = (config['security'] as Map<String, dynamic>?) ?? const {};
    final rateEnabled = (security['rate_limiting'] as bool?) ?? false;
    final maxPerMinute = (security['max_requests_per_minute'] as int?) ?? 0;
    _rateLimiter = rateEnabled && maxPerMinute > 0 ? SimpleRateLimiter(maxPerMinute) : null;

    final queueCfg = (config['queue'] as Map<String, dynamic>?) ?? const {};
    _maxPendingRequests = (queueCfg['max_pending'] as int?) ?? _maxPendingRequests;

    final timeouts = (config['timeouts'] as Map<String, dynamic>?) ?? const {};
    final translateMs = (timeouts['translate_ms'] as int?) ?? (config['maxProcessingTime'] as int?);
    _requestTimeout = translateMs != null && translateMs > 0 ? Duration(milliseconds: translateMs) : null;

    // Degrade mode
    final degrade = (config['degrade'] as Map<String, dynamic>?) ?? const {};
    _degradeEnabled = (degrade['enabled'] as bool?) ?? false;
    final allowed = degrade['allowed_layers'];
    if (allowed is List) {
      _degradeAllowedLayers = allowed.map((e) => e.toString()).toList();
    }
    
    // Health monitoring (circuit breaker для graceful degradation)
    final healthCfg = (config['health_monitoring'] as Map<String, dynamic>?) ?? const {};
    final healthEnabled = (healthCfg['enabled'] as bool?) ?? false;
    if (healthEnabled) {
      _pipeline.enableHealthMonitoring(
        errorThreshold: (healthCfg['error_threshold'] as double?) ?? 0.5,
        minRequests: (healthCfg['min_requests'] as int?) ?? 10,
        resetTimeoutSeconds: (healthCfg['reset_timeout_seconds'] as int?) ?? 60,
        successThreshold: (healthCfg['success_threshold'] as int?) ?? 3,
        windowSeconds: (healthCfg['window_seconds'] as int?) ?? 300,
      );
    }
  }
  
  /// Обновить статистику переводов
  void _updateStatistics(Duration processingTime) {
    _translationsCount++;
    _lastTranslationTime = DateTime.now();
    _totalProcessingTime += processingTime;
  }
  
  /// Метрики и состояние (расширенный снимок)
  Map<String, dynamic> getMetrics() {
    final metrics = {
      'engine': statistics,
      'pipeline': _pipeline.statistics,
      'cache': getCacheInfo(),
      'queue': {
        'pending': _pendingRequests,
        'max_pending': _maxPendingRequests,
      },
      'timeouts': {
        'translate_ms': _requestTimeout?.inMilliseconds ?? 0,
      },
      'logging': {
        'enabled': DebugLogger.instance.enabled,
        'level': DebugLogger.instance.level.name,
        'structured': DebugLogger.instance.structured,
      },
      'metrics': MetricsRegistry.instance.snapshot(),
    };
    
    // Добавить метрики памяти если MemoryManager включен
    if (_memoryManager != null) {
      metrics['memory'] = _memoryManager!.getMemoryReport();
    }
    
    return metrics;
  }
  
  /// Получить отчёт о здоровье слоёв (graceful degradation)
  Map<String, dynamic>? getLayerHealth() {
    return _pipeline.healthMonitor?.getHealthReport();
  }
  
  /// Принудительно восстановить слой после circuit breaker
  void forceRestoreLayer(String layerTypeName) {
    final layerType = LayerType.values.firstWhere(
      (t) => t.name == layerTypeName,
      orElse: () => throw ArgumentError('Unknown layer type: $layerTypeName'),
    );
    _pipeline.forceRestoreLayer(layerType);
  }
}

/// Исключение инициализации движка
class EngineInitializationException implements Exception {
  final String message;
  
  const EngineInitializationException(this.message);
  
  @override
  String toString() => 'EngineInitializationException: $message';
}

/// Исключение состояния движка
class EngineStateException implements Exception {
  final String message;
  
  const EngineStateException(this.message);
  
  @override
  String toString() => 'EngineStateException: $message';
}
