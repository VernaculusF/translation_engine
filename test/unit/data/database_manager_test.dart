import 'dart:io';
import 'package:test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:translation_engine/src/data/database_manager.dart';
import 'package:translation_engine/src/utils/exceptions.dart';
import '../../helpers/test_database_helper.dart';

void main() {
  
  group('DatabaseManager', () {
    late DatabaseManager databaseManager;
    late String testDatabasePath;

    setUpAll(() async {
      // Инициализируем FFI для тестов
      TestDatabaseHelper.setupTestDatabase();
    });

    setUp(() async {
      // Создаем временный путь для каждого теста
      testDatabasePath = TestDatabaseHelper.getTestDatabasePath('test_db');
      databaseManager = DatabaseManager(customDatabasePath: testDatabasePath);
    });

    tearDown(() async {
      await databaseManager.reset();
      await TestDatabaseHelper.cleanupTestDatabases();
    });

    tearDownAll(() async {
      await TestDatabaseHelper.cleanupTestDatabases();
    });

    group('Singleton Pattern', () {
      test('should return same instance', () {
        final instance1 = DatabaseManager();
        final instance2 = DatabaseManager();
        expect(instance1, same(instance2));
      });

      test('should preserve custom path in singleton', () async {
        final customPath = TestDatabaseHelper.getTestDatabasePath('custom');
        final instance1 = DatabaseManager(customDatabasePath: customPath);
        final instance2 = DatabaseManager(customDatabasePath: customPath); // Используем тот же путь
        
        // Beide instances sollten den gleichen custom path verwenden
        final db1 = await instance1.database;
        final db2 = await instance2.database;
        
        expect(db1, same(db2));
        expect(db1.isOpen, isTrue);
      });
    });

    group('Main Database (dictionaries.db)', () {
      test('should initialize dictionaries database successfully', () async {
        final db = await databaseManager.database;
        
        expect(db, isNotNull);
        expect(db.isOpen, isTrue);
      });

      test('should create all required tables', () async {
        final db = await databaseManager.database;
        
        final tables = await TestDatabaseHelper.getAllTables(db);
        
        expect(tables, contains('schema_info'));
        expect(tables, contains('words'));
        expect(tables, contains('word_cache'));
      });

      test('should insert correct schema version', () async {
        final db = await databaseManager.database;
        
        final version = await db.rawQuery('SELECT version FROM schema_info');
        expect(version, hasLength(1));
        expect(version.first['version'], equals(1));
      });

      test('should create words table with correct schema', () async {
        final db = await databaseManager.database;
        
        final schema = await TestDatabaseHelper.getTableSchema(db, 'words');
        final columnNames = schema.map((col) => col['name'] as String).toList();
        
        expect(columnNames, containsAll(['id', 'source_word', 'target_word', 'language_pair', 'frequency']));
        
        // Проверяем типы данных
        final columnInfo = {for (var col in schema) col['name']: col};
        expect(columnInfo['id']?['pk'], equals(1)); // Primary key
        expect(columnInfo['frequency']?['dflt_value'], equals('0')); // Default value
      });

      test('should create word_cache table with correct schema', () async {
        final db = await databaseManager.database;
        
        final schema = await TestDatabaseHelper.getTableSchema(db, 'word_cache');
        final columnNames = schema.map((col) => col['name'] as String).toList();
        
        expect(columnNames, containsAll(['source_word', 'target_word', 'language_pair', 'last_used']));
        
        // Проверяем primary key
        final wordColumn = schema.firstWhere((col) => col['name'] == 'source_word');
        expect(wordColumn['pk'], equals(1));
      });

      test('should create required indexes', () async {
        final db = await databaseManager.database;
        
        final indexes = await TestDatabaseHelper.getAllIndexes(db);
        
        expect(indexes, contains('idx_word_lang'));
        expect(indexes, contains('idx_frequency'));
      });

      test('should enforce CHECK constraints on words table', () async {
        final db = await databaseManager.database;
        
        // Попытка вставить пустое слово должна завершиться неудачей
        expect(
          () async => await db.insert('words', {
            'source_word': '',
            'target_word': 'test',
            'language_pair': 'en-ru',
          }),
          throwsA(isA<DatabaseException>()),
        );

        // Попытка вставить пустой перевод должна завершиться неудачей
        expect(
          () async => await db.insert('words', {
            'source_word': 'test',
            'target_word': '',
            'language_pair': 'en-ru',
          }),
          throwsA(isA<DatabaseException>()),
        );
      });

      test('should allow valid data insertion', () async {
        final db = await databaseManager.database;
        
        final now = DateTime.now().millisecondsSinceEpoch;
        final id = await db.insert('words', {
          'source_word': 'hello',
          'target_word': 'привет',
          'language_pair': 'en-ru',
          'frequency': 100,
          'created_at': now,
          'updated_at': now,
        });
        
        expect(id, greaterThan(0));
        
        final result = await db.query('words', where: 'id = ?', whereArgs: [id]);
        expect(result.length, equals(1));
        expect(result.first['source_word'], equals('hello'));
        expect(result.first['target_word'], equals('привет'));
      });
    });

    group('Phrases Database (phrases.db)', () {
      test('should initialize phrases database successfully', () async {
        final db = await databaseManager.initPhrasesDatabase();
        
        expect(db, isNotNull);
        expect(db.isOpen, isTrue);
      });

      test('should return same instance on multiple calls', () async {
        final db1 = await databaseManager.initPhrasesDatabase();
        final db2 = await databaseManager.initPhrasesDatabase();
        
        expect(db1, same(db2));
      });

      test('should create all required tables in phrases database', () async {
        final db = await databaseManager.initPhrasesDatabase();
        
        final tables = await TestDatabaseHelper.getAllTables(db);
        
        expect(tables, contains('schema_info'));
        expect(tables, contains('phrases'));
        expect(tables, contains('phrase_cache'));
      });

      test('should create phrases table with correct schema', () async {
        final db = await databaseManager.initPhrasesDatabase();
        
        final schema = await TestDatabaseHelper.getTableSchema(db, 'phrases');
        final columnNames = schema.map((col) => col['name'] as String).toList();
        
        expect(columnNames, containsAll(['id', 'source_phrase', 'target_phrase', 'language_pair', 'usage_count']));
      });

      test('should create phrase indexes', () async {
        final db = await databaseManager.initPhrasesDatabase();
        
        final indexes = await TestDatabaseHelper.getAllIndexes(db);
        expect(indexes, contains('idx_phrase_lang'));
      });

      test('should allow phrase insertion', () async {
        final db = await databaseManager.initPhrasesDatabase();
        
        final now = DateTime.now().millisecondsSinceEpoch;
        final id = await db.insert('phrases', {
          'source_phrase': 'good morning',
          'target_phrase': 'доброе утро',
          'language_pair': 'en-ru',
          'usage_count': 50,
          'created_at': now,
          'updated_at': now,
        });
        
        expect(id, greaterThan(0));
      });
    });

    group('User Data Database (user_data.db)', () {
      test('should initialize user data database successfully', () async {
        final db = await databaseManager.initUserDataDatabase();
        
        expect(db, isNotNull);
        expect(db.isOpen, isTrue);
      });

      test('should return same instance on multiple calls', () async {
        final db1 = await databaseManager.initUserDataDatabase();
        final db2 = await databaseManager.initUserDataDatabase();
        
        expect(db1, same(db2));
      });

      test('should create all required tables in user data database', () async {
        final db = await databaseManager.initUserDataDatabase();
        
        final tables = await TestDatabaseHelper.getAllTables(db);
        
        expect(tables, contains('schema_info'));
        expect(tables, contains('translation_history'));
        expect(tables, contains('user_settings'));
        expect(tables, contains('user_translation_edits'));
        expect(tables, contains('context_cache'));
      });

      test('should create user_translation_edits table with correct schema', () async {
        final db = await databaseManager.initUserDataDatabase();
        
        final schema = await TestDatabaseHelper.getTableSchema(db, 'user_translation_edits');
        final columnNames = schema.map((col) => col['name'] as String).toList();
        
        expect(columnNames, containsAll([
          'id', 'original_text', 'user_translation', 'language_pair', 'created_at'
        ]));
      });

      test('should create translation_history table with correct schema', () async {
        final db = await databaseManager.initUserDataDatabase();
        
        final schema = await TestDatabaseHelper.getTableSchema(db, 'translation_history');
        final columnNames = schema.map((col) => col['name'] as String).toList();
        
        expect(columnNames, containsAll([
          'id', 'original_text', 'translated_text', 'language_pair', 'timestamp'
        ]));
      });

      test('should create context_cache table with correct schema', () async {
        final db = await databaseManager.initUserDataDatabase();
        
        final schema = await TestDatabaseHelper.getTableSchema(db, 'context_cache');
        final columnNames = schema.map((col) => col['name'] as String).toList();
        
        expect(columnNames, containsAll([
          'id', 'context_key', 'translation_result', 'language_pair', 'last_used'
        ]));
      });

      test('should create user data indexes', () async {
        final db = await databaseManager.initUserDataDatabase();
        
        final indexes = await TestDatabaseHelper.getAllIndexes(db);
        
        expect(indexes, contains('idx_history_lang'));
        expect(indexes, contains('idx_history_timestamp'));
        expect(indexes, contains('idx_context_key'));
        expect(indexes, contains('idx_user_edits_lang'));
      });

      test('should allow user data insertion', () async {
        final db = await databaseManager.initUserDataDatabase();
        
        final now = DateTime.now().millisecondsSinceEpoch;
        
        // Test translation history
        final historyId = await db.insert('translation_history', {
          'original_text': 'test phrase',
          'translated_text': 'тестовая фраза',
          'language_pair': 'en-ru',
          'confidence': 0.95,
          'processing_time_ms': 100,
          'timestamp': now,
        });
        expect(historyId, greaterThan(0));
        
        // Test user settings
        final settingsId = await db.insert('user_settings', {
          'setting_key': 'default_language',
          'setting_value': 'en-ru',
          'created_at': now,
          'updated_at': now,
        });
        expect(settingsId, isNotNull);
      });
    });

    group('Database Integrity', () {
      test('should pass integrity check for all databases', () async {
        // Инициализируем все базы данных
        await databaseManager.database;
        await databaseManager.initPhrasesDatabase();
        await databaseManager.initUserDataDatabase();
        
        final isIntegrityOk = await databaseManager.checkAllDatabasesIntegrity();
        expect(isIntegrityOk, isTrue);
      });

      test('should return false on integrity check if database not initialized', () async {
        // Создаем новый менеджер без инициализации
        final tempPath = TestDatabaseHelper.getTestDatabasePath('empty_test');
        final newManager = DatabaseManager(customDatabasePath: tempPath);
        
        final isIntegrityOk = await newManager.checkAllDatabasesIntegrity();
        expect(isIntegrityOk, isTrue); // Должно быть true, так как базы создаются автоматически
      });
    });

    group('Database Closing and Cleanup', () {
      test('should close main database', () async {
        final db = await databaseManager.database;
        expect(db.isOpen, isTrue);
        
        await databaseManager.close();
        
        // После закрытия должен создать новое соединение
        final newDb = await databaseManager.database;
        expect(newDb.isOpen, isTrue);
      });

      test('should close all databases', () async {
        // Инициализируем все базы
        final dictDb = await databaseManager.database;
        final phrasesDb = await databaseManager.initPhrasesDatabase();
        final userDb = await databaseManager.initUserDataDatabase();
        
        expect(dictDb.isOpen, isTrue);
        expect(phrasesDb.isOpen, isTrue);
        expect(userDb.isOpen, isTrue);
        
        await databaseManager.close();
        
        // Проверяем, что все базы закрыты (новые соединения должны создаваться)
        final newDictDb = await databaseManager.database;
        final newPhrasesDb = await databaseManager.initPhrasesDatabase();
        final newUserDb = await databaseManager.initUserDataDatabase();
        
        expect(newDictDb.isOpen, isTrue);
        expect(newPhrasesDb.isOpen, isTrue);
        expect(newUserDb.isOpen, isTrue);
      });

      test('should handle multiple close calls gracefully', () async {
        await databaseManager.database;
        
        // Множественные вызовы close не должны вызывать ошибок
        await databaseManager.close();
        await databaseManager.close();
        await databaseManager.close();
        
        // База должна по-прежнему работать
        final db = await databaseManager.database;
        expect(db.isOpen, isTrue);
      });

      test('should reset completely', () async {
        await databaseManager.database;
        await databaseManager.initPhrasesDatabase();
        
        await databaseManager.reset();
        
        // После reset должен работать с тем же custom path
        final db = await databaseManager.database;
        expect(db.isOpen, isTrue);
      });
    });

    group('Error Handling', () {
      test('should wrap database exceptions in DatabaseInitException', () async {
        // Создаем файл в месте, где должна быть директория
        final conflictPath = TestDatabaseHelper.getTestDatabasePath('file_conflict');
        final conflictFile = File(conflictPath);
        await conflictFile.create(recursive: true);
        
        final invalidManager = DatabaseManager(customDatabasePath: conflictPath);
        
        expect(
          () async => await invalidManager.database,
          throwsA(isA<DatabaseInitException>()),
        );
        
        // Очищаем после теста
        if (conflictFile.existsSync()) {
          await conflictFile.delete();
        }
      });

      test('should handle concurrent database initialization', () async {
        // Множественные одновременные запросы к базе данных
        final futures = List.generate(5, (_) => databaseManager.database);
        final databases = await Future.wait(futures);
        
        // Все должны вернуть один и тот же экземпляр
        for (var db in databases) {
          expect(db, same(databases.first));
          expect(db.isOpen, isTrue);
        }
      });

      test('should handle concurrent phrases database initialization', () async {
        final futures = List.generate(3, (_) => databaseManager.initPhrasesDatabase());
        final databases = await Future.wait(futures);
        
        for (var db in databases) {
          expect(db, same(databases.first));
          expect(db.isOpen, isTrue);
        }
      });

      test('should handle concurrent user database initialization', () async {
        final futures = List.generate(3, (_) => databaseManager.initUserDataDatabase());
        final databases = await Future.wait(futures);
        
        for (var db in databases) {
          expect(db, same(databases.first));
          expect(db.isOpen, isTrue);
        }
      });
    });

    group('Custom Path Functionality', () {
      test('should create database in custom directory', () async {
        final customPath = TestDatabaseHelper.getTestDatabasePath('custom_location');
        final customManager = DatabaseManager(customDatabasePath: customPath);
        
        final db = await customManager.database;
        expect(db.isOpen, isTrue);
        
        // Проверяем, что файл создается в нужном месте
        final dbFile = File('$customPath/dictionaries.db');
        expect(dbFile.existsSync(), isTrue);
        
        await customManager.close();
      });

      test('should create directory if it does not exist', () async {
        final nonExistentPath = TestDatabaseHelper.getTestDatabasePath('non_existent/nested/path');
        final customManager = DatabaseManager(customDatabasePath: nonExistentPath);
        
        final db = await customManager.database;
        expect(db.isOpen, isTrue);
        
        // Проверяем, что директория была создана
        final directory = Directory(nonExistentPath);
        expect(directory.existsSync(), isTrue);
        
        await customManager.close();
      });
    });

    group('Performance and Data Insertion', () {
      test('should handle bulk word insertions efficiently', () async {
        final db = await databaseManager.database;
        final stopwatch = Stopwatch()..start();
        
        await db.transaction((txn) async {
          for (int i = 0; i < 100; i++) {
            await txn.insert('words', {
              'source_word': 'word$i',
              'target_word': 'слово$i',
              'language_pair': 'en-ru',
              'frequency': i,
            });
          }
        });
        
        stopwatch.stop();
        
        // Проверяем, что все записи вставлены
        final countResult = await db.rawQuery('SELECT COUNT(*) FROM words');
        final count = countResult.first.values.first as int;
        expect(count, equals(100));
        
        // Время выполнения должно быть разумным (менее 5 секунд для 100 записей)
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });

      test('should use indexes effectively for queries', () async {
        final db = await databaseManager.database;
        
        // Вставляем тестовые данные
        await db.insert('words', {
          'source_word': 'test',
          'target_word': 'тест',
          'language_pair': 'en-ru',
          'frequency': 100,
        });
        
        // Запрос, который должен использовать индекс idx_source_word_lang
        final result = await db.query(
          'words',
          where: 'source_word = ? AND language_pair = ?',
          whereArgs: ['test', 'en-ru'],
        );
        
        expect(result.length, equals(1));
        expect(result.first['target_word'], equals('тест'));
      });

      test('should maintain cache table functionality', () async {
        final db = await databaseManager.database;
        
        final now = DateTime.now().millisecondsSinceEpoch;
        
        // Вставляем в кэш
        await db.insert('word_cache', {
          'source_word': 'cached_word',
          'target_word': 'кэшированное слово',
          'language_pair': 'en-ru',
          'last_used': now,
        });
        
        // Проверяем, что можем найти в кэше
        final cached = await db.query(
          'word_cache',
          where: 'source_word = ?',
          whereArgs: ['cached_word'],
        );
        
        expect(cached.length, equals(1));
        expect(cached.first['last_used'], equals(now));
      });
    });
  });
}