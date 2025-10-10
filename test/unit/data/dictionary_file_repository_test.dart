import 'dart:io';
import 'package:test/test.dart';
import 'package:translation_engine/src/data/dictionary_repository.dart';
import 'package:translation_engine/src/utils/cache_manager.dart';

void main() {
  group('DictionaryRepository (file-based)', () {
    late Directory tempDir;
    late DictionaryRepository repo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('te_dict_repo_');
      repo = DictionaryRepository(dataDirPath: tempDir.path, cacheManager: CacheManager());
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('addTranslation and getTranslation', () async {
      final e = await repo.addTranslation('Hello', 'Привет', 'en-ru', partOfSpeech: 'interjection', frequency: 10);
      expect(e.sourceWord, 'hello');

      final fetched = await repo.getTranslation('hello', 'en-ru');
      expect(fetched, isNotNull);
      expect(fetched!.targetWord, 'Привет');
      expect(fetched.frequency, greaterThanOrEqualTo(10));
    });

    test('searchByWord returns matches', () async {
      await repo.addTranslation('hello', 'привет', 'en-ru', frequency: 10);
      await repo.addTranslation('help', 'помощь', 'en-ru', frequency: 5);

      final result = await repo.searchByWord('he', 'en-ru', limit: 10);
      expect(result.map((e) => e.sourceWord), containsAll(['hello', 'help']));
    });

    test('stats and top words', () async {
      await repo.addTranslation('a', 'а', 'en-ru', frequency: 1);
      await repo.addTranslation('b', 'б', 'en-ru', frequency: 5);
      await repo.addTranslation('c', 'ц', 'en-ru', frequency: 3);

      final stats = await repo.getLanguagePairStats('en-ru');
      expect(stats['total_words'], 3);
      final top = await repo.getTopWords('en-ru', limit: 2);
      expect(top.first.sourceWord, 'b');
    });
  });
}
