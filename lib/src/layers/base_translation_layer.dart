/// Базовый абстрактный класс для всех слоев перевода
/// 
/// Определяет единый интерфейс для всех слоев системы перевода,
/// обеспечивает масштабируемость и возможность отладки.
library;

import '../core/translation_context.dart';
import '../models/layer_debug_info.dart';

/// Приоритет слоя в pipeline (чем меньше число, тем выше приоритет)
enum LayerPriority {
  /// Предобработка - самый высокий приоритет (0)
  preprocessing(0),
  
  /// Поиск фраз - высокий приоритет (100) 
  phrase(100),
  
  /// Словарные переводы - средний приоритет (200)
  dictionary(200),
  
  /// Грамматическая обработка - низкий приоритет (300)
  grammar(300),
  
  /// Порядок слов - очень низкий приоритет (400)
  wordOrder(400),
  
  /// Постобработка - самый низкий приоритет (500)
  postProcessing(500);
  
  const LayerPriority(this.value);
  final int value;
}

/// Результат обработки слоя
class LayerResult {
  /// Обработанный текст
  final String processedText;
  
  /// Успешность обработки
  final bool success;
  
  /// Сообщение об ошибке (если была)
  final String? errorMessage;
  
  /// Уверенность в результате (0.0 - 1.0)
  final double confidence;
  
  /// Информация для отладки
  final LayerDebugInfo debugInfo;
  
  /// Дополнительные метаданные
  final Map<String, dynamic> metadata;
  
  const LayerResult({
    required this.processedText,
    required this.success,
    this.errorMessage,
    required this.confidence,
    required this.debugInfo,
    this.metadata = const {},
  });
  
  /// Создать успешный результат
  factory LayerResult.success({
    required String processedText,
    double confidence = 1.0,
    required LayerDebugInfo debugInfo,
    Map<String, dynamic> metadata = const {},
  }) {
    return LayerResult(
      processedText: processedText,
      success: true,
      confidence: confidence,
      debugInfo: debugInfo,
      metadata: metadata,
    );
  }
  
  /// Создать результат с ошибкой
  factory LayerResult.error({
    required String originalText,
    required String errorMessage,
    required LayerDebugInfo debugInfo,
  }) {
    return LayerResult(
      processedText: originalText,
      success: false,
      errorMessage: errorMessage,
      confidence: 0.0,
      debugInfo: debugInfo,
    );
  }
  
  /// Создать результат без изменений
  factory LayerResult.noChange({
    required String text,
    required LayerDebugInfo debugInfo,
    String reason = 'No processing needed',
  }) {
    return LayerResult(
      processedText: text,
      success: true,
      confidence: 1.0,
      debugInfo: debugInfo,
      metadata: {'no_change_reason': reason},
    );
  }
}

/// Абстрактный базовый класс для всех слоев перевода
/// 
/// Все слои должны наследоваться от этого класса и реализовывать
/// абстрактные методы для обеспечения единообразного API.
abstract class BaseTranslationLayer {
  /// Включен ли debug режим для этого слоя
  bool _debugEnabled = false;
  
  /// Статистика использования слоя
  int _processedCount = 0;
  Duration _totalProcessingTime = Duration.zero;
  int _successCount = 0;
  int _errorCount = 0;
  
  /// Уникальное имя слоя
  String get name;
  
  /// Описание функционала слоя
  String get description;
  
  /// Приоритет слоя в pipeline
  LayerPriority get priority;
  
  /// Версия слоя (для совместимости)
  String get version => '1.0.0';
  
  /// Включен ли debug режим
  bool get debugEnabled => _debugEnabled;
  
  /// Статистика работы слоя
  Map<String, dynamic> get statistics => {
    'processed_count': _processedCount,
    'success_count': _successCount,
    'error_count': _errorCount,
    'success_rate': _processedCount > 0 ? _successCount / _processedCount : 0.0,
    'total_processing_time_ms': _totalProcessingTime.inMilliseconds,
    'average_processing_time_ms': _processedCount > 0 
        ? _totalProcessingTime.inMilliseconds / _processedCount 
        : 0,
  };
  
  /// Включить/отключить debug режим
  void setDebugEnabled(bool enabled) {
    _debugEnabled = enabled;
  }
  
  /// Может ли слой обработать данный контекст
  /// 
  /// Позволяет слою решить, нужно ли ему участвовать в обработке
  /// конкретного текста или контекста перевода.
  bool canHandle(String text, TranslationContext context);
  
  /// Основной метод обработки слоя
  /// 
  /// [text] - входящий текст для обработки
  /// [context] - контекст перевода с настройками и метаданными
  /// 
  /// Возвращает [LayerResult] с результатом обработки
  Future<LayerResult> process(String text, TranslationContext context);
  
  /// Валидация входных данных
  /// 
  /// Проверяет корректность входных параметров перед обработкой.
  /// По умолчанию проверяет только на пустоту текста.
  bool validateInput(String text, TranslationContext context) {
    return text.isNotEmpty && 
           context.sourceLanguage.isNotEmpty && 
           context.targetLanguage.isNotEmpty;
  }
  
  /// Обработка с измерением времени и статистикой
  /// 
  /// Обертка над основным методом process() для сбора метрик
  Future<LayerResult> processWithMetrics(String text, TranslationContext context) async {
    final stopwatch = Stopwatch()..start();
    LayerResult result;
    
    try {
      // Валидация входных данных
      if (!validateInput(text, context)) {
        throw ArgumentError('Invalid input parameters for layer $name');
      }
      
      // Проверка возможности обработки
      if (!canHandle(text, context)) {
        result = LayerResult.noChange(
          text: text,
          debugInfo: _createDebugInfo(
            layerName: name,
            inputText: text,
            outputText: text,
            processingTimeMs: 0,
            additionalInfo: {'skipped': true, 'reason': 'canHandle returned false'},
          ),
          reason: 'Layer cannot handle this input',
        );
      } else {
        // Основная обработка
        result = await process(text, context);
      }
      
      // Обновление статистики
      stopwatch.stop();
      _updateStatistics(stopwatch.elapsed, result.success);
      
      // Добавление времени обработки в debug info
      if (_debugEnabled) {
        result = LayerResult(
          processedText: result.processedText,
          success: result.success,
          errorMessage: result.errorMessage,
          confidence: result.confidence,
          debugInfo: result.debugInfo.copyWith(
            processingTimeMs: stopwatch.elapsedMilliseconds,
          ),
          metadata: result.metadata,
        );
      }
      
      return result;
      
    } catch (e) {
      stopwatch.stop();
      _updateStatistics(stopwatch.elapsed, false);
      
      return LayerResult.error(
        originalText: text,
        errorMessage: 'Layer $name error: $e',
        debugInfo: _createDebugInfo(
          layerName: name,
          inputText: text,
          outputText: text,
          processingTimeMs: stopwatch.elapsedMilliseconds,
          additionalInfo: {'error': e.toString()},
        ),
      );
    }
  }
  
  /// Создание debug информации
  LayerDebugInfo _createDebugInfo({
    required String layerName,
    required String inputText,
    required String outputText,
    required int processingTimeMs,
    Map<String, dynamic> additionalInfo = const {},
  }) {
    return LayerDebugInfo(
      layerName: layerName,
      inputText: inputText,
      outputText: outputText,
      processingTimeMs: processingTimeMs,
      wasModified: inputText != outputText,
      additionalInfo: {
        'layer_version': version,
        'debug_enabled': _debugEnabled,
        ...additionalInfo,
      },
    );
  }
  
  /// Обновление статистики слоя
  void _updateStatistics(Duration processingTime, bool success) {
    _processedCount++;
    _totalProcessingTime += processingTime;
    
    if (success) {
      _successCount++;
    } else {
      _errorCount++;
    }
  }
  
  /// Сброс статистики (для тестов)
  void resetStatistics() {
    _processedCount = 0;
    _totalProcessingTime = Duration.zero;
    _successCount = 0;
    _errorCount = 0;
  }
  
  /// Получить детальную информацию о слое
  Map<String, dynamic> getLayerInfo() {
    return {
      'name': name,
      'description': description,
      'priority': priority.value,
      'version': version,
      'debug_enabled': _debugEnabled,
      'statistics': statistics,
    };
  }
  
  @override
  String toString() => 'TranslationLayer($name, priority: ${priority.value})';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BaseTranslationLayer && other.name == name;
  }
  
  @override
  int get hashCode => name.hashCode;
}

/// Исключение слоя перевода
class LayerException implements Exception {
  final String layerName;
  final String message;
  final dynamic originalError;
  
  const LayerException(this.layerName, this.message, [this.originalError]);
  
  @override
  String toString() {
    final errorInfo = originalError != null ? ' (${originalError.toString()})' : '';
    return 'LayerException in $layerName: $message$errorInfo';
  }
}