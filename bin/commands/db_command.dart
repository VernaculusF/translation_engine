// ignore_for_file: avoid_print, prefer_const_constructors

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart' as crypto;
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'base_command.dart';

class DbCommand extends BaseCommand {
static const String defaultDataRepo = 'https://raw.githubusercontent.com/VernaculusF/translation-engine-data/main';
static const String githubApiRepo = 'https://api.github.com/repos/VernaculusF/translation-engine-data';
  
  @override
  String get name => 'db';
  
  @override
String get description => 'Download zipped data per language pair and import (dictionary/phrases/rules)';
  
  @override
  void printUsage() {
    print('Data Management Command');
    print('');
print('Download zipped data bundles from remote repository and import into local DB.');
    print('');
    print('Usage:');
    print('  dart run bin/translate_engine.dart db [--lang=<xx-yy>] [--db=<dir>] [options]');
    print('');
    print('Options:');
    print('  --lang         Language pair to download (e.g., en-ru, es-en)');
    print('                 If not specified, downloads all available languages');
    print('  --db           Directory to store data (default: ./translation_data)');
    print('  --source       Custom data repository URL');
    print('  --list         List available language pairs without downloading');
    print('  --force        Force re-download even if files exist');
    print('  --sha256       Expected SHA-256 hash for verification (optional)');
    print('  --allow-any-source  Allow downloading from any HTTPS host (security relaxed)');
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
    print('    Force re-download Spanish-English data from zip');
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
    final expectedHash = params['sha256'];
    final allowAnySource = params.containsKey('allow-any-source');
    final langPair = params['lang'];
    final force = params.containsKey('force');
    final dryRun = params.containsKey('dry-run');
    
    print('Translation Engine - Data Management');
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
      
      // Security: enforce HTTPS and allowlist unless overridden
      if (!source.toString().startsWith('https://')) {
        print('Error: Only HTTPS sources are allowed. Provided: $source');
        return 1;
      }
      if (!allowAnySource && !Uri.parse(source).host.contains('githubusercontent.com') && !Uri.parse(source).host.contains('github.com')) {
        print('Error: Source host is not in allowlist. Use --allow-any-source to override.');
        return 1;
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
            force: force,
            expectedSha256: expectedHash,
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

  Future<http.Response> _httpGetWithRetry(Uri uri, {int maxAttempts = 5}) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final resp = await http.get(uri).timeout(Duration(seconds: 10));
        if (resp.statusCode >= 200 && resp.statusCode < 500) {
          return resp;
        }
        // treat 5xx as retryable
        throw HttpException('HTTP ${resp.statusCode}');
      } catch (_) {
        if (attempt >= maxAttempts) rethrow;
        final ms = 200 * (1 << (attempt - 1));
        final backoff = Duration(milliseconds: ms > 5000 ? 5000 : ms);
        await Future.delayed(backoff);
      }
    }
  }

  Future<bool> _downloadAndImportLanguage(
    String lang,
    String source,
    String dbDir, {
    bool force = false,
    String? expectedSha256,
  }) async {
    // Download single zip archive from <source>/zip/<lang>.zip
    final zipUrl = Uri.parse('$source/zip/$lang.zip');
    final destRoot = Directory(dbDir);
    if (!destRoot.existsSync()) destRoot.createSync(recursive: true);
    final zipPath = p.join(dbDir, '$lang.zip');
    final zipFile = File(zipPath);

    // Always re-download zip if --force or zip missing
    if (force || !zipFile.existsSync()) {
      final resp = await _httpGetWithRetry(zipUrl);
      if (resp.statusCode != 200) {
        print('  - Failed to download ZIP: HTTP ${resp.statusCode}');
        return false;
      }
      final bytes = resp.bodyBytes;
      if (expectedSha256 != null && expectedSha256.trim().isNotEmpty) {
        final actual = crypto.sha256.convert(bytes).toString();
        if (!actual.toLowerCase().startsWith(expectedSha256.toLowerCase())) {
          print('  - Hash mismatch for zip. Expected prefix: $expectedSha256, actual: $actual');
          return false;
        }
      }
      await zipFile.writeAsBytes(bytes, flush: true);
      print('  - Downloaded archive: $zipUrl');
    }

    // Extract archive (expects folder <lang>/ inside)
    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      for (final entry in archive) {
        final name = _sanitizeZipEntry(entry.name);
        if (name.isEmpty) continue;
        final outPath = p.normalize(p.join(destRoot.path, name));
        if (!p.isWithin(destRoot.path, outPath)) {
          // prevent traversal
          continue;
        }
        if (entry.isFile) {
          final outFile = File(outPath);
          if (!outFile.parent.existsSync()) outFile.parent.createSync(recursive: true);
          await outFile.writeAsBytes(entry.content as List<int>, flush: true);
        } else {
          final dir = Directory(outPath);
          if (!dir.existsSync()) dir.createSync(recursive: true);
        }
      }
      print('  - Extracted archive to $dbDir');
    } catch (e) {
      print('  - Failed to extract ZIP: $e');
      return false;
    } finally {
      // Remove zip file
      try { if (zipFile.existsSync()) zipFile.deleteSync(); } catch (_) {}
    }

    // Skip importing into repositories here to avoid rewriting extracted files.
    // The engine repositories will read the JSONL files on demand without altering them.
    return true;
  }

  String _sanitizeZipEntry(String name) {
    var n = name.replaceAll('\\\\', '/');
    while (n.startsWith('/')) { n = n.substring(1); }
    n = n.replaceAll('..', '');
    return n.trim();
  }
  
  Future<List<String>> _getAvailableLanguages(String source) async {
    try {
      // Try to get language list from index file
      final indexUrl = '$source/index.json';
      final response = await _httpGetWithRetry(Uri.parse(indexUrl));
      
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
  
}
