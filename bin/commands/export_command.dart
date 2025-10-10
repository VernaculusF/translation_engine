// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'base_command.dart';
import 'package:translation_engine/src/data/dictionary_repository.dart';
import 'package:translation_engine/src/data/phrase_repository.dart';
import 'package:translation_engine/src/utils/cache_manager.dart';

class ExportCommand extends BaseCommand {
  @override
  String get name => 'export';

  @override
  String get description => 'Export data (dictionary/phrases) to CSV/JSON/JSONL';

  @override
  void printUsage() {
    print('Export Command');
    print('');
    print('Usage:');
    print('  dart run bin/translate_engine.dart export --db=<dir> --lang=<xx-yy> --type=<dictionary|phrases> --format=<csv|json|jsonl> --out=<file>');
    print('');
    print('Options:');
    print('  --db        Data directory (translation_data)');
    print('  --lang      Language pair, e.g., en-ru');
    print('  --type      Data type: dictionary | phrases');
    print('  --format    Output format: csv | json | jsonl');
    print('  --out       Output file path');
  }

  @override
  Future<int> run(List<String> args) async {
    if (args.contains('--help') || args.contains('-h')) {
      printUsage();
      return 0;
    }

    final p = parseArgs(args);
    if (!validateRequiredParams(p, ['db', 'lang', 'type', 'format', 'out'])) {
      print('');
      printUsage();
      return 64;
    }
    final dir = p['db']!;
    final lang = p['lang']!;
    final type = p['type']!;
    final format = p['format']!;
    final outPath = p['out']!;

    if (!['dictionary', 'phrases'].contains(type)) {
      print('Error: unsupported type: $type');
      return 65;
    }
    if (!['csv', 'json', 'jsonl'].contains(format)) {
      print('Error: unsupported format: $format');
      return 65;
    }

    try {
      final cache = CacheManager();
      final outFile = File(outPath);
      if (!outFile.parent.existsSync()) outFile.parent.createSync(recursive: true);

      if (type == 'dictionary') {
        final repo = DictionaryRepository(dataDirPath: dir, cacheManager: cache);
        final list = await repo.getAllTranslations(lang);
        await _write(list.map((e) => e.toMap()), format, outFile, csvHeader: const ['source_word','target_word','language_pair','part_of_speech','definition','frequency','created_at','updated_at','id']);
      } else {
        final repo = PhraseRepository(dataDirPath: dir, cacheManager: cache);
        final list = await repo.getAllPhrases(lang);
        await _write(list.map((e) => e.toMap()), format, outFile, csvHeader: const ['source_phrase','target_phrase','language_pair','category','context','frequency','confidence','created_at','updated_at','id']);
      }
      print('Export done: $outPath');
      return 0;
    } catch (e) {
      print('Export error: $e');
      return 1;
    }
  }

  Future<void> _write(Iterable<Map<String, dynamic>> items, String format, File out, {List<String>? csvHeader}) async {
    switch (format) {
      case 'jsonl':
        final sink = out.openWrite();
        try {
          for (final m in items) {
            sink.writeln(jsonEncode(m));
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
        break;
      case 'json':
        await out.writeAsString(jsonEncode(items.toList()));
        break;
      case 'csv':
        final buf = StringBuffer();
        if (csvHeader != null) buf.writeln(csvHeader.join(','));
        for (final m in items) {
          final row = csvHeader?.map((k) => _csvEscape(m[k])) ?? m.values.map(_csvEscape);
          buf.writeln(row.join(','));
        }
        await out.writeAsString(buf.toString());
        break;
    }
  }

  String _csvEscape(Object? v) {
    final s = (v ?? '').toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"' + s.replaceAll('"', '""') + '"';
    }
    return s;
  }
}
