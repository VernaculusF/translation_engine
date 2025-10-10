import 'dart:io';
import 'package:test/test.dart';
import 'package:fluent_translate/src/data/dictionary_repository.dart';
import 'package:fluent_translate/src/tools/dictionary_importer.dart';
import 'package:fluent_translate/src/utils/cache_manager.dart';

void main() {
  test('dictionary importer (jsonl)', () async {
    final dir = await Directory.systemTemp.createTemp('te_import_');
    try {
      final repo = DictionaryRepository(dataDirPath: dir.path, cacheManager: CacheManager());
      final importer = DictionaryImporter(repository: repo);
      final f = File('${dir.path}/en-ru_dictionary.jsonl');
      await f.writeAsString('{"source_word":"a","target_word":"а","language_pair":"en-ru","frequency":1}\n');
      final report = await importer.importFile(f, languagePair: 'en-ru', format: 'jsonl');
      expect(report.insertedOrUpdated, 1);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
