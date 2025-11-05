import '../core/translation_context.dart';
import '../models/layer_debug_info.dart';
import '../utils/debug_logger.dart';
import 'base_translation_layer.dart';
import '../data/post_processing_rules_repository.dart';

/// Represents a post-processing rule
class PostProcessingRule {
  final String ruleId;
  final String description;
  final RegExp pattern;
  final String replacement;
  final int priority;
  final List<String> targetLanguages;
  final bool isGlobal;

  const PostProcessingRule({
    required this.ruleId,
    required this.description,
    required this.pattern,
    required this.replacement,
    this.priority = 1,
    this.targetLanguages = const [],
    this.isGlobal = true,
  });

  bool appliesTo(String targetLanguage) {
    return isGlobal || targetLanguages.isEmpty || targetLanguages.contains(targetLanguage);
  }
}

/// Represents formatting preferences for different languages
class LanguageFormattingRules {
  final String language;
  final bool useDoubleSpacesAfterSentences;
  final String quotationMarkOpen;
  final String quotationMarkClose;
  final List<String> sentenceEnders;
  final bool capitalizeFirstWordAfterColon;
  final bool spaceBetweenSentences;
  final Map<String, String> punctuationRules;

  const LanguageFormattingRules({
    required this.language,
    this.useDoubleSpacesAfterSentences = false,
    this.quotationMarkOpen = '"',
    this.quotationMarkClose = '"',
    this.sentenceEnders = const ['.', '!', '?'],
    this.capitalizeFirstWordAfterColon = false,
    this.spaceBetweenSentences = true,
    this.punctuationRules = const {},
  });
}

/// Quality metrics for post-processed text
class TextQualityMetrics {
  final int characterCount;
  final int wordCount;
  final int sentenceCount;
  final double averageWordsPerSentence;
  final bool hasProperCapitalization;
  final bool hasCorrectPunctuation;
  final int correctedErrors;
  final double qualityScore;

  const TextQualityMetrics({
    required this.characterCount,
    required this.wordCount,
    required this.sentenceCount,
    required this.averageWordsPerSentence,
    required this.hasProperCapitalization,
    required this.hasCorrectPunctuation,
    required this.correctedErrors,
    required this.qualityScore,
  });

  Map<String, dynamic> toMap() {
    return {
      'character_count': characterCount,
      'word_count': wordCount,
      'sentence_count': sentenceCount,
      'average_words_per_sentence': averageWordsPerSentence,
      'proper_capitalization': hasProperCapitalization,
      'correct_punctuation': hasCorrectPunctuation,
      'corrected_errors': correctedErrors,
      'quality_score': qualityScore,
    };
  }
}

/// Post-processing layer that performs final text formatting and cleanup
class PostProcessingLayer extends BaseTranslationLayer {
  static const String layerName = 'PostProcessingLayer';
  static const int layerPriority = 500;
  
  final List<PostProcessingRule> _postProcessingRules;
  final Map<String, LanguageFormattingRules> _languageRules;
  final DebugLogger _logger;
  final bool _enableQualityCheck;

  final PostProcessingRulesRepository? _rulesRepository;
  
  // Опции для отключения шагов
  final bool enableSpacingFix;
  final bool enableCapitalizationFix;
  final bool enablePunctuationFix;
  final bool enableLanguageFormatting;
  final bool enableRulesApplication;
  final bool enableFinalCleanup;
  final bool addMissingPeriods; // Добавлять ли точки в конце предложений

  PostProcessingLayer({
    List<PostProcessingRule>? postProcessingRules,
    Map<String, LanguageFormattingRules>? languageRules,
    DebugLogger? logger,
    bool enableQualityCheck = true,
    PostProcessingRulesRepository? postProcessingRepository,
    this.enableSpacingFix = true,
    this.enableCapitalizationFix = true,
    this.enablePunctuationFix = true,
    this.enableLanguageFormatting = true,
    this.enableRulesApplication = true,
    this.enableFinalCleanup = true,
    this.addMissingPeriods = false, // По умолчанию НЕ добавляем
  }) : _postProcessingRules = postProcessingRules ?? _getDefaultPostProcessingRules(),
       _languageRules = languageRules ?? _getDefaultLanguageFormattingRules(),
       _logger = logger ?? DebugLogger.instance,
       _enableQualityCheck = enableQualityCheck,
       _rulesRepository = postProcessingRepository;

  @override
  String get name => layerName;

  @override
  String get description => 'Post-processing layer: final text formatting, capitalization, punctuation, and quality assessment';

  @override
  LayerPriority get priority => LayerPriority.postProcessing;

  @override
  bool canHandle(String text, TranslationContext context) {
    // Post-processing layer should process all translations
    return context.translatedText != null && context.translatedText!.isNotEmpty;
  }

  @override
  Future<LayerResult> process(String text, TranslationContext context) async {
    final stopwatch = Stopwatch()..start();
    final startTime = DateTime.now();

    try {
      _logger.debug('$name: Starting post-processing');
      
      // Get current translation
      String currentText = context.translatedText ?? text;
      if (currentText.isEmpty) {
        return _createResult(text, false, stopwatch, startTime, 'No text to post-process');
      }

      final targetLanguage = context.targetLanguage;
      String processedText = currentText;
      bool hasChanges = false;
      int correctionCount = 0;
      final appliedRules = <String>[];
      
      // Step 1: Fix spacing issues
      if (enableSpacingFix) {
        final spacingResult = _fixSpacing(processedText);
        if (spacingResult != processedText) {
          processedText = spacingResult;
          hasChanges = true;
          correctionCount++;
          _logger.debug('$name: Fixed spacing issues');
        }
      }
      
      // Step 2: Fix capitalization
      if (enableCapitalizationFix) {
        final capitalizationResult = _fixCapitalization(processedText, targetLanguage);
        if (capitalizationResult != processedText) {
          processedText = capitalizationResult;
          hasChanges = true;
          correctionCount++;
          _logger.debug('$name: Fixed capitalization');
        }
      }
      
      // Step 3: Fix punctuation
      if (enablePunctuationFix) {
        final punctuationResult = _fixPunctuation(processedText, targetLanguage);
        if (punctuationResult != processedText) {
          processedText = punctuationResult;
          hasChanges = true;
          correctionCount++;
          _logger.debug('$name: Fixed punctuation');
        }
      }
      
      // Step 4: Apply language-specific formatting
      if (enableLanguageFormatting) {
        final formattingResult = _applyLanguageFormatting(processedText, targetLanguage);
        if (formattingResult != processedText) {
          processedText = formattingResult;
          hasChanges = true;
          correctionCount++;
          _logger.debug('$name: Applied language-specific formatting');
        }
      }
      
      // Step 5: Apply post-processing rules
      if (enableRulesApplication) {
        final applicableRules = await _getApplicableRules(targetLanguage);
        applicableRules.sort((a, b) => b.priority.compareTo(a.priority));
        
        for (final rule in applicableRules) {
          final beforeText = processedText;
          processedText = _applyPostProcessingRule(rule, processedText);
          
          if (processedText != beforeText) {
            hasChanges = true;
            correctionCount++;
            appliedRules.add(rule.ruleId);
            _logger.debug('$name: Applied rule ${rule.ruleId}: "${rule.description}"');
          }
        }
      }
      
      // Step 6: Final cleanup
      final cleanupResult = _performFinalCleanup(processedText);
      if (cleanupResult != processedText) {
        processedText = cleanupResult;
        hasChanges = true;
        correctionCount++;
        _logger.debug('$name: Performed final cleanup');
      }
      
      // Step 7: Quality assessment
      TextQualityMetrics? qualityMetrics;
      if (_enableQualityCheck) {
        qualityMetrics = _assessTextQuality(processedText, targetLanguage, correctionCount);
      }
      
      // Update context with processed text
      if (hasChanges) {
        context.translatedText = processedText;
      }

      _logger.debug('$name: Post-processing completed. Made $correctionCount corrections');
      
      return _createResult(
        processedText,
        true,
        stopwatch,
        startTime,
        null,
        {
          'applied_rules': appliedRules,
          'corrections_made': correctionCount,
          'text_changed': hasChanges,
          'original_length': currentText.length,
          'processed_length': processedText.length,
          'quality_metrics': qualityMetrics?.toMap(),
        },
      );
      
    } catch (e, stackTrace) {
      _logger.error('$name: Post-processing failed', error: e, stackTrace: stackTrace);
      return _createResult(
        text,
        false,
        stopwatch,
        startTime,
        'Post-processing error: $e'
      );
    }
  }

  /// Fixes spacing issues in the text
  String _fixSpacing(String text) {
    String result = text;
    
    // Remove multiple spaces
    result = result.replaceAll(RegExp(r'\s{2,}'), ' ');
    
    // Fix spacing around punctuation
    result = result.replaceAll(RegExp(r'\s+([,.!?;:])'), r'\1');
    result = result.replaceAll(RegExp(r'([,.!?;:])([a-zA-Z])'), r'\1 \2');
    
    // Fix spacing around parentheses
    result = result.replaceAll(RegExp(r'\(\s+'), '(');
    result = result.replaceAll(RegExp(r'\s+\)'), ')');
    result = result.replaceAll(RegExp(r'\)([a-zA-Z])'), r') \1');
    result = result.replaceAll(RegExp(r'([a-zA-Z])\('), r'\1 (');
    
    // Fix spacing around quotes
    result = result.replaceAll(RegExp(r'"\s+'), '"');
    result = result.replaceAll(RegExp(r'\s+"'), '"');
    
    // Trim leading and trailing whitespace
    result = result.trim();
    
    return result;
  }

  /// Fixes capitalization issues
  String _fixCapitalization(String text, String targetLanguage) {
    if (text.isEmpty) return text;
    
    String result = text;
    final sentences = _splitIntoSentences(result);
    final processedSentences = <String>[];
    
    for (String sentence in sentences) {
      String processed = sentence.trim();
      
      if (processed.isNotEmpty) {
        // Capitalize first letter of sentence
        processed = processed[0].toUpperCase() + processed.substring(1);
        
        // Apply language-specific capitalization rules
        processed = _applyLanguageSpecificCapitalization(processed, targetLanguage);
      }
      
      processedSentences.add(processed);
    }
    
    return processedSentences.join(' ');
  }

  /// Applies language-specific capitalization rules
  String _applyLanguageSpecificCapitalization(String text, String targetLanguage) {
    String result = text;
    
    // English: Capitalize proper nouns, "I", etc.
    if (targetLanguage == 'en') {
      result = result.replaceAllMapped(RegExp(r'\bi\b'), (match) => 'I');
    }
    
    // German: Capitalize all nouns (simplified detection)
    if (targetLanguage == 'de') {
      // This is a simplified approach - in real implementation, 
      // you'd use proper NLP to identify nouns
      final words = result.split(' ');
      for (int i = 1; i < words.length; i++) {
        if (words[i].length > 3 && !_isCommonWord(words[i], targetLanguage)) {
          words[i] = words[i][0].toUpperCase() + words[i].substring(1);
        }
      }
      result = words.join(' ');
    }
    
    return result;
  }

  /// Fixes punctuation issues
  String _fixPunctuation(String text, String targetLanguage) {
    String result = text;
    
    // Ensure sentences end with proper punctuation
    final sentences = _splitIntoSentences(result, false);
    final processedSentences = <String>[];
    
    for (String sentence in sentences) {
      String processed = sentence.trim();
      
      if (addMissingPeriods && processed.isNotEmpty && !RegExp(r'[.!?]$').hasMatch(processed)) {
        // Add period if no ending punctuation (only if enabled)
        processed += '.';
      }
      
      processedSentences.add(processed);
    }
    
    result = processedSentences.join(' ');
    
    // Apply language-specific punctuation rules
    final languageRules = _languageRules[targetLanguage];
    if (languageRules != null) {
      for (final entry in languageRules.punctuationRules.entries) {
        result = result.replaceAll(entry.key, entry.value);
      }
    }
    
    return result;
  }

  /// Applies language-specific formatting rules
  Future<List<PostProcessingRule>> _getApplicableRules(String targetLanguage) async {
    // Prefer external rules if provided
    if (_rulesRepository != null) {
      final dtos = await _rulesRepository.getRules(targetLanguage);
      if (dtos.isNotEmpty) {
        final rules = dtos.map((d) => PostProcessingRule(
          ruleId: d.ruleId,
          description: d.description,
          pattern: RegExp(d.pattern, caseSensitive: d.caseSensitive),
          replacement: d.replacement,
          priority: d.priority,
          targetLanguages: d.targetLanguages,
          isGlobal: d.isGlobal,
        )).toList();
        return rules.where((r) => r.appliesTo(targetLanguage)).toList();
      }
    }
    return _postProcessingRules.where((r) => r.appliesTo(targetLanguage)).toList();
  }

  String _applyLanguageFormatting(String text, String targetLanguage) {
    final languageRules = _languageRules[targetLanguage];
    if (languageRules == null) return text;
    
    String result = text;
    
    // Apply quotation mark preferences
    if (languageRules.quotationMarkOpen != '"' || languageRules.quotationMarkClose != '"') {
      result = result.replaceAllMapped(
        RegExp(r'"([^"]+)"'),
        (match) => '${languageRules.quotationMarkOpen}${match.group(1)}${languageRules.quotationMarkClose}',
      );
    }
    
    // Apply sentence spacing preferences
    if (languageRules.useDoubleSpacesAfterSentences) {
      for (final ender in languageRules.sentenceEnders) {
        result = result.replaceAll('$ender ', '$ender  ');
      }
    }
    
    return result;
  }

  /// Performs final text cleanup
  String _performFinalCleanup(String text) {
    String result = text;
    
    // Remove trailing punctuation duplicates
    result = result.replaceAll(RegExp(r'\.{2,}'), '.');
    result = result.replaceAll(RegExp(r'!{2,}'), '!');
    result = result.replaceAll(RegExp(r'\?{2,}'), '?');
    
    // Ensure proper spacing after punctuation
    result = result.replaceAll(RegExp(r'([.!?])([A-Z])'), r'\1 \2');
    
    // Remove any remaining multiple spaces
    result = result.replaceAll(RegExp(r'\s{2,}'), ' ');
    
    // Final trim
    result = result.trim();
    
    return result;
  }

  /// Assesses the quality of the processed text
  TextQualityMetrics _assessTextQuality(String text, String targetLanguage, int correctionsMade) {
    final characterCount = text.length;
    final words = text.split(RegExp(r'\s+'));
    final wordCount = words.length;
    final sentences = _splitIntoSentences(text);
    final sentenceCount = sentences.length;
    
    final averageWordsPerSentence = sentenceCount > 0 ? wordCount / sentenceCount : 0.0;
    
    // Check capitalization
    final hasProperCapitalization = _checkCapitalization(text);
    
    // Check punctuation
    final hasCorrectPunctuation = _checkPunctuation(text);
    
    // Calculate quality score (0.0 to 1.0)
    double qualityScore = 1.0;
    
    if (!hasProperCapitalization) qualityScore -= 0.1;
    if (!hasCorrectPunctuation) qualityScore -= 0.1;
    if (correctionsMade > 5) qualityScore -= 0.1;
    if (averageWordsPerSentence > 30) qualityScore -= 0.1; // Too long sentences
    if (averageWordsPerSentence < 3) qualityScore -= 0.1;  // Too short sentences
    
    qualityScore = (qualityScore * 100).clamp(0, 100) / 100;
    
    return TextQualityMetrics(
      characterCount: characterCount,
      wordCount: wordCount,
      sentenceCount: sentenceCount,
      averageWordsPerSentence: averageWordsPerSentence,
      hasProperCapitalization: hasProperCapitalization,
      hasCorrectPunctuation: hasCorrectPunctuation,
      correctedErrors: correctionsMade,
      qualityScore: qualityScore,
    );
  }

  /// Checks if text has proper capitalization
  bool _checkCapitalization(String text) {
    final sentences = _splitIntoSentences(text);
    
    for (final sentence in sentences) {
      if (sentence.trim().isNotEmpty) {
        final firstChar = sentence.trim()[0];
        if (firstChar != firstChar.toUpperCase()) {
          return false;
        }
      }
    }
    
    return true;
  }

  /// Checks if text has correct punctuation
  bool _checkPunctuation(String text) {
    final sentences = _splitIntoSentences(text, false);
    
    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      if (trimmed.isNotEmpty && !RegExp(r'[.!?]$').hasMatch(trimmed)) {
        return false;
      }
    }
    
    return true;
  }

  /// Splits text into sentences
  List<String> _splitIntoSentences(String text, [bool preservePunctuation = true]) {
    final sentences = <String>[];
    final pattern = preservePunctuation 
        ? RegExp(r'([.!?])\s+') 
        : RegExp(r'[.!?]\s*');
    
    int lastEnd = 0;
    for (final match in pattern.allMatches(text)) {
      final sentence = text.substring(lastEnd, preservePunctuation ? match.end : match.start + 1);
      sentences.add(sentence);
      lastEnd = match.end;
    }
    
    // Add remaining text
    if (lastEnd < text.length) {
      sentences.add(text.substring(lastEnd));
    }
    
    return sentences.where((s) => s.trim().isNotEmpty).toList();
  }

  /// Checks if a word is a common word that shouldn't be capitalized
  bool _isCommonWord(String word, String language) {
    final commonWords = {
      'en': ['the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by'],
      'de': ['der', 'die', 'das', 'und', 'oder', 'aber', 'in', 'an', 'auf', 'zu', 'für', 'von', 'mit', 'bei'],
      'es': ['el', 'la', 'los', 'las', 'y', 'o', 'pero', 'en', 'a', 'de', 'con', 'por', 'para'],
      'fr': ['le', 'la', 'les', 'et', 'ou', 'mais', 'dans', 'à', 'de', 'avec', 'par', 'pour'],
    };
    
    return commonWords[language]?.contains(word.toLowerCase()) ?? false;
  }

  /// Applies a specific post-processing rule
  String _applyPostProcessingRule(PostProcessingRule rule, String text) {
    try {
      return text.replaceAllMapped(rule.pattern, (match) {
        return _expandBackreferences(rule.replacement, match);
      });
    } catch (e) {
      _logger.warning('$name: Failed to apply rule ${rule.ruleId}: $e');
      return text;
    }
  }

  String _expandBackreferences(String template, Match match) {
    String out = template;
    out = out.replaceAllMapped(RegExp(r'\$(\d+)'), (m) {
      final idx = int.tryParse(m.group(1) ?? '') ?? -1;
      return idx >= 0 && idx <= match.groupCount ? (match.group(idx) ?? '') : '';
    });
    out = out.replaceAllMapped(RegExp(r'\\\$(\d+)'), (m) {
      final idx = int.tryParse(m.group(1) ?? '') ?? -1;
      return idx >= 0 && idx <= match.groupCount ? (match.group(idx) ?? '') : '';
    });
    out = out.replaceAllMapped(RegExp(r'\$\{(\d+)\}'), (m) {
      final idx = int.tryParse(m.group(1) ?? '') ?? -1;
      return idx >= 0 && idx <= match.groupCount ? (match.group(idx) ?? '') : '';
    });
    return out;
  }

  /// Creates a layer result with debug information
  LayerResult _createResult(
    String processedText,
    bool success, 
    Stopwatch stopwatch, 
    DateTime startTime,
    [String? error,
    Map<String, dynamic>? additionalInfo]
  ) {
    stopwatch.stop();
    
    final debugInfo = LayerDebugInfo(
      layerName: name,
      processingTimeMs: stopwatch.elapsedMilliseconds,
      isSuccessful: success,
      hasError: error != null,
      errorMessage: error,
      additionalInfo: additionalInfo ?? {},
    );

    if (success) {
      return LayerResult.success(
        processedText: processedText,
        debugInfo: debugInfo,
      );
    } else {
      return LayerResult.error(
        originalText: processedText,
        errorMessage: error ?? 'Unknown error',
        debugInfo: debugInfo,
      );
    }
  }

  /// Provides default post-processing rules
  static List<PostProcessingRule> _getDefaultPostProcessingRules() {
    return [
      // Remove excessive punctuation
      PostProcessingRule(
        ruleId: 'remove_excessive_punctuation',
        description: 'Remove excessive repeated punctuation',
        pattern: RegExp(r'[.!?]{3,}'),
        replacement: '...',
        priority: 1,
      ),
      
      // Fix common contractions
      PostProcessingRule(
        ruleId: 'fix_contractions',
        description: 'Fix spacing in contractions',
        pattern: RegExp(r"(\w)\s+'\s*(\w)"),
        replacement: r"\1'\2",
        priority: 2,
        targetLanguages: ['en'],
      ),
      
      // Fix number formatting
      PostProcessingRule(
        ruleId: 'fix_number_spacing',
        description: 'Fix spacing around numbers',
        pattern: RegExp(r'(\d)\s+(\d)'),
        replacement: r'$1$2',
        priority: 1,
      ),
      
      // Fix hyphenated words
      PostProcessingRule(
        ruleId: 'fix_hyphenated_words',
        description: 'Fix spacing in hyphenated words',
        pattern: RegExp(r'(\w)\s+-\s+(\w)'),
        replacement: r'$1-$2',
        priority: 2,
      ),
    ];
  }

  /// Provides default language formatting rules
  static Map<String, LanguageFormattingRules> _getDefaultLanguageFormattingRules() {
    return {
      'en': const LanguageFormattingRules(
        language: 'en',
        quotationMarkOpen: '"',
        quotationMarkClose: '"',
        sentenceEnders: ['.', '!', '?'],
      ),
      'es': const LanguageFormattingRules(
        language: 'es',
        quotationMarkOpen: '«',
        quotationMarkClose: '»',
        sentenceEnders: ['.', '!', '?', '¿', '¡'],
      ),
      'fr': const LanguageFormattingRules(
        language: 'fr',
        quotationMarkOpen: '« ',  // Французские кавычки с пробелом
        quotationMarkClose: ' »',
        sentenceEnders: ['.', '!', '?'],
        punctuationRules: {
          ' :': '\u00A0:', // Non-breaking space before colon
          ' ;': '\u00A0;', // Non-breaking space before semicolon
          ' !': '\u00A0!', // Non-breaking space before exclamation
          ' ?': '\u00A0?', // Non-breaking space before question mark
        },
      ),
      'ru': const LanguageFormattingRules(
        language: 'ru',
        quotationMarkOpen: '«',
        quotationMarkClose: '»',
        sentenceEnders: ['.', '!', '?'],
        punctuationRules: {}, // Русский без неразрывных пробелов
      ),
      'de': const LanguageFormattingRules(
        language: 'de',
        quotationMarkOpen: '„',
        quotationMarkClose: '"',
        sentenceEnders: ['.', '!', '?'],
      ),
    };
  }
}