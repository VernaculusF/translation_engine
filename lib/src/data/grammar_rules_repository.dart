library;

import 'dart:convert';
import '../utils/cache_manager.dart';
import '../storage/file_storage.dart';

class GrammarRuleDto {
  final String ruleId;
  final String sourceLanguage; // 'en' | 'ru' | 'any'
  final String targetLanguage; // 'ru' | 'en' | 'any'
  final String description;
  final String pattern; // raw regex string
  final String replacement;
  final int priority;
  final List<String> conditions;
  final bool caseSensitive;

  const GrammarRuleDto({
    required this.ruleId,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.description,
    required this.pattern,
    required this.replacement,
    required this.priority,
    required this.conditions,
    required this.caseSensitive,
  });

  factory GrammarRuleDto.fromMap(Map<String, dynamic> map) {
    return GrammarRuleDto(
      ruleId: map['rule_id'] as String,
      sourceLanguage: (map['source_language'] as String?)?.toLowerCase() ?? 'any',
      targetLanguage: (map['target_language'] as String?)?.toLowerCase() ?? 'any',
      description: map['description'] as String? ?? '',
      pattern: map['pattern'] as String,
      replacement: map['replacement'] as String? ?? '',
      priority: (map['priority'] as int?) ?? 1,
      conditions: List<String>.from(map['conditions'] as List? ?? const []),
      caseSensitive: map['case_sensitive'] as bool? ?? false,
    );
  }
}

/// Repository for loading Grammar rules from JSONL files per language pair
class GrammarRulesRepository {
  static const String _cachePrefix = 'grammar_rules:';

  final CacheManager cacheManager;
  final FileStorageService storage;

  GrammarRulesRepository({
    required String dataDirPath,
    required this.cacheManager,
  }) : storage = FileStorageService(rootDir: dataDirPath);

  final Map<String, List<GrammarRuleDto>> _rulesCache = {};

  Future<List<GrammarRuleDto>> getRules(String languagePair) async {
    final key = languagePair.toLowerCase();
    if (_rulesCache.containsKey(key)) {
      return _rulesCache[key]!;
    }
    final cacheKey = '$_cachePrefix$key';
    final cached = cacheManager.get<List<GrammarRuleDto>>(cacheKey);
    if (cached != null) {
      _rulesCache[key] = cached;
      return cached;
    }

    final file = storage.grammarRulesFile(key);
    if (!file.existsSync()) {
      _rulesCache[key] = const [];
      return const [];
    }

    final dtos = <GrammarRuleDto>[];
    final lines = file.readAsLinesSync();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final obj = jsonDecode(trimmed) as Map<String, dynamic>;
        dtos.add(GrammarRuleDto.fromMap(obj));
      } catch (_) {
        // skip invalid line
      }
    }

    _rulesCache[key] = dtos;
    cacheManager.set(cacheKey, dtos);
    return dtos;
  }
}
