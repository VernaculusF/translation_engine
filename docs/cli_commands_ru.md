# Управление движком из внешнего приложения (через библиотеку fluent_translate)

Ниже — как вызывать функциональность напрямую из ядра (без запуска CLI), с примерами кода.

Инициализация и конфигурация
```dart path=null start=null
import 'package:fluent_translate/src/core/translation_engine.dart';

final engine = TranslationEngine();
await engine.initialize(
  customDatabasePath: './translation_data',
  config: {
    'debug': true,
    'log_level': 'info',
    'cache': {'words_limit': 20000, 'phrases_limit': 10000, 'ttl_seconds': 3600},
    'security': {'rate_limiting': true, 'max_requests_per_minute': 120},
    'queue': {'max_pending': 50},
    'timeouts': {'translate_ms': 5000},
  },
);
```

Метрики и состояние
```dart path=null start=null
final snapshot = engine.getMetrics(); // {'engine': ..., 'cache': ..., 'queue': ..., 'timeouts': ..., 'logging': ..., 'metrics': ...}
```

Логирование
- Управляется конфигом (debug/log_level). Логи — структурированный JSON в stdout приложения (перенаправляйте в файл, если нужно).
- Смена уровня на лету:
```dart path=null start=null
import 'package:fluent_translate/src/utils/debug_logger.dart';
import 'package:fluent_translate/src/core/engine_config.dart';

DebugLogger.instance.setEnabled(true);
DebugLogger.instance.setLevel(LogLevel.info);
```

Кэш
```dart path=null start=null
final cacheInfo = engine.getCacheInfo();
await engine.clearCache(type: 'words'); // 'phrases' | 'all'
```

Очередь и таймауты
- Настраиваются через config.queue.max_pending и config.timeouts.translate_ms
- Снимок очереди: `engine.getMetrics()['queue']`

Сброс
```dart path=null start=null
engine.reset();
```

Импорт данных
- Импортируйте напрямую с помощью импортёров/репозиториев:
```dart path=null start=null
import 'dart:io';
import 'package:fluent_translate/src/data/dictionary_repository.dart';
import 'package:fluent_translate/src/tools/dictionary_importer.dart';

final repo = DictionaryRepository(dataDirPath: './translation_data', cacheManager: CacheManager());
final importer = DictionaryImporter(repository: repo);
final report = await importer.importFile(File('dict.jsonl'), languagePair: 'en-ru');
```

Загрузка с удалённого источника
- Безопаснее делать в вашем приложении: скачайте HTTPS-файл, проверьте SHA-256, положите в `./translation_data/<lang>/dictionary.jsonl` и вызовите импорт.

---

# CLI команды — справочник (локальная отладка)

Запуск: `dart run bin/translate_engine.dart <command> [options]`

- db — загрузка данных из репозитория (для локальной отладки)
  - --lang, --db, --source, --list, --force, --sha256, --allow-any-source, --dry-run
- import/export/validate — работа с файлами
- metrics — показать метрики
- config show/set — показать/применить JSON-конфиг
- logs level|enable|disable — управление логами
- cache stats|clear [words|phrases|all]
- queue stats — статус очереди
- engine reset — мягкий сброс

Примечания
- По умолчанию используется `./translation_data`.
- Логи — JSON в stdout (перенаправляйте в файл при необходимости).
