import 'dart:io';
import 'package:test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Simple test file for database functionality using direct SQLite operations
void main() {
  group('Database Schema Tests', () {
    late Database db;
    late String dbPath;

    setUpAll(() {
      // Initialize sqflite FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Create a temporary database
      final tempDir = Directory.systemTemp.createTempSync();
      dbPath = '${tempDir.path}/test_db.db';
      
      db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          // Schema version table
          await db.execute('''
            CREATE TABLE schema_info (
              version INTEGER NOT NULL
            )
          ''');
          
          await db.execute('INSERT INTO schema_info (version) VALUES (1)');

          // Words table with new schema
          await db.execute('''
            CREATE TABLE words (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              source_word TEXT NOT NULL CHECK(length(source_word) > 0),
              target_word TEXT NOT NULL CHECK(length(target_word) > 0),
              language_pair TEXT NOT NULL CHECK(length(language_pair) > 0),
              part_of_speech TEXT,
              definition TEXT,
              frequency INTEGER DEFAULT 1,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

          // Word cache table
          await db.execute('''
            CREATE TABLE word_cache (
              source_word TEXT PRIMARY KEY NOT NULL CHECK(length(source_word) > 0),
              target_word TEXT NOT NULL,
              language_pair TEXT NOT NULL,
              last_used INTEGER NOT NULL
            )
          ''');

          // Indexes
          await db.execute('CREATE INDEX idx_source_word_lang ON words(source_word, language_pair)');
          await db.execute('CREATE INDEX idx_frequency ON words(frequency)');
        },
      );
    });

    tearDown(() async {
      await db.close();
      final file = File(dbPath);
      if (file.existsSync()) {
        await file.delete();
      }
    });

    test('should create database with correct schema version', () async {
      final result = await db.rawQuery('SELECT version FROM schema_info');
      expect(result, hasLength(1));
      expect(result.first['version'], equals(1));
    });

    test('should create words table with updated schema', () async {
      final result = await db.rawQuery("PRAGMA table_info(words)");
      final columnNames = result.map((col) => col['name'] as String).toList();
      
      expect(columnNames, contains('id'));
      expect(columnNames, contains('source_word'));
      expect(columnNames, contains('target_word'));
      expect(columnNames, contains('language_pair'));
      expect(columnNames, contains('frequency'));
      expect(columnNames, contains('created_at'));
      expect(columnNames, contains('updated_at'));
    });

    test('should create word_cache table with updated schema', () async {
      final result = await db.rawQuery("PRAGMA table_info(word_cache)");
      final columnNames = result.map((col) => col['name'] as String).toList();
      
      expect(columnNames, contains('source_word'));
      expect(columnNames, contains('target_word'));
      expect(columnNames, contains('language_pair'));
      expect(columnNames, contains('last_used'));
    });

    test('should create required indexes', () async {
      final result = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='index'");
      final indexNames = result.map((row) => row['name'] as String).toList();
      
      expect(indexNames, contains('idx_source_word_lang'));
      expect(indexNames, contains('idx_frequency'));
    });

    test('should insert and retrieve data with new schema', () async {
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
      expect(result, hasLength(1));
      expect(result.first['source_word'], equals('hello'));
      expect(result.first['target_word'], equals('привет'));
      expect(result.first['language_pair'], equals('en-ru'));
    });

    test('should enforce CHECK constraints', () async {
      // Test empty source_word constraint
      expect(
        () async => await db.insert('words', {
          'source_word': '',
          'target_word': 'test',
          'language_pair': 'en-ru',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        }),
        throwsA(isA<DatabaseException>()),
      );

      // Test empty target_word constraint
      expect(
        () async => await db.insert('words', {
          'source_word': 'test',
          'target_word': '',
          'language_pair': 'en-ru',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('should work with word_cache table', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      await db.insert('word_cache', {
        'source_word': 'cached_word',
        'target_word': 'кэшированное слово',
        'language_pair': 'en-ru',
        'last_used': now,
      });
      
      final cached = await db.query(
        'word_cache',
        where: 'source_word = ?',
        whereArgs: ['cached_word'],
      );
      
      expect(cached, hasLength(1));
      expect(cached.first['target_word'], equals('кэшированное слово'));
      expect(cached.first['last_used'], equals(now));
    });

    test('should use indexes for queries', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Insert test data
      await db.insert('words', {
        'source_word': 'test',
        'target_word': 'тест',
        'language_pair': 'en-ru',
        'frequency': 100,
        'created_at': now,
        'updated_at': now,
      });
      
      // Query using index
      final result = await db.query(
        'words',
        where: 'source_word = ? AND language_pair = ?',
        whereArgs: ['test', 'en-ru'],
      );
      
      expect(result, hasLength(1));
      expect(result.first['target_word'], equals('тест'));
    });

    test('should handle bulk operations efficiently', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final stopwatch = Stopwatch()..start();
      
      await db.transaction((txn) async {
        for (int i = 0; i < 100; i++) {
          await txn.insert('words', {
            'source_word': 'word$i',
            'target_word': 'слово$i',
            'language_pair': 'en-ru',
            'frequency': i,
            'created_at': now,
            'updated_at': now,
          });
        }
      });
      
      stopwatch.stop();
      
      // Verify all records inserted
      final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM words');
      final count = countResult.first['count'] as int;
      expect(count, equals(100));
      
      // Should complete in reasonable time
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });
  });
}