// ignore_for_file: avoid_print
// CLI entrypoint that uses FFI database manager (no Flutter dependencies)
import 'dart:io';

import 'package:translation_engine/src/data/dictionary_repository.dart';
import 'package:translation_engine/src/utils/cache_manager.dart';
import 'package:translation_engine/src/data/database_manager_ffi.dart';
import 'package:translation_engine/src/tools/dictionary_importer.dart';

void printUsage() {
  print('Dictionary Import CLI (FFI)');
  print('');
  print('Usage:');
  print('  dart run bin/import_dictionary_cli.dart '
      '--db=<dir> --file=<path> --format=<csv|json|jsonl> --lang=<xx-yy> [--delimiter=,|;|\t]');
  print('');
  print('Options:');
  print('  --db           Directory to store or locate databases');
  print('  --file         Input data file (CSV/JSON/JSONL)');
  print('  --format       Data format: csv | json | jsonl');
  print('  --lang         Language pair, e.g., en-ru');
  print('  --delimiter    CSV delimiter (default: ,)');
  print('  -h, --help     Show this help');
}

Future<int> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    printUsage();
    return 0;
  }

  final params = <String, String>{};
  for (final a in args) {
    final idx = a.indexOf('=');
    if (idx > 0) {
      params[a.substring(0, idx).replaceAll('--', '')] = a.substring(idx + 1);
    }
  }

  final filePath = params['file'];
  final dbDir = params['db'];
  final lang = params['lang'];
  final format = params['format'];
  final delimiter = params['delimiter'] ?? ',';

  if (filePath == null || dbDir == null || lang == null || format == null) {
    print('Missing required parameters.');
    print('');
    printUsage();
    return 64; // EX_USAGE
  }

  final file = File(filePath);
  if (!file.existsSync()) {
    print('Error: file not found: $filePath');
    return 66; // EX_NOINPUT
  }

  // Initialize repository on provided DB path using FFI manager
  final dbManager = DatabaseManagerFfi(customDatabasePath: dbDir);
  final cache = CacheManager();
  final repo = DictionaryRepository(databaseManager: dbManager, cacheManager: cache);

  // Warm up the DB to ensure creation
  await dbManager.checkAllDatabasesIntegrity();

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
