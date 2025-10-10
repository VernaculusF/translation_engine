import 'dart:io';
import 'package:test/test.dart';
import 'package:fluent_translate/src/data/user_data_repository.dart';
import 'package:fluent_translate/src/models/translation_result.dart';
import 'package:fluent_translate/src/utils/cache_manager.dart';

void main() {
  group('UserDataRepository (file-based)', () {
    late Directory dir;
    late UserDataRepository repo;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('te_user_repo_');
      repo = UserDataRepository(dataDirPath: dir.path, cacheManager: CacheManager());
    });

    tearDown(() async {
      await dir.delete(recursive: true);
    });

    test('addToHistory and getTranslationHistory', () async {
      final result = TranslationResult.success(
        originalText: 'Hello',
        translatedText: 'Привет',
        languagePair: 'en-ru',
        confidence: 0.9,
        processingTimeMs: 10,
        layerResults: const [],
      );
      await repo.addToHistory(result, sessionId: 's1');
      final history = await repo.getTranslationHistory(languagePair: 'en-ru');
      expect(history.length, 1);
      expect(history.first.sessionId, 's1');
    });

    test('settings set/get/delete', () async {
      final s = await repo.setSetting('default_language_pair', 'en-ru', description: 'Default');
      expect(s.key, 'default_language_pair');
      final got = await repo.getSetting('default_language_pair');
      expect(got, isNotNull);
      final all = await repo.getAllSettings();
      expect(all.map((e) => e.key), contains('default_language_pair'));
      final deleted = await repo.deleteSetting('default_language_pair');
      expect(deleted, isTrue);
    });

    test('translation edits add/approve/find', () async {
      final e = await repo.addTranslationEdit('How are you?', 'Как дела?', 'Как поживаешь?', 'en-ru', reason: 'More natural');
      expect(e.id, isNotNull);
      var found = await repo.findEditForText('How are you?', 'en-ru');
      expect(found, isNull);
      final ok = await repo.approveTranslationEdit(e.id!);
      expect(ok, isTrue);
      found = await repo.findEditForText('How are you?', 'en-ru');
      expect(found, isNotNull);
    });
  });
}
