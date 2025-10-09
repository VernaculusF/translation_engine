import '../utils/cache_manager.dart';
import 'database_manager_base.dart';
import 'database_types.dart';
/// Базовый абстрактный класс для всех репозиториев
/// 
/// Предоставляет общие методы для работы с базой данных и кэшем.
/// Все конкретные репозитории должны наследоваться от этого класса.
abstract class BaseRepository {
  /// Менеджер базы данных (через абстракцию для поддержки Flutter/CLI)
  final DatabaseManagerBase databaseManager;
  
  /// Менеджер кэша
  final CacheManager cacheManager;
  
  /// Имя таблицы для этого репозитория
  String get tableName;
  
  /// Имя базы данных (dictionaries, phrases, user_data)
  DatabaseType get databaseType;
  
  BaseRepository({
    required this.databaseManager,
    required this.cacheManager,
  });
  
  /// Получить подключение к нужной базе данных
  Future<DatabaseConnection> getConnection() async {
    return await databaseManager.getConnection(databaseType);
  }
  
  /// Закрыть подключение
  Future<void> closeConnection(DatabaseConnection connection) async {
    await databaseManager.closeConnection(connection);
  }
  
  /// Выполнить запрос с автоматическим управлением подключением
  Future<T> executeQuery<T>(
    Future<T> Function(DatabaseConnection connection) query,
  ) async {
    final connection = await getConnection();
    try {
      return await query(connection);
    } finally {
      await closeConnection(connection);
    }
  }
  
  /// Выполнить операцию с транзакцией
  Future<T> executeTransaction<T>(
    Future<T> Function(DatabaseConnection connection) operation,
  ) async {
    final connection = await getConnection();
    try {
      await connection.execute('BEGIN TRANSACTION');
      final result = await operation(connection);
      await connection.execute('COMMIT');
      return result;
    } catch (e) {
      await connection.execute('ROLLBACK');
      rethrow;
    } finally {
      await closeConnection(connection);
    }
  }
  
  /// Получить элемент из кэша по ключу
  T? getCached<T>(String key) {
    return cacheManager.get<T>(key);
  }
  
  /// Сохранить элемент в кэш
  void setCached<T>(String key, T value) {
    cacheManager.set(key, value);
  }
  
  /// Удалить элемент из кэша
  bool removeCached(String key) {
    return cacheManager.remove(key);
  }
  
  /// Очистить весь кэш этого репозитория
  void clearCache() {
    // Должно быть переопределено в наследниках для очистки только своих ключей
  }
  
  /// Генерировать ключ кэша для конкретного репозитория
  /// Должно быть переопределено в наследниках
  String generateCacheKey(Map<String, dynamic> params);
  
  /// Проверить существование записи в базе данных
  Future<bool> exists(Map<String, dynamic> conditions) async {
    return executeQuery((connection) async {
      final whereClause = conditions.entries
          .map((entry) => '${entry.key} = ?')
          .join(' AND ');
      
      final values = conditions.values.toList();
      
      final result = await connection.query(
        'SELECT COUNT(*) as count FROM $tableName WHERE $whereClause',
        values,
      );
      
      return result.isNotEmpty && (result.first['count'] as int) > 0;
    });
  }
  
  /// Получить количество записей в таблице
  Future<int> count([Map<String, dynamic>? conditions]) async {
    return executeQuery((connection) async {
      String query = 'SELECT COUNT(*) as count FROM $tableName';
      List<dynamic> values = [];
      
      if (conditions != null && conditions.isNotEmpty) {
        final whereClause = conditions.entries
            .map((entry) => '${entry.key} = ?')
            .join(' AND ');
        query += ' WHERE $whereClause';
        values = conditions.values.toList();
      }
      
      final result = await connection.query(query, values);
      return result.isNotEmpty ? result.first['count'] as int : 0;
    });
  }
  
  /// Удалить записи по условию
  Future<int> delete(Map<String, dynamic> conditions) async {
    return executeTransaction((connection) async {
      final whereClause = conditions.entries
          .map((entry) => '${entry.key} = ?')
          .join(' AND ');
      
      final values = conditions.values.toList();
      
      final result = await connection.execute(
        'DELETE FROM $tableName WHERE $whereClause',
        values,
      );
      
      // Очистить связанные ключи из кэша
      _clearRelatedCacheKeys(conditions);
      
      return result;
    });
  }
  
  /// Получить все записи с опциональной пагинацией
  Future<List<Map<String, dynamic>>> getAll({
    Map<String, dynamic>? conditions,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return executeQuery((connection) async {
      String query = 'SELECT * FROM $tableName';
      List<dynamic> values = [];
      
      if (conditions != null && conditions.isNotEmpty) {
        final whereClause = conditions.entries
            .map((entry) => '${entry.key} = ?')
            .join(' AND ');
        query += ' WHERE $whereClause';
        values = conditions.values.toList();
      }
      
      if (orderBy != null) {
        query += ' ORDER BY $orderBy';
      }
      
      if (limit != null) {
        query += ' LIMIT $limit';
        if (offset != null) {
          query += ' OFFSET $offset';
        }
      }
      
      return await connection.query(query, values);
    });
  }
  
  /// Очистить связанные ключи кэша (должно быть переопределено в наследниках)
  void _clearRelatedCacheKeys(Map<String, dynamic> conditions) {
    // Базовая реализация - очистить весь кэш
    // В наследниках можно сделать более умную очистку
    clearCache();
  }
  
  /// Валидация данных перед операциями
  /// Должно быть переопределено в наследниках
  void validateData(Map<String, dynamic> data) {
    // Базовая валидация - проверить что данные не пустые
    if (data.isEmpty) {
      throw ArgumentError('Data cannot be empty');
    }
  }
  
  /// Преобразование данных перед сохранением
  /// Может быть переопределено в наследниках
  Map<String, dynamic> transformForDatabase(Map<String, dynamic> data) {
    return data;
  }
  
  /// Преобразование данных после получения из БД
  /// Может быть переопределено в наследниках  
  Map<String, dynamic> transformFromDatabase(Map<String, dynamic> data) {
    return data;
  }
}