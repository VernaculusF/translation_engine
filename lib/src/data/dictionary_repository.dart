import 'base_repository.dart';
import '../utils/exceptions.dart';
import 'database_types.dart';

/// Модель записи словаря
class DictionaryEntry {
  final int? id;
  final String sourceWord;
  final String targetWord;
  final String languagePair; // например: "en-ru"
  final String? partOfSpeech;
  final String? definition;
  final int frequency;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  const DictionaryEntry({
    this.id,
    required this.sourceWord,
    required this.targetWord,
    required this.languagePair,
    this.partOfSpeech,
    this.definition,
    this.frequency = 1,
    required this.createdAt,
    required this.updatedAt,
  });
  
  /// Создание из Map (из базы данных)
  factory DictionaryEntry.fromMap(Map<String, dynamic> map) {
    return DictionaryEntry(
      id: map['id'] as int?,
      sourceWord: map['source_word'] as String,
      targetWord: map['target_word'] as String,
      languagePair: map['language_pair'] as String,
      partOfSpeech: map['part_of_speech'] as String?,
      definition: map['definition'] as String?,
      frequency: map['frequency'] as int? ?? 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
  
  /// Конвертация в Map (для базы данных)
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'source_word': sourceWord,
      'target_word': targetWord,
      'language_pair': languagePair,
      'part_of_speech': partOfSpeech,
      'definition': definition,
      'frequency': frequency,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
  
  /// Создание копии с изменениями
  DictionaryEntry copyWith({
    int? id,
    String? sourceWord,
    String? targetWord,
    String? languagePair,
    String? partOfSpeech,
    String? definition,
    int? frequency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DictionaryEntry(
      id: id ?? this.id,
      sourceWord: sourceWord ?? this.sourceWord,
      targetWord: targetWord ?? this.targetWord,
      languagePair: languagePair ?? this.languagePair,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      definition: definition ?? this.definition,
      frequency: frequency ?? this.frequency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  @override
  String toString() {
    return 'DictionaryEntry(sourceWord: $sourceWord, targetWord: $targetWord, languagePair: $languagePair)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DictionaryEntry &&
        other.sourceWord == sourceWord &&
        other.targetWord == targetWord &&
        other.languagePair == languagePair;
  }
  
  @override
  int get hashCode => Object.hash(sourceWord, targetWord, languagePair);
}

/// Репозиторий для работы со словарями
class DictionaryRepository extends BaseRepository {
  static const String _cachePrefix = 'dict:';
  
  DictionaryRepository({
    required super.databaseManager,
    required super.cacheManager,
  });
  
  @override
  String get tableName => 'words';
  
  @override
  DatabaseType get databaseType => DatabaseType.dictionaries;
  
  @override
  String generateCacheKey(Map<String, dynamic> params) {
    final sourceWord = params['sourceWord'] as String?;
    final languagePair = params['languagePair'] as String?;
    final searchType = params['searchType'] as String? ?? 'exact';
    
    if (sourceWord != null && languagePair != null) {
      return '$_cachePrefix$searchType:$languagePair:${sourceWord.toLowerCase()}';
    }
    
    // Для других типов запросов
    final queryType = params['queryType'] as String? ?? 'unknown';
    final hash = params.hashCode.toString();
    return '$_cachePrefix$queryType:$hash';
  }
  
  @override
  void clearCache() {
    // Очистить только ключи словаря
    final allKeys = cacheManager.getAllKeys();
    for (final key in allKeys) {
      if (key.startsWith(_cachePrefix)) {
        cacheManager.remove(key);
      }
    }
  }
  
  @override
  void validateData(Map<String, dynamic> data) {
    super.validateData(data);
    
    if (data['source_word'] == null || (data['source_word'] as String).trim().isEmpty) {
      throw ValidationException('Source word is required and cannot be empty');
    }
    
    if (data['target_word'] == null || (data['target_word'] as String).trim().isEmpty) {
      throw ValidationException('Target word is required and cannot be empty');
    }
    
    if (data['language_pair'] == null || (data['language_pair'] as String).trim().isEmpty) {
      throw ValidationException('Language pair is required and cannot be empty');
    }
    
    // Валидация формата языковой пары
    final languagePair = data['language_pair'] as String;
    if (!RegExp(r'^[a-z]{2}-[a-z]{2}$').hasMatch(languagePair)) {
      throw ValidationException('Language pair must be in format "xx-xx" (e.g., "en-ru")');
    }
  }
  
  @override
  Map<String, dynamic> transformForDatabase(Map<String, dynamic> data) {
    final transformed = Map<String, dynamic>.from(data);
    
    // Нормализация текста
    if (transformed['source_word'] != null) {
      transformed['source_word'] = (transformed['source_word'] as String).trim().toLowerCase();
    }
    
    if (transformed['target_word'] != null) {
      transformed['target_word'] = (transformed['target_word'] as String).trim();
    }
    
    if (transformed['language_pair'] != null) {
      transformed['language_pair'] = (transformed['language_pair'] as String).toLowerCase();
    }
    
    // Добавить временные метки
    final now = DateTime.now().millisecondsSinceEpoch;
    transformed['updated_at'] = now;
    if (transformed['created_at'] == null) {
      transformed['created_at'] = now;
    }
    
    return transformed;
  }
  
  /// Получить перевод слова
  Future<DictionaryEntry?> getTranslation(
    String sourceWord,
    String languagePair, {
    bool useCache = true,
  }) async {
    final normalizedWord = sourceWord.trim().toLowerCase();
    final normalizedLangPair = languagePair.toLowerCase();
    
    // Попробовать получить из кэша
    if (useCache) {
      final cacheKey = generateCacheKey({
        'sourceWord': normalizedWord,
        'languagePair': normalizedLangPair,
        'searchType': 'exact',
      });
      
      final cached = getCached<DictionaryEntry>(cacheKey);
      if (cached != null) {
        return cached;
      }
    }
    
    // Поиск в базе данных
    final results = await executeQuery((connection) async {
      return await connection.query(
        'SELECT * FROM $tableName WHERE source_word = ? AND language_pair = ? ORDER BY frequency DESC LIMIT 1',
        [normalizedWord, normalizedLangPair],
      );
    });
    
    if (results.isEmpty) {
      return null;
    }
    
    final entry = DictionaryEntry.fromMap(results.first);
    
    // Сохранить в кэш
    if (useCache) {
      final cacheKey = generateCacheKey({
        'sourceWord': normalizedWord,
        'languagePair': normalizedLangPair,
        'searchType': 'exact',
      });
      setCached(cacheKey, entry);
    }
    
    return entry;
  }
  
  /// Добавить новый перевод или обновить существующий
  Future<DictionaryEntry> addTranslation(
    String sourceWord,
    String targetWord,
    String languagePair, {
    String? partOfSpeech,
    String? definition,
    int frequency = 1,
  }) async {
    final data = {
      'source_word': sourceWord,
      'target_word': targetWord,
      'language_pair': languagePair,
      'part_of_speech': partOfSpeech,
      'definition': definition,
      'frequency': frequency,
    };
    
    validateData(data);
    final transformedData = transformForDatabase(data);
    
    return executeTransaction((connection) async {
      // Проверить, существует ли уже такая запись
      final existing = await connection.query(
        'SELECT * FROM $tableName WHERE source_word = ? AND language_pair = ?',
        [transformedData['source_word'], transformedData['language_pair']],
      );
      
      DictionaryEntry result;
      
      if (existing.isNotEmpty) {
        // Обновить существующую запись
        final existingId = existing.first['id'] as int;
        final existingFrequency = existing.first['frequency'] as int;
        
        // Увеличить частотность
        transformedData['frequency'] = existingFrequency + frequency;
        transformedData['id'] = existingId;
        
        await connection.execute(
          'UPDATE $tableName SET target_word = ?, part_of_speech = ?, definition = ?, frequency = ?, updated_at = ? WHERE id = ?',
          [
            transformedData['target_word'],
            transformedData['part_of_speech'],
            transformedData['definition'],
            transformedData['frequency'],
            transformedData['updated_at'],
            existingId,
          ],
        );
        
        transformedData['created_at'] = existing.first['created_at'];
        result = DictionaryEntry.fromMap(transformedData);
      } else {
        // Вставить новую запись
        final insertId = await connection.execute(
          'INSERT INTO $tableName (source_word, target_word, language_pair, part_of_speech, definition, frequency, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [
            transformedData['source_word'],
            transformedData['target_word'],
            transformedData['language_pair'],
            transformedData['part_of_speech'],
            transformedData['definition'],
            transformedData['frequency'],
            transformedData['created_at'],
            transformedData['updated_at'],
          ],
        );
        
        transformedData['id'] = insertId;
        result = DictionaryEntry.fromMap(transformedData);
      }
      
      // Обновить кэш
      final cacheKey = generateCacheKey({
        'sourceWord': transformedData['source_word'],
        'languagePair': transformedData['language_pair'],
        'searchType': 'exact',
      });
      setCached(cacheKey, result);
      
      return result;
    });
  }
  
  /// Поиск переводов по частичному совпадению
  Future<List<DictionaryEntry>> searchByWord(
    String searchTerm,
    String languagePair, {
    int limit = 20,
    bool useCache = true,
  }) async {
    final normalizedTerm = searchTerm.trim().toLowerCase();
    final normalizedLangPair = languagePair.toLowerCase();
    
    // Попробовать получить из кэша
    if (useCache) {
      final cacheKey = generateCacheKey({
        'sourceWord': normalizedTerm,
        'languagePair': normalizedLangPair,
        'searchType': 'search',
        'limit': limit,
      });
      
      final cached = getCached<List<DictionaryEntry>>(cacheKey);
      if (cached != null) {
        return cached;
      }
    }
    
    // Поиск в базе данных
    final results = await executeQuery((connection) async {
      return await connection.query(
        'SELECT * FROM $tableName WHERE (source_word LIKE ? OR target_word LIKE ?) AND language_pair = ? ORDER BY frequency DESC, source_word ASC LIMIT ?',
        ['%$normalizedTerm%', '%$normalizedTerm%', normalizedLangPair, limit],
      );
    });
    
    final entries = results.map((row) => DictionaryEntry.fromMap(row)).toList();
    
    // Сохранить в кэш
    if (useCache) {
      final cacheKey = generateCacheKey({
        'sourceWord': normalizedTerm,
        'languagePair': normalizedLangPair,
        'searchType': 'search',
        'limit': limit,
      });
      setCached(cacheKey, entries);
    }
    
    return entries;
  }
  
  /// Получить все переводы для языковой пары
  Future<List<DictionaryEntry>> getAllTranslations(
    String languagePair, {
    int? limit,
    int? offset,
    String orderBy = 'frequency DESC',
  }) async {
    final results = await getAll(
      conditions: {'language_pair': languagePair.toLowerCase()},
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    
    return results.map((row) => DictionaryEntry.fromMap(row)).toList();
  }
  
  /// Удалить перевод
  Future<bool> deleteTranslation(int id) async {
    final deleted = await delete({'id': id});
    return deleted > 0;
  }
  
  /// Получить статистику по языковой паре
  Future<Map<String, dynamic>> getLanguagePairStats(String languagePair) async {
    return executeQuery((connection) async {
      final results = await connection.query(
        'SELECT COUNT(*) as total_words, AVG(frequency) as avg_frequency, MAX(frequency) as max_frequency FROM $tableName WHERE language_pair = ?',
        [languagePair.toLowerCase()],
      );
      
      if (results.isEmpty) {
        return {
          'language_pair': languagePair,
          'total_words': 0,
          'avg_frequency': 0.0,
          'max_frequency': 0,
        };
      }
      
      final row = results.first;
      return {
        'language_pair': languagePair,
        'total_words': row['total_words'] as int,
        'avg_frequency': (row['avg_frequency'] as num?)?.toDouble() ?? 0.0,
        'max_frequency': row['max_frequency'] as int? ?? 0,
      };
    });
  }
  
  /// Получить топ наиболее частых слов
  Future<List<DictionaryEntry>> getTopWords(
    String languagePair, {
    int limit = 100,
  }) async {
    final results = await getAll(
      conditions: {'language_pair': languagePair.toLowerCase()},
      orderBy: 'frequency DESC',
      limit: limit,
    );
    
    return results.map((row) => DictionaryEntry.fromMap(row)).toList();
  }
}