import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:translation_engine/src/data/database_manager.dart';
import 'package:translation_engine/src/data/dictionary_repository.dart';
import 'package:translation_engine/src/utils/cache_manager.dart';
import 'package:translation_engine/src/tools/dictionary_importer.dart';

void main() {
  group('DictionaryImporter', () {
    late Directory tempDir;
    late DatabaseManager dbManager;
    late CacheManager cache;
    late DictionaryRepository repo;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('dict_import_test_');
      dbManager = DatabaseManager(customDatabasePath: tempDir.path);
      cache = CacheManager();
      repo = DictionaryRepository(databaseManager: dbManager, cacheManager: cache);
      await dbManager.database; // ensure DB
    });

    tearDown(() async {
      await dbManager.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('imports CSV with header', () async {
      final file = File('${tempDir.path}/sample.csv');
      await file.writeAsString('source_word,target_word,language_pair,frequency\nhello,привет,en-ru,5\nworld,мир,en-ru,3');

      final importer = DictionaryImporter(repository: repo);
      final report = await importer.importCsv(file);
      expect(report.total, 2);
      expect(report.insertedOrUpdated, 2);

      final e1 = await repo.getTranslation('hello', 'en-ru');
      final e2 = await repo.getTranslation('world', 'en-ru');
      expect(e1, isNotNull);
      expect(e1!.targetWord, 'привет');
      expect(e2, isNotNull);
      expect(e2!.targetWord, 'мир');
    });

    test('imports JSON array', () async {
      final file = File('${tempDir.path}/sample.json');
      await file.writeAsString('[{"source":"cat","target":"кот","language_pair":"en-ru","frequency":2}]');
      final importer = DictionaryImporter(repository: repo);
      final report = await importer.importJsonArray(file);
      expect(report.total, 1);
      expect(report.insertedOrUpdated, 1);
      final e = await repo.getTranslation('cat', 'en-ru');
      expect(e, isNotNull);
      expect(e!.targetWord, 'кот');
    });

    test('imports JSONL lines', () async {
      final file = File('${tempDir.path}/sample.jsonl');
      await file.writeAsString('{"source":"good","target":"хороший","language_pair":"en-ru"}\n{"source":"bad","target":"плохой","language_pair":"en-ru"}');
      final importer = DictionaryImporter(repository: repo);
      final report = await importer.importJsonLines(file);
      expect(report.total, 2);
      expect(report.insertedOrUpdated, 2);
      final good = await repo.getTranslation('good', 'en-ru');
      final bad = await repo.getTranslation('bad', 'en-ru');
      expect(good, isNotNull);
      expect(bad, isNotNull);
    });
  });
}
