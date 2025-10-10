// ignore_for_file: avoid_print
// A minimal CLI for dictionary import (JSONL storage)
import 'dart:io';
import 'package:fluent_translate/src/data/dictionary_repository.dart';
import 'package:fluent_translate/src/utils/cache_manager.dart';
import 'package:fluent_translate/src/tools/dictionary_importer.dart';

void printUsage() {
  print('Usage: dart run bin/import_dictionary.dart --file=path --db=dir [--lang=en-ru] [--format=csv|json|jsonl] [--delimiter=,|;|\\t]');
}

Future<int> main(List<String> args) async {
  final params = <String, String>{};
  for (final a in args) {
    final idx = a.indexOf('=');
    if (idx > 0) {
      params[a.substring(0, idx).replaceAll('--', '')] = a.substring(idx + 1);
    }
  }
  final filePath = params['file'];
  final dbDir = params['db'];
  if (filePath == null || dbDir == null) {
    printUsage();
    return 1;
  }
  final lang = params['lang'];
  final format = params['format'];
  final delimiter = params['delimiter'] ?? ',';

  final file = File(filePath);
  if (!file.existsSync()) {
    print('Error: file not found: $filePath');
    return 1;
  }

  // Initialize repository on provided data path
  final cache = CacheManager();
  final repo = DictionaryRepository(dataDirPath: dbDir, cacheManager: cache);

  final importer = DictionaryImporter(repository: repo);
  final report = await importer.importFile(file, languagePair: lang, format: format, delimiter: delimiter);

  print('Import report:');
  print('  total: ${report.total}');
  print('  inserted/updated: ${report.insertedOrUpdated}');
  print('  skipped: ${report.skipped}');
  if (report.errors.isNotEmpty) {
    print('  errors:');
    for (final e in report.errors.take(10)) {
      print('   - $e');
    }
    if (report.errors.length > 10) {
      print('   - ... ${report.errors.length - 10} more');
    }
  }

  return 0;
}
