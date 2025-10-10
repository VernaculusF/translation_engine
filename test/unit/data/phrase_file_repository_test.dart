import 'dart:io';
import 'package:test/test.dart';
import 'package:translation_engine/src/data/phrase_repository.dart';
import 'package:translation_engine/src/utils/cache_manager.dart';

void main() {
  group('PhraseRepository (file-based)', () {
    late Directory tempDir;
    late PhraseRepository repo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('te_phrase_repo_');
      repo = PhraseRepository(dataDirPath: tempDir.path, cacheManager: CacheManager());
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('addPhrase and getPhraseTranslation', () async {
      final e = await repo.addPhrase('Good morning', 'Доброе утро', 'en-ru', category: 'greetings', confidence: 95, frequency: 10);
      expect(e.sourcePhrase, 'good morning');

      final fetched = await repo.getPhraseTranslation('good morning', 'en-ru');
      expect(fetched, isNotNull);
      expect(fetched!.targetPhrase, 'Доброе утро');
    });

    test('searchByPhrase returns matches and categories', () async {
      await repo.addPhrase('how are you', 'как дела', 'en-ru', category: 'conversation', confidence: 90, frequency: 5);
      await repo.addPhrase('how old are you', 'сколько тебе лет', 'en-ru', category: 'conversation', confidence: 80, frequency: 3);

      final result = await repo.searchByPhrase('how', 'en-ru', limit: 10);
      expect(result.length, 2);
      final cats = await repo.getCategories('en-ru');
      expect(cats, contains('conversation'));
    });

    test('top confident phrases', () async {
      await repo.addPhrase('a', 'a', 'en-ru', confidence: 50, frequency: 1);
      await repo.addPhrase('b', 'b', 'en-ru', confidence: 99, frequency: 1);
      final top = await repo.getTopConfidentPhrases('en-ru', minConfidence: 90, limit: 1);
      expect(top.first.sourcePhrase, 'b');
    });
  });
}
