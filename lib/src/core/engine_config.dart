/// Engine Configuration - система конфигурации движка перевода
/// 
/// Система настроек для performance tuning, debugging, cache limits 
/// и feature flags Translation Engine.
library;

/// Уровни логирования
enum LogLevel {
  none,
  error,
  warning,
  info,
  debug,
  verbose,
}

/// Стратегии кэширования
enum CacheStrategy {
  /// Агрессивное кэширование (максимальные лимиты)
  aggressive,
  
  /// Консервативное кэширование (умеренные лимиты)
  conservative,
  
  /// Минимальное кэширование
  minimal,
  
  /// Кэширование отключено
  disabled,
}

/// Engine Configuration - конфигурация движка перевода
/// 
/// Содержит все настройки для тонкой настройки производительности,
/// отладки и поведения Translation Engine.
/// 
/// Пример использования:
/// ```dart
/// final config = EngineConfig(
///   cacheStrategy: CacheStrategy.aggressive,
///   logLevel: LogLevel.info,
///   enablePerformanceMetrics: true,
/// );
/// 
/// await engine.initialize(config: config.toMap());
/// ```
class EngineConfig {
  // === ПРОИЗВОДИТЕЛЬНОСТЬ ===
  
  /// Стратегия кэширования
  final CacheStrategy cacheStrategy;
  
  /// Максимальное количество слов в кэше (null = auto)
  final int? maxWordsInCache;
  
  /// Максимальное количество фраз в кэше (null = auto) 
  final int? maxPhrasesInCache;
  
  /// Время жизни записей в кэше (в секундах)
  final int cacheTtlSeconds;
  
  /// Максимальное время обработки одного текста (в миллисекундах)
  final int maxProcessingTimeMs;
  
  /// Максимальное количество конкурентных переводов
  final int maxConcurrentTranslations;
  
  /// Включить предварительную загрузку частых переводов
  final bool enablePreloading;
  
  /// Размер batch для массовых операций
  final int batchSize;
  
  // === ОТЛАДКА И ЛОГИРОВАНИЕ ===
  
  /// Уровень логирования
  final LogLevel logLevel;
  
  /// Включить подробные метрики производительности
  final bool enablePerformanceMetrics;
  
  /// Включить трассировку выполнения слоев
  final bool enableLayerTracing;
  
  /// Сохранять промежуточные результаты для отладки
  final bool saveIntermediateResults;
  
  /// Включить профилирование памяти
  final bool enableMemoryProfiling;
  
  /// Интервал сбора метрик (в секундах)
  final int metricsCollectionInterval;
  
  // === КАЧЕСТВО ПЕРЕВОДА ===
  
  /// Минимальный confidence для принятия перевода
  final double defaultMinConfidence;
  
  /// Включить проверку качества перевода
  final bool enableQualityCheck;
  
  /// Включить постобработку переводов
  final bool enablePostProcessing;
  
  /// Использовать пользовательские исправления по умолчанию
  final bool useUserCorrections;
  
  /// Включить автоматическое исправление опечаток
  final bool enableSpellcheck;
  
  // === FEATURE FLAGS ===
  
  /// Включить экспериментальные функции
  final bool enableExperimentalFeatures;
  
  /// Включить A/B тестирование алгоритмов
  final bool enableAbTesting;
  
  /// Включить машинное обучение для улучшения переводов
  final bool enableMachineLearning;
  
  /// Включить автоматическое определение языка
  final bool enableLanguageDetection;
  
  /// Включить контекстный перевод
  final bool enableContextualTranslation;
  
  // === БЕЗОПАСНОСТЬ ===
  
  /// Включить валидацию входных данных
  final bool enableInputValidation;
  
  /// Максимальная длина текста для перевода
  final int maxInputLength;
  
  /// Включить фильтрацию нежелательного контента
  final bool enableContentFiltering;
  
  /// Включить rate limiting
  final bool enableRateLimiting;
  
  /// Максимальное количество запросов в минуту
  final int maxRequestsPerMinute;
  
  // === ИНТЕГРАЦИЯ ===
  
  /// Включить телеметрию
  final bool enableTelemetry;
  
  /// URL для отправки метрик (если включена телеметрия)
  final String? telemetryUrl;
  
  /// Включить crash reporting
  final bool enableCrashReporting;
  
  /// Включить автоматические обновления словарей
  final bool enableDictionaryUpdates;
  
  /// Интервал проверки обновлений (в часах)
  final int updateCheckInterval;
  
  const EngineConfig({
    // Performance
    this.cacheStrategy = CacheStrategy.conservative,
    this.maxWordsInCache,
    this.maxPhrasesInCache,
    this.cacheTtlSeconds = 3600, // 1 hour
    this.maxProcessingTimeMs = 5000,
    this.maxConcurrentTranslations = 5,
    this.enablePreloading = false,
    this.batchSize = 100,
    
    // Debugging
    this.logLevel = LogLevel.warning,
    this.enablePerformanceMetrics = false,
    this.enableLayerTracing = false,
    this.saveIntermediateResults = false,
    this.enableMemoryProfiling = false,
    this.metricsCollectionInterval = 60,
    
    // Quality
    this.defaultMinConfidence = 0.7,
    this.enableQualityCheck = true,
    this.enablePostProcessing = true,
    this.useUserCorrections = true,
    this.enableSpellcheck = false,
    
    // Features
    this.enableExperimentalFeatures = false,
    this.enableAbTesting = false,
    this.enableMachineLearning = false,
    this.enableLanguageDetection = false,
    this.enableContextualTranslation = false,
    
    // Security
    this.enableInputValidation = true,
    this.maxInputLength = 10000,
    this.enableContentFiltering = false,
    this.enableRateLimiting = false,
    this.maxRequestsPerMinute = 100,
    
    // Integration
    this.enableTelemetry = false,
    this.telemetryUrl,
    this.enableCrashReporting = false,
    this.enableDictionaryUpdates = false,
    this.updateCheckInterval = 24,
  });
  
  /// Получить лимиты кэша на основе стратегии
  Map<String, int> getCacheLimits() {
    final int wordLimit;
    final int phraseLimit;
    
    if (maxWordsInCache != null && maxPhrasesInCache != null) {
      wordLimit = maxWordsInCache!;
      phraseLimit = maxPhrasesInCache!;
    } else {
      switch (cacheStrategy) {
        case CacheStrategy.aggressive:
          wordLimit = 50000;
          phraseLimit = 25000;
          break;
        case CacheStrategy.conservative:
          wordLimit = 10000;
          phraseLimit = 5000;
          break;
        case CacheStrategy.minimal:
          wordLimit = 1000;
          phraseLimit = 500;
          break;
        case CacheStrategy.disabled:
          wordLimit = 0;
          phraseLimit = 0;
          break;
      }
    }
    
    return {
      'words_limit': wordLimit,
      'phrases_limit': phraseLimit,
    };
  }
  
  /// Проверить, включено ли логирование для данного уровня
  bool isLoggingEnabled(LogLevel level) {
    return level.index <= logLevel.index;
  }
  
  /// Получить timeout для операций базы данных
  Duration getDatabaseTimeout() {
    return Duration(milliseconds: (maxProcessingTimeMs * 0.8).round());
  }
  
  /// Получить timeout для кэш операций
  Duration getCacheTimeout() {
    return Duration(milliseconds: (maxProcessingTimeMs * 0.2).round());
  }
  
  /// Проверить, нужна ли валидация входных данных
  bool shouldValidateInput(String text) {
    return enableInputValidation && text.length <= maxInputLength;
  }
  
  /// Создать копию с изменениями
  EngineConfig copyWith({
    CacheStrategy? cacheStrategy,
    int? maxWordsInCache,
    int? maxPhrasesInCache,
    int? cacheTtlSeconds,
    int? maxProcessingTimeMs,
    int? maxConcurrentTranslations,
    bool? enablePreloading,
    int? batchSize,
    LogLevel? logLevel,
    bool? enablePerformanceMetrics,
    bool? enableLayerTracing,
    bool? saveIntermediateResults,
    bool? enableMemoryProfiling,
    int? metricsCollectionInterval,
    double? defaultMinConfidence,
    bool? enableQualityCheck,
    bool? enablePostProcessing,
    bool? useUserCorrections,
    bool? enableSpellcheck,
    bool? enableExperimentalFeatures,
    bool? enableAbTesting,
    bool? enableMachineLearning,
    bool? enableLanguageDetection,
    bool? enableContextualTranslation,
    bool? enableInputValidation,
    int? maxInputLength,
    bool? enableContentFiltering,
    bool? enableRateLimiting,
    int? maxRequestsPerMinute,
    bool? enableTelemetry,
    String? telemetryUrl,
    bool? enableCrashReporting,
    bool? enableDictionaryUpdates,
    int? updateCheckInterval,
  }) {
    return EngineConfig(
      cacheStrategy: cacheStrategy ?? this.cacheStrategy,
      maxWordsInCache: maxWordsInCache ?? this.maxWordsInCache,
      maxPhrasesInCache: maxPhrasesInCache ?? this.maxPhrasesInCache,
      cacheTtlSeconds: cacheTtlSeconds ?? this.cacheTtlSeconds,
      maxProcessingTimeMs: maxProcessingTimeMs ?? this.maxProcessingTimeMs,
      maxConcurrentTranslations: maxConcurrentTranslations ?? this.maxConcurrentTranslations,
      enablePreloading: enablePreloading ?? this.enablePreloading,
      batchSize: batchSize ?? this.batchSize,
      logLevel: logLevel ?? this.logLevel,
      enablePerformanceMetrics: enablePerformanceMetrics ?? this.enablePerformanceMetrics,
      enableLayerTracing: enableLayerTracing ?? this.enableLayerTracing,
      saveIntermediateResults: saveIntermediateResults ?? this.saveIntermediateResults,
      enableMemoryProfiling: enableMemoryProfiling ?? this.enableMemoryProfiling,
      metricsCollectionInterval: metricsCollectionInterval ?? this.metricsCollectionInterval,
      defaultMinConfidence: defaultMinConfidence ?? this.defaultMinConfidence,
      enableQualityCheck: enableQualityCheck ?? this.enableQualityCheck,
      enablePostProcessing: enablePostProcessing ?? this.enablePostProcessing,
      useUserCorrections: useUserCorrections ?? this.useUserCorrections,
      enableSpellcheck: enableSpellcheck ?? this.enableSpellcheck,
      enableExperimentalFeatures: enableExperimentalFeatures ?? this.enableExperimentalFeatures,
      enableAbTesting: enableAbTesting ?? this.enableAbTesting,
      enableMachineLearning: enableMachineLearning ?? this.enableMachineLearning,
      enableLanguageDetection: enableLanguageDetection ?? this.enableLanguageDetection,
      enableContextualTranslation: enableContextualTranslation ?? this.enableContextualTranslation,
      enableInputValidation: enableInputValidation ?? this.enableInputValidation,
      maxInputLength: maxInputLength ?? this.maxInputLength,
      enableContentFiltering: enableContentFiltering ?? this.enableContentFiltering,
      enableRateLimiting: enableRateLimiting ?? this.enableRateLimiting,
      maxRequestsPerMinute: maxRequestsPerMinute ?? this.maxRequestsPerMinute,
      enableTelemetry: enableTelemetry ?? this.enableTelemetry,
      telemetryUrl: telemetryUrl ?? this.telemetryUrl,
      enableCrashReporting: enableCrashReporting ?? this.enableCrashReporting,
      enableDictionaryUpdates: enableDictionaryUpdates ?? this.enableDictionaryUpdates,
      updateCheckInterval: updateCheckInterval ?? this.updateCheckInterval,
    );
  }
  
  /// Преобразовать в Map для передачи в TranslationEngine.initialize()
  Map<String, dynamic> toMap() {
    final cacheLimits = getCacheLimits();
    
    return {
      // Performance
      'cache_strategy': cacheStrategy.toString(),
      'cache': {
        'words_limit': cacheLimits['words_limit'],
        'phrases_limit': cacheLimits['phrases_limit'],
        'ttl_seconds': cacheTtlSeconds,
      },
      'max_processing_time_ms': maxProcessingTimeMs,
      'max_concurrent_translations': maxConcurrentTranslations,
      'enable_preloading': enablePreloading,
      'batch_size': batchSize,
      
      // Debugging
      'debug': enableLayerTracing || enablePerformanceMetrics,
      'log_level': logLevel.toString(),
      'enable_performance_metrics': enablePerformanceMetrics,
      'enable_layer_tracing': enableLayerTracing,
      'save_intermediate_results': saveIntermediateResults,
      'enable_memory_profiling': enableMemoryProfiling,
      'metrics_collection_interval': metricsCollectionInterval,
      
      // Quality
      'default_min_confidence': defaultMinConfidence,
      'enable_quality_check': enableQualityCheck,
      'enable_post_processing': enablePostProcessing,
      'use_user_corrections': useUserCorrections,
      'enable_spellcheck': enableSpellcheck,
      
      // Features
      'features': {
        'experimental': enableExperimentalFeatures,
        'ab_testing': enableAbTesting,
        'machine_learning': enableMachineLearning,
        'language_detection': enableLanguageDetection,
        'contextual_translation': enableContextualTranslation,
      },
      
      // Security
      'security': {
        'input_validation': enableInputValidation,
        'max_input_length': maxInputLength,
        'content_filtering': enableContentFiltering,
        'rate_limiting': enableRateLimiting,
        'max_requests_per_minute': maxRequestsPerMinute,
      },
      
      // Integration
      'integration': {
        'telemetry': enableTelemetry,
        'telemetry_url': telemetryUrl,
        'crash_reporting': enableCrashReporting,
        'dictionary_updates': enableDictionaryUpdates,
        'update_check_interval': updateCheckInterval,
      },
    };
  }
  
  /// Создать из Map
  factory EngineConfig.fromMap(Map<String, dynamic> map) {
    final cache = map['cache'] as Map<String, dynamic>? ?? {};
    final features = map['features'] as Map<String, dynamic>? ?? {};
    final security = map['security'] as Map<String, dynamic>? ?? {};
    final integration = map['integration'] as Map<String, dynamic>? ?? {};
    
    return EngineConfig(
      cacheStrategy: CacheStrategy.values.firstWhere(
        (e) => e.toString() == map['cache_strategy'],
        orElse: () => CacheStrategy.conservative,
      ),
      maxWordsInCache: cache['words_limit'] as int?,
      maxPhrasesInCache: cache['phrases_limit'] as int?,
      cacheTtlSeconds: cache['ttl_seconds'] as int? ?? 3600,
      maxProcessingTimeMs: map['max_processing_time_ms'] as int? ?? 5000,
      maxConcurrentTranslations: map['max_concurrent_translations'] as int? ?? 5,
      enablePreloading: map['enable_preloading'] as bool? ?? false,
      batchSize: map['batch_size'] as int? ?? 100,
      logLevel: LogLevel.values.firstWhere(
        (e) => e.toString() == map['log_level'],
        orElse: () => LogLevel.warning,
      ),
      enablePerformanceMetrics: map['enable_performance_metrics'] as bool? ?? false,
      enableLayerTracing: map['enable_layer_tracing'] as bool? ?? false,
      saveIntermediateResults: map['save_intermediate_results'] as bool? ?? false,
      enableMemoryProfiling: map['enable_memory_profiling'] as bool? ?? false,
      metricsCollectionInterval: map['metrics_collection_interval'] as int? ?? 60,
      defaultMinConfidence: map['default_min_confidence'] as double? ?? 0.7,
      enableQualityCheck: map['enable_quality_check'] as bool? ?? true,
      enablePostProcessing: map['enable_post_processing'] as bool? ?? true,
      useUserCorrections: map['use_user_corrections'] as bool? ?? true,
      enableSpellcheck: map['enable_spellcheck'] as bool? ?? false,
      enableExperimentalFeatures: features['experimental'] as bool? ?? false,
      enableAbTesting: features['ab_testing'] as bool? ?? false,
      enableMachineLearning: features['machine_learning'] as bool? ?? false,
      enableLanguageDetection: features['language_detection'] as bool? ?? false,
      enableContextualTranslation: features['contextual_translation'] as bool? ?? false,
      enableInputValidation: security['input_validation'] as bool? ?? true,
      maxInputLength: security['max_input_length'] as int? ?? 10000,
      enableContentFiltering: security['content_filtering'] as bool? ?? false,
      enableRateLimiting: security['rate_limiting'] as bool? ?? false,
      maxRequestsPerMinute: security['max_requests_per_minute'] as int? ?? 100,
      enableTelemetry: integration['telemetry'] as bool? ?? false,
      telemetryUrl: integration['telemetry_url'] as String?,
      enableCrashReporting: integration['crash_reporting'] as bool? ?? false,
      enableDictionaryUpdates: integration['dictionary_updates'] as bool? ?? false,
      updateCheckInterval: integration['update_check_interval'] as int? ?? 24,
    );
  }
  
  /// Создать конфигурацию для development
  factory EngineConfig.development() {
    return const EngineConfig(
      cacheStrategy: CacheStrategy.minimal,
      logLevel: LogLevel.debug,
      enablePerformanceMetrics: true,
      enableLayerTracing: true,
      saveIntermediateResults: true,
      enableMemoryProfiling: true,
      enableExperimentalFeatures: true,
      maxProcessingTimeMs: 10000, // Больше времени для отладки
    );
  }
  
  /// Создать конфигурацию для production
  factory EngineConfig.production() {
    return const EngineConfig(
      cacheStrategy: CacheStrategy.aggressive,
      logLevel: LogLevel.error,
      enablePerformanceMetrics: false,
      enableLayerTracing: false,
      saveIntermediateResults: false,
      enableMemoryProfiling: false,
      enableInputValidation: true,
      enableRateLimiting: true,
      maxProcessingTimeMs: 3000,
      enableTelemetry: true,
      enableCrashReporting: true,
    );
  }
  
  /// Создать конфигурацию для тестирования
  factory EngineConfig.testing() {
    return const EngineConfig(
      cacheStrategy: CacheStrategy.disabled,
      logLevel: LogLevel.info,
      enablePerformanceMetrics: true,
      maxProcessingTimeMs: 1000,
      enableInputValidation: false, // Для простоты тестов
      enableRateLimiting: false,
    );
  }
  
  @override
  String toString() {
    return 'EngineConfig('
        'cache: $cacheStrategy, '
        'log: $logLevel, '
        'maxTime: ${maxProcessingTimeMs}ms, '
        'features: ${enableExperimentalFeatures ? 'experimental' : 'stable'}'
        ')';
  }
}