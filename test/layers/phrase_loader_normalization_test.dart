// ignore_for_file: avoid_print

import 'dart:io';
import 'package:test/test.dart';
import 'package:fluent_translate/fluent_translate.dart';

void main() {
  group('Phrase loader normalization', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('phrase_norm_');
      dbPath = tempDir.path;
      final enRu = Directory('$dbPath/en-ru')..createSync(recursive: true);
      final now = DateTime.now().millisecondsSinceEpoch;
      final phr = File('${enRu.path}/phrases.jsonl');
      final lines = [
        // capitalized
        {
          'source_phrase': 'How are you',
          'target_phrase': 'как дела',
          'language_pair': 'en-ru',
          'confidence': 95,
          'frequency': 100,
          'created_at': now,
          'updated_at': now,
        },
        // quoted
        {
          'source_phrase': '"Good night"',
          'target_phrase': 'спокойной ночи',
          'language_pair': 'en-ru',
          'confidence': 95,
          'frequency': 100,
          'created_at': now,
          'updated_at': now,
        },
      ];
      await phr.writeAsString(lines.map(_j).join('\n'));
      File('${enRu.path}/dictionary.jsonl').writeAsStringSync('');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('how are you (lowercase input) matches capitalized source', () async {
      final engine = TranslationEngine();
      await engine.initialize(customDatabasePath: dbPath);
      final res = await engine.translate('how   are  you', sourceLanguage: 'en', targetLanguage: 'ru');
      expect(res.translatedText.toLowerCase(), contains('как дела'));
      await engine.dispose();
    });

    test('good night (no quotes in input) matches quoted source', () async {
      final engine = TranslationEngine();
      await engine.initialize(customDatabasePath: dbPath);
      final res = await engine.translate('good night', sourceLanguage: 'en', targetLanguage: 'ru');
      expect(res.translatedText.toLowerCase(), contains('спокойной ночи'));
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
