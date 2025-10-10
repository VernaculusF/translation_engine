
import 'dart:convert';
import '../models/translation_result.dart';
import '../utils/cache_manager.dart';
import '../storage/file_storage.dart';

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

/// Репозиторий для пользовательских данных (файловое хранилище JSON/JSONL)
class UserDataRepository {
  static const String _cachePrefix = 'user_data:';

  final CacheManager cacheManager;
  final FileStorageService storage;

  UserDataRepository({
    required String dataDirPath,
    required this.cacheManager,
  }) : storage = FileStorageService(rootDir: dataDirPath);

  String generateCacheKey(Map<String, dynamic> params) {
    final type = params['type'] as String? ?? 'history';
    final identifier = params['identifier'] as String? ?? 'default';
    final hash = params.hashCode.toString();
    return '$_cachePrefix$type:$identifier:$hash';
  }

  void clearCache() {
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
    // Определяем следующий id для истории (инкрементально)
    int maxId = 0;
    final file = storage.userHistoryFile();
    if (file.existsSync()) {
      for (final line in file.readAsLinesSync()) {
        if (line.trim().isEmpty) continue;
        try {
          final obj = jsonDecode(line) as Map<String, dynamic>;
          final id = obj['id'] as int?;
          if (id != null && id > maxId) maxId = id;
        } catch (_) {}
      }
    }

    final entry = TranslationHistoryEntry.fromTranslationResult(
      translationResult,
      sessionId: sessionId,
    );
    final data = entry.toMap();
    data['id'] = maxId + 1;

    await storage.ensureUserDir();
    await storage.appendJsonLine(file, data);
    return TranslationHistoryEntry.fromMap(data);
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

    final cached = cacheManager.get<List<TranslationHistoryEntry>>(cacheKey);
    if (cached != null) return cached;

    final file = storage.userHistoryFile();
    final entries = <TranslationHistoryEntry>[];
    await for (final obj in storage.readJsonLines(file)) {
      try {
        final e = TranslationHistoryEntry.fromMap(obj);
        if (languagePair != null && e.languagePair.toLowerCase() != languagePair.toLowerCase()) continue;
        if (sessionId != null && e.sessionId != sessionId) continue;
        if (fromDate != null && e.timestamp.isBefore(fromDate)) continue;
        if (toDate != null && e.timestamp.isAfter(toDate)) continue;
        entries.add(e);
      } catch (_) {
        // skip
      }
    }
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    var list = entries;
    if (offset != null && offset > 0 && offset < list.length) list = list.sublist(offset);
    if (limit != null && limit < list.length) list = list.sublist(0, limit);

    cacheManager.set(cacheKey, list);
    return list;
  }
  
  /// Получить статистику истории переводов
  Future<Map<String, dynamic>> getHistoryStats({
    String? languagePair,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final file = storage.userHistoryFile();
    int total = 0;
    double confSum = 0;
    double timeSum = 0;
    final langSet = <String>{};
    final sessionSet = <String>{};

    await for (final obj in storage.readJsonLines(file)) {
      try {
        final e = TranslationHistoryEntry.fromMap(obj);
        if (languagePair != null && e.languagePair.toLowerCase() != languagePair.toLowerCase()) continue;
        if (fromDate != null && e.timestamp.isBefore(fromDate)) continue;
        if (toDate != null && e.timestamp.isAfter(toDate)) continue;
        total++;
        confSum += e.confidence;
        timeSum += e.processingTimeMs;
        langSet.add(e.languagePair.toLowerCase());
        if (e.sessionId != null) sessionSet.add(e.sessionId!);
      } catch (_) {}
    }

    if (total == 0) {
      return {
        'total_translations': 0,
        'avg_confidence': 0.0,
        'avg_processing_time': 0.0,
        'language_pairs_count': 0,
        'sessions_count': 0,
      };
    }

    return {
      'total_translations': total,
      'avg_confidence': confSum / total,
      'avg_processing_time': timeSum / total,
      'language_pairs_count': langSet.length,
      'sessions_count': sessionSet.length,
    };
  }
  
  /// Очистить историю переводов старше указанной даты
  Future<int> clearHistoryOlderThan(DateTime date) async {
    final file = storage.userHistoryFile();
    if (!file.existsSync()) return 0;
    final keep = <Map<String, dynamic>>[];
    int removed = 0;
    for (final line in file.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      try {
        final obj = jsonDecode(line) as Map<String, dynamic>;
        final ts = DateTime.fromMillisecondsSinceEpoch(obj['timestamp'] as int);
        if (ts.isBefore(date)) {
          removed++;
        } else {
          keep.add(obj);
        }
      } catch (_) {}
    }
    await storage.rewriteJsonLines(file, keep);
    return removed;
  }
  
  // === ПОЛЬЗОВАТЕЛЬСКИЕ НАСТРОЙКИ ===
  
  /// Получить настройку по ключу
  Future<UserSettings?> getSetting(String key) async {
    final cacheKey = generateCacheKey({'type': 'setting', 'identifier': key});
    final cached = cacheManager.get<UserSettings>(cacheKey);
    if (cached != null) return cached;

    final file = storage.userSettingsFile();
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final obj = json[key];
      if (obj == null) return null;
      final setting = UserSettings.fromMap(obj as Map<String, dynamic>);
      cacheManager.set(cacheKey, setting);
      return setting;
    } catch (_) {
      return null;
    }
  }
  
  /// Установить настройку
  Future<UserSettings> setSetting(
    String key,
    dynamic value, {
    String? description,
  }) async {
    final file = storage.userSettingsFile();
    final now = DateTime.now();
    Map<String, dynamic> jsonMap = {};
    if (file.existsSync()) {
      try {
        jsonMap = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {
        jsonMap = {};
      }
    }
    final existing = jsonMap[key] as Map<String, dynamic>?;
    late UserSettings result;
    if (existing != null) {
      result = UserSettings(
        id: existing['id'] as int?,
        key: key,
        value: value,
        description: description ?? existing['description'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(existing['created_at'] as int),
        updatedAt: now,
      );
    } else {
      result = UserSettings(
        id: null,
        key: key,
        value: value,
        description: description,
        createdAt: now,
        updatedAt: now,
      );
    }
    jsonMap[key] = result.toMap();
    await storage.ensureUserDir();
    file.writeAsStringSync(jsonEncode(jsonMap));

    final cacheKey = generateCacheKey({'type': 'setting', 'identifier': key});
    cacheManager.set(cacheKey, result);
    return result;
  }
  
  /// Получить все настройки
  Future<List<UserSettings>> getAllSettings() async {
    final file = storage.userSettingsFile();
    if (!file.existsSync()) return [];
    try {
      final jsonMap = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final list = <UserSettings>[];
      for (final entry in jsonMap.entries) {
        final obj = entry.value as Map<String, dynamic>;
        list.add(UserSettings.fromMap(obj));
      }
      list.sort((a, b) => a.key.compareTo(b.key));
      return list;
    } catch (_) {
      return [];
    }
  }
  
  /// Удалить настройку
  Future<bool> deleteSetting(String key) async {
    final file = storage.userSettingsFile();
    if (!file.existsSync()) return false;
    try {
      final jsonMap = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      if (!jsonMap.containsKey(key)) return false;
      jsonMap.remove(key);
      file.writeAsStringSync(jsonEncode(jsonMap));
      final cacheKey = generateCacheKey({'type': 'setting', 'identifier': key});
      cacheManager.remove(cacheKey);
      return true;
    } catch (_) {
      return false;
    }
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
    // Определим следующий id
    int maxId = 0;
    final file = storage.userEditsFile();
    if (file.existsSync()) {
      for (final line in file.readAsLinesSync()) {
        if (line.trim().isEmpty) continue;
        try {
          final obj = jsonDecode(line) as Map<String, dynamic>;
          final id = obj['id'] as int?;
          if (id != null && id > maxId) maxId = id;
        } catch (_) {}
      }
    }
    final edit = UserTranslationEdit(
      id: maxId + 1,
      originalText: originalText,
      originalTranslation: originalTranslation,
      userTranslation: userTranslation,
      languagePair: languagePair.toLowerCase(),
      reason: reason,
      createdAt: now,
      updatedAt: now,
    );
    await storage.ensureUserDir();
    await storage.appendJsonLine(file, edit.toMap());
    return edit;
  }
  
  /// Получить пользовательские правки
  Future<List<UserTranslationEdit>> getTranslationEdits({
    String? languagePair,
    bool? onlyApproved,
    int? limit = 50,
    int? offset = 0,
  }) async {
    final file = storage.userEditsFile();
    final list = <UserTranslationEdit>[];
    if (!file.existsSync()) return list;
    for (final line in file.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      try {
        final obj = jsonDecode(line) as Map<String, dynamic>;
        final e = UserTranslationEdit.fromMap(obj);
        if (languagePair != null && e.languagePair.toLowerCase() != languagePair.toLowerCase()) continue;
        if (onlyApproved != null && e.isApproved != onlyApproved) continue;
        list.add(e);
      } catch (_) {}
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    var out = list;
    if (offset != null && offset > 0 && offset < out.length) out = out.sublist(offset);
    if (limit != null && limit < out.length) out = out.sublist(0, limit);
    return out;
  }
  
  /// Одобрить пользовательскую правку
  Future<bool> approveTranslationEdit(int editId) async {
    final file = storage.userEditsFile();
    if (!file.existsSync()) return false;
    final items = <Map<String, dynamic>>[];
    var changed = false;
    for (final line in file.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      try {
        final obj = jsonDecode(line) as Map<String, dynamic>;
        if ((obj['id'] as int?) == editId) {
          obj['is_approved'] = 1;
          obj['updated_at'] = DateTime.now().millisecondsSinceEpoch;
          changed = true;
        }
        items.add(obj);
      } catch (_) {}
    }
    if (changed) await storage.rewriteJsonLines(file, items);
    return changed;
  }
  
  /// Поиск пользовательских правок по тексту
  Future<UserTranslationEdit?> findEditForText(
    String originalText,
    String languagePair,
  ) async {
    final file = storage.userEditsFile();
    if (!file.existsSync()) return null;
    for (final line in file.readAsLinesSync().reversed) {
      if (line.trim().isEmpty) continue;
      try {
        final obj = jsonDecode(line) as Map<String, dynamic>;
        final e = UserTranslationEdit.fromMap(obj);
        if (e.isApproved && e.originalText == originalText && e.languagePair.toLowerCase() == languagePair.toLowerCase()) {
          return e;
        }
      } catch (_) {}
    }
    return null;
  }
}
