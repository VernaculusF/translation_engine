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
  group('Data Layer Integration Tests', () {
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
      test('should store and retrieve dictionary entries with caching', () async {
        const sourceWord = 'hello';
        const targetWord = 'привет';
        const languagePair = 'en-ru';
        
        // Добавить запись (должна сохраниться в БД и кэше)
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
        
        // Получить перевод (должен прийти из кэша)
        final retrievedEntry = await dictionaryRepo.getTranslation(sourceWord, languagePair);
        expect(retrievedEntry, isNotNull);
        expect(retrievedEntry!.sourceWord, equals(sourceWord));
        expect(retrievedEntry.targetWord, equals(targetWord));
        
        // Очистить кэш и получить снова (должен прийти из БД)
        dictionaryRepo.clearCache();
        final retrievedFromDb = await dictionaryRepo.getTranslation(sourceWord, languagePair);
        expect(retrievedFromDb, isNotNull);
        expect(retrievedFromDb!.sourceWord, equals(sourceWord));
        expect(retrievedFromDb.id, equals(addedEntry.id));
      });

      test('should handle multiple translations and search functionality', () async {
        // Добавить несколько переводов
        await dictionaryRepo.addTranslation('cat', 'кот', 'en-ru', partOfSpeech: 'noun', frequency: 15);
        await dictionaryRepo.addTranslation('dog', 'собака', 'en-ru', partOfSpeech: 'noun', frequency: 20);
        await dictionaryRepo.addTranslation('house', 'дом', 'en-ru', partOfSpeech: 'noun', frequency: 25);

        // Поиск по части слова
        final searchResults = await dictionaryRepo.searchByWord('o', 'en-ru');
        expect(searchResults.length, greaterThanOrEqualTo(2)); // dog, house содержат 'o'
        
        // Проверить что результаты отсортированы по частотности
        for (int i = 0; i < searchResults.length - 1; i++) {
          expect(searchResults[i].frequency, greaterThanOrEqualTo(searchResults[i + 1].frequency));
        }
      });
    });

    group('Phrase Repository Integration', () {
      test('should store and retrieve phrase entries with caching', () async {
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
        expect(retrievedEntry.category, equals('greetings'));
      });

      test('should handle phrase search by category', () async {
        // Добавить фразы разных категорий
        await phraseRepo.addPhrase('Hello', 'Привет', 'en-ru', category: 'greetings', frequency: 10, confidence: 95);
        await phraseRepo.addPhrase('Good evening', 'Добрый вечер', 'en-ru', category: 'greetings', frequency: 8, confidence: 90);
        await phraseRepo.addPhrase('Please sign here', 'Подпишите здесь, пожалуйста', 'en-ru', category: 'business', frequency: 3, confidence: 85);

        // Поиск по категории
        final greetings = await phraseRepo.getPhrasesByCategory('greetings', 'en-ru');
        expect(greetings.length, equals(2));
        expect(greetings.every((p) => p.category == 'greetings'), isTrue);

        final business = await phraseRepo.getPhrasesByCategory('business', 'en-ru');
        expect(business.length, equals(1));
        expect(business.first.category, equals('business'));
      });
    });

    group('User Data Repository Integration', () {
      test('should store and retrieve translation history', () async {
        // Создать результат перевода с правильными параметрами
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
          LayerDebugInfo.success(
            layerName: 'post_processing',
            processingTimeMs: 20,
            itemsProcessed: 1,
            modificationsCount: 0,
          ),
        ];

        final translationResult = TranslationResult(
          originalText: 'Hello world',
          translatedText: 'Привет мир',
          languagePair: 'en-ru',
          confidence: 0.95,
          processingTimeMs: 150,
          timestamp: DateTime.now(),
          layersProcessed: 3,
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

        // Получить историю по языковой паре
        final enRuHistory = await userDataRepo.getTranslationHistory(languagePair: 'en-ru');
        expect(enRuHistory.length, equals(1));

        final frRuHistory = await userDataRepo.getTranslationHistory(languagePair: 'fr-ru');
        expect(frRuHistory.length, equals(0));
      });

      test('should manage user settings', () async {
        const settingKey = 'default_language_pair';
        const settingValue = 'en-ru';

        // Сохранить настройку
        final setting = await userDataRepo.setSetting(settingKey, settingValue, description: 'Default translation pair');
        expect(setting.key, equals(settingKey));
        expect(setting.value, equals(settingValue));

        // Получить настройку
        final retrievedSetting = await userDataRepo.getSetting(settingKey);
        expect(retrievedSetting, isNotNull);
        expect(retrievedSetting!.value, equals(settingValue));

        // Обновить настройку
        const newValue = 'ru-en';
        final updatedSetting = await userDataRepo.setSetting(settingKey, newValue);
        expect(updatedSetting.value, equals(newValue));

        // Проверить обновление
        final finalSetting = await userDataRepo.getSetting(settingKey);
        expect(finalSetting!.value, equals(newValue));
      });

      test('should handle user translation edits', () async {
        const originalText = 'How are you?';
        const originalTranslation = 'Как дела?';
        const userTranslation = 'Как поживаешь?';
        const languagePair = 'en-ru';

        // Добавить пользовательскую правку
        final edit = await userDataRepo.addTranslationEdit(
          originalText,
          originalTranslation,
          userTranslation,
          languagePair,
          reason: 'More natural translation',
        );

        expect(edit.id, isNotNull);
        expect(edit.userTranslation, equals(userTranslation));
        expect(edit.reason, equals('More natural translation'));

        // Получить правки пользователя
        final edits = await userDataRepo.getTranslationEdits(languagePair: languagePair);
        expect(edits.length, equals(1));
        expect(edits.first.userTranslation, equals(userTranslation));
      });
    });

    group('Cross-Repository Integration', () {
      test('should handle complex translation workflow', () async {
        const sourceText = 'Good morning, how are you?';
        const languagePair = 'en-ru';

        // 1. Добавить словарные переводы
        await dictionaryRepo.addTranslation('good', 'хороший', languagePair, partOfSpeech: 'adjective', frequency: 100);
        await dictionaryRepo.addTranslation('morning', 'утро', languagePair, partOfSpeech: 'noun', frequency: 80);

        // 2. Добавить готовую фразу
        await phraseRepo.addPhrase('Good morning', 'Доброе утро', languagePair, category: 'greetings', frequency: 50, confidence: 95);

        // 3. Создать результат перевода
        final layerResults = [
          LayerDebugInfo.success(layerName: 'pre_processing', processingTimeMs: 40),
          LayerDebugInfo.success(layerName: 'phrase_lookup', processingTimeMs: 60),
          LayerDebugInfo.success(layerName: 'dictionary', processingTimeMs: 80),
          LayerDebugInfo.success(layerName: 'post_processing', processingTimeMs: 20),
        ];

        final translationResult = TranslationResult(
          originalText: sourceText,
          translatedText: 'Доброе утро, как дела?',
          languagePair: languagePair,
          confidence: 0.88,
          processingTimeMs: 200,
          timestamp: DateTime.now(),
          layersProcessed: 4,
          layerResults: layerResults,
          hasError: false,
          qualityScore: 0.85,
        );

        // 4. Добавить в историю
        await userDataRepo.addToHistory(translationResult, sessionId: 'workflow_test');

        // 5. Пользователь исправляет перевод
        await userDataRepo.addTranslationEdit(
          sourceText,
          'Доброе утро, как дела?',
          'Доброе утро, как поживаешь?',
          languagePair,
          reason: 'More colloquial',
        );

        // 6. Проверить, что все данные сохранились корректно
        final retrievedPhrase = await phraseRepo.getPhraseTranslation('Good morning', languagePair);
        expect(retrievedPhrase, isNotNull);
        expect(retrievedPhrase!.targetPhrase, equals('Доброе утро'));

        final goodTranslation = await dictionaryRepo.getTranslation('good', languagePair);
        expect(goodTranslation, isNotNull);
        expect(goodTranslation!.targetWord, equals('хороший'));

        final history = await userDataRepo.getTranslationHistory(sessionId: 'workflow_test');
        expect(history.length, equals(1));
        expect(history.first.originalText, equals(sourceText));

        final edits = await userDataRepo.getTranslationEdits(languagePair: languagePair);
        expect(edits.length, equals(1));
        expect(edits.first.userTranslation, equals('Доброе утро, как поживаешь?'));
      });

      test('should handle cache consistency across repositories', () async {
        const languagePair = 'en-ru';
        
        // Добавить данные через разные репозитории
        await dictionaryRepo.addTranslation('test', 'тест', languagePair, frequency: 1);
        await phraseRepo.addPhrase('test phrase', 'тестовая фраза', languagePair, frequency: 1, confidence: 90);

        // Проверить кэширование
        final dictCached = await dictionaryRepo.getTranslation('test', languagePair);
        final phraseCached = await phraseRepo.getPhraseTranslation('test phrase', languagePair);
        
        expect(dictCached, isNotNull);
        expect(phraseCached, isNotNull);

        // Очистить кэши по отдельности
        dictionaryRepo.clearCache();
        phraseRepo.clearCache();

        // Данные должны по-прежнему быть доступны из БД
        final dictFromDb = await dictionaryRepo.getTranslation('test', languagePair);
        final phraseFromDb = await phraseRepo.getPhraseTranslation('test phrase', languagePair);
        
        expect(dictFromDb, isNotNull);
        expect(phraseFromDb, isNotNull);
      });
    });

    group('Performance and Stress Tests', () {
      test('should handle bulk operations efficiently', () async {
        const languagePair = 'en-ru';
        const bulkSize = 50; // Уменьшим размер для быстроты тестов

        final stopwatch = Stopwatch()..start();

        // Массовое добавление словарных записей
        for (int i = 0; i < bulkSize; i++) {
          await dictionaryRepo.addTranslation('word$i', 'слово$i', languagePair, frequency: i);
        }

        stopwatch.stop();
        final addTime = stopwatch.elapsedMilliseconds;

        // Производительность должна быть разумной (< 3 сек для 50 записей)
        expect(addTime, lessThan(3000));

        stopwatch.reset();
        stopwatch.start();

        // Массовое чтение (первый раз - из БД, второй - из кэша)
        for (int i = 0; i < bulkSize; i++) {
          final result = await dictionaryRepo.getTranslation('word$i', languagePair);
          expect(result, isNotNull);
        }

        stopwatch.stop();
        final firstReadTime = stopwatch.elapsedMilliseconds;

        stopwatch.reset();
        stopwatch.start();

        // Второе чтение (из кэша должно быть быстрее)
        for (int i = 0; i < bulkSize; i++) {
          final result = await dictionaryRepo.getTranslation('word$i', languagePair);
          expect(result, isNotNull);
        }

        stopwatch.stop();
        final secondReadTime = stopwatch.elapsedMilliseconds;

        // Второе чтение должно быть значительно быстрее (кэш)
        expect(secondReadTime, lessThan(firstReadTime));
      });

      test('should maintain data integrity under concurrent access', () async {
        const languagePair = 'en-ru';
        final futures = <Future<void>>[];

        // Параллельные операции записи
        for (int i = 0; i < 5; i++) {
          futures.add(
            dictionaryRepo.addTranslation('concurrent$i', 'параллель$i', languagePair, frequency: i)
          );
        }

        await Future.wait(futures);

        // Проверить, что все записи сохранились
        for (int i = 0; i < 5; i++) {
          final result = await dictionaryRepo.getTranslation('concurrent$i', languagePair);
          expect(result, isNotNull);
          expect(result!.targetWord, equals('параллель$i'));
        }
      });
    });

    group('Database Integrity Tests', () {
      test('should maintain referential integrity', () async {
        // Проверить целостность всех баз данных
        final isIntegrityOk = await databaseManager.checkAllDatabasesIntegrity();
        expect(isIntegrityOk, isTrue);
      });

      test('should handle database errors gracefully', () async {
        // Закрыть базу данных
        await databaseManager.close();

        // Попытка операции должна вызвать ошибку
        expect(
          () => dictionaryRepo.addTranslation('test', 'тест', 'en-ru', frequency: 1),
          throwsException,
        );
      });
    });
  });
}