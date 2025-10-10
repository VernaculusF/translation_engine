// ignore_for_file: avoid_print

import 'dart:io';
import 'package:fluent_translate/src/utils/cache_manager.dart';
import 'package:fluent_translate/src/data/dictionary_repository.dart';
import 'package:fluent_translate/src/data/phrase_repository.dart';
import 'package:fluent_translate/src/core/translation_engine.dart';
import 'package:fluent_translate/src/core/translation_context.dart';

Future<void> main() async {
  // Use a local folder under samples for persistent data during the demo
  final sampleDir = Directory('samples/.sample_data');
  if (!sampleDir.existsSync()) sampleDir.createSync(recursive: true);
  final dataDir = sampleDir.path;

  // Populate repositories with a couple of entries (file-based)
  final cacheManager = CacheManager();
  final dictRepo = DictionaryRepository(dataDirPath: dataDir, cacheManager: cacheManager);
  final phraseRepo = PhraseRepository(dataDirPath: dataDir, cacheManager: cacheManager);

  // Add sample dictionary entries
  await dictRepo.addTranslation('good', 'хороший', 'en-ru', partOfSpeech: 'adjective', frequency: 100);
  await dictRepo.addTranslation('morning', 'утро', 'en-ru', partOfSpeech: 'noun', frequency: 80);

  // Add a phrase entry
  await phraseRepo.addPhrase('good morning', 'доброе утро', 'en-ru', category: 'greetings', confidence: 95, frequency: 50);

  // Now run engine against the same db path so it can read the data
  final engine = TranslationEngine.instance(reset: true);
  await engine.initialize(customDatabasePath: dataDir);

  final result = await engine.translate(
    'Good morning, friend!',
    sourceLanguage: 'en',
    targetLanguage: 'ru',
    context: TranslationContext(
      sourceLanguage: 'en',
      targetLanguage: 'ru',
      debugMode: true,
    ),
  );

  print('Original:   ${result.originalText}');
  print('Translated: ${result.translatedText}');
  print('Confidence: ${result.confidence.toStringAsFixed(2)}');
  print('Layers:     ${result.layerResults.length}');
  print('Time:       ${result.processingTimeMs}ms');

  await engine.dispose();
}
