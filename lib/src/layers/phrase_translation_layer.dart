/// Слой фразовых переводов
/// 
/// Слой для поиска готовых переводов фраз, идиом и устойчивых выражений
/// в базе данных фраз через PhraseRepository.
library;

import '../core/translation_context.dart';
import '../data/phrase_repository.dart';
import '../models/layer_debug_info.dart';
import 'base_translation_layer.dart';
import 'pre_processing_layer.dart';

/// Результат перевода фразы
class PhraseTranslation {
  /// Исходная фраза
  final String sourcePhrase;
  
  /// Переведенная фраза
  final String targetPhrase;
  
  /// Тип фразы (idiom, collocation, expression, etc.)
  final String? phraseType;
  
  /// Категория фразы (business, technical, casual, etc.)
  final String? category;
  
  /// Контекст использования
  final String? context;
  
  /// Уверенность в переводе (0.0 - 1.0)
  final double confidence;
  
  /// Частотность использования фразы
  final int usageCount;
  
  /// Позиция в исходном тексте
  final int startPosition;
  final int endPosition;
  
  /// Дополнительные метаданные
  final Map<String, dynamic> metadata;
  
  const PhraseTranslation({
    required this.sourcePhrase,
    required this.targetPhrase,
    this.phraseType,
    this.category,
    this.context,
    required this.confidence,
    this.usageCount = 0,
    required this.startPosition,
    required this.endPosition,
    this.metadata = const {},
  });
  
  /// Длина фразы
  int get length => endPosition - startPosition;
  
  /// Количество слов во фразе
  int get wordCount => sourcePhrase.split(' ').length;
  
  @override
  String toString() => '$sourcePhrase -> $targetPhrase ($confidence)';
}

/// Группа переводов для одной фразы
class PhraseTranslationGroup {
  /// Исходная фраза
  final String sourcePhrase;
  
  /// Список возможных переводов
  final List<PhraseTranslation> translations;
  
  /// Лучший (наиболее вероятный) перевод
  final PhraseTranslation bestTranslation;
  
  /// Общая уверенность группы
  final double groupConfidence;
  
  /// Позиция фразы в тексте
  final int startPosition;
  final int endPosition;
  
  const PhraseTranslationGroup({
    required this.sourcePhrase,
    required this.translations,
    required this.bestTranslation,
    required this.groupConfidence,
    required this.startPosition,
    required this.endPosition,
  });
  
  /// Количество переводов
  int get translationCount => translations.length;
  
  /// Есть ли множественные переводы
  bool get hasMultipleTranslations => translations.length > 1;
  
  /// Перекрывается ли с другой фразой
  bool overlapsWith(PhraseTranslationGroup other) {
    return !(endPosition <= other.startPosition || startPosition >= other.endPosition);
  }
  
  @override
  String toString() => '$sourcePhrase: ${translations.length} options, best: ${bestTranslation.targetPhrase}';
}

/// Слой фразовых переводов
/// 
/// Выполняет:
/// - Поиск готовых переводов фраз в PhraseRepository
/// - Обработку идиом и устойчивых выражений
/// - Разрешение конфликтов между перекрывающимися фразами
/// - Учет контекста и категории фразы
/// - Приоритизацию длинных фраз над короткими
class PhraseTranslationLayer extends BaseTranslationLayer {
  /// Repository для доступа к фразам
  final PhraseRepository _phraseRepository;
  
  /// Минимальная уверенность для принятия перевода фразы
  static const double _minConfidence = 0.4;
  
  /// Максимальное количество рассматриваемых переводов на фразу
  static const int _maxTranslationsPerPhrase = 3;
  
  /// Минимальная длина фразы в словах
  static const int _minPhraseWords = 2;
  
  /// Максимальная длина фразы в словах
  static const int _maxPhraseWords = 8;
  
  PhraseTranslationLayer({
    required PhraseRepository phraseRepository,
  }) : _phraseRepository = phraseRepository;
  
  @override
  String get name => 'PhraseTranslationLayer';
  
  @override
  String get description => 'Phrase-level translation using phrase lookup';
  
  @override
  LayerPriority get priority => LayerPriority.phrase;
  
  @override
  bool canHandle(String text, TranslationContext context) {
    // Фразовый слой работает если есть токены слов и достаточно текста
    final tokens = context.getMetadata<List<TextToken>>('preprocessing_tokens');
    if (tokens == null || tokens.isEmpty) return false;
    
    final wordTokens = tokens.where((token) => token.type == TokenType.word).toList();
    return wordTokens.length >= _minPhraseWords;
  }
  
  @override
  Future<LayerResult> process(String text, TranslationContext context) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Получаем токены от PreProcessingLayer
      final tokens = context.getMetadata<List<TextToken>>('preprocessing_tokens');
      if (tokens == null || tokens.isEmpty) {
        throw ArgumentError('No tokens found in context metadata');
      }
      
      // Извлекаем только словарные токены
      final wordTokens = tokens.where((token) => token.type == TokenType.word).toList();
      
      if (wordTokens.length < _minPhraseWords) {
        return LayerResult.noChange(
          text: text,
          debugInfo: _createDebugInfo(
            inputText: text,
            outputText: text,
            processingTimeMs: stopwatch.elapsedMilliseconds,
            additionalInfo: {'reason': 'Not enough words for phrase detection'},
          ),
          reason: 'Text too short for phrases',
        );
      }
      
      // Поиск фраз в тексте (пока заглушка)
      final phraseGroups = <PhraseTranslationGroup>[];
      
      if (phraseGroups.isEmpty) {
        return LayerResult.noChange(
          text: text,
          debugInfo: _createDebugInfo(
            inputText: text,
            outputText: text,
            processingTimeMs: stopwatch.elapsedMilliseconds,
            additionalInfo: {'reason': 'No phrases found'},
          ),
          reason: 'No translatable phrases found',
        );
      }
      
      stopwatch.stop();
      
      return LayerResult.success(
        processedText: text, // Пока без изменений
        confidence: 0.5,
        debugInfo: _createDebugInfo(
          inputText: text,
          outputText: text,
          processingTimeMs: stopwatch.elapsedMilliseconds,
        ),
      );
      
    } catch (e) {
      stopwatch.stop();
      throw LayerException(name, 'Phrase translation failed', e);
    }
  }
  
  /// Создание debug информации
  LayerDebugInfo _createDebugInfo({
    required String inputText,
    required String outputText,
    required int processingTimeMs,
    Map<String, dynamic> additionalInfo = const {},
  }) {
    return LayerDebugInfo(
      layerName: name,
      processingTimeMs: processingTimeMs,
      inputText: inputText,
      outputText: outputText,
      wasModified: inputText != outputText,
      additionalInfo: {
        'layer_version': version,
        'min_confidence_threshold': _minConfidence,
        'max_translations_per_phrase': _maxTranslationsPerPhrase,
        'min_phrase_words': _minPhraseWords,
        'max_phrase_words': _maxPhraseWords,
        ...additionalInfo,
      },
    );
  }
}
