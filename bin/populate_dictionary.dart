#!/usr/bin/env dart

// ignore_for_file: avoid_print

import 'dart:io';
import 'package:translation_engine/src/data/database_manager_ffi.dart';
import 'package:translation_engine/src/data/dictionary_repository.dart';
import 'package:translation_engine/src/utils/cache_manager.dart';

void printUsage() {
  print('Populate dictionary with test data (FFI)');
  print('');
  print('Usage:');
  print('  dart run bin/populate_dictionary.dart --db=<dir> [--lang=en-ru]');
  print('');
  print('Options:');
  print('  --db     Directory where dictionaries.db resides (external repo path)');
  print('  --lang   Language pair (default: en-ru)');
}

Future<void> main(List<String> args) async {
  print('📝 Заполнение словаря тестовыми данными (только во внешнюю БД)');

  final params = <String, String>{};
  for (final a in args) {
    final idx = a.indexOf('=');
    if (idx > 0) {
      params[a.substring(0, idx).replaceAll('--', '')] = a.substring(idx + 1);
    }
  }
  final dbDir = params['db'];
  final lang = params['lang'] ?? 'en-ru';

  if (dbDir == null || dbDir.isEmpty) {
    print('❌ Не указан путь к директории БД');
    print('');
    printUsage();
    exit(64);
  }

  try {
    final dbManager = DatabaseManagerFfi(customDatabasePath: dbDir);
    final cache = CacheManager();
    final repo = DictionaryRepository(databaseManager: dbManager, cacheManager: cache);

    final testData = <Map<String, dynamic>>[
      {'source': 'hello', 'target': 'привет', 'pos': 'interjection', 'freq': 500},
      {'source': 'world', 'target': 'мир', 'pos': 'noun', 'freq': 475},
      {'source': 'good', 'target': 'хороший', 'pos': 'adjective', 'freq': 450},
      {'source': 'test', 'target': 'тест', 'pos': 'noun', 'freq': 300},
      {'source': 'yes', 'target': 'да', 'pos': 'adverb', 'freq': 500},
    ];

    print('➡️  Добавляем ${testData.length} записей в $lang по пути: $dbDir');

    for (final row in testData) {
      try {
        await repo.addTranslation(
          row['source'] as String,
          row['target'] as String,
          lang,
          partOfSpeech: row['pos'] as String?,
          frequency: row['freq'] as int,
        );
        print('  ✅ ${row['source']} → ${row['target']}');
      } catch (e) {
        print('  ❌ Ошибка добавления ${row['source']}: $e');
      }
    }

    print('✅ Готово. Проверка выборки:');
    for (final w in const ['hello', 'world', 'good']) {
      final res = await repo.getTranslation(w, lang);
      if (res != null) {
        print('  🔹 $w → ${res.targetWord}');
      } else {
        print('  🔸 $w не найдено');
      }
    }
  } catch (e, st) {
    print('❌ Ошибка заполнения БД: $e');
    print(st);
    exit(1);
  }
}
