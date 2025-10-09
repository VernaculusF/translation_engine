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
