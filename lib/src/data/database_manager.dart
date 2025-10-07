import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import '../utils/exceptions.dart';
import 'database_types.dart';

class DatabaseManager {
  static final DatabaseManager _instance = DatabaseManager._internal();
  factory DatabaseManager({String? customDatabasePath}) => _instance.._customPath = customDatabasePath;
  DatabaseManager._internal();

  static Database? _database;
  static Database? _phrasesDb;
  static Database? _userDataDb;
  
  final String _databasePath = 'translation_engine';
  String? _customPath;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final String basePath;
      if (_customPath != null) {
        basePath = _customPath!;
      } else {
        final documentsDirectory = await getApplicationDocumentsDirectory();
        basePath = join(documentsDirectory.path, _databasePath);
      }
      
      // Создаем директорию если не существует
      final directory = Directory(basePath);
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
      
      return await openDatabase(
        join(basePath, 'dictionaries.db'),
        version: 1,
        onCreate: _createDictionariesDatabase,
      );
    } catch (e) {
      throw DatabaseInitException('Failed to initialize database: $e');
    }
  }

  Future<void> _createDictionariesDatabase(Database db, int version) async {
    // Таблица для версий схемы
    await db.execute('''
      CREATE TABLE schema_info (
        version INTEGER NOT NULL
      )
    ''');
    
    // Вставляем текущую версию
    await db.execute('''
      INSERT INTO schema_info (version) VALUES (1)
    ''');

    // Таблица для слов
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

    // Таблица для кэша слов
    await db.execute('''
      CREATE TABLE word_cache (
        source_word TEXT PRIMARY KEY NOT NULL CHECK(length(source_word) > 0),
        target_word TEXT NOT NULL,
        language_pair TEXT NOT NULL,
        last_used INTEGER NOT NULL
      )
    ''');

    // Индексы для быстрого поиска
    await db.execute('CREATE INDEX idx_word_lang ON words(source_word, language_pair)');
    await db.execute('CREATE INDEX idx_frequency ON words(frequency)');
  }

  // Метод для инициализации базы фраз
  Future<Database> initPhrasesDatabase() async {
    if (_phrasesDb != null) return _phrasesDb!;
    
    try {
      final String basePath;
      if (_customPath != null) {
        basePath = _customPath!;
      } else {
        final documentsDirectory = await getApplicationDocumentsDirectory();
        basePath = join(documentsDirectory.path, _databasePath);
      }
      
      // Создаем директорию если не существует
      final directory = Directory(basePath);
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
      
      _phrasesDb = await openDatabase(
        join(basePath, 'phrases.db'),
        version: 1,
        onCreate: _createPhrasesDatabase,
      );
      
      return _phrasesDb!;
    } catch (e) {
      throw DatabaseInitException('Failed to initialize phrases database: $e');
    }
  }

  Future<void> _createPhrasesDatabase(Database db, int version) async {
    // Таблица для версий схемы
    await db.execute('''
      CREATE TABLE schema_info (
        version INTEGER NOT NULL
      )
    ''');
    
    await db.execute('INSERT INTO schema_info (version) VALUES (1)');

    // Таблица для фраз
    await db.execute('''
      CREATE TABLE phrases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_phrase TEXT NOT NULL CHECK(length(source_phrase) > 0),
        target_phrase TEXT NOT NULL CHECK(length(target_phrase) > 0),
        language_pair TEXT NOT NULL CHECK(length(language_pair) > 0),
        category TEXT,
        context TEXT,
        usage_count INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Таблица для кэша фраз
    await db.execute('''
      CREATE TABLE phrase_cache (
        source_phrase TEXT PRIMARY KEY NOT NULL CHECK(length(source_phrase) > 0),
        target_phrase TEXT NOT NULL,
        language_pair TEXT NOT NULL,
        last_used INTEGER NOT NULL
      )
    ''');

    // Индекс для быстрого поиска фраз
    await db.execute('CREATE INDEX idx_phrase_lang ON phrases(source_phrase, language_pair)');
  }

  // Метод для инициализации базы пользовательских данных
  Future<Database> initUserDataDatabase() async {
    if (_userDataDb != null) return _userDataDb!;
    
    try {
      final String basePath;
      if (_customPath != null) {
        basePath = _customPath!;
      } else {
        final documentsDirectory = await getApplicationDocumentsDirectory();
        basePath = join(documentsDirectory.path, _databasePath);
      }
      
      // Создаем директорию если не существует
      final directory = Directory(basePath);
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
      
      _userDataDb = await openDatabase(
        join(basePath, 'user_data.db'),
        version: 1,
        onCreate: _createUserDataDatabase,
      );
      
      return _userDataDb!;
    } catch (e) {
      throw DatabaseInitException('Failed to initialize user data database: $e');
    }
  }

  Future<void> _createUserDataDatabase(Database db, int version) async {
    // Таблица для версий схемы
    await db.execute('''
      CREATE TABLE schema_info (
        version INTEGER NOT NULL
      )
    ''');
    
    await db.execute('INSERT INTO schema_info (version) VALUES (1)');

    // Таблица для истории переводов
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

    // Таблица для пользовательских настроек
    await db.execute('''
      CREATE TABLE user_settings (
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Таблица для пользовательских редактирований переводов
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

    // Таблица для контекстного кэша
    await db.execute('''
      CREATE TABLE context_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        context_key TEXT NOT NULL,
        translation_result TEXT NOT NULL,
        language_pair TEXT NOT NULL,
        last_used INTEGER NOT NULL
      )
    ''');

    // Индексы для пользовательских данных
    await db.execute('CREATE INDEX idx_history_lang ON translation_history(language_pair)');
    await db.execute('CREATE INDEX idx_history_timestamp ON translation_history(timestamp)');
    await db.execute('CREATE INDEX idx_context_key ON context_cache(context_key)');
    await db.execute('CREATE INDEX idx_user_edits_lang ON user_translation_edits(language_pair)');
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
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
  
  /// Получение соединения с базой данных по типу
  Future<DatabaseConnection> getConnection(DatabaseType type) async {
    switch (type) {
      case DatabaseType.dictionaries:
        final db = await database;
        return SqliteDatabaseConnection(db);
      case DatabaseType.phrases:
        final db = await initPhrasesDatabase();
        return SqliteDatabaseConnection(db);
      case DatabaseType.userData:
        final db = await initUserDataDatabase();
        return SqliteDatabaseConnection(db);
    }
  }

  /// Закрытие соединения с базой данных
  Future<void> closeConnection(DatabaseConnection connection) async {
    // В текущей реализации мы не закрываем соединения индивидуально,
    // так как они переиспользуются через singleton паттерн
    // Закрытие происходит только при вызове close() или reset()
  }

  /// Метод для полной очистки (для тестов)
  Future<void> reset() async {
    await close();
    // Не сбрасываем _customPath, так как это singleton
  }

  // Метод для проверки целостности всех баз данных
  Future<bool> checkAllDatabasesIntegrity() async {
    try {
      final dictDb = await database;
      final phrasesDb = await initPhrasesDatabase();
      final userDb = await initUserDataDatabase();

      // Проверяем существование основных таблиц в каждой БД
      final dictTables = await dictDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'"
      );
      final phraseTables = await phrasesDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'"
      );
      final userTables = await userDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'"
      );

      // Проверяем наличие всех необходимых таблиц
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
             userTableNames.contains('user_settings') &&
             userTableNames.contains('user_translation_edits') &&
             userTableNames.contains('context_cache');
    } catch (e) {
      return false;
    }
  }
  
}
