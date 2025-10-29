# CLI команды — справочник (через пакет fluent_translate)

Вызов всех команд идёт через исполняемый бин пакета:
- Формат: `dart run fluent_translate:translate_engine <command> [options]`

Команды данных
- db — загрузка и управление файлами данных из удалённого репозитория
  - Опции:
    - `--lang=<xx-yy>` язык (например, en-ru). Если не указан — все доступные
    - `--db=<dir>` каталог базы (по умолчанию `./translation_data`)
    - `--source=<url>` альтернативный HTTPS-источник
    - `--list` вывести доступные языковые пары без загрузки
    - `--force` перезагрузить при наличии файлов
    - `--sha256=<prefix>` ожидаемый префикс SHA-256 хэша (проверка целостности)
    - `--allow-any-source` ослабить политику источников (по умолчанию allowlist github*)
    - `--dry-run` показать, что будет скачано, без фактической загрузки
  - Примеры:
    - `dart run fluent_translate:translate_engine db --list`
    - `dart run fluent_translate:translate_engine db --lang=en-ru --db=./translation_data`

- import — импорт слов/фраз из файлов (CSV/JSON/JSONL)
  - Пример: `dart run fluent_translate:translate_engine import --file=./data/dict.jsonl --lang=en-ru --db=./translation_data`
- export — экспорт данных в файлы
  - Пример: `dart run fluent_translate:translate_engine export --type=dict --lang=en-ru --out=./out`
- validate — валидация файлов данных
  - Пример: `dart run fluent_translate:translate_engine validate --db=./translation_data`

Наблюдаемость и конфигурация
- metrics — показать снимок метрик движка/кэша/очереди/таймаутов/логирования
  - `dart run fluent_translate:translate_engine metrics --db=./translation_data`

- config — показать/применить конфигурацию движка
  - `config show [--db=<dir>]`
  - `config set --file=<path> [--db=<dir>]`
  - Примеры:
    - `dart run fluent_translate:translate_engine config show`
    - `dart run fluent_translate:translate_engine config set --file=engine_config.json`

- logs — управление логированием
  - `logs level <error|warn|info|debug>` — выставить уровень и включить логирование
  - `logs enable` — включить
  - `logs disable` — выключить
  - Примеры:
    - `dart run fluent_translate:translate_engine logs level info`
    - `dart run fluent_translate:translate_engine logs disable`

Кэш и очередь
- cache — статистика/очистка кэша
  - `cache stats`
  - `cache clear [words|phrases|all]`
  - Примеры:
    - `dart run fluent_translate:translate_engine cache stats`
    - `dart run fluent_translate:translate_engine cache clear words`

- queue — статус очереди
  - `queue stats`
  - Пример: `dart run fluent_translate:translate_engine queue stats`

Обслуживание движка
- engine — команды обслуживания
  - `engine reset` — мягкий сброс состояния
  - Пример: `dart run fluent_translate:translate_engine engine reset`

Примечания
- По умолчанию используется `./translation_data` (можно переопределить флагом `--db`).
- Логи — структурированный JSON в stdout; при необходимости перенаправляйте в файл (пример PowerShell: `... | Tee-Object -FilePath .\engine.log`).
- Для программного использования (без CLI) см. примеры в README/доках ядра.
