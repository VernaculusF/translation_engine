/// Schema Validator для JSONL файлов
/// 
/// Валидация записей словаря, фраз и правил при загрузке из файлов.
/// Поддержка карантина битых записей и детальной отчётности.
library;

import 'dart:convert';

/// Результат валидации записи
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final Map<String, dynamic>? sanitizedData;
  
  const ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.sanitizedData,
  });
  
  factory ValidationResult.valid(Map<String, dynamic> data) {
    return ValidationResult(
      isValid: true,
      sanitizedData: data,
    );
  }
  
  factory ValidationResult.invalid(String error) {
    return ValidationResult(
      isValid: false,
      errorMessage: error,
    );
  }
}

/// Отчёт о валидации файла
class FileValidationReport {
  final String filePath;
  final int totalLines;
  final int validLines;
  final int invalidLines;
  final int emptyLines;
  final List<InvalidLineInfo> errors;
  final Duration processingTime;
  
  FileValidationReport({
    required this.filePath,
    required this.totalLines,
    required this.validLines,
    required this.invalidLines,
    required this.emptyLines,
    required this.errors,
    required this.processingTime,
  });
  
  bool get hasErrors => invalidLines > 0;
  double get successRate => totalLines > 0 ? validLines / totalLines : 0.0;
  
  Map<String, dynamic> toJson() {
    return {
      'file_path': filePath,
      'total_lines': totalLines,
      'valid_lines': validLines,
      'invalid_lines': invalidLines,
      'empty_lines': emptyLines,
      'success_rate': successRate,
      'processing_time_ms': processingTime.inMilliseconds,
      'errors': errors.map((e) => e.toJson()).toList(),
    };
  }
  
  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Validation Report for: $filePath');
    buffer.writeln('Total lines: $totalLines');
    buffer.writeln('Valid: $validLines, Invalid: $invalidLines, Empty: $emptyLines');
    buffer.writeln('Success rate: ${(successRate * 100).toStringAsFixed(2)}%');
    buffer.writeln('Processing time: ${processingTime.inMilliseconds}ms');
    
    if (hasErrors) {
      buffer.writeln('\nErrors:');
      for (final error in errors.take(10)) {
        buffer.writeln('  Line ${error.lineNumber}: ${error.errorMessage}');
        if (error.lineContent != null && error.lineContent!.length < 100) {
          buffer.writeln('    Content: ${error.lineContent}');
        }
      }
      if (errors.length > 10) {
        buffer.writeln('  ... and ${errors.length - 10} more errors');
      }
    }
    
    return buffer.toString();
  }
}

/// Информация об ошибке в строке
class InvalidLineInfo {
  final int lineNumber;
  final String errorMessage;
  final String? lineContent;
  
  InvalidLineInfo({
    required this.lineNumber,
    required this.errorMessage,
    this.lineContent,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'line_number': lineNumber,
      'error': errorMessage,
      if (lineContent != null) 'content': lineContent,
    };
  }
}

/// Типы валидируемых схем
enum SchemaType {
  dictionary,
  phrase,
  grammarRule,
  wordOrderRule,
  postProcessingRule,
}

/// Валидатор схем JSONL
class SchemaValidator {
  /// Список допустимых языковых пар
  static const List<String> allowedLanguagePairs = [
    'en-ru', 'ru-en',
    'en-es', 'es-en',
    'en-fr', 'fr-en',
    'en-de', 'de-en',
    'en-it', 'it-en',
    'en-pt', 'pt-en',
    'en-zh', 'zh-en',
    'en-ja', 'ja-en',
    'en-ko', 'ko-en',
  ];
  
  /// Regex для проверки формата языковой пары
  static final RegExp languagePairRegex = RegExp(r'^[a-z]{2}-[a-z]{2}$');
  
  /// Валидация записи словаря
  static ValidationResult validateDictionaryEntry(Map<String, dynamic> data) {
    try {
      // Обязательные поля
      if (!data.containsKey('source_word') || data['source_word'] == null) {
        return ValidationResult.invalid('Missing required field: source_word');
      }
      if (!data.containsKey('target_word') || data['target_word'] == null) {
        return ValidationResult.invalid('Missing required field: target_word');
      }
      if (!data.containsKey('language_pair') || data['language_pair'] == null) {
        return ValidationResult.invalid('Missing required field: language_pair');
      }
      
      final sourceWord = data['source_word'].toString().trim();
      final targetWord = data['target_word'].toString().trim();
      final languagePair = data['language_pair'].toString().trim().toLowerCase();
      
      // Проверка на пустоту
      if (sourceWord.isEmpty) {
        return ValidationResult.invalid('source_word cannot be empty');
      }
      if (targetWord.isEmpty) {
        return ValidationResult.invalid('target_word cannot be empty');
      }
      
      // Проверка формата языковой пары
      if (!languagePairRegex.hasMatch(languagePair)) {
        return ValidationResult.invalid('Invalid language_pair format: $languagePair (expected: xx-xx)');
      }
      
      // Проверка допустимых пар (опционально, можно отключить)
      // if (!allowedLanguagePairs.contains(languagePair)) {
      //   return ValidationResult.invalid('Unsupported language_pair: $languagePair');
      // }
      
      // Проверка типов и диапазонов
      if (data.containsKey('frequency') && data['frequency'] != null) {
        final frequency = data['frequency'];
        if (frequency is! int || frequency < 0) {
          return ValidationResult.invalid('frequency must be a non-negative integer');
        }
      }
      
      if (data.containsKey('confidence') && data['confidence'] != null) {
        final confidence = data['confidence'];
        if (confidence is! int || confidence < 0 || confidence > 100) {
          return ValidationResult.invalid('confidence must be an integer between 0 and 100');
        }
      }
      
      // Проверка временных меток
      if (data.containsKey('created_at') && data['created_at'] != null) {
        if (data['created_at'] is! int) {
          return ValidationResult.invalid('created_at must be an integer timestamp');
        }
      }
      if (data.containsKey('updated_at') && data['updated_at'] != null) {
        if (data['updated_at'] is! int) {
          return ValidationResult.invalid('updated_at must be an integer timestamp');
        }
      }
      
      return ValidationResult.valid(data);
      
    } catch (e) {
      return ValidationResult.invalid('Validation error: $e');
    }
  }
  
  /// Валидация записи фразы
  static ValidationResult validatePhraseEntry(Map<String, dynamic> data) {
    try {
      // Обязательные поля
      if (!data.containsKey('source_phrase') || data['source_phrase'] == null) {
        return ValidationResult.invalid('Missing required field: source_phrase');
      }
      if (!data.containsKey('target_phrase') || data['target_phrase'] == null) {
        return ValidationResult.invalid('Missing required field: target_phrase');
      }
      if (!data.containsKey('language_pair') || data['language_pair'] == null) {
        return ValidationResult.invalid('Missing required field: language_pair');
      }
      
      final sourcePhrase = data['source_phrase'].toString().trim();
      final targetPhrase = data['target_phrase'].toString().trim();
      final languagePair = data['language_pair'].toString().trim().toLowerCase();
      
      // Проверка на пустоту
      if (sourcePhrase.isEmpty) {
        return ValidationResult.invalid('source_phrase cannot be empty');
      }
      if (targetPhrase.isEmpty) {
        return ValidationResult.invalid('target_phrase cannot be empty');
      }
      
      // Проверка формата языковой пары
      if (!languagePairRegex.hasMatch(languagePair)) {
        return ValidationResult.invalid('Invalid language_pair format: $languagePair (expected: xx-xx)');
      }
      
      // Проверка confidence
      if (data.containsKey('confidence') && data['confidence'] != null) {
        final confidence = data['confidence'];
        if (confidence is! int || confidence < 0 || confidence > 100) {
          return ValidationResult.invalid('confidence must be an integer between 0 and 100');
        }
      }
      
      // Проверка frequency
      if (data.containsKey('frequency') && data['frequency'] != null) {
        final frequency = data['frequency'];
        if (frequency is! int || frequency < 0) {
          return ValidationResult.invalid('frequency must be a non-negative integer');
        }
      }
      
      // Проверка временных меток
      if (data.containsKey('created_at') && data['created_at'] != null) {
        if (data['created_at'] is! int) {
          return ValidationResult.invalid('created_at must be an integer timestamp');
        }
      }
      if (data.containsKey('updated_at') && data['updated_at'] != null) {
        if (data['updated_at'] is! int) {
          return ValidationResult.invalid('updated_at must be an integer timestamp');
        }
      }
      
      return ValidationResult.valid(data);
      
    } catch (e) {
      return ValidationResult.invalid('Validation error: $e');
    }
  }
  
  /// Валидация грамматического правила
  static ValidationResult validateGrammarRule(Map<String, dynamic> data) {
    try {
      // Обязательные поля
      if (!data.containsKey('language_pair') || data['language_pair'] == null) {
        return ValidationResult.invalid('Missing required field: language_pair');
      }
      if (!data.containsKey('pattern') || data['pattern'] == null) {
        return ValidationResult.invalid('Missing required field: pattern');
      }
      if (!data.containsKey('replacement') || data['replacement'] == null) {
        return ValidationResult.invalid('Missing required field: replacement');
      }
      
      final languagePair = data['language_pair'].toString().trim().toLowerCase();
      
      // Проверка формата языковой пары
      if (!languagePairRegex.hasMatch(languagePair)) {
        return ValidationResult.invalid('Invalid language_pair format: $languagePair');
      }
      
      // Проверка pattern (должен быть валидным regex)
      try {
        RegExp(data['pattern'].toString());
      } catch (e) {
        return ValidationResult.invalid('Invalid regex pattern: $e');
      }
      
      // Проверка priority
      if (data.containsKey('priority') && data['priority'] != null) {
        if (data['priority'] is! int) {
          return ValidationResult.invalid('priority must be an integer');
        }
      }
      
      return ValidationResult.valid(data);
      
    } catch (e) {
      return ValidationResult.invalid('Validation error: $e');
    }
  }
  
  /// Валидация JSONL файла построчно
  static FileValidationReport validateJsonlFile({
    required String content,
    required String filePath,
    required SchemaType schemaType,
    bool quarantineInvalid = true,
  }) {
    final stopwatch = Stopwatch()..start();
    
    final lines = content.split('\n');
    var validLines = 0;
    var invalidLines = 0;
    var emptyLines = 0;
    final errors = <InvalidLineInfo>[];
    
    for (var i = 0; i < lines.length; i++) {
      final lineNumber = i + 1;
      final line = lines[i].trim();
      
      if (line.isEmpty) {
        emptyLines++;
        continue;
      }
      
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        
        // Выбор валидатора по типу схемы
        ValidationResult result;
        switch (schemaType) {
          case SchemaType.dictionary:
            result = validateDictionaryEntry(json);
            break;
          case SchemaType.phrase:
            result = validatePhraseEntry(json);
            break;
          case SchemaType.grammarRule:
            result = validateGrammarRule(json);
            break;
          case SchemaType.wordOrderRule:
          case SchemaType.postProcessingRule:
            // Аналогично grammarRule
            result = validateGrammarRule(json);
            break;
        }
        
        if (result.isValid) {
          validLines++;
        } else {
          invalidLines++;
          errors.add(InvalidLineInfo(
            lineNumber: lineNumber,
            errorMessage: result.errorMessage ?? 'Unknown validation error',
            lineContent: quarantineInvalid ? line : null,
          ));
        }
        
      } catch (e) {
        invalidLines++;
        errors.add(InvalidLineInfo(
          lineNumber: lineNumber,
          errorMessage: 'JSON parse error: $e',
          lineContent: quarantineInvalid ? line : null,
        ));
      }
    }
    
    stopwatch.stop();
    
    return FileValidationReport(
      filePath: filePath,
      totalLines: lines.length,
      validLines: validLines,
      invalidLines: invalidLines,
      emptyLines: emptyLines,
      errors: errors,
      processingTime: stopwatch.elapsed,
    );
  }
  
  /// Быстрая проверка одной строки JSONL
  static bool isValidJsonlLine(String line, SchemaType schemaType) {
    if (line.trim().isEmpty) return true; // Пустые строки допустимы
    
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      ValidationResult result;
      
      switch (schemaType) {
        case SchemaType.dictionary:
          result = validateDictionaryEntry(json);
          break;
        case SchemaType.phrase:
          result = validatePhraseEntry(json);
          break;
        case SchemaType.grammarRule:
        case SchemaType.wordOrderRule:
        case SchemaType.postProcessingRule:
          result = validateGrammarRule(json);
          break;
      }
      
      return result.isValid;
    } catch (e) {
      return false;
    }
  }
}
