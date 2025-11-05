/// Слой фразовых переводов
/// 
/// Слой для поиска готовых переводов фраз, идиом и устойчивых выражений
/// в базе данных фраз через PhraseRepository.
library;

import 'dart:math' as math;
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
      
      // Пробуем точный поиск фразы по всему нормализованному тексту
      final normalizedSource = wordTokens.map((t) => t.normalized).join(' ');
      final exact = await _phraseRepository.getPhraseTranslation(
        normalizedSource,
        context.languagePair,
      );
      if (exact != null) {
        final processed = exact.targetPhrase;
        stopwatch.stop();
        return LayerResult.success(
          processedText: processed,
          confidence: math.max(0.7, (exact.confidence / 100.0)),
          debugInfo: _createDebugInfo(
            inputText: text,
            outputText: processed,
            processingTimeMs: stopwatch.elapsedMilliseconds,
            additionalInfo: {
              'matched_phrase': normalizedSource,
              'target_phrase': exact.targetPhrase,
              'confidence_raw': exact.confidence,
            },
          ),
        );
      }
      
      // Если точного совпадения для всей строки нет — выполнить n-gram поиск по токенам
      final preproc = context.getMetadata<List<TextToken>>('preprocessing_tokens');
      if (preproc == null || preproc.isEmpty) {
        return LayerResult.noChange(
          text: text,
          debugInfo: _createDebugInfo(
            inputText: text,
            outputText: text,
            processingTimeMs: stopwatch.elapsedMilliseconds,
            additionalInfo: {'reason': 'No phrases found (exact)', 'ngram': 'skipped_no_tokens'},
          ),
          reason: 'No translatable phrases found',
        );
      }

      // Выделяем только слова с позициями
      final ngramWordTokens = preproc.where((t) => t.type == TokenType.word).toList();
      if (ngramWordTokens.length < _minPhraseWords) {
        return LayerResult.noChange(
          text: text,
          debugInfo: _createDebugInfo(
            inputText: text,
            outputText: text,
            processingTimeMs: stopwatch.elapsedMilliseconds,
            additionalInfo: {'reason': 'No phrases found (too_few_words)'},
          ),
          reason: 'No translatable phrases found',
        );
      }

      // Поиск n-грамм (от длинных к коротким), без перекрытий
      final matches = <_PhraseMatch>[];
      final used = List<bool>.filled(ngramWordTokens.length, false);
      for (int len = _maxPhraseWords; len >= _minPhraseWords; len--) {
        for (int i = 0; i + len <= ngramWordTokens.length; i++) {
          // Пропускаем окна, если пересекаются с уже выбранными
          bool overlapped = false;
          for (int k = i; k < i + len; k++) {
            if (used[k]) { overlapped = true; break; }
          }
          if (overlapped) continue;
          final window = ngramWordTokens.sublist(i, i + len);
          final phraseNorm = window.map((t) => t.normalized).join(' ');
          final found = await _phraseRepository.getPhraseTranslation(
            phraseNorm,
            context.languagePair,
          );
          if (found != null) {
            matches.add(_PhraseMatch(
              startWordIndex: i,
              endWordIndex: i + len - 1,
              startPos: window.first.startPosition,
              endPos: window.last.endPosition,
              source: phraseNorm,
              target: found.targetPhrase,
              confidence: math.max(0.6, (found.confidence / 100.0) + (len - 2) * 0.05).clamp(0.0, 1.0),
            ));
            for (int k = i; k < i + len; k++) {
              used[k] = true;
            }
          }
        }
      }

      if (matches.isEmpty) {
        return LayerResult.noChange(
          text: text,
          debugInfo: _createDebugInfo(
            inputText: text,
            outputText: text,
            processingTimeMs: stopwatch.elapsedMilliseconds,
            additionalInfo: {'reason': 'No phrases found (ngram)'},
          ),
          reason: 'No translatable phrases found',
        );
      }

      // Реконструируем текст из оригинала, заменяя найденные диапазоны
      matches.sort((a,b) => a.startPos.compareTo(b.startPos));
      final buf = StringBuffer();
      int pos = 0;
      // Сохраним защищённые диапазоны в координатах выходного текста
      final protected = <List<int>>[]; // [start,end)
      for (final m in matches) {
        if (m.startPos > pos) buf.write(text.substring(pos, m.startPos));
        final outStart = buf.length;
        buf.write(m.target);
        final outEnd = buf.length;
        protected.add([outStart, outEnd]);
        pos = m.endPos;
      }
      if (pos < text.length) buf.write(text.substring(pos));
      final processed = buf.toString();

      // Положим защищённые диапазоны в контекст, чтобы словарь их не трогал
      context.setMetadata('phrase_protected_ranges', protected);
      context.setMetadata('phrase_applied', true);

      final layerInfo = _createDebugInfo(
        inputText: text,
        outputText: processed,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        additionalInfo: {
          'ngram_matches': matches.length,
          'windows_used': used.where((v) => v).length,
        },
      );

      return LayerResult.success(
        processedText: processed,
        confidence: matches.map((m) => m.confidence).reduce((a,b)=>a+b) / matches.length,
        debugInfo: layerInfo,
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
        'phrase_repo_storage': 'jsonl',
        'storage_root_dir': _phraseRepository.storage.rootDir,
        ...additionalInfo,
      },
    );
  }
}

class _PhraseMatch {
  final int startWordIndex;
  final int endWordIndex;
  final int startPos;
  final int endPos;
  final String source;
  final String target;
  final double confidence;
  _PhraseMatch({
    required this.startWordIndex,
    required this.endWordIndex,
    required this.startPos,
    required this.endPos,
    required this.source,
    required this.target,
    required this.confidence,
  });
}
