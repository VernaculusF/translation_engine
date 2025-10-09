import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:translation_engine/src/core/translation_engine.dart';
import 'package:translation_engine/src/core/translation_context.dart';

void main() {
  group('Pipeline E2E', () {
    late Directory tempDir;
    late TranslationEngine engine;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('translation_engine_e2e_');
      engine = TranslationEngine.instance(reset: true);
      await engine.initialize(customDatabasePath: tempDir.path);
    });

    tearDown(() async {
      await engine.dispose();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should process text through all layers and return TranslationResult', () async {
      final result = await engine.translate(
        'Good morning, world!!!',
        sourceLanguage: 'en',
        targetLanguage: 'en',
        context: TranslationContext(
          sourceLanguage: 'en',
          targetLanguage: 'en',
          debugMode: true,
        ),
      );

      expect(result.hasError, isFalse);
      expect(result.translatedText.isNotEmpty, isTrue);
      expect(result.layerResults.isNotEmpty, isTrue);
      expect(result.processingTimeMs, greaterThanOrEqualTo(0));
      expect(result.languagePair, equals('en-en'));
    });
  });
}
