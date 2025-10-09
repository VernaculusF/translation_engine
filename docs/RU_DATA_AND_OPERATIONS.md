# Руководство по языковым данным и эксплуатации ядра (RU)

Это руководство описывает, как добавлять и обновлять языковые базы данных, эксплуатировать движок в продакшене, дополнять систему и развивать её.

## 1. Структура и типы БД

Движок использует 3 SQLite-базы, автоматически создаваемые DatabaseManager:
- dictionaries.db — словарные пары слов
  - words(id, source_word, target_word, language_pair, part_of_speech, definition, frequency, created_at, updated_at)
  - word_cache(source_word, target_word, language_pair, last_used)
- phrases.db — фразы и выражения
  - phrases(id, source_phrase, target_phrase, language_pair, category, context, frequency, confidence, usage_count, created_at, updated_at)
  - phrase_cache(source_phrase, target_phrase, language_pair, last_used)
- user_data.db — пользовательские данные
  - translation_history(id, original_text, translated_text, language_pair, confidence, processing_time_ms, timestamp, session_id, metadata)
  - user_settings(setting_key, setting_value, description, created_at, updated_at)
  - user_translation_edits(id, original_text, original_translation, user_translation, language_pair, reason, is_approved, created_at, updated_at)
  - user_corrections(id, original_text, corrected_translation, lang_pair, created_at)
  - context_cache(id, context_key, translation_result, language_pair, last_used)

## 2. Как добавить языковые данные

### Импорт словарей (CLI)
- Запуск (FFI CLI, без Flutter-зависимостей):
```
flutter pub get
# Примеры PowerShell (Windows):
# CSV
dart run bin/import_dictionary_cli.dart --db .\data --file .\datasets\dict.csv --format csv --lang en-ru --delimiter ,
# JSON (массив объектов)
dart run bin/import_dictionary_cli.dart --db .\data --file .\datasets\dict.json --format json --lang en-ru
# JSONL (1 JSON-объект на строку)
dart run bin/import_dictionary_cli.dart --db .\data --file .\datasets\dict.jsonl --format jsonl --lang en-ru
```
- Поддерживаемые форматы: CSV (желателен заголовок), JSON (массив), JSONL (по объекту на строку).
- Языковая пара:
  - Можно указать флагом `--lang`, либо колонкой `language_pair` в файле.

### Где взять датасеты (источники)
Ниже перечислены открытые источники, откуда можно получить двуязычные пары слов/фраз. Всегда проверяйте лицензию и условия использования для вашего кейса:
- OPUS / OPUS-MT (Tatoeba, OpenSubtitles, etc.) — параллельные корпуса, можно извлечь частотные пары слов/фраз из сегментов.
- Wiktionary (Викисловарь) — открытые словарные данные; доступны дампы, можно конвертировать в CSV/JSON.
- Tatoeba — коллекция предложений и переводов, хорошо подходит для фраз.
- OpenSubtitles (переводные субтитры) — частотные выражения разговорной речи.
- CC BY ресурсы вузов/сообществ (лексиконы, частотные списки).
- Собственные корпоративные параллельные тексты (соблюдая права и конфиденциальность).

### Требуемый формат входных файлов
Импортер поддерживает гибкую схему, но рекомендуемый минимальный набор полей:

- CSV (с заголовком):
  - Обязательные: source_word, target_word
  - Рекомендуемые: language_pair, part_of_speech, definition, frequency
  - Пример:
```
source_word,target_word,language_pair,part_of_speech,definition,frequency
hello,привет,en-ru,interjection,greeting,120
world,мир,en-ru,noun,planet or humanity,85
```

- JSON (массив объектов):
```
[
  {"source_word":"hello","target_word":"привет","language_pair":"en-ru","part_of_speech":"interjection","definition":"greeting","frequency":120},
  {"source_word":"world","target_word":"мир","language_pair":"en-ru","part_of_speech":"noun","definition":"planet or humanity","frequency":85}
]
```

- JSONL (по одному объекту на строку):
```
{"source_word":"hello","target_word":"привет","language_pair":"en-ru","part_of_speech":"interjection","definition":"greeting","frequency":120}
{"source_word":"world","target_word":"мир","language_pair":"en-ru","part_of_speech":"noun","definition":"planet or humanity","frequency":85}
```

Примечания по полям:
- language_pair (строка формата `xx-yy`, например `en-ru`). Если не указано в файле, используйте флаг `--lang`.
- source_word нормализуется: trim + lower-case (наша БД хранит source_word в нижнем регистре).
- target_word сохраняется как есть (trim).
- part_of_speech и definition опциональны.
- frequency — целое число; при повторных вставках значение увеличивается (агрегация частот).

### Типичные ошибки и их решения
- Конфликт транзакций SQLite: не запускайте параллельные импорты в одну и ту же БД.
- Регистрозависимость: тестовые ожидания должны учитывать, что source_word хранится в нижнем регистре.
- Некорректный формат `language_pair`: допустим только ISO 639-1, образец `en-ru`.
- Пустые поля: `source_word` и `target_word` обязательны.

### Импорт словарей (через код)
```dart path=null start=null
final importer = DictionaryImporter(repository: dictionaryRepo);
final report = await importer.importFile(File('data.jsonl'), format: 'jsonl');
print(report.toMap());
```

### 2.1. Слова (DictionaryRepository)
- Нормализация: source_word приводится к нижнему регистру, лишние пробелы убираются.
- Добавление одной записи:
```dart path=null start=null
await dictionaryRepo.addTranslation('hello', 'привет', 'en-ru', partOfSpeech: 'noun', frequency: 10);
```
- Поиск/получение:
```dart path=null start=null
final exact = await dictionaryRepo.getTranslation('hello', 'en-ru');
final search = await dictionaryRepo.searchByWord('he', 'en-ru');
```
- Bulk-вставка (рекомендовано через транзакцию):
```dart path=null start=null
await dictionaryRepo.executeTransaction((conn) async {
  for (final w in words) {
    await conn.execute(
      'INSERT INTO words (source_word, target_word, language_pair, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
      [w.source, w.target, 'en-ru', now, now],
    );
  }
  return true;
});
```

### 2.2. Фразы (PhraseRepository)
- Нормализация: source_phrase приводится к нижнему регистру, пробелы схлопываются.
- Добавление одной записи:
```dart path=null start=null
await phraseRepo.addPhrase('good morning', 'доброе утро', 'en-ru', category: 'greetings', confidence: 95, frequency: 50);
```
- Поиск по категории/фразе/ключевым словам — см. методы репозитория.

### 2.3. Пользовательские данные (UserDataRepository)
- История переводов:
```dart path=null start=null
await userDataRepo.addToHistory(translationResult, sessionId: 'session-1');
final history = await userDataRepo.getTranslationHistory(languagePair: 'en-ru', limit: 100);
```
- Настройки пользователя:
```dart path=null start=null
await userDataRepo.setSetting('default_language_pair', 'en-ru', description: 'Default pair');
final s = await userDataRepo.getSetting('default_language_pair');
```
- Пользовательские правки:
```dart path=null start=null
await userDataRepo.addTranslationEdit('How are you?', 'Как дела?', 'Как поживаешь?', 'en-ru', reason: 'More natural');
final edits = await userDataRepo.getTranslationEdits(languagePair: 'en-ru');
```

## 3. Обновление и миграции
- Версии схем сейчас 1.0. При обновлениях рекомендуется:
  - Добавлять ALTER TABLE с сохранением данных
  - Поддерживать миграции в DatabaseManager (onUpgrade)
  - Делать backup перед миграцией (копия файлов *.db)

## 4. Эксплуатация и мониторинг
- Ресурсы:
  - Для небольших объемов (<=10k слов): ~128MB RAM достаточно
  - Для средних (<=50k элементов): 256MB+ и, при необходимости, изменённые лимиты кэша
- Кэш:
  - MAX_WORDS_CACHE=10000, MAX_PHRASES_CACHE=5000, TTL=30 мин
  - Метрики: CacheManager.metrics, очистка: cleanupExpired()
- Мониторинг:
  - TranslationPipeline.statistics — глобальные тайминги и слои
  - TranslationResult.performanceReport — на транзакцию
  - Экспорт в APM (Prometheus, Grafana) через адаптер на стороне приложения

## 5. Безопасность и валидация
- Ввод:
  - Ограничивать длину текста (<=10k символов на запрос)
  - Валидировать языковые коды (ISO 639-1) и пары
- Malicious input:
  - PreProcessingLayer очищает HTML/Markdown, не исполнять HTML/JS
  - Избегать тяжелых regex, тестировать офлайн
- Логи и ПДн:
  - debugMode=off в проде, не логировать контент на INFO
  - Хранение истории — дать пользователю возможность выключить

## 6. Расширение и развитие
- Слои:
  - Добавлять новые правила в Grammar/WordOrder/PostProcessing и покрывать тестами
  - Для новых языков — расширять словари/фразы и правила word order
- Производительность:
  - E2E-тесты + бенчмарки
  - Снять p50/p95/p99, горячие места слоев оптимизировать
- CI/CD:
  - Анализатор + тесты на PR
  - Отчеты о перфе на nightly или вручную

## 7. Практические рекомендации
- Инициализировать Engine при старте приложения
- Переиспользовать singleton Engine
- Делать дебаунс вызовов translate() в UI
- Разрешить userId/sessionId для трассировки и метрик по пользователям
- Делать регулярные бэкапы *.db и обновлять индексы при росте объема
