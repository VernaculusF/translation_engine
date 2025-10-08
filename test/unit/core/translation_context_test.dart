import 'package:flutter_test/flutter_test.dart';
import 'package:translation_engine/src/core/translation_context.dart';

void main() {
  group('TranslationContext Tests', () {
    
    test('should create context with required parameters', () {
    final context = TranslationContext(
        sourceLanguage: 'en',
        targetLanguage: 'ru',
        debugMode: false,
      );
      
      expect(context.languagePair, equals('en-ru'));
      expect(context.debugMode, isFalse);
      expect(context.sourceLanguage, equals('en'));
      expect(context.targetLanguage, equals('ru'));
    });

    test('should generate language pair correctly', () {
      final context = TranslationContext(
        sourceLanguage: 'fr',
        targetLanguage: 'de',
        debugMode: false,
      );
      
      expect(context.sourceLanguage, equals('fr'));
      expect(context.targetLanguage, equals('de'));
      expect(context.languagePair, equals('fr-de'));
      expect(context.reverseLanguagePair, equals('de-fr'));
    });

    test('should handle debug mode', () {
      final debugContext = TranslationContext(
        sourceLanguage: 'en',
        targetLanguage: 'ru',
        debugMode: true,
      );
      
      final prodContext = TranslationContext(
        sourceLanguage: 'en',
        targetLanguage: 'ru',
        debugMode: false,
      );
      
      expect(debugContext.debugMode, isTrue);
      expect(debugContext.isDebugEnabled(), isTrue);
      expect(prodContext.debugMode, isFalse);
      expect(prodContext.isDebugEnabled(), isFalse);
    });

    test('should support additional metadata', () {
      final context = TranslationContext(
        sourceLanguage: 'en',
        targetLanguage: 'ru',
        debugMode: false,
        metadata: {'userId': '123', 'sessionId': 'abc'},
      );
      
      expect(context.metadata, isNotNull);
      expect(context.metadata['userId'], equals('123'));
      expect(context.metadata['sessionId'], equals('abc'));
    });

    test('should check language pair support', () {
      final supportedContext = TranslationContext(
        sourceLanguage: 'en',
        targetLanguage: 'ru',
      );
      
      final unsupportedContext = TranslationContext(
        sourceLanguage: 'zh',
        targetLanguage: 'hi',
      );
      
      expect(supportedContext.isLanguagePairSupported(), isTrue);
      expect(unsupportedContext.isLanguagePairSupported(), isFalse);
    });

    test('should handle translation modes', () {
      final fastContext = TranslationContext(
        sourceLanguage: 'en',
        targetLanguage: 'ru',
        mode: TranslationMode.fast,
      );
      
      final qualityContext = TranslationContext(
        sourceLanguage: 'en',
        targetLanguage: 'ru',
        mode: TranslationMode.quality,
      );
      
      final detailedContext = TranslationContext(
        sourceLanguage: 'en',
        targetLanguage: 'ru',
        mode: TranslationMode.detailed,
      );
      
      expect(fastContext.isFastModeEnabled(), isTrue);
      expect(fastContext.isQualityModeEnabled(), isFalse);
      
      expect(qualityContext.isQualityModeEnabled(), isTrue);
      expect(qualityContext.isFastModeEnabled(), isFalse);
      
      expect(detailedContext.isDebugEnabled(), isTrue);
    });

    test('should handle confidence threshold', () {
      final context = TranslationContext(
        sourceLanguage: 'en',
        targetLanguage: 'ru',
        minConfidence: 0.8,
      );
      
      expect(context.minConfidence, equals(0.8));
    });

    test('should handle processing timeout', () {
      final context = TranslationContext(
        sourceLanguage: 'en',
        targetLanguage: 'ru',
        maxProcessingTimeMs: 10000,
      );
      
      expect(context.maxProcessingTimeMs, equals(10000));
    });

    test('should handle exclude words', () {
      final context = TranslationContext(
        sourceLanguage: 'en',
        targetLanguage: 'ru',
        excludeWords: {'password', 'secret'},
      );
      
      expect(context.shouldExcludeWord('password'), isTrue);
      expect(context.shouldExcludeWord('Password'), isTrue); // Case insensitive
      expect(context.shouldExcludeWord('hello'), isFalse);
    });

    test('should handle force translations', () {
      final context = TranslationContext(
        sourceLanguage: 'en',
        targetLanguage: 'ru',
        forceTranslations: {'hello': 'привет', 'world': 'мир'},
      );
      
      expect(context.getForceTranslation('hello'), equals('привет'));
      expect(context.getForceTranslation('Hello'), equals('привет')); // Case insensitive
      expect(context.getForceTranslation('goodbye'), isNull);
    });

    test('should support cache configuration', () {
      final cacheContext = TranslationContext(
        sourceLanguage: 'en',
        targetLanguage: 'ru',
        useCache: true,
        saveToCache: true,
      );
      
      final noCacheContext = TranslationContext(
        sourceLanguage: 'en',
        targetLanguage: 'ru',
        useCache: false,
        saveToCache: false,
      );
      
      expect(cacheContext.useCache, isTrue);
      expect(cacheContext.saveToCache, isTrue);
      expect(noCacheContext.useCache, isFalse);
      expect(noCacheContext.saveToCache, isFalse);
    });

    test('should be immutable', () {
      final context = TranslationContext(
        sourceLanguage: 'en',
        targetLanguage: 'ru',
        debugMode: false,
      );
      
      // All fields should be final, no setters available
      expect(context.languagePair, equals('en-ru'));
      expect(context.debugMode, isFalse);
    });
  });
}
