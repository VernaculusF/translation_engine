/// Слой предобработки текста
/// 
/// Первый слой в pipeline, выполняет нормализацию, токенизацию,
/// очистку и подготовку текста для последующих слоев.
library;

import 'dart:math' as math;

import '../core/translation_context.dart';
import '../models/layer_debug_info.dart';
import 'base_translation_layer.dart';

/// Токен текста после предобработки
class TextToken {
  /// Оригинальный текст токена
  final String original;
  
  /// Нормализованный текст токена (lowercase, без диакритики)
  final String normalized;
  
  /// Перевод токена (если был переведён)
  final String? translation;
  
  /// Позиция в исходном тексте
  final int startPosition;
  final int endPosition;
  
  /// Тип токена
  final TokenType type;
  
  /// Уверенность в правильности токенизации
  final double confidence;
  
  /// Дополнительные метаданные
  final Map<String, dynamic> metadata;
  
  const TextToken({
    required this.original,
    required this.normalized,
    this.translation,
    required this.startPosition,
    required this.endPosition,
    required this.type,
    this.confidence = 1.0,
    this.metadata = const {},
  });
  
  /// Длина токена
  int get length => endPosition - startPosition;
  
  /// Токен был изменен при нормализации
  bool get wasNormalized => original.toLowerCase() != normalized;
  
  /// Токен был переведён
  bool get isTranslated => translation != null;
  
  /// Получить финальный текст (перевод или оригинал)
  String get finalText => translation ?? original;
  
  @override
  String toString() {
    final parts = ['Token("$original"'];
    if (wasNormalized) parts.add(' norm:"$normalized"');
    if (isTranslated) parts.add(' trans:"$translation"');
    parts.add(', $type)');
    return parts.join();
  }
  
  /// Создать копию с переводом
  TextToken withTranslation(String translatedText, {double? newConfidence}) {
    return TextToken(
      original: original,
      normalized: normalized,
      translation: translatedText,
      startPosition: startPosition,
      endPosition: endPosition,
      type: type,
      confidence: newConfidence ?? confidence,
      metadata: {...metadata, 'translated': true},
    );
  }
}

/// Типы токенов
enum TokenType {
  /// Обычное слово
  word,
  
  /// Число
  number,
  
  /// Знак пунктуации
  punctuation,
  
  /// Пробельный символ
  whitespace,
  
  /// Специальный символ
  special,
  
  /// Символ новой строки
  newline,
  
  /// Email адрес
  email,
  
  /// URL
  url,
  
  /// Хештег
  hashtag,
  
  /// Упоминание (@username)
  mention,
  
  /// Неизвестный тип
  unknown,
}

/// Слой предобработки текста
/// 
/// Выполняет:
/// - Нормализацию Unicode символов
/// - Очистку от HTML/Markdown разметки
/// - Токенизацию на слова, числа, знаки препинания
/// - Определение базового языка (если не указан)
/// - Обработку специальных символов и сущностей
class PreProcessingLayer extends BaseTranslationLayer {
  /// Регулярные выражения для токенизации
  static final _emailRegex = RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b');
  static final _urlRegex = RegExp(r'https?://[^\s]+|www\.[^\s]+');
  static final _hashtagRegex = RegExp(r'#\w+');
  static final _mentionRegex = RegExp(r'@\w+');
  
  /// HTML теги для очистки
  static final _htmlTagRegex = RegExp(r'<[^>]+>');
  static final _htmlEntityRegex = RegExp(r'&[a-zA-Z0-9#]+;');
  
  /// Карта HTML сущностей
  static const _htmlEntities = {
    '&lt;': '<',
    '&gt;': '>',
    '&amp;': '&',
    '&quot;': '"',
    '&apos;': "'",
    '&nbsp;': ' ',
    '&#39;': "'",
    '&#x27;': "'",
    '&#x2F;': '/',
    '&#x60;': '`',
    '&#x3D;': '=',
  };
  
  @override
  String get name => 'PreProcessingLayer';
  
  @override
  String get description => 'Text normalization, tokenization, and cleanup';
  
  @override
  LayerPriority get priority => LayerPriority.preprocessing;
  
  @override
  bool canHandle(String text, TranslationContext context) {
    // Предобработка нужна всегда, если есть текст
    return text.trim().isNotEmpty;
  }
  
  @override
  Future<LayerResult> process(String text, TranslationContext context) async {
    final stopwatch = Stopwatch()..start();
    final originalText = text;
    
    try {
      // Шаг 1: Очистка от HTML и Markdown
      String cleanedText = _cleanMarkup(text);
      
      // Шаг 2: Нормализация Unicode
      cleanedText = _normalizeUnicode(cleanedText);
      
      // Шаг 3: Токенизация
      final tokens = _tokenize(cleanedText);
      
      // Шаг 4: Дополнительная нормализация токенов
      final normalizedTokens = _normalizeTokens(tokens, context);
      
      // Шаг 5: Сборка финального текста
      final processedText = _reconstructText(normalizedTokens);
      
      // Шаг 6: Определение языка (если не указан)
      String detectedLanguage = '';
      if (context.sourceLanguage.isEmpty || context.sourceLanguage == 'auto') {
        detectedLanguage = _detectLanguage(processedText);
      }
      
      stopwatch.stop();
      
      // Создание debug информации
      final debugInfo = LayerDebugInfo(
        layerName: name,
        inputText: originalText,
        outputText: processedText,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        wasModified: originalText != processedText,
        additionalInfo: {
          'tokens_count': normalizedTokens.length,
          'normalized_tokens': normalizedTokens.where((t) => t.wasNormalized).length,
          'detected_language': detectedLanguage,
          'cleanup_applied': originalText != _cleanMarkup(originalText),
          'token_types': _getTokenTypeStats(normalizedTokens),
          'processing_steps': [
            'HTML/Markdown cleanup',
            'Unicode normalization', 
            'Tokenization',
            'Token normalization',
            'Text reconstruction',
            if (detectedLanguage.isNotEmpty) 'Language detection',
          ],
        },
      );
      
      // Сохранение токенов в контекст для следующих слоев
      context.setMetadata('preprocessing_tokens', normalizedTokens);
      context.setMetadata('token_count', normalizedTokens.length);
      // Заполняем краткие токены для нижних слоёв
      context.tokens = normalizedTokens
          .where((t) => t.type == TokenType.word)
          .map((t) => t.normalized)
          .toList();
      // Инициализируем исходный текст, если ещё не был установлен
      context.originalText ??= originalText;
      if (detectedLanguage.isNotEmpty) {
        context.setMetadata('detected_language', detectedLanguage);
      }
      
      final confidence = _calculateConfidence(originalText, processedText, normalizedTokens);
      
      return LayerResult.success(
        processedText: processedText,
        confidence: confidence,
        debugInfo: debugInfo,
        metadata: {
          'tokens': normalizedTokens.map((t) => {
            'original': t.original,
            'normalized': t.normalized, 
            'type': t.type.name,
            'position': [t.startPosition, t.endPosition],
          }).toList(),
          'detected_language': detectedLanguage,
        },
      );
      
    } catch (e) {
      stopwatch.stop();
      throw LayerException(name, 'Pre-processing failed', e);
    }
  }
  
  /// Очистка HTML и Markdown разметки
  String _cleanMarkup(String text) {
    String cleaned = text;
    
    // Удаление HTML тегов
    cleaned = cleaned.replaceAll(_htmlTagRegex, ' ');
    
    // Декодирование HTML сущностей
    for (final entry in _htmlEntities.entries) {
      cleaned = cleaned.replaceAll(entry.key, entry.value);
    }
    
    // Декодирование остальных числовых HTML сущностей
    cleaned = cleaned.replaceAllMapped(_htmlEntityRegex, (match) {
      final entity = match.group(0)!;
      if (entity.startsWith('&#')) {
        try {
          final code = entity.startsWith('&#x')
              ? int.parse(entity.substring(3, entity.length - 1), radix: 16)
              : int.parse(entity.substring(2, entity.length - 1));
          return String.fromCharCode(code);
        } catch (e) {
          return entity; // Оставляем как есть
        }
      }
      return entity;
    });
    
    // Упрощенная очистка Markdown
    cleaned = cleaned.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1'); // **bold**
    cleaned = cleaned.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1'); // *italic*
    cleaned = cleaned.replaceAll(RegExp(r'_([^_]+)_'), r'$1'); // _italic_
    cleaned = cleaned.replaceAll(RegExp(r'`([^`]+)`'), r'$1'); // `code`
    cleaned = cleaned.replaceAll(RegExp(r'~~([^~]+)~~'), r'$1'); // ~~strike~~
    cleaned = cleaned.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1'); // [text](url)
    cleaned = cleaned.replaceAll(RegExp(r'^#+\s*', multiLine: true), ''); // # headers
    
    return cleaned;
  }
  
  /// Нормализация Unicode символов
  String _normalizeUnicode(String text) {
    // Нормализация пробельных символов
    String normalized = text.replaceAll(RegExp(r'[\u00A0\u2000-\u200B\u2028\u2029\u202F\u205F\u3000]'), ' ');
    
    // Нормализация кавычек
    normalized = normalized.replaceAll(RegExp(r'[“”„‟]'), '"');
    normalized = normalized.replaceAll(RegExp(r'[‘’‚‛]'), "'");
    
    // Нормализация тире
    normalized = normalized.replaceAll(RegExp(r'[–—―]'), '-');
    
    // Нормализация многоточия
    normalized = normalized.replaceAll('…', '...');
    
    // Удаление невидимых символов
    normalized = normalized.replaceAll(RegExp(r'[\u200C\u200D\u200E\u200F\uFEFF]'), '');
    
    // Нормализация множественных пробелов
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    
    return normalized.trim();
  }
  
  /// Токенизация текста
  List<TextToken> _tokenize(String text) {
    final tokens = <TextToken>[];
    final processed = List<bool>.filled(text.length, false);
    
    // Поиск специальных токенов
    _findSpecialTokens(text, tokens, processed);
    
    // Поиск обычных токенов
    _findRegularTokens(text, tokens, processed);
    
    // Сортировка по позиции
    tokens.sort((a, b) => a.startPosition.compareTo(b.startPosition));
    
    return tokens;
  }
  
  /// Поиск специальных токенов
  void _findSpecialTokens(String text, List<TextToken> tokens, List<bool> processed) {
    _findTokensByRegex(text, _urlRegex, TokenType.url, tokens, processed);
    _findTokensByRegex(text, _emailRegex, TokenType.email, tokens, processed);
    _findTokensByRegex(text, _hashtagRegex, TokenType.hashtag, tokens, processed);
    _findTokensByRegex(text, _mentionRegex, TokenType.mention, tokens, processed);
  }
  
  /// Поиск токенов по регулярному выражению
  void _findTokensByRegex(String text, RegExp regex, TokenType type, 
      List<TextToken> tokens, List<bool> processed) {
    final matches = regex.allMatches(text);
    
    for (final match in matches) {
      final start = match.start;
      final end = match.end;
      final tokenText = match.group(0)!;
      
      bool canAdd = true;
      for (int i = start; i < end && canAdd; i++) {
        if (processed[i]) canAdd = false;
      }
      
      if (canAdd) {
        tokens.add(TextToken(
          original: tokenText,
          normalized: tokenText,
          startPosition: start,
          endPosition: end,
          type: type,
          confidence: 0.95,
        ));
        
        for (int i = start; i < end; i++) {
          processed[i] = true;
        }
      }
    }
  }
  
  /// Поиск обычных токенов
  void _findRegularTokens(String text, List<TextToken> tokens, List<bool> processed) {
    int i = 0;
    
    while (i < text.length) {
      if (processed[i]) {
        i++;
        continue;
      }
      
      final char = text[i];
      
      if (_isWhitespace(char)) {
        final start = i;
        while (i < text.length && !processed[i] && _isWhitespace(text[i])) {
          i++;
        }
        
        tokens.add(TextToken(
          original: text.substring(start, i),
          normalized: ' ',
          startPosition: start,
          endPosition: i,
          type: char == '\n' || char == '\r' ? TokenType.newline : TokenType.whitespace,
        ));
        
      } else if (_isPunctuation(char)) {
        tokens.add(TextToken(
          original: char,
          normalized: char,
          startPosition: i,
          endPosition: i + 1,
          type: TokenType.punctuation,
        ));
        i++;
        
      } else if (_isDigit(char)) {
        final start = i;
        while (i < text.length && !processed[i] && 
               (_isDigit(text[i]) || text[i] == '.' || text[i] == ',' || text[i] == ' ')) {
          if (text[i] == ' ' && i + 1 < text.length && !_isDigit(text[i + 1])) {
            break;
          }
          i++;
        }
        
        final numberText = text.substring(start, i).trim();
        tokens.add(TextToken(
          original: numberText,
          normalized: numberText.replaceAll(RegExp(r'\s+'), ''),
          startPosition: start,
          endPosition: start + numberText.length,
          type: TokenType.number,
        ));
        
      } else if (_isWordChar(char)) {
        final start = i;
        while (i < text.length && !processed[i] && _isWordChar(text[i])) {
          i++;
        }
        
        final wordText = text.substring(start, i);
        tokens.add(TextToken(
          original: wordText,
          normalized: wordText.toLowerCase(),
          startPosition: start,
          endPosition: i,
          type: TokenType.word,
        ));
        
      } else {
        tokens.add(TextToken(
          original: char,
          normalized: char,
          startPosition: i,
          endPosition: i + 1,
          type: TokenType.special,
          confidence: 0.8,
        ));
        i++;
      }
    }
  }
  
  /// Дополнительная нормализация токенов
  List<TextToken> _normalizeTokens(List<TextToken> tokens, TranslationContext context) {
    return tokens.map((token) {
      switch (token.type) {
        case TokenType.word:
          String normalized = token.normalized;
          normalized = normalized.replaceAll(RegExp(r"^'|'$"), '');
          
          // Keep intra-word apostrophes (contractions like what's, it's).
          // Possessive handling should be done at grammar/post-processing stage.
          return TextToken(
            original: token.original,
            normalized: normalized,
            startPosition: token.startPosition,
            endPosition: token.endPosition,
            type: token.type,
            confidence: token.confidence,
            metadata: token.metadata,
          );
          
        case TokenType.number:
          String normalized = token.normalized;
          
          if (context.sourceLanguage.startsWith('en')) {
            normalized = normalized.replaceAll(',', '');
          } else {
            normalized = normalized.replaceAll(',', '.');
          }
          
          return TextToken(
            original: token.original,
            normalized: normalized,
            startPosition: token.startPosition,
            endPosition: token.endPosition,
            type: token.type,
            confidence: token.confidence,
            metadata: token.metadata,
          );
          
        default:
          return token;
      }
    }).toList();
  }
  
  /// Сборка текста из токенов
  String _reconstructText(List<TextToken> tokens) {
    if (tokens.isEmpty) return '';
    
    final buffer = StringBuffer();
    
    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      
      buffer.write(token.normalized);
      
      if (i < tokens.length - 1) {
        final nextToken = tokens[i + 1];
        
        if (token.type == TokenType.word && nextToken.type == TokenType.word) {
          if (!tokens.any((t) => 
              t.startPosition > token.endPosition && 
              t.startPosition < nextToken.startPosition &&
              (t.type == TokenType.whitespace || t.type == TokenType.newline))) {
            buffer.write(' ');
          }
        }
      }
    }
    
    return buffer.toString().trim();
  }
  
  /// Определение языка
  String _detectLanguage(String text) {
    if (text.length < 3) return '';
    
    final textLower = text.toLowerCase();
    
    int cyrillicCount = 0;
    int latinCount = 0;
    int chineseCount = 0;
    int arabicCount = 0;
    
    for (int i = 0; i < text.length; i++) {
      final char = text.codeUnitAt(i);
      
      if (char >= 0x0400 && char <= 0x04FF) {
        cyrillicCount++;
      } else if ((char >= 0x0041 && char <= 0x005A) || (char >= 0x0061 && char <= 0x007A)) {
        latinCount++;
      } else if (char >= 0x4E00 && char <= 0x9FFF) {
        chineseCount++;
      } else if (char >= 0x0600 && char <= 0x06FF) {
        arabicCount++;
      }
    }
    
    final total = cyrillicCount + latinCount + chineseCount + arabicCount;
    if (total == 0) return '';
    
    if (cyrillicCount > total * 0.3) {
      if (textLower.contains('що') || textLower.contains('який')) {
        return 'uk';
      } else {
        return 'ru';
      }
    } else if (chineseCount > total * 0.3) {
      return 'zh';
    } else if (arabicCount > total * 0.3) {
      return 'ar';
    } else if (latinCount > total * 0.3) {
      if (textLower.contains('the ') || textLower.contains(' and ')) {
        return 'en';
      } else if (textLower.contains('der ') || textLower.contains('die ')) {
        return 'de';
      } else {
        return 'en';
      }
    }
    
    return '';
  }
  
  /// Вычисление уверенности
  double _calculateConfidence(String original, String processed, List<TextToken> tokens) {
    if (tokens.isEmpty) return 0.0;
    
    double confidence = 1.0;
    
    final specialTokens = tokens.where((t) => t.type == TokenType.special || t.type == TokenType.unknown).length;
    final specialRatio = specialTokens / tokens.length;
    confidence -= specialRatio * 0.3;
    
    final changedTokens = tokens.where((t) => t.wasNormalized).length;
    final changeRatio = changedTokens / tokens.length;
    if (changeRatio > 0.5) {
      confidence -= (changeRatio - 0.5) * 0.4;
    }
    
    if (processed.length < 3) {
      confidence *= 0.5;
    }
    
    return math.max(0.0, math.min(1.0, confidence));
  }
  
  /// Статистика типов токенов
  Map<String, int> _getTokenTypeStats(List<TextToken> tokens) {
    final stats = <String, int>{};
    
    for (final token in tokens) {
      final typeName = token.type.name;
      stats[typeName] = (stats[typeName] ?? 0) + 1;
    }
    
    return stats;
  }
  
  /// Проверка на пробельный символ
  bool _isWhitespace(String char) {
    return char == ' ' || char == '\t' || char == '\n' || char == '\r';
  }
  
  /// Проверка на знак пунктуации
  bool _isPunctuation(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 33 && code <= 47) ||
           (code >= 58 && code <= 64) ||
           (code >= 91 && code <= 96) ||
           (code >= 123 && code <= 126);
  }
  
  /// Проверка на цифру
  bool _isDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }
  
  /// Проверка на символ слова
  bool _isWordChar(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) ||
           (code >= 97 && code <= 122) ||
           (code >= 48 && code <= 57) ||
           (code >= 0x0400 && code <= 0x04FF) ||
           (code >= 0x4E00 && code <= 0x9FFF) ||
           char == "'" || char == '-' || char == '_';
  }
}
