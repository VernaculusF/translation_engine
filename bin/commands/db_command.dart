// ignore_for_file: avoid_print, prefer_const_constructors

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:translation_engine/src/data/dictionary_repository.dart';
import 'package:translation_engine/src/data/phrase_repository.dart';
import 'package:translation_engine/src/utils/cache_manager.dart';
import 'package:translation_engine/src/data/database_manager_ffi.dart';
import 'package:translation_engine/src/tools/dictionary_importer.dart';
import 'package:translation_engine/src/tools/phrase_importer.dart';
import 'base_command.dart';

class DbCommand extends BaseCommand {
static const String defaultDataRepo = 'https://raw.githubusercontent.com/VernaculusF/translation-engine-data/main';
static const String githubApiRepo = 'https://api.github.com/repos/VernaculusF/translation-engine-data';
  
  @override
  String get name => 'db';
  
  @override
  String get description => 'Download and manage dictionary databases';
  
  @override
  void printUsage() {
    print('Database Management Command');
    print('');
    print('Download and manage translation dictionaries from remote repository.');
    print('');
    print('Usage:');
    print('  dart run bin/translate_engine.dart db [--lang=<xx-yy>] [--db=<dir>] [options]');
    print('');
    print('Options:');
    print('  --lang         Language pair to download (e.g., en-ru, es-en)');
    print('                 If not specified, downloads all available languages');
    print('  --db           Directory to store databases (default: ./translation_data)');
    print('  --source       Custom data repository URL');
    print('  --list         List available language pairs without downloading');
    print('  --force        Force re-download even if files exist');
    print('  --dry-run      Show what would be downloaded without actually downloading');
    print('  --help, -h     Show this help');
    print('');
    print('Examples:');
    print('  dart run bin/translate_engine.dart db');
    print('    Downloads all available language pairs to ./translation_data');
    print('');
    print('  dart run bin/translate_engine.dart db --lang=en-ru --db=./data');
    print('    Downloads English-Russian dictionary to ./data directory');
    print('');
    print('  dart run bin/translate_engine.dart db --list');
    print('    Lists all available language pairs');
    print('');
    print('  dart run bin/translate_engine.dart db --lang=es-en --force');
    print('    Force re-download Spanish-English dictionary');
  }
  
  @override
  Future<int> run(List<String> args) async {
    if (args.contains('--help') || args.contains('-h')) {
      printUsage();
      return 0;
    }
    
    final params = parseArgs(args);
    
    // Handle list command
    if (params.containsKey('list')) {
      return await _listAvailableLanguages(params);
    }
    
    // Set defaults
    final dbDir = params['db'] ?? './translation_data';
    final source = params['source'] ?? defaultDataRepo;
    final langPair = params['lang'];
    final force = params.containsKey('force');
    final dryRun = params.containsKey('dry-run');
    
    print('Translation Engine - Database Management');
    print('');
    print('Source: $source');
    print('Database directory: $dbDir');
    
    if (langPair != null) {
      print('Language pair: $langPair');
    } else {
      print('Mode: Download all available languages');
    }
    
    if (dryRun) {
      print('Mode: Dry run (no actual downloads)');
    }
    
    print('');
    
    try {
      // Get available languages
      final availableLanguages = await _getAvailableLanguages(source);
      
      if (availableLanguages.isEmpty) {
        print('No language pairs found in the data repository.');
        return 1;
      }
      
      List<String> languagesToDownload;
      
      if (langPair != null) {
        if (!availableLanguages.contains(langPair)) {
          print('Error: Language pair "$langPair" is not available.');
          print('Available language pairs:');
          for (final lang in availableLanguages) {
            print('  - $lang');
          }
          return 65; // EX_DATAERR
        }
        languagesToDownload = [langPair];
      } else {
        languagesToDownload = availableLanguages;
      }
      
      print('Found ${availableLanguages.length} available language pairs:');
      for (final lang in availableLanguages) {
        final isSelected = languagesToDownload.contains(lang);
        print('  ${isSelected ? "✓" : " "} $lang');
      }
      print('');
      
      if (dryRun) {
        print('Dry run complete. ${languagesToDownload.length} language pairs would be downloaded.');
        return 0;
      }
      
      // Create database directory
      final dbDirectory = Directory(dbDir);
      if (!dbDirectory.existsSync()) {
        print('Creating database directory: $dbDir');
        dbDirectory.createSync(recursive: true);
      }
      
      // Download and import each language pair
      var successCount = 0;
      var failCount = 0;
      
      for (final lang in languagesToDownload) {
        print('Processing $lang...');
        
        try {
          final success = await _downloadAndImportLanguage(
            lang, 
            source, 
            dbDir, 
            force: force
          );
          
          if (success) {
            successCount++;
            print('  ✓ $lang completed successfully');
          } else {
            failCount++;
            print('  ✗ $lang failed');
          }
        } catch (e) {
          failCount++;
          print('  ✗ $lang failed with error: $e');
        }
        
        print('');
      }
      
      print('Download Summary:');
      print('  Successful: $successCount');
      print('  Failed: $failCount');
      print('  Total: ${successCount + failCount}');
      
      if (failCount == 0) {
        print('');
        print('All downloads completed successfully!');
        print('Database location: $dbDir');
        return 0;
      } else {
        print('');
        print('Some downloads failed. Check the output above for details.');
        return failCount > successCount ? 1 : 0;
      }
      
    } catch (e) {
      print('Error: $e');
      return 1;
    }
  }
  
  Future<List<String>> _getAvailableLanguages(String source) async {
    try {
      // Try to get language list from index file
      final indexUrl = '$source/index.json';
      final response = await http.get(Uri.parse(indexUrl)).timeout(Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final languages = (data['languages'] as List?)?.cast<String>() ?? [];
        if (languages.isNotEmpty) {
          return languages;
        }
      }
    } catch (e) {
      // Fallback to hardcoded list if index is not available
      print('Note: Could not fetch language index, using default list');
    }
    
    // Fallback to common language pairs
    return [
      'en-ru', 'ru-en',
      'en-es', 'es-en', 
      'en-fr', 'fr-en',
      'en-de', 'de-en',
      'en-it', 'it-en',
      'en-pt', 'pt-en',
      'en-ja', 'ja-en',
      'en-ko', 'ko-en',
      'en-zh', 'zh-en',
    ];
  }
  
  Future<int> _listAvailableLanguages(Map<String, String> params) async {
    final source = params['source'] ?? defaultDataRepo;
    
    print('Available Language Pairs');
    print('');
    print('Source: $source');
    print('');
    
    try {
      final languages = await _getAvailableLanguages(source);
      
      if (languages.isEmpty) {
        print('No language pairs available.');
        return 1;
      }
      
      print('Available language pairs (${languages.length}):');
      for (final lang in languages) {
        print('  - $lang');
      }
      
      return 0;
    } catch (e) {
      print('Error fetching language list: $e');
      return 1;
    }
  }
  
  Future<bool> _downloadAndImportLanguage(
    String langPair, 
    String source, 
    String dbDir, 
    {bool force = false}
  ) async {
    final tempDir = Directory.systemTemp.createTempSync('translation_engine_');
    
    try {
      // Define possible file formats and names
      final formats = ['csv', 'json', 'jsonl'];
      final fileTypes = ['dictionary', 'phrases'];
      
      var downloadedFiles = <File>[];
      
      // Try to download dictionary and phrase files
      for (final fileType in fileTypes) {
        var downloaded = false;
        
        for (final format in formats) {
          final fileName = '${langPair}_$fileType.$format';
          final fileUrl = '$source/data/$fileName';
          final tempFile = File('${tempDir.path}/$fileName');
          
          // Try to download the file
          try {
            final response = await http.get(Uri.parse(fileUrl)).timeout(Duration(seconds: 30));
            
            if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
              await tempFile.writeAsBytes(response.bodyBytes);
              downloadedFiles.add(tempFile);
              print('    Downloaded $fileName (${_formatFileSize(tempFile.lengthSync())})');
              downloaded = true;
              break; // Found this file type, move to next
            }
          } catch (e) {
            // File not found or network error, try next format
            continue;
          }
        }
        
        if (!downloaded) {
          print('    Warning: No $fileType file found for $langPair');
        }
      }
      
      if (downloadedFiles.isEmpty) {
        print('    Error: No data files found for $langPair');
        return false;
      }
      
      // Initialize database
      final dbManager = DatabaseManagerFfi(customDatabasePath: dbDir);
      final cache = CacheManager();
      final dictRepo = DictionaryRepository(databaseManager: dbManager, cacheManager: cache);
      final phraseRepo = PhraseRepository(databaseManager: dbManager, cacheManager: cache);
      
      await dbManager.checkAllDatabasesIntegrity();
      
      // Import downloaded files
      for (final file in downloadedFiles) {
        final fileName = file.path.split(Platform.pathSeparator).last;
        final format = fileName.split('.').last;
        
        print('    Importing $fileName...');
        
        try {
          if (fileName.contains('dictionary')) {
            // Import dictionary data
            final importer = DictionaryImporter(repository: dictRepo);
            final report = await importer.importFile(
              file, 
              languagePair: langPair, 
              format: format
            );
            
            print('      Dictionary: ${report.insertedOrUpdated} entries imported');
            if (report.errors.isNotEmpty) {
              print('      Warnings: ${report.errors.length} import errors');
            }
          } else if (fileName.contains('phrases')) {
            // Import phrase data using PhraseImporter
            final phraseImporter = PhraseImporter(repository: phraseRepo);
            final report = await phraseImporter.importFile(
              file, 
              languagePair: langPair, 
              format: format
            );
            
            print('      Phrases: ${report.insertedOrUpdated} entries imported');
            if (report.errors.isNotEmpty) {
              print('      Warnings: ${report.errors.length} import errors');
            }
          }
        } catch (e) {
          print('      Error importing $fileName: $e');
          return false;
        }
      }
      
      return true;
      
    } finally {
      // Clean up temp directory
      try {
        tempDir.deleteSync(recursive: true);
      } catch (e) {
        // Ignore cleanup errors
      }
    }
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}