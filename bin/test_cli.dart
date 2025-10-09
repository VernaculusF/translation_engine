#!/usr/bin/env dart

// ignore_for_file: avoid_print, avoid_relative_lib_imports

import 'dart:io';
import '../lib/src/data/database_manager_ffi.dart';
import '../lib/src/data/dictionary_repository.dart';  
import '../lib/src/data/phrase_repository.dart';
import '../lib/src/data/user_data_repository.dart';
import '../lib/src/utils/cache_manager.dart';
import '../lib/src/core/translation_pipeline.dart';
import '../lib/src/core/translation_context.dart';

void printUsage() {
  print('Translation pipeline CLI (FFI)');
  print('');
  print('Usage:');
  print('  dart run bin/test_cli.dart [--db=<dir>] [--lang=en-ru] [text ...]');
}

Future<void> main(List<String> arguments) async {
  print('🔍 CLI тестирование TranslationEngine без Flutter');

  // Parse simple args
  String? dbDir;
  String lang = 'en-ru';
  final words = <String>[];
  for (final a in arguments) {
    if (a.startsWith('--db=')) {
      dbDir = a.substring(5);
    } else if (a.startsWith('--lang=')) {
      lang = a.substring(7);
    } else if (a.startsWith('--')) {
      // skip unknown flags
    } else {
      words.add(a);
    }
  }
  if (words.isEmpty) {
    words.addAll(['hello', 'world', 'good']);
  }

  try {
    print('📦 Создание компонентов движка...');
    
    // Создаем компоненты напрямую с FFI database manager
    final databaseManager = DatabaseManagerFfi(customDatabasePath: dbDir);
    final cacheManager = CacheManager();
    
    final dictionaryRepository = DictionaryRepository(
      databaseManager: databaseManager,
      cacheManager: cacheManager,
    );
    
    final phraseRepository = PhraseRepository(
      databaseManager: databaseManager,
      cacheManager: cacheManager,
    );
    
    final userDataRepository = UserDataRepository(
      databaseManager: databaseManager,
      cacheManager: cacheManager,
    );
    
    final pipeline = TranslationPipeline(
      dictionaryRepository: dictionaryRepository,
      phraseRepository: phraseRepository, 
      userDataRepository: userDataRepository,
      cacheManager: cacheManager,
      registerDefaultLayers: true,
    );
    
    print('✅ Компоненты созданы');
    
    print('\n🔤 Тестирование перевода слов...');
    for (final word in words) {
      print('\n🔸 Переводим: "$word"');
      
      try {
        final result = await pipeline.process(word, TranslationContext(
          sourceLanguage: lang.split('-').first,
          targetLanguage: lang.split('-').last,
        ));
        
        print('  Результат:');
        print('    Исходный: "${result.originalText}"');
        print('    Перевод: "${result.translatedText}"');
        print('    Статус: ${result.hasError ? "ОШИБКА" : "УСПЕХ"}');
        print('    Уверенность: ${result.confidence.toStringAsFixed(2)}');
        print('    Время: ${result.processingTimeMs}ms');
        print('    Слоев обработано: ${result.layersProcessed}');
        
        if (result.errorMessage != null) {
          print('    ❌ Ошибка: ${result.errorMessage}');
        }
        
        if (result.layerResults.isNotEmpty) {
          print('    Debug по слоям:');
          for (final layer in result.layerResults) {
            print('      - ${layer.layerName}: ${layer.wasModified ? "изменен" : "не изменен"} (${layer.processingTimeMs}ms)');
          }
        }
        
      } catch (e) {
        print('  ❌ Ошибка перевода: $e');
      }
    }
    
    print('\n🧹 Очистка ресурсов...');
    await databaseManager.reset();
    print('✅ Ресурсы очищены');
    
  } catch (e, stackTrace) {
    print('❌ Критическая ошибка: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}
