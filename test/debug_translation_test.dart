import 'package:test/test.dart';
import 'package:fluent_translate/src/core/translation_engine.dart';
import 'helpers/test_database_helper.dart' as helpers;

void main() {
  group('Translation Engine (JSONL)', () {
    test('initialize and dispose with empty data dir', () async {
      final session = await helpers.TestDataHelper.createSession();
      final engine = TranslationEngine.instance(reset: true);
      await engine.initialize(customDatabasePath: session.dataDir.path);
      expect(engine.isReady, isTrue);
      await engine.dispose();
      await session.cleanup();
    });
  });
}
