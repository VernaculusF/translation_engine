#!/usr/bin/env dart

import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) async {
  print('🔄 Простой тест перевода через SQLite');
  
  final testWord = args.isNotEmpty ? args.first : 'hello';
  print('🔤 Тестируем перевод слова: "$testWord"');
  
  try {
    // Открываем базу данных напрямую
    final dbPath = 'dictionaries.db';
    if (!File(dbPath).existsSync()) {
      print('❌ База данных не найдена: $dbPath');
      print('💡 Сначала запустите: dart run bin/check_database_direct.dart');
      exit(1);
    }
    
    final db = sqlite3.open(dbPath);
    
    try {
      // Ищем перевод
      final result = db.select("""
        SELECT target_word, part_of_speech, frequency 
        FROM words 
        WHERE source_word = ? AND language_pair = 'en-ru'
        ORDER BY frequency DESC
        LIMIT 1;
      """, [testWord]);
      
      if (result.isNotEmpty) {
        final row = result.first;
        print('✅ Результат перевода:');
        print('   $testWord → ${row['target_word']}');
        print('   Часть речи: ${row['part_of_speech']}');
        print('   Частотность: ${row['frequency']}');
        
        // Также попробуем найти похожие слова
        final similar = db.select("""
          SELECT source_word, target_word 
          FROM words 
          WHERE source_word LIKE ? AND language_pair = 'en-ru'
          LIMIT 5;
        """, ['%$testWord%']);
        
        if (similar.length > 1) {
          print('🔍 Похожие слова:');
          for (final row in similar) {
            if (row['source_word'] != testWord) {
              print('   ${row['source_word']} → ${row['target_word']}');
            }
          }
        }
        
      } else {
        print('❌ Перевод не найден для слова: $testWord');
        
        // Показываем доступные слова
        final available = db.select("""
          SELECT source_word, target_word 
          FROM words 
          WHERE language_pair = 'en-ru'
          ORDER BY frequency DESC
          LIMIT 10;
        """);
        
        print('📝 Доступные слова в базе:');
        for (final row in available) {
          print('   ${row['source_word']} → ${row['target_word']}');
        }
      }
      
    } finally {
      db.dispose();
    }
    
  } catch (e, stackTrace) {
    print('❌ Ошибка: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}