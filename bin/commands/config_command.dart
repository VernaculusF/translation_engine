// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:fluent_translate/src/core/translation_engine.dart';
import 'base_command.dart';

class ConfigCommand extends BaseCommand {
  @override
  String get name => 'config';

  @override
  String get description => 'Show or apply engine configuration (JSON)';

  @override
  void printUsage() {
    print('Config Command');
    print('');
    print('Usage:');
    print('  dart run bin/translate_engine.dart config show [--db=<dir>]');
    print('  dart run bin/translate_engine.dart config set --file=<path> [--db=<dir>]');
    print('');
    print('Options:');
    print('  --db      Data directory (default: ./translation_data)');
    print('  --file    Path to JSON config file for set');
    print('  --help    Show this help');
  }

  @override
  Future<int> run(List<String> args) async {
    if (args.isEmpty || args.contains('--help')) {
      printUsage();
      return 0;
    }

    final cmd = args.first;
    final params = parseArgs(args.skip(1).toList());
    final db = params['db'];

    final engine = TranslationEngine();

    switch (cmd) {
      case 'show':
        await engine.initialize(customDatabasePath: db);
        final snapshot = engine.getMetrics();
        print(const JsonEncoder.withIndent('  ').convert(snapshot));
        return 0;

      case 'set':
        final filePath = params['file'];
        if (filePath == null) {
          print('Error: --file is required for config set');
          return 64;
        }
        final content = await File(filePath).readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        await engine.initialize(customDatabasePath: db, config: map);
        print('Configuration applied.');
        return 0;

      default:
        print('Unknown subcommand: $cmd');
        printUsage();
        return 64;
    }
  }
}