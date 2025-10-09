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

## 3. Data Models

Below are the core data structures returned/consumed by the engine and layers.

- TranslationResult
  - originalText: String
  - translatedText: String
  - languagePair: String (e.g., "en-ru")
  - confidence: double (0.0-1.0)
  - processingTimeMs: int
  - layerResults: List<LayerDebugInfo>
  - layersProcessed: int
  - hasError: bool
  - errorMessage?: String
  - cacheMetrics?: CacheMetrics
  - timestamp: DateTime
  - qualityScore?: double (1..10)
  - alternatives: List<String>
  - context: Map<String, dynamic>

- LayerResult (per layer)
  - processedText: String
  - success: bool
  - errorMessage?: String
  - confidence: double (0.0-1.0)
  - debugInfo: LayerDebugInfo
  - metadata: Map<String, dynamic>

- LayerDebugInfo (per layer)
  - layerName: String
  - processingTimeMs: int
  - isSuccessful: bool
  - hasError: bool
  - errorMessage?: String
  - itemsProcessed: int
  - modificationsCount: int
  - impactLevel: double (0.0-1.0)
  - cacheHits: int
  - cacheMisses: int
  - inputText?: String
  - outputText?: String
  - wasModified: bool
  - additionalInfo: Map<String, dynamic>
  - debugData: Map<String, dynamic>
  - warnings: List<String>
  - layerConfig: Map<String, dynamic>

- TranslationContext (input to pipeline and layers)
  - sourceLanguage: String (ISO 639-1)
  - targetLanguage: String (ISO 639-1)
  - mode: TranslationMode (standard|fast|detailed|quality)
  - formality: FormalityLevel (auto|informal|neutral|formal)
  - domain: TranslationDomain (general|technical|medical|legal|scientific|business|literary)
  - maxProcessingTimeMs?: int
  - minConfidence?: double
  - useCache: bool (default true)
  - saveToCache: bool (default true)
  - useUserCorrections: bool (default true)
  - debugMode: bool (default false)
  - excludeWords: Set<String>
  - forceTranslations: Map<String, String>
  - contextText?: String
  - userId?: String
  - sessionId?: String
  - tokens?: List<String>
  - originalText?: String
  - translatedText?: String
  - metadata: Map<String, dynamic> (get/set via setMetadata/getMetadata)

### Enums used by TranslationContext

```dart path=null start=null
enum TranslationMode { standard, fast, detailed, quality }
enum FormalityLevel { auto, informal, neutral, formal }
enum TranslationDomain { general, technical, medical, legal, scientific, business, literary }
```

## 4. Databases and Schemas

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

## 5. Populating Databases

Dictionary importer
- CLI: `dart run bin/import_dictionary.dart --file=path/to.csv --db=/path/to/dbdir --lang=en-ru --format=csv --delimiter=,`
- Formats: csv (header preferred), json (array), jsonl (one JSON object per line)
- Programmatic usage:
```dart path=null start=null
final importer = DictionaryImporter(repository: dictRepo);
final report = await importer.importFile(File('data/en-ru.csv'), languagePair: 'en-ru');
print(report.toMap());
```

Bulk operations:
- Use BaseRepository.executeTransaction to batch inserts/updates in a single transaction.
- Example (dictionary bulk add):
```dart path=null start=null
final words = [
  {'source': 'alpha', 'target': 'альфа'},
  {'source': 'beta', 'target': 'бета'},
];
await dict.executeTransaction((conn) async {
  for (final w in words) {
    await conn.execute(
      'INSERT INTO words (source_word, target_word, language_pair, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
      [w['source'], w['target'], 'en-ru', DateTime.now().millisecondsSinceEpoch, DateTime.now().millisecondsSinceEpoch],
    );
  }
  return true;
});
```

User corrections (edits/settings/history):
```dart path=null start=null
// settings
await user.setSetting('default_language_pair', 'en-ru', description: 'Default translation pair');

// add user edit
await user.addTranslationEdit(
  'How are you?',
  'Как дела?',
  'Как поживаешь?',
  'en-ru',
  reason: 'More natural',
);

// get edits
final edits = await user.getTranslationEdits(languagePair: 'en-ru');
```

Error handling in repositories:
- ValidationException — invalid input
- DatabaseInitException/DatabaseQueryException — DB initialization and query errors
- Use try/catch and surface errors to UI/telemetry

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

## 6. Using the Pipeline and Layers

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

## 7. Extending with Custom Layers

Implement BaseTranslationLayer:
- canHandle(String text, TranslationContext context)
- process(String text, TranslationContext context) → LayerResult

Best practices:
- Respect TranslationContext metadata
- Produce LayerDebugInfo.success/error
- Return LayerResult.success/noChange/error accordingly
- Keep regex safe and avoid heavy CPU where possible

## 8. Performance and Reporting

Quality scoring & alternatives:
- qualityScore (1..10) is optional and can be derived from confidence and formatting metrics.
  - Reference formula (example):
```dart path=null start=null
// Map confidence (0..1) to 6..10, deduct penalties based on formatting/grammar scores
double qualityScoreFrom(double confidence, {double formattingScore = 1.0, double grammarScore = 1.0}) {
  // base 6..10
  final base = 6.0 + (confidence.clamp(0.0, 1.0) * 4.0);
  final penalty = (1.0 - formattingScore.clamp(0.0, 1.0)) * 1.0 + (1.0 - grammarScore.clamp(0.0, 1.0)) * 1.0;
  return (base - penalty).clamp(1.0, 10.0);
}
```
- alternatives is a list of candidate translations; produce them from Phrase/Dictionary lookups and post-process. Example:
```dart path=null start=null
final result = TranslationResult.success(
  originalText: text,
  translatedText: bestCandidate,
  languagePair: ctx.languagePair,
  confidence: 0.9,
  processingTimeMs: sw.elapsedMilliseconds,
  layerResults: layers,
  alternatives: ['Candidate A', 'Candidate B'],
  context: {'source_tokens': tokens},
);
```

Cache and memory:
- CacheManager limits (hard-coded defaults):
  - MAX_WORDS_CACHE = 10,000
  - MAX_PHRASES_CACHE = 5,000
  - CACHE_TTL_MS = 30 minutes
- Metrics: `CacheManager.metrics` returns counts, hit/miss, estimated_memory_bytes, configured limits.
- Recommended production defaults:
  - For small-scale apps (<= 10k words): 128MB RAM budget is sufficient for engine + caches.
  - For mid-scale (<= 50k items total): consider 256MB+ and adjust limits (fork of CacheManager).

Runtime metrics and monitoring:
- TranslationPipeline.statistics: processed_texts, total/avg processing time, layer_statistics (executions, total/avg time per layer)
- TranslationResult.performanceReport: aggregate per-translation timing and cache metrics
- Add an application-level exporter to push these metrics into your APM (e.g., Prometheus via custom adapter).

Benchmarks and reports:
- Run: `flutter test test/benchmarks/perf_benchmarks_test.dart`
- Generate JSON report: `flutter test test/benchmarks/perf_report_test.dart` → `reports/performance/*.json`
- Recommended P50/P95/P99 additions: extend perf_report_test to compute percentiles from recorded samples.

Cache and memory:
- CacheManager limits (hard-coded defaults):
  - MAX_WORDS_CACHE = 10,000
  - MAX_PHRASES_CACHE = 5,000
  - CACHE_TTL_MS = 30 minutes
- Metrics: `CacheManager.metrics` returns counts, hit/miss, estimated_memory_bytes, configured limits.
- Recommended production defaults:
  - For small-scale apps (<= 10k words): 128MB RAM budget is sufficient for engine + caches.
  - For mid-scale (<= 50k items total): consider 256MB+ and adjust limits (fork of CacheManager).

Runtime metrics and monitoring:
- TranslationPipeline.statistics: processed_texts, total/avg processing time, layer_statistics (executions, total/avg time per layer)
- TranslationResult.performanceReport: aggregate per-translation timing and cache metrics
- Add an application-level exporter to push these metrics into your APM (e.g., Prometheus via custom adapter).

Benchmarks and reports:
- Run: `flutter test test/benchmarks/perf_benchmarks_test.dart`
- Generate JSON report: `flutter test test/benchmarks/perf_report_test.dart` → `reports/performance/*.json`
- Recommended P50/P95/P99 additions: extend perf_report_test to compute percentiles from recorded samples.

- Run benchmarks: `flutter test test/benchmarks/perf_benchmarks_test.dart`
- Generate JSON perf report: `flutter test test/benchmarks/perf_report_test.dart` → `reports/performance/*.json`
- Use pipeline.statistics for layer-level timings and counts

## 9. Testing

- Analyzer: `flutter analyze`
- All tests: `flutter test`
- E2E test: `flutter test test/e2e/pipeline_e2e_test.dart`

## 10. Integration Tips for Real Apps

Persisting TranslationResult to history:
```dart path=null start=null
final engine = TranslationEngine.instance();
await engine.initialize(customDatabasePath: '/data/appdb');
final ctx = TranslationContext(sourceLanguage: 'en', targetLanguage: 'ru', debugMode: false);
final result = await engine.translate('Good morning', sourceLanguage: 'en', targetLanguage: 'ru', context: ctx);

// Save to history
final userRepo = UserDataRepository(databaseManager: DatabaseManager(customDatabasePath: '/data/appdb'), cacheManager: CacheManager());
await userRepo.addToHistory(result, sessionId: 'session-123');
```

Using sessionId and userId:
- sessionId — связывает несколько операций перевода одной пользовательской сессии; передавайте при сохранении истории (addToHistory).
- userId — задайте в TranslationContext, если необходимо связывать события/правки с конкретным пользователем (например, B2B многопользовательская среда).
```dart path=null start=null
final ctx = TranslationContext(
  sourceLanguage: 'en',
  targetLanguage: 'ru',
  userId: 'user-42',
  // можно сохранить дополнительный контекст
  metadata: {'tenant': 'acme'},
);
```

- Provide a writable database path on the device (e.g., application documents directory)
- Initialize engine in app startup and reuse the singleton
- Wrap translate() calls with debouncing/throttling for rapid user input
- Persist user corrections via UserDataRepository
- Use context (formality, domain) for future rule refinements

## 11. Maintenance and Updates

Security & validation guidelines:
- Input limits:
  - Max text length: recommend <= 10,000 characters per request (guard at UI/backend)
  - Supported languages: validate ISO 639-1 codes and pair format (e.g., en-ru)
- Malicious input handling:
  - PreProcessingLayer sanitizes HTML/Markdown; do not execute HTML/JS
  - Disallow binary data; normalize Unicode before processing
  - Avoid catastrophic regex: keep rules linear-time; test new regex offline
- API validation:
  - TranslationEngine.translate returns error for empty input; enforce text length and language allowlists in your app
  - Repositories validate data (e.g., language_pair format, non-empty fields); wrap bulk ops in transactions
- Secrets & PII:
  - Do not log user content at INFO; keep debugMode off in production
  - If storing history (user_data.db), ensure compliance with local data protection laws; allow user opt-out
- Resource constraints:
  - Configure timeouts via context.maxProcessingTimeMs in future extensions; currently enforce request time budgets at app level

Operational tips:
- Turn off debugMode in production
- Periodically call CacheManager.cleanupExpired() on long-running services
- Monitor pipeline.statistics and cache metrics; alert on rising error rates/latencies

- Follow CHANGELOG for new versions and migration notes
- Keep tests green (CI recommended: analyzer + tests)
- When adding new layers/rules, augment tests and update this guide
