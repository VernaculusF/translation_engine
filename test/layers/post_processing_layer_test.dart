import 'package:flutter_test/flutter_test.dart';
import 'package:translation_engine/src/core/translation_context.dart';
import 'package:translation_engine/src/layers/post_processing_layer.dart';

void main() {
  group('PostProcessingLayer', () {
    test('canHandle requires non-empty translatedText', () async {
      final layer = PostProcessingLayer();
      final contextEmpty = TranslationContext(sourceLanguage: 'en', targetLanguage: 'en', translatedText: '');
      final contextFilled = TranslationContext(sourceLanguage: 'en', targetLanguage: 'en', translatedText: 'Hello   world!!!');

      expect(layer.canHandle('Hello', contextEmpty), isFalse);
      expect(layer.canHandle('Hello', contextFilled), isTrue);
    });

    test('process fixes spacing and excessive punctuation', () async {
      final layer = PostProcessingLayer();
      final context = TranslationContext(sourceLanguage: 'en', targetLanguage: 'en', translatedText: 'Hello   world!!!');

      final result = await layer.process('Hello', context);

      expect(result.success, isTrue);
      expect(result.processedText.contains('  '), isFalse); // no double spaces
      expect(result.processedText.contains('!!!'), isFalse); // excessive punctuation removed
      expect(result.processedText.contains('Hello world'), isTrue);
    });
  });
}
