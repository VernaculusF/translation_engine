import 'package:flutter_test/flutter_test.dart';
import 'package:translation_engine/src/utils/cache_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WordCacheEntry', () {
    test('should create from map correctly', () {
      final map = {
        'word': 'hello',
        'translation': 'привет',
        'lang_pair': 'en-ru',
        'frequency': 100,
        'last_used': 1234567890,
      };

      final entry = WordCacheEntry.fromMap(map);

      expect(entry.word, equals('hello'));
      expect(entry.translation, equals('привет'));
      expect(entry.langPair, equals('en-ru'));
      expect(entry.frequency, equals(100));
      expect(entry.lastUsed, equals(1234567890));
    });

    test('should convert to map correctly', () {
      final entry = WordCacheEntry(
        word: 'test',
        translation: 'тест',
        langPair: 'en-ru',
        frequency: 50,
        lastUsed: 9876543210,
      );

      final map = entry.toMap();

      expect(map['word'], equals('test'));
      expect(map['translation'], equals('тест'));
      expect(map['lang_pair'], equals('en-ru'));
      expect(map['frequency'], equals(50));
      expect(map['last_used'], equals(9876543210));
    });

    test('should generate correct cache key', () {
      final entry = WordCacheEntry(
        word: 'key',
        translation: 'ключ',
        langPair: 'en-ru',
        frequency: 0,
        lastUsed: 0,
      );

      expect(entry.cacheKey, equals('key_en-ru'));
    });

    test('should handle missing frequency in fromMap', () {
      final map = {
        'word': 'hello',
        'translation': 'привет',
        'lang_pair': 'en-ru',
        'last_used': 1234567890,
        // frequency отсутствует
      };

      final entry = WordCacheEntry.fromMap(map);
      expect(entry.frequency, equals(0)); // default value
    });
  });

  group('PhraseCacheEntry', () {
    test('should create from map correctly', () {
      final map = {
        'phrase': 'good morning',
        'translation': 'доброе утро',
        'lang_pair': 'en-ru',
        'usage_count': 25,
        'last_used': 1234567890,
      };

      final entry = PhraseCacheEntry.fromMap(map);

      expect(entry.phrase, equals('good morning'));
      expect(entry.translation, equals('доброе утро'));
      expect(entry.langPair, equals('en-ru'));
      expect(entry.usageCount, equals(25));
      expect(entry.lastUsed, equals(1234567890));
    });

    test('should convert to map correctly', () {
      final entry = PhraseCacheEntry(
        phrase: 'how are you',
        translation: 'как дела',
        langPair: 'en-ru',
        usageCount: 10,
        lastUsed: 9876543210,
      );

      final map = entry.toMap();

      expect(map['phrase'], equals('how are you'));
      expect(map['translation'], equals('как дела'));
      expect(map['lang_pair'], equals('en-ru'));
      expect(map['usage_count'], equals(10));
      expect(map['last_used'], equals(9876543210));
    });

    test('should generate correct cache key', () {
      final entry = PhraseCacheEntry(
        phrase: 'test phrase',
        translation: 'тестовая фраза',
        langPair: 'en-ru',
        usageCount: 0,
        lastUsed: 0,
      );

      expect(entry.cacheKey, equals('test phrase_en-ru'));
    });
  });

  group('CacheManager', () {
    late CacheManager cache;

    setUp(() {
      cache = CacheManager();
      cache.clear(); // Очищаем перед каждым тестом
    });

    tearDown(() {
      cache.clear(); // Очищаем после каждого теста
    });

    group('Singleton Pattern', () {
      test('should return same instance', () {
        final instance1 = CacheManager();
        final instance2 = CacheManager();
        expect(instance1, same(instance2));
      });
    });

    group('Words Cache', () {
      test('should store and retrieve word correctly', () {
        final entry = WordCacheEntry(
          word: 'hello',
          translation: 'привет',
          langPair: 'en-ru',
          frequency: 100,
          lastUsed: DateTime.now().millisecondsSinceEpoch,
        );

        cache.putWord(entry);
        final retrieved = cache.getWord('hello', 'en-ru');

        expect(retrieved, isNotNull);
        expect(retrieved!.word, equals('hello'));
        expect(retrieved.translation, equals('привет'));
      });

      test('should return null for non-existent word', () {
        final retrieved = cache.getWord('nonexistent', 'en-ru');
        expect(retrieved, isNull);
      });

      test('should update lastUsed when retrieving word', () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final entry = WordCacheEntry(
          word: 'test',
          translation: 'тест',
          langPair: 'en-ru',
          frequency: 50,
          lastUsed: now - 1000, // 1 second ago
        );

        cache.putWord(entry);
        
        // Небольшая задержка
        await Future.delayed(Duration(milliseconds: 10));
        
        final retrieved = cache.getWord('test', 'en-ru');
        expect(retrieved!.lastUsed, greaterThan(now - 1000));
      });

      test('should implement LRU eviction for words', () {
        // Заполняем кэш до лимита + 1
        for (int i = 0; i <= CacheManager.MAX_WORDS_CACHE; i++) {
          final entry = WordCacheEntry(
            word: 'word$i',
            translation: 'слово$i',
            langPair: 'en-ru',
            frequency: i,
            lastUsed: DateTime.now().millisecondsSinceEpoch,
          );
          cache.putWord(entry);
        }

        // Кэш должен содержать максимальное количество элементов
        expect(cache.wordsCount, equals(CacheManager.MAX_WORDS_CACHE));
        
        // Первый элемент (word0) должен быть удален
        expect(cache.getWord('word0', 'en-ru'), isNull);
        
        // Последний элемент должен быть доступен
        expect(cache.getWord('word${CacheManager.MAX_WORDS_CACHE}', 'en-ru'), isNotNull);
      });

      test('should handle TTL expiration for words', () {
        final expiredTime = DateTime.now().millisecondsSinceEpoch - 
                           CacheManager.CACHE_TTL_MS - 1000; // Expired

        final entry = WordCacheEntry(
          word: 'expired',
          translation: 'истекший',
          langPair: 'en-ru',
          frequency: 10,
          lastUsed: expiredTime,
        );

        cache.putWord(entry);
        
        // После putWord entry.lastUsed обновится, но мы можем вернуть его назад
        entry.lastUsed = expiredTime;
        
        final retrieved = cache.getWord('expired', 'en-ru');
        expect(retrieved, isNull);
      });

      test('should update hit/miss metrics for words', () {
        final initialMetrics = cache.metrics;
        expect(initialMetrics['word_hits'], equals(0));
        expect(initialMetrics['word_misses'], equals(0));

        // Miss
        cache.getWord('nonexistent', 'en-ru');
        expect(cache.metrics['word_misses'], equals(1));

        // Hit
        final entry = WordCacheEntry(
          word: 'hit',
          translation: 'попадание',
          langPair: 'en-ru',
          frequency: 10,
          lastUsed: DateTime.now().millisecondsSinceEpoch,
        );
        cache.putWord(entry);
        cache.getWord('hit', 'en-ru');
        
        expect(cache.metrics['word_hits'], equals(1));
      });

      test('should check word existence without affecting LRU', () {
        final entry = WordCacheEntry(
          word: 'check',
          translation: 'проверить',
          langPair: 'en-ru',
          frequency: 10,
          lastUsed: DateTime.now().millisecondsSinceEpoch,
        );

        cache.putWord(entry);
        
        expect(cache.containsWord('check', 'en-ru'), isTrue);
        expect(cache.containsWord('nonexistent', 'en-ru'), isFalse);
        
        // Metrics should not be affected
        expect(cache.metrics['word_hits'], equals(0));
        expect(cache.metrics['word_misses'], equals(0));
      });
    });

    group('Phrases Cache', () {
      test('should store and retrieve phrase correctly', () {
        final entry = PhraseCacheEntry(
          phrase: 'good morning',
          translation: 'доброе утро',
          langPair: 'en-ru',
          usageCount: 25,
          lastUsed: DateTime.now().millisecondsSinceEpoch,
        );

        cache.putPhrase(entry);
        final retrieved = cache.getPhrase('good morning', 'en-ru');

        expect(retrieved, isNotNull);
        expect(retrieved!.phrase, equals('good morning'));
        expect(retrieved.translation, equals('доброе утро'));
      });

      test('should return null for non-existent phrase', () {
        final retrieved = cache.getPhrase('nonexistent phrase', 'en-ru');
        expect(retrieved, isNull);
      });

      test('should implement LRU eviction for phrases', () {
        // Заполняем кэш до лимита + 1
        for (int i = 0; i <= CacheManager.MAX_PHRASES_CACHE; i++) {
          final entry = PhraseCacheEntry(
            phrase: 'phrase $i',
            translation: 'фраза $i',
            langPair: 'en-ru',
            usageCount: i,
            lastUsed: DateTime.now().millisecondsSinceEpoch,
          );
          cache.putPhrase(entry);
        }

        // Кэш должен содержать максимальное количество элементов
        expect(cache.phrasesCount, equals(CacheManager.MAX_PHRASES_CACHE));
        
        // Первый элемент должен быть удален
        expect(cache.getPhrase('phrase 0', 'en-ru'), isNull);
        
        // Последний элемент должен быть доступен
        expect(cache.getPhrase('phrase ${CacheManager.MAX_PHRASES_CACHE}', 'en-ru'), isNotNull);
      });

      test('should update hit/miss metrics for phrases', () {
        final initialMetrics = cache.metrics;
        expect(initialMetrics['phrase_hits'], equals(0));
        expect(initialMetrics['phrase_misses'], equals(0));

        // Miss
        cache.getPhrase('nonexistent phrase', 'en-ru');
        expect(cache.metrics['phrase_misses'], equals(1));

        // Hit
        final entry = PhraseCacheEntry(
          phrase: 'test phrase',
          translation: 'тестовая фраза',
          langPair: 'en-ru',
          usageCount: 5,
          lastUsed: DateTime.now().millisecondsSinceEpoch,
        );
        cache.putPhrase(entry);
        cache.getPhrase('test phrase', 'en-ru');
        
        expect(cache.metrics['phrase_hits'], equals(1));
      });
    });

    group('LRU Algorithm', () {
      test('should move accessed items to end (words)', () {
        // Добавляем несколько записей
        for (int i = 0; i < 5; i++) {
          cache.putWord(WordCacheEntry(
            word: 'word$i',
            translation: 'слово$i',
            langPair: 'en-ru',
            frequency: i,
            lastUsed: DateTime.now().millisecondsSinceEpoch,
          ));
        }

        // Получаем доступ к первому элементу (должен переместиться в конец)
        cache.getWord('word0', 'en-ru');
        
        final keys = cache.wordKeys;
        expect(keys.last, equals('word0_en-ru')); // Should be at end
      });

      test('should move accessed items to end (phrases)', () {
        // Добавляем несколько записей
        for (int i = 0; i < 5; i++) {
          cache.putPhrase(PhraseCacheEntry(
            phrase: 'phrase $i',
            translation: 'фраза $i',
            langPair: 'en-ru',
            usageCount: i,
            lastUsed: DateTime.now().millisecondsSinceEpoch,
          ));
        }

        // Получаем доступ к первому элементу
        cache.getPhrase('phrase 0', 'en-ru');
        
        final keys = cache.phraseKeys;
        expect(keys.last, equals('phrase 0_en-ru')); // Should be at end
      });

      test('should maintain insertion order when no access', () {
        final entries = <String>[];
        for (int i = 0; i < 5; i++) {
          final word = 'word$i';
          entries.add('${word}_en-ru');
          cache.putWord(WordCacheEntry(
            word: word,
            translation: 'слово$i',
            langPair: 'en-ru',
            frequency: i,
            lastUsed: DateTime.now().millisecondsSinceEpoch,
          ));
        }

        final keys = cache.wordKeys;
        expect(keys, equals(entries));
      });
    });

    group('Memory Management', () {
      test('should calculate estimated memory usage', () {
        // Add some entries
        cache.putWord(WordCacheEntry(
          word: 'test',
          translation: 'тест',
          langPair: 'en-ru',
          frequency: 10,
          lastUsed: DateTime.now().millisecondsSinceEpoch,
        ));

        cache.putPhrase(PhraseCacheEntry(
          phrase: 'test phrase',
          translation: 'тестовая фраза',
          langPair: 'en-ru',
          usageCount: 5,
          lastUsed: DateTime.now().millisecondsSinceEpoch,
        ));

        final memoryUsage = cache.estimatedMemoryUsage;
        expect(memoryUsage, greaterThan(0));
        
        // Basic sanity check: should be reasonable for our small test data
        expect(memoryUsage, lessThan(10000)); // Less than 10KB for 2 entries
      });

      test('should cleanup expired entries', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final expiredTime = now - CacheManager.CACHE_TTL_MS - 1000;

        // Add expired entry
        cache.putWord(WordCacheEntry(
          word: 'expired',
          translation: 'истекший',
          langPair: 'en-ru',
          frequency: 10,
          lastUsed: expiredTime,
        ));

        // Add valid entry
        cache.putWord(WordCacheEntry(
          word: 'valid',
          translation: 'действительный',
          langPair: 'en-ru',
          frequency: 10,
          lastUsed: now,
        ));

        expect(cache.wordsCount, equals(2));

        // Модифицируем expired entry после вставки
        final expiredEntry = cache.getWord('expired', 'en-ru');
        if (expiredEntry != null) {
          expiredEntry.lastUsed = expiredTime;
        }

        final removedCount = cache.cleanupExpired();
        
        expect(removedCount, equals(1));
        expect(cache.wordsCount, equals(1));
        expect(cache.containsWord('valid', 'en-ru'), isTrue);
        expect(cache.containsWord('expired', 'en-ru'), isFalse);
      });
    });

    group('Cache Operations', () {
      test('should clear all caches', () {
        // Add some data
        cache.putWord(WordCacheEntry(
          word: 'test',
          translation: 'тест',
          langPair: 'en-ru',
          frequency: 10,
          lastUsed: DateTime.now().millisecondsSinceEpoch,
        ));

        cache.putPhrase(PhraseCacheEntry(
          phrase: 'test phrase',
          translation: 'тестовая фраза',
          langPair: 'en-ru',
          usageCount: 5,
          lastUsed: DateTime.now().millisecondsSinceEpoch,
        ));

        // Generate some metrics
        cache.getWord('test', 'en-ru');
        cache.getPhrase('test phrase', 'en-ru');

        expect(cache.totalCount, equals(2));
        expect(cache.metrics['word_hits'], equals(1));

        cache.clear();

        expect(cache.totalCount, equals(0));
        expect(cache.metrics['word_hits'], equals(0));
        expect(cache.metrics['phrase_hits'], equals(0));
      });

      test('should clear only words cache', () {
        // Add data to both caches
        cache.putWord(WordCacheEntry(
          word: 'word',
          translation: 'слово',
          langPair: 'en-ru',
          frequency: 10,
          lastUsed: DateTime.now().millisecondsSinceEpoch,
        ));

        cache.putPhrase(PhraseCacheEntry(
          phrase: 'phrase',
          translation: 'фраза',
          langPair: 'en-ru',
          usageCount: 5,
          lastUsed: DateTime.now().millisecondsSinceEpoch,
        ));

        expect(cache.wordsCount, equals(1));
        expect(cache.phrasesCount, equals(1));

        cache.clearWords();

        expect(cache.wordsCount, equals(0));
        expect(cache.phrasesCount, equals(1)); // Should remain
      });

      test('should clear only phrases cache', () {
        // Add data to both caches
        cache.putWord(WordCacheEntry(
          word: 'word',
          translation: 'слово',
          langPair: 'en-ru',
          frequency: 10,
          lastUsed: DateTime.now().millisecondsSinceEpoch,
        ));

        cache.putPhrase(PhraseCacheEntry(
          phrase: 'phrase',
          translation: 'фраза',
          langPair: 'en-ru',
          usageCount: 5,
          lastUsed: DateTime.now().millisecondsSinceEpoch,
        ));

        expect(cache.wordsCount, equals(1));
        expect(cache.phrasesCount, equals(1));

        cache.clearPhrases();

        expect(cache.wordsCount, equals(1)); // Should remain
        expect(cache.phrasesCount, equals(0));
      });
    });

    group('Metrics and Statistics', () {
      test('should calculate correct hit rates', () {
        // Add entries
        cache.putWord(WordCacheEntry(
          word: 'word1',
          translation: 'слово1',
          langPair: 'en-ru',
          frequency: 10,
          lastUsed: DateTime.now().millisecondsSinceEpoch,
        ));

        cache.putPhrase(PhraseCacheEntry(
          phrase: 'phrase1',
          translation: 'фраза1',
          langPair: 'en-ru',
          usageCount: 5,
          lastUsed: DateTime.now().millisecondsSinceEpoch,
        ));

        // Generate hits and misses
        cache.getWord('word1', 'en-ru'); // Hit
        cache.getWord('nonexistent', 'en-ru'); // Miss
        cache.getPhrase('phrase1', 'en-ru'); // Hit
        cache.getPhrase('nonexistent', 'en-ru'); // Miss

        expect(cache.wordHitRate, equals(0.5)); // 1 hit / 2 requests
        expect(cache.phraseHitRate, equals(0.5)); // 1 hit / 2 requests
        expect(cache.overallHitRate, equals(0.5)); // 2 hits / 4 requests
      });

      test('should provide comprehensive metrics', () {
        // Add some data
        cache.putWord(WordCacheEntry(
          word: 'test',
          translation: 'тест',
          langPair: 'en-ru',
          frequency: 10,
          lastUsed: DateTime.now().millisecondsSinceEpoch,
        ));

        final metrics = cache.metrics;

        expect(metrics, containsPair('words_count', 1));
        expect(metrics, containsPair('phrases_count', 0));
        expect(metrics, containsPair('total_count', 1));
        expect(metrics, containsPair('max_words', CacheManager.MAX_WORDS_CACHE));
        expect(metrics, containsPair('max_phrases', CacheManager.MAX_PHRASES_CACHE));
        expect(metrics, containsPair('ttl_ms', CacheManager.CACHE_TTL_MS));
        expect(metrics.containsKey('estimated_memory_bytes'), isTrue);
        expect(metrics.containsKey('word_hit_rate'), isTrue);
        expect(metrics.containsKey('phrase_hit_rate'), isTrue);
        expect(metrics.containsKey('overall_hit_rate'), isTrue);
      });

      test('should handle zero hit rates', () {
        // No access, should be 0.0
        expect(cache.wordHitRate, equals(0.0));
        expect(cache.phraseHitRate, equals(0.0));
        expect(cache.overallHitRate, equals(0.0));
      });
    });

    group('toString', () {
      test('should provide meaningful string representation', () {
        cache.putWord(WordCacheEntry(
          word: 'test',
          translation: 'тест',
          langPair: 'en-ru',
          frequency: 10,
          lastUsed: DateTime.now().millisecondsSinceEpoch,
        ));

        final string = cache.toString();
        
        expect(string, contains('CacheManager'));
        expect(string, contains('words: 1'));
        expect(string, contains('phrases: 0'));
        expect(string, contains('hitRate:'));
        expect(string, contains('memory:'));
      });
    });
  });
}

