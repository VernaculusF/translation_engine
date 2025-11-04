// ignore_for_file: avoid_print
import 'dart:convert';

import 'base_command.dart';
import 'package:fluent_translate/fluent_translate.dart';

class TranslateOnceCommand extends BaseCommand {
  @override
  String get name => 'translate';

  @override
  String get description => 'Run a single translation and output JSON with layer results';

  @override
  void printUsage() {
    print('Translate Command');
    print('');
    print('Usage:');
    print('  dart run bin/translate_engine.dart translate --db=<dir> --text="..." --sl=<xx> --tl=<yy>');
  }

  @override
  Future<int> run(List<String> args) async {
    if (args.contains('--help') || args.contains('-h')) {
      printUsage();
      return 0;
    }
    final p = parseArgs(args);
    if (!validateRequiredParams(p, ['db', 'text', 'sl', 'tl'])) {
      print('');
      printUsage();
      return 64;
    }

    final db = p['db']!;
    final text = p['text']!;
    final sl = p['sl']!;
    final tl = p['tl']!;

    final engine = TranslationEngine();
    await engine.initialize(customDatabasePath: db, config: {
      'debug': true,
      'log_level': 'info',
    });

    final res = await engine.translate(text, sourceLanguage: sl, targetLanguage: tl);

    final output = res.toMap();
    print(const JsonEncoder.withIndent('  ').convert(output));
    return res.hasError ? 1 : 0;
  }
}
