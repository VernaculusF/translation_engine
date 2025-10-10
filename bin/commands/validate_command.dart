// ignore_for_file: avoid_print
import 'base_command.dart';

import 'package:fluent_translate/src/utils/cache_manager.dart';
import 'package:fluent_translate/src/data/dictionary_repository.dart';
import 'package:fluent_translate/src/data/phrase_repository.dart';

class ValidateCommand extends BaseCommand {
  @override
  String get name => 'validate';

  @override
  String get description => 'Validate translation data files (dictionary/phrases)';

  @override
  void printUsage() {
    print('Validate Command');
    print('');
    print('Usage:');
    print('  dart run bin/translate_engine.dart validate --db=<dir> --lang=<xx-yy>');
  }

  @override
  Future<int> run(List<String> args) async {
    if (args.contains('--help') || args.contains('-h')) {
      printUsage();
      return 0;
    }
    final p = parseArgs(args);
    if (!validateRequiredParams(p, ['db', 'lang'])) {
      print('');
      printUsage();
      return 64;
    }
    final dir = p['db']!;
    final lang = p['lang']!;

    try {
      final cache = CacheManager();
      final dictRepo = DictionaryRepository(dataDirPath: dir, cacheManager: cache);
      final phraseRepo = PhraseRepository(dataDirPath: dir, cacheManager: cache);

      final dict = await dictRepo.getAllTranslations(lang);
      final phrases = await phraseRepo.getAllPhrases(lang);

      print('Dictionary entries: ${dict.length}');
      print('Phrases entries:    ${phrases.length}');

      // Simple sanity checks
      final badDict = dict.where((e) => e.sourceWord.isEmpty || e.targetWord.isEmpty).length;
      final badPhr = phrases.where((e) => e.sourcePhrase.isEmpty || e.targetPhrase.isEmpty).length;

      if (badDict > 0 || badPhr > 0) {
        print('Found issues: dict=$badDict, phrases=$badPhr');
        return 1;
      }
      print('Validation OK');
      return 0;
    } catch (e) {
      print('Validation error: $e');
      return 1;
    }
  }
}
