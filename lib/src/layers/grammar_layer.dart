import '../core/translation_context.dart';
import '../models/layer_debug_info.dart';
import '../utils/debug_logger.dart';
import 'base_translation_layer.dart';
import '../data/grammar_rules_repository.dart';

/// Grammar rules for specific language pairs
class GrammarRule {
  final String ruleId;
  final String sourceLanguage;
  final String targetLanguage;
  final String description;
  final RegExp pattern;
  final String replacement;
  final int priority;
  final List<String> conditions;

  const GrammarRule({
    required this.ruleId,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.description,
    required this.pattern,
    required this.replacement,
    this.priority = 1,
    this.conditions = const [],
  });

  bool appliesTo(String sourceLanguage, String targetLanguage) {
    final srcOk = this.sourceLanguage == 'any' || this.sourceLanguage == sourceLanguage;
    final tgtOk = this.targetLanguage == 'any' || this.targetLanguage == targetLanguage;
    return srcOk && tgtOk;
  }

  bool matchesConditions(TranslationContext context) {
    if (conditions.isEmpty) return true;
    
    for (final condition in conditions) {
      // Simple condition matching - can be extended
      if (condition.startsWith('has_token:')) {
        final token = condition.substring('has_token:'.length);
        if (context.tokens?.any((t) => t.toLowerCase().contains(token.toLowerCase())) != true) {
          return false;
        }
      }
    }
    return true;
  }
}

/// Represents a verb conjugation pattern
class VerbConjugation {
  final String infinitive;
  final String language;
  final Map<String, String> forms;
  final bool isIrregular;

  const VerbConjugation({
    required this.infinitive,
    required this.language,
    required this.forms,
    this.isIrregular = false,
  });

  String? getForm(String tense, String person, String number) {
    final key = '${tense}_${person}_$number';
    return forms[key];
  }
}

/// Represents grammatical agreement between words
class GrammaticalAgreement {
  final String word;
  final String partOfSpeech;
  final String gender;
  final String number;
  final String case_;
  final String tense;
  
  const GrammaticalAgreement({
    required this.word,
    required this.partOfSpeech,
    this.gender = 'unknown',
    this.number = 'unknown', 
    this.case_ = 'unknown',
    this.tense = 'unknown',
  });
}

/// Grammar layer that applies language-specific grammatical rules
class GrammarLayer extends BaseTranslationLayer {
  static const String layerName = 'GrammarLayer';
  static const int layerPriority = 300;
  
  final List<GrammarRule> _grammarRules;
  final Map<String, List<VerbConjugation>> _verbConjugations;
  final DebugLogger _logger;

  final GrammarRulesRepository? _rulesRepository;

  GrammarLayer({
    List<GrammarRule>? grammarRules,
    Map<String, List<VerbConjugation>>? verbConjugations,
    DebugLogger? logger,
    GrammarRulesRepository? grammarRulesRepository,
  }) : _grammarRules = grammarRules ?? _getDefaultGrammarRules(),
       _verbConjugations = verbConjugations ?? {},
       _logger = logger ?? DebugLogger.instance,
       _rulesRepository = grammarRulesRepository;

  @override
  String get name => layerName;

  @override
  String get description => 'Grammar correction layer: applies language rules, verb conjugation, and grammatical agreement';

  @override
  LayerPriority get priority => LayerPriority.grammar;

  /// Resolve rules: external repository overrides defaults if available
  Future<List<GrammarRule>> _resolveRules(TranslationContext context) async {
    if (_rulesRepository != null) {
      final dtos = await _rulesRepository.getRules(context.languagePair);
      if (dtos.isNotEmpty) {
        return dtos.map((d) => GrammarRule(
          ruleId: d.ruleId,
          sourceLanguage: d.sourceLanguage,
          targetLanguage: d.targetLanguage,
          description: d.description,
          pattern: RegExp(d.pattern, caseSensitive: d.caseSensitive),
          replacement: d.replacement,
          priority: d.priority,
          conditions: d.conditions,
        )).toList();
      }
    }
    return _grammarRules;
  }

  @override
  bool canHandle(String text, TranslationContext context) {
    // Grammar layer should process all translations that have tokens
    return context.tokens != null && context.tokens!.isNotEmpty;
  }

  @override
  Future<LayerResult> process(String text, TranslationContext context) async {
    final stopwatch = Stopwatch()..start();
    final startTime = DateTime.now();

    try {
      _logger.debug('$name: Starting grammar processing');
      
      // Get current translation - prefer translated text from context, fallback to input text
      String currentTranslation = context.translatedText ?? text;
      if (currentTranslation.isEmpty) {
        return _createResult(text, false, stopwatch, startTime, 'No text to process');
      }

      String processedText = currentTranslation;
      bool hasChanges = false;
      final appliedRules = <String>[];

      // Apply grammar rules in priority order
      final allRules = await _resolveRules(context);
      final applicableRules = _getApplicableRules(context, allRules);
      applicableRules.sort((a, b) => b.priority.compareTo(a.priority));

      for (final rule in applicableRules) {
        final beforeText = processedText;
        processedText = _applyGrammarRule(rule, processedText, context);
        
        if (processedText != beforeText) {
          hasChanges = true;
          appliedRules.add(rule.ruleId);
          _logger.debug('$name: Applied rule ${rule.ruleId}: "${rule.description}"');
        }
      }

      // Perform verb conjugation
      final conjugationResult = await _performVerbConjugation(
        processedText, 
        context.sourceLanguage, 
        context.targetLanguage,
        context
      );
      
      if (conjugationResult != processedText) {
        processedText = conjugationResult;
        hasChanges = true;
      }

      // Apply grammatical agreements (gender, number, case)
      final agreementResult = _applyGrammaticalAgreements(processedText, context);
      if (agreementResult != processedText) {
        processedText = agreementResult;
        hasChanges = true;
      }

      // Update context with processed text
      if (hasChanges) {
        context.translatedText = processedText;
      }

      _logger.debug('$name: Grammar processing completed. Applied ${appliedRules.length} rules');
      
      return _createResult(
        processedText,
        true,
        stopwatch,
        startTime,
        null,
        {
          'applied_rules': appliedRules,
          'rules_count': applicableRules.length,
          'text_changed': hasChanges,
          'original_length': currentTranslation.length,
          'processed_length': processedText.length,
        },
      );
      
    } catch (e, stackTrace) {
      _logger.error('$name: Grammar processing failed', error: e, stackTrace: stackTrace);
      return _createResult(
        text, 
        false, 
        stopwatch, 
        startTime, 
        'Grammar processing error: $e'
      );
    }
  }

  /// Gets grammar rules applicable to the current translation context
  List<GrammarRule> _getApplicableRules(TranslationContext context, List<GrammarRule> rules) {
    final sourceLanguage = context.sourceLanguage;
    final targetLanguage = context.targetLanguage;
    
    return rules.where((rule) {
      return rule.appliesTo(sourceLanguage, targetLanguage) && 
             rule.matchesConditions(context);
    }).toList();
  }

  /// Applies a specific grammar rule to the text
  String _applyGrammarRule(GrammarRule rule, String text, TranslationContext context) {
    try {
      return text.replaceAllMapped(rule.pattern, (match) {
        String replacement = rule.replacement;
        
        // Replace placeholders in replacement string
        for (int i = 0; i <= match.groupCount; i++) {
          final group = match.group(i);
          if (group != null) {
            replacement = replacement.replaceAll('\\$i', group);
          }
        }
        
        return replacement;
      });
    } catch (e) {
      _logger.warning('$name: Failed to apply rule ${rule.ruleId}: $e');
      return text;
    }
  }

  /// Performs verb conjugation based on language rules
  Future<String> _performVerbConjugation(
    String text, 
    String sourceLanguage, 
    String targetLanguage,
    TranslationContext context
  ) async {
    final conjugations = _verbConjugations[targetLanguage];
    if (conjugations == null || conjugations.isEmpty) {
      return text;
    }

    final words = text.split(' ');
    
    for (int i = 0; i < words.length; i++) {
      final word = words[i].toLowerCase();
      
      // Find matching verb conjugation
      final conjugation = conjugations.firstWhere(
        (c) => c.infinitive.toLowerCase() == word || c.forms.values.contains(word),
        orElse: () => const VerbConjugation(infinitive: '', language: '', forms: {}),
      );
      
      if (conjugation.infinitive.isNotEmpty) {
        // Apply conjugation based on context (simplified logic)
        final conjugatedForm = _getConjugatedForm(conjugation, context, i, words);
        if (conjugatedForm != null && conjugatedForm != word) {
          words[i] = _preserveCapitalization(words[i], conjugatedForm);
        }
      }
    }
    
    return words.join(' ');
  }

  /// Gets the appropriate conjugated form of a verb
  String? _getConjugatedForm(
    VerbConjugation conjugation, 
    TranslationContext context, 
    int wordIndex, 
    List<String> words
  ) {
    // Simplified conjugation logic - can be extended with more sophisticated analysis
    final tense = _detectTense(words, wordIndex);
    final person = _detectPerson(words, wordIndex);
    final number = _detectNumber(words, wordIndex);
    
    return conjugation.getForm(tense, person, number);
  }

  /// Applies grammatical agreements between words
  String _applyGrammaticalAgreements(String text, TranslationContext context) {
    // Simplified agreement logic - can be extended with more sophisticated analysis
    final words = text.split(' ');
    final agreements = <GrammaticalAgreement>[];
    
    // Analyze words for grammatical properties
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final agreement = _analyzeWordGrammar(word, context);
      if (agreement != null) {
        agreements.add(agreement);
      }
    }
    
    // Apply agreements (simplified)
    return _adjustAgreements(words, agreements).join(' ');
  }

  /// Analyzes grammatical properties of a word
  GrammaticalAgreement? _analyzeWordGrammar(String word, TranslationContext context) {
    // This would typically involve more sophisticated grammatical analysis
    // For now, return basic analysis
    return GrammaticalAgreement(
      word: word,
      partOfSpeech: 'unknown',
    );
  }

  /// Adjusts words based on grammatical agreements
  List<String> _adjustAgreements(List<String> words, List<GrammaticalAgreement> agreements) {
    // Simplified agreement adjustment - can be extended
    return words;
  }

  /// Detects tense from context
  String _detectTense(List<String> words, int index) {
    // Simplified tense detection
    if (index > 0) {
      final prevWord = words[index - 1].toLowerCase();
      if (prevWord == 'will' || prevWord == 'shall') return 'future';
      if (prevWord == 'have' || prevWord == 'has') return 'present_perfect';
      if (prevWord == 'had') return 'past_perfect';
    }
    return 'present';
  }

  /// Detects person from context
  String _detectPerson(List<String> words, int index) {
    // Simplified person detection
    if (index > 0) {
      final prevWord = words[index - 1].toLowerCase();
      if (prevWord == 'i') return 'first';
      if (prevWord == 'you') return 'second';
      if (prevWord == 'he' || prevWord == 'she' || prevWord == 'it') return 'third';
    }
    return 'third';
  }

  /// Detects number from context
  String _detectNumber(List<String> words, int index) {
    // Simplified number detection
    if (index > 0) {
      final prevWord = words[index - 1].toLowerCase();
      if (prevWord == 'we' || prevWord == 'they') return 'plural';
    }
    return 'singular';
  }

  /// Preserves original capitalization when replacing words
  String _preserveCapitalization(String original, String replacement) {
    if (original.isEmpty || replacement.isEmpty) return replacement;
    
    if (original[0] == original[0].toUpperCase()) {
      return replacement[0].toUpperCase() + replacement.substring(1).toLowerCase();
    }
    return replacement.toLowerCase();
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

  /// Provides default grammar rules for common language pairs
  static List<GrammarRule> _getDefaultGrammarRules() {
    return [
      // Safe general cleanup only; language-specific rules must come from repository files
      GrammarRule(
        ruleId: 'double_spaces',
        sourceLanguage: 'any',
        targetLanguage: 'any',
        description: 'Remove double or more spaces',
        pattern: RegExp(r'\s{2,}'),
        replacement: ' ',
        priority: 1,
      ),
    ];
  }
}