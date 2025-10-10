# fluent_translate

Offline translation engine for Flutter with JSON/JSONL file-based storage.

Note: This is an early test version. APIs and behavior may change.

## Installation

```yaml
dependencies:
  fluent_translate: ^0.0.1
```

## Quick start

```dart
import 'package:fluent_translate/src/core/translation_engine.dart';

final engine = TranslationEngine.instance(reset: true);
await engine.initialize(customDatabasePath: './translation_data');

final result = await engine.translate(
  'Hello world',
  sourceLanguage: 'en',
  targetLanguage: 'ru',
);
print(result.translatedText);
```

## License

MIT (for testing purposes).
