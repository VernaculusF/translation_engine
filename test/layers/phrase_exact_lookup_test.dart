// ignore_for_file: avoid_print

import 'dart:io';
import 'package:test/test.dart';
import 'package:fluent_translate/fluent_translate.dart';

void main() {
  group('Phrase exact lookup', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('phrase_exact_');
      dbPath = tempDir.path;
      final enRu = Directory('$dbPath/en-ru')..createSync(recursive: true);
      final now = DateTime.now().millisecondsSinceEpoch;
      // Minimal phrases with good morning
      final phr = File('${enRu.path}/phrases.jsonl');
      final phrases = [
        {
          'source_phrase': 'good morning',
          'target_phrase': 'доброе утро',
          'language_pair': 'en-ru',
          'category': 'greetings',
          'context': 'formal',
          'confidence': 95,
          'frequency': 50,
          'created_at': now,
          'updated_at': now,
        }
      ];
      await phr.writeAsString(phrases.map(_j).join('\n'));
      // Empty dictionary so only phrase layer applies
      File('${enRu.path}/dictionary.jsonl').writeAsStringSync('');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('good morning -> доброе утро (phrase exact)', () async {
      final engine = TranslationEngine();
      await engine.initialize(customDatabasePath: dbPath);
      final res = await engine.translate('Good   morning', sourceLanguage: 'en', targetLanguage: 'ru');
      expect(res.errorMessage ?? '', '');
      expect(res.translatedText.toLowerCase(), contains('доброе утро'));
      await engine.dispose();
    });
  });
}

String _j(Map<String, Object?> m) => '{${m.entries.map((e) => '"${e.key}":${_v(e.value)}').join(',')}}';
String _v(Object? v) {
  if (v == null) return 'null';
  if (v is num || v is bool) return v.toString();
  final s = v.toString().replaceAll('"', '\\"');
  return '"$s"';
}
