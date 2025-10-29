// ignore_for_file: avoid_print

import 'package:fluent_translate/src/core/translation_engine.dart';
import 'base_command.dart';

class EngineCommand extends BaseCommand {
  @override
  String get name => 'engine';

  @override
  String get description => 'Engine maintenance commands (reset)';

  @override
  void printUsage() {
    print('Engine Command');
    print('');
    print('Usage:');
    print('  dart run bin/translate_engine.dart engine reset');
  }

  @override
  Future<int> run(List<String> args) async {
    if (args.isEmpty || args.first != 'reset') {
      printUsage();
      return 0;
    }
    final engine = TranslationEngine();
    engine.reset();
    print('Engine reset performed.');
    return 0;
  }
}