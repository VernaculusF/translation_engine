# Translation Engine

A modular translation pipeline library for Dart/Flutter with layered processing, data repositories, and rich debug info.

## Quick start

- Add this repository as a dependency or clone locally.
- Make sure you have Flutter installed.

### Minimal example (engine)

```dart path=null start=null
import 'package:translation_engine/src/core/translation_engine.dart';
import 'package:translation_engine/src/core/translation_context.dart';

Future<void> main() async {
  final engine = TranslationEngine.instance(reset: true);
  await engine.initialize(customDatabasePath: '/tmp/te_db');

  final result = await engine.translate(
    'Hello,   world!!!',
    sourceLanguage: 'en',
    targetLanguage: 'en',
    context: TranslationContext(sourceLanguage: 'en', targetLanguage: 'en', debugMode: true),
  );

  print(result.translatedText); // Cleaned and formatted
  await engine.dispose();
}
```

### Run samples

- Basic usage:
  - `dart run samples/basic_usage/main.dart`

- Populate dictionary/phrases then translate:
  - `dart run samples/data_population/populate_and_translate.dart`

### Tests

- Run analyzer: `flutter analyze`
- Run tests: `flutter test`

## Performance

- Benchmarks: `flutter test test/benchmarks/perf_benchmarks_test.dart`
- Generate JSON report: `flutter test test/benchmarks/perf_report_test.dart`
  - Output in `reports/performance/perf_report_*.json`

## Architecture

- Core
  - TranslationEngine – high-level API
  - TranslationPipeline – orchestrates layers
  - TranslationContext – processing context
- Layers (adapters wired by default in engine)
  - PreProcessing → PhraseLookup → Dictionary → Grammar → WordOrder → PostProcessing
- Data layer
  - DictionaryRepository, PhraseRepository, UserDataRepository

See CHECKLISTS/DEVELOPMENT_STAGES.md for roadmap and current status.

**Закрытая коммерческая библиотека для оффлайн-перевода**

---

## 🎯 **НАЗНАЧЕНИЕ**

Библиотека предоставляет оффлайн-движок перевода для двух типов приложений:
1. **Мобильный оффлайн-переводчик** - быстрое перевода текста без интернета
2. **Приложение для чтения книг** - автоматический перевод текста в реальном времени

---

## 🏗️ **АРХИТЕКТУРА**

### **Многослойный конвейер перевода:**
1. **Предобработка** - нормализация, токенизация, определение языка
2. **Фразовый перевод** - поиск готовых переводов выражений  
3. **Словарный перевод** - перевод отдельных слов
4. **Грамматическая коррекция** - применение языковых правил
5. **Синтаксическая перестройка** - порядок слов
6. **Финальное форматирование** - капитализация, пунктуация

### **Технологический стек:**
- **Dart 3.0+** - основной язык
- **Flutter** - кроссплатформенность
- **SQLite** - локальное хранение словарей
- **In-memory кэш** - для производительности

---

## 📁 **СТРУКТУРА ПРОЕКТА**
lib/src/
├── core/ # Основной движок и конвейер
├── layers/ # 6 слоев обработки перевода
├── data/ # Работа с БД и репозитории
├── models/ # Data-классы
├── utils/ # Утилиты, кэш, логи
└── adaptation/ # Интерфейсы для адаптации

text

---

## 🗃️ **ДАННЫЕ**

### **Базы данных:**

#### **1. dictionaries.db - Словари**
- **words** - основная таблица словарей (`source_word` → `target_word`)
- **word_cache** - LRU кэш для быстрого доступа к переводам
- Индексы по `language_pair`, `frequency` для производительности

#### **2. phrases.db - Фразы и выражения**  
- **phrases** - готовые переводы фраз (`source_phrase` → `target_phrase`)
- **phrase_cache** - кэш часто используемых фраз
- Поддержка категорий, контекста, уверенности перевода

#### **3. user_data.db - Пользовательские данные**
- **translation_history** - история переводов с метаданными
- **user_corrections** - исправления переводов пользователем
- **user_settings** - настройки пользователя
- **user_translation_edits** - правки с системой аппрува
- **context_cache** - контекстный кэш переводов

### **Принципы схемы БД:**
- **`source_*`** - входящие данные (что переводим)
- **`target_*`** - выходные данные (результат перевода)
- **`language_pair`** - направление перевода (например, "en-ru")

### **Источники данных:**
- OPUS, Wiktionary, Tatoeba, Apertium
- OpenRussian, Project Gutenberg

---

## 🚀 **ХАРАКТЕРИСТИКИ**

- **Оффлайн работа** - основной приоритет
- **Размер пакета**: ~75-100MB
- **Время перевода**: 20-50ms
- **Память**: 80-120MB RAM
- **Качество**: 7.5/10 для основных сценариев

---

## 💰 **БИЗНЕС-МОДЕЛЬ**

**Закрытая коммерческая библиотека:**
- Лицензирование для разработчиков
- Интеграция в мобильные приложения
- Поддержка монетизации через премиум-функции

---

## 📅 **ПЛАН РАЗРАБОТКИ**

**11 недель до production-ready (осталось 6-7 недель):**
1. ✅ **Базовая архитектура и БД** (3 нед) - **ЗАВЕРШЕН**
2. ✅ **Ядро системы** (2 нед) - **ЗАВЕРШЕН**
3. 🔄 **Слои перевода** (3 нед) - **ТЕКУЩИЙ ЭТАП**
4. 🔴 **Качество и данные** (2 нед)
5. 🔴 **Финальная подготовка** (1 нед)

---

## 🔧 **ТЕКУЩИЙ СТАТУС**

**✅ ПОЛНОСТЬЮ ЗАВЕРШЕНО (ЭТАП 1-2):**
- **Data System (100%)**: DatabaseManager, CacheManager, Repositories, Models
- **Core System (100%)**: TranslationEngine, TranslationPipeline, TranslationContext, EngineConfig
- **223+ автоматических теста** (добавлены интеграционные тесты)
- **Обновленная схема БД** с правильными колонками (`source_*`/`target_*`)
- **1649+ строк продакшн кода** с полным API

**🔄 АКТИВНЫЙ ЭТАП (ЭТАП 3):**
- **Translation Layers (0/6)**: Начинаем реализацию 6 слоев перевода

---

## 👨‍💻 **РАЗРАБОТКА**

Проект разрабатывается как **чистая Flutter-библиотека** с соблюдением:
- SOLID принципов
- Clean Code
- Полного покрытия тестами
- Коммерческой лицензии

---

**Версия: 0.0.1** | **Лицензия: Коммерческая** | **Статус: В активной разработке**