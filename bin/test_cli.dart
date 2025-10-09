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

void main(List<String> arguments) async {
  print('🔍 CLI тестирование TranslationEngine без Flutter');
  
  try {
    print('📦 Создание компонентов движка...');
    
    // Создаем компоненты напрямую с FFI database manager
    final databaseManager = DatabaseManagerFfi();
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
    
    // Тестовые слова
    final testWords = ['hello', 'world', 'good'];
    
    print('\n🔤 Тестирование перевода слов...');
    for (final word in testWords) {
      print('\n🔸 Переводим: "$word"');
      
      try {
        final result = await pipeline.process(word, TranslationContext(
          sourceLanguage: 'en',
          targetLanguage: 'ru',
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