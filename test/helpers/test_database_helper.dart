import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

/// Helper класс для настройки тестовой базы данных
class TestDatabaseHelper {
  static bool _initialized = false;
  static String? _testDbPath;

  /// Инициализация FFI версии SQLite для тестов на десктопе
  static void setupTestDatabase() {
    if (_initialized) return;
    
    // Инициализируем ffi реализацию для тестов
    sqfliteFfiInit();
    
    // Устанавливаем фабрику для использования ffi версии
    databaseFactory = databaseFactoryFfi;
    
    _initialized = true;
  }

  /// Получение пути для тестовой базы данных
  static String getTestDatabasePath(String dbName) {
    _testDbPath ??= Directory.systemTemp.createTempSync('test_translation_engine').path;
    return join(_testDbPath!, dbName);
  }

  /// Очистка тестовых баз данных
  static Future<void> cleanupTestDatabases() async {
    if (_testDbPath != null) {
      final testDir = Directory(_testDbPath!);
      if (testDir.existsSync()) {
        testDir.deleteSync(recursive: true);
      }
      _testDbPath = null;
    }
  }

  /// Создание тестового Database с контролем над путем
  static Future<Database> createTestDatabase(
    String dbName, {
    int version = 1,
    required Future<void> Function(Database, int) onCreate,
  }) async {
    setupTestDatabase();
    final path = getTestDatabasePath(dbName);
    
    // Удаляем существующую базу если есть
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
    
    return await openDatabase(
      path,
      version: version,
      onCreate: onCreate,
    );
  }

  /// Проверка существования таблицы в базе данных
  static Future<bool> tableExists(Database db, String tableName) async {
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return result.isNotEmpty;
  }

  /// Получение списка всех таблиц в базе данных
  static Future<List<String>> getAllTables(Database db) async {
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    return result.map((row) => row['name'] as String).toList();
  }

  /// Получение списка всех индексов в базе данных
  static Future<List<String>> getAllIndexes(Database db) async {
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index'",
    );
    return result.map((row) => row['name'] as String).toList();
  }

  /// Проверка схемы таблицы
  static Future<List<Map<String, dynamic>>> getTableSchema(
    Database db, 
    String tableName
  ) async {
    return await db.rawQuery("PRAGMA table_info($tableName)");
  }

  /// Проверка ограничений таблицы
  static Future<bool> hasCheckConstraint(
    Database db, 
    String tableName, 
    String columnName
  ) async {
    final result = await db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    
    if (result.isEmpty) return false;
    
    final sql = result.first['sql'] as String;
    return sql.toLowerCase().contains('check(length($columnName)');
  }
}