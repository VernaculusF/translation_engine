import 'package:flutter_test/flutter_test.dart';
import 'package:fluent_translate/src/core/translation_engine.dart';

void main() {
  group('TranslationEngine Tests', () {
    late TranslationEngine engine;

    setUp(() {
      // Reset singleton for testing
      engine = TranslationEngine.instance(reset: true);
    });

    tearDown(() async {
      if (engine.isInitialized) {
        await engine.dispose();
      }
    });

    test('should create singleton instance', () {
      final engine1 = TranslationEngine();
      final engine2 = TranslationEngine();
      
      expect(engine1, same(engine2));
    });

    test('should start in uninitialized state', () {
      expect(engine.state, equals(EngineState.uninitialized));
      expect(engine.isReady, isFalse);
      expect(engine.isInitialized, isFalse);
    });

    test('should initialize successfully', () async {
      expect(engine.state, equals(EngineState.uninitialized));
      
      await engine.initialize();
      
      expect(engine.state, equals(EngineState.ready));
      expect(engine.isReady, isTrue);
      expect(engine.isInitialized, isTrue);
    });

    test('should provide statistics', () {
      final stats = engine.statistics;
      
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats['translations_count'], equals(0));
      expect(stats['state'], isNotNull);
    });

    test('should not initialize twice', () async {
      await engine.initialize();
      expect(engine.state, equals(EngineState.ready));
      
      // Second initialization should not throw and remain ready
      await engine.initialize();
      expect(engine.state, equals(EngineState.ready));
    });

    test('should handle dispose properly', () async {
      await engine.initialize();
      expect(engine.isReady, isTrue);
      
      await engine.dispose();
      expect(engine.state, equals(EngineState.disposed));
      expect(engine.isReady, isFalse);
    });

    test('should have state stream', () {
      expect(engine.stateStream, isA<Stream<EngineState>>());
    });

    test('should have error stream', () {
      expect(engine.errorStream, isA<Stream<Exception>>());
    });

    test('should track last error', () {
      expect(engine.lastError, isNull);
    });

    test('should prevent operations after dispose', () async {
      await engine.initialize();
      await engine.dispose();
      
      expect(engine.state, equals(EngineState.disposed));
      
      // Should throw when trying to translate after dispose
      expect(
        () => engine.translate('test', sourceLanguage: 'en', targetLanguage: 'ru'),
        throwsA(isA<Exception>()),
      );
    });
  });
}