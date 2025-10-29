// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:fluent_translate/src/core/translation_engine.dart';
import 'base_command.dart';

class MetricsCommand extends BaseCommand {
  @override
  String get name => 'metrics';

  @override
  String get description => 'Show engine metrics snapshot (engine/cache/queue/metrics)';

  @override
  void printUsage() {
    print('Metrics Command');
    print('');
    print('Usage:');
    print('  dart run bin/translate_engine.dart metrics [--db=<dir>]');
    print('');
    print('Options:');
    print('  --db    Directory with data (default: ./translation_data)');
    print('  --help  Show this help');
  }

  @override
  Future<int> run(List<String> args) async {
    if (args.contains('--help')) {
      printUsage();
      return 0;
    }
    final params = parseArgs(args);
    final db = params['db'];

    final engine = TranslationEngine();
    await engine.initialize(customDatabasePath: db);
    final snapshot = engine.getMetrics();
    print(const JsonEncoder.withIndent('  ').convert(snapshot));
    return 0;
  }
}