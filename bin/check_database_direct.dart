#!/usr/bin/env dart

import 'dart:io';
import 'package:sqlite3/sqlite3.dart';


void main() async {
  print('🔍 Прямая проверка SQLite базы данных переводов');
  
  try {
  // Ищем файл базы данных (создаем dictionaries.db для совместимости с DatabaseManager)
    final databasePath = 'dictionaries.db';
    
    print('📍 Путь к базе: $databasePath');
    
    // Открываем соединение с базой
    final db = sqlite3.open(databasePath);
    
    try {
      print('✅ База данных открыта');
      
      // Проверяем существование таблиц
      await _checkTables(db);
      
      // Получаем статистику
      await _getStatistics(db);
      
      // Если база пуста, добавляем тестовые данные
      final isEmpty = await _isDatabaseEmpty(db);
      if (isEmpty) {
        print('\n❌ База данных пуста! Добавляем тестовые данные...');
        await _addTestData(db);
        print('✅ Тестовые данные добавлены');
        
        // Показываем новую статистику
        print('\n📊 Статистика после добавления:');
        await _getStatistics(db);
      }
      
      // Тестируем поиск
      print('\n🔤 Тестирование поиска слов...');
      await _testSearch(db);
      
    } finally {
      db.dispose();
    }
    
  } catch (e, stackTrace) {
    print('❌ Ошибка: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}


Future<void> _checkTables(Database db) async {
  try {
    final result = db.select("""
      SELECT name FROM sqlite_master 
      WHERE type='table' AND name IN ('words', 'word_cache', 'schema_info')
      ORDER BY name;
    """);
    
    if (result.isEmpty) {
      print('⚠️  Таблицы переводов не найдены. Создаем...');
      await _createTables(db);
    } else {
      print('✅ Найдено таблиц: ${result.length}');
      for (final row in result) {
        print('  - ${row['name']}');
      }
    }
  } catch (e) {
    print('❌ Ошибка проверки таблиц: $e');
    rethrow;
  }
}

Future<void> _createTables(Database db) async {
  // Создаем таблицу версий схемы (как в DatabaseManager)
  db.execute("""
    CREATE TABLE IF NOT EXISTS schema_info (
      version INTEGER NOT NULL
    );
  """);
  
  // Вставляем версию схемы
  try {
    db.execute('INSERT INTO schema_info (version) VALUES (1);');
  } catch (e) {
    // Игнорируем если уже есть
  }
  
  // Создаем таблицу words (как ожидает DatabaseManager)
  db.execute("""
    CREATE TABLE IF NOT EXISTS words (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      source_word TEXT NOT NULL CHECK(length(source_word) > 0),
      target_word TEXT NOT NULL CHECK(length(target_word) > 0),
      language_pair TEXT NOT NULL CHECK(length(language_pair) > 0),
      part_of_speech TEXT,
      definition TEXT,
      frequency INTEGER DEFAULT 0,
      created_at INTEGER,
      updated_at INTEGER
    );
  """);
  
  // Создаем таблицу кэша слов
  db.execute("""
    CREATE TABLE IF NOT EXISTS word_cache (
      source_word TEXT PRIMARY KEY NOT NULL CHECK(length(source_word) > 0),
      target_word TEXT NOT NULL,
      language_pair TEXT NOT NULL,
      last_used INTEGER NOT NULL
    );
  """);
  
  // Создаем индексы (как в DatabaseManager)
  db.execute('CREATE INDEX IF NOT EXISTS idx_word_lang ON words(source_word, language_pair);');
  db.execute('CREATE INDEX IF NOT EXISTS idx_frequency ON words(frequency);');
  
  print('✅ Таблицы созданы в формате DatabaseManager');
}

Future<void> _getStatistics(Database db) async {
  try {
    // Общая статистика
    final totalResult = db.select('SELECT COUNT(*) as total FROM words;');
    final total = totalResult.first['total'] as int;
    
    if (total == 0) {
      print('📊 База данных пуста (0 слов)');
      return;
    }
    
    // Статистика по языковым парам
    final pairStats = db.select("""
      SELECT language_pair, COUNT(*) as count, 
             AVG(frequency) as avg_freq, MAX(frequency) as max_freq
      FROM words 
      GROUP BY language_pair 
      ORDER BY count DESC;
    """);
    
    print('📊 Статистика базы данных:');
    print('  Всего переводов: $total');
    
    for (final row in pairStats) {
      print('  ${row['language_pair']}: ${row['count']} переводов');
      print('    Средняя частотность: ${(row['avg_freq'] as double).toStringAsFixed(1)}');
      print('    Максимальная частотность: ${row['max_freq']}');
    }
    
  } catch (e) {
    print('❌ Ошибка получения статистики: $e');
  }
}

Future<bool> _isDatabaseEmpty(Database db) async {
  final result = db.select('SELECT COUNT(*) as total FROM words;');
  return (result.first['total'] as int) == 0;
}

Future<void> _addTestData(Database db) async {
  
  final testData = [
    {'source': 'hello', 'target': 'привет', 'pos': 'interjection', 'freq': 500},
    {'source': 'world', 'target': 'мир', 'pos': 'noun', 'freq': 475},
    {'source': 'good', 'target': 'хороший', 'pos': 'adjective', 'freq': 450},
    {'source': 'test', 'target': 'тест', 'pos': 'noun', 'freq': 300},
    {'source': 'yes', 'target': 'да', 'pos': 'adverb', 'freq': 500},
    {'source': 'no', 'target': 'нет', 'pos': 'adverb', 'freq': 480},
    {'source': 'water', 'target': 'вода', 'pos': 'noun', 'freq': 400},
    {'source': 'book', 'target': 'книга', 'pos': 'noun', 'freq': 350},
    {'source': 'time', 'target': 'время', 'pos': 'noun', 'freq': 450},
    {'source': 'day', 'target': 'день', 'pos': 'noun', 'freq': 420},
  ];
  
  final now = DateTime.now().millisecondsSinceEpoch;
  
  for (final data in testData) {
    try {
      db.execute("""
        INSERT OR REPLACE INTO words 
        (source_word, target_word, language_pair, part_of_speech, frequency, created_at, updated_at)
        VALUES (?, ?, 'en-ru', ?, ?, ?, ?);
      """, [
        data['source'],
        data['target'],
        data['pos'],
        data['freq'],
        now,
        now,
      ]);
      
      print('  ✅ ${data['source']} → ${data['target']}');
    } catch (e) {
      print('  ❌ Ошибка добавления ${data['source']}: $e');
    }
  }
}

Future<void> _testSearch(Database db) async {
  final testWords = ['hello', 'world', 'good', 'test', 'water', 'nonexistent'];
  
  for (final word in testWords) {
    try {
      final result = db.select("""
        SELECT target_word, part_of_speech, frequency 
        FROM words 
        WHERE source_word = ? AND language_pair = 'en-ru'
        LIMIT 1;
      """, [word]);
      
      if (result.isNotEmpty) {
        final row = result.first;
        print('  ✅ $word → ${row['target_word']} (${row['part_of_speech']}, частотность: ${row['frequency']})');
      } else {
        print('  ❌ $word не найдено');
      }
    } catch (e) {
      print('  ❌ Ошибка поиска $word: $e');
    }
  }
}