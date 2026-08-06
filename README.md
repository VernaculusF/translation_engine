# fluent_translate

Offline translation engine for Dart and Flutter applications. It processes local JSON and JSONL translation data through a rule-based pipeline without an online translation service.

## Features

- Offline translation with local dictionaries and phrase data
- Layered processing for phrases, dictionary entries, grammar, word order, and post-processing
- Exact and n-gram phrase matching
- File-based caching and UTF-8/UTF-16 input support
- CLI commands for downloading and managing translation data bundles
- English-to-Russian data support in the current release

The project is under active development. Vocabulary coverage and grammar rules are limited, and public APIs may change.

## Stack

- Dart 3.9+
- Flutter
- JSON and JSONL storage
- Dart CLI
- `flutter_test`, `test`, and Mockito

## Quick start

Add the package to an application:

```yaml
dependencies:
  fluent_translate: ^0.0.12
```

Install dependencies and download translation data:

```bash
flutter pub get
dart run fluent_translate:translate_engine db --list
dart run fluent_translate:translate_engine db --lang=en-ru --db=./translation_data
```

Initialize and use the engine:

```dart
import 'package:fluent_translate/fluent_translate.dart';

Future<void> main() async {
  final engine = TranslationEngine();
  await engine.initialize(customDatabasePath: './translation_data');

  final result = await engine.translate(
    'Hello world',
    sourceLanguage: 'en',
    targetLanguage: 'ru',
  );

  print(result.translatedText);
}
```

For repository development:

```bash
flutter pub get
flutter test
dart run bin/translate_engine.dart --help
```

## Project structure

- `lib/fluent_translate.dart` — public library entry point
- `lib/src/core/` — engine configuration and translation pipeline
- `lib/src/layers/` — rule-based processing layers
- `lib/src/data/` — repositories and translation data access
- `lib/src/tools/` — dictionary and phrase import utilities
- `bin/` — CLI entry point and commands
- `example/` — usage examples
- `test/` — unit, integration, end-to-end, and benchmark tests
- `docs/` — developer and rule-authoring documentation

## License

The project is distributed under the terms in `LICENSE`.
