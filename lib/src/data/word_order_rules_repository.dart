library;

import 'dart:convert';
import '../utils/cache_manager.dart';
import '../storage/file_storage.dart';

class WordOrderRuleDto {
  final String ruleId;
  final String sourceLanguage;
  final String targetLanguage;
  final String description;
  final String sourceOrder; // 'svo' | 'sov' | ...
  final String targetOrder;
  final String pattern;
  final String reorderTemplate;
  final int priority;
  final List<String> conditions;
  final bool caseSensitive;

  const WordOrderRuleDto({
    required this.ruleId,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.description,
    required this.sourceOrder,
    required this.targetOrder,
    required this.pattern,
    required this.reorderTemplate,
    required this.priority,
    required this.conditions,
    required this.caseSensitive,
  });

  factory WordOrderRuleDto.fromMap(Map<String, dynamic> map) {
    return WordOrderRuleDto(
      ruleId: map['rule_id'] as String,
      sourceLanguage: (map['source_language'] as String?)?.toLowerCase() ?? 'any',
      targetLanguage: (map['target_language'] as String?)?.toLowerCase() ?? 'any',
      description: map['description'] as String? ?? '',
      sourceOrder: (map['source_order'] as String?)?.toLowerCase() ?? 'svo',
      targetOrder: (map['target_order'] as String?)?.toLowerCase() ?? 'svo',
      pattern: map['pattern'] as String,
      reorderTemplate: map['reorder_template'] as String? ?? r'$0',
      priority: (map['priority'] as int?) ?? 1,
      conditions: List<String>.from(map['conditions'] as List? ?? const []),
      caseSensitive: map['case_sensitive'] as bool? ?? false,
    );
  }
}

class WordOrderRulesRepository {
  static const String _cachePrefix = 'word_order_rules:';

  final CacheManager cacheManager;
  final FileStorageService storage;

  WordOrderRulesRepository({
    required String dataDirPath,
    required this.cacheManager,
  }) : storage = FileStorageService(rootDir: dataDirPath);

  final Map<String, List<WordOrderRuleDto>> _rulesCache = {};

  Future<List<WordOrderRuleDto>> getRules(String languagePair) async {
    final key = languagePair.toLowerCase();
    if (_rulesCache.containsKey(key)) return _rulesCache[key]!;

    final cacheKey = '$_cachePrefix$key';
    final cached = cacheManager.get<List<WordOrderRuleDto>>(cacheKey);
    if (cached != null) {
      _rulesCache[key] = cached;
      return cached;
    }

    final file = storage.wordOrderRulesFile(key);
    if (!file.existsSync()) {
      _rulesCache[key] = const [];
      return const [];
    }

    final dtos = <WordOrderRuleDto>[];
    final lines = file.readAsLinesSync();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final obj = jsonDecode(trimmed) as Map<String, dynamic>;
        dtos.add(WordOrderRuleDto.fromMap(obj));
      } catch (_) {
        // skip invalid line
      }
    }

    _rulesCache[key] = dtos;
    cacheManager.set(cacheKey, dtos);
    return dtos;
  }
}
