import 'package:flutter_test/flutter_test.dart';
import 'package:translation_engine/src/models/layer_debug_info.dart';

void main() {
  group('LayerDebugInfo', () {
    test('should create LayerDebugInfo with basic constructor', () {
      final debugInfo = LayerDebugInfo(
        layerName: 'TestLayer',
        processingTimeMs: 100,
      );

      expect(debugInfo.layerName, equals('TestLayer'));
      expect(debugInfo.processingTimeMs, equals(100));
      expect(debugInfo.isSuccessful, isTrue);
      expect(debugInfo.hasError, isFalse);
      expect(debugInfo.errorMessage, isNull);
      expect(debugInfo.itemsProcessed, equals(0));
      expect(debugInfo.modificationsCount, equals(0));
      expect(debugInfo.impactLevel, equals(0.0));
    });

    test('should create LayerDebugInfo with all parameters', () {
      final debugData = {'param1': 'value1', 'param2': 42};
      final warnings = ['Warning 1', 'Warning 2'];
      final layerConfig = {'config1': true, 'config2': 'test'};

      final debugInfo = LayerDebugInfo(
        layerName: 'ComplexLayer',
        processingTimeMs: 250,
        isSuccessful: true,
        hasError: false,
        errorMessage: null,
        itemsProcessed: 15,
        modificationsCount: 8,
        impactLevel: 0.6,
        cacheHits: 12,
        cacheMisses: 3,
        debugData: debugData,
        warnings: warnings,
        layerConfig: layerConfig,
      );

      expect(debugInfo.layerName, equals('ComplexLayer'));
      expect(debugInfo.processingTimeMs, equals(250));
      expect(debugInfo.isSuccessful, isTrue);
      expect(debugInfo.hasError, isFalse);
      expect(debugInfo.itemsProcessed, equals(15));
      expect(debugInfo.modificationsCount, equals(8));
      expect(debugInfo.impactLevel, equals(0.6));
      expect(debugInfo.cacheHits, equals(12));
      expect(debugInfo.cacheMisses, equals(3));
      expect(debugInfo.debugData, equals(debugData));
      expect(debugInfo.warnings, equals(warnings));
      expect(debugInfo.layerConfig, equals(layerConfig));
    });

    test('should create successful LayerDebugInfo using factory constructor', () {
      final debugInfo = LayerDebugInfo.success(
        layerName: 'SuccessfulLayer',
        processingTimeMs: 150,
        itemsProcessed: 20,
        modificationsCount: 5,
        impactLevel: 0.8,
        cacheHits: 18,
        cacheMisses: 2,
      );

      expect(debugInfo.layerName, equals('SuccessfulLayer'));
      expect(debugInfo.processingTimeMs, equals(150));
      expect(debugInfo.isSuccessful, isTrue);
      expect(debugInfo.hasError, isFalse);
      expect(debugInfo.errorMessage, isNull);
      expect(debugInfo.itemsProcessed, equals(20));
      expect(debugInfo.modificationsCount, equals(5));
      expect(debugInfo.impactLevel, equals(0.8));
      expect(debugInfo.cacheHits, equals(18));
      expect(debugInfo.cacheMisses, equals(2));
    });

    test('should create error LayerDebugInfo using factory constructor', () {
      final debugInfo = LayerDebugInfo.error(
        layerName: 'ErrorLayer',
        processingTimeMs: 75,
        errorMessage: 'Processing failed',
        itemsProcessed: 5,
        modificationsCount: 0,
      );

      expect(debugInfo.layerName, equals('ErrorLayer'));
      expect(debugInfo.processingTimeMs, equals(75));
      expect(debugInfo.isSuccessful, isFalse);
      expect(debugInfo.hasError, isTrue);
      expect(debugInfo.errorMessage, equals('Processing failed'));
      expect(debugInfo.itemsProcessed, equals(5));
      expect(debugInfo.modificationsCount, equals(0));
      expect(debugInfo.impactLevel, equals(0.0));
      expect(debugInfo.cacheHits, equals(0));
      expect(debugInfo.cacheMisses, equals(0));
    });

    group('computed properties', () {
      test('should calculate cache hit rate correctly', () {
        final debugInfo = LayerDebugInfo(
          layerName: 'TestLayer',
          processingTimeMs: 100,
          cacheHits: 8,
          cacheMisses: 2,
        );

        expect(debugInfo.cacheHitRate, equals(0.8));
      });

      test('should return 0 cache hit rate when no cache requests', () {
        final debugInfo = LayerDebugInfo(
          layerName: 'TestLayer',
          processingTimeMs: 100,
        );

        expect(debugInfo.cacheHitRate, equals(0.0));
      });

      test('should calculate processing rate correctly', () {
        final debugInfo = LayerDebugInfo(
          layerName: 'TestLayer',
          processingTimeMs: 100,
          itemsProcessed: 10,
        );

        // 10 items in 100ms = 100 items per second
        expect(debugInfo.processingRate, equals(100.0));
      });

      test('should return 0 processing rate when no time', () {
        final debugInfo = LayerDebugInfo(
          layerName: 'TestLayer',
          processingTimeMs: 0,
          itemsProcessed: 10,
        );

        expect(debugInfo.processingRate, equals(0.0));
      });

      test('should calculate modification rate correctly', () {
        final debugInfo = LayerDebugInfo(
          layerName: 'TestLayer',
          processingTimeMs: 100,
          itemsProcessed: 20,
          modificationsCount: 8,
        );

        expect(debugInfo.modificationRate, equals(0.4));
      });

      test('should return 0 modification rate when no items processed', () {
        final debugInfo = LayerDebugInfo(
          layerName: 'TestLayer',
          processingTimeMs: 100,
          itemsProcessed: 0,
          modificationsCount: 5,
        );

        expect(debugInfo.modificationRate, equals(0.0));
      });

      test('should detect warnings correctly', () {
        final debugInfoWithWarnings = LayerDebugInfo(
          layerName: 'TestLayer',
          processingTimeMs: 100,
          warnings: ['Warning 1', 'Warning 2'],
        );

        final debugInfoWithoutWarnings = LayerDebugInfo(
          layerName: 'TestLayer',
          processingTimeMs: 100,
        );

        expect(debugInfoWithWarnings.hasWarnings, isTrue);
        expect(debugInfoWithoutWarnings.hasWarnings, isFalse);
      });
    });

    group('serialization', () {
      test('should serialize to Map correctly', () {
        final debugInfo = LayerDebugInfo(
          layerName: 'TestLayer',
          processingTimeMs: 200,
          isSuccessful: true,
          hasError: false,
          errorMessage: null,
          itemsProcessed: 15,
          modificationsCount: 7,
          impactLevel: 0.75,
          cacheHits: 10,
          cacheMisses: 5,
          debugData: {'key': 'value'},
          warnings: ['warning1'],
          layerConfig: {'config': 'test'},
        );

        final map = debugInfo.toMap();

        expect(map['layer_name'], equals('TestLayer'));
        expect(map['processing_time_ms'], equals(200));
        expect(map['is_successful'], isTrue);
        expect(map['has_error'], isFalse);
        expect(map['error_message'], isNull);
        expect(map['items_processed'], equals(15));
        expect(map['modifications_count'], equals(7));
        expect(map['impact_level'], equals(0.75));
        expect(map['cache_hits'], equals(10));
        expect(map['cache_misses'], equals(5));
        expect(map['cache_hit_rate'], equals(2/3));
        expect(map['processing_rate'], equals(75.0));
        expect(map['modification_rate'], equals(7/15));
        expect(map['debug_data'], equals({'key': 'value'}));
        expect(map['warnings'], equals(['warning1']));
        expect(map['layer_config'], equals({'config': 'test'}));
      });

      test('should deserialize from Map correctly', () {
        final map = {
          'layer_name': 'DeserializedLayer',
          'processing_time_ms': 180,
          'is_successful': false,
          'has_error': true,
          'error_message': 'Test error',
          'items_processed': 12,
          'modifications_count': 4,
          'impact_level': 0.5,
          'cache_hits': 8,
          'cache_misses': 4,
          'debug_data': {'debug': 'info'},
          'warnings': ['warn1', 'warn2'],
          'layer_config': {'setting': 'value'},
        };

        final debugInfo = LayerDebugInfo.fromMap(map);

        expect(debugInfo.layerName, equals('DeserializedLayer'));
        expect(debugInfo.processingTimeMs, equals(180));
        expect(debugInfo.isSuccessful, isFalse);
        expect(debugInfo.hasError, isTrue);
        expect(debugInfo.errorMessage, equals('Test error'));
        expect(debugInfo.itemsProcessed, equals(12));
        expect(debugInfo.modificationsCount, equals(4));
        expect(debugInfo.impactLevel, equals(0.5));
        expect(debugInfo.cacheHits, equals(8));
        expect(debugInfo.cacheMisses, equals(4));
        expect(debugInfo.debugData, equals({'debug': 'info'}));
        expect(debugInfo.warnings, equals(['warn1', 'warn2']));
        expect(debugInfo.layerConfig, equals({'setting': 'value'}));
      });

      test('should handle missing fields in fromMap with defaults', () {
        final map = {
          'layer_name': 'MinimalLayer',
          'processing_time_ms': 50,
        };

        final debugInfo = LayerDebugInfo.fromMap(map);

        expect(debugInfo.layerName, equals('MinimalLayer'));
        expect(debugInfo.processingTimeMs, equals(50));
        expect(debugInfo.isSuccessful, isTrue);
        expect(debugInfo.hasError, isFalse);
        expect(debugInfo.errorMessage, isNull);
        expect(debugInfo.itemsProcessed, equals(0));
        expect(debugInfo.modificationsCount, equals(0));
        expect(debugInfo.impactLevel, equals(0.0));
        expect(debugInfo.cacheHits, equals(0));
        expect(debugInfo.cacheMisses, equals(0));
        expect(debugInfo.debugData, isEmpty);
        expect(debugInfo.warnings, isEmpty);
        expect(debugInfo.layerConfig, isEmpty);
      });

      test('should round-trip serialize and deserialize', () {
        final original = LayerDebugInfo(
          layerName: 'RoundTripLayer',
          processingTimeMs: 300,
          isSuccessful: true,
          hasError: false,
          itemsProcessed: 25,
          modificationsCount: 12,
          impactLevel: 0.9,
          cacheHits: 20,
          cacheMisses: 5,
          debugData: {'test': 'data', 'number': 42},
          warnings: ['warning1', 'warning2'],
          layerConfig: {'enabled': true, 'threshold': 0.8},
        );

        final map = original.toMap();
        final deserialized = LayerDebugInfo.fromMap(map);

        expect(deserialized.layerName, equals(original.layerName));
        expect(deserialized.processingTimeMs, equals(original.processingTimeMs));
        expect(deserialized.isSuccessful, equals(original.isSuccessful));
        expect(deserialized.hasError, equals(original.hasError));
        expect(deserialized.itemsProcessed, equals(original.itemsProcessed));
        expect(deserialized.modificationsCount, equals(original.modificationsCount));
        expect(deserialized.impactLevel, equals(original.impactLevel));
        expect(deserialized.cacheHits, equals(original.cacheHits));
        expect(deserialized.cacheMisses, equals(original.cacheMisses));
        expect(deserialized.debugData, equals(original.debugData));
        expect(deserialized.warnings, equals(original.warnings));
        expect(deserialized.layerConfig, equals(original.layerConfig));
      });
    });

    group('copyWith', () {
      late LayerDebugInfo original;

      setUp(() {
        original = LayerDebugInfo(
          layerName: 'OriginalLayer',
          processingTimeMs: 100,
          itemsProcessed: 10,
          modificationsCount: 5,
          impactLevel: 0.5,
        );
      });

      test('should create copy with no changes', () {
        final copy = original.copyWith();

        expect(copy.layerName, equals(original.layerName));
        expect(copy.processingTimeMs, equals(original.processingTimeMs));
        expect(copy.itemsProcessed, equals(original.itemsProcessed));
        expect(copy.modificationsCount, equals(original.modificationsCount));
        expect(copy.impactLevel, equals(original.impactLevel));
      });

      test('should create copy with single change', () {
        final copy = original.copyWith(layerName: 'ModifiedLayer');

        expect(copy.layerName, equals('ModifiedLayer'));
        expect(copy.processingTimeMs, equals(original.processingTimeMs));
        expect(copy.itemsProcessed, equals(original.itemsProcessed));
      });

      test('should create copy with multiple changes', () {
        final copy = original.copyWith(
          layerName: 'NewLayer',
          processingTimeMs: 200,
          itemsProcessed: 20,
          hasError: true,
          errorMessage: 'New error',
        );

        expect(copy.layerName, equals('NewLayer'));
        expect(copy.processingTimeMs, equals(200));
        expect(copy.itemsProcessed, equals(20));
        expect(copy.hasError, isTrue);
        expect(copy.errorMessage, equals('New error'));
        expect(copy.modificationsCount, equals(original.modificationsCount));
        expect(copy.impactLevel, equals(original.impactLevel));
      });
    });

    group('string representations', () {
      test('should generate correct summary for successful processing', () {
        final debugInfo = LayerDebugInfo.success(
          layerName: 'TestLayer',
          processingTimeMs: 150,
          itemsProcessed: 25,
          modificationsCount: 10,
        );

        expect(debugInfo.summary, equals('TestLayer: 25 items, 10 mods, 150ms'));
      });

      test('should generate correct summary for error processing', () {
        final debugInfo = LayerDebugInfo.error(
          layerName: 'ErrorLayer',
          processingTimeMs: 75,
          errorMessage: 'Processing failed',
        );

        expect(debugInfo.summary, equals('ErrorLayer: Error - Processing failed (75ms)'));
      });

      test('should generate correct performance report', () {
        final debugInfo = LayerDebugInfo.success(
          layerName: 'PerfLayer',
          processingTimeMs: 200,
          itemsProcessed: 40,
          modificationsCount: 16,
          impactLevel: 0.7,
          cacheHits: 35,
          cacheMisses: 5,
          warnings: ['warning1', 'warning2'],
        );

        final report = debugInfo.performanceReport;

        expect(report['layer_name'], equals('PerfLayer'));
        expect(report['processing_time_ms'], equals(200));
        expect(report['items_processed'], equals(40));
        expect(report['processing_rate_per_sec'], equals(200.0)); // 40 items in 200ms = 200 per second
        expect(report['modification_rate'], equals(0.4)); // 16/40
        expect(report['cache_hit_rate'], equals(0.875)); // 35/40
        expect(report['impact_level'], equals(0.7));
        expect(report['warnings_count'], equals(2));
      });

      test('should generate correct toString for successful processing', () {
        final debugInfo = LayerDebugInfo.success(
          layerName: 'TestLayer',
          processingTimeMs: 100,
          itemsProcessed: 15,
          modificationsCount: 6,
        );

        expect(debugInfo.toString(), equals(
          'LayerDebugInfo.success(layer: TestLayer, items: 15, mods: 6, time: 100ms)'));
      });

      test('should generate correct toString for error processing', () {
        final debugInfo = LayerDebugInfo.error(
          layerName: 'ErrorLayer',
          processingTimeMs: 50,
          errorMessage: 'Failed to process',
        );

        expect(debugInfo.toString(), equals(
          'LayerDebugInfo.error(layer: ErrorLayer, error: Failed to process, time: 50ms)'));
      });
    });

    group('equality and hashCode', () {
      test('should be equal when key properties are same', () {
        final debugInfo1 = LayerDebugInfo(
          layerName: 'TestLayer',
          processingTimeMs: 100,
          isSuccessful: true,
          hasError: false,
        );

        final debugInfo2 = LayerDebugInfo(
          layerName: 'TestLayer',
          processingTimeMs: 100,
          isSuccessful: true,
          hasError: false,
          itemsProcessed: 10, // Different but not part of equality
        );

        expect(debugInfo1, equals(debugInfo2));
        expect(debugInfo1.hashCode, equals(debugInfo2.hashCode));
      });

      test('should not be equal when key properties differ', () {
        final debugInfo1 = LayerDebugInfo(
          layerName: 'TestLayer',
          processingTimeMs: 100,
        );

        final debugInfo2 = LayerDebugInfo(
          layerName: 'DifferentLayer',
          processingTimeMs: 100,
        );

        final debugInfo3 = LayerDebugInfo(
          layerName: 'TestLayer',
          processingTimeMs: 200,
        );

        expect(debugInfo1, isNot(equals(debugInfo2)));
        expect(debugInfo1, isNot(equals(debugInfo3)));
        expect(debugInfo1.hashCode, isNot(equals(debugInfo2.hashCode)));
        expect(debugInfo1.hashCode, isNot(equals(debugInfo3.hashCode)));
      });

      test('should handle self-equality', () {
        final debugInfo = LayerDebugInfo(
          layerName: 'TestLayer',
          processingTimeMs: 100,
        );

        expect(debugInfo, equals(debugInfo));
        expect(debugInfo == debugInfo, isTrue);
      });
    });
  });
}