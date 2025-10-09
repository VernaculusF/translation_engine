# Translation Engine

Offline translation engine for Flutter applications.

## Installation

```yaml
dependencies:
  translation_engine: ^0.0.3
```

## Usage

```dart
import 'package:translation_engine/translation_engine.dart';

final engine = TranslationEngine.instance();
await engine.initialize();

final result = await engine.translate(
  'Hello world',
  sourceLanguage: 'en',
  targetLanguage: 'ru',
);

print(result.translatedText);
```

## CLI Commands

```bash
# Download dictionaries
dart run bin/translate_engine.dart db

# Download specific language
dart run bin/translate_engine.dart db --lang=en-ru
```

## Features

- Offline translation with local dictionaries
- 6-layer processing pipeline
- SQLite storage with caching
- Command line tools

## License

Commercial license. See LICENSE file for details.
