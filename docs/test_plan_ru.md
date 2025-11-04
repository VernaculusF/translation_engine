# План тестирования изменений ядра и интеграции во внешнем приложении

## 🎯 Цель тестирования

Проверить работоспособность Translation Engine в составе внешнего браузерного приложения (Flutter Web клиент + REST API сервер на Dart).

## ⚠️ Текущие ограничения системы

### ✅ Доступно для тестирования:
- **Слои:** PreProcessing, PhraseTranslation, Dictionary (полностью функциональны)
- **Данные:** Словари слов + фразовые переводы для en-ru (доступны в GitHub)
- **Репозитории:** DictionaryRepository, PhraseRepository (JSONL файловое хранилище)
- **Кэш:** LRU+TTL с метриками, конфигурируемые лимиты
- **Очередь:** Rate limiting, max_pending, queue drop policy
- **Метрики:** Полная наблюдаемость (engine.getMetrics())
- **Конфигурация:** EngineConfig с debug/log_level/timeouts/degrade mode
- **CLI:** 10 команд (db, import, metrics, config, logs, cache, queue, engine, validate, export)

### ⚠️ Ограничено (слои без данных):
- **Grammar/WordOrder/PostProcessing слои** работают, но **не имеют правил** в GitHub репозитории
- Эти слои возвращают текст **без изменений** (pass-through режим)
- Для полного тестирования нужны файлы: `grammar_rules.jsonl`, `word_order_rules.jsonl`, `post_processing_rules.jsonl`

### 🎯 Рекомендуемая стратегия:
1. Тестировать **только доступные слои**: PreProcessing + PhraseTranslation + Dictionary
2. Использовать **degrade mode** с `allowed_layers: ['phraseLookup', 'dictionary']`
3. Документировать текущее покрытие и планировать расширение после добавления правил

---

## 📦 Структура тестового приложения

```
test_app/
├── server/
│   ├── bin/server.dart          # REST API сервер (Dart + shelf)
│   ├── pubspec.yaml             # dependencies: shelf, fluent_translate
│   └── README.md
├── client/
│   ├── lib/main.dart            # Flutter Web клиент
│   ├── web/index.html
│   ├── pubspec.yaml             # dependencies: flutter, http
│   └── README.md
└── data/
    └── translation_data/         # Загруженные словари через CLI
        └── en-ru/
            ├── dictionary.jsonl  # Словарь слов
            ├── phrases.jsonl     # Фразовые переводы
            └── version.json      # Версия формата данных
```

---

## 1. Анализатор и сборка

**Цель:** Убедиться, что код проходит статический анализ и успешно собирается.

### Проверки:
- ✅ `flutter analyze` — без ошибок и предупреждений
- ✅ Сборка внешнего приложения с зависимостью `fluent_translate` — успешна
- ✅ `dart analyze` для серверной части — без ошибок

### Команды:
```bash
cd translation_engine
flutter analyze

cd ../test_app/server
dart analyze

cd ../client
flutter analyze
```

---

## 2. Инициализация и путь данных

**Цель:** Проверить корректность инициализации движка с различными путями к данным.

### Проверки:
- ✅ Инициализация с default путем: создаётся `./translation_data`, успешная проба записи
- ✅ Инициализация с customDatabasePath: корректный `path.join`, проба записи/удаления файла
- ✅ Обработка ошибок: недоступный путь → `EngineInitializationException`

### Код проверки (серверная часть):
```dart
import 'package:fluent_translate/fluent_translate.dart';

void main() async {
  // Тест 1: Default path
  final engine1 = TranslationEngine();
  await engine1.initialize();
  print('Default path initialized: ${engine1.state}');
  
  // Тест 2: Custom path
  final engine2 = await TranslationEngine.create(reset: true);
  await engine2.initialize(customDatabasePath: './test_data');
  print('Custom path initialized: ${engine2.state}');
  
  // Проверка: директория создана
  final dir = Directory('./test_data');
  print('Directory exists: ${dir.existsSync()}');
}
```

---

## 3. Конфигурация EngineConfig

**Цель:** Проверить применение конфигурации и её отражение в метриках.

### Проверки:
- ✅ Применение `cache.{words_limit,phrases_limit,ttl_seconds}`: отражается в `engine.getCacheInfo()`
- ✅ Логи: `debug=true` и `log_level=info` — видны JSON-логи; смена через `DebugLogger.instance.setLevel()`
- ✅ Лимиты: `security.rate_limiting`, `queue.max_pending` — очередь ограничивается, в метриках `queue.pending/max_pending`
- ✅ Таймауты: `timeouts.translate_ms` — долгий перевод завершается ошибкой timeout; лог `translate.timeout`

### Код проверки:
```dart
final engine = TranslationEngine();

final config = {
  'cache': {
    'words_limit': 5000,
    'phrases_limit': 2000,
    'ttl_seconds': 1800, // 30 минут
  },
  'debug': true,
  'log_level': 'info',
  'security': {
    'rate_limiting': true,
    'max_requests_per_minute': 30,
  },
  'queue': {
    'max_pending': 10,
  },
  'timeouts': {
    'translate_ms': 3000,
  },
};

await engine.initialize(config: config);

// Проверка кэша
final cacheInfo = engine.getCacheInfo();
print('Cache limits: ${cacheInfo}');
assert(cacheInfo['words_limit'] == 5000 || cacheInfo.containsKey('words'));

// Проверка метрик
final metrics = engine.getMetrics();
print('Queue config: ${metrics['queue']}');
print('Logging config: ${metrics['logging']}');
print('Timeouts: ${metrics['timeouts']}');
```

---

## 4. Кэш LRU+TTL

**Цель:** Проверить работу кэша с LRU выталкиванием и TTL истечением.

### Проверки:
- ✅ Прогрев кэша words/phrases — рост hit-rate
- ✅ TTL истекает по времени (настроить короткий TTL для теста)
- ✅ Очистка: `engine.clearCache('words'|'phrases'|'all')`

### Код проверки:
```dart
// Прогрев кэша
for (int i = 0; i < 5; i++) {
  await engine.translate('hello', sourceLanguage: 'en', targetLanguage: 'ru');
}

final cacheInfo = engine.getCacheInfo();
print('Cache hit rate: ${cacheInfo}');
// Ожидаем рост hits

// Очистка
await engine.clearCache('words');
final afterClear = engine.getCacheInfo();
print('After clear: ${afterClear}');
```

---

## 5. CSV/JSON/JSONL импорт

**Цель:** Проверить корректность импорта данных через CLI и программный API.

### Проверки:
- ✅ Импорт CSV с кавычками/экранированием: корректный парсинг
- ✅ Импорт JSON/JSONL: отчёт об ошибках, транзакционная запись (tmp+rename)
- ✅ Нормализация Unicode (NFC): после импорта поиск по словам/фразам с диакритикой отрабатывает корректно

### CLI проверка:
```bash
# Загрузка данных из GitHub
dart run bin/translate_engine.dart db --lang=en-ru --db=./test_data

# Импорт локального CSV
dart run bin/translate_engine.dart import --file=./data.csv --type=dictionary --lang=en-ru
```

### Программная проверка:
```dart
final dictRepo = DictionaryRepository(
  dataDirPath: './test_data',
  cacheManager: CacheManager(),
);

final importer = DictionaryImporter(repository: dictRepo);
final report = await importer.importFile(
  File('data.csv'),
  languagePair: 'en-ru',
);

print('Import report: ${report.toMap()}');
print('Total: ${report.total}, Imported: ${report.insertedOrUpdated}, Errors: ${report.errors.length}');

// Проверка Unicode
final entry = await dictRepo.getTranslation('café', 'en-ru');
print('Unicode search result: ${entry?.targetWord}');
```

---

## 6. Метрики и наблюдаемость

**Цель:** Проверить полноту метрик и возможность наблюдения за состоянием системы.

### Проверки:
- ✅ `engine.getMetrics()` содержит: engine, pipeline, cache, queue, timeouts, logging, metrics
- ✅ `hasDataAccess` отражён в `pipeline.data_access_available`
- ✅ Версионирование: после перезаписи данных в `<lang>/version.json` указана актуальная версия
- ✅ Логи по слоям/пайплайну появляются при `debug=true`

### Код проверки:
```dart
final metrics = engine.getMetrics();

print('Engine state: ${metrics['engine']['state']}');
print('Data access: ${metrics['pipeline']['data_access_available']}');
print('Cache info: ${metrics['cache']}');
print('Queue status: ${metrics['queue']}');
print('Logging: ${metrics['logging']}');

// Проверка структуры метрик
assert(metrics.containsKey('engine'));
assert(metrics.containsKey('pipeline'));
assert(metrics.containsKey('cache'));
assert(metrics.containsKey('queue'));
```

---

## 7. DbCommand (CLI тестирование)

**Цель:** Проверить безопасность и надёжность загрузки данных из внешних источников.

### Проверки:
- ✅ HTTPS-only: не даёт скачать с `http://`
- ✅ `--sha256`: несоответствие — отказ; корректный префикс — успех
- ✅ retry/backoff: временные 5xx не ломают процесс
- ✅ Atomic write: tmp+rename, файлы не повреждаются при сбое

### Команды проверки:
```bash
# Тест 1: HTTP должен отклониться
dart run bin/translate_engine.dart db --lang=en-ru --source=http://unsafe.com
# Ожидается: Error: Only HTTPS sources are allowed

# Тест 2: SHA-256 проверка (если задан)
dart run bin/translate_engine.dart db --lang=en-ru --sha256=abc123
# Ожидается: Hash mismatch при неверном хэше

# Тест 3: Успешная загрузка
dart run bin/translate_engine.dart db --lang=en-ru --db=./test_data
# Ожидается: Download completed successfully

# Тест 4: Список доступных языков
dart run bin/translate_engine.dart db --list
```

---

## 8. Очередь/таймаут/confidence/деградация

**Цель:** Проверить устойчивость системы к перегрузкам и корректность режима деградации.

### Проверки:
- ✅ Вызвать N параллельных translate: pending растёт, при переполнении — drop, лог `queue.drop`
- ✅ Длинная обработка — timeout, лог `translate.timeout`
- ✅ Проверить confidence: при большем числе модифицированных слоёв и cache hits метрика растёт
- ✅ Degrade-mode: задать `config.degrade = {enabled:true, allowed_layers:['phraseLookup','dictionary']}`; убедиться, что в логах есть `pipeline.degrade`, а результат формируется только разрешёнными слоями

### Код проверки:
```dart
// Тест 1: Очередь и drop policy
final configQueue = {
  'queue': {'max_pending': 5},
  'debug': true,
  'log_level': 'info',
};

await engine.initialize(config: configQueue);

// Запустить 20 параллельных запросов
final futures = <Future>[];
for (int i = 0; i < 20; i++) {
  futures.add(engine.translate('test $i', sourceLanguage: 'en', targetLanguage: 'ru'));
}

final results = await Future.wait(futures);
final dropped = results.where((r) => r.errorMessage?.contains('Queue is full') ?? false).length;
print('Dropped requests: $dropped / 20');

// Тест 2: Timeout
final configTimeout = {'timeouts': {'translate_ms': 100}};
await engine.initialize(config: configTimeout);

final result = await engine.translate('long text...', sourceLanguage: 'en', targetLanguage: 'ru');
if (result.errorMessage?.contains('timed out') ?? false) {
  print('Timeout detected correctly');
}

// Тест 3: Confidence
final translateResult = await engine.translate('hello world', sourceLanguage: 'en', targetLanguage: 'ru');
print('Confidence: ${translateResult.confidence}');
print('Layers processed: ${translateResult.layersProcessed}');

// Тест 4: Degrade mode
final configDegrade = {
  'degrade': {
    'enabled': true,
    'allowed_layers': ['phraseLookup', 'dictionary'],
  },
  'debug': true,
};

await engine.initialize(config: configDegrade);
final degradeResult = await engine.translate('test', sourceLanguage: 'en', targetLanguage: 'ru');
print('Degrade result layers: ${degradeResult.layerResults.map((l) => l.layerName).toList()}');
// Ожидается: только PreProcessingLayer, PhraseTranslationLayer, DictionaryLayer
```

---

## 9. Сброс и завершение

**Цель:** Проверить корректность управления жизненным циклом движка.

### Проверки:
- ✅ `engine.reset()` — снимает ошибку, `state=ready`
- ✅ Использовать `TranslationEngine.create(reset:true)` для безопасного пересоздания инстанса без гонок
- ✅ `engine.dispose()` — корректное освобождение ресурсов

### Код проверки:
```dart
// Тест 1: Reset после ошибки
try {
  // Симулируем ошибку
  await engine.translate('', sourceLanguage: 'en', targetLanguage: 'ru');
} catch (e) {
  print('Error occurred: $e');
}

engine.reset();
print('State after reset: ${engine.state}'); // Ожидается: ready

// Тест 2: Безопасное пересоздание
final newEngine = await TranslationEngine.create(reset: true);
await newEngine.initialize();
print('New engine state: ${newEngine.state}');

// Тест 3: Dispose
await newEngine.dispose();
print('State after dispose: ${newEngine.state}'); // Ожидается: disposed
```

---

## 10. CLI команды (локальное тестирование)

**Цель:** Проверить работу всех CLI команд и корректность вывода JSON.

### Команды проверки:
```bash
# Метрики
dart run bin/translate_engine.dart metrics --db=./test_data
# Ожидается: JSON с engine/cache/queue/metrics

# Конфигурация
dart run bin/translate_engine.dart config show --db=./test_data
# Ожидается: JSON с текущей конфигурацией

# Логирование
dart run bin/translate_engine.dart logs level info
dart run bin/translate_engine.dart logs enable

# Кэш
dart run bin/translate_engine.dart cache stats
dart run bin/translate_engine.dart cache clear all

# Очередь
dart run bin/translate_engine.dart queue stats

# Engine
dart run bin/translate_engine.dart engine reset

# Валидация данных
dart run bin/translate_engine.dart validate --db=./test_data --lang=en-ru

# Экспорт
dart run bin/translate_engine.dart export --db=./test_data --lang=en-ru --output=./export.json
```

---

## 📊 REST API тестирование (браузерное приложение)

### Архитектура:
```
Flutter Web Client → HTTP/JSON → Dart REST Server → TranslationEngine → JSONL Data
```

### Endpoint: `POST /translate`

#### Запрос:
```json
{
  "text": "hello",
  "sl": "en",
  "tl": "ru"
}
```

#### Ответ (успех):
```json
{
  "translatedText": "привет"
}
```

#### Ответ (ошибка):
```json
{
  "error": "Empty text"
}
```

### Тест-кейсы:

#### 1. Базовые переводы
- ✅ Одно слово: `hello` → `привет`
- ✅ Несколько слов: `good morning` → `доброе утро`
- ✅ Неизвестное слово: `xyzabc123` → `xyzabc123` (возврат оригинала)
- ✅ Mixed case: `HELLO` → нормализация и перевод

#### 2. Граничные случаи
- ✅ Пустой текст: `{"text":""}` → `{"error":"Empty text"}`
- ✅ Очень длинный текст (1000+ символов)
- ✅ UTF-8: `café`, `naïve`, `Москва`
- ✅ Специальные символы: `!@#$%^&*()`
- ✅ Числа: `123`, `3.14`

#### 3. HTTP протокол
- ✅ CORS preflight: `OPTIONS /translate`
- ✅ Content-Type: `application/json`
- ✅ HTTP статусы: 200 OK, 400 Bad Request, 500 Internal Error
- ✅ Cross-origin запросы из браузера

#### 4. Производительность
- ✅ Latency измерение: среднее время ответа < 100ms
- ✅ 10 параллельных запросов
- ✅ 100 последовательных запросов
- ✅ Проверка утечек памяти (memory profiling)

#### 5. Отказоустойчивость
- ✅ Некорректный JSON в запросе
- ✅ Отсутствие обязательных полей (`text`, `sl`, `tl`)
- ✅ Недоступность данных (удалить `translation_data`)
- ✅ Повторные запросы после ошибки

---

## 🧪 Примеры Flutter Web клиента

### Базовый тест:
```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> testTranslate() async {
  final uri = Uri.parse('http://localhost:8080/translate');
  
  final response = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'text': 'hello',
      'sl': 'en',
      'tl': 'ru',
    }),
  );
  
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    print('Translation: ${data['translatedText']}');
  } else {
    print('Error: ${response.statusCode}');
  }
}
```

### Batch тест (10 запросов):
```dart
Future<void> batchTest() async {
  final words = ['hello', 'world', 'cat', 'dog', 'book', 'car', 'house', 'tree', 'water', 'fire'];
  final stopwatch = Stopwatch()..start();
  
  final futures = words.map((word) async {
    final uri = Uri.parse('http://localhost:8080/translate');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': word, 'sl': 'en', 'tl': 'ru'}),
    );
    return jsonDecode(response.body)['translatedText'];
  });
  
  final results = await Future.wait(futures);
  stopwatch.stop();
  
  print('Translated ${results.length} words in ${stopwatch.elapsedMilliseconds}ms');
  print('Average: ${stopwatch.elapsedMilliseconds / results.length}ms per word');
}
```

---

## 🚨 Известные риски и ограничения

### Критичные:
1. **Отсутствие правил** в GitHub для Grammar/WordOrder/PostProcessing слоёв
   - **Воздействие:** Эти слои не влияют на результат (pass-through)
   - **Митигация:** Тестировать в degrade mode только доступные слои
   
2. **Ограниченный набор языковых пар**
   - **Доступно:** только en-ru
   - **Воздействие:** Невозможно протестировать другие языки
   - **Митигация:** Документировать текущее покрытие

3. **Небольшие тестовые датасеты**
   - **Воздействие:** Невозможно проверить производительность на больших объёмах
   - **Митигация:** Синтетические нагрузочные тесты

### Некритичные:
4. **Локальное окружение** (без продакшн-деплоя)
5. **Отсутствие мониторинга** в реальном времени
6. **Ограниченное покрытие edge-cases**

---

## ✅ Критерии успешности тестирования

### Обязательные (must-have):
- ✅ Все базовые переводы работают (слова + простые фразы)
- ✅ REST API корректно обрабатывает запросы/ошибки
- ✅ Кэш повышает производительность (hit rate > 50% при повторах)
- ✅ Метрики доступны и корректны
- ✅ CLI команды выполняются без ошибок
- ✅ Нет утечек памяти при 100+ запросах

### Желательные (nice-to-have):
- ✅ Degrade mode работает корректно
- ✅ Timeout и rate limiting функционируют
- ✅ Unicode обрабатывается корректно (NFC нормализация)
- ✅ Параллельные запросы не вызывают race conditions

---

## 📋 Чек-лист выполнения

```
[ ] 1. Подготовка окружения (server + client + data)
[ ] 2. Загрузка данных через CLI (db command)
[ ] 3. Базовые функциональные тесты (п.1-10)
[ ] 4. REST API тестирование (браузерный клиент)
[ ] 5. Производительность и нагрузочные тесты
[ ] 6. Граничные случаи и отказоустойчивость
[ ] 7. Документирование результатов
[ ] 8. Gap-анализ (plan vs reality)
[ ] 9. Рекомендации по доработке
[ ] 10. Итоговый отчёт
```

---

## 📝 Шаблон отчёта о тестировании

```markdown
# Отчёт о тестировании Translation Engine

## Дата: YYYY-MM-DD
## Тестировщик: [Имя]
## Версия ядра: [git commit hash]

### Окружение:
- OS: Windows/Linux/MacOS
- Dart SDK: [версия]
- Flutter SDK: [версия]
- Браузер: Chrome [версия]

### Доступные данные:
- Языковые пары: en-ru
- Словарь слов: [количество записей]
- Фразы: [количество записей]

### Результаты тестов:

#### 1. Инициализация: ✅ PASS
- Default path: OK
- Custom path: OK
- Error handling: OK

#### 2. Конфигурация: ✅ PASS
- Cache limits: OK
- Logging: OK
- Queue: OK
- Timeouts: OK

...

### Найденные проблемы:
1. [Описание проблемы]
   - Severity: Critical/High/Medium/Low
   - Steps to reproduce: ...
   - Expected: ...
   - Actual: ...

### Рекомендации:
1. ...
2. ...

### Общий вывод:
Система [готова/не готова] к использованию с ограничениями: ...
```
