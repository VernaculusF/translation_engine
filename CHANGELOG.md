# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.0.12] - 2025-10-26
### Added
- Enhanced translation pipeline functionality
- Improved error handling and stability
- Better performance optimizations

### Fixed
- Translation accuracy improvements
- Bug fixes in dictionary and phrase processing

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

## [0.0.1] - 2025-01-09
### Added
- Initial release of offline translation engine for Flutter.
- CLI for dictionary/phrases management.
- 6-layer translation pipeline with preprocessing, dictionary lookup, grammar rules, and post-processing.
- File-based JSON/JSONL storage with caching.
- Automatic dictionary downloads.
- Public API with basic error handling.
