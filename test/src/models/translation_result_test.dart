import 'package:flutter_test/flutter_test.dart';
import 'package:fluent_translate/src/models/translation_result.dart';
import 'package:fluent_translate/src/models/layer_debug_info.dart';

void main() {
  group('TranslationResult', () {
    late DateTime testTimestamp;
    late List<LayerDebugInfo> testLayerResults;
    late CacheMetrics testCacheMetrics;

    setUp(() {
      testTimestamp = DateTime(2024, 1, 1, 12, 0, 0);
      testLayerResults = [
        LayerDebugInfo.success(
          layerName: 'TestLayer1',
          processingTimeMs: 50,
          itemsProcessed: 10,
          modificationsCount: 5,
        ),
        LayerDebugInfo.success(
          layerName: 'TestLayer2',
          processingTimeMs: 75,
          itemsProcessed: 8,
          modificationsCount: 3,
        ),
      ];
      testCacheMetrics = const CacheMetrics(
        wordCacheHits: 10,
        wordCacheMisses: 2,
        phraseCacheHits: 5,
        phraseCacheMisses: 1,
        timeSavedMs: 50,
      );
    });

    test('should create TranslationResult with basic constructor', () {
      final result = TranslationResult(
        originalText: 'Hello world',
        translatedText: 'Привет мир',
        languagePair: 'en-ru',
        confidence: 0.85,
        processingTimeMs: 200,
        layerResults: testLayerResults,
        layersProcessed: 2,
        hasError: false,
        timestamp: testTimestamp,
      );

      expect(result.originalText, equals('Hello world'));
      expect(result.translatedText, equals('Привет мир'));
      expect(result.languagePair, equals('en-ru'));
      expect(result.confidence, equals(0.85));
      expect(result.processingTimeMs, equals(200));
      expect(result.layerResults, equals(testLayerResults));
      expect(result.layersProcessed, equals(2));
      expect(result.hasError, isFalse);
      expect(result.errorMessage, isNull);
      expect(result.timestamp, equals(testTimestamp));
    });

    test('should create successful TranslationResult using factory constructor', () {
      final result = TranslationResult.success(
        originalText: 'Test text',
        translatedText: 'Тестовый текст',
        languagePair: 'en-ru',
        confidence: 0.9,
        processingTimeMs: 150,
        layerResults: testLayerResults,
        cacheMetrics: testCacheMetrics,
        qualityScore: 8.5,
        alternatives: ['Альтернатива 1', 'Альтернатива 2'],
        context: {'source': 'test'},
      );

      expect(result.originalText, equals('Test text'));
      expect(result.translatedText, equals('Тестовый текст'));
      expect(result.confidence, equals(0.9));
      expect(result.hasError, isFalse);
      expect(result.errorMessage, isNull);
      expect(result.layersProcessed, equals(2));
      expect(result.cacheMetrics, equals(testCacheMetrics));
      expect(result.qualityScore, equals(8.5));
      expect(result.alternatives, equals(['Альтернатива 1', 'Альтернатива 2']));
      expect(result.context, equals({'source': 'test'}));
    });

    test('should create error TranslationResult using factory constructor', () {
      final result = TranslationResult.error(
        originalText: 'Error text',
        languagePair: 'en-ru',
        errorMessage: 'Translation failed',
        processingTimeMs: 100,
        layerResults: testLayerResults,
        cacheMetrics: testCacheMetrics,
        context: {'error_code': '500'},
      );

      expect(result.originalText, equals('Error text'));
      expect(result.translatedText, equals('Error text')); // Returns original on error
      expect(result.hasError, isTrue);
      expect(result.errorMessage, equals('Translation failed'));
      expect(result.confidence, equals(0.0));
      expect(result.qualityScore, isNull);
      expect(result.alternatives, isEmpty);
      expect(result.layersProcessed, equals(2));
      expect(result.cacheMetrics, equals(testCacheMetrics));
      expect(result.context, equals({'error_code': '500'}));
    });

    group('computed properties', () {
      late TranslationResult successfulResult;
      late TranslationResult errorResult;

      setUp(() {
        successfulResult = TranslationResult.success(
          originalText: 'Test',
          translatedText: 'Тест',
          languagePair: 'en-ru',
          confidence: 0.8,
          processingTimeMs: 200,
          layerResults: testLayerResults,
        );

        errorResult = TranslationResult.error(
          originalText: 'Test',
          languagePair: 'en-ru',
          errorMessage: 'Error',
          processingTimeMs: 100,
        );
      });

      test('should correctly identify successful translation', () {
        expect(successfulResult.isSuccessful, isTrue);
        expect(errorResult.isSuccessful, isFalse);

        // Test edge case: zero confidence
        final zeroConfidenceResult = TranslationResult.success(
          originalText: 'Test',
          translatedText: 'Тест',
          languagePair: 'en-ru',
          confidence: 0.0,
          processingTimeMs: 100,
          layerResults: [],
        );
        expect(zeroConfidenceResult.isSuccessful, isFalse);
      });

      test('should correctly identify high quality translation', () {
        expect(successfulResult.isHighQuality, isTrue);

        final mediumQualityResult = TranslationResult.success(
          originalText: 'Test',
          translatedText: 'Тест',
          languagePair: 'en-ru',
          confidence: 0.7,
          processingTimeMs: 100,
          layerResults: [],
        );
        expect(mediumQualityResult.isHighQuality, isFalse);
      });

      test('should correctly identify low quality translation', () {
        final lowQualityResult = TranslationResult.success(
          originalText: 'Test',
          translatedText: 'Тест',
          languagePair: 'en-ru',
          confidence: 0.4,
          processingTimeMs: 100,
          layerResults: [],
        );

        expect(lowQualityResult.isLowQuality, isTrue);
        expect(successfulResult.isLowQuality, isFalse);
      });

      test('should calculate total layer processing time', () {
        expect(successfulResult.totalLayerProcessingTime, equals(125)); // 50 + 75
        expect(errorResult.totalLayerProcessingTime, equals(0));
      });

      test('should identify slowest layer', () {
        final slowestLayer = successfulResult.slowestLayer;
        expect(slowestLayer, isNotNull);
        expect(slowestLayer!.layerName, equals('TestLayer2'));
        expect(slowestLayer.processingTimeMs, equals(75));

        expect(errorResult.slowestLayer, isNull);
      });

      test('should filter layers with errors', () {
        final layersWithError = [
          LayerDebugInfo.success(layerName: 'Layer1', processingTimeMs: 50),
          LayerDebugInfo.error(layerName: 'Layer2', processingTimeMs: 25, errorMessage: 'Error'),
          LayerDebugInfo.success(layerName: 'Layer3', processingTimeMs: 30),
        ];

        final resultWithErrors = TranslationResult.success(
          originalText: 'Test',
          translatedText: 'Тест',
          languagePair: 'en-ru',
          confidence: 0.8,
          processingTimeMs: 105,
          layerResults: layersWithError,
        );

        final errorsOnly = resultWithErrors.layersWithErrors;
        expect(errorsOnly, hasLength(1));
        expect(errorsOnly.first.layerName, equals('Layer2'));
        expect(errorsOnly.first.hasError, isTrue);
      });
    });

    group('string representations', () {
      test('should generate correct summary for successful result', () {
        final result = TranslationResult.success(
          originalText: 'Test',
          translatedText: 'Тест',
          languagePair: 'en-ru',
          confidence: 0.85,
          processingTimeMs: 150,
          layerResults: [],
        );

        expect(result.summary, equals('Success: 0.85 confidence, 150ms processing'));
      });

      test('should generate correct summary for error result', () {
        final result = TranslationResult.error(
          originalText: 'Test',
          languagePair: 'en-ru',
          errorMessage: 'Translation failed',
          processingTimeMs: 100,
        );

        expect(result.summary, equals('Error: Translation failed'));
      });

      test('should generate performance report', () {
        final result = TranslationResult.success(
          originalText: 'Test',
          translatedText: 'Тест',
          languagePair: 'en-ru',
          confidence: 0.8,
          processingTimeMs: 200,
          layerResults: testLayerResults,
          cacheMetrics: testCacheMetrics,
        );

        final report = result.performanceReport;

        expect(report['total_processing_time_ms'], equals(200));
        expect(report['layer_processing_time_ms'], equals(125)); // 50 + 75
        expect(report['overhead_ms'], equals(75)); // 200 - 125
        expect(report['layers_processed'], equals(2));
        expect(report['average_layer_time_ms'], equals(62.5)); // 125 / 2
        expect(report['slowest_layer'], equals('TestLayer2'));
        expect(report['slowest_layer_time_ms'], equals(75));
        expect(report['cache_metrics'], equals(testCacheMetrics.toMap()));
      });

      test('should generate correct toString for successful result', () {
        final result = TranslationResult.success(
          originalText: 'Hello',
          translatedText: 'Привет',
          languagePair: 'en-ru',
          confidence: 0.856,
          processingTimeMs: 150,
          layerResults: [],
        );

        expect(result.toString(), equals(
          'TranslationResult.success(original: "Hello", translated: "Привет", confidence: 0.856, time: 150ms)'));
      });

      test('should generate correct toString for error result', () {
        final result = TranslationResult.error(
          originalText: 'Test',
          languagePair: 'en-ru',
          errorMessage: 'Network error',
          processingTimeMs: 50,
        );

        expect(result.toString(), equals(
          'TranslationResult.error(original: "Test", error: "Network error", time: 50ms)'));
      });
    });

    group('serialization', () {
      late TranslationResult fullResult;

      setUp(() {
        fullResult = TranslationResult.success(
          originalText: 'Test text',
          translatedText: 'Тестовый текст',
          languagePair: 'en-ru',
          confidence: 0.85,
          processingTimeMs: 200,
          layerResults: testLayerResults,
          cacheMetrics: testCacheMetrics,
          qualityScore: 8.0,
          alternatives: ['Alt 1', 'Alt 2'],
          context: {'source': 'test'},
        );
      });

      test('should serialize to Map correctly', () {
        final map = fullResult.toMap();

        expect(map['original_text'], equals('Test text'));
        expect(map['translated_text'], equals('Тестовый текст'));
        expect(map['language_pair'], equals('en-ru'));
        expect(map['confidence'], equals(0.85));
        expect(map['processing_time_ms'], equals(200));
        expect(map['layers_processed'], equals(2));
        expect(map['has_error'], isFalse);
        expect(map['error_message'], isNull);
        expect(map['quality_score'], equals(8.0));
        expect(map['alternatives'], equals(['Alt 1', 'Alt 2']));
        expect(map['context'], equals({'source': 'test'}));
        expect(map['timestamp'], equals(fullResult.timestamp.millisecondsSinceEpoch));

        // Check layer results serialization
        expect(map['layer_results'], isA<List>());
        final layerMaps = map['layer_results'] as List;
        expect(layerMaps, hasLength(2));
        expect(layerMaps[0]['layer_name'], equals('TestLayer1'));

        // Check cache metrics serialization
        expect(map['cache_metrics'], isNotNull);
        expect(map['cache_metrics']['word_cache_hits'], equals(10));
      });

      test('should deserialize from Map correctly', () {
        final originalMap = fullResult.toMap();
        final deserialized = TranslationResult.fromMap(originalMap);

        expect(deserialized.originalText, equals(fullResult.originalText));
        expect(deserialized.translatedText, equals(fullResult.translatedText));
        expect(deserialized.languagePair, equals(fullResult.languagePair));
        expect(deserialized.confidence, equals(fullResult.confidence));
        expect(deserialized.processingTimeMs, equals(fullResult.processingTimeMs));
        expect(deserialized.layersProcessed, equals(fullResult.layersProcessed));
        expect(deserialized.hasError, equals(fullResult.hasError));
        expect(deserialized.errorMessage, equals(fullResult.errorMessage));
        expect(deserialized.qualityScore, equals(fullResult.qualityScore));
        expect(deserialized.alternatives, equals(fullResult.alternatives));
        expect(deserialized.context, equals(fullResult.context));
        expect(deserialized.timestamp.millisecondsSinceEpoch, 
               equals(fullResult.timestamp.millisecondsSinceEpoch));

        // Check layer results
        expect(deserialized.layerResults, hasLength(2));
        expect(deserialized.layerResults[0].layerName, equals('TestLayer1'));
        expect(deserialized.layerResults[1].layerName, equals('TestLayer2'));

        // Check cache metrics
        expect(deserialized.cacheMetrics?.wordCacheHits, equals(10));
        expect(deserialized.cacheMetrics?.timeSavedMs, equals(50));
      });

      test('should handle null cache metrics in serialization', () {
        final result = TranslationResult.success(
          originalText: 'Test',
          translatedText: 'Тест',
          languagePair: 'en-ru',
          confidence: 0.8,
          processingTimeMs: 100,
          layerResults: [],
          cacheMetrics: null, // Explicitly null
        );

        final map = result.toMap();
        expect(map['cache_metrics'], isNull);

        final deserialized = TranslationResult.fromMap(map);
        expect(deserialized.cacheMetrics, isNull);
      });

      test('should round-trip serialize and deserialize', () {
        final map = fullResult.toMap();
        final roundTrip = TranslationResult.fromMap(map);

        // Key properties should match exactly
        expect(roundTrip.originalText, equals(fullResult.originalText));
        expect(roundTrip.translatedText, equals(fullResult.translatedText));
        expect(roundTrip.confidence, equals(fullResult.confidence));
        expect(roundTrip.hasError, equals(fullResult.hasError));
        expect(roundTrip.layersProcessed, equals(fullResult.layersProcessed));
      });
    });

    group('copyWith', () {
      late TranslationResult original;

      setUp(() {
        original = TranslationResult.success(
          originalText: 'Original text',
          translatedText: 'Оригинальный текст',
          languagePair: 'en-ru',
          confidence: 0.8,
          processingTimeMs: 150,
          layerResults: testLayerResults,
          cacheMetrics: testCacheMetrics,
        );
      });

      test('should create copy with no changes', () {
        final copy = original.copyWith();

        expect(copy.originalText, equals(original.originalText));
        expect(copy.translatedText, equals(original.translatedText));
        expect(copy.confidence, equals(original.confidence));
        expect(copy.processingTimeMs, equals(original.processingTimeMs));
        expect(copy.hasError, equals(original.hasError));
      });

      test('should create copy with single change', () {
        final copy = original.copyWith(confidence: 0.9);

        expect(copy.confidence, equals(0.9));
        expect(copy.originalText, equals(original.originalText));
        expect(copy.translatedText, equals(original.translatedText));
        expect(copy.processingTimeMs, equals(original.processingTimeMs));
      });

      test('should create copy with multiple changes', () {
        final copy = original.copyWith(
          translatedText: 'Новый перевод',
          confidence: 0.95,
          hasError: true,
          errorMessage: 'New error',
          qualityScore: 9.0,
        );

        expect(copy.translatedText, equals('Новый перевод'));
        expect(copy.confidence, equals(0.95));
        expect(copy.hasError, isTrue);
        expect(copy.errorMessage, equals('New error'));
        expect(copy.qualityScore, equals(9.0));
        expect(copy.originalText, equals(original.originalText));
        expect(copy.languagePair, equals(original.languagePair));
      });
    });

    group('equality and hashCode', () {
      test('should be equal when key properties are same', () {
        final result1 = TranslationResult.success(
          originalText: 'Test',
          translatedText: 'Тест',
          languagePair: 'en-ru',
          confidence: 0.8,
          processingTimeMs: 100,
          layerResults: [],
        );

        final result2 = TranslationResult.success(
          originalText: 'Test',
          translatedText: 'Тест',
          languagePair: 'en-ru',
          confidence: 0.8,
          processingTimeMs: 100,
          layerResults: [],
          qualityScore: 7.5, // Different but not part of equality
        );

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('should not be equal when key properties differ', () {
        final result1 = TranslationResult.success(
          originalText: 'Test',
          translatedText: 'Тест',
          languagePair: 'en-ru',
          confidence: 0.8,
          processingTimeMs: 100,
          layerResults: [],
        );

        final result2 = TranslationResult.success(
          originalText: 'Different',
          translatedText: 'Тест',
          languagePair: 'en-ru',
          confidence: 0.8,
          processingTimeMs: 100,
          layerResults: [],
        );

        final result3 = TranslationResult.error(
          originalText: 'Test',
          languagePair: 'en-ru',
          errorMessage: 'Error',
          processingTimeMs: 100,
        );

        expect(result1, isNot(equals(result2)));
        expect(result1, isNot(equals(result3)));
        expect(result1.hashCode, isNot(equals(result2.hashCode)));
        expect(result1.hashCode, isNot(equals(result3.hashCode)));
      });

      test('should handle self-equality', () {
        final result = TranslationResult.success(
          originalText: 'Test',
          translatedText: 'Тест',
          languagePair: 'en-ru',
          confidence: 0.8,
          processingTimeMs: 100,
          layerResults: [],
        );

        expect(result, equals(result));
        expect(result == result, isTrue);
      });
    });
  });

  group('CacheMetrics', () {
    test('should create CacheMetrics with all properties', () {
      const metrics = CacheMetrics(
        wordCacheHits: 10,
        wordCacheMisses: 2,
        phraseCacheHits: 5,
        phraseCacheMisses: 1,
        timeSavedMs: 50,
      );

      expect(metrics.wordCacheHits, equals(10));
      expect(metrics.wordCacheMisses, equals(2));
      expect(metrics.phraseCacheHits, equals(5));
      expect(metrics.phraseCacheMisses, equals(1));
      expect(metrics.timeSavedMs, equals(50));
    });

    test('should calculate hit rates correctly', () {
      const metrics = CacheMetrics(
        wordCacheHits: 8,
        wordCacheMisses: 2,
        phraseCacheHits: 3,
        phraseCacheMisses: 1,
        timeSavedMs: 40,
      );

      expect(metrics.hitRate, equals(11.0 / 14.0)); // (8+3)/(8+2+3+1)
      expect(metrics.wordHitRate, equals(0.8)); // 8/(8+2)
      expect(metrics.phraseHitRate, equals(0.75)); // 3/(3+1)
    });

    test('should handle zero requests in hit rate calculations', () {
      const metrics = CacheMetrics(
        wordCacheHits: 0,
        wordCacheMisses: 0,
        phraseCacheHits: 0,
        phraseCacheMisses: 0,
        timeSavedMs: 0,
      );

      expect(metrics.hitRate, equals(0.0));
      expect(metrics.wordHitRate, equals(0.0));
      expect(metrics.phraseHitRate, equals(0.0));
    });

    test('should serialize and deserialize correctly', () {
      const original = CacheMetrics(
        wordCacheHits: 15,
        wordCacheMisses: 3,
        phraseCacheHits: 8,
        phraseCacheMisses: 2,
        timeSavedMs: 120,
      );

      final map = original.toMap();
      final deserialized = CacheMetrics.fromMap(map);

      expect(deserialized.wordCacheHits, equals(original.wordCacheHits));
      expect(deserialized.wordCacheMisses, equals(original.wordCacheMisses));
      expect(deserialized.phraseCacheHits, equals(original.phraseCacheHits));
      expect(deserialized.phraseCacheMisses, equals(original.phraseCacheMisses));
      expect(deserialized.timeSavedMs, equals(original.timeSavedMs));
    });

    test('should include computed properties in toMap', () {
      const metrics = CacheMetrics(
        wordCacheHits: 9,
        wordCacheMisses: 1,
        phraseCacheHits: 4,
        phraseCacheMisses: 1,
        timeSavedMs: 60,
      );

      final map = metrics.toMap();

      expect(map['hit_rate'], equals(13.0 / 15.0));
      expect(map['word_hit_rate'], equals(0.9));
      expect(map['phrase_hit_rate'], equals(0.8));
    });

    test('should generate correct toString', () {
      const metrics = CacheMetrics(
        wordCacheHits: 18,
        wordCacheMisses: 2,
        phraseCacheHits: 7,
        phraseCacheMisses: 1,
        timeSavedMs: 80,
      );

      // Hit rate = (18+7)/(18+2+7+1) = 25/28 ≈ 0.893 ≈ 89.3%
      expect(metrics.toString(), equals('CacheMetrics(hitRate: 89.3%, timeSaved: 80ms)'));
    });
  });
}