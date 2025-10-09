import 'package:flutter_test/flutter_test.dart';
import 'package:translation_engine/src/core/translation_context.dart';
import 'package:translation_engine/src/layers/pre_processing_layer.dart';

void main() {
  group('PreProcessingLayer', () {
    test('canHandle returns true for non-empty text', () async {
      final layer = PreProcessingLayer();
      final context = TranslationContext(sourceLanguage: 'en', targetLanguage: 'en');

      expect(layer.canHandle('Hello', context), isTrue);
      expect(layer.canHandle('   ', context), isFalse);
    });

    test('process tokenizes and stores tokens in metadata', () async {
      final layer = PreProcessingLayer();
      final context = TranslationContext(sourceLanguage: 'en', targetLanguage: 'en');

      final result = await layer.process('Hello,   world!  ', context);

      expect(result.success, isTrue);
      expect(result.processedText.isNotEmpty, isTrue);

      final tokens = context.getMetadata<List<TextToken>>('preprocessing_tokens');
      expect(tokens, isNotNull);
      expect(tokens!.isNotEmpty, isTrue);

      // Ensure there are no triple spaces in the processed text
      expect(result.processedText.contains('   '), isFalse);
    });
  });
}
