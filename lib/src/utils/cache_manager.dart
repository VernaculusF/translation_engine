// ignore_for_file: constant_identifier_names

import 'dart:collection';

/// Entry для кэша слов
class WordCacheEntry {
  final String word;
  final String translation;
  final String langPair;
  final int frequency;
  int lastUsed;

  WordCacheEntry({
    required this.word,
    required this.translation,
    required this.langPair,
    required this.frequency,
    required this.lastUsed,
  });

  /// Создание из Map (для загрузки из БД)
  factory WordCacheEntry.fromMap(Map<String, dynamic> map) {
    return WordCacheEntry(
      word: map['word'] as String,
      translation: map['translation'] as String,
      langPair: map['lang_pair'] as String,
      frequency: (map['frequency'] as int?) ?? 0,
      lastUsed: map['last_used'] as int,
    );
  }

  /// Конвертация в Map (для сохранения в БД)
  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'translation': translation,
      'lang_pair': langPair,
      'frequency': frequency,
      'last_used': lastUsed,
    };
  }

  /// Ключ для кэша
  String get cacheKey => '${word}_$langPair';

  @override
  String toString() => 'WordCacheEntry($word -> $translation [$langPair])';
}

/// Entry для кэша фраз
class PhraseCacheEntry {
  final String phrase;
  final String translation;
  final String langPair;
  final int usageCount;
  int lastUsed;

  PhraseCacheEntry({
    required this.phrase,
    required this.translation,
    required this.langPair,
    required this.usageCount,
    required this.lastUsed,
  });

  /// Создание из Map (для загрузки из БД)
  factory PhraseCacheEntry.fromMap(Map<String, dynamic> map) {
    return PhraseCacheEntry(
      phrase: map['phrase'] as String,
      translation: map['translation'] as String,
      langPair: map['lang_pair'] as String,
      usageCount: (map['usage_count'] as int?) ?? 0,
      lastUsed: map['last_used'] as int,
    );
  }

  /// Конвертация в Map (для сохранения в БД)
  Map<String, dynamic> toMap() {
    return {
      'phrase': phrase,
      'translation': translation,
      'lang_pair': langPair,
      'usage_count': usageCount,
      'last_used': lastUsed,
    };
  }

  /// Ключ для кэша
  String get cacheKey => '${phrase}_$langPair';

  @override
  String toString() => 'PhraseCacheEntry($phrase -> $translation [$langPair])';
}

/// LRU Cache Manager для слов и фраз
class CacheManager {
  // Лимиты согласно AiRules.md
  static const int MAX_WORDS_CACHE = 10000;
  static const int MAX_PHRASES_CACHE = 5000;
  
  // Время жизни записей в кэше (в миллисекундах)
  static const int CACHE_TTL_MS = 30 * 60 * 1000; // 30 минут
  
  // Singleton pattern
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  // LRU кэши с использованием LinkedHashMap для O(1) операций
  final LinkedHashMap<String, WordCacheEntry> _wordsCache = LinkedHashMap();
  final LinkedHashMap<String, PhraseCacheEntry> _phrasesCache = LinkedHashMap();
  
  // Счетчики для метрик
  int _wordHits = 0;
  int _wordMisses = 0;
  int _phraseHits = 0;
  int _phraseMisses = 0;
  
  // Дополнительный кэш для общих данных
  final Map<String, dynamic> _genericCache = {};

  /// Получение слова из кэша
  WordCacheEntry? getWord(String word, String langPair) {
    final key = '${word}_$langPair';
    final entry = _wordsCache.remove(key); // Remove для перемещения в конец
    
    if (entry != null) {
      // Проверяем TTL
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - entry.lastUsed > CACHE_TTL_MS) {
        _wordMisses++;
        return null; // Expired
      }
      
      // Обновляем время последнего использования
      entry.lastUsed = now;
      
      // Возвращаем в конец (most recently used)
      _wordsCache[key] = entry;
      _wordHits++;
      return entry;
    }
    
    _wordMisses++;
    return null;
  }

  /// Добавление слова в кэш
  void putWord(WordCacheEntry entry) {
    final key = entry.cacheKey;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Обновляем время последнего использования
    entry.lastUsed = now;
    
    // Удаляем если уже существует (для обновления позиции)
    _wordsCache.remove(key);
    
    // Добавляем в конец
    _wordsCache[key] = entry;
    
    // Проверяем лимит и удаляем oldest entries
    _evictWordsIfNeeded();
  }

  /// Получение фразы из кэша
  PhraseCacheEntry? getPhrase(String phrase, String langPair) {
    final key = '${phrase}_$langPair';
    final entry = _phrasesCache.remove(key); // Remove для перемещения в конец
    
    if (entry != null) {
      // Проверяем TTL
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - entry.lastUsed > CACHE_TTL_MS) {
        _phraseMisses++;
        return null; // Expired
      }
      
      // Обновляем время последнего использования
      entry.lastUsed = now;
      
      // Возвращаем в конец (most recently used)
      _phrasesCache[key] = entry;
      _phraseHits++;
      return entry;
    }
    
    _phraseMisses++;
    return null;
  }

  /// Добавление фразы в кэш
  void putPhrase(PhraseCacheEntry entry) {
    final key = entry.cacheKey;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Обновляем время последнего использования
    entry.lastUsed = now;
    
    // Удаляем если уже существует (для обновления позиции)
    _phrasesCache.remove(key);
    
    // Добавляем в конец
    _phrasesCache[key] = entry;
    
    // Проверяем лимит и удаляем oldest entries
    _evictPhrasesIfNeeded();
  }

  /// Удаление старых записей из кэша слов при превышении лимита
  void _evictWordsIfNeeded() {
    while (_wordsCache.length > MAX_WORDS_CACHE) {
      // Удаляем первый элемент (least recently used)
      _wordsCache.remove(_wordsCache.keys.first);
    }
  }

  /// Удаление старых записей из кэша фраз при превышении лимита
  void _evictPhrasesIfNeeded() {
    while (_phrasesCache.length > MAX_PHRASES_CACHE) {
      // Удаляем первый элемент (least recently used)
      _phrasesCache.remove(_phrasesCache.keys.first);
    }
  }

  /// Очистка всего кэша
  void clear() {
    _genericCache.clear();
    _wordsCache.clear();
    _phrasesCache.clear();
    _resetMetrics();
  }

  /// Очистка только кэша слов
  void clearWords() {
    _wordsCache.clear();
    _wordHits = 0;
    _wordMisses = 0;
  }

  /// Очистка только кэша фраз
  void clearPhrases() {
    _phrasesCache.clear();
    _phraseHits = 0;
    _phraseMisses = 0;
  }

  /// Удаление истекших записей по TTL
  int cleanupExpired() {
    final now = DateTime.now().millisecondsSinceEpoch;
    int removedCount = 0;

    // Cleanup words cache
    final expiredWords = <String>[];
    for (final entry in _wordsCache.entries) {
      if (now - entry.value.lastUsed > CACHE_TTL_MS) {
        expiredWords.add(entry.key);
      }
    }
    for (final key in expiredWords) {
      _wordsCache.remove(key);
      removedCount++;
    }

    // Cleanup phrases cache
    final expiredPhrases = <String>[];
    for (final entry in _phrasesCache.entries) {
      if (now - entry.value.lastUsed > CACHE_TTL_MS) {
        expiredPhrases.add(entry.key);
      }
    }
    for (final key in expiredPhrases) {
      _phrasesCache.remove(key);
      removedCount++;
    }

    return removedCount;
  }

  /// Получение размера кэша слов
  int get wordsCount => _wordsCache.length;

  /// Получение размера кэша фраз
  int get phrasesCount => _phrasesCache.length;

  /// Общий размер кэша
  int get totalCount => wordsCount + phrasesCount;

  /// Приблизительный размер в памяти (байты)
  int get estimatedMemoryUsage {
    int totalBytes = 0;
    
    // Подсчет для слов (приблизительно)
    for (final entry in _wordsCache.values) {
      totalBytes += entry.word.length * 2; // UTF-16
      totalBytes += entry.translation.length * 2;
      totalBytes += entry.langPair.length * 2;
      totalBytes += 16; // int fields + overhead
    }
    
    // Подсчет для фраз (приблизительно)
    for (final entry in _phrasesCache.values) {
      totalBytes += entry.phrase.length * 2; // UTF-16
      totalBytes += entry.translation.length * 2;
      totalBytes += entry.langPair.length * 2;
      totalBytes += 16; // int fields + overhead
    }
    
    return totalBytes;
  }

  /// Hit rate для слов (0.0 - 1.0)
  double get wordHitRate {
    final total = _wordHits + _wordMisses;
    return total > 0 ? _wordHits / total : 0.0;
  }

  /// Hit rate для фраз (0.0 - 1.0)
  double get phraseHitRate {
    final total = _phraseHits + _phraseMisses;
    return total > 0 ? _phraseHits / total : 0.0;
  }

  /// Общий hit rate
  double get overallHitRate {
    final totalHits = _wordHits + _phraseHits;
    final totalRequests = _wordHits + _wordMisses + _phraseHits + _phraseMisses;
    return totalRequests > 0 ? totalHits / totalRequests : 0.0;
  }

  /// Метрики кэша
  Map<String, dynamic> get metrics {
    return {
      'words_count': wordsCount,
      'phrases_count': phrasesCount,
      'total_count': totalCount,
      'estimated_memory_bytes': estimatedMemoryUsage,
      'word_hits': _wordHits,
      'word_misses': _wordMisses,
      'phrase_hits': _phraseHits,
      'phrase_misses': _phraseMisses,
      'word_hit_rate': wordHitRate,
      'phrase_hit_rate': phraseHitRate,
      'overall_hit_rate': overallHitRate,
      'max_words': MAX_WORDS_CACHE,
      'max_phrases': MAX_PHRASES_CACHE,
      'ttl_ms': CACHE_TTL_MS,
    };
  }

  /// Сброс метрик
  void _resetMetrics() {
    _wordHits = 0;
    _wordMisses = 0;
    _phraseHits = 0;
    _phraseMisses = 0;
  }

  /// Проверка наличия слова в кэше (без влияния на LRU)
  bool containsWord(String word, String langPair) {
    final key = '${word}_$langPair';
    final entry = _wordsCache[key];
    if (entry == null) return false;
    
    // Проверяем TTL
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - entry.lastUsed <= CACHE_TTL_MS;
  }

  /// Проверка наличия фразы в кэше (без влияния на LRU)
  bool containsPhrase(String phrase, String langPair) {
    final key = '${phrase}_$langPair';
    final entry = _phrasesCache[key];
    if (entry == null) return false;
    
    // Проверяем TTL
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - entry.lastUsed <= CACHE_TTL_MS;
  }

  /// Получение всех ключей слов (для отладки)
  List<String> get wordKeys => _wordsCache.keys.toList();

  /// Получение всех ключей фраз (для отладки)
  List<String> get phraseKeys => _phrasesCache.keys.toList();

  /// Общий метод для получения данных из кэша
  T? get<T>(String key) {
    // Проверяем общий кэш сначала
    if (_genericCache.containsKey(key)) {
      return _genericCache[key] as T?;
    }
    
    // Пытаемся найти среди слов
    if (_wordsCache.containsKey(key)) {
      final parts = key.split('_');
      if (parts.length >= 2) {
        final langPair = parts.last;
        final word = parts.sublist(0, parts.length - 1).join('_');
        final entry = getWord(word, langPair);
        return entry as T?;
      }
    }
    
    // Пытаемся найти среди фраз
    if (_phrasesCache.containsKey(key)) {
      final parts = key.split('_');
      if (parts.length >= 2) {
        final langPair = parts.last;
        final phrase = parts.sublist(0, parts.length - 1).join('_');
        final entry = getPhrase(phrase, langPair);
        return entry as T?;
      }
    }
    
    return null;
  }

  /// Общий метод для добавления данных в кэш
  void set<T>(String key, T value) {
    if (value is WordCacheEntry) {
      putWord(value);
    } else if (value is PhraseCacheEntry) {
      putPhrase(value);
    } else {
      // Сохраняем в общий кэш
      _genericCache[key] = value;
    }
  }

  /// Общий метод для удаления из кэша
  bool remove(String key) {
    bool removed = false;
    
    if (_genericCache.containsKey(key)) {
      _genericCache.remove(key);
      removed = true;
    }
    
    if (_wordsCache.containsKey(key)) {
      _wordsCache.remove(key);
      removed = true;
    }
    
    if (_phrasesCache.containsKey(key)) {
      _phrasesCache.remove(key);
      removed = true;
    }
    
    return removed;
  }

  /// Получение всех ключей
  List<String> getAllKeys() {
    return [..._genericCache.keys, ...wordKeys, ...phraseKeys];
  }

  @override
  String toString() {
    return 'CacheManager(words: $wordsCount/$MAX_WORDS_CACHE, '
           'phrases: $phrasesCount/$MAX_PHRASES_CACHE, '
           'hitRate: ${(overallHitRate * 100).toStringAsFixed(1)}%, '
           'memory: ${(estimatedMemoryUsage / 1024 / 1024).toStringAsFixed(2)}MB)';
  }
}