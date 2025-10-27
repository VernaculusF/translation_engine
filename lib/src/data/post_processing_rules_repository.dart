library;

import 'dart:convert';
import '../utils/cache_manager.dart';
import '../storage/file_storage.dart';
import 'dart:io';

class PostProcessingRuleDto {
  final String ruleId;
  final String description;
  final String pattern;
  final String replacement;
  final int priority;
  final List<String> targetLanguages; // applies to these targets; empty means global
  final bool isGlobal;
  final bool caseSensitive;

  const PostProcessingRuleDto({
    required this.ruleId,
    required this.description,
    required this.pattern,
    required this.replacement,
    required this.priority,
    required this.targetLanguages,
    required this.isGlobal,
    required this.caseSensitive,
  });

  factory PostProcessingRuleDto.fromMap(Map<String, dynamic> map) {
    return PostProcessingRuleDto(
      ruleId: map['rule_id'] as String,
      description: map['description'] as String? ?? '',
      pattern: map['pattern'] as String,
      replacement: map['replacement'] as String? ?? '',
      priority: (map['priority'] as int?) ?? 1,
      targetLanguages: List<String>.from(map['target_languages'] as List? ?? const []),
      isGlobal: map['is_global'] as bool? ?? true,
      caseSensitive: map['case_sensitive'] as bool? ?? false,
    );
  }
}

/// Repository for loading Post-processing rules from JSONL files.
/// The file is searched under dataDir/{languageOrPair}/post_processing_rules.jsonl
class PostProcessingRulesRepository {
  static const String _cachePrefix = 'post_processing_rules:';

  final CacheManager cacheManager;
  final FileStorageService storage;

  PostProcessingRulesRepository({
    required String dataDirPath,
    required this.cacheManager,
  }) : storage = FileStorageService(rootDir: dataDirPath);

  final Map<String, List<PostProcessingRuleDto>> _rulesCache = {};

  Future<List<PostProcessingRuleDto>> getRules(String languageOrPair) async {
    final key = languageOrPair.toLowerCase();
    if (_rulesCache.containsKey(key)) return _rulesCache[key]!;

    final cacheKey = '$_cachePrefix$key';
    final cached = cacheManager.get<List<PostProcessingRuleDto>>(cacheKey);
    if (cached != null) {
      _rulesCache[key] = cached;
      return cached;
    }

    // Try pair folder first, then single-language folder
    final filePair = storage.postProcessingRulesFile(key);
    final candidates = <String>[];
    if (filePair.existsSync()) {
      candidates.add(filePair.path);
    } else {
      // If key looks like 'en-ru', also try target side
      final parts = key.split('-');
      final target = parts.length == 2 ? parts[1] : key;
      final alt = storage.postProcessingRulesFile(target);
      if (alt.existsSync()) candidates.add(alt.path);
    }

    if (candidates.isEmpty) {
      _rulesCache[key] = const [];
      return const [];
    }

    final dtos = <PostProcessingRuleDto>[];
    final file = File(candidates.first);
    final lines = file.readAsLinesSync();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final obj = jsonDecode(trimmed) as Map<String, dynamic>;
        dtos.add(PostProcessingRuleDto.fromMap(obj));
      } catch (_) {
        // skip invalid line
      }
    }

    _rulesCache[key] = dtos;
    cacheManager.set(cacheKey, dtos);
    return dtos;
  }
}
