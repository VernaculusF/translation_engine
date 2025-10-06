import 'layer_debug_info.dart';

/// Результат перевода с детальной информацией о процессе
class TranslationResult {
  /// Исходный текст для перевода
  final String originalText;
  
  /// Результат перевода
  final String translatedText;
  
  /// Языковая пара (например: "en-ru")
  final String languagePair;
  
  /// Уровень уверенности в переводе (0.0 - 1.0)
  final double confidence;
  
  /// Время выполнения перевода в миллисекундах
  final int processingTimeMs;
  
  /// Информация о работе каждого слоя
  final List<LayerDebugInfo> layerResults;
  
  /// Общее количество обработанных слоев
  final int layersProcessed;
  
  /// Была ли ошибка при переводе
  final bool hasError;
  
  /// Сообщение об ошибке (если есть)
  final String? errorMessage;
  
  /// Метрики использования кэша
  final CacheMetrics? cacheMetrics;
  
  /// Временная метка создания результата
  final DateTime timestamp;
  
  /// Качество перевода (оценка от 1 до 10)
  final double? qualityScore;
  
  /// Список альтернативных переводов
  final List<String> alternatives;
  
  /// Контекстная информация
  final Map<String, dynamic> context;

  const TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.languagePair,
    required this.confidence,
    required this.processingTimeMs,
    required this.layerResults,
    required this.layersProcessed,
    required this.hasError,
    this.errorMessage,
    this.cacheMetrics,
    required this.timestamp,
    this.qualityScore,
    this.alternatives = const [],
    this.context = const {},
  });

  /// Конструктор для успешного перевода
  factory TranslationResult.success({
    required String originalText,
    required String translatedText,
    required String languagePair,
    required double confidence,
    required int processingTimeMs,
    required List<LayerDebugInfo> layerResults,
    CacheMetrics? cacheMetrics,
    double? qualityScore,
    List<String> alternatives = const [],
    Map<String, dynamic> context = const {},
  }) {
    return TranslationResult(
      originalText: originalText,
      translatedText: translatedText,
      languagePair: languagePair,
      confidence: confidence,
      processingTimeMs: processingTimeMs,
      layerResults: layerResults,
      layersProcessed: layerResults.length,
      hasError: false,
      errorMessage: null,
      cacheMetrics: cacheMetrics,
      timestamp: DateTime.now(),
      qualityScore: qualityScore,
      alternatives: alternatives,
      context: context,
    );
  }

  /// Конструктор для результата с ошибкой
  factory TranslationResult.error({
    required String originalText,
    required String languagePair,
    required String errorMessage,
    required int processingTimeMs,
    List<LayerDebugInfo> layerResults = const [],
    CacheMetrics? cacheMetrics,
    Map<String, dynamic> context = const {},
  }) {
    return TranslationResult(
      originalText: originalText,
      translatedText: originalText, // Возвращаем исходный текст при ошибке
      languagePair: languagePair,
      confidence: 0.0,
      processingTimeMs: processingTimeMs,
      layerResults: layerResults,
      layersProcessed: layerResults.length,
      hasError: true,
      errorMessage: errorMessage,
      cacheMetrics: cacheMetrics,
      timestamp: DateTime.now(),
      qualityScore: null,
      alternatives: [],
      context: context,
    );
  }

  /// Создание копии с изменениями
  TranslationResult copyWith({
    String? originalText,
    String? translatedText,
    String? languagePair,
    double? confidence,
    int? processingTimeMs,
    List<LayerDebugInfo>? layerResults,
    int? layersProcessed,
    bool? hasError,
    String? errorMessage,
    CacheMetrics? cacheMetrics,
    DateTime? timestamp,
    double? qualityScore,
    List<String>? alternatives,
    Map<String, dynamic>? context,
  }) {
    return TranslationResult(
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      languagePair: languagePair ?? this.languagePair,
      confidence: confidence ?? this.confidence,
      processingTimeMs: processingTimeMs ?? this.processingTimeMs,
      layerResults: layerResults ?? this.layerResults,
      layersProcessed: layersProcessed ?? this.layersProcessed,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      cacheMetrics: cacheMetrics ?? this.cacheMetrics,
      timestamp: timestamp ?? this.timestamp,
      qualityScore: qualityScore ?? this.qualityScore,
      alternatives: alternatives ?? this.alternatives,
      context: context ?? this.context,
    );
  }

  /// Конвертация в Map для сериализации
  Map<String, dynamic> toMap() {
    return {
      'original_text': originalText,
      'translated_text': translatedText,
      'language_pair': languagePair,
      'confidence': confidence,
      'processing_time_ms': processingTimeMs,
      'layer_results': layerResults.map((layer) => layer.toMap()).toList(),
      'layers_processed': layersProcessed,
      'has_error': hasError,
      'error_message': errorMessage,
      'cache_metrics': cacheMetrics?.toMap(),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'quality_score': qualityScore,
      'alternatives': alternatives,
      'context': context,
    };
  }

  /// Создание из Map
  factory TranslationResult.fromMap(Map<String, dynamic> map) {
    return TranslationResult(
      originalText: map['original_text'] as String,
      translatedText: map['translated_text'] as String,
      languagePair: map['language_pair'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      processingTimeMs: map['processing_time_ms'] as int,
      layerResults: (map['layer_results'] as List<dynamic>)
          .map((layer) => LayerDebugInfo.fromMap(layer as Map<String, dynamic>))
          .toList(),
      layersProcessed: map['layers_processed'] as int,
      hasError: map['has_error'] as bool,
      errorMessage: map['error_message'] as String?,
      cacheMetrics: map['cache_metrics'] != null
          ? CacheMetrics.fromMap(map['cache_metrics'] as Map<String, dynamic>)
          : null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      qualityScore: map['quality_score'] as double?,
      alternatives: List<String>.from(map['alternatives'] as List? ?? []),
      context: Map<String, dynamic>.from(map['context'] as Map? ?? {}),
    );
  }

  /// Проверка успешности перевода
  bool get isSuccessful => !hasError && confidence > 0.0;

  /// Проверка высокого качества перевода
  bool get isHighQuality => confidence >= 0.8;

  /// Проверка низкого качества перевода
  bool get isLowQuality => confidence < 0.5;

  /// Получение общего времени обработки слоями
  int get totalLayerProcessingTime {
    return layerResults.fold(0, (total, layer) => total + layer.processingTimeMs);
  }

  /// Получение самого медленного слоя
  LayerDebugInfo? get slowestLayer {
    if (layerResults.isEmpty) return null;
    return layerResults.reduce((a, b) => 
        a.processingTimeMs > b.processingTimeMs ? a : b);
  }

  /// Получение списка ошибок по слоям
  List<LayerDebugInfo> get layersWithErrors {
    return layerResults.where((layer) => layer.hasError).toList();
  }

  /// Краткое резюме результата
  String get summary {
    if (hasError) {
      return 'Error: $errorMessage';
    }
    return 'Success: ${confidence.toStringAsFixed(2)} confidence, '
           '${processingTimeMs}ms processing';
  }

  /// Детальный отчет о производительности
  Map<String, dynamic> get performanceReport {
    return {
      'total_processing_time_ms': processingTimeMs,
      'layer_processing_time_ms': totalLayerProcessingTime,
      'overhead_ms': processingTimeMs - totalLayerProcessingTime,
      'layers_processed': layersProcessed,
      'average_layer_time_ms': layersProcessed > 0 
          ? totalLayerProcessingTime / layersProcessed 
          : 0,
      'slowest_layer': slowestLayer?.layerName,
      'slowest_layer_time_ms': slowestLayer?.processingTimeMs,
      'cache_metrics': cacheMetrics?.toMap(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TranslationResult &&
        other.originalText == originalText &&
        other.translatedText == translatedText &&
        other.languagePair == languagePair &&
        other.confidence == confidence &&
        other.hasError == hasError;
  }

  @override
  int get hashCode {
    return Object.hash(
      originalText,
      translatedText,
      languagePair,
      confidence,
      hasError,
    );
  }

  @override
  String toString() {
    if (hasError) {
      return 'TranslationResult.error('
             'original: "$originalText", '
             'error: "$errorMessage", '
             'time: ${processingTimeMs}ms)';
    }
    return 'TranslationResult.success('
           'original: "$originalText", '
           'translated: "$translatedText", '
           'confidence: ${confidence.toStringAsFixed(3)}, '
           'time: ${processingTimeMs}ms)';
  }
}

/// Метрики использования кэша
class CacheMetrics {
  /// Количество попаданий в кэш слов
  final int wordCacheHits;
  
  /// Количество промахов кэша слов
  final int wordCacheMisses;
  
  /// Количество попаданий в кэш фраз
  final int phraseCacheHits;
  
  /// Количество промахов кэша фраз
  final int phraseCacheMisses;
  
  /// Время, сэкономленное благодаря кэшу (мс)
  final int timeSavedMs;

  const CacheMetrics({
    required this.wordCacheHits,
    required this.wordCacheMisses,
    required this.phraseCacheHits,
    required this.phraseCacheMisses,
    required this.timeSavedMs,
  });

  /// Общий hit rate кэша (0.0 - 1.0)
  double get hitRate {
    final totalHits = wordCacheHits + phraseCacheHits;
    final totalRequests = totalHits + wordCacheMisses + phraseCacheMisses;
    return totalRequests > 0 ? totalHits / totalRequests : 0.0;
  }

  /// Hit rate для слов
  double get wordHitRate {
    final totalWordRequests = wordCacheHits + wordCacheMisses;
    return totalWordRequests > 0 ? wordCacheHits / totalWordRequests : 0.0;
  }

  /// Hit rate для фраз
  double get phraseHitRate {
    final totalPhraseRequests = phraseCacheHits + phraseCacheMisses;
    return totalPhraseRequests > 0 ? phraseCacheHits / totalPhraseRequests : 0.0;
  }

  /// Конвертация в Map
  Map<String, dynamic> toMap() {
    return {
      'word_cache_hits': wordCacheHits,
      'word_cache_misses': wordCacheMisses,
      'phrase_cache_hits': phraseCacheHits,
      'phrase_cache_misses': phraseCacheMisses,
      'time_saved_ms': timeSavedMs,
      'hit_rate': hitRate,
      'word_hit_rate': wordHitRate,
      'phrase_hit_rate': phraseHitRate,
    };
  }

  /// Создание из Map
  factory CacheMetrics.fromMap(Map<String, dynamic> map) {
    return CacheMetrics(
      wordCacheHits: map['word_cache_hits'] as int,
      wordCacheMisses: map['word_cache_misses'] as int,
      phraseCacheHits: map['phrase_cache_hits'] as int,
      phraseCacheMisses: map['phrase_cache_misses'] as int,
      timeSavedMs: map['time_saved_ms'] as int,
    );
  }

  @override
  String toString() {
    return 'CacheMetrics(hitRate: ${(hitRate * 100).toStringAsFixed(1)}%, '
           'timeSaved: ${timeSavedMs}ms)';
  }
}

