/// Перечисление типов баз данных в системе
enum DatabaseType {
  /// База данных словарей
  dictionaries,
  
  /// База данных фраз
  phrases,
  
  /// База данных пользовательских данных
  userData,
}

/// Интерфейс для работы с соединением базы данных
/// Обертка над Database от sqflite для удобства тестирования
abstract class DatabaseConnection {
  /// Выполнить SQL запрос с параметрами
  Future<List<Map<String, Object?>>> query(
    String query, [
    List<Object?>? arguments,
  ]);
  
  /// Выполнить SQL команду (INSERT, UPDATE, DELETE)
  Future<int> execute(
    String sql, [
    List<Object?>? arguments,
  ]);
  
  /// Закрыть соединение
  Future<void> close();
}

/// Реализация DatabaseConnection для работы с sqflite Database
class SqliteDatabaseConnection implements DatabaseConnection {
  final dynamic _database;
  
  SqliteDatabaseConnection(this._database);
  
  @override
  Future<List<Map<String, Object?>>> query(
    String query, [
    List<Object?>? arguments,
  ]) async {
    return await _database.rawQuery(query, arguments);
  }
  
  @override
  Future<int> execute(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    return await _database.rawInsert(sql, arguments);
  }
  
  @override
  Future<void> close() async {
    await _database.close();
  }
}