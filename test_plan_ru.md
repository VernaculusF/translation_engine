# План тестирования: правила Grammar/WordOrder/PostProcessing и целое ядро

Цели:
- Проверить шаблоны правил (JSONL), их целостность и применение слоями.
- Протестировать весь пайплайн с данными en-ru: словарь/фразы + правила.
- Собирать метрики/кэш/очередь без дебага; использовать CLI и детальный вывод JSON.

Подготовка:
1) Убедиться, что шаблоны созданы:
   - rules_templates/en-ru/grammar_rules.jsonl
   - rules_templates/en-ru/word_order_rules.jsonl
   - rules_templates/en-ru/post_processing_rules.jsonl
2) Проверка целостности шаблонов:
   - dart run bin/translate_engine.dart rules-validate --db=./rules_templates --lang=en-ru
   - Ожидается: errors = 0 для всех файлов.

Данные:
3) Загрузить базовые данные en-ru (если ещё нет):
   - dart run bin/translate_engine.dart db --lang=en-ru --db=./translation_data
4) Установить правила (скопировать шаблоны в каталог данных):
   - PowerShell: Copy-Item -Force -Path .\rules_templates\en-ru\*.jsonl -Destination .\translation_data\en-ru\
   - Проверка: должны существовать 3 файла правил в .\translation_data\en-ru\
5) Валидация данных словаря/фраз:
   - dart run bin/translate_engine.dart validate --db=./translation_data --lang=en-ru
   - Ожидается: Validation OK.

Наблюдаемость/метрики/логи:
6) Включить логи и уровень info:
   - dart run bin/translate_engine.dart logs level info
   - dart run bin/translate_engine.dart logs enable
7) Снимок метрик до переводов:
   - dart run bin/translate_engine.dart metrics --db=./translation_data
   - Ожидается: data_access_available=true; cache.total_count=0; очередь pending=0.

Функциональные тесты правил:
8) Программно в тестовом приложении (следующий этап): выполнить 3 перевода из плана (кавычки, числа/пробелы, word order) и проверить визуально результат и метрики. В ядре на текущем этапе фиксируем только наличие правил и готовность пайплайна; сами переводы проверим в translator_app.

Кэш:
11) Прогрев кэша:
   - 3×: dart run bin/translate_engine.dart translate --db=./translation_data --text="hello" --sl=en --tl=ru
   - Затем: dart run bin/translate_engine.dart metrics --db=./translation_data
   - Ожидается: рост word_hits/phrase_hits или общий hit_rate > 0 при повторах.
12) Очистка кэша и сверка:
   - dart run bin/translate_engine.dart cache stats
   - dart run bin/translate_engine.dart cache clear all
   - dart run bin/translate_engine.dart cache stats (ожидается обнуление счётчиков записей).

Очередь/таймаут (smoke):
13) Снизить max_pending и отправить серию запросов (псевдонагрузка вручную):
   - (Опц.) выполнить 10–20 быстрых translate подряд и наблюдать, что ошибок drop нет при текущей конфигурации по умолчанию.

Итоговые метрики:
14) dart run bin/translate_engine.dart metrics --db=./translation_data
    - Проверить: engine.state=EngineState.ready; pipeline.layers_count >= 6; data_access_available=true; logging.level=info.

Критерии PASS:
- Шаблоны правил проходят rules-validate (errors=0).
- В "translate" JSON видны модификации соответствующих слоёв (was_modified=true), в layer_results присутствует additional_info.
- Метрики/кэш доступны и изменяются после прогрева; validate OK; экспорт/импорт по необходимости работают.
