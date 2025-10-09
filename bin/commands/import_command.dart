// ignore_for_file: avoid_print

import 'dart:io';
import 'package:translation_engine/src/data/dictionary_repository.dart';
import 'package:translation_engine/src/utils/cache_manager.dart';
import 'package:translation_engine/src/data/database_manager_ffi.dart';
import 'package:translation_engine/src/tools/dictionary_importer.dart';
import 'base_command.dart';

class ImportCommand extends BaseCommand {
  @override
  String get name => 'import';
  
  @override
  String get description => 'Import dictionary data from files (CSV/JSON/JSONL)';
  
  @override
  void printUsage() {
    print('Import Command');
    print('');
    print('Import dictionary data from local files into the database.');
    print('');
    print('Usage:');
    print('  dart run bin/translate_engine.dart import --db=<dir> --file=<path> --format=<csv|json|jsonl> --lang=<xx-yy> [--delimiter=,|;|\\t]');
    print('');
    print('Required Options:');
    print('  --db           Directory to store or locate databases');
    print('  --file         Input data file (CSV/JSON/JSONL)');
    print('  --format       Data format: csv | json | jsonl');
    print('  --lang         Language pair, e.g., en-ru');
    print('');
    print('Optional:');
    print('  --delimiter    CSV delimiter (default: ,)');
    print('  --help, -h     Show this help');
    print('');
    print('Examples:');
    print('  dart run bin/translate_engine.dart import --db=./data --file=en_ru_dict.csv --format=csv --lang=en-ru');
    print('  dart run bin/translate_engine.dart import --db=./data --file=dictionary.json --format=json --lang=es-en');
  }
  
  @override
  Future<int> run(List<String> args) async {
    if (args.contains('--help') || args.contains('-h')) {
      printUsage();
      return 0;
    }
    
    final params = parseArgs(args);
    
    if (!validateRequiredParams(params, ['db', 'file', 'format', 'lang'])) {
      print('');
      printUsage();
      return 64; // EX_USAGE
    }
    
    final filePath = params['file']!;
    final dbDir = params['db']!;
    final lang = params['lang']!;
    final format = params['format']!;
    final delimiter = params['delimiter'] ?? ',';
    
    // Validate format
    if (!['csv', 'json', 'jsonl'].contains(format.toLowerCase())) {
      print('Error: Invalid format "$format". Supported formats: csv, json, jsonl');
      return 65; // EX_DATAERR
    }
    
    // Check file exists
    final file = File(filePath);
    if (!file.existsSync()) {
      print('Error: File not found: $filePath');
      return 66; // EX_NOINPUT
    }
    
    try {
      print('Initializing database...');
      
      // Initialize repository on provided DB path using FFI manager
      final dbManager = DatabaseManagerFfi(customDatabasePath: dbDir);
      final cache = CacheManager();
      final repo = DictionaryRepository(databaseManager: dbManager, cacheManager: cache);
      
      // Ensure database integrity
      await dbManager.checkAllDatabasesIntegrity();
      
      print('Starting import...');
      print('  File: $filePath');
      print('  Format: $format');
      print('  Language: $lang');
      print('  Database: $dbDir');
      
      final importer = DictionaryImporter(repository: repo);
      final report = await importer.importFile(
        file, 
        languagePair: lang, 
        format: format, 
        delimiter: delimiter
      );
      
      print('');
      print('Import completed successfully!');
      print('');
      print('Import report:');
      print('  Total records processed: ${report.total}');
      print('  Inserted/Updated: ${report.insertedOrUpdated}');
      print('  Skipped: ${report.skipped}');
      
      if (report.errors.isNotEmpty) {
        print('  Errors: ${report.errors.length}');
        print('');
        print('First 10 errors:');
        for (final error in report.errors.take(10)) {
          print('    - $error');
        }
        if (report.errors.length > 10) {
          print('    ... and ${report.errors.length - 10} more errors');
        }
      }
      
      return 0;
      
    } catch (e) {
      print('Error during import: $e');
      return 1;
    }
  }
}