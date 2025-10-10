import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluent_translate/src/core/translation_engine.dart';
import 'package:fluent_translate/src/core/translation_context.dart';

void main() {
  group('Performance Benchmarks', () {
    late Directory tempDir;
    late TranslationEngine engine;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('translation_engine_bench_');
      engine = TranslationEngine.instance(reset: true);
      await engine.initialize(customDatabasePath: tempDir.path);
    });

    tearDown(() async {
      await engine.dispose();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('pipeline processes 100 short texts under 10 seconds total', () async {
      const runs = 100;
      final sw = Stopwatch()..start();
      for (int i = 0; i < runs; i++) {
        final text = 'Sample text #$i with punctuation!!!  And  spaces.';
        final result = await engine.translate(
          text,
          sourceLanguage: 'en',
          targetLanguage: 'en',
          context: TranslationContext(
            sourceLanguage: 'en',
            targetLanguage: 'en',
          ),
        );
        expect(result.hasError, isFalse);
      }
      sw.stop();

      // Keep generous threshold to avoid flakiness in CI
      expect(sw.elapsed.inMilliseconds, lessThan(10000));
    });
  });
}
