import 'base_repository.dart';
import '../utils/exceptions.dart';
import 'database_types.dart';

/// Модель фразы для перевода
class PhraseEntry {
  final int? id;
  final String sourcePhrase;
  final String targetPhrase;
  final String languagePair; // например: "en-ru"
  final String? category; // категория: greetings, business, travel
  final String? context; // контекст использования
  final int frequency;
  final int confidence; // уверенность в переводе (0-100)
  final DateTime createdAt;
  final DateTime updatedAt;
  
  const PhraseEntry({
    this.id,
    required this.sourcePhrase,
    required this.targetPhrase,
    required this.languagePair,
    this.category,
    this.context,
    this.frequency = 1,
    this.confidence = 95,
    required this.createdAt,
    required this.updatedAt,
  });
  
  /// Создание из Map (из базы данных)
  factory PhraseEntry.fromMap(Map<String, dynamic> map) {
    return PhraseEntry(
      id: map['id'] as int?,
      sourcePhrase: map['source_phrase'] as String,
      targetPhrase: map['target_phrase'] as String,
      languagePair: map['language_pair'] as String,
      category: map['category'] as String?,
      context: map['context'] as String?,
      frequency: map['frequency'] as int? ?? 1,
      confidence: map['confidence'] as int? ?? 95,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
  
  /// Конвертация в Map (для базы данных)
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'source_phrase': sourcePhrase,
      'target_phrase': targetPhrase,
      'language_pair': languagePair,
      'category': category,
      'context': context,
      'frequency': frequency,
      'confidence': confidence,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
  
  /// Создание копии с изменениями
  PhraseEntry copyWith({
    int? id,
    String? sourcePhrase,
    String? targetPhrase,
    String? languagePair,
    String? category,
    String? context,
    int? frequency,
    int? confidence,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PhraseEntry(
      id: id ?? this.id,
      sourcePhrase: sourcePhrase ?? this.sourcePhrase,
      targetPhrase: targetPhrase ?? this.targetPhrase,
      languagePair: languagePair ?? this.languagePair,
      category: category ?? this.category,
      context: context ?? this.context,
      frequency: frequency ?? this.frequency,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  /// Получить ключевые слова из фразы
  List<String> get keywords {
    return sourcePhrase
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(' ')
        .where((word) => word.length > 2)
        .toList();
  }
  
  /// Проверить, содержит ли фраза поисковый терм
  bool containsSearchTerm(String searchTerm) {
    final normalizedSource = sourcePhrase.toLowerCase();
    final normalizedTarget = targetPhrase.toLowerCase();
    final normalizedTerm = searchTerm.toLowerCase();
    
    return normalizedSource.contains(normalizedTerm) ||
           normalizedTarget.contains(normalizedTerm) ||
           keywords.any((keyword) => keyword.contains(normalizedTerm));
  }
  
  @override
  String toString() {
    return 'PhraseEntry(sourcePhrase: "$sourcePhrase", targetPhrase: "$targetPhrase", languagePair: $languagePair)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PhraseEntry &&
        other.sourcePhrase == sourcePhrase &&
        other.targetPhrase == targetPhrase &&
        other.languagePair == languagePair;
  }
  
  @override
  int get hashCode => Object.hash(sourcePhrase, targetPhrase, languagePair);
}

/// Репозиторий для работы с фразами
class PhraseRepository extends BaseRepository {
  static const String _cachePrefix = 'phrase:';
  
  PhraseRepository({
    required super.databaseManager,
    required super.cacheManager,
  });
  
  @override
  String get tableName => 'phrases';
  
  @override
  DatabaseType get databaseType => DatabaseType.phrases;
  
  @override
  String generateCacheKey(Map<String, dynamic> params) {
    final sourcePhrase = params['sourcePhrase'] as String?;
    final languagePair = params['languagePair'] as String?;
    final searchType = params['searchType'] as String? ?? 'exact';
    
    if (sourcePhrase != null && languagePair != null) {
      // Нормализовать фразу для ключа
      final normalizedPhrase = sourcePhrase
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), '_');
      return '$_cachePrefix$searchType:$languagePair:$normalizedPhrase';
    }
    
    // Для других типов запросов
    final queryType = params['queryType'] as String? ?? 'unknown';
    final hash = params.hashCode.toString();
    return '$_cachePrefix$queryType:$hash';
  }
  
  @override
  void clearCache() {
    // Очистить только ключи фраз
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
    
    if (data['source_phrase'] == null || (data['source_phrase'] as String).trim().isEmpty) {
      throw ValidationException('Source phrase is required and cannot be empty');
    }
    
    if (data['target_phrase'] == null || (data['target_phrase'] as String).trim().isEmpty) {
      throw ValidationException('Target phrase is required and cannot be empty');
    }
    
    if (data['language_pair'] == null || (data['language_pair'] as String).trim().isEmpty) {
      throw ValidationException('Language pair is required and cannot be empty');
    }
    
    // Валидация формата языковой пары
    final languagePair = data['language_pair'] as String;
    if (!RegExp(r'^[a-z]{2}-[a-z]{2}$').hasMatch(languagePair)) {
      throw ValidationException('Language pair must be in format "xx-xx" (e.g., "en-ru")');
    }
    
    // Валидация confidence
    if (data['confidence'] != null) {
      final confidence = data['confidence'] as int;
      if (confidence < 0 || confidence > 100) {
        throw ValidationException('Confidence must be between 0 and 100');
      }
    }
    
    // Проверить длину фраз
    final sourcePhrase = data['source_phrase'] as String;
    final targetPhrase = data['target_phrase'] as String;
    if (sourcePhrase.length < 3) {
      throw ValidationException('Source phrase must be at least 3 characters long');
    }
    if (targetPhrase.length < 3) {
      throw ValidationException('Target phrase must be at least 3 characters long');
    }
  }
  
  @override
  Map<String, dynamic> transformForDatabase(Map<String, dynamic> data) {
    final transformed = Map<String, dynamic>.from(data);
    
    // Нормализация фраз
    if (transformed['source_phrase'] != null) {
      transformed['source_phrase'] = (transformed['source_phrase'] as String)
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' '); // объединить множественные пробелы
    }
    
    if (transformed['target_phrase'] != null) {
      transformed['target_phrase'] = (transformed['target_phrase'] as String)
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ');
    }
    
    if (transformed['language_pair'] != null) {
      transformed['language_pair'] = (transformed['language_pair'] as String).toLowerCase();
    }
    
    if (transformed['category'] != null) {
      transformed['category'] = (transformed['category'] as String).toLowerCase().trim();
    }
    
    // Установить значения по умолчанию
    transformed['confidence'] ??= 95;
    transformed['frequency'] ??= 1;
    
    // Добавить временные метки
    final now = DateTime.now().millisecondsSinceEpoch;
    transformed['updated_at'] = now;
    if (transformed['created_at'] == null) {
      transformed['created_at'] = now;
    }
    
    return transformed;
  }
  
  /// Получить точный перевод фразы
  Future<PhraseEntry?> getPhraseTranslation(
    String sourcePhrase,
    String languagePair, {
    bool useCache = true,
  }) async {
    final normalizedPhrase = sourcePhrase.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final normalizedLangPair = languagePair.toLowerCase();
    
    // Попробовать получить из кэша
    if (useCache) {
      final cacheKey = generateCacheKey({
        'sourcePhrase': normalizedPhrase,
        'languagePair': normalizedLangPair,
        'searchType': 'exact',
      });
      
      final cached = getCached<PhraseEntry>(cacheKey);
      if (cached != null) {
        return cached;
      }
    }
    
    // Поиск в базе данных
    final results = await executeQuery((connection) async {
      return await connection.query(
        'SELECT * FROM $tableName WHERE source_phrase = ? AND language_pair = ? ORDER BY confidence DESC, frequency DESC LIMIT 1',
        [normalizedPhrase, normalizedLangPair],
      );
    });
    
    if (results.isEmpty) {
      return null;
    }
    
    final entry = PhraseEntry.fromMap(results.first);
    
    // Сохранить в кэш
    if (useCache) {
      final cacheKey = generateCacheKey({
        'sourcePhrase': normalizedPhrase,
        'languagePair': normalizedLangPair,
        'searchType': 'exact',
      });
      setCached(cacheKey, entry);
    }
    
    return entry;
  }
  
  /// Добавить новую фразу или обновить существующую
  Future<PhraseEntry> addPhrase(
    String sourcePhrase,
    String targetPhrase,
    String languagePair, {
    String? category,
    String? context,
    int frequency = 1,
    int confidence = 95,
  }) async {
    final data = {
      'source_phrase': sourcePhrase,
      'target_phrase': targetPhrase,
      'language_pair': languagePair,
      'category': category,
      'context': context,
      'frequency': frequency,
      'confidence': confidence,
    };
    
    validateData(data);
    final transformedData = transformForDatabase(data);
    
    return executeTransaction((connection) async {
      // Проверить, существует ли уже такая фраза
      final existing = await connection.query(
        'SELECT * FROM $tableName WHERE source_phrase = ? AND language_pair = ?',
        [transformedData['source_phrase'], transformedData['language_pair']],
      );
      
      PhraseEntry result;
      
      if (existing.isNotEmpty) {
        // Обновить существующую фразу
        final existingId = existing.first['id'] as int;
        final existingFrequency = existing.first['frequency'] as int;
        final existingConfidence = existing.first['confidence'] as int;
        
        // Увеличить частотность и обновить confidence
        transformedData['frequency'] = existingFrequency + frequency;
        transformedData['confidence'] = (existingConfidence + confidence) ~/  2; // среднее значение
        transformedData['id'] = existingId;
        
        await connection.execute(
          'UPDATE $tableName SET target_phrase = ?, category = ?, context = ?, frequency = ?, confidence = ?, updated_at = ? WHERE id = ?',
          [
            transformedData['target_phrase'],
            transformedData['category'],
            transformedData['context'],
            transformedData['frequency'],
            transformedData['confidence'],
            transformedData['updated_at'],
            existingId,
          ],
        );
        
        transformedData['created_at'] = existing.first['created_at'];
        result = PhraseEntry.fromMap(transformedData);
      } else {
        // Вставить новую фразу
        final insertId = await connection.execute(
          'INSERT INTO $tableName (source_phrase, target_phrase, language_pair, category, context, frequency, confidence, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            transformedData['source_phrase'],
            transformedData['target_phrase'],
            transformedData['language_pair'],
            transformedData['category'],
            transformedData['context'],
            transformedData['frequency'],
            transformedData['confidence'],
            transformedData['created_at'],
            transformedData['updated_at'],
          ],
        );
        
        transformedData['id'] = insertId;
        result = PhraseEntry.fromMap(transformedData);
      }
      
      // Обновить кэш
      final cacheKey = generateCacheKey({
        'sourcePhrase': transformedData['source_phrase'],
        'languagePair': transformedData['language_pair'],
        'searchType': 'exact',
      });
      setCached(cacheKey, result);
      
      return result;
    });
  }
  
  /// Поиск фраз по частичному совпадению
  Future<List<PhraseEntry>> searchByPhrase(
    String searchTerm,
    String languagePair, {
    String? category,
    int limit = 20,
    bool useCache = true,
  }) async {
    final normalizedTerm = searchTerm.trim().toLowerCase();
    final normalizedLangPair = languagePair.toLowerCase();
    
    // Попробовать получить из кэша
    if (useCache) {
      final cacheKey = generateCacheKey({
        'sourcePhrase': normalizedTerm,
        'languagePair': normalizedLangPair,
        'searchType': 'search',
        'category': category,
        'limit': limit,
      });
      
      final cached = getCached<List<PhraseEntry>>(cacheKey);
      if (cached != null) {
        return cached;
      }
    }
    
    // Построить запрос
    String query = 'SELECT * FROM $tableName WHERE (source_phrase LIKE ? OR target_phrase LIKE ?) AND language_pair = ?';
    List<dynamic> params = ['%$normalizedTerm%', '%$normalizedTerm%', normalizedLangPair];
    
    if (category != null) {
      query += ' AND category = ?';
      params.add(category.toLowerCase());
    }
    
    query += ' ORDER BY confidence DESC, frequency DESC, LENGTH(source_phrase) ASC LIMIT ?';
    params.add(limit);
    
    // Поиск в базе данных
    final results = await executeQuery((connection) async {
      return await connection.query(query, params);
    });
    
    final entries = results.map((row) => PhraseEntry.fromMap(row)).toList();
    
    // Сохранить в кэш
    if (useCache) {
      final cacheKey = generateCacheKey({
        'sourcePhrase': normalizedTerm,
        'languagePair': normalizedLangPair,
        'searchType': 'search',
        'category': category,
        'limit': limit,
      });
      setCached(cacheKey, entries);
    }
    
    return entries;
  }
  
  /// Получить все фразы для языковой пары
  Future<List<PhraseEntry>> getAllPhrases(
    String languagePair, {
    String? category,
    int? limit,
    int? offset,
    String orderBy = 'confidence DESC, frequency DESC',
  }) async {
    Map<String, dynamic> conditions = {'language_pair': languagePair.toLowerCase()};
    
    if (category != null) {
      conditions['category'] = category.toLowerCase();
    }
    
    final results = await getAll(
      conditions: conditions,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    
    return results.map((row) => PhraseEntry.fromMap(row)).toList();
  }
  
  /// Получить фразы по категории
  Future<List<PhraseEntry>> getPhrasesByCategory(
    String category,
    String languagePair, {
    int limit = 50,
  }) async {
    return await getAllPhrases(
      languagePair,
      category: category,
      limit: limit,
    );
  }
  
  /// Получить список всех категорий
  Future<List<String>> getCategories(String languagePair) async {
    return executeQuery((connection) async {
      final results = await connection.query(
        'SELECT DISTINCT category FROM $tableName WHERE language_pair = ? AND category IS NOT NULL ORDER BY category',
        [languagePair.toLowerCase()],
      );
      
      return results
          .map((row) => row['category'] as String)
          .where((category) => category.isNotEmpty)
          .toList();
    });
  }
  
  /// Удалить фразу
  Future<bool> deletePhrase(int id) async {
    final deleted = await delete({'id': id});
    return deleted > 0;
  }
  
  /// Получить статистику по языковой паре
  Future<Map<String, dynamic>> getLanguagePairStats(String languagePair) async {
    return executeQuery((connection) async {
      final results = await connection.query(
        'SELECT COUNT(*) as total_phrases, AVG(confidence) as avg_confidence, AVG(frequency) as avg_frequency, COUNT(DISTINCT category) as categories_count FROM $tableName WHERE language_pair = ?',
        [languagePair.toLowerCase()],
      );
      
      if (results.isEmpty) {
        return {
          'language_pair': languagePair,
          'total_phrases': 0,
          'avg_confidence': 0.0,
          'avg_frequency': 0.0,
          'categories_count': 0,
        };
      }
      
      final row = results.first;
      return {
        'language_pair': languagePair,
        'total_phrases': row['total_phrases'] as int,
        'avg_confidence': (row['avg_confidence'] as num?)?.toDouble() ?? 0.0,
        'avg_frequency': (row['avg_frequency'] as num?)?.toDouble() ?? 0.0,
        'categories_count': row['categories_count'] as int? ?? 0,
      };
    });
  }
  
  /// Получить топ наиболее уверенных фраз
  Future<List<PhraseEntry>> getTopConfidentPhrases(
    String languagePair, {
    int limit = 100,
    int minConfidence = 90,
  }) async {
    return executeQuery((connection) async {
      final results = await connection.query(
        'SELECT * FROM $tableName WHERE language_pair = ? AND confidence >= ? ORDER BY confidence DESC, frequency DESC LIMIT ?',
        [languagePair.toLowerCase(), minConfidence, limit],
      );
      
      return results.map((row) => PhraseEntry.fromMap(row)).toList();
    });
  }
  
  /// Поиск по ключевым словам
  Future<List<PhraseEntry>> searchByKeywords(
    List<String> keywords,
    String languagePair, {
    int limit = 20,
  }) async {
    if (keywords.isEmpty) return [];
    
    final normalizedKeywords = keywords.map((k) => k.toLowerCase().trim()).toList();
    final placeholders = normalizedKeywords.map((_) => '?').join(',');
    
    return executeQuery((connection) async {
      final results = await connection.query(
        'SELECT * FROM $tableName WHERE language_pair = ? AND (source_phrase LIKE ANY (VALUES $placeholders) OR target_phrase LIKE ANY (VALUES $placeholders)) ORDER BY confidence DESC, frequency DESC LIMIT ?',
        [languagePair.toLowerCase(), ...normalizedKeywords.map((k) => '%$k%'), ...normalizedKeywords.map((k) => '%$k%'), limit],
      );
      
      return results.map((row) => PhraseEntry.fromMap(row)).toList();
    });
  }
}