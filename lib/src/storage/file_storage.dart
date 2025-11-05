library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class FileStorageService {
  final String rootDir; // e.g., ./translation_data

  FileStorageService({required this.rootDir});

  bool get rootExists => Directory(rootDir).existsSync();

  Directory langDir(String languagePair) => Directory(_p(rootDir, languagePair));

  File dictFile(String languagePair) => File(_p(rootDir, languagePair, 'dictionary.jsonl'));
  File phrasesFile(String languagePair) => File(_p(rootDir, languagePair, 'phrases.jsonl'));
  File grammarRulesFile(String languagePair) => File(_p(rootDir, languagePair, 'grammar_rules.jsonl'));
  File wordOrderRulesFile(String languagePair) => File(_p(rootDir, languagePair, 'word_order_rules.jsonl'));
  File postProcessingRulesFile(String languagePair) => File(_p(rootDir, languagePair, 'post_processing_rules.jsonl'));

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

  // Read JSONL lazily as stream of Map (UTF-8 only)
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

  // Read whole text with BOM/encoding detection (UTF-8/UTF-16 LE/BE)
  String readAllTextDetectingEncoding(File file) {
    if (!file.existsSync()) return '';
    final raf = file.openSync(mode: FileMode.read);
    try {
      final headerLen = (raf.lengthSync() >= 4) ? 4 : raf.lengthSync();
      final header = raf.readSync(headerLen);
      // Detect BOMs
      bool isUtf8Bom = header.length >= 3 && header[0] == 0xEF && header[1] == 0xBB && header[2] == 0xBF;
      bool isUtf16LeBom = header.length >= 2 && header[0] == 0xFF && header[1] == 0xFE;
      bool isUtf16BeBom = header.length >= 2 && header[0] == 0xFE && header[1] == 0xFF;

      // Read remaining bytes
      raf.setPositionSync(0);
      final bytes = raf.readSync(raf.lengthSync());

      if (isUtf8Bom) {
        return utf8.decode(bytes.sublist(3), allowMalformed: true);
      }
      if (isUtf16LeBom) {
        return _decodeUtf16(bytes.sublist(2), Endian.little);
      }
      if (isUtf16BeBom) {
        return _decodeUtf16(bytes.sublist(2), Endian.big);
      }

      // No BOM: try to guess UTF-16 (presence of many 0x00 bytes)
      int zeroCount = 0;
      for (int i = 0; i < bytes.length && i < 2000; i++) {
        if (bytes[i] == 0x00) zeroCount++;
      }
      if (zeroCount > 200) {
        // Likely UTF-16 without BOM; assume little-endian (Windows default)
        return _decodeUtf16(bytes, Endian.little);
      }

      // Fallback UTF-8
      return utf8.decode(bytes, allowMalformed: true);
    } finally {
      raf.closeSync();
    }
  }

  String _decodeUtf16(List<int> bytes, Endian endian) {
    final bd = ByteData.sublistView(Uint8List.fromList(bytes));
    final units = <int>[];
    for (int i = 0; i + 1 < bd.lengthInBytes; i += 2) {
      final unit = bd.getUint16(i, endian);
      units.add(unit);
    }
    return String.fromCharCodes(units);
  }

  // Acquire a simple file lock using an adjacent .lock file (best-effort)
  Future<T> _withFileLock<T>(File target, Future<T> Function() action) async {
    final lockPath = '${target.path}.lock';
    final lockFile = File(lockPath);
    try {
      // Try to create lock exclusively; if exists, wait shortly and retry
      int attempts = 0;
      while (true) {
        try {
          lockFile.createSync(exclusive: true);
          break;
        } catch (_) {
          if (attempts++ > 50) {
            // Give up after ~5s
            break;
          }
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      return await action();
    } finally {
      try { if (lockFile.existsSync()) lockFile.deleteSync(); } catch (_) {}
    }
  }

  // Rewrite entire JSONL file from iterable of Map atomically (tmp + rename)
  Future<void> rewriteJsonLines(File file, Iterable<Map<String, dynamic>> items) async {
    if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
    final tmp = File('${file.path}.tmp');
    await _withFileLock(file, () async {
      IOSink? sink;
      try {
        sink = tmp.openWrite(mode: FileMode.write);
        for (final m in items) {
          sink.writeln(jsonEncode(m));
        }
        await sink.flush();
      } finally {
        await sink?.close();
      }
      // Replace original atomically where possible
      if (file.existsSync()) {
        try { file.deleteSync(); } catch (_) {}
      }
      tmp.renameSync(file.path);
    });
  }

  // Append single JSON object as a JSONL line (with best-effort lock)
  Future<void> appendJsonLine(File file, Map<String, dynamic> item) async {
    if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
    await _withFileLock(file, () async {
      final sink = file.openWrite(mode: FileMode.append);
      try {
        sink.writeln(jsonEncode(item));
      } finally {
        await sink.flush();
        await sink.close();
      }
    });
  }
}

String _p(String a, [String? b, String? c]) {
  if (b == null) return a;
  if (c == null) return a + Platform.pathSeparator + b;
  return a + Platform.pathSeparator + b + Platform.pathSeparator + c;
}
