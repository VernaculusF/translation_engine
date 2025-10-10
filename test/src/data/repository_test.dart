import 'package:test/test.dart';
import 'package:translation_engine/src/utils/cache_manager.dart';
import 'package:translation_engine/src/models/translation_result.dart';
import 'package:translation_engine/src/data/dictionary_repository.dart';
import 'package:translation_engine/src/data/phrase_repository.dart';
import 'package:translation_engine/src/data/user_data_repository.dart';
import '../../helpers/test_database_helper.dart';

void main() {
  group('File-based Repositories (JSONL)', () {
    late TestDataSession session;
    late CacheManager cache;
    late DictionaryRepository dict;
    late PhraseRepository phrase;
    late UserDataRepository userData;

    setUp(() async {
      session = await TestDataHelper.createSession();
      cache = CacheManager();
      dict = DictionaryRepository(dataDirPath: session.dataDir.path, cacheManager: cache);
      phrase = PhraseRepository(dataDirPath: session.dataDir.path, cacheManager: cache);
      userData = UserDataRepository(dataDirPath: session.dataDir.path, cacheManager: cache);
    });

    tearDown(() async {
      cache.clear();
      await session.cleanup();
    });

    test('DictionaryRepository: add/get/search/delete/stats', () async {
      final e1 = await dict.addTranslation('hello', 'привет', 'en-ru', frequency: 2);
      final e2 = await dict.addTranslation('world', 'мир', 'en-ru', frequency: 1);
      expect(e1.id, isNotNull);
      expect(e2.id, isNotNull);

      final e1b = await dict.addTranslation('hello', 'привет', 'en-ru', frequency: 3);
      expect(e1b.frequency, equals(e1.frequency + 3));

      final r1 = await dict.getTranslation('hello', 'en-ru');
      expect(r1, isNotNull);
      expect(r1!.targetWord, equals('привет'));

      final search = await dict.searchByWord('o', 'en-ru');
      expect(search.map((e) => e.sourceWord).toSet(), containsAll({'hello', 'world'}));

      final stats = await dict.getLanguagePairStats('en-ru');
      expect(stats['language_pair'], equals('en-ru'));
      expect(stats['total_words'], equals(2));
      final top = await dict.getTopWords('en-ru', limit: 1);
      expect(top.first.sourceWord, equals('hello'));

      final removed = await dict.deleteTranslation(e2.id!);
      expect(removed, isTrue);
      final all = await dict.getAllTranslations('en-ru');
      expect(all.length, equals(1));
    });

    test('PhraseRepository: add/get/search/category/delete/stats', () async {
      final p = await phrase.addPhrase(
        'Good morning', 'Доброе утро', 'en-ru',
        category: 'greetings', context: 'formal', frequency: 5, confidence: 95,
      );
      expect(p.id, isNotNull);
      expect(p.sourcePhrase, equals('good morning'));

      final got = await phrase.getPhraseTranslation('Good morning', 'en-ru');
      expect(got, isNotNull);
      expect(got!.targetPhrase, equals('Доброе утро'));

      final bySearch = await phrase.searchByPhrase('good', 'en-ru', limit: 10);
      expect(bySearch.any((e) => e.sourcePhrase == 'good morning'), isTrue);

      final cats = await phrase.getCategories('en-ru');
      expect(cats, contains('greetings'));

      final okDel = await phrase.deletePhrase(p.id!);
      expect(okDel, isTrue);
      final all = await phrase.getAllPhrases('en-ru');
      expect(all, isEmpty);
    });

    test('UserDataRepository: history/settings/edits', () async {
      final tr = TranslationResult.success(
        originalText: 'Hello',
        translatedText: 'Привет',
        languagePair: 'en-ru',
        confidence: 0.9,
        processingTimeMs: 42,
        layerResults: const [],
      );
      final h = await userData.addToHistory(tr, sessionId: 's1');
      expect(h.id, isNotNull);
      final history = await userData.getTranslationHistory(limit: 10);
      expect(history.length, equals(1));
      expect(history.first.sessionId, equals('s1'));

      final s1 = await userData.setSetting('theme', 'dark', description: 'UI theme');
      expect(s1.key, 'theme');
      final sGet = await userData.getSetting('theme');
      expect(sGet?.value, equals('dark'));
      final sDel = await userData.deleteSetting('theme');
      expect(sDel, isTrue);
      final sGet2 = await userData.getSetting('theme');
      expect(sGet2, isNull);

      final edit = await userData.addTranslationEdit(
        'Hello', 'Привет', 'Здравствуйте', 'en-ru', reason: 'More formal',
      );
      expect(edit.id, isNotNull);
      var edits = await userData.getTranslationEdits(languagePair: 'en-ru');
      expect(edits.length, equals(1));
      final approved = await userData.approveTranslationEdit(edit.id!);
      expect(approved, isTrue);
      final found = await userData.findEditForText('Hello', 'en-ru');
      expect(found, isNotNull);
      expect(found!.userTranslation, equals('Здравствуйте'));
    });
  });
}
