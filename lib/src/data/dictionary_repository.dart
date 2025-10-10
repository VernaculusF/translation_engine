import 'dart:convert';
import '../utils/exceptions.dart';
import '../utils/cache_manager.dart';
import '../storage/file_storage.dart';

/// Модель записи словаря
class DictionaryEntry {
  final int? id;
  final String sourceWord;
  final String targetWord;
  final String languagePair; // например: "en-ru"
  final String? partOfSpeech;
  final String? definition;
  final int frequency;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  const DictionaryEntry({
    this.id,
    required this.sourceWord,
    required this.targetWord,
    required this.languagePair,
    this.partOfSpeech,
    this.definition,
    this.frequency = 1,
    required this.createdAt,
    required this.updatedAt,
  });
  
  /// Создание из Map (из базы данных)
  factory DictionaryEntry.fromMap(Map<String, dynamic> map) {
    return DictionaryEntry(
      id: map['id'] as int?,
      sourceWord: map['source_word'] as String,
      targetWord: map['target_word'] as String,
      languagePair: map['language_pair'] as String,
      partOfSpeech: map['part_of_speech'] as String?,
      definition: map['definition'] as String?,
      frequency: map['frequency'] as int? ?? 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
  
  /// Конвертация в Map (для базы данных)
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'source_word': sourceWord,
      'target_word': targetWord,
      'language_pair': languagePair,
      'part_of_speech': partOfSpeech,
      'definition': definition,
      'frequency': frequency,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
  
  /// Создание копии с изменениями
  DictionaryEntry copyWith({
    int? id,
    String? sourceWord,
    String? targetWord,
    String? languagePair,
    String? partOfSpeech,
    String? definition,
    int? frequency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DictionaryEntry(
      id: id ?? this.id,
      sourceWord: sourceWord ?? this.sourceWord,
      targetWord: targetWord ?? this.targetWord,
      languagePair: languagePair ?? this.languagePair,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      definition: definition ?? this.definition,
      frequency: frequency ?? this.frequency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  @override
  String toString() {
    return 'DictionaryEntry(sourceWord: $sourceWord, targetWord: $targetWord, languagePair: $languagePair)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DictionaryEntry &&
        other.sourceWord == sourceWord &&
        other.targetWord == targetWord &&
        other.languagePair == languagePair;
  }
  
  @override
  int get hashCode => Object.hash(sourceWord, targetWord, languagePair);
}

/// Репозиторий для работы со словарями (файловое хранилище JSONL)
class DictionaryRepository {
  static const String _cachePrefix = 'dict:';

  final CacheManager cacheManager;
  final FileStorageService storage;

  DictionaryRepository({
    required String dataDirPath,
    required this.cacheManager,
  }) : storage = FileStorageService(rootDir: dataDirPath);

  // В памяти поддерживаем индекс по языковой паре
  final Map<String, _DictLangCache> _langCaches = {};

  _DictLangCache _ensureLoaded(String languagePair) {
    final lang = languagePair.toLowerCase();
    return _langCaches.putIfAbsent(lang, () => _DictLangCache(lang, storage));
  }

  String generateCacheKey(Map<String, dynamic> params) {
    final sourceWord = params['sourceWord'] as String?;
    final languagePair = params['languagePair'] as String?;
    final searchType = params['searchType'] as String? ?? 'exact';
    if (sourceWord != null && languagePair != null) {
      return '$_cachePrefix$searchType:$languagePair:${sourceWord.toLowerCase()}';
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
    if (data['source_word'] == null || (data['source_word'] as String).trim().isEmpty) {
      throw ValidationException('Source word is required and cannot be empty');
    }
    if (data['target_word'] == null || (data['target_word'] as String).trim().isEmpty) {
      throw ValidationException('Target word is required and cannot be empty');
    }
    if (data['language_pair'] == null || (data['language_pair'] as String).trim().isEmpty) {
      throw ValidationException('Language pair is required and cannot be empty');
    }
    final languagePair = data['language_pair'] as String;
    if (!RegExp(r'^[a-z]{2}-[a-z]{2}$').hasMatch(languagePair)) {
      throw ValidationException('Language pair must be in format "xx-xx" (e.g., "en-ru")');
    }
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> data) {
    final transformed = Map<String, dynamic>.from(data);
    if (transformed['source_word'] != null) {
      transformed['source_word'] = (transformed['source_word'] as String).trim().toLowerCase();
    }
    if (transformed['target_word'] != null) {
      transformed['target_word'] = (transformed['target_word'] as String).trim();
    }
    if (transformed['language_pair'] != null) {
      transformed['language_pair'] = (transformed['language_pair'] as String).toLowerCase();
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    transformed['updated_at'] = now;
    transformed['created_at'] ??= now;
    return transformed;
  }

  /// Получить перевод слова
  Future<DictionaryEntry?> getTranslation(
    String sourceWord,
    String languagePair, {
    bool useCache = true,
  }) async {
    final normalizedWord = sourceWord.trim().toLowerCase();
    final normalizedLangPair = languagePair.toLowerCase();
    
    // Попробовать получить из кэша
    if (useCache) {
      final cacheKey = generateCacheKey({
        'sourceWord': normalizedWord,
        'languagePair': normalizedLangPair,
        'searchType': 'exact',
      });
      
      final cached = cacheManager.get<DictionaryEntry>(cacheKey);
      if (cached != null) {
        return cached;
      }
    }
    
    // Поиск в файловом индексе
    final cache = _ensureLoaded(normalizedLangPair);
    final entry = cache.bySource[normalizedWord];
    if (entry == null) {
      return null;
    }
    
    // Сохранить в кэш
    if (useCache) {
      final cacheKey = generateCacheKey({
        'sourceWord': normalizedWord,
        'languagePair': normalizedLangPair,
        'searchType': 'exact',
      });
      cacheManager.set(cacheKey, entry);
    }
    
    return entry;
  }
  
  /// Добавить новый перевод или обновить существующий
  Future<DictionaryEntry> addTranslation(
    String sourceWord,
    String targetWord,
    String languagePair, {
    String? partOfSpeech,
    String? definition,
    int frequency = 1,
  }) async {
    final data = {
      'source_word': sourceWord,
      'target_word': targetWord,
      'language_pair': languagePair,
      'part_of_speech': partOfSpeech,
      'definition': definition,
      'frequency': frequency,
    };

    _validateData(data);
    final transformedData = _normalize(data);

    final lang = transformedData['language_pair'] as String;
    final cache = _ensureLoaded(lang);

    final existing = cache.bySource[transformedData['source_word'] as String];
    DictionaryEntry result;

    if (existing != null) {
      // обновление
      final updated = existing.copyWith(
        targetWord: transformedData['target_word'] as String,
        partOfSpeech: transformedData['part_of_speech'] as String?,
        definition: transformedData['definition'] as String?,
        frequency: existing.frequency + (transformedData['frequency'] as int? ?? 1),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(transformedData['updated_at'] as int),
      );
      cache.bySource[updated.sourceWord] = updated;
      result = updated;
    } else {
      // вставка
      final id = ++cache.maxId;
      final entry = DictionaryEntry(
        id: id,
        sourceWord: transformedData['source_word'] as String,
        targetWord: transformedData['target_word'] as String,
        languagePair: lang,
        partOfSpeech: transformedData['part_of_speech'] as String?,
        definition: transformedData['definition'] as String?,
        frequency: transformedData['frequency'] as int? ?? 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(transformedData['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(transformedData['updated_at'] as int),
      );
      cache.bySource[entry.sourceWord] = entry;
      result = entry;
    }

    // перезаписать файл
    await storage.ensureLangDir(lang);
    final file = storage.dictFile(lang);
    await storage.rewriteJsonLines(file, cache.bySource.values.map((e) => e.toMap()));

    // Обновить кэш
    final cacheKey = generateCacheKey({
      'sourceWord': result.sourceWord,
      'languagePair': result.languagePair,
      'searchType': 'exact',
    });
    cacheManager.set(cacheKey, result);

    return result;
  }
  
  /// Поиск переводов по частичному совпадению
  Future<List<DictionaryEntry>> searchByWord(
    String searchTerm,
    String languagePair, {
    int limit = 20,
    bool useCache = true,
  }) async {
    final normalizedTerm = searchTerm.trim().toLowerCase();
    final normalizedLangPair = languagePair.toLowerCase();
    
    // Попробовать получить из кэша
    if (useCache) {
      final cacheKey = generateCacheKey({
        'sourceWord': normalizedTerm,
        'languagePair': normalizedLangPair,
        'searchType': 'search',
        'limit': limit,
      });
      
      final cached = cacheManager.get<List<DictionaryEntry>>(cacheKey);
      if (cached != null) {
        return cached;
      }
    }
    
    // Поиск по индексу в памяти
    final cache = _ensureLoaded(normalizedLangPair);
    final entries = cache.bySource.values
        .where((e) => e.sourceWord.contains(normalizedTerm) || e.targetWord.toLowerCase().contains(normalizedTerm))
        .toList()
      ..sort((a, b) {
        final f = b.frequency.compareTo(a.frequency);
        if (f != 0) return f;
        return a.sourceWord.compareTo(b.sourceWord);
      });
    if (entries.length > limit) {
      return entries.sublist(0, limit);
    }
    
    // Сохранить в кэш
    if (useCache) {
      final cacheKey = generateCacheKey({
        'sourceWord': normalizedTerm,
        'languagePair': normalizedLangPair,
        'searchType': 'search',
        'limit': limit,
      });
      cacheManager.set(cacheKey, entries);
    }
    
    return entries;
  }
  
  /// Получить все переводы для языковой пары
  Future<List<DictionaryEntry>> getAllTranslations(
    String languagePair, {
    int? limit,
    int? offset,
    String orderBy = 'frequency DESC',
  }) async {
    final cache = _ensureLoaded(languagePair.toLowerCase());
    var list = cache.bySource.values.toList();
    // orderBy: 'frequency DESC' by default
    if (orderBy.toLowerCase().contains('frequency')) {
      final desc = orderBy.toLowerCase().contains('desc');
      list.sort((a, b) => desc ? b.frequency.compareTo(a.frequency) : a.frequency.compareTo(b.frequency));
    }
    if (offset != null && offset > 0 && offset < list.length) {
      list = list.sublist(offset);
    }
    if (limit != null && limit < list.length) {
      list = list.sublist(0, limit);
    }
    return list;
  }
  
  /// Удалить перевод
  Future<bool> deleteTranslation(int id) async {
    // удалить по id в любой языковой паре (обычно вызывается зная пару)
    for (final cache in _langCaches.values) {
      DictionaryEntry? toRemove;
      for (final e in cache.bySource.values) {
        if (e.id == id) {
          toRemove = e;
          break;
        }
      }
      if (toRemove != null) {
        cache.bySource.remove(toRemove.sourceWord);
        final file = storage.dictFile(cache.lang);
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
        'total_words': 0,
        'avg_frequency': 0.0,
        'max_frequency': 0,
      };
    }
    final total = cache.bySource.length;
    final maxFreq = cache.bySource.values.map((e) => e.frequency).fold<int>(0, (p, c) => c > p ? c : p);
    final avg = cache.bySource.values.map((e) => e.frequency).fold<int>(0, (a, b) => a + b) / total;
    return {
      'language_pair': languagePair,
      'total_words': total,
      'avg_frequency': avg,
      'max_frequency': maxFreq,
    };
  }
  
  /// Получить топ наиболее частых слов
  Future<List<DictionaryEntry>> getTopWords(
    String languagePair, {
    int limit = 100,
  }) async {
    final cache = _ensureLoaded(languagePair.toLowerCase());
    final list = cache.bySource.values.toList()
      ..sort((a, b) => b.frequency.compareTo(a.frequency));
    return list.length > limit ? list.sublist(0, limit) : list;
  }
}

class _DictLangCache {
  final String lang;
  final FileStorageService storage;
  final Map<String, DictionaryEntry> bySource = {};
  int maxId = 0;

  _DictLangCache(this.lang, this.storage) {
    _load();
  }

  void _load() {
    final file = storage.dictFile(lang);
    if (!file.existsSync()) return;
    final lines = file.readAsLinesSync();
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final map = jsonDecode(line) as Map<String, dynamic>;
        final entry = DictionaryEntry.fromMap(map);
        bySource[entry.sourceWord] = entry;
        if (entry.id != null && entry.id! > maxId) maxId = entry.id!;
      } catch (_) {
        // skip
      }
    }
  }
}
