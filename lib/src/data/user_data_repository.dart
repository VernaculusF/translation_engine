
import 'dart:convert';
import 'base_repository.dart';
import '../models/translation_result.dart';
import 'database_types.dart';

/// Модель истории переводов пользователя
class TranslationHistoryEntry {
  final int? id;
  final String originalText;
  final String translatedText;
  final String languagePair;
  final double confidence;
  final int processingTimeMs;
  final DateTime timestamp;
  final String? sessionId;
  final Map<String, dynamic>? metadata;
  
  const TranslationHistoryEntry({
    this.id,
    required this.originalText,
    required this.translatedText,
    required this.languagePair,
    required this.confidence,
    required this.processingTimeMs,
    required this.timestamp,
    this.sessionId,
    this.metadata,
  });
  
  /// Создание из TranslationResult
  factory TranslationHistoryEntry.fromTranslationResult(
    TranslationResult result, {
    String? sessionId,
  }) {
    return TranslationHistoryEntry(
      originalText: result.originalText,
      translatedText: result.translatedText,
      languagePair: result.languagePair,
      confidence: result.confidence,
      processingTimeMs: result.processingTimeMs,
      timestamp: result.timestamp,
      sessionId: sessionId,
      metadata: {
        'has_error': result.hasError,
        'layers_processed': result.layersProcessed,
        'quality_score': result.qualityScore,
        if (result.alternatives.isNotEmpty) 'alternatives_count': result.alternatives.length,
      },
    );
  }
  
  /// Создание из Map (из базы данных)
  factory TranslationHistoryEntry.fromMap(Map<String, dynamic> map) {
    return TranslationHistoryEntry(
      id: map['id'] as int?,
      originalText: map['original_text'] as String,
      translatedText: map['translated_text'] as String,
      languagePair: map['language_pair'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      processingTimeMs: map['processing_time_ms'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      sessionId: map['session_id'] as String?,
      metadata: _parseMetadata(map['metadata']),
    );
  }
  
  /// Конвертация в Map (для базы данных)
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'original_text': originalText,
      'translated_text': translatedText,
      'language_pair': languagePair,
      'confidence': confidence,
      'processing_time_ms': processingTimeMs,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'session_id': sessionId,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
    };
  }
  
  /// Парсинг metadata из различных форматов
  static Map<String, dynamic>? _parseMetadata(dynamic metadata) {
    if (metadata == null) return null;
    
    if (metadata is Map<String, dynamic>) {
      return metadata;
    }
    
    if (metadata is String) {
      try {
        final decoded = jsonDecode(metadata);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (e) {
        // Если не удалось декодировать JSON, возвращаем null
        return null;
      }
    }
    
    return null;
  }
  
  @override
  String toString() {
    return 'TranslationHistoryEntry(originalText: "$originalText", translatedText: "$translatedText", languagePair: $languagePair)';
  }
}

/// Модель пользовательских настроек
class UserSettings {
  final int? id;
  final String key;
  final dynamic value;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  const UserSettings({
    this.id,
    required this.key,
    required this.value,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });
  
  /// Создание из Map (из базы данных)
  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      id: map['id'] as int?,
      key: map['setting_key'] as String,
      value: map['setting_value'], // может быть любой тип
      description: map['description'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
  
  /// Конвертация в Map (для базы данных)
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'setting_key': key,
      'setting_value': value,
      'description': description,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
  
  /// Создание копии с изменениями
  UserSettings copyWith({
    int? id,
    String? key,
    dynamic value,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserSettings(
      id: id ?? this.id,
      key: key ?? this.key,
      value: value ?? this.value,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  @override
  String toString() {
    return 'UserSettings(key: $key, value: $value)';
  }
}

/// Модель пользовательских правок переводов
class UserTranslationEdit {
  final int? id;
  final String originalText;
  final String originalTranslation;
  final String userTranslation;
  final String languagePair;
  final String? reason; // причина правки
  final bool isApproved;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  const UserTranslationEdit({
    this.id,
    required this.originalText,
    required this.originalTranslation,
    required this.userTranslation,
    required this.languagePair,
    this.reason,
    this.isApproved = false,
    required this.createdAt,
    required this.updatedAt,
  });
  
  /// Создание из Map (из базы данных)
  factory UserTranslationEdit.fromMap(Map<String, dynamic> map) {
    return UserTranslationEdit(
      id: map['id'] as int?,
      originalText: map['original_text'] as String,
      originalTranslation: map['original_translation'] as String,
      userTranslation: map['user_translation'] as String,
      languagePair: map['language_pair'] as String,
      reason: map['reason'] as String?,
      isApproved: (map['is_approved'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
  
  /// Конвертация в Map (для базы данных)
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'original_text': originalText,
      'original_translation': originalTranslation,
      'user_translation': userTranslation,
      'language_pair': languagePair,
      'reason': reason,
      'is_approved': isApproved ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
  
  /// Создание копии с изменениями
  UserTranslationEdit copyWith({
    int? id,
    String? originalText,
    String? originalTranslation,
    String? userTranslation,
    String? languagePair,
    String? reason,
    bool? isApproved,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserTranslationEdit(
      id: id ?? this.id,
      originalText: originalText ?? this.originalText,
      originalTranslation: originalTranslation ?? this.originalTranslation,
      userTranslation: userTranslation ?? this.userTranslation,
      languagePair: languagePair ?? this.languagePair,
      reason: reason ?? this.reason,
      isApproved: isApproved ?? this.isApproved,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  @override
  String toString() {
    return 'UserTranslationEdit(originalText: "$originalText", userTranslation: "$userTranslation", languagePair: $languagePair)';
  }
}

/// Репозиторий для пользовательских данных
class UserDataRepository extends BaseRepository {
  static const String _cachePrefix = 'user_data:';
  static const String _historyTableName = 'translation_history';
  static const String _settingsTableName = 'user_settings';
  static const String _editsTableName = 'user_translation_edits';
  
  UserDataRepository({
    required super.databaseManager,
    required super.cacheManager,
  });
  
  @override
  String get tableName => _historyTableName; // основная таблица по умолчанию
  
  @override
  DatabaseType get databaseType => DatabaseType.userData;
  
  @override
  String generateCacheKey(Map<String, dynamic> params) {
    final type = params['type'] as String? ?? 'history';
    final identifier = params['identifier'] as String? ?? 'default';
    final hash = params.hashCode.toString();
    
    return '$_cachePrefix$type:$identifier:$hash';
  }
  
  @override
  void clearCache() {
    // Очистить только ключи пользовательских данных
    final allKeys = cacheManager.getAllKeys();
    for (final key in allKeys) {
      if (key.startsWith(_cachePrefix)) {
        cacheManager.remove(key);
      }
    }
  }
  
  // === ИСТОРИЯ ПЕРЕВОДОВ ===
  
  /// Добавить запись в историю переводов
  Future<TranslationHistoryEntry> addToHistory(
    TranslationResult translationResult, {
    String? sessionId,
  }) async {
    final entry = TranslationHistoryEntry.fromTranslationResult(
      translationResult,
      sessionId: sessionId,
    );
    
    return executeTransaction((connection) async {
      final data = entry.toMap();
      
      final insertId = await connection.execute(
        'INSERT INTO $_historyTableName (original_text, translated_text, language_pair, confidence, processing_time_ms, timestamp, session_id, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          data['original_text'],
          data['translated_text'],
          data['language_pair'],
          data['confidence'],
          data['processing_time_ms'],
          data['timestamp'],
          data['session_id'],
          data['metadata']?.toString(),
        ],
      );
      
      return TranslationHistoryEntry.fromMap({
        ...data,
        'id': insertId,
      });
    });
  }
  
  /// Получить историю переводов
  Future<List<TranslationHistoryEntry>> getTranslationHistory({
    String? languagePair,
    String? sessionId,
    DateTime? fromDate,
    DateTime? toDate,
    int? limit = 50,
    int? offset = 0,
  }) async {
    final cacheKey = generateCacheKey({
      'type': 'history',
      'identifier': 'list',
      'languagePair': languagePair,
      'sessionId': sessionId,
      'fromDate': fromDate?.millisecondsSinceEpoch,
      'toDate': toDate?.millisecondsSinceEpoch,
      'limit': limit,
      'offset': offset,
    });
    
    // Попробовать получить из кэша
    final cached = getCached<List<TranslationHistoryEntry>>(cacheKey);
    if (cached != null) {
      return cached;
    }
    
    return executeQuery((connection) async {
      String query = 'SELECT * FROM $_historyTableName WHERE 1=1';
      List<dynamic> params = [];
      
      if (languagePair != null) {
        query += ' AND language_pair = ?';
        params.add(languagePair.toLowerCase());
      }
      
      if (sessionId != null) {
        query += ' AND session_id = ?';
        params.add(sessionId);
      }
      
      if (fromDate != null) {
        query += ' AND timestamp >= ?';
        params.add(fromDate.millisecondsSinceEpoch);
      }
      
      if (toDate != null) {
        query += ' AND timestamp <= ?';
        params.add(toDate.millisecondsSinceEpoch);
      }
      
      query += ' ORDER BY timestamp DESC';
      
      if (limit != null) {
        query += ' LIMIT $limit';
        if (offset != null && offset > 0) {
          query += ' OFFSET $offset';
        }
      }
      
      final results = await connection.query(query, params);
      final entries = results.map((row) => TranslationHistoryEntry.fromMap(row)).toList();
      
      // Сохранить в кэш
      setCached(cacheKey, entries);
      
      return entries;
    });
  }
  
  /// Получить статистику истории переводов
  Future<Map<String, dynamic>> getHistoryStats({
    String? languagePair,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return executeQuery((connection) async {
      String query = '''
        SELECT 
          COUNT(*) as total_translations,
          AVG(confidence) as avg_confidence,
          AVG(processing_time_ms) as avg_processing_time,
          COUNT(DISTINCT language_pair) as language_pairs_count,
          COUNT(DISTINCT session_id) as sessions_count
        FROM $_historyTableName 
        WHERE 1=1
      ''';
      
      List<dynamic> params = [];
      
      if (languagePair != null) {
        query += ' AND language_pair = ?';
        params.add(languagePair.toLowerCase());
      }
      
      if (fromDate != null) {
        query += ' AND timestamp >= ?';
        params.add(fromDate.millisecondsSinceEpoch);
      }
      
      if (toDate != null) {
        query += ' AND timestamp <= ?';
        params.add(toDate.millisecondsSinceEpoch);
      }
      
      final results = await connection.query(query, params);
      
      if (results.isEmpty) {
        return {
          'total_translations': 0,
          'avg_confidence': 0.0,
          'avg_processing_time': 0.0,
          'language_pairs_count': 0,
          'sessions_count': 0,
        };
      }
      
      final row = results.first;
      return {
        'total_translations': row['total_translations'] as int,
        'avg_confidence': (row['avg_confidence'] as num?)?.toDouble() ?? 0.0,
        'avg_processing_time': (row['avg_processing_time'] as num?)?.toDouble() ?? 0.0,
        'language_pairs_count': row['language_pairs_count'] as int? ?? 0,
        'sessions_count': row['sessions_count'] as int? ?? 0,
      };
    });
  }
  
  /// Очистить историю переводов старше указанной даты
  Future<int> clearHistoryOlderThan(DateTime date) async {
    return await delete({
      'timestamp': '< ${date.millisecondsSinceEpoch}',
    });
  }
  
  // === ПОЛЬЗОВАТЕЛЬСКИЕ НАСТРОЙКИ ===
  
  /// Получить настройку по ключу
  Future<UserSettings?> getSetting(String key) async {
    final cacheKey = generateCacheKey({
      'type': 'setting',
      'identifier': key,
    });
    
    // Попробовать получить из кэша
    final cached = getCached<UserSettings>(cacheKey);
    if (cached != null) {
      return cached;
    }
    
    return executeQuery((connection) async {
      final results = await connection.query(
        'SELECT * FROM $_settingsTableName WHERE setting_key = ?',
        [key],
      );
      
      if (results.isEmpty) {
        return null;
      }
      
      final setting = UserSettings.fromMap(results.first);
      
      // Сохранить в кэш
      setCached(cacheKey, setting);
      
      return setting;
    });
  }
  
  /// Установить настройку
  Future<UserSettings> setSetting(
    String key,
    dynamic value, {
    String? description,
  }) async {
    return executeTransaction((connection) async {
      final now = DateTime.now();
      final existing = await connection.query(
        'SELECT * FROM $_settingsTableName WHERE setting_key = ?',
        [key],
      );
      
      UserSettings result;
      
      if (existing.isNotEmpty) {
        // Обновить существующую настройку
        await connection.execute(
          'UPDATE $_settingsTableName SET setting_value = ?, description = ?, updated_at = ? WHERE setting_key = ?',
          [value, description, now.millisecondsSinceEpoch, key],
        );
        
        result = UserSettings(
          id: existing.first['id'] as int,
          key: key,
          value: value,
          description: description,
          createdAt: DateTime.fromMillisecondsSinceEpoch(existing.first['created_at'] as int),
          updatedAt: now,
        );
      } else {
        // Создать новую настройку
        final insertId = await connection.execute(
          'INSERT INTO $_settingsTableName (setting_key, setting_value, description, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
          [key, value, description, now.millisecondsSinceEpoch, now.millisecondsSinceEpoch],
        );
        
        result = UserSettings(
          id: insertId,
          key: key,
          value: value,
          description: description,
          createdAt: now,
          updatedAt: now,
        );
      }
      
      // Обновить кэш
      final cacheKey = generateCacheKey({
        'type': 'setting',
        'identifier': key,
      });
      setCached(cacheKey, result);
      
      return result;
    });
  }
  
  /// Получить все настройки
  Future<List<UserSettings>> getAllSettings() async {
    return executeQuery((connection) async {
      final results = await connection.query(
        'SELECT * FROM $_settingsTableName ORDER BY setting_key',
      );
      
      return results.map((row) => UserSettings.fromMap(row)).toList();
    });
  }
  
  /// Удалить настройку
  Future<bool> deleteSetting(String key) async {
    final result = await executeTransaction((connection) async {
      return await connection.execute(
        'DELETE FROM $_settingsTableName WHERE setting_key = ?',
        [key],
      );
    });
    
    if (result > 0) {
      // Удалить из кэша
      final cacheKey = generateCacheKey({
        'type': 'setting',
        'identifier': key,
      });
      removeCached(cacheKey);
      return true;
    }
    
    return false;
  }
  
  // === ПОЛЬЗОВАТЕЛЬСКИЕ ПРАВКИ ===
  
  /// Добавить пользовательскую правку перевода
  Future<UserTranslationEdit> addTranslationEdit(
    String originalText,
    String originalTranslation,
    String userTranslation,
    String languagePair, {
    String? reason,
  }) async {
    final now = DateTime.now();
    final edit = UserTranslationEdit(
      originalText: originalText,
      originalTranslation: originalTranslation,
      userTranslation: userTranslation,
      languagePair: languagePair.toLowerCase(),
      reason: reason,
      createdAt: now,
      updatedAt: now,
    );
    
    return executeTransaction((connection) async {
      final data = edit.toMap();
      
      final insertId = await connection.execute(
        'INSERT INTO $_editsTableName (original_text, original_translation, user_translation, language_pair, reason, is_approved, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          data['original_text'],
          data['original_translation'],
          data['user_translation'],
          data['language_pair'],
          data['reason'],
          data['is_approved'],
          data['created_at'],
          data['updated_at'],
        ],
      );
      
      return UserTranslationEdit.fromMap({
        ...data,
        'id': insertId,
      });
    });
  }
  
  /// Получить пользовательские правки
  Future<List<UserTranslationEdit>> getTranslationEdits({
    String? languagePair,
    bool? onlyApproved,
    int? limit = 50,
    int? offset = 0,
  }) async {
    return executeQuery((connection) async {
      String query = 'SELECT * FROM $_editsTableName WHERE 1=1';
      List<dynamic> params = [];
      
      if (languagePair != null) {
        query += ' AND language_pair = ?';
        params.add(languagePair.toLowerCase());
      }
      
      if (onlyApproved != null) {
        query += ' AND is_approved = ?';
        params.add(onlyApproved ? 1 : 0);
      }
      
      query += ' ORDER BY created_at DESC';
      
      if (limit != null) {
        query += ' LIMIT $limit';
        if (offset != null && offset > 0) {
          query += ' OFFSET $offset';
        }
      }
      
      final results = await connection.query(query, params);
      return results.map((row) => UserTranslationEdit.fromMap(row)).toList();
    });
  }
  
  /// Одобрить пользовательскую правку
  Future<bool> approveTranslationEdit(int editId) async {
    final result = await executeTransaction((connection) async {
      return await connection.execute(
        'UPDATE $_editsTableName SET is_approved = 1, updated_at = ? WHERE id = ?',
        [DateTime.now().millisecondsSinceEpoch, editId],
      );
    });
    
    return result > 0;
  }
  
  /// Поиск пользовательских правок по тексту
  Future<UserTranslationEdit?> findEditForText(
    String originalText,
    String languagePair,
  ) async {
    return executeQuery((connection) async {
      final results = await connection.query(
        'SELECT * FROM $_editsTableName WHERE original_text = ? AND language_pair = ? AND is_approved = 1 ORDER BY updated_at DESC LIMIT 1',
        [originalText.toLowerCase(), languagePair.toLowerCase()],
      );
      
      if (results.isEmpty) {
        return null;
      }
      
      return UserTranslationEdit.fromMap(results.first);
    });
  }
}