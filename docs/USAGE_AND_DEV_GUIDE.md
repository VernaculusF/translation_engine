# Translation Engine: Usage and Development Guide

This guide explains how to use, extend, and operate the Translation Engine, including database setup and population.

## 1. Quick Start

- Engine is a singleton with default pipeline layers registered.
- Databases are created on first initialization at a provided path.

```dart path=null start=null
import 'package:translation_engine/src/core/translation_engine.dart';
import 'package:translation_engine/src/core/translation_context.dart';

Future<void> main() async {
  final engine = TranslationEngine.instance(reset: true);
  await engine.initialize(customDatabasePath: '/path/to/db');

  final result = await engine.translate(
    'Hello, world!',
    sourceLanguage: 'en',
    targetLanguage: 'en',
    context: TranslationContext(sourceLanguage: 'en', targetLanguage: 'en', debugMode: true),
  );

  print(result.translatedText);
  await engine.dispose();
}
```

## 2. Architecture Overview

- TranslationEngine: high-level lifecycle and API
- TranslationPipeline: orchestrates layers (pre → phrase → dictionary → grammar → word order → post)
- BaseTranslationLayer: common interface implemented by all layers
- Layer adapters: bridge BaseTranslationLayer into pipeline automatically
- Data layer:
  - DatabaseManager: creates and manages three SQLite databases
  - Repositories: DictionaryRepository, PhraseRepository, UserDataRepository
  - CacheManager: in-memory LRU cache

## 3. Databases and Schemas

Databases are created in a folder (customDatabasePath). Three DB files are used:

- dictionaries.db
  - words(id, source_word, target_word, language_pair, part_of_speech, definition, frequency, created_at, updated_at)
  - word_cache(source_word, target_word, language_pair, last_used)
- phrases.db
  - phrases(id, source_phrase, target_phrase, language_pair, category, context, frequency, confidence, usage_count, created_at, updated_at)
  - phrase_cache(source_phrase, target_phrase, language_pair, last_used)
- user_data.db
  - translation_history(id, original_text, translated_text, language_pair, confidence, processing_time_ms, timestamp, session_id, metadata)
  - user_corrections(id, original_text, corrected_translation, lang_pair, created_at)
  - user_settings(setting_key, setting_value, description, created_at, updated_at)
  - user_translation_edits(id, original_text, original_translation, user_translation, language_pair, reason, is_approved, created_at, updated_at)
  - context_cache(id, context_key, translation_result, language_pair, last_used)

All schemas are created automatically by DatabaseManager.

## 4. Populating Databases

Use repositories for safe, validated inserts.

- Dictionary entries
```dart path=null start=null
final dict = DictionaryRepository(databaseManager: dbManager, cacheManager: cache);
await dict.addTranslation('good', 'хороший', 'en-ru', partOfSpeech: 'adjective', frequency: 100);
```

- Phrase entries
```dart path=null start=null
final phrases = PhraseRepository(databaseManager: dbManager, cacheManager: cache);
await phrases.addPhrase('good morning', 'доброе утро', 'en-ru', category: 'greetings', confidence: 95, frequency: 50);
```

- User history/settings/edits
```dart path=null start=null
final user = UserDataRepository(databaseManager: dbManager, cacheManager: cache);
// settings
await user.setSetting('default_language_pair', 'en-ru', description: 'Default translation pair');
// history is typically added from a TranslationResult via a helper (not shown in engine yet)
```

Normalization rules:
- words.source_word and phrases.source_phrase are normalized to lowercase and spaces collapsed.

## 5. Using the Pipeline and Layers

- Engine initializes pipeline with all default layers via adapters.
- To customize layers:
  - Build your own TranslationPipeline(registerDefaultLayers: false)
  - Register adapters selectively.

```dart path=null start=null
final pipeline = TranslationPipeline(
  dictionaryRepository: dict,
  phraseRepository: phrases,
  userDataRepository: user,
  cacheManager: cache,
  registerDefaultLayers: false,
);
// Register only required layers via adapters factory
// e.g., LayerAdaptersFactory.preProcessing(), LayerAdaptersFactory.dictionary(repo: dict)
```

## 6. Extending with Custom Layers

Implement BaseTranslationLayer:
- canHandle(String text, TranslationContext context)
- process(String text, TranslationContext context) → LayerResult

Best practices:
- Respect TranslationContext metadata
- Produce LayerDebugInfo.success/error
- Return LayerResult.success/noChange/error accordingly
- Keep regex safe and avoid heavy CPU where possible

## 7. Performance and Reporting

- Run benchmarks: `flutter test test/benchmarks/perf_benchmarks_test.dart`
- Generate JSON perf report: `flutter test test/benchmarks/perf_report_test.dart` → `reports/performance/*.json`
- Use pipeline.statistics for layer-level timings and counts

## 8. Testing

- Analyzer: `flutter analyze`
- All tests: `flutter test`
- E2E test: `flutter test test/e2e/pipeline_e2e_test.dart`

## 9. Integration Tips for Real Apps

- Provide a writable database path on the device (e.g., application documents directory)
- Initialize engine in app startup and reuse the singleton
- Wrap translate() calls with debouncing/throttling for rapid user input
- Persist user corrections via UserDataRepository
- Use context (formality, domain) for future rule refinements

## 10. Maintenance and Updates

- Follow CHANGELOG for new versions and migration notes
- Keep tests green (CI recommended: analyzer + tests)
- When adding new layers/rules, augment tests and update this guide
