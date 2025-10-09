import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:translation_engine/src/data/database_manager.dart';
import 'package:translation_engine/src/utils/cache_manager.dart';
import 'package:translation_engine/src/data/dictionary_repository.dart';
import 'package:translation_engine/src/data/phrase_repository.dart';
import 'package:translation_engine/src/data/user_data_repository.dart';
import 'package:translation_engine/src/core/translation_pipeline.dart';
import 'package:translation_engine/src/core/translation_context.dart';

void main() {
  group('Performance Report Generator', () {
    late Directory tempDir;
    late DatabaseManager dbManager;
    late CacheManager cacheManager;
    late DictionaryRepository dictionaryRepo;
    late PhraseRepository phraseRepo;
    late UserDataRepository userRepo;
    late TranslationPipeline pipeline;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('translation_engine_perf_');
      dbManager = DatabaseManager(customDatabasePath: tempDir.path);
      cacheManager = CacheManager();
      dictionaryRepo = DictionaryRepository(databaseManager: dbManager, cacheManager: cacheManager);
      phraseRepo = PhraseRepository(databaseManager: dbManager, cacheManager: cacheManager);
      userRepo = UserDataRepository(databaseManager: dbManager, cacheManager: cacheManager);

      // Ensure DBs are initialized
      await dbManager.database;
      await dbManager.initPhrasesDatabase();
      await dbManager.initUserDataDatabase();

      pipeline = TranslationPipeline(
        dictionaryRepository: dictionaryRepo,
        phraseRepository: phraseRepo,
        userDataRepository: userRepo,
        cacheManager: cacheManager,
        registerDefaultLayers: true,
      );
    });

    tearDown(() async {
      await dbManager.close();
      cacheManager.clear();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('generate JSON performance report', () async {
      const runs = 50;
      final sw = Stopwatch()..start();

      final context = TranslationContext(sourceLanguage: 'en', targetLanguage: 'en');
      for (int i = 0; i < runs; i++) {
        final text = 'Hello world #$i!!!   How are you?';
        final result = await pipeline.process(text, context);
        expect(result.hasError, isFalse);
      }
      sw.stop();

      final stats = pipeline.statistics;
      final layerStats = stats['layer_statistics'] as Map<String, dynamic>;

      final report = {
        'timestamp': DateTime.now().toIso8601String(),
        'runs': runs,
        'total_time_ms': sw.elapsedMilliseconds,
        'average_time_ms': sw.elapsedMilliseconds / runs,
        'layers_count': stats['layers_count'],
        'layer_statistics': layerStats,
      };

      final outDir = Directory('reports/performance');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      final outFile = File('reports/performance/perf_report_${DateTime.now().millisecondsSinceEpoch}.json');
      await outFile.writeAsString(const JsonEncoder.withIndent('  ').convert(report));

      // Also assert existence
      expect(outFile.existsSync(), isTrue);
    });
  });
}
