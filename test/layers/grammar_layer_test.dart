import 'package:flutter_test/flutter_test.dart';
import 'package:translation_engine/src/core/translation_context.dart';
import 'package:translation_engine/src/layers/grammar_layer.dart';

void main() {
  group('GrammarLayer', () {
    test('canHandle requires tokens', () async {
      final layer = GrammarLayer();
      final contextNoTokens = TranslationContext(sourceLanguage: 'en', targetLanguage: 'en');
      final contextWithTokens = TranslationContext(sourceLanguage: 'en', targetLanguage: 'es', tokens: ['I','am','happy']);

      expect(layer.canHandle('I am happy', contextNoTokens), isFalse);
      expect(layer.canHandle('I am happy', contextWithTokens), isTrue);
    });

    test('process returns success and may update translatedText', () async {
      final layer = GrammarLayer();
      final context = TranslationContext(sourceLanguage: 'en', targetLanguage: 'es', tokens: ['I','am','happy']);

      final result = await layer.process('I am happy', context);

      expect(result.success, isTrue);
      expect(result.processedText.isNotEmpty, isTrue);
      // After processing, translatedText may be updated if changes happened
      // We just verify there is no crash and output is present
    });
  });
}
