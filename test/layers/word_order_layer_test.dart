import 'package:flutter_test/flutter_test.dart';
import 'package:translation_engine/src/core/translation_context.dart';
import 'package:translation_engine/src/layers/word_order_layer.dart';

void main() {
  group('WordOrderLayer', () {
    test('canHandle requires tokens and translatedText', () async {
      final layer = WordOrderLayer();
      final contextNoTokens = TranslationContext(sourceLanguage: 'en', targetLanguage: 'ja', translatedText: 'I eat apples.');
      final contextWithTokens = TranslationContext(sourceLanguage: 'en', targetLanguage: 'ja', tokens: ['I','eat','apples'], translatedText: 'I eat apples.');

      expect(layer.canHandle('I eat apples.', contextNoTokens), isFalse);
      expect(layer.canHandle('I eat apples.', contextWithTokens), isTrue);
    });

    test('process reorders or returns success without crash', () async {
      final layer = WordOrderLayer();
      final context = TranslationContext(sourceLanguage: 'en', targetLanguage: 'ja', tokens: ['I','eat','apples'], translatedText: 'I eat apples.');

      final result = await layer.process('I eat apples.', context);

      expect(result.success, isTrue);
      expect(result.processedText.isNotEmpty, isTrue);
    });
  });
}
