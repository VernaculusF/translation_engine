# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.0.11] - 2025-10-25
### Added
- PhraseTranslationLayer: exact phrase lookup using phrases.jsonl (returns phrase translation when full phrase matches).
- Tests: dictionary_single_letter_test (no partial matches for 1-letter tokens), phrase_exact_lookup_test (exact phrase translation).

### Fixed
- DictionaryLayer: prevent partial contains-search for 1-letter tokens to avoid false positives like 'i' -> 'family'.
- DictionaryLayer: tokenizes current text locally to ensure sequential layer processing.

### Docs
- README: Variant A CLI instructions and public API quick start.
- DEVELOPMENT_STAGES: started Stage 1 (API stabilization).

## [0.0.4] - 2025-10-09
### Fixed
- CLI scripts migrated to file-based JSON/JSONL storage and external `--db` path; removed Flutter dependencies from CLI.
- Completed `populate_dictionary.dart` to fill only external DB; no local DB inside the package.
- `check_database.dart`: stats check and optional test data insertion via `--populate`.
- `test_cli.dart`: allow `--db` and verify end-to-end pipeline.

### Internal
- Analyzer clean (dart analyze).
- Integration and debug tests green.

## [0.0.3] - 2025-10-09
### Changed
- Pipeline: dynamic per-layer canProcess evaluation so downstream layers (Dictionary, Phrase) run after PreProcessing. Fixes the "no translation despite data" issue and enables actual word translations.
- Updated debug scripts/tests to current APIs and to use a local file-based DB path for Windows debugging.
- Docs: README dependency version bumped; usage unchanged.

### Fixed
- Ensured data layout matches repositories (words/phrases use source*/target* and language_pair; timestamps present). Integration tests confirm integrity.

### Tooling
- Verified `db` command flow for downloading/importing dictionaries/phrases into a specified folder (e.g., `./translation_data`) on Windows.

## [0.0.2] - 2025-01-09
### Changed
- Documentation simplified and aligned; English-only content.
- README reduced to essentials.

## [0.0.1] - 2025-01-09
### Added
- Initial release of offline translation engine for Flutter.
- CLI for dictionary/phrases management.
- 6-layer translation pipeline with preprocessing, dictionary lookup, grammar rules, and post-processing.
- File-based JSON/JSONL storage with caching.
- Automatic dictionary downloads.
- Public API with basic error handling.
