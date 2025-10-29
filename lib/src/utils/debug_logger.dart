/// Debug logger utility for Translation Engine
/// 
/// Provides structured logging with levels and optional trace/span context.
// ignore_for_file: avoid_print, dangling_library_doc_comments

import 'dart:convert';

import '../core/engine_config.dart';

class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  static DebugLogger get instance => _instance;
  
  DebugLogger._internal();
  
  bool _enabled = false;
  LogLevel _level = LogLevel.warning;
  bool _structured = true;

  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  void setLevel(LogLevel level) {
    _level = level;
  }

  void setStructured(bool structured) {
    _structured = structured;
  }

  bool get enabled => _enabled;
  LogLevel get level => _level;
  bool get structured => _structured;

  bool _shouldLog(LogLevel level) => _enabled && level.index <= _level.index;

  void _print(LogLevel level, String message, {Map<String, dynamic>? fields}) {
    if (!_shouldLog(level)) return;
    final ts = DateTime.now().toUtc().toIso8601String();
    if (_structured) {
      final payload = {
        'ts': ts,
        'level': level.name,
        'message': message,
        if (fields != null) ...fields,
      };
      print(jsonEncode(payload));
    } else {
      final prefix = '[${level.name.toUpperCase()} $ts]';
      if (fields != null && fields.isNotEmpty) {
        print('$prefix $message ${jsonEncode(fields)}');
      } else {
        print('$prefix $message');
      }
    }
  }

  void debug(String message, {Map<String, dynamic>? fields}) =>
      _print(LogLevel.debug, message, fields: fields);

  void info(String message, {Map<String, dynamic>? fields}) =>
      _print(LogLevel.info, message, fields: fields);

  void warning(String message, {Map<String, dynamic>? fields}) =>
      _print(LogLevel.warning, message, fields: fields);

  void error(String message, {dynamic error, StackTrace? stackTrace, Map<String, dynamic>? fields}) {
    final f = {
      if (fields != null) ...fields,
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stack': stackTrace.toString(),
    };
    _print(LogLevel.error, message, fields: f);
  }
}
