import 'database_types.dart';

/// Abstraction over database manager so repositories can be used
/// both in Flutter (sqflite + path_provider) and CLI (sqflite_common_ffi)
abstract class DatabaseManagerBase {
  /// Get a connection for a given logical database type
  Future<DatabaseConnection> getConnection(DatabaseType type);

  /// Close a specific connection (no-op in pooled/singleton implementations)
  Future<void> closeConnection(DatabaseConnection connection);

  /// Reset/close all internal databases (mainly for tests)
  Future<void> reset();

  /// Validate existence of required tables across all databases
  Future<bool> checkAllDatabasesIntegrity();
}
