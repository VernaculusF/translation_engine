library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class FileStorageService {
  final String rootDir; // e.g., ./translation_data

  FileStorageService({required this.rootDir});

  Directory langDir(String languagePair) => Directory(_p(rootDir, languagePair));

  File dictFile(String languagePair) => File(_p(rootDir, languagePair, 'dictionary.jsonl'));
  File phrasesFile(String languagePair) => File(_p(rootDir, languagePair, 'phrases.jsonl'));

  File userHistoryFile() => File(_p(rootDir, 'user', 'translation_history.jsonl'));
  File userSettingsFile() => File(_p(rootDir, 'user', 'user_settings.json'));
  File userEditsFile() => File(_p(rootDir, 'user', 'user_translation_edits.jsonl'));

  Future<void> ensureLangDir(String languagePair) async {
    final d = langDir(languagePair);
    if (!d.existsSync()) {
      d.createSync(recursive: true);
    }
  }

  Future<void> ensureUserDir() async {
    final d = Directory(_p(rootDir, 'user'));
    if (!d.existsSync()) d.createSync(recursive: true);
  }

  // Read JSONL lazily as stream of Map
  Stream<Map<String, dynamic>> readJsonLines(File file) async* {
    if (!file.existsSync()) return;
    final stream = file.openRead();
    await for (final chunk in stream.transform(utf8.decoder).transform(const LineSplitter())) {
      final line = chunk.trim();
      if (line.isEmpty) continue;
      try {
        final obj = jsonDecode(line);
        if (obj is Map<String, dynamic>) yield obj;
      } catch (_) {
        // skip broken line
      }
    }
  }

  // Rewrite entire JSONL file from iterable of Map
  Future<void> rewriteJsonLines(File file, Iterable<Map<String, dynamic>> items) async {
    if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
    final sink = file.openWrite(mode: FileMode.write);
    try {
      for (final m in items) {
        sink.writeln(jsonEncode(m));
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  // Append single JSON object as a JSONL line
  Future<void> appendJsonLine(File file, Map<String, dynamic> item) async {
    if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
    final sink = file.openWrite(mode: FileMode.append);
    try {
      sink.writeln(jsonEncode(item));
    } finally {
      await sink.flush();
      await sink.close();
    }
  }
}

String _p(String a, [String? b, String? c]) {
  if (b == null) return a;
  if (c == null) return a + Platform.pathSeparator + b;
  return a + Platform.pathSeparator + b + Platform.pathSeparator + c;
}