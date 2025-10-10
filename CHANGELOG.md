# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] - 2025-10-10

### Breaking
- Полный переход с SQLite-хранилища на файловое JSON/JSONL хранилище (без зависимостей от sqflite/sqflite_ffi)
- Удалены DatabaseManager/DatabaseManagerFfi и связанные API. Репозитории работают через FileStorageService и каталог данных
- Параметр инициализации движка: вместо пути к SQLite теперь используется путь к каталогу данных: `initialize(customDatabasePath: <path_to_translation_data>)`
- Публичные репозитории (DictionaryRepository, PhraseRepository, UserDataRepository) больше не принимают `databaseManager`; вместо этого требуется `dataDirPath`

### Added
- FileStorageService: чтение/запись JSONL (по одной JSON-записи на строку), директория `translation_data/` c поддиректориями на языковые пары и пользовательскими файлами (`user/*.json(l)`)
- CLI команды обновлены под файл-бэкенд:
  - `db` — загрузка данных из внешнего репозитория (по умолчанию https://github.com/VernaculusF/translation-engine-data) и импорт в JSONL
  - `import` — импорт словарей из CSV/JSON/JSONL в файловое хранилище
  - `export` — экспорт в CSV/JSON/JSONL
  - `validate` — простая валидация структуры данных
- Тесты переписаны под файловое хранилище (unit/integration), устаревшие SQLite-тесты заглушены

### Changed
- TranslationEngine и Pipeline инициализируют репозитории через путь к данным
- Сохранены публичные методы репозиториев (addTranslation/getTranslation и т.п.), но внутренняя реализация использует JSONL + кэш в памяти

### Migration
1) Удалите зависимости от SQLite (sqflite, sqflite_common_ffi) и все обращения к DatabaseManager
2) Создайте/укажите каталог данных (например, `./translation_data`) и инициализируйте движок: `await engine.initialize(customDatabasePath: '<path>')`
3) Импортируйте данные:
   - С внешнего репозитория: `dart run bin/translate_engine.dart db --lang=en-ru --db=./translation_data`
   - Или локально: `dart run bin/translate_engine.dart import --db=./translation_data --file=... --format=csv|json|jsonl --lang=<xx-yy>`
4) Обновите внешний app (translator_app) на новый путь инициализации; Web не поддерживается (dart:io) — потребуется альтернативный сторедж

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
