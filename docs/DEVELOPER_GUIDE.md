# Translation Engine - Руководство разработчика

> **Версия документа**: 1.0  
> **Дата последнего обновления**: 2025-10-29  
> **Статус проекта**: Ранняя стадия разработки (v0.0.12)

---

## 📋 Оглавление

1. [Обзор проекта](#обзор-проекта)
2. [Архитектура системы](#архитектура-системы)
3. [Слои обработки](#слои-обработки)
4. [Репозитории данных](#репозитории-данных)
5. [CLI и точки входа](#cli-и-точки-входа)
6. [Конфигурация и настройка](#конфигурация-и-настройка)
7. [Правила разработки](#правила-разработки)
8. [Тестирование](#тестирование)
9. [Известные ограничения](#известные-ограничения)
10. [Дорожная карта](#дорожная-карта)

---

## 🎯 Обзор проекта

**translation_engine** (пакет `fluent_translate`) — оффлайн движок перевода текста для Flutter/Dart с многослойной обработкой и файловым хранилищем данных (JSONL). При обращении называть "Ядро".

### Ключевые характеристики

- **Оффлайн работа**: полностью автономная работа без сетевых запросов после загрузки словарей
- **Многослойная архитектура**: 6 слоев обработки текста с возможностью расширения
- **JSONL-хранилище**: файловая система для словарей, фраз и правил
- **CLI-интерфейс**: утилиты для загрузки данных, импорта/экспорта, валидации
- **Метрики и отладка**: встроенная система логирования, трассировки и метрик

### Текущий статус

- ✅ Базовая функциональность всех слоёв реализована
- ✅ JSONL-хранилище и репозитории работают
- ✅ CLI-команды доступны через `dart run fluent_translate:translate_engine`
- ⚠️ Ограниченный словарный запас (расширяется)
- ⚠️ Упрощённые грамматические правила (требуют доработки)
- ⚠️ Базовая поддержка языковых пар (en-ru приоритет)

---

## 🏗️ Архитектура системы

### Основные компоненты

```
translation_engine/
├── bin/                          # CLI entry points
│   ├── translate_engine.dart     # Главная точка входа CLI
│   └── commands/                 # Реализация CLI команд
│       ├── db_command.dart       # Загрузка словарей
│       ├── import_command.dart   # Импорт данных
│       ├── export_command.dart   # Экспорт данных
│       ├── validate_command.dart # Валидация файлов
│       ├── metrics_command.dart  # Метрики движка
│       ├── config_command.dart   # Конфигурация
│       ├── logs_command.dart     # Управление логами
│       ├── cache_command.dart    # Управление кэшем
│       ├── queue_command.dart    # Статистика очереди
│       └── engine_command.dart   # Обслуживание движка
│
├── lib/
│   ├── fluent_translate.dart     # Публичный API
│   └── src/
│       ├── core/                 # Ядро движка
│       │   ├── translation_engine.dart       # Главный класс движка
│       │   ├── translation_pipeline.dart     # Pipeline обработки слоёв
│       │   ├── translation_context.dart      # Контекст перевода
│       │   ├── engine_config.dart            # Конфигурация
│       │   └── layer_adapters.dart           # Адаптеры для слоёв
│       │
│       ├── layers/               # Слои обработки текста (6 слоёв)
│       │   ├── base_translation_layer.dart    # Базовый класс слоя
│       │   ├── pre_processing_layer.dart      # Слой 1: Предобработка
│       │   ├── phrase_translation_layer.dart  # Слой 2: Фразы
│       │   ├── dictionary_layer.dart          # Слой 3: Словарь
│       │   ├── grammar_layer.dart             # Слой 4: Грамматика
│       │   ├── word_order_layer.dart          # Слой 5: Порядок слов
│       │   └── post_processing_layer.dart     # Слой 6: Постобработка
│       │
│       ├── data/                 # Data Layer (репозитории)
│       │   ├── base_repository.dart
│       │   ├── database_manager.dart
│       │   ├── dictionary_repository.dart
│       │   ├── phrase_repository.dart
│       │   ├── user_data_repository.dart
│       │   ├── grammar_rules_repository.dart
│       │   ├── word_order_rules_repository.dart
│       │   └── post_processing_rules_repository.dart
│       │
│       ├── models/               # Модели данных
│       │   ├── translation_result.dart
│       │   └── layer_debug_info.dart
│       │
│       ├── utils/                # Утилиты
│       │   ├── cache_manager.dart       # Управление кэшем (LRU+TTL)
│       │   ├── config_manager.dart      # Конфигурационные файлы
│       │   ├── debug_logger.dart        # Логирование
│       │   ├── metrics.dart             # Метрики производительности
│       │   ├── tracing.dart             # Трассировка запросов
│       │   ├── rate_limiter.dart        # Ограничение частоты
│       │   ├── exceptions.dart          # Исключения
│       │   └── integrity_checker.dart   # Проверка целостности
│       │
│       ├── storage/              # Файловое хранилище
│       │   └── file_storage.dart
│       │
│       └── tools/                # Инструменты импорта/экспорта
│           ├── dictionary_importer.dart
│           └── phrase_importer.dart
│
├── test/                         # Тесты (82 .dart файла)
│   ├── unit/                     # Юнит-тесты
│   ├── integration/              # Интеграционные тесты
│   ├── layers/                   # Тесты слоёв
│   ├── e2e/                      # End-to-end тесты
│   └── benchmarks/               # Производительность
│
└── docs/                         # Документация
    ├── DEVELOPER_GUIDE.md        # Этот файл
    ├── DEVELOPMENT_STAGES.md     # План развития
    ├── cli_commands_ru.md        # Справка по CLI
    ├── core_audit_ru.md          # Технический аудит
    ├── core_changes_ru.md        # История изменений
    └── usage_ru.md               # Инструкция пользователя
```

### Жизненный цикл движка

```dart
// 1. Создание и инициализация
final engine = TranslationEngine();
await engine.initialize(
  customDatabasePath: './translation_data',
  config: {
    'cache': {'words_limit': 10000, 'ttl_seconds': 3600},
    'debug': true,
    'log_level': 'info',
  },
);

// 2. Выполнение перевода
final result = await engine.translate(
  'Hello, world!',
  sourceLanguage: 'en',
  targetLanguage: 'ru',
);

// 3. Проверка результата
if (result.hasError) {
  print('Error: ${result.errorMessage}');
} else {
  print('Translation: ${result.translatedText}');
  print('Confidence: ${result.confidence}');
}

// 4. Очистка ресурсов
await engine.dispose();
```

### Состояния движка

```
uninitialized → initializing → ready ⇄ processing
                                 ↓
                               error (recoverable via reset())
                                 ↓
                             disposing → disposed
```

---

## 🔄 Слои обработки

Движок использует **6 последовательных слоёв обработки**. Каждый слой наследуется от `BaseTranslationLayer` и реализует интерфейс `TranslationLayer`.

### Порядок выполнения слоёв

| # | Слой | Приоритет | Назначение | Статус |
|---|------|-----------|------------|--------|
| 1 | **PreProcessingLayer** | 0 | Нормализация, токенизация, очистка HTML/Markdown | ✅ Работает |
| 2 | **PhraseTranslationLayer** | 100 | Поиск готовых переводов фраз/идиом | ✅ Базовый n-gram реализован |
| 3 | **DictionaryLayer** | 200 | Перевод отдельных слов через словарь | ✅ Работает |
| 4 | **GrammarLayer** | 300 | Применение грамматических правил | ⚠️ Упрощённые правила |
| 5 | **WordOrderLayer** | 400 | Перестановка слов согласно целевому языку | ⚠️ Базовые эвристики |
| 6 | **PostProcessingLayer** | 500 | Капитализация, пунктуация, форматирование | ⚠️ Эвристики, требует улучшений |

### Детали слоёв

#### 1. PreProcessingLayer (Предобработка)

**Ответственность:**
- Очистка HTML тегов и Markdown разметки
- Нормализация Unicode (NFC)
- Токенизация текста на слова, числа, пунктуацию, whitespace
- Определение типов токенов (word, number, punctuation, email, url, hashtag, mention)
- Сохранение токенов в контексте для последующих слоёв

**Особенности:**
- Поддерживает латиницу, кириллицу, CJK символы
- Создаёт метаданные `preprocessing_tokens` и `token_count`
- Заполняет `context.tokens` списком нормализованных слов

**Важно:** Все последующие слои используют токены из этого слоя для обеспечения согласованности.

#### 2. PhraseTranslationLayer (Фразовый перевод)

**Ответственность:**
- Exact lookup: поиск точного совпадения фразы в `PhraseRepository`
- N-gram matching: поиск биграмм (2 слова) и триграмм (3 слова)
- Приоритизация длинных фраз над короткими
- Безопасная реконструкция текста без артефактов

**Алгоритм:**
1. Попытка точного поиска всей фразы
2. Генерация биграмм и триграмм из токенов
3. Поиск каждой n-граммы в репозитории
4. Сортировка найденных фраз по длине (длинные первые)
5. Разрешение конфликтов (без перекрытий)
6. Замена найденных фраз в тексте

**Особенности:**
- Минимальная длина фразы: 2 слова
- Максимальная длина фразы: 8 слов
- Confidence зависит от длины и точности совпадения

#### 3. DictionaryLayer (Словарный перевод)

**Ответственность:**
- Перевод отдельных слов через `DictionaryRepository`
- Поддержка множественных переводов с выбором лучшего
- Учёт частотности слов
- Принудительные переводы (`context.forceTranslations`)
- Исключения слов из перевода (`context.excludeWords`)

**Алгоритм:**
1. Использование токенов из `PreProcessingLayer`
2. Fallback-токенизация при отсутствии метаданных
3. Для каждого словарного токена:
   - Проверка принудительного перевода
   - Проверка исключений
   - Поиск в словаре по нормализованной форме
   - Выбор лучшего перевода (по confidence/frequency)
4. Безопасная реконструкция текста с сохранением пробелов/пунктуации

**Особенности:**
- Токенизатор поддерживает латиницу, кириллицу, CJK
- Минимальная confidence для принятия: 0.3
- Максимум 5 вариантов перевода на слово

#### 4. GrammarLayer (Грамматическая коррекция)

**Ответственность:**
- Применение языко-специфичных грамматических правил
- Коррекция окончаний, артиклей, глагольных форм
- Согласование рода, числа, падежа

**Текущая реализация:**
- Упрощённые regex-правила из `GrammarRulesRepository`
- Применение замен на основе паттернов

**⚠️ Известные проблемы:**
- Правила упрощены до прототипа
- Некоторые regex/replacement выглядят некорректно
- Отсутствует schema validation правил
- Нет поддержки морфологического анализа

**Планы:**
- Вынесение правил во внешние JSONL файлы
- Schema validation
- Язык-специфичные правила с тестами

#### 5. WordOrderLayer (Синтаксическая перестройка)

**Ответственность:**
- Изменение порядка слов согласно целевому языку
- Перемещение прилагательных, глаголов, частиц

**Текущая реализация:**
- Базовые эвристики из `WordOrderRulesRepository`
- Применение правил перестановки на основе паттернов

**⚠️ Известные проблемы:**
- Отсутствуют риcкованные дефолтные правила
- Нет учёта контекста предложения
- Может вносить артефакты при смешанных скриптах

**Планы:**
- Язык-специфичные правила
- Учёт синтаксического дерева
- Более продвинутая эвристика

#### 6. PostProcessingLayer (Финальное форматирование)

**Ответственность:**
- Капитализация первой буквы предложения
- Добавление финальной пунктуации
- Удаление лишних пробелов
- Нормализация кавычек

**Текущая реализация:**
- Эвристические правила капитализации/пунктуации
- Применение правил из `PostProcessingRulesRepository`

**⚠️ Известные проблемы:**
- Может портить тексты для нелатинских языков
- Навязывает финальную точку там, где не требуется
- Проблемы с кавычками, NBSP (особенно FR/ES)

**Планы:**
- Язык-специфичные правила форматирования
- Опциональное отключение шагов
- Учёт типа текста (вопрос, восклицание, утверждение)

### Базовый класс слоя

Все слои наследуются от `BaseTranslationLayer`:

```dart
abstract class BaseTranslationLayer {
  // Метаданные слоя
  String get name;                    // Уникальное имя
  String get description;             // Описание функционала
  LayerPriority get priority;         // Приоритет выполнения
  String get version => '1.0.0';      // Версия слоя
  
  // Методы обработки
  bool canHandle(String text, TranslationContext context);
  Future<LayerResult> process(String text, TranslationContext context);
  bool validateInput(String text, TranslationContext context);
  
  // Обработка с метриками
  Future<LayerResult> processWithMetrics(String text, TranslationContext context);
  
  // Статистика
  Map<String, dynamic> get statistics;
  void resetStatistics();
  Map<String, dynamic> getLayerInfo();
}
```

### Регистрация слоёв

Слои регистрируются в `TranslationPipeline` через `LayerAdaptersFactory`:

```dart
// В _initializeDefaultLayers():
registerLayer(LayerAdaptersFactory.preProcessing());
registerLayer(LayerAdaptersFactory.phraseLookup(repo: phraseRepository));
registerLayer(LayerAdaptersFactory.dictionary(repo: dictionaryRepository));
registerLayer(LayerAdaptersFactory.grammar(repo: grammarRulesRepository));
registerLayer(LayerAdaptersFactory.wordOrder(repo: wordOrderRulesRepository));
registerLayer(LayerAdaptersFactory.postProcessing(repo: postProcessingRulesRepository));
```

---

## 💾 Репозитории данных

Все репозитории наследуются от `BaseRepository` и используют JSONL-файловое хранилище.

### Структура данных

```
translation_data/
├── en-ru/                          # Языковая пара
│   ├── dictionary.jsonl            # Словарь переводов
│   ├── phrases.jsonl               # Фразы и идиомы
│   ├── grammar_rules.jsonl         # Грамматические правила
│   ├── word_order_rules.jsonl      # Правила порядка слов
│   ├── post_processing_rules.jsonl # Правила постобработки
│   └── version.json                # Версия формата данных
├── ru-en/                          # Другие языковые пары...
└── user/                           # Пользовательские данные
    ├── translation_history.jsonl
    ├── user_settings.json
    └── user_translation_edits.jsonl
```

### Репозитории

#### DictionaryRepository

**Назначение:** Управление словарными переводами слов.

**Формат JSONL записи:**
```json
{"source":"hello","target":"привет","lang":"en-ru","confidence":95,"frequency":1000,"pos":"interjection"}
```

**Основные методы:**
- `getTranslation(word, langPair)` - поиск перевода слова
- `getTranslations(word, langPair)` - все варианты перевода
- `addTranslation(...)` - добавление перевода (deprecated, use bulk)
- `bulkUpsertTranslations([...])` - пакетная запись (рекомендуется)
- `searchTranslations(query, langPair)` - поиск по частичному совпадению

**Индексы:** In-memory индекс `bySource` для быстрого поиска по исходному слову.

#### PhraseRepository

**Назначение:** Управление фразовыми переводами и идиомами.

**Формат JSONL записи:**
```json
{"source":"good morning","target":"доброе утро","lang":"en-ru","confidence":98,"type":"greeting","category":"greetings"}
```

**Основные методы:**
- `getPhraseTranslation(phrase, langPair)` - точный поиск фразы
- `searchPhrases(query, langPair)` - поиск фраз
- `addPhrase(...)` - добавление фразы (deprecated, use bulk)
- `bulkUpsertPhrases([...])` - пакетная запись (рекомендуется)

**Индексы:** In-memory индекс `bySource` для точного поиска фраз.

#### UserDataRepository

**Назначение:** Хранение пользовательских настроек, истории переводов, правок.

**Файлы:**
- `translation_history.jsonl` - история переводов
- `user_settings.json` - настройки пользователя
- `user_translation_edits.jsonl` - пользовательские правки переводов

**Основные методы:**
- `saveTranslationHistory(result)` - сохранение истории
- `getUserSettings()` - получение настроек
- `saveUserSettings(settings)` - сохранение настроек
- `getUserEdit(source, langPair)` - получение правки
- `saveUserEdit(...)` - сохранение правки

#### GrammarRulesRepository, WordOrderRulesRepository, PostProcessingRulesRepository

**Назначение:** Хранение правил для соответствующих слоёв.

**Формат JSONL записи (пример grammar):**
```json
{"lang":"en-ru","pattern":"\\bis\\b","replacement":"есть","priority":10,"description":"verb to be"}
```

**Основные методы:**
- `getRules(langPair)` - получение всех правил для языковой пары

### Операции с репозиториями

#### Пакетная запись (Bulk Operations)

**❗Важно:** Всегда используйте bulk-операции для импорта данных вместо циклов с единичными вставками.

```dart
// ❌ ПЛОХО: O(n²) сложность
for (final word in words) {
  await repo.addTranslation(word.source, word.target, ...);
}

// ✅ ХОРОШО: O(n) сложность
await repo.bulkUpsertTranslations(words.map((w) => {
  'source': w.source,
  'target': w.target,
  'lang': langPair,
  'confidence': w.confidence,
}).toList());
```

#### Атомарная запись

Все bulk-операции используют atomic write (tmp + rename):

1. Запись в временный файл `{file}.tmp`
2. Atomic rename `{file}.tmp` → `{file}`
3. Best-effort file lock (`{file}.lock`)

#### Кэширование

Репозитории используют `CacheManager` с двумя стратегиями:

- **Generic cache**: универсальный LRU+TTL кэш для результатов поиска
- **In-memory indexes**: индексы для быстрого поиска (bySource)

**Конфигурация кэша:**
```dart
config: {
  'cache': {
    'words_limit': 10000,       // Лимит словарного кэша
    'phrases_limit': 5000,      // Лимит фразового кэша
    'ttl_seconds': 3600,        // TTL (время жизни) в секундах
  }
}
```

---

## 🔧 CLI и точки входа

### Запуск CLI

Из внешнего приложения:
```bash
dart run fluent_translate:translate_engine <command> [options]
```

Локально (в папке проекта):
```bash
dart run bin/translate_engine.dart <command> [options]
```

### Доступные команды

#### db - Загрузка словарей

```bash
# Список доступных языковых пар
dart run fluent_translate:translate_engine db --list

# Загрузка en-ru в ./translation_data
dart run fluent_translate:translate_engine db --lang=en-ru --db=./translation_data

# Загрузка всех доступных пар
dart run fluent_translate:translate_engine db --db=./translation_data

# Опции:
# --lang=<xx-yy>        Языковая пара
# --db=<dir>            Путь к директории данных
# --source=<url>        Альтернативный HTTPS-источник
# --force               Перезагрузить существующие файлы
# --sha256=<prefix>     Проверка целостности SHA-256
# --allow-any-source    Разрешить любые источники (по умолчанию только github*)
# --dry-run             Показать что будет загружено
```

#### import - Импорт данных

```bash
dart run fluent_translate:translate_engine import \
  --file=./data/dict.jsonl \
  --lang=en-ru \
  --db=./translation_data

# Опции:
# --file=<path>   Путь к файлу (CSV/JSON/JSONL)
# --lang=<pair>   Языковая пара
# --db=<dir>      Путь к БД
# --type=<type>   Тип данных (dict/phrases)
```

#### export - Экспорт данных

```bash
dart run fluent_translate:translate_engine export \
  --type=dict \
  --lang=en-ru \
  --out=./output

# Опции:
# --type=<type>   Тип данных (dict/phrases)
# --lang=<pair>   Языковая пара
# --out=<dir>     Выходная директория
```

#### validate - Валидация данных

```bash
dart run fluent_translate:translate_engine validate --db=./translation_data
```

#### metrics - Метрики движка

```bash
dart run fluent_translate:translate_engine metrics --db=./translation_data
```

Выводит:
- Статистику движка (переводы, время обработки)
- Метрики кэша (hits, misses, размер)
- Очередь запросов
- Таймауты
- Метрики слоёв

#### config - Конфигурация

```bash
# Показать текущую конфигурацию
dart run fluent_translate:translate_engine config show

# Применить конфигурацию из файла
dart run fluent_translate:translate_engine config set --file=engine_config.json
```

#### logs - Управление логами

```bash
# Установить уровень логирования
dart run fluent_translate:translate_engine logs level info

# Включить логирование
dart run fluent_translate:translate_engine logs enable

# Выключить логирование
dart run fluent_translate:translate_engine logs disable

# Уровни: error | warn | info | debug
```

#### cache - Управление кэшем

```bash
# Статистика кэша
dart run fluent_translate:translate_engine cache stats

# Очистка кэша
dart run fluent_translate:translate_engine cache clear all
dart run fluent_translate:translate_engine cache clear words
dart run fluent_translate:translate_engine cache clear phrases
```

#### queue - Статус очереди

```bash
dart run fluent_translate:translate_engine queue stats
```

#### engine - Обслуживание движка

```bash
# Мягкий сброс состояния
dart run fluent_translate:translate_engine engine reset
```

---

## ⚙️ Конфигурация и настройка

### Структура конфигурации

```dart
final config = {
  // Кэширование
  'cache': {
    'words_limit': 10000,           // Лимит словарного кэша
    'phrases_limit': 5000,          // Лимит фразового кэша
    'ttl_seconds': 3600,            // TTL в секундах
  },
  
  // Отладка и логирование
  'debug': true,                    // Включить debug-режим
  'log_level': 'info',              // error|warn|info|debug
  
  // Безопасность и ограничения
  'security': {
    'rate_limiting': true,          // Включить rate limiting
    'max_requests_per_minute': 60,  // Максимум запросов в минуту
  },
  
  // Очередь запросов
  'queue': {
    'max_pending': 100,             // Макс. запросов в очереди (0 = unlimited)
  },
  
  // Таймауты
  'timeouts': {
    'translate_ms': 5000,           // Таймаут перевода в мс
  },
  
  // Режим деградации
  'degrade': {
    'enabled': false,               // Включить degrade-режим
    'allowed_layers': [             // Разрешённые слои в degrade
      'phraseLookup',
      'dictionary',
    ],
  },
  
  // Качество перевода (планируется)
  'quality': {
    'min_confidence': 0.3,
    'prefer_exact_matches': true,
  },
};

await engine.initialize(config: config);
```

### Degrade-режим

Режим деградации позволяет ограничить набор слоёв при проблемах или для ускорения:

```dart
config: {
  'degrade': {
    'enabled': true,
    'allowed_layers': ['phraseLookup', 'dictionary'],
  }
}
```

В этом режиме будут выполнены только слои фраз и словаря, остальные пропущены.

### Метрики и мониторинг

```dart
// Получение расширенных метрик
final metrics = engine.getMetrics();
print(metrics);

// Вывод:
// {
//   'engine': {...},          // Статистика движка
//   'cache': {...},           // Метрики кэша
//   'queue': {...},           // Статус очереди
//   'timeouts': {...},        // Таймауты
//   'logging': {...},         // Конфигурация логов
//   'metrics': {...},         // Метрики слоёв
// }
```

### Логирование

Движок использует структурированное JSON-логирование через `DebugLogger`:

```dart
// Включение логирования
DebugLogger.instance.setEnabled(true);
DebugLogger.instance.setLevel(LogLevel.info);
DebugLogger.instance.setStructured(true);
```

Логи пишутся в stdout в формате JSON:
```json
{"level":"info","msg":"translate.start","trace_id":"abc123","lang_pair":"en-ru","queued":0}
{"level":"debug","msg":"layer.start","trace_id":"abc123","layer":"dictionary"}
{"level":"info","msg":"translate.end","trace_id":"abc123","processing_time_ms":45}
```

### Трассировка

Каждый запрос получает уникальный `trace_id` для отслеживания:

```dart
// Автоматически генерируется в translate()
final traceId = newTraceId();  // UUID v4

// Доступен в логах и метриках
context.setMetadata('trace_id', traceId);
```

---

## 📐 Правила разработки

### Соблюдение архитектуры

**❗Обязательно:**
1. **OOP принципы**: инкапсуляция, наследование, полиморфизм
2. **SOLID**: Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion
3. **Не нарушать целостность кода**: любые изменения должны проходить `flutter analyze` без ошибок

### Flutter Analyze

**Перед коммитом ВСЕГДА запускайте:**
```bash
flutter analyze
```

Код должен проходить без ошибок и критичных предупреждений.

### Стиль кода

1. **Dart style guide**: следуйте официальному стилю Dart
2. **Комментарии на русском** для внутренней документации
3. **Dartdoc комментарии (///)** для публичного API на английском
4. **Осмысленные имена**: классов, методов, переменных

### Добавление нового слоя

1. Наследоваться от `BaseTranslationLayer`
2. Реализовать методы:
   - `name`, `description`, `priority`
   - `canHandle(text, context)`
   - `process(text, context)`
3. Зарегистрировать в `LayerAdaptersFactory`
4. Добавить тесты в `test/layers/`
5. Обновить документацию

Пример:
```dart
class MyCustomLayer extends BaseTranslationLayer {
  @override
  String get name => 'MyCustomLayer';
  
  @override
  String get description => 'Custom processing logic';
  
  @override
  LayerPriority get priority => LayerPriority.grammar; // or custom value
  
  @override
  bool canHandle(String text, TranslationContext context) {
    // Логика проверки возможности обработки
    return text.isNotEmpty;
  }
  
  @override
  Future<LayerResult> process(String text, TranslationContext context) async {
    // Основная логика обработки
    final processedText = myProcessingLogic(text);
    
    return LayerResult.success(
      processedText: processedText,
      confidence: 0.8,
      debugInfo: _createDebugInfo(...),
    );
  }
}
```

### Добавление нового репозитория

1. Наследоваться от `BaseRepository`
2. Определить формат JSONL-записей
3. Реализовать методы поиска/добавления/удаления
4. **Обязательно** реализовать `bulkUpsert` для эффективной записи
5. Использовать `CacheManager` для кэширования
6. Добавить тесты в `test/unit/data/`

### Работа с JSONL

```dart
// ✅ ПРАВИЛЬНО: атомарная запись
await storage.rewriteJsonLines(
  langPair,
  fileName,
  entries.map((e) => jsonEncode(e)).toList(),
  lock: true,  // Использовать file lock
);

// ❌ НЕПРАВИЛЬНО: синхронная блокирующая запись без блокировки
final file = File(path);
file.writeAsStringSync(data); // Не атомарно, не безопасно
```

### Unicode нормализация

**❗Важно:** Всегда нормализуйте Unicode строки при работе с ключами:

```dart
import 'package:unorm_dart/unorm_dart.dart' as unorm;

final normalized = unorm.nfc(text.toLowerCase());
```

Это обеспечивает корректное сопоставление слов с диакритикой.

### Обработка ошибок

1. **Используйте typed exceptions**: `EngineInitializationException`, `EngineStateException`, `LayerException`
2. **Логируйте ошибки** через `DebugLogger`
3. **Возвращайте graceful results** вместо бросания исключений в слоях:
   ```dart
   return LayerResult.error(
     originalText: text,
     errorMessage: 'Detailed error message',
     debugInfo: _createDebugInfo(...),
   );
   ```

### Тестирование

1. **Unit тесты** для всех публичных методов
2. **Integration тесты** для взаимодействия компонентов
3. **Layer тесты** для каждого слоя
4. **E2E тесты** для полного цикла перевода
5. **Benchmarks** для критичных путей

Запуск тестов:
```bash
# Все тесты
flutter test

# Конкретный файл
flutter test test/layers/dictionary_layer_test.dart

# Бенчмарки
flutter test test/benchmarks/
```

### Документация

При изменениях обновляйте:
1. Этот файл (`DEVELOPER_GUIDE.md`)
2. `core_changes_ru.md` (история изменений)
3. `usage_ru.md` (если меняется API)
4. `CHANGELOG.md` (для релизов)

---

## 🧪 Тестирование

### Структура тестов

```
test/
├── unit/                  # Юнит-тесты отдельных компонентов
│   ├── core/              # Тесты ядра (engine, pipeline, context)
│   ├── data/              # Тесты репозиториев
│   └── utils/             # Тесты утилит
│
├── integration/           # Интеграционные тесты
│   └── data_layer_integration_test.dart
│
├── layers/                # Тесты слоёв
│   ├── pre_processing_layer_test.dart
│   ├── phrase_exact_lookup_test.dart
│   ├── dictionary_single_letter_test.dart
│   ├── grammar_layer_test.dart
│   ├── word_order_layer_test.dart
│   └── post_processing_layer_test.dart
│
├── e2e/                   # End-to-end тесты
│   └── pipeline_e2e_test.dart
│
├── benchmarks/            # Производительность
│   ├── perf_benchmarks_test.dart
│   └── perf_report_test.dart
│
├── helpers/               # Вспомогательные утилиты для тестов
│   └── test_database_helper.dart
│
└── tools/                 # Тесты инструментов импорта
    └── dictionary_importer_test.dart
```

### Примеры тестов

#### Unit тест слоя

```dart
void main() {
  group('DictionaryLayer', () {
    late DictionaryLayer layer;
    late DictionaryRepository mockRepo;
    
    setUp(() {
      mockRepo = MockDictionaryRepository();
      layer = DictionaryLayer(dictionaryRepository: mockRepo);
    });
    
    test('should translate word successfully', () async {
      final context = TranslationContext(
        sourceLanguage: 'en',
        targetLanguage: 'ru',
      );
      
      when(mockRepo.getTranslation('hello', 'en-ru'))
          .thenAnswer((_) async => mockTranslation);
      
      final result = await layer.process('hello', context);
      
      expect(result.success, isTrue);
      expect(result.processedText, equals('привет'));
    });
  });
}
```

#### Integration тест

```dart
void main() {
  testWidgets('Full translation pipeline', (tester) async {
    final engine = TranslationEngine();
    await engine.initialize(
      customDatabasePath: './test_data',
    );
    
    final result = await engine.translate(
      'Hello world',
      sourceLanguage: 'en',
      targetLanguage: 'ru',
    );
    
    expect(result.hasError, isFalse);
    expect(result.translatedText, isNotEmpty);
    expect(result.confidence, greaterThan(0.0));
    
    await engine.dispose();
  });
}
```

### Mock данные

Используйте `TestDatabaseHelper` для создания тестовых данных:

```dart
class TestDatabaseHelper {
  static Future<void> createTestData(String path) async {
    // Создание тестовых словарей/фраз
  }
  
  static Future<void> cleanupTestData(String path) async {
    // Очистка после тестов
  }
}
```

### Покрытие кода

Запуск с покрытием:
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

**Цель:** минимум 70% покрытия для критичных компонентов.

## 📚 Дополнительные ресурсы

### Документы проекта

- **DEVELOPMENT_STAGES.md** - подробный план развития до "идеальной библиотеки"
- **core_audit_ru.md** - технический аудит ядра (риски, проблемы, блокеры)
- **core_changes_ru.md** - история изменений с статусами выполнения
- **cli_commands_ru.md** - справка по CLI командам
- **usage_ru.md** - инструкция для пользователей
- **test_plan_ru.md** - план тестирования

### Ключевые файлы кода

**Core:**
- `lib/src/core/translation_engine.dart` - главный класс движка
- `lib/src/core/translation_pipeline.dart` - конвейер слоёв
- `lib/src/core/translation_context.dart` - контекст перевода

**Layers:**
- `lib/src/layers/base_translation_layer.dart` - базовый класс слоя
- `lib/src/layers/pre_processing_layer.dart` - предобработка
- `lib/src/layers/phrase_translation_layer.dart` - фразы
- `lib/src/layers/dictionary_layer.dart` - словарь
- `lib/src/layers/grammar_layer.dart` - грамматика
- `lib/src/layers/word_order_layer.dart` - порядок слов
- `lib/src/layers/post_processing_layer.dart` - постобработка

**Data:**
- `lib/src/data/base_repository.dart` - базовый репозиторий
- `lib/src/data/dictionary_repository.dart` - словарный репозиторий
- `lib/src/data/phrase_repository.dart` - фразовый репозиторий

**Utils:**
- `lib/src/utils/cache_manager.dart` - управление кэшем
- `lib/src/utils/debug_logger.dart` - логирование
- `lib/src/utils/metrics.dart` - метрики
- `lib/src/utils/tracing.dart` - трассировка

**CLI:**
- `bin/translate_engine.dart` - точка входа CLI
- `bin/commands/` - реализация команд

### Контакты и поддержка

- **Repository**: https://github.com/VernaculusF/translation_engine
- **Issues**: https://github.com/VernaculusF/translation_engine/issues
- **Package**: https://pub.dev/packages/fluent_translate

---

## ✅ Чеклист для разработчика

Перед началом работы убедитесь, что вы:

- [x] Прочитали этот документ полностью
- [x] Ознакомились с архитектурой системы
- [x] Понимаете назначение каждого слоя
- [x] Знаете как работают репозитории
- [x] Изучили правила разработки
- [x] Настроили окружение (`flutter pub get`)
- [x] Запустили тесты (`flutter test`)
- [x] Запустили analyze (`flutter analyze`)

Перед коммитом изменений:

- [ ] Код проходит `flutter analyze` без ошибок
- [ ] Все новые функции покрыты тестами
- [ ] Документация обновлена
- [ ] CHANGELOG.md дополнен (если применимо)
- [ ] Соблюдены OOP и SOLID принципы
- [ ] Использованы bulk-операции для записи данных
- [ ] Unicode нормализация применена где нужно
- [ ] Логирование добавлено для ключевых операций

---

## 🤖 Правила ДЛЯ ИИ

> Этот раздел содержит специфичные инструкции для агентных ИИ-разработчиков, работающих с translation_engine.

### Общие принципы работы

#### 1. ВСЕГДА запускайте `flutter analyze` после изменений

**❗КРИТИЧНО:** После любых изменений кода **ОБЯЗАТЕЛЬНО** запускайте:
```bash
flutter analyze
```

Код ДОЛЖЕН проходить без ошибок. Если есть ошибки - исправьте их до завершения задачи.

#### 2. Не нарушайте целостность кода

- **OOP принципы**: соблюдайте инкапсуляцию, наследование, полиморфизм
- **SOLID принципы**: Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion
- **Не ломайте существующий функционал**: перед изменениями проверяйте зависимости
- **Сохраняйте архитектуру**: не меняйте структуру слоёв/репозиториев без явного запроса

#### 3. Изучайте контекст перед изменениями

**Перед любыми изменениями:**
1. Прочитайте измененяемый файл целиком
2. Найдите и изучите связанные файлы (импорты, наследование)
3. Проверьте существующие тесты для этого компонента
4. Убедитесь, что понимаете назначение компонента

**Используйте инструменты:**
- `read_any_files` для чтения кода
- `grep` для поиска использований
- `find_files` для поиска связанных файлов
- `search_codebase` для семантического поиска

### Работа со слоями (Layers)

#### Структура слоя

Все слои наследуются от `BaseTranslationLayer` и **ДОЛЖНЫ**:

1. **Реализовать обязательные методы:**
   ```dart
   String get name;                    // Уникальное имя слоя
   String get description;             // Описание функционала
   LayerPriority get priority;         // Приоритет выполнения
   bool canHandle(String text, TranslationContext context);
   Future<LayerResult> process(String text, TranslationContext context);
   ```

2. **Использовать `processWithMetrics` для вызова:**
   - Слои вызываются через `LayerAdapter`, который использует `processWithMetrics`
   - НЕ вызывайте `process` напрямую из pipeline

3. **Работать с токенами из PreProcessingLayer:**
   ```dart
   final tokens = context.getMetadata<List<TextToken>>('preprocessing_tokens');
   ```
   - Это обеспечивает согласованность токенизации между слоями

4. **Возвращать LayerResult, а не бросать исключения:**
   ```dart
   // ❌ ПЛОХО
   throw Exception('Something failed');
   
   // ✅ ХОРОШО
   return LayerResult.error(
     originalText: text,
     errorMessage: 'Something failed',
     debugInfo: _createDebugInfo(...),
   );
   ```

#### Модификация существующих слоёв

**Перед изменением слоя:**
1. Прочитайте весь файл слоя
2. Проверьте тесты в `test/layers/{layer_name}_test.dart`
3. Найдите, где используется слой через `grep` или `search_codebase`
4. Убедитесь, что изменения не сломают pipeline

**После изменения:**
1. Запустите `flutter analyze`
2. Запустите тесты слоя: `flutter test test/layers/{layer_name}_test.dart`
3. Запустите e2e тесты: `flutter test test/e2e/`

### Работа с репозиториями (Data Layer)

#### Ключевые правила

1. **ВСЕГДА используйте bulk-операции для записи данных:**
   ```dart
   // ❌ ПЛОХО: O(n²)
   for (final item in items) {
     await repo.addTranslation(...);
   }
   
   // ✅ ХОРОШО: O(n)
   await repo.bulkUpsertTranslations(items);
   ```

2. **Атомарная запись через storage:**
   ```dart
   await storage.rewriteJsonLines(
     langPair,
     fileName,
     entries.map((e) => jsonEncode(e)).toList(),
     lock: true,  // ВАЖНО: используйте блокировку
   );
   ```

3. **Unicode нормализация для ключей:**
   ```dart
   import 'package:unorm_dart/unorm_dart.dart' as unorm;
   
   final normalized = unorm.nfc(text.toLowerCase());
   ```

4. **Используйте CacheManager:**
   - Репозитории должны использовать `CacheManager` для кэширования результатов поиска
   - Ключи кэша: `'dict:{source}:{langPair}'` или `'phrase:{source}:{langPair}'`

### Работа с конфигурацией

#### Применение конфигурации в _applyConfig

Когда добавляете новые параметры конфигурации:

1. **Добавьте в `EngineConfig`** (если нужно типизацию)
2. **Применяйте в `_applyConfig`** метода `TranslationEngine`:
   ```dart
   Future<void> _applyConfig(Map<String, dynamic> config) async {
     // Пример: новый параметр
     if (config.containsKey('my_feature')) {
       final myConfig = config['my_feature'] as Map<String, dynamic>;
       // Применить настройки
     }
   }
   ```

3. **Обновите документацию** в разделе "Конфигурация и настройка"

### Тестирование

#### Обязательные тесты при изменениях

**Для слоёв:**
```bash
# Тест конкретного слоя
flutter test test/layers/{layer_name}_test.dart

# E2E тесты
flutter test test/e2e/pipeline_e2e_test.dart
```

**Для репозиториев:**
```bash
# Unit тесты репозитория
flutter test test/unit/data/{repository_name}_test.dart

# Интеграционные тесты
flutter test test/integration/
```

**После любых изменений:**
```bash
# Все тесты
flutter test

# Analyze
flutter analyze
```

#### Написание новых тестов

При добавлении функционала **ОБЯЗАТЕЛЬНО** добавьте тесты:

```dart
void main() {
  group('MyFeature', () {
    setUp(() {
      // Инициализация
    });
    
    test('should work correctly', () {
      // Arrange
      final input = 'test';
      
      // Act
      final result = myFeature(input);
      
      // Assert
      expect(result, isNotNull);
    });
  });
}
```

### Логирование и отладка

#### Добавляйте структурированные логи

```dart
import '../utils/debug_logger.dart';

// Для важных операций
DebugLogger.instance.info('operation.start', fields: {
  'trace_id': traceId,
  'param1': value1,
});

// Для ошибок
DebugLogger.instance.error('operation.error', error: e, stackTrace: st, fields: {
  'trace_id': traceId,
  'context': 'additional info',
});

// Для отладки
DebugLogger.instance.debug('operation.detail', fields: {
  'detail': 'some debug info',
});
```

#### Используйте метрики

```dart
import '../utils/metrics.dart';

// Таймер
final stopwatch = Stopwatch()..start();
// ... операция ...
MetricsRegistry.instance.timer('my.operation').observe(stopwatch.elapsed);

// Счётчик
MetricsRegistry.instance.counter('my.events').inc();
```

### Импорт и работа с данными

#### CSV импорт

Используйте корректный CSV парсер с поддержкой кавычек:

```dart
// Поддержка кавычек и экранирования
final fields = _parseCSVLine(line, delimiter: '\t');
```

Реализация должна:
- Обрабатывать кавычки (`"field with, comma"`)
- Обрабатывать экранированные кавычки (`"field with "" quotes"`)
- Поддерживать разные разделители (`,`, `\t`)

#### JSONL импорт

```dart
// Читать построчно
for (final line in lines) {
  if (line.trim().isEmpty) continue;
  
  try {
    final entry = jsonDecode(line) as Map<String, dynamic>;
    entries.add(entry);
  } catch (e) {
    // Собирать ошибки для отчёта
    errors.add('Line $lineNum: $e');
  }
}

// Bulk запись
await repo.bulkUpsertTranslations(entries);
```

### CLI команды

#### Структура команды

Все CLI команды наследуются от `BaseCommand`:

```dart
class MyCommand extends BaseCommand {
  @override
  String get name => 'mycommand';
  
  @override
  String get description => 'Description of my command';
  
  @override
  Future<int> run(List<String> args) async {
    // Парсинг аргументов
    final parser = ArgParser();
    parser.addOption('param', abbr: 'p', help: 'Parameter');
    
    final results = parser.parse(args);
    
    // Логика команды
    try {
      // ... работа ...
      print('Success!');
      return 0; // EX_OK
    } catch (e) {
      print('Error: $e');
      return 1; // EX_ERROR
    }
  }
}
```

### Частые ошибки и как их избежать

#### 1. Изменение текста без сохранения структуры

**❌ ПЛОХО:**
```dart
final words = text.split(' ');
final translated = words.map((w) => translate(w)).toList();
return translated.join(' '); // Потеряна пунктуация, whitespace
```

**✅ ХОРОШО:**
```dart
// Используйте токены из PreProcessingLayer
final tokens = context.getMetadata<List<TextToken>>('preprocessing_tokens');
// Переводите только word токены, сохраняйте структуру
```

#### 2. Прямое изменение файлов без атомарности

**❌ ПЛОХО:**
```dart
final file = File(path);
file.writeAsStringSync(data); // Не атомарно!
```

**✅ ХОРОШО:**
```dart
await storage.rewriteJsonLines(langPair, fileName, lines, lock: true);
```

#### 3. Забытая нормализация Unicode

**❌ ПЛОХО:**
```dart
final key = text.toLowerCase(); // Проблемы с диакритикой
```

**✅ ХОРОШО:**
```dart
final key = unorm.nfc(text.toLowerCase());
```

#### 4. Бросание исключений в слоях

**❌ ПЛОХО:**
```dart
if (error) throw Exception('Error');
```

**✅ ХОРОШО:**
```dart
return LayerResult.error(
  originalText: text,
  errorMessage: 'Error description',
  debugInfo: _createDebugInfo(...),
);
```

### Workflow для типичных задач

#### Задача: Добавить новое поле в словарь

1. **Изучите структуру:**
   ```bash
   # Прочитайте DictionaryRepository
   read_any_files: lib/src/data/dictionary_repository.dart
   ```

2. **Измените формат JSONL записи:**
   - Добавьте поле в методы `getTranslation`, `bulkUpsertTranslations`
   - Обновите парсинг JSON

3. **Обновите тесты:**
   - `test/unit/data/dictionary_repository_test.dart`

4. **Обновите импортёры:**
   - `lib/src/tools/dictionary_importer.dart`

5. **Проверьте:**
   ```bash
   flutter analyze
   flutter test test/unit/data/dictionary_repository_test.dart
   ```

6. **Обновите документацию:**
   - Раздел "Репозитории данных" в этом файле

#### Задача: Исправить баг в слое

1. **Воспроизведите проблему:**
   - Создайте/найдите тест, который падает

2. **Изучите код слоя:**
   ```bash
   read_any_files: lib/src/layers/{layer_name}.dart
   ```

3. **Найдите причину:**
   - Используйте логи, дебаг
   - Проверьте связанные компоненты

4. **Исправьте:**
   - Минимальные изменения
   - Сохраните архитектуру

5. **Проверьте:**
   ```bash
   flutter analyze
   flutter test test/layers/{layer_name}_test.dart
   flutter test test/e2e/
   ```

6. **Обновите тесты:**
   - Добавьте тест для этого бага (regression test)

#### Задача: Оптимизировать производительность

1. **Профилируйте:**
   - Используйте бенчмарки: `test/benchmarks/`
   - Идентифицируйте узкие места

2. **Проверьте кэширование:**
   - Используется ли `CacheManager`?
   - Корректны ли ключи кэша?

3. **Проверьте I/O:**
   - Используются ли bulk-операции?
   - Есть ли лишние чтения/записи?

4. **Оптимизируйте:**
   - Добавьте индексы
   - Используйте кэш
   - Минимизируйте I/O

5. **Измерьте результат:**
   ```bash
   flutter test test/benchmarks/perf_benchmarks_test.dart
   ```

### Финальный чеклист перед завершением

**ОБЯЗАТЕЛЬНО перед завершением любой задачи:**

- [ ] ✅ `flutter analyze` проходит без ошибок
- [ ] ✅ Все изменённые компоненты покрыты тестами
- [ ] ✅ Тесты проходят: `flutter test`
- [ ] ✅ Не нарушена архитектура (OOP, SOLID)
- [ ] ✅ Использованы bulk-операции для записи
- [ ] ✅ Применена Unicode нормализация где нужно
- [ ] ✅ Добавлено логирование для ключевых операций
- [ ] ✅ Документация обновлена (если нужно)
- [ ] ✅ Код читаем и понятен

### Приоритеты при работе

1. **Не ломать существующий функционал** - самый важный приоритет
2. **Соблюдать архитектуру** - не создавать технический долг
3. **Покрывать тестами** - обеспечить стабильность
4. **Документировать** - помочь будущим разработчикам
5. **Оптимизировать** - только после того, как всё работает

---

**Удачи в разработке! 🚀**
