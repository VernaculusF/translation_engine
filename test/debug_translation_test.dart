import 'package:test/test.dart';
import 'package:translation_engine/src/core/translation_engine.dart';
import 'package:translation_engine/src/data/database_manager_ffi.dart';
import 'package:translation_engine/src/data/dictionary_repository.dart';
import 'package:translation_engine/src/utils/cache_manager.dart';

void main() {
  group('Translation Engine Debug Tests', () {
    test('Test dictionary database connection and data', () async {
      print('=== Testing Dictionary Database ===');
      
      final dbManager = DatabaseManagerFfi(customDatabasePath: '.\\translation_data');
      final cache = CacheManager();
      final dictRepo = DictionaryRepository(databaseManager: dbManager, cacheManager: cache);
      
      try {
        // Проверим, сколько записей в базе
        final allWords = await dictRepo.searchByWord('', 'en-ru');
        print('Total words in en-ru dictionary (approx): ${allWords.length}');
        
        if (allWords.isEmpty) {
          print('ERROR: No words found in dictionary!');
          return;
        }
        
        // Покажем первые 10 слов
        print('First 10 words in dictionary:');
        for (int i = 0; i < 10 && i < allWords.length; i++) {
          final word = allWords[i];
          print('  ${word.sourceWord} -> ${word.targetWord}');
        }
        
        // Проверим конкретные слова
        final testWords = ['he', 'hello', 'world', 'good', 'morning'];
        print('\n=== Testing specific word lookups ===');
        
        for (final testWord in testWords) {
          final results = await dictRepo.searchByWord(testWord, 'en-ru');
          print('Lookup "$testWord": found ${results.length} results');
          for (final result in results) {
            print('  $testWord -> ${result.targetWord}');
          }
        }
        
      } catch (e, stackTrace) {
        print('Error during dictionary test: $e');
        print('Stack trace: $stackTrace');
      }
    });
    
    test('Test full translation engine pipeline', () async {
      print('\n=== Testing Full Translation Pipeline ===');
      
      try {
        final engine = TranslationEngine.instance(reset: true);
        await engine.initialize(customDatabasePath: '.\\translation_data');
        print('Translation engine initialized successfully');
        
        final testCases = [
          'he',
          'hello', 
          'world',
          'good morning',
          'hello world'
        ];
        
        for (final testCase in testCases) {
          print('\nTranslating: "$testCase"');
          
          final result = await engine.translate(
            testCase,
            sourceLanguage: 'en',
            targetLanguage: 'ru',
          );
          
          print('  Input: "$testCase"');
          print('  Output: "${result.translatedText}"');
          print('  Processing time: ${result.processingTimeMs}ms');
          print('  Confidence: ${result.confidence}');
          
          if (result.layerResults.isNotEmpty) {
            print('  Debug info:');
            for (final debug in result.layerResults) {
              print('    ${debug.layerName}: ${debug.processingTimeMs}ms - ${debug.summary}');
            }
          }
        }
        
        await engine.dispose();
        
      } catch (e, stackTrace) {
        print('Error during translation test: $e');
        print('Stack trace: $stackTrace');
      }
    });
  });
}