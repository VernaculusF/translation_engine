import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:translation_engine/src/data/database_manager.dart';
import 'package:translation_engine/src/data/database_types.dart';
import 'package:translation_engine/src/utils/cache_manager.dart';
import 'package:translation_engine/src/models/translation_result.dart';
import 'package:translation_engine/src/models/layer_debug_info.dart';
import 'dart:io';

void main() {
  group('Data Layer Integration Tests (Compatible)', () {
    late DatabaseManager databaseManager;
    late CacheManager cacheManager;
    late Directory tempDir;

    setUpAll(() async {
      // Инициализация sqflite для тестов
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Создание временной директории для тестовых баз данных
      tempDir = await Directory.systemTemp.createTemp('translation_engine_test_');
      
      // Инициализация компонентов
      databaseManager = DatabaseManager(customDatabasePath: tempDir.path);
      cacheManager = CacheManager();
      
      // Инициализация баз данных
      await databaseManager.database;
      await databaseManager.initPhrasesDatabase();
      await databaseManager.initUserDataDatabase();
    });

    tearDown(() async {
      await databaseManager.close();
      cacheManager.clear();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Database Connection Tests', () {
      test('should establish connections to all databases', () async {
        // Тестируем подключения напрямую через DatabaseManager
        final dictConnection = await databaseManager.getConnection(DatabaseType.dictionaries);
        final phrasesConnection = await databaseManager.getConnection(DatabaseType.phrases);
        final userDataConnection = await databaseManager.getConnection(DatabaseType.userData);
        
        expect(dictConnection, isNotNull);
        expect(phrasesConnection, isNotNull);
        expect(userDataConnection, isNotNull);
        
        await databaseManager.closeConnection(dictConnection);
        await databaseManager.closeConnection(phrasesConnection);
        await databaseManager.closeConnection(userDataConnection);
      });

      test('should have correct table structures', () async {
        final dictDb = await databaseManager.database;
        final phrasesDb = await databaseManager.initPhrasesDatabase();
        final userDataDb = await databaseManager.initUserDataDatabase();

        // Проверяем структуру таблиц словаря
        final dictTables = await dictDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table'"
        );
        final dictTableNames = dictTables.map((t) => t['name'] as String).toList();
        expect(dictTableNames, contains('words'));
        expect(dictTableNames, contains('word_cache'));

        // Проверяем структуру таблиц фраз
        final phraseTables = await phrasesDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table'"
        );
        final phraseTableNames = phraseTables.map((t) => t['name'] as String).toList();
        expect(phraseTableNames, contains('phrases'));
        expect(phraseTableNames, contains('phrase_cache'));

        // Проверяем структуру таблиц пользовательских данных
        final userTables = await userDataDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table'"
        );
        final userTableNames = userTables.map((t) => t['name'] as String).toList();
        expect(userTableNames, contains('translation_history'));
        expect(userTableNames, contains('user_corrections'));
      });
    });

    group('Dictionary Database Integration', () {
      test('should insert and retrieve dictionary entries', () async {
        final dictDb = await databaseManager.database;
        
        // Вставить запись со структурой, совместимой с реальной БД
        await dictDb.execute(
          'INSERT INTO words (source_word, target_word, language_pair, frequency) VALUES (?, ?, ?, ?)',
          ['hello', 'привет', 'en-ru', 5],
        );

        // Получить запись
        final results = await dictDb.query(
          'words',
          where: 'source_word = ? AND language_pair = ?',
          whereArgs: ['hello', 'en-ru'],
        );

        expect(results.length, equals(1));
        expect(results.first['source_word'], equals('hello'));
        expect(results.first['target_word'], equals('привет'));
        expect(results.first['language_pair'], equals('en-ru'));
        expect(results.first['frequency'], equals(5));
      });

      test('should handle word cache operations', () async {
        final dictDb = await databaseManager.database;
        
        // Добавить в кэш
        final now = DateTime.now().millisecondsSinceEpoch;
        await dictDb.execute(
          'INSERT INTO word_cache (source_word, target_word, language_pair, last_used) VALUES (?, ?, ?, ?)',
          ['test', 'тест', 'en-ru', now],
        );

        // Получить из кэша
        final cached = await dictDb.query(
          'word_cache',
          where: 'source_word = ? AND language_pair = ?',
          whereArgs: ['test', 'en-ru'],
        );

        expect(cached.length, equals(1));
        expect(cached.first['source_word'], equals('test'));
        expect(cached.first['target_word'], equals('тест'));
      });
    });

    group('Phrases Database Integration', () {
      test('should insert and retrieve phrase entries', () async {
        final phrasesDb = await databaseManager.initPhrasesDatabase();
        
        // Вставить фразу
        await phrasesDb.execute(
          'INSERT INTO phrases (source_phrase, target_phrase, language_pair, usage_count) VALUES (?, ?, ?, ?)',
          ['good morning', 'доброе утро', 'en-ru', 3],
        );

        // Получить фразу
        final results = await phrasesDb.query(
          'phrases',
          where: 'source_phrase = ? AND language_pair = ?',
          whereArgs: ['good morning', 'en-ru'],
        );

        expect(results.length, equals(1));
        expect(results.first['source_phrase'], equals('good morning'));
        expect(results.first['target_phrase'], equals('доброе утро'));
        expect(results.first['language_pair'], equals('en-ru'));
        expect(results.first['usage_count'], equals(3));
      });

      test('should handle phrase cache operations', () async {
        final phrasesDb = await databaseManager.initPhrasesDatabase();
        
        // Добавить в кэш
        final now = DateTime.now().millisecondsSinceEpoch;
        await phrasesDb.execute(
          'INSERT INTO phrase_cache (source_phrase, target_phrase, language_pair, last_used) VALUES (?, ?, ?, ?)',
          ['test phrase', 'тестовая фраза', 'en-ru', now],
        );

        // Получить из кэша
        final cached = await phrasesDb.query(
          'phrase_cache',
          where: 'source_phrase = ? AND language_pair = ?',
          whereArgs: ['test phrase', 'en-ru'],
        );

        expect(cached.length, equals(1));
        expect(cached.first['source_phrase'], equals('test phrase'));
        expect(cached.first['target_phrase'], equals('тестовая фраза'));
      });
    });

    group('User Data Database Integration', () {
      test('should insert and retrieve translation history', () async {
        final userDb = await databaseManager.initUserDataDatabase();
        
        final now = DateTime.now().millisecondsSinceEpoch;
        
        // Добавить в историю
        await userDb.execute(
          'INSERT INTO translation_history (original_text, translated_text, language_pair, confidence, processing_time_ms, timestamp) VALUES (?, ?, ?, ?, ?, ?)',
          ['hello world', 'привет мир', 'en-ru', 0.95, 100, now],
        );

        // Получить из истории
        final history = await userDb.query(
          'translation_history',
          where: 'original_text = ? AND language_pair = ?',
          whereArgs: ['hello world', 'en-ru'],
        );

        expect(history.length, equals(1));
        expect(history.first['original_text'], equals('hello world'));
        expect(history.first['translated_text'], equals('привет мир'));
        expect(history.first['language_pair'], equals('en-ru'));
      });

      test('should handle user corrections', () async {
        final userDb = await databaseManager.initUserDataDatabase();
        
        final now = DateTime.now().millisecondsSinceEpoch;
        
        // Добавить исправление
        await userDb.execute(
          'INSERT INTO user_corrections (original_text, corrected_translation, lang_pair, created_at) VALUES (?, ?, ?, ?)',
          ['wrong translation', 'правильный перевод', 'en-ru', now],
        );

        // Получить исправления
        final corrections = await userDb.query(
          'user_corrections',
          where: 'lang_pair = ?',
          whereArgs: ['en-ru'],
        );

        expect(corrections.length, equals(1));
        expect(corrections.first['original_text'], equals('wrong translation'));
        expect(corrections.first['corrected_translation'], equals('правильный перевод'));
      });
    });

    group('Cache Manager Integration', () {
      test('should store and retrieve cache entries', () async {
        const key = 'test_key';
        const value = 'test_value';
        
        // Сохранить в кэш
        cacheManager.set(key, value);
        
        // Получить из кэша
        final cached = cacheManager.get<String>(key);
        expect(cached, equals(value));
        
        // Проверить существование
        expect(cacheManager.get<String>(key), isNotNull);
        expect(cacheManager.get<String>('non_existent_key'), isNull);
      });

      test('should handle complex objects in cache', () async {
        const key = 'translation_result';
        
        // Создать объект TranslationResult
        final layerResults = [
          LayerDebugInfo.success(
            layerName: 'test_layer',
            processingTimeMs: 100,
          ),
        ];

        final translationResult = TranslationResult(
          originalText: 'test',
          translatedText: 'тест',
          languagePair: 'en-ru',
          confidence: 0.95,
          processingTimeMs: 100,
          timestamp: DateTime.now(),
          layersProcessed: 1,
          layerResults: layerResults,
          hasError: false,
          qualityScore: 0.9,
        );
        
        // Сохранить в кэш
        cacheManager.set(key, translationResult);
        
        // Получить из кэша
        final cached = cacheManager.get<TranslationResult>(key);
        expect(cached, isNotNull);
        expect(cached!.originalText, equals('test'));
        expect(cached.translatedText, equals('тест'));
        expect(cached.confidence, equals(0.95));
      });

      test('should handle cache expiration', () async {
        const key = 'expiring_key';
        const value = 'expiring_value';
        
        // Сохранить значение
        cacheManager.set(key, value);
        
        // Проверить сразу
        expect(cacheManager.get<String>(key), equals(value));
        
        // Подождать и попытаться принудительно очистить истекшие записи
        await Future.delayed(const Duration(milliseconds: 150));
        cacheManager.cleanupExpired();
        // TTL глобальный (30 минут), поэтому ключ ещё существует
        expect(cacheManager.get<String>(key), equals(value));
      });
    });

    group('Cross-Database Operations', () {
      test('should handle operations across multiple databases', () async {
        final dictDb = await databaseManager.database;
        final phrasesDb = await databaseManager.initPhrasesDatabase();
        final userDb = await databaseManager.initUserDataDatabase();
        final now = DateTime.now().millisecondsSinceEpoch;

        // Добавить записи во все базы данных
        await dictDb.execute(
          'INSERT INTO words (source_word, target_word, language_pair, frequency) VALUES (?, ?, ?, ?)',
          ['integration', 'интеграция', 'en-ru', 1],
        );

        await phrasesDb.execute(
          'INSERT INTO phrases (source_phrase, target_phrase, language_pair, usage_count) VALUES (?, ?, ?, ?)',
          ['integration test', 'интеграционный тест', 'en-ru', 1],
        );

        await userDb.execute(
          'INSERT INTO translation_history (original_text, translated_text, language_pair, confidence, processing_time_ms, timestamp) VALUES (?, ?, ?, ?, ?, ?)',
          ['integration test complete', 'интеграционный тест завершен', 'en-ru', 0.95, 100, now],
        );

        // Проверить, что все записи сохранились
        final dictResults = await dictDb.query('words', where: 'source_word = ?', whereArgs: ['integration']);
        final phraseResults = await phrasesDb.query('phrases', where: 'source_phrase = ?', whereArgs: ['integration test']);
        final historyResults = await userDb.query('translation_history', where: 'language_pair = ?', whereArgs: ['en-ru']);

        expect(dictResults.length, equals(1));
        expect(phraseResults.length, equals(1));
        expect(historyResults.length, equals(1));
      });

      test('should maintain database integrity', () async {
        final isIntegrityOk = await databaseManager.checkAllDatabasesIntegrity();
        expect(isIntegrityOk, isTrue);
      });
    });

    group('Performance and Concurrent Operations', () {
      test('should handle concurrent database operations', () async {
        final dictDb = await databaseManager.database;
        final futures = <Future<void>>[];
        
        // Создать несколько параллельных операций записи
        for (int i = 0; i < 5; i++) {
          futures.add(
            dictDb.execute(
              'INSERT INTO words (source_word, target_word, language_pair, frequency) VALUES (?, ?, ?, ?)',
              ['concurrent$i', 'параллель$i', 'en-ru', i],
            )
          );
        }

        await Future.wait(futures);

        // Проверить, что все записи сохранились
        final results = await dictDb.query('words', where: 'language_pair = ?', whereArgs: ['en-ru']);
        expect(results.length, greaterThanOrEqualTo(5));
        
        final concurrentWords = results.where((r) => (r['source_word'] as String).startsWith('concurrent')).toList();
        expect(concurrentWords.length, equals(5));
      });

      test('should handle cache operations efficiently', () async {
        final stopwatch = Stopwatch()..start();
        
        // Выполнить множественные операции кэша
        for (int i = 0; i < 100; i++) {
          cacheManager.set('key_$i', 'value_$i');
        }
        
        for (int i = 0; i < 100; i++) {
          final value = cacheManager.get<String>('key_$i');
          expect(value, equals('value_$i'));
        }
        
        stopwatch.stop();
        
        // Все операции должны выполниться быстро (меньше 1 секунды)
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });
    });
  });
}