import 'dart:convert';
import '../utils/exceptions.dart';
import '../utils/cache_manager.dart';
import '../utils/memory_manager.dart';
import '../storage/file_storage.dart';

/// Модель фразы для перевода
class PhraseEntry {
  final int? id;
  final String sourcePhrase;
  final String targetPhrase;
  final String languagePair; // например: "en-ru"
  final String? category; // категория: greetings, business, travel
  final String? context; // контекст использования
  final int frequency;
  final int confidence; // уверенность в переводе (0-100)
  final DateTime createdAt;
  final DateTime updatedAt;
  
  const PhraseEntry({
    this.id,
    required this.sourcePhrase,
    required this.targetPhrase,
    required this.languagePair,
    this.category,
    this.context,
    this.frequency = 1,
    this.confidence = 95,
    required this.createdAt,
    required this.updatedAt,
  });
  
  /// Создание из Map (из базы данных)
  factory PhraseEntry.fromMap(Map<String, dynamic> map) {
    return PhraseEntry(
      id: map['id'] as int?,
      sourcePhrase: map['source_phrase'] as String,
      targetPhrase: map['target_phrase'] as String,
      languagePair: map['language_pair'] as String,
      category: map['category'] as String?,
      context: map['context'] as String?,
      frequency: map['frequency'] as int? ?? 1,
      confidence: map['confidence'] as int? ?? 95,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
  
  /// Конвертация в Map (для базы данных)
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'source_phrase': sourcePhrase,
      'target_phrase': targetPhrase,
      'language_pair': languagePair,
      'category': category,
      'context': context,
      'frequency': frequency,
      'confidence': confidence,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
  
  /// Создание копии с изменениями
  PhraseEntry copyWith({
    int? id,
    String? sourcePhrase,
    String? targetPhrase,
    String? languagePair,
    String? category,
    String? context,
    int? frequency,
    int? confidence,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PhraseEntry(
      id: id ?? this.id,
      sourcePhrase: sourcePhrase ?? this.sourcePhrase,
      targetPhrase: targetPhrase ?? this.targetPhrase,
      languagePair: languagePair ?? this.languagePair,
      category: category ?? this.category,
      context: context ?? this.context,
      frequency: frequency ?? this.frequency,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  /// Получить ключевые слова из фразы
  List<String> get keywords {
    return sourcePhrase
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(' ')
        .where((word) => word.length > 2)
        .toList();
  }
  
  /// Проверить, содержит ли фраза поисковый терм
  bool containsSearchTerm(String searchTerm) {
    final normalizedSource = sourcePhrase.toLowerCase();
    final normalizedTarget = targetPhrase.toLowerCase();
    final normalizedTerm = searchTerm.toLowerCase();
    
    return normalizedSource.contains(normalizedTerm) ||
           normalizedTarget.contains(normalizedTerm) ||
           keywords.any((keyword) => keyword.contains(normalizedTerm));
  }
  
  @override
  String toString() {
    return 'PhraseEntry(sourcePhrase: "$sourcePhrase", targetPhrase: "$targetPhrase", languagePair: $languagePair)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PhraseEntry &&
        other.sourcePhrase == sourcePhrase &&
        other.targetPhrase == targetPhrase &&
        other.languagePair == languagePair;
  }
  
  @override
  int get hashCode => Object.hash(sourcePhrase, targetPhrase, languagePair);
}

/// Репозиторий для работы с фразами (файловое хранилище JSONL)
class PhraseRepository {
  static const String _cachePrefix = 'phrase:';
  static const String _repoName = 'phrase';

  final CacheManager cacheManager;
  final FileStorageService storage;
  final MemoryManager? memoryManager;

  PhraseRepository({
    required String dataDirPath,
    required this.cacheManager,
    this.memoryManager,
  }) : storage = FileStorageService(rootDir: dataDirPath) {
    // Регистрируем репозиторий в MemoryManager
    memoryManager?.registerRepository(
      _repoName,
      _unloadLanguagePair,
      _estimateLanguagePairSize,
    );
  }

  final Map<String, _PhraseLangCache> _langCaches = {};
  
  _PhraseLangCache _ensureLoaded(String languagePair) {
    final lang = languagePair.toLowerCase();
    
    // Уведомить MemoryManager о доступе
    memoryManager?.touchLanguagePair(_repoName, lang);
    
    return _langCaches.putIfAbsent(lang, () => _PhraseLangCache(lang, storage));
  }
  
  /// Callback для выгрузки языковой пары (используется MemoryManager)
  Future<void> _unloadLanguagePair(String languagePair) async {
    final lang = languagePair.toLowerCase();
    _langCaches.remove(lang);
  }
  
  /// Оценка размера языковой пары в байтах (используется MemoryManager)
  int _estimateLanguagePairSize(String languagePair) {
    final lang = languagePair.toLowerCase();
    final cache = _langCaches[lang];
    if (cache == null) return 0;
    
    // Приблизительная оценка: количество фраз * средний размер
    // Фразы занимают больше памяти: ~500 байт на фразу + индексы
    const avgPhraseSize = 500;
    // Учитываем два индекса: bySource и bySourceLoose
    final indexOverhead = cache.bySourceLoose.length * 50;
    return cache.bySource.length * avgPhraseSize + indexOverhead;
  }
  
  String generateCacheKey(Map<String, dynamic> params) {
    final sourcePhrase = params['sourcePhrase'] as String?;
    final languagePair = params['languagePair'] as String?;
    final searchType = params['searchType'] as String? ?? 'exact';
    if (sourcePhrase != null && languagePair != null) {
      final normalizedPhrase = sourcePhrase
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), '_');
      return '$_cachePrefix$searchType:$languagePair:$normalizedPhrase';
    }
    final queryType = params['queryType'] as String? ?? 'unknown';
    final hash = params.hashCode.toString();
    return '$_cachePrefix$queryType:$hash';
  }

  void clearCache() {
    final allKeys = cacheManager.getAllKeys();
    for (final key in allKeys) {
      if (key.startsWith(_cachePrefix)) {
        cacheManager.remove(key);
      }
    }
  }

  void _validateData(Map<String, dynamic> data) {
    if (data['source_phrase'] == null || (data['source_phrase'] as String).trim().isEmpty) {
      throw ValidationException('Source phrase is required and cannot be empty');
    }
    if (data['target_phrase'] == null || (data['target_phrase'] as String).trim().isEmpty) {
      throw ValidationException('Target phrase is required and cannot be empty');
    }
    if (data['language_pair'] == null || (data['language_pair'] as String).trim().isEmpty) {
      throw ValidationException('Language pair is required and cannot be empty');
    }
    final languagePair = data['language_pair'] as String;
    if (!RegExp(r'^[a-z]{2}-[a-z]{2}$').hasMatch(languagePair)) {
      throw ValidationException('Language pair must be in format "xx-xx" (e.g., "en-ru")');
    }
    if (data['confidence'] != null) {
      final confidence = data['confidence'] as int;
      if (confidence < 0 || confidence > 100) {
        throw ValidationException('Confidence must be between 0 and 100');
      }
    }
    final sourcePhrase = (data['source_phrase'] as String).trim();
    final targetPhrase = (data['target_phrase'] as String).trim();
    if (sourcePhrase.isEmpty) {
      throw ValidationException('Source phrase must not be empty');
    }
    if (targetPhrase.isEmpty) {
      throw ValidationException('Target phrase must not be empty');
    }
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> data) {
    final transformed = Map<String, dynamic>.from(data);
    if (transformed['source_phrase'] != null) {
      transformed['source_phrase'] = (transformed['source_phrase'] as String)
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ');
    }
    if (transformed['target_phrase'] != null) {
      transformed['target_phrase'] = (transformed['target_phrase'] as String)
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ');
    }
    if (transformed['language_pair'] != null) {
      transformed['language_pair'] = (transformed['language_pair'] as String).toLowerCase();
    }
    if (transformed['category'] != null) {
      transformed['category'] = (transformed['category'] as String).toLowerCase().trim();
    }
    transformed['confidence'] ??= 95;
    transformed['frequency'] ??= 1;
    final now = DateTime.now().millisecondsSinceEpoch;
    transformed['updated_at'] = now;
    transformed['created_at'] ??= now;
    return transformed;
  }
  
  /// Получить точный перевод фразы
  Future<PhraseEntry?> getPhraseTranslation(
    String sourcePhrase,
    String languagePair, {
    bool useCache = true,
  }) async {
    // Canonical key
    String canonical = sourcePhrase.trim().toLowerCase();
    canonical = canonical.replaceAll(RegExp(r'\s+'), ' ');
    // Remove wrapping quotes for canonical (not inner)
    if ((canonical.length >= 2 && canonical.startsWith('"') && canonical.endsWith('"')) ||
        (canonical.length >= 2 && canonical.startsWith("'") && canonical.endsWith("'"))) {
      canonical = canonical.substring(1, canonical.length - 1);
    }
    final normalizedLangPair = languagePair.toLowerCase();

    if (useCache) {
      final cacheKey = generateCacheKey({
        'sourcePhrase': canonical,
        'languagePair': normalizedLangPair,
        'searchType': 'exact',
      });
      final cached = cacheManager.get<PhraseEntry>(cacheKey);
      if (cached != null) return cached;
    }

    final cache = _ensureLoaded(normalizedLangPair);
    PhraseEntry? entry = cache.bySource[canonical];
    if (entry == null) {
      // Try loose variant without apostrophes
      final loose = canonical.replaceAll("'", '');
      entry = cache.bySourceLoose[loose];
    }
    if (entry == null) {
      // Try words-only lookup (punctuation stripped), suits n-gram tokenization
      final wordsOnly = canonical.replaceAll(RegExp(r"[^a-z0-9\s]", caseSensitive: false), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (wordsOnly.isNotEmpty) {
        entry = cache.bySourceWordsOnly[wordsOnly];
      }
      if (entry == null) return null;
    }

    if (useCache) {
      final cacheKey = generateCacheKey({
        'sourcePhrase': canonical,
        'languagePair': normalizedLangPair,
        'searchType': 'exact',
      });
      cacheManager.set(cacheKey, entry);
    }
    return entry;
  }
  
  /// Добавить новую фразу или обновить существующую (с немедленной записью)
  Future<PhraseEntry> addPhrase(
    String sourcePhrase,
    String targetPhrase,
    String languagePair, {
    String? category,
    String? context,
    int frequency = 1,
    int confidence = 95,
  }) async {
    final res = await addPhrasesBulk([
      {
        'source_phrase': sourcePhrase,
        'target_phrase': targetPhrase,
        'language_pair': languagePair,
        'category': category,
        'context': context,
        'frequency': frequency,
        'confidence': confidence,
      }
    ]);
    return res.first;
  }

  /// Пакетное добавление/обновление фраз одной записью файла
  Future<List<PhraseEntry>> addPhrasesBulk(List<Map<String, dynamic>> items) async {
    final results = <PhraseEntry>[];
    final byLang = <String, List<Map<String, dynamic>>>{};
    for (final raw in items) {
      _validateData(raw);
      final normalized = _normalize(raw);
      final lang = normalized['language_pair'] as String;
      (byLang[lang] ??= []).add(normalized);
    }

    for (final entry in byLang.entries) {
      final lang = entry.key;
      final list = entry.value;
      final cache = _ensureLoaded(lang);

      for (final data in list) {
        final key = (data['source_phrase'] as String);
        final existing = cache.bySource[key];
        if (existing != null) {
          final updated = existing.copyWith(
            targetPhrase: data['target_phrase'] as String,
            category: data['category'] as String?,
            context: data['context'] as String?,
            frequency: existing.frequency + (data['frequency'] as int? ?? 1),
            confidence: ((existing.confidence + (data['confidence'] as int? ?? 95)) ~/ 2),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(data['updated_at'] as int),
          );
          cache.bySource[key] = updated;
          results.add(updated);
        } else {
          final id = ++cache.maxId;
          final entry = PhraseEntry(
            id: id,
            sourcePhrase: key,
            targetPhrase: data['target_phrase'] as String,
            languagePair: lang,
            category: data['category'] as String?,
            context: data['context'] as String?,
            frequency: data['frequency'] as int? ?? 1,
            confidence: data['confidence'] as int? ?? 95,
            createdAt: DateTime.fromMillisecondsSinceEpoch(data['created_at'] as int),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(data['updated_at'] as int),
          );
          cache.bySource[key] = entry;
          results.add(entry);
        }
      }

      await storage.ensureLangDir(lang);
      final file = storage.phrasesFile(lang);
      await storage.rewriteJsonLines(file, cache.bySource.values.map((e) => e.toMap()));
    }

    for (final r in results) {
      final cacheKey = generateCacheKey({
        'sourcePhrase': r.sourcePhrase,
        'languagePair': r.languagePair,
        'searchType': 'exact',
      });
      cacheManager.set(cacheKey, r);
    }
    return results;
  }
  
  /// Поиск фраз по частичному совпадению
  Future<List<PhraseEntry>> searchByPhrase(
    String searchTerm,
    String languagePair, {
    String? category,
    int limit = 20,
    bool useCache = true,
  }) async {
    final normalizedTerm = searchTerm.trim().toLowerCase();
    final normalizedLangPair = languagePair.toLowerCase();
    
    // Попробовать получить из кэша
    if (useCache) {
      final cacheKey = generateCacheKey({
        'sourcePhrase': normalizedTerm,
        'languagePair': normalizedLangPair,
        'searchType': 'search',
        'category': category,
        'limit': limit,
      });
      
      final cached = cacheManager.get<List<PhraseEntry>>(cacheKey);
      if (cached != null) {
        return cached;
      }
    }
    
    // Поиск по памяти
    final cache = _ensureLoaded(normalizedLangPair);
    var entries = cache.bySource.values.where((e) {
      final okText = e.sourcePhrase.contains(normalizedTerm) || e.targetPhrase.toLowerCase().contains(normalizedTerm);
      final okCat = category == null || (e.category?.toLowerCase() == category.toLowerCase());
      return okText && okCat;
    }).toList()
      ..sort((a, b) {
        final c = b.confidence.compareTo(a.confidence);
        if (c != 0) return c;
        final f = b.frequency.compareTo(a.frequency);
        if (f != 0) return f;
        return a.sourcePhrase.length.compareTo(b.sourcePhrase.length);
      });
    if (entries.length > limit) entries = entries.sublist(0, limit);
    
    // Сохранить в кэш
    if (useCache) {
      final cacheKey = generateCacheKey({
        'sourcePhrase': normalizedTerm,
        'languagePair': normalizedLangPair,
        'searchType': 'search',
        'category': category,
        'limit': limit,
      });
      cacheManager.set(cacheKey, entries);
    }
    
    return entries;
  }
  
  /// Получить все фразы для языковой пары
  Future<List<PhraseEntry>> getAllPhrases(
    String languagePair, {
    String? category,
    int? limit,
    int? offset,
    String orderBy = 'confidence DESC, frequency DESC',
  }) async {
    Map<String, dynamic> conditions = {'language_pair': languagePair.toLowerCase()};
    
    if (category != null) {
      conditions['category'] = category.toLowerCase();
    }
    
    final cache = _ensureLoaded(languagePair.toLowerCase());
    var list = cache.bySource.values.where((e) {
      if (category != null && (e.category?.toLowerCase() != category.toLowerCase())) return false;
      return true;
    }).toList();
    if (orderBy.toLowerCase().contains('confidence')) {
      final desc = orderBy.toLowerCase().contains('desc');
      list.sort((a, b) => desc ? b.confidence.compareTo(a.confidence) : a.confidence.compareTo(b.confidence));
    }
    if (offset != null && offset > 0 && offset < list.length) list = list.sublist(offset);
    if (limit != null && limit < list.length) list = list.sublist(0, limit);
    return list;
  }
  
  /// Получить фразы по категории
  Future<List<PhraseEntry>> getPhrasesByCategory(
    String category,
    String languagePair, {
    int limit = 50,
  }) async {
    return await getAllPhrases(
      languagePair,
      category: category,
      limit: limit,
    );
  }
  
  /// Получить список всех категорий
  Future<List<String>> getCategories(String languagePair) async {
    final cache = _ensureLoaded(languagePair.toLowerCase());
    final set = <String>{};
    for (final e in cache.bySource.values) {
      final c = e.category ?? '';
      if (c.isNotEmpty) set.add(c);
    }
    final list = set.toList()..sort();
    return list;
  }
  
  /// Удалить фразу
  Future<bool> deletePhrase(int id) async {
    for (final cache in _langCaches.values) {
      PhraseEntry? toRemove;
      for (final e in cache.bySource.values) {
        if (e.id == id) {
          toRemove = e;
          break;
        }
      }
      if (toRemove != null) {
        cache.bySource.remove(toRemove.sourcePhrase);
        final file = storage.phrasesFile(cache.lang);
        await storage.rewriteJsonLines(file, cache.bySource.values.map((e) => e.toMap()));
        clearCache();
        return true;
      }
    }
    return false;
  }
  
  /// Получить статистику по языковой паре
  Future<Map<String, dynamic>> getLanguagePairStats(String languagePair) async {
    final cache = _ensureLoaded(languagePair.toLowerCase());
    if (cache.bySource.isEmpty) {
      return {
        'language_pair': languagePair,
        'total_phrases': 0,
        'avg_confidence': 0.0,
        'avg_frequency': 0.0,
        'categories_count': 0,
      };
    }
    final total = cache.bySource.length;
    final avgConf = cache.bySource.values.map((e) => e.confidence).reduce((a, b) => a + b) / total;
    final avgFreq = cache.bySource.values.map((e) => e.frequency).reduce((a, b) => a + b) / total;
    final cats = cache.bySource.values.map((e) => e.category).whereType<String>().toSet().length;
    return {
      'language_pair': languagePair,
      'total_phrases': total,
      'avg_confidence': avgConf,
      'avg_frequency': avgFreq,
      'categories_count': cats,
    };
  }
  
  /// Получить топ наиболее уверенных фраз
  Future<List<PhraseEntry>> getTopConfidentPhrases(
    String languagePair, {
    int limit = 100,
    int minConfidence = 90,
  }) async {
    final cache = _ensureLoaded(languagePair.toLowerCase());
    var list = cache.bySource.values
        .where((e) => e.confidence >= minConfidence)
        .toList()
      ..sort((a, b) {
        final c = b.confidence.compareTo(a.confidence);
        return c != 0 ? c : b.frequency.compareTo(a.frequency);
      });
    if (list.length > limit) list = list.sublist(0, limit);
    return list;
  }
  
  /// Поиск по ключевым словам
  Future<List<PhraseEntry>> searchByKeywords(
    List<String> keywords,
    String languagePair, {
    int limit = 20,
  }) async {
    if (keywords.isEmpty) return [];
    final normalized = keywords.map((k) => k.toLowerCase().trim()).where((k) => k.isNotEmpty).toList();
    if (normalized.isEmpty) return [];

    final cache = _ensureLoaded(languagePair.toLowerCase());
    var list = cache.bySource.values.where((e) {
      final src = e.sourcePhrase;
      final dst = e.targetPhrase.toLowerCase();
      for (final k in normalized) {
        if (src.contains(k) || dst.contains(k)) return true;
      }
      return false;
    }).toList()
      ..sort((a, b) {
        final c = b.confidence.compareTo(a.confidence);
        return c != 0 ? c : b.frequency.compareTo(a.frequency);
      });

    if (list.length > limit) list = list.sublist(0, limit);
    return list;
  }
}

class _PhraseLangCache {
  final String lang;
  final FileStorageService storage;
  final Map<String, PhraseEntry> bySource = {};
  final Map<String, PhraseEntry> bySourceLoose = {};
  // Words-only (punctuation-stripped) keys for phrase lookup from tokenized text
  final Map<String, PhraseEntry> bySourceWordsOnly = {};
  int maxId = 0;

  _PhraseLangCache(this.lang, this.storage) {
    _load();
  }

  String _normalizeKey(String s) {
    var t = s.trim().toLowerCase();
    if ((t.length >= 2 && t.startsWith('"') && t.endsWith('"')) ||
        (t.length >= 2 && t.startsWith("'") && t.endsWith("'"))) {
      t = t.substring(1, t.length - 1);
    }
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t;
  }

  String _wordsOnlyKey(String key) {
    // Strip punctuation/symbols, keep letters, numbers and spaces; collapse spaces
    var t = key.replaceAll(RegExp(r"[^a-z0-9\s]", caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  void _load() {
    final file = storage.phrasesFile(lang);
    if (!file.existsSync()) return;
    // Decode with BOM/encoding detection and split on all newline variants
    final content = storage.readAllTextDetectingEncoding(file);
    final lines = content.split(RegExp(r'\r\n|\n|\r'));
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final map = jsonDecode(line) as Map<String, dynamic>;
        final entry = PhraseEntry.fromMap(map);
        final key = _normalizeKey(entry.sourcePhrase);
        final loose = _looseKey(key);
        final words = _wordsOnlyKey(key);
        bySource[key] = entry;
        bySourceLoose[loose] = entry;
        if (words.isNotEmpty) bySourceWordsOnly[words] = entry;
        if (entry.id != null && entry.id! > maxId) maxId = entry.id!;
      } catch (_) {
        // skip
      }
    }
  }

  String _looseKey(String key) {
    return key.replaceAll("'", '');
  }
}
