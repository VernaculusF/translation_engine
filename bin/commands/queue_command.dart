// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:fluent_translate/src/core/translation_engine.dart';
import 'base_command.dart';

class QueueCommand extends BaseCommand {
  @override
  String get name => 'queue';

  @override
  String get description => 'Show queue status';

  @override
  void printUsage() {
    print('Queue Command');
    print('');
    print('Usage:');
    print('  dart run bin/translate_engine.dart queue stats');
  }

  @override
  Future<int> run(List<String> args) async {
    final engine = TranslationEngine();
    await engine.initialize();
    final metrics = engine.getMetrics();
    print(const JsonEncoder.withIndent('  ').convert(metrics['queue']));
    return 0;
  }
}