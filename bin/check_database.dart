#!/usr/bin/env dart

import 'dart:io';
import 'package:translation_engine/src/data/dictionary_repository.dart';
import 'package:translation_engine/src/utils/cache_manager.dart';
import 'package:translation_engine/src/data/database_manager.dart';

void main() async {
  print('🔍 Проверка содержимого базы данных');
  
  try {
    // Инициализация компонентов
    final dbManager = DatabaseManager();
    final cache = CacheManager();
    final repo = DictionaryRepository(databaseManager: dbManager, cacheManager: cache);
    
    // Убедимся что БД готова
    await dbManager.database;
    print('✅ База данных подключена');
    
    // Проверяем статистику по языковой паре en-ru
    final stats = await repo.getLanguagePairStats('en-ru');
    print('📊 Статистика для en-ru:');
    print('  Всего слов: ${stats['total_words']}');
    print('  Средняя частотность: ${stats['avg_frequency']}');
    print('  Максимальная частотность: ${stats['max_frequency']}');
    
    if (stats['total_words'] == 0) {
      print('❌ База данных пуста! Нужно добавить тестовые данные.');
      
      // Добавляем тестовые данные
      print('📝 Добавляем тестовые переводы...');
      
      final testData = [
        {'source': 'hello', 'target': 'привет', 'pos': 'interjection', 'freq': 500},
        {'source': 'world', 'target': 'мир', 'pos': 'noun', 'freq': 475},
        {'source': 'good', 'target': 'хороший', 'pos': 'adjective', 'freq': 450},
        {'source': 'test', 'target': 'тест', 'pos': 'noun', 'freq': 300},
        {'source': 'yes', 'target': 'да', 'pos': 'adverb', 'freq': 500},
      ];
      
      for (final data in testData) {
        try {
          await repo.addTranslation(
            data['source'] as String,
            data['target'] as String,
            'en-ru',
            partOfSpeech: data['pos'] as String?,
            frequency: data['freq'] as int,
          );
          print('  ✅ Добавлен: ${data['source']} → ${data['target']}');
        } catch (e) {
          print('  ❌ Ошибка добавления ${data['source']}: $e');
        }
      }
      
      // Проверяем статистику еще раз
      final newStats = await repo.getLanguagePairStats('en-ru');
      print('📊 Новая статистика для en-ru:');
      print('  Всего слов: ${newStats['total_words']}');
      
    } else {
      print('✅ В базе есть данные');
      
      // Показываем топ слов
      final topWords = await repo.getTopWords('en-ru', limit: 10);
      print('🔝 Топ слов в базе:');
      for (final word in topWords) {
        print('  ${word.sourceWord} → ${word.targetWord} (частотность: ${word.frequency})');
      }
    }
    
    // Тестируем поиск конкретных слов
    print('\n🔤 Тестирование поиска слов...');
    final testWords = ['hello', 'world', 'good'];
    
    for (final word in testWords) {
      final result = await repo.getTranslation(word, 'en-ru');
      if (result != null) {
        print('  ✅ $word → ${result.targetWord}');
      } else {
        print('  ❌ $word не найдено');
      }
    }
    
  } catch (e, stackTrace) {
    print('❌ Ошибка: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}