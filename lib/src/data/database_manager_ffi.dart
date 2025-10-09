import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/exceptions.dart';
import 'database_manager_base.dart';
import 'database_types.dart';

/// FFI-based database manager for CLI/desktop without Flutter
class DatabaseManagerFfi implements DatabaseManagerBase {
  static final DatabaseManagerFfi _instance = DatabaseManagerFfi._internal();
  factory DatabaseManagerFfi({String? customDatabasePath}) => _instance.._customPath = customDatabasePath;
  DatabaseManagerFfi._internal();

  static Database? _dictDb;
  static Database? _phrasesDb;
  static Database? _userDataDb;

  final String _databasePath = 'translation_engine';
  String? _customPath;

  Future<Database> _openOrCreate(String dbFileName, Future<void> Function(Database db, int version) onCreate) async {
    try {
      // Initialize ffi
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      final String basePath = _customPath ?? join(Directory.current.path, _databasePath);
      final directory = Directory(basePath);
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      final dbPath = join(basePath, dbFileName);
      return await databaseFactoryFfi.openDatabase(dbPath, options: OpenDatabaseOptions(
        version: 1,
        onCreate: onCreate,
      ));
    } catch (e) {
      throw DatabaseInitException('Failed to initialize database ($dbFileName): $e');
    }
  }

  Future<Database> get _dictionaries async {
    if (_dictDb != null) return _dictDb!;
    _dictDb = await _openOrCreate('dictionaries.db', _createDictionariesDatabase);
    return _dictDb!;
  }

  Future<Database> get _phrases async {
    if (_phrasesDb != null) return _phrasesDb!;
    _phrasesDb = await _openOrCreate('phrases.db', _createPhrasesDatabase);
    return _phrasesDb!;
  }

  Future<Database> get _userData async {
    if (_userDataDb != null) return _userDataDb!;
    _userDataDb = await _openOrCreate('user_data.db', _createUserDataDatabase);
    return _userDataDb!;
  }

  Future<void> _createDictionariesDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE schema_info (
        version INTEGER NOT NULL
      )
    ''');
    await db.execute('INSERT INTO schema_info (version) VALUES (1)');

    await db.execute('''
      CREATE TABLE words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_word TEXT NOT NULL CHECK(length(source_word) > 0),
        target_word TEXT NOT NULL CHECK(length(target_word) > 0),
        language_pair TEXT NOT NULL CHECK(length(language_pair) > 0),
        part_of_speech TEXT,
        definition TEXT,
        frequency INTEGER DEFAULT 0,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE word_cache (
        source_word TEXT PRIMARY KEY NOT NULL CHECK(length(source_word) > 0),
        target_word TEXT NOT NULL,
        language_pair TEXT NOT NULL,
        last_used INTEGER NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_word_lang ON words(source_word, language_pair)');
    await db.execute('CREATE INDEX idx_frequency ON words(frequency)');
  }

  Future<void> _createPhrasesDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE schema_info (
        version INTEGER NOT NULL
      )
    ''');
    await db.execute('INSERT INTO schema_info (version) VALUES (1)');

    await db.execute('''
      CREATE TABLE phrases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_phrase TEXT NOT NULL CHECK(length(source_phrase) > 0),
        target_phrase TEXT NOT NULL CHECK(length(target_phrase) > 0),
        language_pair TEXT NOT NULL CHECK(length(language_pair) > 0),
        category TEXT,
        context TEXT,
        frequency INTEGER DEFAULT 0,
        confidence INTEGER,
        usage_count INTEGER DEFAULT 0,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE phrase_cache (
        source_phrase TEXT PRIMARY KEY NOT NULL CHECK(length(source_phrase) > 0),
        target_phrase TEXT NOT NULL,
        language_pair TEXT NOT NULL,
        last_used INTEGER NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_phrase_lang ON phrases(source_phrase, language_pair)');
  }

  Future<void> _createUserDataDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE schema_info (
        version INTEGER NOT NULL
      )
    ''');
    await db.execute('INSERT INTO schema_info (version) VALUES (1)');

    await db.execute('''
      CREATE TABLE translation_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_text TEXT NOT NULL,
        translated_text TEXT NOT NULL,
        language_pair TEXT NOT NULL,
        confidence REAL NOT NULL,
        processing_time_ms INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        session_id TEXT,
        metadata TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE user_corrections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_text TEXT NOT NULL,
        corrected_translation TEXT NOT NULL,
        lang_pair TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE user_settings (
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT NOT NULL,
        description TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE user_translation_edits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_text TEXT NOT NULL,
        original_translation TEXT NOT NULL,
        user_translation TEXT NOT NULL,
        language_pair TEXT NOT NULL,
        reason TEXT,
        is_approved INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE context_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        context_key TEXT NOT NULL,
        translation_result TEXT NOT NULL,
        language_pair TEXT NOT NULL,
        last_used INTEGER NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_history_lang ON translation_history(language_pair)');
    await db.execute('CREATE INDEX idx_history_timestamp ON translation_history(timestamp)');
    await db.execute('CREATE INDEX idx_context_key ON context_cache(context_key)');
    await db.execute('CREATE INDEX idx_user_edits_lang ON user_translation_edits(language_pair)');
    await db.execute('CREATE INDEX idx_user_corrections_lang ON user_corrections(lang_pair)');
  }

  @override
  Future<DatabaseConnection> getConnection(DatabaseType type) async {
    switch (type) {
      case DatabaseType.dictionaries:
        final db = await _dictionaries;
        return SqliteDatabaseConnection(db);
      case DatabaseType.phrases:
        final db = await _phrases;
        return SqliteDatabaseConnection(db);
      case DatabaseType.userData:
        final db = await _userData;
        return SqliteDatabaseConnection(db);
    }
  }

  @override
  Future<void> closeConnection(DatabaseConnection connection) async {
    // No-op for singleton-managed databases
  }

  @override
  Future<void> reset() async {
    if (_dictDb != null) {
      await _dictDb!.close();
      _dictDb = null;
    }
    if (_phrasesDb != null) {
      await _phrasesDb!.close();
      _phrasesDb = null;
    }
    if (_userDataDb != null) {
      await _userDataDb!.close();
      _userDataDb = null;
    }
  }

  @override
  Future<bool> checkAllDatabasesIntegrity() async {
    try {
      final dictDb = await _dictionaries;
      final phrasesDb = await _phrases;
      final userDb = await _userData;

      final dictTables = await dictDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final phraseTables = await phrasesDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final userTables = await userDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");

      final dictTableNames = dictTables.map((t) => t['name'] as String).toList();
      final phraseTableNames = phraseTables.map((t) => t['name'] as String).toList();
      final userTableNames = userTables.map((t) => t['name'] as String).toList();

      return dictTableNames.contains('schema_info') &&
          dictTableNames.contains('words') &&
          dictTableNames.contains('word_cache') &&
          phraseTableNames.contains('schema_info') &&
          phraseTableNames.contains('phrases') &&
          phraseTableNames.contains('phrase_cache') &&
          userTableNames.contains('schema_info') &&
          userTableNames.contains('translation_history') &&
          userTableNames.contains('user_corrections') &&
          userTableNames.contains('user_settings') &&
          userTableNames.contains('user_translation_edits') &&
          userTableNames.contains('context_cache');
    } catch (e) {
      return false;
    }
  }
}
