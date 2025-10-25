/// Словарный слой перевода
/// 
/// Основной слой перевода, выполняющий поиск переводов отдельных слов
/// в словарной базе данных через DictionaryRepository.
library;

import 'dart:math' as math;

import '../core/translation_context.dart';
import '../data/dictionary_repository.dart';
import '../models/layer_debug_info.dart';
import 'base_translation_layer.dart';
import 'pre_processing_layer.dart';

/// Результат перевода отдельного слова
class WordTranslation {
  /// Исходное слово
  final String sourceWord;
  
  /// Переведенное слово
  final String targetWord;
  
  /// Часть речи
  final String? partOfSpeech;
  
  /// Определение/значение
  final String? definition;
  
  /// Уверенность в переводе (0.0 - 1.0)
  final double confidence;
  
  /// Частотность использования слова
  final int frequency;
  
  /// Дополнительные метаданные
  final Map<String, dynamic> metadata;
  
  const WordTranslation({
    required this.sourceWord,
    required this.targetWord,
    this.partOfSpeech,
    this.definition,
    required this.confidence,
    this.frequency = 0,
    this.metadata = const {},
  });
  
  @override
  String toString() => '$sourceWord -> $targetWord ($confidence)';
}

/// Группа переводов для одного слова
class WordTranslationGroup {
  /// Исходное слово
  final String sourceWord;
  
  /// Список возможных переводов
  final List<WordTranslation> translations;
  
  /// Лучший (наиболее вероятный) перевод
  final WordTranslation bestTranslation;
  
  /// Общая уверенность группы
  final double groupConfidence;
  
  const WordTranslationGroup({
    required this.sourceWord,
    required this.translations,
    required this.bestTranslation,
    required this.groupConfidence,
  });
  
  /// Количество переводов
  int get translationCount => translations.length;
  
  /// Есть ли множественные переводы
  bool get hasMultipleTranslations => translations.length > 1;
  
  @override
  String toString() => '$sourceWord: ${translations.length} options, best: ${bestTranslation.targetWord}';
}

/// Словарный слой перевода
/// 
/// Выполняет:
/// - Поиск переводов отдельных слов в DictionaryRepository
/// - Обработку множественных переводов с выбором лучшего
/// - Частеречную разметку и определения
/// - Учет частотности и контекста
/// - Работу с пользовательскими исправлениями
class DictionaryLayer extends BaseTranslationLayer {
  /// Repository для доступа к словарям
  final DictionaryRepository _dictionaryRepository;
  
  /// Минимальная уверенность для принятия перевода
  static const double _minConfidence = 0.3;
  
  /// Максимальное количество рассматриваемых переводов
  static const int _maxTranslationsPerWord = 5;
  
  DictionaryLayer({
    required DictionaryRepository dictionaryRepository,
  }) : _dictionaryRepository = dictionaryRepository;
  
  @override
  String get name => 'DictionaryLayer';
  
  @override
  String get description => 'Word-level translation using dictionary lookup';
  
  @override
  LayerPriority get priority => LayerPriority.dictionary;
  
  @override
  bool canHandle(String text, TranslationContext context) {
    // Словарный слой работает, если есть токены слов
    final tokens = context.getMetadata<List<TextToken>>('preprocessing_tokens');
    if (tokens == null || tokens.isEmpty) return false;
    
    // Проверяем, есть ли хотя бы одно слово
    return tokens.any((token) => token.type == TokenType.word);
  }
  
  @override
  Future<LayerResult> process(String text, TranslationContext context) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Токенизируем текущий текст, чтобы работать последовательно по конвейеру
      final tokens = _tokenizeText(text);
      
      // Извлекаем только словарные токены
      final wordTokens = tokens.where((token) => token.type == TokenType.word).toList();
      
      if (wordTokens.isEmpty) {
        return LayerResult.noChange(
          text: text,
          debugInfo: _createDebugInfo(
            inputText: text,
            outputText: text,
            processingTimeMs: stopwatch.elapsedMilliseconds,
            additionalInfo: {'reason': 'No word tokens found'},
          ),
          reason: 'No words to translate',
        );
      }
      
      // Переводим каждое слово
      final translationGroups = <WordTranslationGroup>[];
      final translatedTokens = <TextToken>[];
      
      int successfulTranslations = 0;
      int totalWords = 0;
      
      for (final token in tokens) {
        if (token.type == TokenType.word) {
          totalWords++;
          
          // Проверяем принудительные переводы
          final forceTranslation = context.getForceTranslation(token.normalized);
          if (forceTranslation != null) {
            final forcedGroup = WordTranslationGroup(
              sourceWord: token.normalized,
              translations: [
                WordTranslation(
                  sourceWord: token.normalized,
                  targetWord: forceTranslation,
                  confidence: 1.0,
                  frequency: 1000,
                  metadata: const {'forced': true},
                ),
              ],
              bestTranslation: WordTranslation(
                sourceWord: token.normalized,
                targetWord: forceTranslation,
                confidence: 1.0,
                frequency: 1000,
                metadata: const {'forced': true},
              ),
              groupConfidence: 1.0,
            );
            
            translationGroups.add(forcedGroup);
            translatedTokens.add(_createTranslatedToken(token, forceTranslation, 1.0));
            successfulTranslations++;
            continue;
          }
          
          // Проверяем исключения
          if (context.shouldExcludeWord(token.normalized)) {
            translatedTokens.add(token);
            continue;
          }
          
          // Поиск в словаре
          final translationGroup = await _translateWord(
            token.normalized,
            context.sourceLanguage,
            context.targetLanguage,
            context,
          );
          
          if (translationGroup != null && translationGroup.bestTranslation.confidence >= _minConfidence) {
            translationGroups.add(translationGroup);
            translatedTokens.add(_createTranslatedToken(
              token,
              translationGroup.bestTranslation.targetWord,
              translationGroup.bestTranslation.confidence,
            ));
            successfulTranslations++;
          } else {
            translatedTokens.add(token);
          }
        } else {
          translatedTokens.add(token);
        }
      }
      
      // Сборка переведенного текста
      final translatedText = _reconstructTextFromTokens(translatedTokens);
      
      stopwatch.stop();
      
      // Вычисляем метрики
      final translationRate = totalWords > 0 ? successfulTranslations / totalWords : 0.0;
      final overallConfidence = _calculateOverallConfidence(translationGroups);
      
      // Сохраняем результаты в контекст
      context.setMetadata('dictionary_translations', translationGroups);
      context.setMetadata('translated_tokens', translatedTokens);
      context.setMetadata('dictionary_success_rate', translationRate);
      
      return LayerResult.success(
        processedText: translatedText,
        confidence: overallConfidence,
        debugInfo: _createDebugInfo(
          inputText: text,
          outputText: translatedText,
          processingTimeMs: stopwatch.elapsedMilliseconds,
          additionalInfo: {
            'total_words': totalWords,
            'successful_translations': successfulTranslations,
            'translation_rate': translationRate,
          },
        ),
      );
      
    } catch (e) {
      stopwatch.stop();
      throw LayerException(name, 'Dictionary translation failed', e);
    }
  }
  
  /// Простейшая токенизация текущего текста (слова и прочие сегменты)
  List<TextToken> _tokenizeText(String text) {
    final tokens = <TextToken>[];
    int i = 0;
    while (i < text.length) {
      final ch = text.codeUnitAt(i);
      // [A-Za-z] слово
      if ((ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122)) {
        final start = i;
        while (i < text.length) {
          final c = text.codeUnitAt(i);
          if (!((c >= 65 && c <= 90) || (c >= 97 && c <= 122))) break;
          i++;
        }
        final original = text.substring(start, i);
        tokens.add(TextToken(
          original: original,
          normalized: original.toLowerCase(),
          startPosition: start,
          endPosition: i,
          type: TokenType.word,
        ));
      } else {
        // прочий символ: сгруппируем подрядной последовательностью
        final start = i;
        while (i < text.length) {
          final c = text.codeUnitAt(i);
          final isLetter = (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
          if (isLetter) break;
          i++;
        }
        final seg = text.substring(start, i);
        final isWhitespace = RegExp(r"^\s+").hasMatch(seg);
        tokens.add(TextToken(
          original: seg,
          normalized: seg,
          startPosition: start,
          endPosition: i,
          type: isWhitespace ? TokenType.whitespace : TokenType.punctuation,
        ));
      }
    }
    return tokens;
  }
  
  /// Перевод отдельного слова
  Future<WordTranslationGroup?> _translateWord(
    String word,
    String sourceLanguage,
    String targetLanguage,
    TranslationContext context,
  ) async {
    try {
      // Сначала попробуем точное совпадение
      final exactEntry = await _dictionaryRepository.getTranslation(
        word,
        '$sourceLanguage-$targetLanguage',
      );
      
      List<Map<String, dynamic>> dictionaryEntries = [];
      
      if (exactEntry != null) {
        dictionaryEntries.add({
          'id': exactEntry.id,
          'source_word': exactEntry.sourceWord,
          'target_word': exactEntry.targetWord,
          'part_of_speech': exactEntry.partOfSpeech,
          'definition': exactEntry.definition,
          'frequency': exactEntry.frequency,
          'language_pair': exactEntry.languagePair,
        });
      } else {
        // Если точного не нашли, поищем по частичному совпадению ТОЛЬКО для слов длиной >= 2
        if (word.length >= 2) {
          final searchResults = await _dictionaryRepository.searchByWord(
            word,
            '$sourceLanguage-$targetLanguage',
            limit: _maxTranslationsPerWord,
          );
          
          dictionaryEntries = searchResults.map((entry) => {
            'id': entry.id,
            'source_word': entry.sourceWord,
            'target_word': entry.targetWord,
            'part_of_speech': entry.partOfSpeech,
            'definition': entry.definition,
            'frequency': entry.frequency,
            'language_pair': entry.languagePair,
          }).toList();
        } else {
          dictionaryEntries = [];
        }
      }
      
      if (dictionaryEntries.isEmpty) return null;
      
      final translations = <WordTranslation>[];
      
      for (final entry in dictionaryEntries.take(_maxTranslationsPerWord)) {
        final confidence = _calculateWordConfidence(entry, context, dictionaryEntries.length);
        
        final translation = WordTranslation(
          sourceWord: word,
          targetWord: entry['target_word'] as String,
          partOfSpeech: entry['part_of_speech'] as String?,
          definition: entry['definition'] as String?,
          confidence: confidence,
          frequency: (entry['frequency'] as int?) ?? 0,
          metadata: {
            'from_cache': entry.containsKey('from_cache') ? entry['from_cache'] : false,
            'database_id': entry['id'],
          },
        );
        
        translations.add(translation);
      }
      
      if (translations.isEmpty) return null;
      
      translations.sort((a, b) {
        final confidenceCompare = b.confidence.compareTo(a.confidence);
        if (confidenceCompare != 0) return confidenceCompare;
        return b.frequency.compareTo(a.frequency);
      });
      
      final bestTranslation = translations.first;
      final groupConfidence = _calculateGroupConfidence(translations);
      
      return WordTranslationGroup(
        sourceWord: word,
        translations: translations,
        bestTranslation: bestTranslation,
        groupConfidence: groupConfidence,
      );
      
    } catch (e) {
      return null;
    }
  }
  
  /// Вычисление уверенности для отдельного перевода
  double _calculateWordConfidence(
    Map<String, dynamic> entry,
    TranslationContext context,
    int totalOptionsCount,
  ) {
    double confidence = 0.7;
    
    final frequency = (entry['frequency'] as int?) ?? 0;
    if (frequency > 1000) {
      confidence += 0.2;
    } else if (frequency > 100) {
      confidence += 0.1;
    } else if (frequency < 10) {
      confidence -= 0.1;
    }
    
    if (totalOptionsCount == 1) {
      confidence += 0.1;
    } else if (totalOptionsCount > 5) {
      confidence -= 0.1;
    }
    
    if (entry['part_of_speech'] != null) confidence += 0.05;
    if (entry['definition'] != null) confidence += 0.05;
    
    if (context.isQualityModeEnabled()) {
      confidence *= 0.9;
    }
    
    return math.max(0.0, math.min(1.0, confidence));
  }
  
  /// Вычисление групповой уверенности
  double _calculateGroupConfidence(List<WordTranslation> translations) {
    if (translations.isEmpty) return 0.0;
    
    final bestConfidence = translations.first.confidence;
    final averageConfidence = translations
        .map((t) => t.confidence)
        .reduce((a, b) => a + b) / translations.length;
    
    return (bestConfidence * 0.7 + averageConfidence * 0.3);
  }
  
  /// Вычисление общей уверенности слоя
  double _calculateOverallConfidence(List<WordTranslationGroup> groups) {
    if (groups.isEmpty) return 0.0;
    
    final totalConfidence = groups
        .map((g) => g.groupConfidence)
        .reduce((a, b) => a + b);
    
    return totalConfidence / groups.length;
  }
  
  /// Создание токена с переводом
  TextToken _createTranslatedToken(TextToken originalToken, String translation, double confidence) {
    return TextToken(
      original: originalToken.original,
      normalized: translation,
      startPosition: originalToken.startPosition,
      endPosition: originalToken.endPosition,
      type: originalToken.type,
      confidence: confidence,
      metadata: {
        ...originalToken.metadata,
        'translated': true,
        'translation_confidence': confidence,
      },
    );
  }
  
  /// Сборка текста из токенов
  String _reconstructTextFromTokens(List<TextToken> tokens) {
    if (tokens.isEmpty) return '';
    
    final buffer = StringBuffer();
    
    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      
      if (token.type == TokenType.word && token.wasNormalized) {
        buffer.write(token.normalized);
      } else {
        buffer.write(token.original);
      }
      
      if (i < tokens.length - 1) {
        final nextToken = tokens[i + 1];
        
        if (token.type == TokenType.word && nextToken.type == TokenType.word) {
          buffer.write(' ');
        } else if (token.type == TokenType.punctuation && nextToken.type == TokenType.word) {
          buffer.write(' ');
        }
      }
    }
    
    return buffer.toString().trim();
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
        'max_translations_per_word': _maxTranslationsPerWord,
        ...additionalInfo,
      },
    );
  }
}
