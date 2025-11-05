# Правила форматирования и шаблоны (RU)

Этот документ описывает, как писать правила для grammar_rules.jsonl, word_order_rules.jsonl и post_processing_rules.jsonl.

- Каждая строка — валидный JSON-объект с полями из соответствующих DTO (см. lib/src/data/*_rules_repository.dart)
- Поле pattern — строка RegExp в синтаксисе Dart; флаги чувствительности: case_sensitive: true/false
- Подстановки в replacement/reorder_template:
  - Используйте $1, $2, … для ссылок на захваченные группы
  - Также поддерживаются ${n} и \$n (в JSON это будет "\\$1")
  - НЕЛЬЗЯ оставлять «$» без цифры — это приведёт к артефактам

Примеры

1) Постобработка: слепленные числа
{"rule_id":"fix_number_spacing","description":"Fix spacing around numbers","pattern":"(\\d)\\s+(\\d)","replacement":"$1$2","priority":1}

2) Слова с дефисом
{"rule_id":"fix_hyphenated_words","pattern":"(\\w)\\s+-\\s+(\\w)","replacement":"$1-$2","priority":2}

3) Синтаксис порядка слов (упрощённо)
{"rule_id":"swap_noun_adj","source_language":"en","target_language":"ru","source_order":"svo","target_order":"svo","pattern":"(\\b\\w+\\b)\\s+(\\b\\w+\\b)","reorder_template":"$2 $1","priority":1}

Рекомендации

- Начинайте с низкого приоритета (1..10); более сложные/опасные правила делайте ниже по списку
- Делайте паттерны максимально узкими, чтобы не зацеплять нерелевантный текст
- Тестируйте правила локально на небольших корпусах перед выкладкой
- Для языка RU не используйте агрессивные изменения регистра — регистр сохраняет движок; заменяйте только нужные фрагменты
