import '../core/translation_context.dart';
import '../models/layer_debug_info.dart';
import '../utils/debug_logger.dart';
import 'base_translation_layer.dart';

/// Represents the syntactic order pattern for a language
enum WordOrderType {
  svo, // Subject-Verb-Object (English, Spanish, French)
  sov, // Subject-Object-Verb (Japanese, Korean)
  vso, // Verb-Subject-Object (Arabic, Welsh)
  vos, // Verb-Object-Subject (Malagasy)
  ovs, // Object-Verb-Subject (rare)
  osv, // Object-Subject-Verb (rare)
}

/// Represents a word order rule for specific language pairs
class WordOrderRule {
  final String ruleId;
  final String sourceLanguage;
  final String targetLanguage;
  final String description;
  final WordOrderType sourceOrder;
  final WordOrderType targetOrder;
  final RegExp pattern;
  final String reorderTemplate;
  final int priority;
  final List<String> conditions;

  const WordOrderRule({
    required this.ruleId,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.description,
    required this.sourceOrder,
    required this.targetOrder,
    required this.pattern,
    required this.reorderTemplate,
    this.priority = 1,
    this.conditions = const [],
  });

  bool appliesTo(String sourceLanguage, String targetLanguage) {
    return this.sourceLanguage == sourceLanguage && 
           this.targetLanguage == targetLanguage;
  }

  bool matchesConditions(TranslationContext context) {
    if (conditions.isEmpty) return true;
    
    for (final condition in conditions) {
      if (condition.startsWith('has_token:')) {
        final token = condition.substring('has_token:'.length);
        if (context.tokens?.any((t) => t.toLowerCase().contains(token.toLowerCase())) != true) {
          return false;
        }
      }
      
      if (condition.startsWith('word_count_gt:')) {
        final count = int.tryParse(condition.substring('word_count_gt:'.length)) ?? 0;
        final wordCount = context.tokens?.length ?? 0;
        if (wordCount <= count) {
          return false;
        }
      }
    }
    return true;
  }
}

/// Represents a parsed sentence component
class SentenceComponent {
  final String text;
  final ComponentType type;
  final int originalPosition;
  final List<String> tokens;
  final Map<String, dynamic> metadata;

  const SentenceComponent({
    required this.text,
    required this.type,
    required this.originalPosition,
    required this.tokens,
    this.metadata = const {},
  });

  SentenceComponent copyWith({
    String? text,
    ComponentType? type,
    int? originalPosition,
    List<String>? tokens,
    Map<String, dynamic>? metadata,
  }) {
    return SentenceComponent(
      text: text ?? this.text,
      type: type ?? this.type,
      originalPosition: originalPosition ?? this.originalPosition,
      tokens: tokens ?? this.tokens,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Types of sentence components
enum ComponentType {
  subject,
  verb,
  object,
  adjective,
  adverb,
  preposition,
  article,
  conjunction,
  unknown,
}

/// Represents a complete sentence structure
class SentenceStructure {
  final List<SentenceComponent> components;
  final WordOrderType detectedOrder;
  final String originalText;
  final double confidence;

  const SentenceStructure({
    required this.components,
    required this.detectedOrder,
    required this.originalText,
    this.confidence = 0.0,
  });

  SentenceComponent? getComponent(ComponentType type) {
    return components.where((c) => c.type == type).firstOrNull;
  }

  List<SentenceComponent> getComponents(ComponentType type) {
    return components.where((c) => c.type == type).toList();
  }
}

/// Word order layer that reorders words according to target language syntax
class WordOrderLayer extends BaseTranslationLayer {
  static const String layerName = 'WordOrderLayer';
  static const int layerPriority = 400;
  
  final List<WordOrderRule> _orderRules;
  final Map<String, WordOrderType> _languageOrders;
  final DebugLogger _logger;

  WordOrderLayer({
    List<WordOrderRule>? orderRules,
    Map<String, WordOrderType>? languageOrders,
    DebugLogger? logger,
  }) : _orderRules = orderRules ?? _getDefaultOrderRules(),
       _languageOrders = languageOrders ?? _getDefaultLanguageOrders(),
       _logger = logger ?? DebugLogger.instance;

  @override
  String get name => layerName;

  @override
  String get description => 'Word order layer: reorders words according to target language syntax (SVO, SOV, VSO, etc.)';

  @override
  LayerPriority get priority => LayerPriority.wordOrder;

  @override
  bool canHandle(String text, TranslationContext context) {
    // Word order layer processes translations that have tokens and require reordering
    return context.tokens != null && 
           context.tokens!.length > 2 && // At least 3 words to reorder
           context.translatedText != null &&
           context.translatedText!.isNotEmpty;
  }

  @override
  Future<LayerResult> process(String text, TranslationContext context) async {
    final stopwatch = Stopwatch()..start();

    try {
      _logger.debug('$name: Starting word order processing');
      
      // Get current translation
      final currentTranslation = context.translatedText ?? text;
      if (currentTranslation.isEmpty) {
        final debugInfo = LayerDebugInfo.error(
          layerName: name,
          processingTimeMs: stopwatch.elapsedMilliseconds,
          errorMessage: 'No translated text to reorder',
          inputText: text,
        );
        stopwatch.stop();
        return LayerResult.error(
          originalText: text,
          errorMessage: 'No translated text to reorder',
          debugInfo: debugInfo,
        );
      }

      final sourceLanguage = context.sourceLanguage;
      final targetLanguage = context.targetLanguage;
      
      // Skip if same language
      if (sourceLanguage == targetLanguage) {
        final debugInfo = LayerDebugInfo.success(
          layerName: name,
          processingTimeMs: stopwatch.elapsedMilliseconds,
          inputText: text,
          outputText: text,
          wasModified: false,
          additionalInfo: {'reason': 'Same source and target language'},
        );
        stopwatch.stop();
        return LayerResult.noChange(
          text: text,
          debugInfo: debugInfo,
          reason: 'Same source and target language',
        );
      }

      String reorderedText = currentTranslation;
      bool hasChanges = false;
      final appliedRules = <String>[];
      
      // Parse sentence structure
      final sentences = _splitIntoSentences(currentTranslation);
      final reorderedSentences = <String>[];
      
      for (final sentence in sentences) {
        if (sentence.trim().isEmpty) {
          reorderedSentences.add(sentence);
          continue;
        }
        
        final structure = _parseSentenceStructure(sentence, context);
        final reordered = await _reorderSentence(
          structure, 
          sourceLanguage, 
          targetLanguage,
          context
        );
        
        if (reordered != sentence) {
          hasChanges = true;
        }
        
        reorderedSentences.add(reordered);
      }
      
      reorderedText = reorderedSentences.join('');
      
      // Apply specific word order rules
      final applicableRules = _getApplicableRules(context, sourceLanguage, targetLanguage);
      applicableRules.sort((a, b) => b.priority.compareTo(a.priority));
      
      for (final rule in applicableRules) {
        final beforeText = reorderedText;
        reorderedText = _applyWordOrderRule(rule, reorderedText, context);
        
        if (reorderedText != beforeText) {
          hasChanges = true;
          appliedRules.add(rule.ruleId);
          _logger.debug('$name: Applied rule ${rule.ruleId}: "${rule.description}"');
        }
      }
      
      // Update context with reordered text
      if (hasChanges) {
        context.translatedText = reorderedText;
      }

      final debugInfo = LayerDebugInfo.success(
        layerName: name,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        inputText: text,
        outputText: reorderedText,
        wasModified: hasChanges,
        additionalInfo: {
          'applied_rules': appliedRules,
          'sentences_processed': sentences.length,
          'text_changed': hasChanges,
          'source_order': _languageOrders[sourceLanguage]?.name ?? 'unknown',
          'target_order': _languageOrders[targetLanguage]?.name ?? 'unknown',
          'original_length': currentTranslation.length,
          'reordered_length': reorderedText.length,
        },
        itemsProcessed: sentences.length,
        modificationsCount: appliedRules.length,
      );

      _logger.debug('$name: Word order processing completed. Applied ${appliedRules.length} rules');
      
      stopwatch.stop();
      return LayerResult.success(
        processedText: reorderedText,
        confidence: hasChanges ? 0.8 : 1.0,
        debugInfo: debugInfo,
      );
      
    } catch (e, stackTrace) {
      _logger.error('$name: Word order processing failed', e, stackTrace);
      final debugInfo = LayerDebugInfo.error(
        layerName: name,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        errorMessage: 'Word order processing error: $e',
        inputText: text,
      );
      stopwatch.stop();
      return LayerResult.error(
        originalText: text,
        errorMessage: 'Word order processing error: $e',
        debugInfo: debugInfo,
      );
    }
  }

  /// Splits text into sentences for individual processing
  List<String> _splitIntoSentences(String text) {
    // Simple sentence splitting - can be improved with more sophisticated logic
    final sentences = <String>[];
    final sentencePattern = RegExp(r'([.!?]\s*)');
    
    int lastEnd = 0;
    for (final match in sentencePattern.allMatches(text)) {
      final sentence = text.substring(lastEnd, match.end);
      sentences.add(sentence);
      lastEnd = match.end;
    }
    
    // Add remaining text if any
    if (lastEnd < text.length) {
      sentences.add(text.substring(lastEnd));
    }
    
    return sentences;
  }

  /// Parses sentence structure to identify components
  SentenceStructure _parseSentenceStructure(String sentence, TranslationContext context) {
    final words = sentence.trim().split(RegExp(r'\s+'));
    final components = <SentenceComponent>[];
    
    // Simple component detection - can be enhanced with NLP libraries
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final cleanWord = word.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
      
      if (cleanWord.isEmpty) continue;
      
      final componentType = _detectComponentType(cleanWord, i, words);
      
      components.add(SentenceComponent(
        text: word,
        type: componentType,
        originalPosition: i,
        tokens: [cleanWord],
      ));
    }
    
    final detectedOrder = _detectWordOrder(components);
    
    return SentenceStructure(
      components: components,
      detectedOrder: detectedOrder,
      originalText: sentence,
      confidence: 0.5, // Simple confidence - can be improved
    );
  }

  /// Detects the type of a word component
  ComponentType _detectComponentType(String word, int position, List<String> words) {
    // Simplified component type detection
    final wordLower = word.toLowerCase();
    
    // Articles
    if (['the', 'a', 'an', 'el', 'la', 'un', 'una', 'le', 'les', 'un', 'une'].contains(wordLower)) {
      return ComponentType.article;
    }
    
    // Prepositions
    if (['in', 'on', 'at', 'by', 'for', 'with', 'to', 'from', 'of', 'en', 'de', 'à', 'dans'].contains(wordLower)) {
      return ComponentType.preposition;
    }
    
    // Conjunctions
    if (['and', 'or', 'but', 'so', 'yet', 'for', 'nor', 'y', 'o', 'pero', 'et', 'ou', 'mais'].contains(wordLower)) {
      return ComponentType.conjunction;
    }
    
    // Simple verb detection (ends with common verb endings)
    if (RegExp(r'(ed|ing|s|es|er|ir|ar|ent|ons|ez)$').hasMatch(wordLower)) {
      return ComponentType.verb;
    }
    
    // Simple adjective detection (position and patterns)
    if (position > 0 && RegExp(r'(ly|ful|less|able|ible|al|ive|ous|ic)$').hasMatch(wordLower)) {
      return ComponentType.adjective;
    }
    
    // Default to subject if at beginning, object if after verb, unknown otherwise
    if (position == 0) {
      return ComponentType.subject;
    } else if (position > 0) {
      // Check if previous word was a verb
      final prevWordLower = words[position - 1].replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
      if (RegExp(r'(ed|ing|s|es|er|ir|ar|ent|ons|ez)$').hasMatch(prevWordLower)) {
        return ComponentType.object;
      }
    }
    
    return ComponentType.unknown;
  }

  /// Detects word order from sentence components
  WordOrderType _detectWordOrder(List<SentenceComponent> components) {
    final subjects = components.where((c) => c.type == ComponentType.subject).toList();
    final verbs = components.where((c) => c.type == ComponentType.verb).toList();
    final objects = components.where((c) => c.type == ComponentType.object).toList();
    
    if (subjects.isEmpty || verbs.isEmpty) {
      return WordOrderType.svo; // Default
    }
    
    final subjectPos = subjects.first.originalPosition;
    final verbPos = verbs.first.originalPosition;
    final objectPos = objects.isNotEmpty ? objects.first.originalPosition : -1;
    
    if (objectPos == -1) {
      // No object, check S-V order
      return subjectPos < verbPos ? WordOrderType.svo : WordOrderType.vso;
    }
    
    // Determine order based on positions
    if (subjectPos < verbPos && verbPos < objectPos) {
      return WordOrderType.svo;
    } else if (subjectPos < objectPos && objectPos < verbPos) {
      return WordOrderType.sov;
    } else if (verbPos < subjectPos && subjectPos < objectPos) {
      return WordOrderType.vso;
    } else if (verbPos < objectPos && objectPos < subjectPos) {
      return WordOrderType.vos;
    } else if (objectPos < verbPos && verbPos < subjectPos) {
      return WordOrderType.ovs;
    } else if (objectPos < subjectPos && subjectPos < verbPos) {
      return WordOrderType.osv;
    }
    
    return WordOrderType.svo; // Default
  }

  /// Reorders sentence according to target language syntax
  Future<String> _reorderSentence(
    SentenceStructure structure,
    String sourceLanguage,
    String targetLanguage,
    TranslationContext context
  ) async {
    final sourceOrder = _languageOrders[sourceLanguage] ?? WordOrderType.svo;
    final targetOrder = _languageOrders[targetLanguage] ?? WordOrderType.svo;
    
    // If same order, no reordering needed
    if (sourceOrder == targetOrder) {
      return structure.originalText;
    }
    
    final reorderedComponents = _reorderComponents(structure.components, targetOrder);
    
    // Rebuild sentence from reordered components
    final reorderedWords = <String>[];
    for (final component in reorderedComponents) {
      reorderedWords.add(component.text);
    }
    
    return reorderedWords.join(' ');
  }

  /// Reorders components according to target word order
  List<SentenceComponent> _reorderComponents(
    List<SentenceComponent> components,
    WordOrderType targetOrder
  ) {
    final subjects = components.where((c) => c.type == ComponentType.subject).toList();
    final verbs = components.where((c) => c.type == ComponentType.verb).toList();
    final objects = components.where((c) => c.type == ComponentType.object).toList();
    final others = components.where((c) => 
      c.type != ComponentType.subject && 
      c.type != ComponentType.verb && 
      c.type != ComponentType.object
    ).toList();
    
    final reordered = <SentenceComponent>[];
    
    // Add non-core components at the beginning (articles, prepositions)
    final initialOthers = others.where((c) => 
      c.type == ComponentType.article ||
      c.type == ComponentType.preposition
    ).toList();
    reordered.addAll(initialOthers);
    
    // Add core components in target order
    switch (targetOrder) {
      case WordOrderType.svo:
        reordered.addAll(subjects);
        reordered.addAll(verbs);
        reordered.addAll(objects);
        break;
      case WordOrderType.sov:
        reordered.addAll(subjects);
        reordered.addAll(objects);
        reordered.addAll(verbs);
        break;
      case WordOrderType.vso:
        reordered.addAll(verbs);
        reordered.addAll(subjects);
        reordered.addAll(objects);
        break;
      case WordOrderType.vos:
        reordered.addAll(verbs);
        reordered.addAll(objects);
        reordered.addAll(subjects);
        break;
      case WordOrderType.ovs:
        reordered.addAll(objects);
        reordered.addAll(verbs);
        reordered.addAll(subjects);
        break;
      case WordOrderType.osv:
        reordered.addAll(objects);
        reordered.addAll(subjects);
        reordered.addAll(verbs);
        break;
    }
    
    // Add remaining components
    final remainingOthers = others.where((c) => 
      c.type != ComponentType.article &&
      c.type != ComponentType.preposition
    ).toList();
    reordered.addAll(remainingOthers);
    
    return reordered;
  }

  /// Gets word order rules applicable to the current context
  List<WordOrderRule> _getApplicableRules(
    TranslationContext context,
    String sourceLanguage,
    String targetLanguage
  ) {
    return _orderRules.where((rule) {
      return rule.appliesTo(sourceLanguage, targetLanguage) && 
             rule.matchesConditions(context);
    }).toList();
  }

  /// Applies a specific word order rule to the text
  String _applyWordOrderRule(
    WordOrderRule rule,
    String text,
    TranslationContext context
  ) {
    try {
      return text.replaceAllMapped(rule.pattern, (match) {
        String reordered = rule.reorderTemplate;
        
        // Replace placeholders with captured groups
        for (int i = 0; i <= match.groupCount; i++) {
          final group = match.group(i);
          if (group != null) {
            reordered = reordered.replaceAll('\\$i', group);
          }
        }
        
        return reordered;
      });
    } catch (e) {
      _logger.warning('$name: Failed to apply rule ${rule.ruleId}: $e');
      return text;
    }
  }


  /// Provides default word order rules for common language pairs
  static List<WordOrderRule> _getDefaultOrderRules() {
    return [
      // English to Japanese: Subject-Object-Verb reordering
      WordOrderRule(
        ruleId: 'en_ja_sov_basic',
        sourceLanguage: 'en',
        targetLanguage: 'ja',
        description: 'Reorder English SVO to Japanese SOV',
        sourceOrder: WordOrderType.svo,
        targetOrder: WordOrderType.sov,
        pattern: RegExp(r'(\w+)\s+(\w+)\s+(\w+)'),
        reorderTemplate: r'\1 \3 \2',
        priority: 5,
        conditions: ['word_count_gt:2'],
      ),
      
      // French adjective placement
      WordOrderRule(
        ruleId: 'en_fr_adjective_placement',
        sourceLanguage: 'en',
        targetLanguage: 'fr',
        description: 'Move adjectives after nouns in French',
        sourceOrder: WordOrderType.svo,
        targetOrder: WordOrderType.svo,
        pattern: RegExp(r'(\w+)\s+(\w+)\s+(noun)'),
        reorderTemplate: r'\3 \1',
        priority: 3,
      ),
      
      // Spanish question inversion
      WordOrderRule(
        ruleId: 'en_es_question_inversion',
        sourceLanguage: 'en',
        targetLanguage: 'es',
        description: 'Invert subject-verb in Spanish questions',
        sourceOrder: WordOrderType.svo,
        targetOrder: WordOrderType.vso,
        pattern: RegExp(r'(do|does|did)\s+(\w+)\s+(\w+)'),
        reorderTemplate: r'\3 \2',
        priority: 4,
      ),
    ];
  }

  /// Provides default language word orders
  static Map<String, WordOrderType> _getDefaultLanguageOrders() {
    return {
      'en': WordOrderType.svo,  // English
      'es': WordOrderType.svo,  // Spanish
      'fr': WordOrderType.svo,  // French
      'de': WordOrderType.sov,  // German (in subordinate clauses)
      'it': WordOrderType.svo,  // Italian
      'pt': WordOrderType.svo,  // Portuguese
      'ru': WordOrderType.svo,  // Russian (flexible)
      'ja': WordOrderType.sov,  // Japanese
      'ko': WordOrderType.sov,  // Korean
      'zh': WordOrderType.svo,  // Chinese
      'ar': WordOrderType.vso,  // Arabic
      'he': WordOrderType.svo,  // Hebrew
      'tr': WordOrderType.sov,  // Turkish
      'hi': WordOrderType.sov,  // Hindi
    };
  }
}