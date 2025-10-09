# Translation Data Repository Setup Guide

Этот документ содержит инструкции по созданию отдельного GitHub репозитория с переводными данными для Translation Engine.

## 1. Создание репозитория

1. Создайте новый GitHub репозиторий: `translation-engine/translation-data`
2. Установите его как публичный для свободного доступа к данным
3. Добавьте описание: "Translation dictionaries and phrase data for Translation Engine"

## 2. Структура репозитория

```
translation-data/
├── README.md                    # Основное описание
├── LICENSE                      # Лицензия на данные
├── index.json                   # Индекс доступных языковых пар
├── schema.yaml                  # Схема форматов данных
├── data/                        # Основные данные
│   ├── en-ru_dictionary.csv     # Словарь английский-русский
│   ├── en-ru_dictionary.json    # То же в JSON
│   ├── en-ru_dictionary.jsonl   # То же в JSONL
│   ├── en-ru_phrases.csv        # Фразы английский-русский
│   ├── en-ru_phrases.json       # То же в JSON
│   ├── en-ru_phrases.jsonl      # То же в JSONL
│   ├── ru-en_dictionary.csv     # Обратное направление
│   ├── ru-en_phrases.csv        # 
│   ├── es-en_dictionary.csv     # Испанский-английский
│   ├── es-en_phrases.csv        #
│   └── ...                      # Другие языковые пары
├── sources/                     # Исходники и скрипты
│   ├── opus-extract.py          # Скрипт извлечения из OPUS
│   ├── wiktionary-scraper.py    # Парсер Wiktionary
│   └── tatoeba-converter.py     # Конвертер данных Tatoeba
└── tools/                       # Утилиты валидации
    ├── validate-data.py         # Валидация файлов данных
    └── generate-index.py        # Генерация index.json
```

## 3. Форматы файлов

### 3.1 Словарные файлы (dictionary)

**CSV format:**
```csv
source_word,target_word,language_pair,part_of_speech,definition,frequency
hello,привет,en-ru,interjection,greeting,100
world,мир,en-ru,noun,the earth,80
```

**JSON format:**
```json
[
  {
    "source_word": "hello",
    "target_word": "привет", 
    "language_pair": "en-ru",
    "part_of_speech": "interjection",
    "definition": "greeting",
    "frequency": 100
  }
]
```

**JSONL format:**
```jsonl
{"source_word": "hello", "target_word": "привет", "language_pair": "en-ru", "part_of_speech": "interjection", "definition": "greeting", "frequency": 100}
{"source_word": "world", "target_word": "мир", "language_pair": "en-ru", "part_of_speech": "noun", "definition": "the earth", "frequency": 80}
```

### 3.2 Фразовые файлы (phrases)

**CSV format:**
```csv
source_phrase,target_phrase,language_pair,category,context,confidence,frequency
"good morning","доброе утро",en-ru,greetings,formal,95,50
"how are you","как дела",en-ru,greetings,informal,90,45
```

**JSON format:**
```json
[
  {
    "source_phrase": "good morning",
    "target_phrase": "доброе утро",
    "language_pair": "en-ru", 
    "category": "greetings",
    "context": "formal",
    "confidence": 95,
    "frequency": 50
  }
]
```

## 4. Файл индекса (index.json)

```json
{
  "version": "1.0.0",
  "languages": [
    "en-ru", "ru-en",
    "en-es", "es-en",
    "en-fr", "fr-en", 
    "en-de", "de-en",
    "en-it", "it-en",
    "en-pt", "pt-en",
    "en-ja", "ja-en",
    "en-ko", "ko-en",
    "en-zh", "zh-en"
  ],
  "formats": ["csv", "json", "jsonl"],
  "data_types": ["dictionary", "phrases"],
  "last_updated": "2025-01-09T14:52:51Z",
  "total_entries": {
    "dictionaries": 50000,
    "phrases": 10000
  },
  "sources": [
    "OPUS parallel corpus",
    "Wiktionary",
    "Tatoeba",
    "OpenRussian"
  ]
}
```

## 5. Схема данных (schema.yaml)

```yaml
version: "1.0"
formats:
  csv:
    encoding: "utf-8"
    delimiter: ","
    quote_char: "\""
    
  json:
    encoding: "utf-8"
    type: "array"
    
  jsonl:
    encoding: "utf-8"
    type: "objects"

dictionary:
  required_fields:
    - source_word
    - target_word
    - language_pair
  optional_fields:
    - part_of_speech
    - definition  
    - frequency
  field_types:
    source_word: string
    target_word: string
    language_pair: string  # format: xx-yy
    part_of_speech: string
    definition: string
    frequency: integer

phrases:
  required_fields:
    - source_phrase
    - target_phrase
    - language_pair
  optional_fields:
    - category
    - context
    - confidence
    - frequency
  field_types:
    source_phrase: string
    target_phrase: string
    language_pair: string  # format: xx-yy
    category: string
    context: string
    confidence: integer    # 0-100
    frequency: integer
```

## 6. README.md для репозитория данных

```markdown
# Translation Engine Data Repository

This repository contains bilingual dictionaries and phrase translations for the Translation Engine library.

## Structure

- `data/` - Translation data files in CSV, JSON, and JSONL formats
- `index.json` - Index of available language pairs and metadata
- `schema.yaml` - Data format specification
- `sources/` - Scripts for extracting data from various sources
- `tools/` - Validation and maintenance utilities

## Usage

The Translation Engine CLI can automatically download and import this data:

```bash
# Download all languages
dart run bin/translate_engine.dart db

# Download specific language pair
dart run bin/translate_engine.dart db --lang=en-ru

# List available languages
dart run bin/translate_engine.dart db --list
```

## Data Sources

- **OPUS Parallel Corpus** - High-quality sentence alignments
- **Wiktionary** - Community-maintained multilingual dictionary
- **Tatoeba** - Sentence translations by native speakers
- **OpenRussian** - Russian language dictionary data

## Contributing

1. Fork this repository
2. Add new language pair data following the schema
3. Run validation: `python tools/validate-data.py`
4. Update index.json: `python tools/generate-index.py`  
5. Submit pull request

## License

The data in this repository is distributed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) license, compatible with the original sources.

## Data Quality

All entries are validated for:
- UTF-8 encoding
- Required field completeness
- Language pair format (xx-yy)
- Confidence scores (0-100 range)
- No duplicate entries per language pair
```

## 7. Пример данных

### Словарь en-ru (50 базовых слов)

```csv
source_word,target_word,language_pair,part_of_speech,definition,frequency
hello,привет,en-ru,interjection,greeting,100
world,мир,en-ru,noun,the earth,95
good,хороший,en-ru,adjective,positive quality,90
bad,плохой,en-ru,adjective,negative quality,85
yes,да,en-ru,adverb,affirmative,100
no,нет,en-ru,adverb,negative,100
please,пожалуйста,en-ru,adverb,polite request,80
thank,спасибо,en-ru,verb,express gratitude,95
you,ты,en-ru,pronoun,second person,100
me,я,en-ru,pronoun,first person,100
```

### Фразы en-ru (20 базовых фраз)

```csv
source_phrase,target_phrase,language_pair,category,context,confidence,frequency
"good morning","доброе утро",en-ru,greetings,formal,95,50
"good night","спокойной ночи",en-ru,greetings,formal,95,45
"how are you","как дела",en-ru,conversation,informal,90,60
"what's your name","как тебя зовут",en-ru,conversation,informal,95,40
"nice to meet you","приятно познакомиться",en-ru,conversation,formal,90,35
"excuse me","извините",en-ru,politeness,formal,95,55
"I'm sorry","мне жаль",en-ru,politeness,formal,90,45
"see you later","увидимся позже",en-ru,farewell,informal,85,30
```

## 8. Команды для настройки

```bash
# Создание репозитория
git clone https://github.com/translation-engine/translation-data.git
cd translation-data

# Создание структуры
mkdir -p data sources tools
touch README.md LICENSE index.json schema.yaml

# Добавление данных
# (создание CSV/JSON/JSONL файлов с переводами)

# Инициализация Git LFS для больших файлов
git lfs track "*.csv"
git lfs track "*.json"
git lfs track "*.jsonl"

# Коммит и пуш
git add .
git commit -m "Initial data repository structure"
git push origin main
```

## 9. Интеграция с основным репозиторием

В основном репозитории Translation Engine будет использоваться URL:
- `https://raw.githubusercontent.com/translation-engine/translation-data/main`

CLI команда будет загружать файлы по шаблону:
- `{source}/data/{lang-pair}_dictionary.{format}`
- `{source}/data/{lang-pair}_phrases.{format}`

## 10. Версионирование данных

- Используйте Git теги для версионирования: `v1.0.0`, `v1.1.0`, etc.
- Обновляйте поле `version` в index.json при каждом релизе
- Добавляйте записи в CHANGELOG.md при изменении данных