**ОБНОВЛЁННЫЙ TODO СПИСОК РЕАЛИЗАЦИИ**

**🗄️ [2025-01-07] СХЕМА БД ПОЛНОСТЬЮ ОБНОВЛЕНА:**
- ✅ Исправлены названия колонок (`source_*`/`target_*` вместо сокращений)
- ✅ Добавлены недостающие колонки (`part_of_speech`, `definition`, `category`, `context`)
- ✅ Восстановлена таблица `user_corrections`
- ✅ Исправлена обработка JSON метаданных
- ✅ Обновлены 54 ключевых теста
- ✅ Создана подробная документация DATABASE_SCHEMA.md (285 строк)

---

## 📁 **ФАЙЛОВАЯ СИСТЕМА**

### **СТРУКТУРА ПРОЕКТА:**
```
lib/
├── src/
│   ├── core/
│   │   ├── translation_engine.dart        # Основной движок
│   │   ├── translation_pipeline.dart      # Конвейер обработки
│   │   └── translation_context.dart       # Контекст перевода
│   ├── layers/
│   │   ├── pre_processing_layer.dart      # Предобработка
│   │   ├── phrase_translation_layer.dart  # Фразовый перевод
│   │   ├── dictionary_layer.dart          # Словарный перевод
│   │   ├── grammar_layer.dart             # Грамматическая коррекция
│   │   ├── word_order_layer.dart          # Порядок слов
│   │   └── post_processing_layer.dart     # Финальное форматирование
│   ├── data/
│   │   ├── database_manager.dart          # Менеджер БД
│   │   ├── dictionary_repository.dart     # Репозиторий словарей
│   │   └── phrase_repository.dart         # Репозиторий фраз
│   ├── adaptation/
│   │   └── adaptation_provider.dart       # Интерфейс адаптации
│   ├── models/
│   │   ├── translation_result.dart        # Результат перевода
│   │   └── layer_debug_info.dart          # Отладочная информация
│   └── utils/
│       ├── cache_manager.dart             # Менеджер кэша
│       ├── config_manager.dart            # Менеджер конфигурации
│       ├── debug_logger.dart              # Логгер отладки
│       ├── exceptions.dart                # Пользовательские исключения
│       ├── integrity_checker.dart         # Проверка целостности данных
│       └── memory_profiler.dart           # Профилировщик памяти
└── test/
    ├── unit/
    ├── integration/
    └── performance/
```

---

## 🗃️ **СТРУКТУРА БАЗ ДАННЫХ**

### **DICTIONARIES.DB:** ✅ **СХЕМА ОБНОВЛЕНА (Версия 1.0)**
```sql
CREATE TABLE schema_info (version INTEGER)
CREATE TABLE words (
  id INTEGER PRIMARY KEY, 
  source_word TEXT NOT NULL CHECK(length(source_word) > 0), 
  target_word TEXT NOT NULL CHECK(length(target_word) > 0), 
  language_pair TEXT NOT NULL CHECK(length(language_pair) > 0), 
  part_of_speech TEXT,
  definition TEXT,
  frequency INTEGER DEFAULT 0,
  created_at INTEGER,
  updated_at INTEGER
)
CREATE TABLE word_cache (
  source_word TEXT PRIMARY KEY NOT NULL CHECK(length(source_word) > 0), 
  target_word TEXT NOT NULL, 
  language_pair TEXT NOT NULL, 
  last_used INTEGER NOT NULL
)
CREATE INDEX idx_word_lang ON words(source_word, language_pair)
CREATE INDEX idx_frequency ON words(frequency)
```

### **PHRASES.DB:** ✅ **СХЕМА ОБНОВЛЕНА (Версия 1.0)**
```sql
CREATE TABLE schema_info (version INTEGER)
CREATE TABLE phrases (
  id INTEGER PRIMARY KEY, 
  source_phrase TEXT NOT NULL CHECK(length(source_phrase) > 0), 
  target_phrase TEXT NOT NULL CHECK(length(target_phrase) > 0), 
  language_pair TEXT NOT NULL CHECK(length(language_pair) > 0), 
  category TEXT,
  context TEXT,
  frequency INTEGER DEFAULT 0,
  confidence INTEGER,
  usage_count INTEGER DEFAULT 0,
  created_at INTEGER,
  updated_at INTEGER
)
CREATE TABLE phrase_cache (
  source_phrase TEXT PRIMARY KEY NOT NULL CHECK(length(source_phrase) > 0), 
  target_phrase TEXT NOT NULL, 
  language_pair TEXT NOT NULL, 
  last_used INTEGER NOT NULL
)
CREATE INDEX idx_phrase_lang ON phrases(source_phrase, language_pair)
```

---

## ✅ **TODO СПИСОК РЕАЛИЗАЦИИ**

### **1. СИСТЕМА ДАННЫХ И КЭШИРОВАНИЯ** ✅ **ЗАВЕРШЕНО + СХЕМА ОБНОВЛЕНА**
- ✅ Реализовать DatabaseManager с обновленной схемой БД - правильная логика `source_*`/`target_*`
- ✅ Создать DictionaryRepository с LRU кэшем - 10k самых частых слов, поддержка `part_of_speech`/`definition`
- ✅ Создать PhraseRepository с категоризацией - 5k фраз, поддержка `category`/`context`/`confidence`
- ✅ Реализовать CacheManager с LRU стратегией - 31 тест, автоматическая очистка по TTL
- ✅ Усовершенствовать UserDataRepository - JSON метаданные, `user_corrections`, `user_translation_edits`
- ⚠️ IntegrityChecker - ожидает реализации (низкий приоритет)

### **2. СИСТЕМА ИСКЛЮЧЕНИЙ И УТИЛИТ**
- Создать exceptions.dart с пользовательскими исключениями - DatabaseInitError, InvalidLangPairError, CacheError, TranslationError
- Реализовать MemoryProfiler - профилирование использования памяти для performance-тестов
- Создать DebugLogger с уровнями логирования - детальное отслеживание работы системы

### **3. ОСНОВНЫЕ СЛОИ ПЕРЕВОДА**

#### **PreProcessingLayer:**
- Нормализация текста - приведение к нижнему регистру, удаление лишних пробелов
- Токенизация на слова и фразы - разбивка текста на отдельные единицы
- Определение языка входящего текста - автоопределение или проверка указанного
- Очистка от специальных символов - подготовка к дальнейшей обработке

#### **PhraseTranslationLayer:**
- Поиск готовых переводов целых фраз - приоритетная обработка устойчивых выражений
- Проверка in-memory кэша частых фраз - быстрый доступ к часто используемым переводам
- Поиск в SQLite базе фраз - для фраз отсутствующих в кэше
- Обновление статистики использования - увеличение счетчиков частотности

#### **DictionaryLayer:**
- Перевод отдельных слов по словарю - основной словарный запас
- Использование in-memory кэша частотных слов - быстрый доступ к частым словам
- Поиск в SQLite базе слов - для слов отсутствующих в кэше
- Обработка неизвестных слов - сохранение оригинала или замена на схожие

#### **GrammarLayer:**
- Применение грамматических правил - согласование частей речи
- Удаление/добавление артиклей - в зависимости от направления перевода
- Замена предлогов по контексту - адаптация к правилам целевого языка
- Коррекция времен и наклонений - приведение к естественным формам

#### **WordOrderLayer:**
- Перестановка слов согласно правилам языка - SVO, SOV и другие структуры
- Применение шаблонов порядка слов - универсальные правила для языковых пар
- Учет синтаксических особенностей - положение определений, обстоятельств
- Обеспечение естественности - плавность и читаемость предложения

#### **PostProcessingLayer:**
- Капитализация первого слова - приведение к правильному регистру
- Восстановление пунктуации - добавление знаков препинания
- Финальное форматирование текста - устранение артефактов перевода
- Проверка читабельности - итоговая валидация качества

### **4. ИНТЕРФЕЙС АДАПТАЦИИ (опционально)**
- Определить интерфейс AdaptationProvider для внешних модулей адаптации
- Обеспечить возможность переопределения переводов через внешний адаптер
- Реализовать механизм внедрения адаптеров в конвейер перевода

### **5. ОСНОВНОЙ ДВИЖОК И КОНВЕЙЕР**
- Создать TranslationContext - передача данных между слоями, история изменений
- Реализовать TranslationPipeline - координация работы слоев, управление потоком обработки
- Создать TranslationEngine - основной публичный API, инициализация, управление состоянием

### **6. КОНФИГУРАЦИЯ И УТИЛИТЫ**
- Создать ConfigManager - настройки библиотеки, параметры слоев, режимы работы
- Реализовать систему инициализации - предзагрузка данных, проверка целостности
- Создать утилиты миграции - обновление схем БД, преобразование данных

### **7. ТЕСТИРОВАНИЕ И КАЧЕСТВО**
- Написать unit тесты для каждого слоя по мере реализации - изолированное тестирование функциональности
- Создать integration тесты - проверка полного конвейера перевода
- Реализовать performance тесты с MemoryProfiler - замеры времени выполнения, использование памяти
- Создать тесты качества - валидация на 10k+ примеров, сравнение с эталонами

### **8. ДОКУМЕНТАЦИЯ И ПРИМЕРЫ**
- Создать документацию API - описание классов, методов, параметров, исключений
- Реализовать примеры использования - базовые сценарии, интеграция в приложения
- Подготовить руководство по отладке - работа с debug mode, анализ проблем

### **9. ФИНАЛИЗАЦИЯ И ОПТИМИЗАЦИЯ**
- Провести оптимизацию производительности - анализ узких мест, улучшение скорости
- Реализовать финальное тестирование - проверка на реальных сценариях использования
- Подготовить пакет к публикации - настройка pubspec.yaml, лицензия, документация

---

**ПРИМЕЧАНИЕ:** 
- Unit тесты разрабатываются параллельно с каждым слоем
- In-memory кэш минимизирует SQLite запросы с автоматическим обновлением при изменении БД
- Debug mode обеспечивает детальную отладку процесса перевода
- IntegrityChecker гарантирует целостность данных при инициализации
- MemoryProfiler помогает в performance-тестировании и оптимизации памяти
