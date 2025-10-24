# fluent_translate

Offline translation engine for Flutter with JSON/JSONL file-based storage.

Note: This is an early test version. APIs and behavior may change.

## Installation

```yaml
dependencies:
  fluent_translate: ^0.0.1
```

## Quick start (library)

```dart
import 'package:fluent_translate/fluent_translate.dart';

final engine = TranslationEngine();
await engine.initialize(customDatabasePath: './translation_data');

final result = await engine.translate(
  'Hello world',
  sourceLanguage: 'en',
  targetLanguage: 'ru',
);
print(result.translatedText);
```

## Data preparation from an external app

Use the published CLI entrypoint shipped with this package. Run these from your app project where `fluent_translate` is a dependency:

- List available language pairs:
  ```sh
  dart run fluent_translate:translate_engine db --list
  ```
- Download English→Russian into `./translation_data`:
  ```sh
  dart run fluent_translate:translate_engine db --lang=en-ru --db=./translation_data
  ```
- Download all available pairs:
  ```sh
  dart run fluent_translate:translate_engine db --db=./translation_data
  ```

For Flutter Web, initialize the engine on a backend server and call it via REST from the client.

## License

MIT (for testing purposes).
