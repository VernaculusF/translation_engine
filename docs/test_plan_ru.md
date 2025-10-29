# План тестирования изменений ядра и интеграции во внешнем приложении

## 1. Анализатор и сборка
- flutter analyze — без ошибок и предупреждений
- Сборка внешнего приложения с зависимостью fluent_translate — успешна

## 2. Инициализация и путь данных
- Инициализация с default путем: создаётся `./translation_data`, успешная проба записи
- Инициализация с customDatabasePath: корректный `path.join`, проба записи/удаления файла

## 3. Конфигурация EngineConfig
- Применение cache.{words_limit,phrases_limit,ttl_seconds}: отражается в `engine.getCacheInfo()`
- Логи: debug=true и log_level=info — видны JSON-логи; смена через DebugLogger.instance.setLevel()
- Лимиты: security.rate_limiting, queue.max_pending — очередь ограничивается, в метриках `queue.pending/max_pending`
- Таймауты: timeouts.translate_ms — долгий перевод завершается ошибкой timeout; лог `translate.timeout`

Проверка (программно)
```dart path=null start=null
final engine = TranslationEngine();
await engine.initialize(config: {...});
final metrics = engine.getMetrics();
print(metrics);
```

## 4. Кэш LRU+TTL
- Прогрев кэша words/phrases — рост hit-rate, TTL истекает по времени
- Очистка: engine.clearCache('words'|'phrases'|'all')

## 5. CSV/JSON/JSONL импорт
- Импорт CSV с кавычками/экранированием: корректный парсинг
- Импорт JSON/JSONL: отчёт об ошибках, транзакционная запись (tmp+rename)

Программно
```dart path=null start=null
final dictRepo = DictionaryRepository(dataDirPath: './translation_data', cacheManager: CacheManager());
final importer = DictionaryImporter(repository: dictRepo);
final report = await importer.importFile(File('data.csv'), languagePair: 'en-ru');
print(report.toMap());
```

## 6. Метрики и наблюдаемость
- engine.getMetrics() содержит: engine, cache, queue, timeouts, logging, metrics
- hasDataAccess отражён в statistics/data_access_available
- Логи по слоям/пайплайну появляются при debug=true

## 7. DbCommand (по желанию на локалке)
- HTTPS-only: не даёт скачать с http://
- --sha256: несоответствие — отказ; корректный префикс — успех
- retry/backoff: временные 5xx не ломают процесс

## 8. Очередь/таймаут/уверенность
- Вызвать N параллельных translate: pending растёт, при переполнении — drop, лог `queue.drop`
- Длинная обработка — timeout, лог `translate.timeout`
- Проверить confidence: при большем числе модифицированных слоёв и cache hits метрика растёт по новой формуле

## 9. Сброс и завершение
- engine.reset() — снимает ошибку, state=ready

## 10. CLI (локально)
- metrics/config/logs/cache/queue/engine — выполняются, формат JSON корректен