# Fluent Translate: Инструкция по эксплуатации (RU)

Статус: ранняя тестовая версия.

Пакет предоставляет офлайн движок перевода с послойной обработкой и файловым JSONL-хранилищем для словаря и фраз.

- Имя пакета: fluent_translate
- Хранилище: JSONL-файлы
- Каталог данных по умолчанию: ./translation_data

1) Установка

Добавьте в pubspec.yaml:

```
dependencies:
  fluent_translate: ^0.0.1
```

Затем установите зависимости:

```
dart pub get
```

2) Подготовка файлов данных

Вариант A: встроенный CLI для загрузки данных из внешнего репозитория

- Загрузить английский→русский в ./translation_data
```
dart run fluent_translate:translate_engine db --lang=en-ru --db=./translation_data
```
- Показать доступные языковые пары
```
dart run fluent_translate:translate_engine db --list
```
- Загрузить все доступные пары
```
dart run fluent_translate:translate_engine db --db=./translation_data
```

Вариант B: импорт собственных CSV/JSON/JSONL

Используйте утилиты импорта программно (CSV, JSON-массив, JSON Lines). Пример (словарь):

```dart
import 'dart:io';
import 'package:fluent_translate/src/data/dictionary_repository.dart';
import 'package:fluent_translate/src/tools/dictionary_importer.dart';
import 'package:fluent_translate/src/utils/cache_manager.dart';

Future<void> importSample() async {
  final repo = DictionaryRepository(
    dataDirPath: './translation_data',
    cacheManager: CacheManager(),
  );
  final importer = DictionaryImporter(repository: repo);
  await importer.importFile(
    File('en-ru_dictionary.jsonl'),
    languagePair: 'en-ru',
    format: 'jsonl',
  );
}
```

3) Быстрый старт (Dart/Flutter)

```dart
import 'package:fluent_translate/fluent_translate.dart';

Future<void> main() async {
  final engine = TranslationEngine();
  await engine.initialize(customDatabasePath: './translation_data');

  final result = await engine.translate(
    'Hello, world!',
    sourceLanguage: 'en',
    targetLanguage: 'ru',
  );

  if (result.hasError) {
    print('Ошибка: ${result.errorMessage}');
  } else {
    print('Перевод: ${result.translatedText}');
  }
}
```

4) Структура данных

- Словарь: translation_data/{langPair}/dictionary.jsonl
- Фразы: translation_data/{langPair}/phrases.jsonl
- Пользовательские данные: translation_data/user/
  - translation_history.jsonl
  - user_settings.json
  - user_translation_edits.jsonl

5) Интеграция с Flutter

Используйте path_provider для выбора каталога приложения и передайте путь в initialize(customDatabasePath: ...), чтобы движок работал внутри песочницы приложения.

6) Управление кэшем

- Очистить все кэши
```
await engine.clearCache(type: 'all');
```

7) Примечания

- Это ранняя тестовая версия, ориентированная на JSONL-хранилище и минимально стабильный API.
- Интерфейсы и команды могут развиваться; следите за обновлениями на pub.dev.
