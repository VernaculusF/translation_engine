import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:fluent_translate/src/data/dictionary_repository.dart';
import 'package:fluent_translate/src/data/phrase_repository.dart';
import 'package:fluent_translate/src/utils/cache_manager.dart';

/// Тесты конкурентного доступа к репозиториям
/// 
/// Проверяют корректность работы при одновременном доступе
/// к репозиториям из нескольких изолятов/потоков
void main() {
  late Directory tempDir;
  late String testDbPath;
  
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('concurrent_test_');
    testDbPath = tempDir.path;
  });
  
  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });
  
  group('DictionaryRepository Concurrent Access', () {
    test('concurrent bulk inserts do not corrupt data', () async {
      final repo = DictionaryRepository(
        dataDirPath: testDbPath,
        cacheManager: CacheManager(),
      );
      
      // Создаём 3 параллельных задачи записи
      final futures = <Future>[];
      
      for (var i = 0; i < 3; i++) {
        final batch = List.generate(100, (j) => {
          'source_word': 'word_${i}_$j',
          'target_word': 'слово_${i}_$j',
          'language_pair': 'en-ru',
          'frequency': j,
        });
        
        futures.add(repo.addTranslationsBulk(batch));
      }
      
      // Ждём завершения всех задач
      await Future.wait(futures);
      
      // Проверяем целостность: должны быть все 300 записей
      final allTranslations = await repo.getAllTranslations('en-ru');
      expect(allTranslations.length, equals(300));
      
      // Проверяем уникальность записей
      final uniqueWords = allTranslations.map((e) => e.sourceWord).toSet();
      expect(uniqueWords.length, equals(300), reason: 'All words should be unique');
    });
    
    test('concurrent reads during writes return consistent data', () async {
      final repo = DictionaryRepository(
        dataDirPath: testDbPath,
        cacheManager: CacheManager(),
      );
      
      // Предварительная запись данных
      await repo.addTranslationsBulk(List.generate(50, (i) => {
        'source_word': 'test_$i',
        'target_word': 'тест_$i',
        'language_pair': 'en-ru',
      }));
      
      final futures = <Future>[];
      
      // 5 параллельных чтений
      for (var i = 0; i < 5; i++) {
        futures.add(Future(() async {
          for (var j = 0; j < 50; j++) {
            final result = await repo.getTranslation('test_$j', 'en-ru');
            expect(result, isNotNull, reason: 'Should find test_$j');
            expect(result!.targetWord, equals('тест_$j'));
          }
        }));
      }
      
      // 2 параллельные записи
      for (var i = 0; i < 2; i++) {
        futures.add(repo.addTranslationsBulk(List.generate(25, (j) => {
          'source_word': 'new_${i}_$j',
          'target_word': 'новый_${i}_$j',
          'language_pair': 'en-ru',
        })));
      }
      
      // Все операции должны завершиться без ошибок
      await Future.wait(futures);
      
      // Проверяем финальное состояние
      final allTranslations = await repo.getAllTranslations('en-ru');
      expect(allTranslations.length, greaterThanOrEqualTo(100));
    });
    
    test('cache remains consistent under concurrent access', () async {
      final cacheManager = CacheManager();
      final repo = DictionaryRepository(
        dataDirPath: testDbPath,
        cacheManager: cacheManager,
      );
      
      // Добавляем тестовые данные
      await repo.addTranslationsBulk(List.generate(20, (i) => {
        'source_word': 'cache_test_$i',
        'target_word': 'кэш_тест_$i',
        'language_pair': 'en-ru',
      }));
      
      // Параллельные запросы к одним и тем же данным
      final futures = List.generate(10, (i) => Future(() async {
        for (var j = 0; j < 20; j++) {
          final result = await repo.getTranslation('cache_test_$j', 'en-ru', useCache: true);
          expect(result, isNotNull);
          expect(result!.targetWord, equals('кэш_тест_$j'));
        }
      }));
      
      await Future.wait(futures);
      
      // Проверяем метрики кэша
      final metrics = cacheManager.metrics;
      expect(metrics['generic_hits'], greaterThan(0));
    });
  });
  
  group('PhraseRepository Concurrent Access', () {
    test('concurrent phrase additions maintain integrity', () async {
      final repo = PhraseRepository(
        dataDirPath: testDbPath,
        cacheManager: CacheManager(),
      );
      
      final futures = <Future>[];
      
      // 3 параллельных пакета фраз
      for (var i = 0; i < 3; i++) {
        final batch = List.generate(50, (j) => {
          'source_phrase': 'hello world $i $j',
          'target_phrase': 'привет мир $i $j',
          'language_pair': 'en-ru',
          'category': 'test',
          'confidence': 90 + (j % 10),
        });
        
        futures.add(repo.addPhrasesBulk(batch));
      }
      
      await Future.wait(futures);
      
      // Проверяем целостность
      final allPhrases = await repo.getAllPhrases('en-ru');
      expect(allPhrases.length, equals(150));
      
      // Проверяем уникальность
      final uniquePhrases = allPhrases.map((e) => e.sourcePhrase).toSet();
      expect(uniquePhrases.length, equals(150));
    });
    
    test('concurrent search operations do not interfere', () async {
      final repo = PhraseRepository(
        dataDirPath: testDbPath,
        cacheManager: CacheManager(),
      );
      
      // Подготовка данных
      await repo.addPhrasesBulk(List.generate(30, (i) => {
        'source_phrase': 'test phrase $i',
        'target_phrase': 'тестовая фраза $i',
        'language_pair': 'en-ru',
        'category': 'greeting',
      }));
      
      // Параллельные поиски
      final futures = List.generate(8, (i) => Future(() async {
        for (var j = 0; j < 30; j++) {
          final result = await repo.getPhraseTranslation('test phrase $j', 'en-ru');
          expect(result, isNotNull);
          expect(result!.targetPhrase, equals('тестовая фраза $j'));
        }
      }));
      
      await Future.wait(futures);
    });
  });
  
  group('Cross-Repository Concurrent Access', () {
    test('dictionary and phrase repos can be accessed concurrently', () async {
      final dictRepo = DictionaryRepository(
        dataDirPath: testDbPath,
        cacheManager: CacheManager(),
      );
      
      final phraseRepo = PhraseRepository(
        dataDirPath: testDbPath,
        cacheManager: CacheManager(),
      );
      
      final futures = <Future>[];
      
      // Параллельная запись в оба репозитория
      futures.add(dictRepo.addTranslationsBulk(List.generate(100, (i) => {
        'source_word': 'word_$i',
        'target_word': 'слово_$i',
        'language_pair': 'en-ru',
      })));
      
      futures.add(phraseRepo.addPhrasesBulk(List.generate(100, (i) => {
        'source_phrase': 'phrase $i test',
        'target_phrase': 'фраза $i тест',
        'language_pair': 'en-ru',
      })));
      
      await Future.wait(futures);
      
      // Параллельное чтение
      final readFutures = <Future>[];
      
      readFutures.add(Future(() async {
        for (var i = 0; i < 100; i++) {
          final result = await dictRepo.getTranslation('word_$i', 'en-ru');
          expect(result, isNotNull);
        }
      }));
      
      readFutures.add(Future(() async {
        for (var i = 0; i < 100; i++) {
          final result = await phraseRepo.getPhraseTranslation('phrase $i test', 'en-ru');
          expect(result, isNotNull);
        }
      }));
      
      await Future.wait(readFutures);
      
      // Проверка целостности обоих репозиториев
      final dictCount = (await dictRepo.getAllTranslations('en-ru')).length;
      final phraseCount = (await phraseRepo.getAllPhrases('en-ru')).length;
      
      expect(dictCount, equals(100));
      expect(phraseCount, equals(100));
    });
  });
  
  group('File Lock Verification', () {
    test('file locks prevent corruption during concurrent writes', () async {
      final repo = DictionaryRepository(
        dataDirPath: testDbPath,
        cacheManager: CacheManager(),
      );
      
      // Множественные одновременные записи
      final futures = List.generate(5, (i) => 
        repo.addTranslationsBulk(List.generate(20, (j) => {
          'source_word': 'concurrent_${i}_$j',
          'target_word': 'параллельный_${i}_$j',
          'language_pair': 'en-ru',
        }))
      );
      
      await Future.wait(futures);
      
      // Файл должен быть валидным JSONL после всех операций
      final dictFile = File('$testDbPath/en-ru/dictionary.jsonl');
      expect(await dictFile.exists(), isTrue);
      
      // Проверяем, что файл не поврежден
      final lines = await dictFile.readAsLines();
      var validLines = 0;
      
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          // Должен быть валидным JSON
          final json = Map<String, dynamic>.from(
            // ignore: avoid_dynamic_calls
            jsonDecode(line) as Map
          );
          expect(json['source_word'], isNotNull);
          expect(json['target_word'], isNotNull);
          validLines++;
        } catch (e) {
          fail('Invalid JSON line found: $line, error: $e');
        }
      }
      
      expect(validLines, equals(100), reason: 'All lines should be valid JSON');
    });
  });
}
