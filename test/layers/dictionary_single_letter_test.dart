// ignore_for_file: avoid_print

import 'dart:io';
import 'package:test/test.dart';
import 'package:fluent_translate/fluent_translate.dart';

void main() {
  group('Dictionary single-letter fallback', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('dict_single_letter_');
      dbPath = tempDir.path;
      final enRu = Directory('$dbPath/en-ru')..createSync(recursive: true);
      final now = DateTime.now().millisecondsSinceEpoch;
      // Minimal dictionary without entries for 'i', 'a', 'c'
      final dict = File('${enRu.path}/dictionary.jsonl');
      final entries = [
        {
          'source_word': 'family',
          'target_word': 'семья',
          'language_pair': 'en-ru',
          'part_of_speech': 'noun',
          'frequency': 90,
          'created_at': now,
          'updated_at': now,
        },
        {
          'source_word': 'come',
          'target_word': 'приходить',
          'language_pair': 'en-ru',
          'part_of_speech': 'verb',
          'frequency': 88,
          'created_at': now,
          'updated_at': now,
        },
      ];
      await dict.writeAsString(entries.map(_j).join('\n'));
      // Empty phrases
      File('${enRu.path}/phrases.jsonl').writeAsStringSync('');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('i stays i (no partial match)', () async {
      final engine = TranslationEngine();
      await engine.initialize(customDatabasePath: dbPath);
      final res = await engine.translate('i', sourceLanguage: 'en', targetLanguage: 'ru');
      expect(res.translatedText, 'i');
      await engine.dispose();
    });

    test('a stays a (no partial match)', () async {
      final engine = TranslationEngine();
      await engine.initialize(customDatabasePath: dbPath);
      final res = await engine.translate('a', sourceLanguage: 'en', targetLanguage: 'ru');
      expect(res.translatedText, 'a');
      await engine.dispose();
    });

    test('c stays c (no partial match)', () async {
      final engine = TranslationEngine();
      await engine.initialize(customDatabasePath: dbPath);
      final res = await engine.translate('c', sourceLanguage: 'en', targetLanguage: 'ru');
      expect(res.translatedText, 'c');
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
