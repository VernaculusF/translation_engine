// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:fluent_translate/src/core/translation_engine.dart';
import 'base_command.dart';

class CacheCommand extends BaseCommand {
  @override
  String get name => 'cache';

  @override
  String get description => 'Show or clear cache';

  @override
  void printUsage() {
    print('Cache Command');
    print('');
    print('Usage:');
    print('  dart run bin/translate_engine.dart cache stats');
    print('  dart run bin/translate_engine.dart cache clear [words|phrases|all]');
  }

  @override
  Future<int> run(List<String> args) async {
    if (args.isEmpty) {
      printUsage();
      return 0;
    }
    final engine = TranslationEngine();
    await engine.initialize();

    switch (args.first) {
      case 'stats':
        print(const JsonEncoder.withIndent('  ').convert(engine.getCacheInfo()));
        return 0;
      case 'clear':
        final type = args.length > 1 ? args[1] : 'all';
        await engine.clearCache(type: type);
        print('Cache cleared: $type');
        return 0;
      default:
        printUsage();
        return 64;
    }
  }
}