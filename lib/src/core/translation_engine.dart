/// Translation Engine - главный класс системы перевода
/// 
/// Основной публичный API для работы с движком перевода.
/// Управляет lifecycle системы и интегрируется с Data Layer.
library;

import 'dart:async';
import 'dart:io';

import '../data/dictionary_repository.dart';
import '../data/phrase_repository.dart';
import '../data/user_data_repository.dart';
import '../utils/cache_manager.dart';
import '../models/translation_result.dart';
import 'translation_pipeline.dart';
import 'translation_context.dart';
import '../data/grammar_rules_repository.dart';
import '../data/word_order_rules_repository.dart';
import '../data/post_processing_rules_repository.dart';

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
  
  TranslationEngine._();
  
  /// Получить singleton instance TranslationEngine
  factory TranslationEngine() {
    return _instance ??= TranslationEngine._();
  }
  
  /// Получить singleton instance с возможностью сброса для тестов
  factory TranslationEngine.instance({bool reset = false}) {
    if (reset) {
      _instance?._dispose();
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
_dataPath = customDatabasePath ?? '${Directory.current.uri.toFilePath()}translation_data';
      _cacheManager = CacheManager();

      // Инициализация репозиториев (файловые JSONL)
      _dictionaryRepository = DictionaryRepository(
        dataDirPath: _dataPath,
        cacheManager: _cacheManager,
      );
      _phraseRepository = PhraseRepository(
        dataDirPath: _dataPath,
        cacheManager: _cacheManager,
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
    
    try {
      _setState(EngineState.processing);
      
      // Создание контекста перевода если не предоставлен
      final translationContext = context ?? TranslationContext(
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
      
      // Выполнение перевода через pipeline
      final result = await _pipeline.process(text, translationContext);
      
      // Обновление статистики
      stopwatch.stop();
      _updateStatistics(stopwatch.elapsed);
      
      // Сохранение в историю переводов (пока отключено)
      // await _userDataRepository.addTranslationHistory(result);
      
      _setState(EngineState.ready);
      
      return result;
      
    } catch (e) {
      stopwatch.stop();
      _lastError = e is Exception ? e : Exception('Translation failed: $e');
      _setState(EngineState.error);
      _errorController.add(_lastError!);
      
      // Возвращаем результат с ошибкой
      return TranslationResult.error(
        originalText: text,
        errorMessage: _lastError!.toString(),
        languagePair: '$sourceLanguage-$targetLanguage',
        processingTimeMs: stopwatch.elapsedMilliseconds,
      );
    }
  }
  
  /// Получить информацию о состоянии кэша
  Map<String, dynamic> getCacheInfo() {
    if (!isInitialized) {
      return {'error': 'Engine not initialized'};
    }
    
    return {
      'words_cache': 'Available', // _cacheManager.getWordsMetrics(),
      'phrases_cache': 'Available', // _cacheManager.getPhrasesMetrics(),
      'overall_metrics': 'Available', // _cacheManager.getOverallMetrics(),
      'memory_estimate_mb': 0.0, // _cacheManager.estimateMemoryUsage() / (1024 * 1024),
    };
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
  
  /// Освобождение ресурсов движка
  Future<void> dispose() async {
    if (_state == EngineState.disposed || _state == EngineState.disposing) {
      return;
    }
    
    await _dispose();
  }
  
  /// Внутренний метод освобождения ресурсов
  Future<void> _dispose() async {
    _setState(EngineState.disposing);
    
    try {
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
  
  /// Применить конфигурацию
  Future<void> _applyConfig(Map<String, dynamic> config) async {
    // Применение настроек кэша
    if (config.containsKey('cache')) {
      final cacheConfig = config['cache'] as Map<String, dynamic>;
      
      if (cacheConfig.containsKey('words_limit')) {
        // Применение лимитов кэша (пока что сохраняем как есть)
      }
      
      if (cacheConfig.containsKey('phrases_limit')) {
        // Применение лимитов кэша
      }
    }
    
    // Применение настроек debugging
    if (config.containsKey('debug') && config['debug'] == true) {
      // Включение debug режима
    }
  }
  
  /// Обновить статистику переводов
  void _updateStatistics(Duration processingTime) {
    _translationsCount++;
    _lastTranslationTime = DateTime.now();
    _totalProcessingTime += processingTime;
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
