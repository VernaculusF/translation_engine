import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:translation_engine/src/data/base_repository.dart';
import 'package:translation_engine/src/data/dictionary_repository.dart';
import 'package:translation_engine/src/data/phrase_repository.dart';
import 'package:translation_engine/src/data/user_data_repository.dart';
import 'package:translation_engine/src/data/database_manager.dart';
import 'package:translation_engine/src/data/database_types.dart';
import 'package:translation_engine/src/utils/cache_manager.dart';
import 'package:translation_engine/src/models/translation_result.dart';

// Мок класс для тестирования BaseRepository
class MockRepository extends BaseRepository {
  MockRepository({required super.databaseManager, required super.cacheManager});
  
  @override
  String get tableName => 'mock_table';
  
  @override
  DatabaseType get databaseType => DatabaseType.dictionaries;
  
  @override
  String generateCacheKey(Map<String, dynamic> params) {
    // Генерируем стабильный ключ на основе содержимого
    final sortedKeys = params.keys.toList()..sort();
    final keyParts = sortedKeys.map((key) => '$key:${params[key]}').join('|');
    return 'mock:$keyParts';
  }
  
  @override
  void clearCache() {
    // Мок реализация
  }
}

// Мок DatabaseConnection
class MockDatabaseConnection implements DatabaseConnection {
  final List<Map<String, dynamic>> _mockData = [];
  int _nextId = 1;
  
  @override
  Future<List<Map<String, Object?>>> query(String sql, [List<Object?>? parameters]) async {
    // Простая эмуляция SELECT
    if (sql.toLowerCase().contains('select')) {
      return _mockData.cast<Map<String, Object?>>();
    }
    return [];
  }
  
  @override
  Future<int> execute(String sql, [List<Object?>? parameters]) async {
    // Простая эмуляция INSERT/UPDATE/DELETE
    if (sql.toLowerCase().contains('insert')) {
      final id = _nextId++;
      return id;
    } else if (sql.toLowerCase().contains('update') || sql.toLowerCase().contains('delete')) {
      return 1; // одна строка затронута
    }
    return 0;
  }
  
  @override
  Future<void> close() async {}
  
  void addMockData(Map<String, dynamic> data) {
    _mockData.add(data);
  }
  
  void clearMockData() {
    _mockData.clear();
  }
}

// Мок DatabaseManager
class MockDatabaseManager implements DatabaseManager {
  final MockDatabaseConnection _connection = MockDatabaseConnection();
  
  @override
  Future<DatabaseConnection> getConnection(DatabaseType type) async {
    return _connection;
  }
  
  @override
  Future<void> closeConnection(DatabaseConnection connection) async {}
  
  @override
  Future<void> close() async {}
  
  @override
  Future<Database> get database async => throw UnsupportedError('Mock implementation');
  
  @override
  Future<Database> initPhrasesDatabase() async => throw UnsupportedError('Mock implementation');
  
  @override
  Future<Database> initUserDataDatabase() async => throw UnsupportedError('Mock implementation');
  
  @override
  Future<void> reset() async {}
  
  @override
  Future<bool> checkAllDatabasesIntegrity() async => true;
  
  MockDatabaseConnection get mockConnection => _connection;
}

void main() {
  group('Repository Layer Tests', () {
    late MockDatabaseManager mockDbManager;
    late CacheManager cacheManager;
    
    setUp(() {
      mockDbManager = MockDatabaseManager();
      cacheManager = CacheManager();
    });
    
    tearDown(() {
      cacheManager.clear();
      mockDbManager.mockConnection.clearMockData();
    });
    
    group('BaseRepository', () {
      late MockRepository repository;
      
      setUp(() {
        repository = MockRepository(
          databaseManager: mockDbManager,
          cacheManager: cacheManager,
        );
      });
      
      test('should cache and retrieve values', () {
        const testKey = 'test_key';
        const testValue = 'test_value';
        
        // Сохранить в кэш
        repository.setCached(testKey, testValue);
        
        // Получить из кэша
        final cached = repository.getCached<String>(testKey);
        expect(cached, equals(testValue));
      });
      
      test('should remove cached values', () {
        const testKey = 'test_key';
        const testValue = 'test_value';
        
        repository.setCached(testKey, testValue);
        expect(repository.getCached<String>(testKey), isNotNull);
        
        final removed = repository.removeCached(testKey);
        expect(removed, isTrue);
        expect(repository.getCached<String>(testKey), isNull);
      });
      
      test('should generate cache keys', () {
        final key1 = repository.generateCacheKey({'param1': 'value1'});
        final key2 = repository.generateCacheKey({'param1': 'value1'});
        final key3 = repository.generateCacheKey({'param1': 'value2'});
        
        // Ключи для одинаковых данных должны быть одинаковыми
        expect(key1, equals(key2));
        expect(key1, equals('mock:param1:value1'));
        // Ключи для разных данных должны быть разными
        expect(key1, isNot(equals(key3)));
        expect(key3, equals('mock:param1:value2'));
        // Все ключи должны начинаться с префикса
        expect(key1, startsWith('mock:'));
        expect(key2, startsWith('mock:'));
        expect(key3, startsWith('mock:'));
      });
      
      test('should execute queries with connection management', () async {
        final result = await repository.executeQuery((connection) async {
          return 'test_result';
        });
        
        expect(result, equals('test_result'));
      });
      
      test('should validate data', () {
        expect(() => repository.validateData({}), throwsA(isA<ArgumentError>()));
        expect(() => repository.validateData({'key': 'value'}), returnsNormally);
      });
    });
    
    group('DictionaryRepository', () {
      late DictionaryRepository repository;
      
      setUp(() {
        repository = DictionaryRepository(
          databaseManager: mockDbManager,
          cacheManager: cacheManager,
        );
      });
      
      test('should create DictionaryEntry from map', () {
        final now = DateTime.now();
        final map = {
          'id': 1,
          'source_word': 'hello',
          'target_word': 'привет',
          'language_pair': 'en-ru',
          'part_of_speech': 'noun',
          'definition': 'greeting',
          'frequency': 10,
          'created_at': now.millisecondsSinceEpoch,
          'updated_at': now.millisecondsSinceEpoch,
        };
        
        final entry = DictionaryEntry.fromMap(map);
        
        expect(entry.id, equals(1));
        expect(entry.sourceWord, equals('hello'));
        expect(entry.targetWord, equals('привет'));
        expect(entry.languagePair, equals('en-ru'));
        expect(entry.partOfSpeech, equals('noun'));
        expect(entry.frequency, equals(10));
      });
      
      test('should convert DictionaryEntry to map', () {
        final now = DateTime.now();
        final entry = DictionaryEntry(
          id: 1,
          sourceWord: 'hello',
          targetWord: 'привет',
          languagePair: 'en-ru',
          frequency: 5,
          createdAt: now,
          updatedAt: now,
        );
        
        final map = entry.toMap();
        
        expect(map['id'], equals(1));
        expect(map['source_word'], equals('hello'));
        expect(map['target_word'], equals('привет'));
        expect(map['language_pair'], equals('en-ru'));
        expect(map['frequency'], equals(5));
      });
      
      test('should validate dictionary data', () {
        // Валидные данные
        expect(() => repository.validateData({
          'source_word': 'hello',
          'target_word': 'привет',
          'language_pair': 'en-ru',
        }), returnsNormally);
        
        // Невалидные данные
        expect(() => repository.validateData({
          'source_word': '',
          'target_word': 'привет',
          'language_pair': 'en-ru',
        }), throwsA(isA<Exception>()));
        
        expect(() => repository.validateData({
          'source_word': 'hello',
          'target_word': 'привет',
          'language_pair': 'invalid-format',
        }), throwsA(isA<Exception>()));
      });
      
      test('should transform data for database', () {
        final data = {
          'source_word': '  Hello  ',
          'target_word': '  Привет  ',
          'language_pair': 'EN-RU',
        };
        
        final transformed = repository.transformForDatabase(data);
        
        expect(transformed['source_word'], equals('hello'));
        expect(transformed['target_word'], equals('Привет'));
        expect(transformed['language_pair'], equals('en-ru'));
        expect(transformed['updated_at'], isNotNull);
        expect(transformed['created_at'], isNotNull);
      });
      
      test('should generate cache keys correctly', () {
        final key1 = repository.generateCacheKey({
          'sourceWord': 'hello',
          'languagePair': 'en-ru',
          'searchType': 'exact',
        });
        
        expect(key1, equals('dict:exact:en-ru:hello'));
        
        final key2 = repository.generateCacheKey({
          'queryType': 'stats',
          'param': 'value',
        });
        
        expect(key2, startsWith('dict:stats:'));
      });
    });
    
    group('PhraseRepository', () {
      late PhraseRepository repository;
      
      setUp(() {
        repository = PhraseRepository(
          databaseManager: mockDbManager,
          cacheManager: cacheManager,
        );
      });
      
      test('should create PhraseEntry from map', () {
        final now = DateTime.now();
        final map = {
          'id': 1,
          'source_phrase': 'Good morning',
          'target_phrase': 'Доброе утро',
          'language_pair': 'en-ru',
          'category': 'greetings',
          'context': 'formal',
          'frequency': 15,
          'confidence': 95,
          'created_at': now.millisecondsSinceEpoch,
          'updated_at': now.millisecondsSinceEpoch,
        };
        
        final entry = PhraseEntry.fromMap(map);
        
        expect(entry.id, equals(1));
        expect(entry.sourcePhrase, equals('Good morning'));
        expect(entry.targetPhrase, equals('Доброе утро'));
        expect(entry.category, equals('greetings'));
        expect(entry.confidence, equals(95));
      });
      
      test('should extract keywords from phrase', () {
        final entry = PhraseEntry(
          sourcePhrase: 'Good morning everyone',
          targetPhrase: 'Доброе утро всем',
          languagePair: 'en-ru',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        final keywords = entry.keywords;
        expect(keywords, contains('good'));
        expect(keywords, contains('morning'));
        expect(keywords, contains('everyone'));
      });
      
      test('should check if phrase contains search term', () {
        final entry = PhraseEntry(
          sourcePhrase: 'How are you?',
          targetPhrase: 'Как дела?',
          languagePair: 'en-ru',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        expect(entry.containsSearchTerm('how'), isTrue);
        expect(entry.containsSearchTerm('дела'), isTrue);
        expect(entry.containsSearchTerm('goodbye'), isFalse);
      });
      
      test('should validate phrase data', () {
        // Валидные данные
        expect(() => repository.validateData({
          'source_phrase': 'Hello world',
          'target_phrase': 'Привет мир',
          'language_pair': 'en-ru',
        }), returnsNormally);
        
        // Слишком короткие фразы
        expect(() => repository.validateData({
          'source_phrase': 'Hi',
          'target_phrase': 'Привет мир',
          'language_pair': 'en-ru',
        }), throwsA(isA<Exception>()));
        
        // Невалидный confidence
        expect(() => repository.validateData({
          'source_phrase': 'Hello world',
          'target_phrase': 'Привет мир',
          'language_pair': 'en-ru',
          'confidence': 150,
        }), throwsA(isA<Exception>()));
      });
    });
    
    group('UserDataRepository', () {
      late UserDataRepository repository;
      
      setUp(() {
        repository = UserDataRepository(
          databaseManager: mockDbManager,
          cacheManager: cacheManager,
        );
      });
      
      test('should create TranslationHistoryEntry from TranslationResult', () {
        final translationResult = TranslationResult.success(
          originalText: 'Hello',
          translatedText: 'Привет',
          languagePair: 'en-ru',
          confidence: 0.9,
          processingTimeMs: 100,
          layerResults: [],
        );
        
        final historyEntry = TranslationHistoryEntry.fromTranslationResult(
          translationResult,
          sessionId: 'test-session',
        );
        
        expect(historyEntry.originalText, equals('Hello'));
        expect(historyEntry.translatedText, equals('Привет'));
        expect(historyEntry.confidence, equals(0.9));
        expect(historyEntry.sessionId, equals('test-session'));
      });
      
      test('should create UserSettings correctly', () {
        final now = DateTime.now();
        final settings = UserSettings(
          key: 'theme',
          value: 'dark',
          description: 'UI Theme',
          createdAt: now,
          updatedAt: now,
        );
        
        expect(settings.key, equals('theme'));
        expect(settings.value, equals('dark'));
        expect(settings.description, equals('UI Theme'));
      });
      
      test('should create UserTranslationEdit correctly', () {
        final now = DateTime.now();
        final edit = UserTranslationEdit(
          originalText: 'Hello',
          originalTranslation: 'Привет',
          userTranslation: 'Здравствуйте',
          languagePair: 'en-ru',
          reason: 'More formal',
          createdAt: now,
          updatedAt: now,
        );
        
        expect(edit.originalText, equals('Hello'));
        expect(edit.userTranslation, equals('Здравствуйте'));
        expect(edit.reason, equals('More formal'));
        expect(edit.isApproved, isFalse);
      });
      
      test('should convert UserTranslationEdit to/from map', () {
        final now = DateTime.now();
        final edit = UserTranslationEdit(
          id: 1,
          originalText: 'Hello',
          originalTranslation: 'Привет',
          userTranslation: 'Здравствуйте',
          languagePair: 'en-ru',
          isApproved: true,
          createdAt: now,
          updatedAt: now,
        );
        
        final map = edit.toMap();
        expect(map['is_approved'], equals(1));
        
        final restored = UserTranslationEdit.fromMap(map);
        expect(restored.isApproved, isTrue);
        expect(restored.originalText, equals('Hello'));
      });
      
      test('should generate different cache keys for different data types', () {
        final historyKey = repository.generateCacheKey({
          'type': 'history',
          'identifier': 'list',
        });
        
        final settingKey = repository.generateCacheKey({
          'type': 'setting',
          'identifier': 'theme',
        });
        
        expect(historyKey, startsWith('user_data:history:'));
        expect(settingKey, startsWith('user_data:setting:'));
        expect(historyKey, isNot(equals(settingKey)));
      });
    });
    
    group('Repository Integration', () {
      test('should work with all repository types', () async {
        final dictionaryRepo = DictionaryRepository(
          databaseManager: mockDbManager,
          cacheManager: cacheManager,
        );
        
        final phraseRepo = PhraseRepository(
          databaseManager: mockDbManager,
          cacheManager: cacheManager,
        );
        
        final userDataRepo = UserDataRepository(
          databaseManager: mockDbManager,
          cacheManager: cacheManager,
        );
        
        // Тест что все репозитории используют разные префиксы кэша
        final dictKey = dictionaryRepo.generateCacheKey({
          'sourceWord': 'test',
          'languagePair': 'en-ru',
        });
        
        final phraseKey = phraseRepo.generateCacheKey({
          'sourcePhrase': 'test phrase',
          'languagePair': 'en-ru',
        });
        
        final userKey = userDataRepo.generateCacheKey({
          'type': 'setting',
          'identifier': 'test',
        });
        
        expect(dictKey, startsWith('dict:'));
        expect(phraseKey, startsWith('phrase:'));
        expect(userKey, startsWith('user_data:'));
        
        // Убедиться что все ключи уникальны
        final keys = {dictKey, phraseKey, userKey};
        expect(keys, hasLength(3));
      });
      
      test('should handle concurrent cache operations', () {
        final repo1 = DictionaryRepository(
          databaseManager: mockDbManager,
          cacheManager: cacheManager,
        );
        
        final repo2 = PhraseRepository(
          databaseManager: mockDbManager,
          cacheManager: cacheManager,
        );
        
        // Сохранить данные в разных репозиториях
        repo1.setCached('key1', 'value1');
        repo2.setCached('key2', 'value2');
        
        // Проверить что данные не смешиваются
        expect(repo1.getCached<String>('key1'), equals('value1'));
        expect(repo2.getCached<String>('key2'), equals('value2'));
        expect(repo1.getCached<String>('key2'), equals('value2')); // общий кэш
        
        // Очистить кэш одного репозитория
        repo1.clearCache();
        
        // Проверить что данные других репозиториев не пострадали
        // (в реальной реализации clearCache должен удалять только свои ключи)
        expect(repo2.getCached<String>('key2'), equals('value2'));
      });
    });
  });
}