#!/usr/bin/env dart

// ignore_for_file: avoid_print

import 'dart:io';
import 'package:translation_engine/src/data/dictionary_repository.dart';
import 'package:translation_engine/src/utils/cache_manager.dart';
import 'package:translation_engine/src/data/database_manager_ffi.dart';

void printUsage() {
  print('Dictionary DB check (FFI)');
  print('');
  print('Usage:');
  print('  dart run bin/check_database.dart --db=<dir> [--lang=en-ru] [--populate]');
  print('');
  print('Options:');
  print('  --db         Directory where dictionaries.db/phrases.db/user_data.db are located');
  print('  --lang       Language pair to check (default: en-ru)');
  print('  --populate   Insert a small set of test words if DB is empty');
}

Future<void> main(List<String> args) async {
  print('🔍 Проверка содержимого базы данных (FFI)');

  final params = <String, String>{};
  for (final a in args) {
    final idx = a.indexOf('=');
    if (idx > 0) {
      params[a.substring(0, idx).replaceAll('--', '')] = a.substring(idx + 1);
    }
  }
  final dbDir = params['db'];
  final lang = params['lang'] ?? 'en-ru';
  final shouldPopulate = args.contains('--populate');

  if (dbDir == null || dbDir.isEmpty) {
    print('❌ Не указан путь к директории БД');
    print('');
    printUsage();
    exit(64);
  }

  try {
    // Инициализация компонентов (FFI менеджер, внешний путь)
    final dbManager = DatabaseManagerFfi(customDatabasePath: dbDir);
    final cache = CacheManager();
    final repo = DictionaryRepository(databaseManager: dbManager, cacheManager: cache);

    // Проверяем статистику по языковой паре
    final stats = await repo.getLanguagePairStats(lang);
    print('📊 Статистика для $lang:');
    print('  Всего слов: ${stats['total_words']}');
    print('  Средняя частотность: ${stats['avg_frequency']}');
    print('  Максимальная частотность: ${stats['max_frequency']}');

    if (stats['total_words'] == 0) {
      print('⚠️  Словарь пуст');
      if (shouldPopulate) {
        print('📝 Добавляем небольшой набор тестовых переводов в $lang...');
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
              lang,
              partOfSpeech: data['pos'] as String?,
              frequency: data['freq'] as int,
            );
            print('  ✅ ${data['source']} → ${data['target']}');
          } catch (e) {
            print('  ❌ Ошибка добавления ${data['source']}: $e');
          }
        }
        final newStats = await repo.getLanguagePairStats(lang);
        print('📊 Новая статистика для $lang:');
        print('  Всего слов: ${newStats['total_words']}');
      } else {
        print('ℹ️  Запустите с флагом --populate для добавления тестовых данных');
      }
    } else {
      print('✅ В базе есть данные');
      final topWords = await repo.getTopWords(lang, limit: 10);
      print('🔝 Топ слов:');
      for (final w in topWords) {
        print('  ${w.sourceWord} → ${w.targetWord} (частотность: ${w.frequency})');
      }
    }

    // Тестирование поиска
    print('\n🔤 Тестирование поиска слов (hello, world, good)');
    for (final word in const ['hello', 'world', 'good']) {
      final result = await repo.getTranslation(word, lang);
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
