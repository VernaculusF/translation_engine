// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:fluent_translate/src/data/grammar_rules_repository.dart';
import 'package:fluent_translate/src/data/word_order_rules_repository.dart';
import 'package:fluent_translate/src/data/post_processing_rules_repository.dart';
import 'package:fluent_translate/src/storage/file_storage.dart';

import 'base_command.dart';

class RulesValidateCommand extends BaseCommand {
  @override
  String get name => 'rules-validate';

  @override
  String get description => 'Validate grammar/word-order/post-processing rules JSONL files';

  @override
  void printUsage() {
    print('Rules Validate Command');
    print('');
    print('Usage:');
    print('  dart run bin/translate_engine.dart rules-validate --db=<dir> --lang=<xx-yy>');
  }

  @override
  Future<int> run(List<String> args) async {
    if (args.contains('--help') || args.contains('-h')) {
      printUsage();
      return 0;
    }
    final p = parseArgs(args);
    if (!validateRequiredParams(p, ['db', 'lang'])) {
      print('');
      printUsage();
      return 64;
    }

    final dir = p['db']!;
    final lang = p['lang']!.toLowerCase();

    final storage = FileStorageService(rootDir: dir);

    final files = <String, File>{
      'grammar': storage.grammarRulesFile(lang),
      'word_order': storage.wordOrderRulesFile(lang),
      'post_processing': storage.postProcessingRulesFile(lang),
    };

    final result = <String, dynamic>{};
    int exit = 0;

    for (final entry in files.entries) {
      final name = entry.key;
      final file = entry.value;
      final summary = await _validateFile(name, file, lang);
      result[name] = summary;
      if ((summary['errors'] as int) > 0) exit = 1;
    }

    print(const JsonEncoder.withIndent('  ').convert(result));
    return exit;
  }

  Future<Map<String, dynamic>> _validateFile(String name, File file, String lang) async {
    final type = name;
    if (!file.existsSync()) {
      return {
        'file': file.path,
        'exists': false,
        'lines': 0,
        'parsed': 0,
        'errors': 0,
        'error_lines': [],
      };
    }

    final lines = await file.readAsLines();
    int parsed = 0;
    final errorLines = <int, String>{};

    for (int i = 0; i < lines.length; i++) {
      final raw = lines[i].trim();
      if (raw.isEmpty) continue;
      try {
        final obj = jsonDecode(raw) as Map<String, dynamic>;
        switch (type) {
          case 'grammar':
            GrammarRuleDto.fromMap(obj);
            break;
          case 'word_order':
            WordOrderRuleDto.fromMap(obj);
            break;
          case 'post_processing':
            PostProcessingRuleDto.fromMap(obj);
            break;
        }
        parsed++;
      } catch (e) {
        errorLines[i + 1] = e.toString();
      }
    }

    return {
      'file': file.path,
      'exists': true,
      'lines': lines.where((l) => l.trim().isNotEmpty).length,
      'parsed': parsed,
      'errors': errorLines.length,
      'error_lines': errorLines,
    };
  }
}
