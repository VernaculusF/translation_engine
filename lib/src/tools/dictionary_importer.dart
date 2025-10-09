library;

import 'dart:convert';
import 'dart:io';

import '../data/dictionary_repository.dart';

class ImportReport {
  final int total;
  final int insertedOrUpdated;
  final int skipped;
  final List<String> errors;

  const ImportReport({
    required this.total,
    required this.insertedOrUpdated,
    required this.skipped,
    this.errors = const [],
  });

  Map<String, dynamic> toMap() => {
        'total': total,
        'inserted_or_updated': insertedOrUpdated,
        'skipped': skipped,
        'errors': errors,
      };
}

/// Universal dictionary importer supporting CSV, JSON (array) and JSONL
class DictionaryImporter {
  final DictionaryRepository repository;

  DictionaryImporter({required this.repository});

  Future<ImportReport> importFile(
    File file, {
    String? languagePair,
    String? format, // csv|json|jsonl (autodetect by extension if null)
    String delimiter = ',',
  }) async {
    final fmt = format ?? _detectFormat(file.path);
    switch (fmt) {
      case 'csv':
        return importCsv(file, languagePair: languagePair, delimiter: delimiter);
      case 'json':
        return importJsonArray(file, languagePair: languagePair);
      case 'jsonl':
        return importJsonLines(file, languagePair: languagePair);
      default:
        throw ArgumentError('Unsupported format: $fmt');
    }
  }

  String _detectFormat(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.csv')) return 'csv';
    if (lower.endsWith('.jsonl') || lower.endsWith('.ndjson')) return 'jsonl';
    if (lower.endsWith('.json')) return 'json';
    return 'csv';
  }

  Future<ImportReport> importCsv(
    File file, {
    String? languagePair,
    String delimiter = ',',
  }) async {
    final lines = await file.readAsLines();
    if (lines.isEmpty) {
      return const ImportReport(total: 0, insertedOrUpdated: 0, skipped: 0);
    }

    // Detect header
    final header = _splitLine(lines.first, delimiter);
    final hasHeader = _looksLikeHeader(header);
    int total = 0;
    int ok = 0;
    int skipped = 0;
    final errors = <String>[];

    // Determine column indices
    final idx = _ColumnIndex.fromHeader(header);

    // Process rows
    for (int i = hasHeader ? 1 : 0; i < lines.length; i++) {
      final rowLine = lines[i].trim();
      if (rowLine.isEmpty) continue;
      final cols = _splitLine(rowLine, delimiter);
      total++;
      try {
        final source = _getCol(cols, idx.sourceIdx) ?? cols[0];
        final target = _getCol(cols, idx.targetIdx) ?? ((cols.length > 1) ? cols[1] : '');
        final pair = (languagePair ?? _getCol(cols, idx.langIdx)) ?? 'en-ru';
        final pos = _getCol(cols, idx.posIdx);
        final def = _getCol(cols, idx.defIdx);
        final freqStr = _getCol(cols, idx.freqIdx);
        final freq = int.tryParse(freqStr ?? '') ?? 1;

        if (source.isEmpty || target.isEmpty) {
          skipped++;
          continue;
        }

        await repository.addTranslation(
          source,
          target,
          pair,
          partOfSpeech: pos,
          definition: def,
          frequency: freq,
        );
        ok++;
      } catch (e) {
        skipped++;
        errors.add('Line ${i + 1}: ${e.toString()}');
      }
    }

    return ImportReport(total: total, insertedOrUpdated: ok, skipped: skipped, errors: errors);
  }

  Future<ImportReport> importJsonArray(
    File file, {
    String? languagePair,
  }) async {
    final content = await file.readAsString();
    final data = jsonDecode(content);
    if (data is! List) {
      throw ArgumentError('JSON must be an array of objects');
    }
    int total = 0, ok = 0, skipped = 0;
    final errors = <String>[];
    for (int i = 0; i < data.length; i++) {
      final obj = data[i];
      total++;
      try {
        final source = (obj['source_word'] ?? obj['source'] ?? '').toString();
        final target = (obj['target_word'] ?? obj['target'] ?? '').toString();
        final pair = (languagePair ?? obj['language_pair'] ?? '').toString();
        final pos = obj['part_of_speech']?.toString();
        final def = obj['definition']?.toString();
        final freq = (obj['frequency'] is int)
            ? obj['frequency'] as int
            : int.tryParse(obj['frequency']?.toString() ?? '') ?? 1;
        if (source.isEmpty || target.isEmpty) {
          skipped++;
          continue;
        }
        final lp = pair.isEmpty ? 'en-ru' : pair;
        await repository.addTranslation(source, target, lp, partOfSpeech: pos, definition: def, frequency: freq);
        ok++;
      } catch (e) {
        skipped++;
        errors.add('Item ${i + 1}: ${e.toString()}');
      }
    }
    return ImportReport(total: total, insertedOrUpdated: ok, skipped: skipped, errors: errors);
  }

  Future<ImportReport> importJsonLines(
    File file, {
    String? languagePair,
  }) async {
    final lines = await file.readAsLines();
    int total = 0, ok = 0, skipped = 0;
    final errors = <String>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      total++;
      try {
        final obj = jsonDecode(line) as Map<String, dynamic>;
        final source = (obj['source_word'] ?? obj['source'] ?? '').toString();
        final target = (obj['target_word'] ?? obj['target'] ?? '').toString();
        final pair = (languagePair ?? obj['language_pair'] ?? '').toString();
        final pos = obj['part_of_speech']?.toString();
        final def = obj['definition']?.toString();
        final freq = (obj['frequency'] is int)
            ? obj['frequency'] as int
            : int.tryParse(obj['frequency']?.toString() ?? '') ?? 1;
        if (source.isEmpty || target.isEmpty) {
          skipped++;
          continue;
        }
        final lp = pair.isEmpty ? 'en-ru' : pair;
        await repository.addTranslation(source, target, lp, partOfSpeech: pos, definition: def, frequency: freq);
        ok++;
      } catch (e) {
        skipped++;
        errors.add('Line ${i + 1}: ${e.toString()}');
      }
    }
    return ImportReport(total: total, insertedOrUpdated: ok, skipped: skipped, errors: errors);
  }

  List<String> _splitLine(String line, String delimiter) {
    if (delimiter == '\t') return line.split('\t');
    // naive split; for advanced CSV with quotes consider using a CSV parser
    return line.split(delimiter);
  }

  bool _looksLikeHeader(List<String> header) {
    final lower = header.map((e) => e.trim().toLowerCase()).toList();
    return lower.contains('source') ||
        lower.contains('source_word') ||
        lower.contains('target') ||
        lower.contains('target_word') ||
        lower.contains('language_pair');
  }

  String? _getCol(List<String> cols, int? idx) {
    if (idx == null) return null;
    if (idx < 0 || idx >= cols.length) return null;
    return cols[idx].trim();
  }
}

class _ColumnIndex {
  final int? sourceIdx;
  final int? targetIdx;
  final int? langIdx;
  final int? posIdx;
  final int? defIdx;
  final int? freqIdx;

  _ColumnIndex({this.sourceIdx, this.targetIdx, this.langIdx, this.posIdx, this.defIdx, this.freqIdx});

  static _ColumnIndex fromHeader(List<String> header) {
    final map = <String, int>{};
    for (int i = 0; i < header.length; i++) {
      map[header[i].trim().toLowerCase()] = i;
    }
    return _ColumnIndex(
      sourceIdx: map['source_word'] ?? map['source'],
      targetIdx: map['target_word'] ?? map['target'],
      langIdx: map['language_pair'] ?? map['lang'] ?? map['pair'],
      posIdx: map['part_of_speech'] ?? map['pos'],
      defIdx: map['definition'] ?? map['def'],
      freqIdx: map['frequency'] ?? map['freq'],
    );
  }
}