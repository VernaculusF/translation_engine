# MIGRATION: SQLite -> JSON/JSONL storage

This guide explains how to migrate from the legacy SQLite-backed data layer to the new file-based JSON/JSONL storage.

## Summary of changes
- Replaced SQLite databases with JSON/JSONL files under `translation_data/`
- Removed dependencies on `sqflite` and `sqflite_common_ffi`
- Repositories (`DictionaryRepository`, `PhraseRepository`, `UserDataRepository`) now operate on files
- CLI commands `db` and `import` now work with files only

## Data layout
```
translation_data/
  en-ru/
    dictionary.jsonl
    phrases.jsonl
    metadata.json (optional)
  user/
    translation_history.jsonl
    user_settings.json
    user_translation_edits.jsonl
```

## How to migrate existing data
1) Export your existing tables from SQLite to JSONL/CSV.
   - If you have existing `.db` files, export them with your preferred tool or script.
2) Run the CLI importer to convert into JSONL storage:
   ```powershell
   dart run bin/translate_engine.dart import --db=./translation_data --file=./exports/en-ru_dictionary.csv --format=csv --lang=en-ru
   dart run bin/translate_engine.dart import --db=./translation_data --file=./exports/en-ru_phrases.csv --format=csv --lang=en-ru
   ```
3) Verify data:
   ```powershell
   dart run bin/check_database.dart --db=./translation_data --lang=en-ru
   ```

## Engine initialization
The `customDatabasePath` parameter in `TranslationEngine.initialize()` is now treated as a data directory path.
```dart
await engine.initialize(customDatabasePath: './translation_data');
```

## Breaking changes
- Removed SQLite APIs and types. Any direct usage of DatabaseManager should be deleted.
- Repositories no longer expose SQL transaction helpers; they perform file rewrites internally.
- Tests relying on SQLite must be updated to JSONL fixtures.

## Validation and indexing
- Files are line-oriented JSON (JSONL). The repositories keep an in-memory index per language pair.
- For large datasets, consider pre-generating `metadata.json` with counts/checksums and keeping data compressed externally.

## Troubleshooting
- If files are malformed, the repository will skip broken lines.
- Use the importer `--format=jsonl` or `--format=csv` to re-create data consistently.
