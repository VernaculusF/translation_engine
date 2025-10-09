# Changelog

All notable changes to this project will be documented in this file.

## [0.0.4] - 2025-10-09

### Fixed
- CLI скрипты переведены на FFI-менеджер БД и работу с внешним путём (--db), без Flutter-зависимостей
- Завершён populate_dictionary.dart: наполнение ТОЛЬКО во внешнюю БД, никаких локальных БД внутри пакета
- check_database.dart: проверка статистики, безопасное (опциональное) добавление тестовых данных флагом --populate
- test_cli.dart: возможность указать --db и тестировать финальный перевод по конвейеру

### Internal
- Анализатор: без предупреждений (flutter analyze)
- Интеграционные и debug-тесты проходят (flutter test)

## [0.0.3] - 2025-10-09

### Changed
- Pipeline: dynamic per-layer canProcess evaluation so downstream layers (Dictionary, Phrase) run after PreProcessing. This fixes the "no translation despite data" issue and enables actual word translations.
- Debug scripts/tests updated to current APIs (DictionaryRepository.searchByWord, TranslationResult.layerResults) and to use a local FFI database path for Windows debugging.
- Documentation: README dependency version bumped and usage remains the same.

### Fixed
- Ensured database schema matches tests and repositories (words/phrases use source_*/target_* and language_pair; timestamps present). Integration tests confirm integrity.

### Tooling
- Verified CLI db command flow for downloading and importing dictionaries/phrases into a specified folder (e.g., .\\translation_data) on Windows.

## [0.0.2] - 2025-01-09

### Changed
- Cleaned documentation to English only
- Simplified README with essential information

## [0.0.1] - 2025-01-09

### Added
- Initial release of offline translation engine for Flutter
- CLI for dictionary management
- 6-layer translation pipeline with preprocessing, dictionary lookup, grammar rules, and post-processing
- SQLite storage with LRU caching
- Automatic dictionary downloads
- Production-ready API with comprehensive error handling
