/// Debug logger utility for Translation Engine
/// 
/// Provides logging functionality for development and debugging purposes.
// ignore_for_file: avoid_print, dangling_library_doc_comments

class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  static DebugLogger get instance => _instance;
  
  DebugLogger._internal();
  
  bool _enabled = false;
  
  /// Enable or disable debug logging
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }
  
  /// Log debug message
  void debug(String message) {
    if (_enabled) {
      print('[DEBUG] $message');
    }
  }
  
  /// Log warning message
  void warning(String message) {
    if (_enabled) {
      print('[WARNING] $message');
    }
  }
  
  /// Log error message
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_enabled) {
      print('[ERROR] $message');
      if (error != null) {
        print('[ERROR] Details: $error');
      }
      if (stackTrace != null) {
        print('[ERROR] StackTrace: $stackTrace');
      }
    }
  }
  
  /// Log info message
  void info(String message) {
    if (_enabled) {
      print('[INFO] $message');
    }
  }
}