// ignore_for_file: avoid_print

import 'package:fluent_translate/src/utils/debug_logger.dart';
import 'package:fluent_translate/src/core/engine_config.dart';
import 'base_command.dart';

class LogsCommand extends BaseCommand {
  @override
  String get name => 'logs';

  @override
  String get description => 'Configure logging (level enable/disable structured)';

  @override
  void printUsage() {
    print('Logs Command');
    print('');
    print('Usage:');
    print('  dart run bin/translate_engine.dart logs level <error|warn|info|debug>');
    print('  dart run bin/translate_engine.dart logs enable');
    print('  dart run bin/translate_engine.dart logs disable');
    print('');
  }

  @override
  Future<int> run(List<String> args) async {
    if (args.isEmpty) {
      printUsage();
      return 0;
    }
    final sub = args.first;
    switch (sub) {
      case 'level':
        if (args.length < 2) {
          print('Error: missing level');
          return 64;
        }
        final lvl = args[1].toLowerCase();
        final level = LogLevel.values.firstWhere(
          (l) => l.name.toLowerCase() == lvl,
          orElse: () => LogLevel.warning,
        );
        DebugLogger.instance.setLevel(level);
        DebugLogger.instance.setEnabled(true);
        print('Log level set to ${level.name}');
        return 0;
      case 'enable':
        DebugLogger.instance.setEnabled(true);
        print('Logging enabled');
        return 0;
      case 'disable':
        DebugLogger.instance.setEnabled(false);
        print('Logging disabled');
        return 0;
      default:
        printUsage();
        return 64;
    }
  }
}