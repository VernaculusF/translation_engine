/// Отладочная информация о работе слоя перевода
class LayerDebugInfo {
  /// Название слоя
  final String layerName;
  
  /// Время обработки слоем в мс
  final int processingTimeMs;
  
  /// Успешно ли обработан слой
  final bool isSuccessful;
  
  /// Произошла ли ошибка
  final bool hasError;
  
  /// Сообщение об ошибке (если есть)
  final String? errorMessage;
  
  /// Количество обработанных слов/фраз
  final int itemsProcessed;
  
  /// Количество изменений, сделанных слоем
  final int modificationsCount;
  
  /// Уровень воздействия слоя на результат (0.0 - 1.0)
  final double impactLevel;
  
  /// Количество использованных кэш-записей
  final int cacheHits;
  
  /// Количество промахов кэша
  final int cacheMisses;
  
  /// Дополнительные отладочные данные
  final Map<String, dynamic> debugData;
  
  /// Варнинги слоя (например, низкое качество)
  final List<String> warnings;
  
  /// Настройки, использованные слоем
  final Map<String, dynamic> layerConfig;

  const LayerDebugInfo({
    required this.layerName,
    required this.processingTimeMs,
    this.isSuccessful = true,
    this.hasError = false,
    this.errorMessage,
    this.itemsProcessed = 0,
    this.modificationsCount = 0,
    this.impactLevel = 0.0,
    this.cacheHits = 0,
    this.cacheMisses = 0,
    this.debugData = const {},
    this.warnings = const [],
    this.layerConfig = const {},
  });

  /// Конструктор для успешной обработки
  factory LayerDebugInfo.success({
    required String layerName,
    required int processingTimeMs,
    int itemsProcessed = 0,
    int modificationsCount = 0,
    double impactLevel = 0.0,
    int cacheHits = 0,
    int cacheMisses = 0,
    Map<String, dynamic> debugData = const {},
    List<String> warnings = const [],
    Map<String, dynamic> layerConfig = const {},
  }) {
    return LayerDebugInfo(
      layerName: layerName,
      processingTimeMs: processingTimeMs,
      isSuccessful: true,
      hasError: false,
      errorMessage: null,
      itemsProcessed: itemsProcessed,
      modificationsCount: modificationsCount,
      impactLevel: impactLevel,
      cacheHits: cacheHits,
      cacheMisses: cacheMisses,
      debugData: debugData,
      warnings: warnings,
      layerConfig: layerConfig,
    );
  }

  /// Конструктор для обработки с ошибкой
  factory LayerDebugInfo.error({
    required String layerName,
    required int processingTimeMs,
    required String errorMessage,
    int itemsProcessed = 0,
    int modificationsCount = 0,
    Map<String, dynamic> debugData = const {},
    Map<String, dynamic> layerConfig = const {},
  }) {
    return LayerDebugInfo(
      layerName: layerName,
      processingTimeMs: processingTimeMs,
      isSuccessful: false,
      hasError: true,
      errorMessage: errorMessage,
      itemsProcessed: itemsProcessed,
      modificationsCount: modificationsCount,
      impactLevel: 0.0,
      cacheHits: 0,
      cacheMisses: 0,
      debugData: debugData,
      warnings: [],
      layerConfig: layerConfig,
    );
  }

  /// Общий hit rate кэша для этого слоя
  double get cacheHitRate {
    final totalRequests = cacheHits + cacheMisses;
    return totalRequests > 0 ? cacheHits / totalRequests : 0.0;
  }

  /// Производительность обработки (элементов в мс)
  double get processingRate {
    return processingTimeMs > 0 ? itemsProcessed / processingTimeMs * 1000 : 0.0;
  }

  /// Количество изменений на элемент
  double get modificationRate {
    return itemsProcessed > 0 ? modificationsCount / itemsProcessed : 0.0;
  }

  /// Есть ли предупреждения
  bool get hasWarnings => warnings.isNotEmpty;

  /// Конвертация в Map для сериализации
  Map<String, dynamic> toMap() {
    return {
      'layer_name': layerName,
      'processing_time_ms': processingTimeMs,
      'is_successful': isSuccessful,
      'has_error': hasError,
      'error_message': errorMessage,
      'items_processed': itemsProcessed,
      'modifications_count': modificationsCount,
      'impact_level': impactLevel,
      'cache_hits': cacheHits,
      'cache_misses': cacheMisses,
      'cache_hit_rate': cacheHitRate,
      'processing_rate': processingRate,
      'modification_rate': modificationRate,
      'debug_data': debugData,
      'warnings': warnings,
      'layer_config': layerConfig,
    };
  }

  /// Создание из Map
  factory LayerDebugInfo.fromMap(Map<String, dynamic> map) {
    return LayerDebugInfo(
      layerName: map['layer_name'] as String,
      processingTimeMs: map['processing_time_ms'] as int,
      isSuccessful: (map['is_successful'] as bool?) ?? true,
      hasError: (map['has_error'] as bool?) ?? false,
      errorMessage: map['error_message'] as String?,
      itemsProcessed: (map['items_processed'] as int?) ?? 0,
      modificationsCount: (map['modifications_count'] as int?) ?? 0,
      impactLevel: ((map['impact_level'] as num?) ?? 0.0).toDouble(),
      cacheHits: (map['cache_hits'] as int?) ?? 0,
      cacheMisses: (map['cache_misses'] as int?) ?? 0,
      debugData: Map<String, dynamic>.from(map['debug_data'] as Map? ?? {}),
      warnings: List<String>.from(map['warnings'] as List? ?? []),
      layerConfig: Map<String, dynamic>.from(map['layer_config'] as Map? ?? {}),
    );
  }

  /// Создание копии с изменениями
  LayerDebugInfo copyWith({
    String? layerName,
    int? processingTimeMs,
    bool? isSuccessful,
    bool? hasError,
    String? errorMessage,
    int? itemsProcessed,
    int? modificationsCount,
    double? impactLevel,
    int? cacheHits,
    int? cacheMisses,
    Map<String, dynamic>? debugData,
    List<String>? warnings,
    Map<String, dynamic>? layerConfig,
  }) {
    return LayerDebugInfo(
      layerName: layerName ?? this.layerName,
      processingTimeMs: processingTimeMs ?? this.processingTimeMs,
      isSuccessful: isSuccessful ?? this.isSuccessful,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      itemsProcessed: itemsProcessed ?? this.itemsProcessed,
      modificationsCount: modificationsCount ?? this.modificationsCount,
      impactLevel: impactLevel ?? this.impactLevel,
      cacheHits: cacheHits ?? this.cacheHits,
      cacheMisses: cacheMisses ?? this.cacheMisses,
      debugData: debugData ?? this.debugData,
      warnings: warnings ?? this.warnings,
      layerConfig: layerConfig ?? this.layerConfig,
    );
  }

  /// Краткое резюме о работе слоя
  String get summary {
    if (hasError) {
      return '$layerName: Error - $errorMessage (${processingTimeMs}ms)';
    }
    return '$layerName: $itemsProcessed items, '
           '$modificationsCount mods, ${processingTimeMs}ms';
  }

  /// Отчет о производительности слоя
  Map<String, dynamic> get performanceReport {
    return {
      'layer_name': layerName,
      'processing_time_ms': processingTimeMs,
      'items_processed': itemsProcessed,
      'processing_rate_per_sec': processingRate,
      'modification_rate': modificationRate,
      'cache_hit_rate': cacheHitRate,
      'impact_level': impactLevel,
      'warnings_count': warnings.length,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LayerDebugInfo &&
        other.layerName == layerName &&
        other.processingTimeMs == processingTimeMs &&
        other.isSuccessful == isSuccessful &&
        other.hasError == hasError;
  }

  @override
  int get hashCode {
    return Object.hash(
      layerName,
      processingTimeMs,
      isSuccessful,
      hasError,
    );
  }

  @override
  String toString() {
    if (hasError) {
      return 'LayerDebugInfo.error(layer: $layerName, '
             'error: $errorMessage, time: ${processingTimeMs}ms)';
    }
    return 'LayerDebugInfo.success(layer: $layerName, '
           'items: $itemsProcessed, mods: $modificationsCount, '
           'time: ${processingTimeMs}ms)';
  }
}