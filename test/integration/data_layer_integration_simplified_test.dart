import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:translation_engine/src/data/database_manager.dart';
import 'package:translation_engine/src/data/dictionary_repository.dart';
import 'package:translation_engine/src/data/phrase_repository.dart';
import 'package:translation_engine/src/data/user_data_repository.dart';
import 'package:translation_engine/src/utils/cache_manager.dart';
import 'package:translation_engine/src/models/translation_result.dart';
import 'package:translation_engine/src/models/layer_debug_info.dart';
import 'dart:io';

void main() {
  group('Data Layer Integration Tests (Simplified)', () {
    late DatabaseManager databaseManager;
    late CacheManager cacheManager;
    late DictionaryRepository dictionaryRepo;
    late PhraseRepository phraseRepo;
    late UserDataRepository userDataRepo;
    late Directory tempDir;

    setUpAll(() async {
      // Инициализация sqflite для тестов
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Создание временной директории для тестовых баз данных
      tempDir = await Directory.systemTemp.createTemp('translation_engine_test_');
      
      // Инициализация компонентов
      databaseManager = DatabaseManager(customDatabasePath: tempDir.path);
      cacheManager = CacheManager();
      
      dictionaryRepo = DictionaryRepository(
        databaseManager: databaseManager,
        cacheManager: cacheManager,
      );
      
      phraseRepo = PhraseRepository(
        databaseManager: databaseManager,
        cacheManager: cacheManager,
      );
      
      userDataRepo = UserDataRepository(
        databaseManager: databaseManager,
        cacheManager: cacheManager,
      );
      
      // Инициализация баз данных
      await databaseManager.database;
      await databaseManager.initPhrasesDatabase();
      await databaseManager.initUserDataDatabase();
    });

    tearDown(() async {
      await databaseManager.close();
      cacheManager.clear();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Dictionary Repository Integration', () {
      test('should store and retrieve dictionary entries', () async {
        const sourceWord = 'hello';
        const targetWord = 'привет';
        const languagePair = 'en-ru';
        
        // Добавить запись
        final addedEntry = await dictionaryRepo.addTranslation(
          sourceWord,
          targetWord,
          languagePair,
          partOfSpeech: 'noun',
          definition: 'A greeting',
          frequency: 10,
        );
        expect(addedEntry.id, isNotNull);
        expect(addedEntry.sourceWord, equals(sourceWord));
        
        // Получить перевод
        final retrievedEntry = await dictionaryRepo.getTranslation(sourceWord, languagePair);
        expect(retrievedEntry, isNotNull);
        expect(retrievedEntry!.sourceWord, equals(sourceWord));
        expect(retrievedEntry.targetWord, equals(targetWord));
      });

      test('should handle cache operations', () async {
        const sourceWord = 'test';
        const targetWord = 'тест';
        const languagePair = 'en-ru';
        
        // Добавить и проверить кэш
        await dictionaryRepo.addTranslation(sourceWord, targetWord, languagePair);
        
        // Очистить кэш и проверить что данные все еще доступны из БД
        dictionaryRepo.clearCache();
        final entry = await dictionaryRepo.getTranslation(sourceWord, languagePair);
        expect(entry, isNotNull);
        expect(entry!.sourceWord, equals(sourceWord));
      });
    });

    group('Phrase Repository Integration', () {
      test('should store and retrieve phrase entries', () async {
        const sourcePhrase = 'Good morning';
        const targetPhrase = 'Доброе утро';
        const languagePair = 'en-ru';
        
        // Добавить запись
        final addedEntry = await phraseRepo.addPhrase(
          sourcePhrase,
          targetPhrase, 
          languagePair,
          category: 'greetings',
          context: 'formal',
          frequency: 5,
          confidence: 95,
        );
        expect(addedEntry.id, isNotNull);
        expect(addedEntry.sourcePhrase, equals(sourcePhrase));
        
        // Получить перевод фразы
        final retrievedEntry = await phraseRepo.getPhraseTranslation(sourcePhrase, languagePair);
        expect(retrievedEntry, isNotNull);
        expect(retrievedEntry!.sourcePhrase, equals(sourcePhrase));
        expect(retrievedEntry.targetPhrase, equals(targetPhrase));
      });
    });

    group('User Data Repository Integration', () {
      test('should store and retrieve translation history', () async {
        // Создать результат перевода
        final layerResults = [
          LayerDebugInfo.success(
            layerName: 'pre_processing',
            processingTimeMs: 50,
            itemsProcessed: 2,
            modificationsCount: 1,
          ),
          LayerDebugInfo.success(
            layerName: 'dictionary',
            processingTimeMs: 80,
            itemsProcessed: 2,
            modificationsCount: 2,
          ),
        ];

        final translationResult = TranslationResult(
          originalText: 'Hello world',
          translatedText: 'Привет мир',
          languagePair: 'en-ru',
          confidence: 0.95,
          processingTimeMs: 150,
          timestamp: DateTime.now(),
          layersProcessed: 2,
          layerResults: layerResults,
          hasError: false,
          qualityScore: 0.9,
        );

        // Добавить в историю
        final historyEntry = await userDataRepo.addToHistory(translationResult, sessionId: 'test_session');
        expect(historyEntry.id, isNotNull);
        expect(historyEntry.originalText, equals('Hello world'));
        expect(historyEntry.sessionId, equals('test_session'));

        // Получить историю
        final history = await userDataRepo.getTranslationHistory(limit: 10);
        expect(history.length, equals(1));
        expect(history.first.originalText, equals('Hello world'));
      });
    });

    group('Cross-Component Integration', () {
      test('should handle basic workflow with all repositories', () async {
        const languagePair = 'en-ru';

        // 1. Добавить словарный перевод
        await dictionaryRepo.addTranslation('good', 'хороший', languagePair, frequency: 100);

        // 2. Добавить фразовый перевод
        await phraseRepo.addPhrase('Good morning', 'Доброе утро', languagePair, frequency: 50, confidence: 95);

        // 3. Создать результат перевода
        final layerResults = [
          LayerDebugInfo.success(layerName: 'dictionary', processingTimeMs: 80),
        ];

        final translationResult = TranslationResult(
          originalText: 'Good morning',
          translatedText: 'Доброе утро',
          languagePair: languagePair,
          confidence: 0.88,
          processingTimeMs: 200,
          timestamp: DateTime.now(),
          layersProcessed: 1,
          layerResults: layerResults,
          hasError: false,
          qualityScore: 0.85,
        );

        // 4. Добавить в историю
        await userDataRepo.addToHistory(translationResult, sessionId: 'workflow_test');

        // 5. Проверить, что все данные сохранились
        final dictEntry = await dictionaryRepo.getTranslation('good', languagePair);
        expect(dictEntry, isNotNull);
        expect(dictEntry!.targetWord, equals('хороший'));

        final phraseEntry = await phraseRepo.getPhraseTranslation('Good morning', languagePair);
        expect(phraseEntry, isNotNull);
        expect(phraseEntry!.targetPhrase, equals('Доброе утро'));

        final history = await userDataRepo.getTranslationHistory(sessionId: 'workflow_test');
        expect(history.length, equals(1));
        expect(history.first.originalText, equals('Good morning'));
      });

      test('should handle cache operations across repositories', () async {
        const languagePair = 'en-ru';
        
        // Добавить данные через разные репозитории
        await dictionaryRepo.addTranslation('test', 'тест', languagePair, frequency: 1);
        await phraseRepo.addPhrase('test phrase', 'тестовая фраза', languagePair, frequency: 1, confidence: 90);

        // Проверить кэширование
        final dictCached = await dictionaryRepo.getTranslation('test', languagePair);
        final phraseCached = await phraseRepo.getPhraseTranslation('test phrase', languagePair);
        
        expect(dictCached, isNotNull);
        expect(phraseCached, isNotNull);

        // Очистить кэши
        dictionaryRepo.clearCache();
        phraseRepo.clearCache();

        // Данные должны по-прежнему быть доступны из БД
        final dictFromDb = await dictionaryRepo.getTranslation('test', languagePair);
        final phraseFromDb = await phraseRepo.getPhraseTranslation('test phrase', languagePair);
        
        expect(dictFromDb, isNotNull);
        expect(phraseFromDb, isNotNull);
      });
    });

    group('Database Integrity Tests', () {
      test('should maintain database integrity', () async {
        // Проверить целостность всех баз данных
        final isIntegrityOk = await databaseManager.checkAllDatabasesIntegrity();
        expect(isIntegrityOk, isTrue);
      });

      test('should handle concurrent operations', () async {
        const languagePair = 'en-ru';
        final futures = <Future<void>>[];

        // Параллельные операции записи (уменьшенное количество)
        for (int i = 0; i < 3; i++) {
          futures.add(
            dictionaryRepo.addTranslation('concurrent$i', 'параллель$i', languagePair, frequency: i)
          );
        }

        await Future.wait(futures);

        // Проверить, что все записи сохранились
        for (int i = 0; i < 3; i++) {
          final result = await dictionaryRepo.getTranslation('concurrent$i', languagePair);
          expect(result, isNotNull);
          expect(result!.targetWord, equals('параллель$i'));
        }
      });
    });
  });
}