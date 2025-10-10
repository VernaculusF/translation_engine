# Fluent Translate: Usage (English)

Status: early test version.

This package provides an offline, layered translation engine with JSONL file storage for dictionaries and phrases.

- Package name: fluent_translate
- Storage backend: JSONL files
- Default data folder: ./translation_data

1) Install

Add to your pubspec.yaml:

```
dependencies:
  fluent_translate: ^0.0.1
```

Then install:

```
dart pub get
```

2) Prepare data files

Option A: Use the built-in CLI to download data from the external data repo

- Download English→Russian to ./translation_data
```
dart run fluent_translate:translate_engine db --lang=en-ru --db=./translation_data
```
- List available language pairs
```
dart run fluent_translate:translate_engine db --list
```
- Download all available pairs
```
dart run fluent_translate:translate_engine db --db=./translation_data
```

Option B: Import your own CSV/JSON/JSONL

Use the import utilities programmatically (CSV, JSON array, JSON Lines). Example (dictionary):

```dart
import 'dart:io';
import 'package:fluent_translate/src/data/dictionary_repository.dart';
import 'package:fluent_translate/src/tools/dictionary_importer.dart';
import 'package:fluent_translate/src/utils/cache_manager.dart';

Future<void> importSample() async {
  final repo = DictionaryRepository(
    dataDirPath: './translation_data',
    cacheManager: CacheManager(),
  );
  final importer = DictionaryImporter(repository: repo);
  await importer.importFile(
    File('en-ru_dictionary.jsonl'),
    languagePair: 'en-ru',
    format: 'jsonl',
  );
}
```

3) Quick start (Dart/Flutter)

```dart
import 'package:fluent_translate/fluent_translate.dart';

Future<void> main() async {
  final engine = TranslationEngine();
  await engine.initialize(customDatabasePath: './translation_data');

  final result = await engine.translate(
    'Hello, world!',
    sourceLanguage: 'en',
    targetLanguage: 'ru',
  );

  if (result.hasError) {
    print('Error: ${result.errorMessage}');
  } else {
    print('Translated: ${result.translatedText}');
  }
}
```

4) Data layout

- Dictionary: translation_data/{langPair}/dictionary.jsonl
- Phrases: translation_data/{langPair}/phrases.jsonl
- User data: translation_data/user/
  - translation_history.jsonl
  - user_settings.json
  - user_translation_edits.jsonl

5) Flutter integration tip

Use path_provider to choose an app directory, then pass its path into initialize(customDatabasePath: ...) so the engine stores files under the app’s sandbox.

6) Cache control

- Clear all caches
```
await engine.clearCache(type: 'all');
```

7) Notes

- This is an early test version focused on JSONL storage and a stable minimal API.
- Some commands and APIs may evolve; follow pub.dev updates.
