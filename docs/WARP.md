# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is an offline translation engine for Flutter applications with a 6-layer processing pipeline. It uses SQLite databases for dictionary storage and provides both programmatic API and CLI tools for managing translation data.

## Key Commands

### Building & Testing
```powershell
# Install dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run all tests
flutter test

# Run specific test files
flutter test test/debug_translation_test.dart
flutter test test/e2e/pipeline_e2e_test.dart

# Run benchmarks
flutter test test/benchmarks/perf_benchmarks_test.dart
flutter test test/benchmarks/perf_report_test.dart
```

### CLI Operations
```powershell
# Download translation databases (all languages)
dart run bin/translate_engine.dart db

# Download specific language pair
dart run bin/translate_engine.dart db --lang=en-ru

# List available languages
dart run bin/translate_engine.dart db --list

# Import dictionary from CSV file
dart run bin/translate_engine.dart import --db .\data --file .\datasets\dict.csv --format csv --lang en-ru

# Import from JSON/JSONL
dart run bin/translate_engine.dart import --db .\data --file .\datasets\dict.json --format json --lang en-ru
```

## Architecture Overview

### Core Components

**TranslationEngine**: Singleton entry point managing the entire translation lifecycle. Handles initialization, state management, and provides high-level translation API.

**TranslationPipeline**: Orchestrates the 6-layer processing pipeline in sequence:
1. **PreProcessing**: Text sanitization and tokenization
2. **PhraseLookup**: Multi-word phrase translation
3. **Dictionary**: Word-level dictionary lookup
4. **Grammar**: Grammatical adjustments
5. **WordOrder**: Word order corrections
6. **PostProcessing**: Final formatting and cleanup

**BaseTranslationLayer**: Abstract base class all layers inherit from. Provides metrics, debug info, and standardized processing interface.

### Data Layer Architecture

**DatabaseManager**: Creates and manages 3 SQLite databases:
- `dictionaries.db`: Word translations with metadata
- `phrases.db`: Phrase/idiom translations
- `user_data.db`: User history, corrections, settings

**Repositories**: Type-safe data access layers
- `DictionaryRepository`: Word-level translation data
- `PhraseRepository`: Multi-word phrase data  
- `UserDataRepository`: User customizations and history

**CacheManager**: In-memory LRU cache with configurable limits (10k words, 5k phrases, 30min TTL)

### Key Data Flow

1. Text enters via `TranslationEngine.translate()`
2. `TranslationContext` carries metadata through pipeline
3. Each layer processes sequentially, updating context metadata
4. Results aggregated into `TranslationResult` with debug info
5. Cache and statistics updated

## Directory Structure

- `lib/src/core/`: Main engine and pipeline logic
- `lib/src/layers/`: 6 processing layers implementing BaseTranslationLayer
- `lib/src/data/`: Database managers and repositories
- `lib/src/models/`: Data models (TranslationResult, LayerDebugInfo)
- `lib/src/tools/`: Import utilities for dictionaries/phrases
- `bin/`: CLI commands for data management
- `test/`: Comprehensive test suite including benchmarks and E2E tests

## Development Guidelines

### Layer Development
- Extend `BaseTranslationLayer`
- Implement `canHandle()` for conditional processing
- Use context metadata to pass data between layers
- Return appropriate `LayerResult` (success/error/noChange)
- Include detailed debug information

### Context Usage
The `TranslationContext` object carries:
- Language pair and translation mode
- Processing constraints (timeouts, confidence thresholds)
- Layer metadata (tokens, translations, etc.)
- User preferences (forced translations, exclusions)

### Testing Strategy
- Unit tests per layer in `test/layers/`
- Integration tests in `test/integration/`
- E2E pipeline tests in `test/e2e/`
- Performance benchmarks in `test/benchmarks/`
- Database helpers for test isolation

### Database Population
Use the CLI for data import rather than manual SQL. The repositories handle validation and normalization:
- Words normalized to lowercase
- Automatic timestamp management
- Transaction wrapping for bulk operations
- Cache invalidation on updates

## Performance Considerations

### Caching Strategy
- Words cache: 10,000 items, 30min TTL
- Phrases cache: 5,000 items, 30min TTL  
- LRU eviction policy
- Cache-first lookup with fallback to database

### Processing Pipeline
- Layers process sequentially but can skip via `canHandle()`
- Pipeline tracks per-layer timing and success metrics
- Debug mode adds detailed timing information
- Short-circuit on critical errors

### Memory Management
- SQLite with connection pooling via DatabaseManager
- Repositories use prepared statements
- Cache limits prevent unbounded growth
- Statistics tracking for monitoring

## Error Handling

- `EngineInitializationException`: Setup failures
- `EngineStateException`: Invalid state transitions
- `LayerException`: Layer-specific processing errors
- `DatabaseQueryException`: Data access issues
- `ValidationException`: Invalid input data

All errors include context for debugging and can be surfaced through the `TranslationResult.error()` factory.

## Language Support

Currently focused on English-Russian (en-ru) but architecture supports any language pair. Language codes use ISO 639-1 standard. Database schemas are language-agnostic.