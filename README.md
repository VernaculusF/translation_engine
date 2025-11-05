# fluent_translate

Offline translation engine for Flutter with JSON/JSONL file-based storage.

⚠️ **Important Notice**: This is an early development version with limited vocabulary and phrase coverage. The translation quality and feature set are actively being expanded. APIs and behavior may change in future versions.

## Installation

Add `fluent_translate` to your `pubspec.yaml`:

```yaml
dependencies:
  fluent_translate: ^0.0.12
```

Then run:
```bash
flutter pub get
```

## Quick Start

### 1. Basic Setup

```dart
import 'package:fluent_translate/fluent_translate.dart';

// Initialize the translation engine
final engine = TranslationEngine();
```

### 2. Initialize with Translation Data

Before using the engine, you need to initialize it with translation data:

```dart
// Initialize with custom database path
await engine.initialize(customDatabasePath: './translation_data');

// Or initialize with default path
await engine.initialize();
```

### 3. Download Translation Data (ZIP bundles)

Use the CLI to download a zipped bundle per language pair from the data repo; the archive is extracted into the DB folder and removed automatically.

```bash
# List available language pairs
dart run fluent_translate:translate_engine db --list

# Download English→Russian (downloads zip/en-ru.zip and extracts into ./translation_data)
dart run fluent_translate:translate_engine db --lang=en-ru --db=./translation_data

# Download from a custom source (optional)
# Default source: https://raw.githubusercontent.com/VernaculusF/translation-engine-data/main
# Expected path: <source>/zip/<lang>.zip
# Example (explicit):
dart run fluent_translate:translate_engine db \
  --source=https://raw.githubusercontent.com/VernaculusF/translation-engine-data/main \
  --lang=en-ru --db=./translation_data

# Download all available language pairs
dart run fluent_translate:translate_engine db --db=./translation_data
```

### 4. Perform Translation

```dart
// Translate text
final result = await engine.translate(
  'Hello world',
  sourceLanguage: 'en',
  targetLanguage: 'ru',
);

print('Original: ${result.originalText}');
print('Translation: ${result.translatedText}');
print('Source: ${result.sourceLanguage}');
print('Target: ${result.targetLanguage}');
```

### 5. Complete Example

```dart
import 'package:fluent_translate/fluent_translate.dart';

void main() async {
  // Create and initialize the engine
  final engine = TranslationEngine();
  await engine.initialize(customDatabasePath: './translation_data');
  
  try {
    // Translate a simple phrase
    final result = await engine.translate(
      'Good morning',
      sourceLanguage: 'en',
      targetLanguage: 'ru',
    );
    
    print('Translation: ${result.translatedText}');
  } catch (e) {
    print('Translation error: $e');
  }
}
```

## Current Limitations

- **Limited Vocabulary**: The current version includes a small set of words and phrases. Translation coverage will be expanded in future releases.
- **Basic Grammar Rules**: Complex grammatical structures may not be handled correctly.
- **Language Pairs**: Currently focused on specific language combinations. More pairs will be added progressively.
- **Offline Only**: No online fallback for unknown words or phrases.

## Features

- ✅ **Offline Translation**: Works completely offline with local JSON/JSONL files (UTF‑8/UTF‑16 supported with BOM/autodetect)
- ✅ **Multi-layer Processing**: 6-layer translation pipeline (phrases → dictionary → grammar → word order → post-processing)
- ✅ **Phrase Support**: Exact and n‑gram phrase matching with punctuation-tolerant lookup; protected ranges prevent overwriting by later layers
- ✅ **Dictionary Management**: Built-in CLI for downloading and managing translation data (ZIP bundles)
- ✅ **Caching**: Efficient file-based caching for improved performance
- ✅ **Flutter Integration**: Designed specifically for Flutter applications
- ✅ **Error Handling**: Comprehensive error handling and fallback mechanisms

## Supported Languages

Currently available language pairs (more to be added):
- English → Russian (en-ru)
- _(Additional language pairs coming soon)_

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
