# Translation Engine - Data Repository Setup (FINAL)

## ✅ Что уже готово в Translation Engine

### 1. Новые компоненты реализованы
- ✅ **PhraseImporter** (`lib/src/tools/phrase_importer.dart`) - импорт фраз из CSV/JSON/JSONL  
- ✅ **DbCommand** (`bin/commands/db_command.dart`) - CLI команда для загрузки данных
- ✅ **ImportCommand** (`bin/commands/import_command.dart`) - CLI для локального импорта
- ✅ **BaseCommand** (`bin/commands/base_command.dart`) - базовый класс для команд
- ✅ **translate_engine.dart** (`bin/translate_engine.dart`) - главный CLI entry-point

### 2. CLI команды готовы к использованию

```bash
# Основная команда для загрузки данных
dart run bin/translate_engine.dart db

# Конкретная языковая пара  
dart run bin/translate_engine.dart db --lang=en-ru

# Просмотр доступных языков
dart run bin/translate_engine.dart db --list

# Импорт локальных файлов
dart run bin/translate_engine.dart import --db=./data --file=dict.csv --format=csv --lang=en-ru
```

### 3. Примеры данных созданы
- ✅ `sample_data/en-ru_dictionary.csv` - 50 базовых словарных записей
- ✅ `sample_data/en-ru_phrases.csv` - 20 базовых фраз
- ✅ `sample_data/index.json` - индекс языковых пар  
- ✅ `sample_data/schema.yaml` - схема форматов данных

### 4. Документация обновлена
- ✅ `docs/USAGE_AND_DEV_GUIDE.md` - добавлены инструкции по работе с данными
- ✅ `DATA_REPOSITORY_SETUP.md` - полное руководство по созданию репозитория

## 📋 Следующие шаги для создания репозитория данных

### 1. Создание GitHub репозитория

```bash
# 1. Создайте новый репозиторий на GitHub
# Название: translation-engine/translation-data
# Доступ: Public
# Описание: "Translation dictionaries and phrase data for Translation Engine"

# 2. Клонируйте локально
git clone https://github.com/translation-engine/translation-data.git
cd translation-data

# 3. Создайте структуру
mkdir -p data sources tools
touch README.md LICENSE
```

### 2. Структура файлов в репозитории

```
translation-data/
├── README.md                    # Основное описание репозитория
├── LICENSE                      # CC BY-SA 4.0 или совместимая 
├── index.json                   # Индекс доступных языков
├── schema.yaml                  # Схема форматов данных
├── data/                        # Основные данные
│   ├── en-ru_dictionary.csv     # Словарь EN→RU
│   ├── en-ru_dictionary.json    # То же в JSON
│   ├── en-ru_dictionary.jsonl   # То же в JSONL
│   ├── en-ru_phrases.csv        # Фразы EN→RU
│   ├── en-ru_phrases.json       # То же в JSON
│   ├── en-ru_phrases.jsonl      # То же в JSONL
│   ├── ru-en_dictionary.csv     # Обратное направление
│   ├── ru-en_phrases.csv
│   └── ... (другие языковые пары)
├── sources/                     # Скрипты для сбора данных
│   ├── opus-extract.py          # Извлечение из OPUS
│   ├── wiktionary-scraper.py    # Парсинг Wiktionary
│   └── tatoeba-converter.py     # Конвертация Tatoeba
└── tools/                       # Утилиты
    ├── validate-data.py         # Валидация файлов
    └── generate-index.py        # Генерация index.json
```

### 3. Копирование готовых файлов

```bash
# Из Translation Engine скопируйте готовые примеры:
cp /path/to/translation_engine/sample_data/* ./

# Переименуйте файлы по нужной структуре:
mv en-ru_dictionary.csv data/en-ru_dictionary.csv
mv en-ru_phrases.csv data/en-ru_phrases.csv
mv index.json ./index.json
mv schema.yaml ./schema.yaml
```

### 4. README.md для data-repository

```markdown
# Translation Engine Data Repository

This repository contains bilingual dictionaries and phrase translations for the Translation Engine library.

## Quick Start

The Translation Engine CLI automatically downloads and imports this data:

```bash
# Download all languages
dart run bin/translate_engine.dart db

# Download specific language pair
dart run bin/translate_engine.dart db --lang=en-ru

# List available languages  
dart run bin/translate_engine.dart db --list
```

## Data Formats

- **CSV**: Simple comma-separated values with headers
- **JSON**: Array of objects 
- **JSONL**: One JSON object per line

## Language Pairs Available

- English ↔ Russian (en-ru, ru-en)
- English ↔ Spanish (en-es, es-en)
- English ↔ French (en-fr, fr-en)
- English ↔ German (en-de, de-en)
- English ↔ Italian (en-it, it-en)
- English ↔ Portuguese (en-pt, pt-en)

## Data Sources

- OPUS Parallel Corpus
- Wiktionary
- Tatoeba
- OpenRussian

## License

Data is distributed under CC BY-SA 4.0 license.
```

### 5. Настройка Git LFS (опционально)

```bash
# Для больших файлов данных
git lfs track "*.csv"
git lfs track "*.json"
git lfs track "*.jsonl"
git add .gitattributes
```

### 6. Первый коммит

```bash
git add .
git commit -m "Initial translation data repository

- Added en-ru dictionary (50 entries)
- Added en-ru phrases (20 entries)  
- Added index.json with metadata
- Added schema.yaml with format specification
- Added README with usage instructions"

git push origin main
```

### 7. Тестирование интеграции

```bash
# Перейдите в Translation Engine и протестируйте:
cd /path/to/translation_engine

# Проверьте список языков (должен падать пока репозитория нет)
dart run bin/translate_engine.dart db --list

# После создания репозитория - повторите тест
dart run bin/translate_engine.dart db --dry-run --lang=en-ru
```

## 🔄 Workflow после создания

### Добавление новых языковых пар

1. Создайте файлы в формате `{lang-pair}_dictionary.{format}` и `{lang-pair}_phrases.{format}`
2. Обновите `index.json` - добавьте языковую пару в массив `languages`
3. Обновите статистику в `index.json`
4. Создайте коммит с версионным тегом: `git tag v1.1.0`

### Поддержка версий

- **Основные изменения** (новые языки): `v1.1.0 → v1.2.0`
- **Дополнения к существующим**: `v1.1.0 → v1.1.1`  
- **Исправления**: `v1.1.1 → v1.1.2`

### Автоматизация (будущее)

- GitHub Actions для валидации PR
- Автоматическая генерация index.json
- Проверка форматов данных
- Статистика покрытия языков

## ⚠️ Важные замечания

1. **Не сломайте** существующий код Translation Engine - новый CLI сохраняет обратную совместимость
2. **URL для данных**: `https://raw.githubusercontent.com/translation-engine/translation-data/main`
3. **Формат файлов**: строго следуйте schema.yaml для совместимости
4. **Лицензии**: убедитесь что все данные совместимы с CC BY-SA 4.0

## 🎯 Результат

После выполнения этих шагов пользователи смогут:

```bash
# Скачать все доступные языки одной командой
dart run bin/translate_engine.dart db

# Работать с конкретными языками
dart run bin/translate_engine.dart db --lang=en-ru --db=./my_data

# Импортировать свои данные
dart run bin/translate_engine.dart import --db=./data --file=my_dict.csv --lang=en-ru
```

CLI будет автоматически:
- Загружать данные из GitHub
- Импортировать в локальные SQLite базы
- Показывать прогресс и статистику
- Обрабатывать ошибки

**Translation Engine готов к работе с внешними данными! 🚀**