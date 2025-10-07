/// Translation Context - контекст перевода
/// 
/// Контейнер для настроек перевода, языковых пар,
/// пользовательских предпочтений и состояния перевода.
library;

/// Типы контекста перевода
enum TranslationMode {
  /// Обычный перевод
  standard,
  
  /// Быстрый перевод (только кэш и словарь)
  fast,
  
  /// Подробный перевод (все слои + debug)
  detailed,
  
  /// Качественный перевод (максимальное качество)
  quality,
}

/// Уровень формальности перевода
enum FormalityLevel {
  /// Неопределенный
  auto,
  
  /// Неформальный
  informal,
  
  /// Нейтральный
  neutral,
  
  /// Формальный
  formal,
}

/// Область применения перевода
enum TranslationDomain {
  /// Общая лексика
  general,
  
  /// Техническая литература
  technical,
  
  /// Медицинская литература
  medical,
  
  /// Юридическая литература
  legal,
  
  /// Научная литература
  scientific,
  
  /// Бизнес
  business,
  
  /// Литература и сказки
  literary,
}

/// Translation Context - контекст перевода
/// 
/// Содержит все настройки, предпочтения и метаданные,
/// необходимые для качественного перевода.
/// 
/// Пример использования:
/// ```dart
/// final context = TranslationContext(
///   sourceLanguage: 'en',
///   targetLanguage: 'ru',
///   mode: TranslationMode.quality,
///   formality: FormalityLevel.formal,
///   domain: TranslationDomain.technical,
/// );
/// ```
class TranslationContext {
  /// Исходный язык (ISO 639-1 код)
  final String sourceLanguage;
  
  /// Целевой язык (ISO 639-1 код)
  final String targetLanguage;
  
  /// Режим перевода
  final TranslationMode mode;
  
  /// Уровень формальности
  final FormalityLevel formality;
  
  /// Область применения
  final TranslationDomain domain;
  
  /// Максимальное время обработки (в миллисекундах)
  final int? maxProcessingTimeMs;
  
  /// Минимальный уровень confidence для принятия перевода
  final double? minConfidence;
  
  /// Использовать кэш
  final bool useCache;
  
  /// Сохранять переводы в кэш
  final bool saveToCache;
  
  /// Использовать пользовательские исправления
  final bool useUserCorrections;
  
  /// Включить режим отладки
  final bool debugMode;
  
  /// Список исключаемых слов (не переводить)
  final Set<String> excludeWords;
  
  /// Список принудительных переводов (слово -> перевод)
  final Map<String, String> forceTranslations;
  
  /// Контекстная информация (например, предыдущие предложения)
  final String? contextText;
  
  /// Идентификатор пользователя
  final String? userId;
  
  /// Идентификатор сессии
  final String? sessionId;
  
  /// Метаданные перевода
  final Map<String, dynamic> metadata;
  
  const TranslationContext({
    required this.sourceLanguage,
    required this.targetLanguage,
    this.mode = TranslationMode.standard,
    this.formality = FormalityLevel.auto,
    this.domain = TranslationDomain.general,
    this.maxProcessingTimeMs,
    this.minConfidence,
    this.useCache = true,
    this.saveToCache = true,
    this.useUserCorrections = true,
    this.debugMode = false,
    this.excludeWords = const {},
    this.forceTranslations = const {},
    this.contextText,
    this.userId,
    this.sessionId,
    this.metadata = const {},
  });
  
  /// языковая пара в формате "en-ru"
  String get languagePair => '$sourceLanguage-$targetLanguage';
  
  /// Обращенная языковая пара в формате "ru-en"
  String get reverseLanguagePair => '$targetLanguage-$sourceLanguage';
  
  /// Проверить, поддерживается ли языковая пара
  bool isLanguagePairSupported() {
    final supportedPairs = {
      'en-ru', 'ru-en',
      'en-es', 'es-en',
      'en-fr', 'fr-en',
      'en-de', 'de-en',
      'en-it', 'it-en',
      'en-pt', 'pt-en',
      'ru-es', 'es-ru',
      'ru-fr', 'fr-ru',
    };
    
    return supportedPairs.contains(languagePair);
  }
  
  /// Проверить, нужно ли исключить слово
  bool shouldExcludeWord(String word) {
    return excludeWords.contains(word.toLowerCase());
  }
  
  /// Получить принудительный перевод слова (если есть)
  String? getForceTranslation(String word) {
    return forceTranslations[word.toLowerCase()];
  }
  
  /// Проверить, подходит ли режим для быстрого перевода
  bool isFastModeEnabled() {
    return mode == TranslationMode.fast;
  }
  
  /// Проверить, нужна ли подробная информация о debugе
  bool isDebugEnabled() {
    return debugMode || mode == TranslationMode.detailed;
  }
  
  /// Проверить, нужно ли максимальное качество
  bool isQualityModeEnabled() {
    return mode == TranslationMode.quality;
  }
  
  /// Создать копию с изменениями
  TranslationContext copyWith({
    String? sourceLanguage,
    String? targetLanguage,
    TranslationMode? mode,
    FormalityLevel? formality,
    TranslationDomain? domain,
    int? maxProcessingTimeMs,
    double? minConfidence,
    bool? useCache,
    bool? saveToCache,
    bool? useUserCorrections,
    bool? debugMode,
    Set<String>? excludeWords,
    Map<String, String>? forceTranslations,
    String? contextText,
    String? userId,
    String? sessionId,
    Map<String, dynamic>? metadata,
  }) {
    return TranslationContext(
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      mode: mode ?? this.mode,
      formality: formality ?? this.formality,
      domain: domain ?? this.domain,
      maxProcessingTimeMs: maxProcessingTimeMs ?? this.maxProcessingTimeMs,
      minConfidence: minConfidence ?? this.minConfidence,
      useCache: useCache ?? this.useCache,
      saveToCache: saveToCache ?? this.saveToCache,
      useUserCorrections: useUserCorrections ?? this.useUserCorrections,
      debugMode: debugMode ?? this.debugMode,
      excludeWords: excludeWords ?? this.excludeWords,
      forceTranslations: forceTranslations ?? this.forceTranslations,
      contextText: contextText ?? this.contextText,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      metadata: metadata ?? this.metadata,
    );
  }
  
  /// Преобразовать в Map
  Map<String, dynamic> toMap() {
    return {
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
      'mode': mode.toString(),
      'formality': formality.toString(),
      'domain': domain.toString(),
      'max_processing_time_ms': maxProcessingTimeMs,
      'min_confidence': minConfidence,
      'use_cache': useCache,
      'save_to_cache': saveToCache,
      'use_user_corrections': useUserCorrections,
      'debug_mode': debugMode,
      'exclude_words': excludeWords.toList(),
      'force_translations': forceTranslations,
      'context_text': contextText,
      'user_id': userId,
      'session_id': sessionId,
      'metadata': metadata,
      'language_pair': languagePair,
    };
  }
  
  /// Создать из Map
  factory TranslationContext.fromMap(Map<String, dynamic> map) {
    return TranslationContext(
      sourceLanguage: map['source_language'] as String,
      targetLanguage: map['target_language'] as String,
      mode: TranslationMode.values.firstWhere(
        (e) => e.toString() == map['mode'],
        orElse: () => TranslationMode.standard,
      ),
      formality: FormalityLevel.values.firstWhere(
        (e) => e.toString() == map['formality'],
        orElse: () => FormalityLevel.auto,
      ),
      domain: TranslationDomain.values.firstWhere(
        (e) => e.toString() == map['domain'],
        orElse: () => TranslationDomain.general,
      ),
      maxProcessingTimeMs: map['max_processing_time_ms'] as int?,
      minConfidence: map['min_confidence'] as double?,
      useCache: map['use_cache'] as bool? ?? true,
      saveToCache: map['save_to_cache'] as bool? ?? true,
      useUserCorrections: map['use_user_corrections'] as bool? ?? true,
      debugMode: map['debug_mode'] as bool? ?? false,
      excludeWords: (map['exclude_words'] as List<dynamic>? ?? [])
          .cast<String>()
          .toSet(),
      forceTranslations: Map<String, String>.from(
        map['force_translations'] as Map<String, dynamic>? ?? {},
      ),
      contextText: map['context_text'] as String?,
      userId: map['user_id'] as String?,
      sessionId: map['session_id'] as String?,
      metadata: Map<String, dynamic>.from(
        map['metadata'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
  
  /// Создать контекст для быстрого перевода
  factory TranslationContext.fast({
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    return TranslationContext(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      mode: TranslationMode.fast,
      useCache: true,
      saveToCache: true,
      maxProcessingTimeMs: 100, // 100ms лимит
    );
  }
  
  /// Создать контекст для качественного перевода
  factory TranslationContext.quality({
    required String sourceLanguage,
    required String targetLanguage,
    TranslationDomain domain = TranslationDomain.general,
    FormalityLevel formality = FormalityLevel.auto,
  }) {
    return TranslationContext(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      mode: TranslationMode.quality,
      domain: domain,
      formality: formality,
      useCache: true,
      saveToCache: true,
      useUserCorrections: true,
      minConfidence: 0.8, // высокие требования к confidence
    );
  }
  
  /// Создать debug контекст
  factory TranslationContext.debug({
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    return TranslationContext(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      mode: TranslationMode.detailed,
      debugMode: true,
      useCache: true,
      saveToCache: false, // Не засоряем кэш debug данными
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is TranslationContext &&
        other.sourceLanguage == sourceLanguage &&
        other.targetLanguage == targetLanguage &&
        other.mode == mode &&
        other.formality == formality &&
        other.domain == domain &&
        other.maxProcessingTimeMs == maxProcessingTimeMs &&
        other.minConfidence == minConfidence &&
        other.useCache == useCache &&
        other.saveToCache == saveToCache &&
        other.useUserCorrections == useUserCorrections &&
        other.debugMode == debugMode;
  }
  
  @override
  int get hashCode {
    return Object.hash(
      sourceLanguage,
      targetLanguage,
      mode,
      formality,
      domain,
      maxProcessingTimeMs,
      minConfidence,
      useCache,
      saveToCache,
      useUserCorrections,
      debugMode,
    );
  }
  
  @override
  String toString() {
    return 'TranslationContext('
        'languagePair: $languagePair, '
        'mode: $mode, '
        'formality: $formality, '
        'domain: $domain, '
        'useCache: $useCache'
        ')';
  }
}