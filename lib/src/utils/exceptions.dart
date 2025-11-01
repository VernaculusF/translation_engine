/// Модель ошибок TranslationEngine
library;

///
///
/// 1. **Исключения (Exception)** — для фатальных ошибок:
///    - Не инициализирован (EngineStateException)
///    - Сбой инициализации (EngineInitializationException)
///    - Сбой I/O (DatabaseInitException, DatabaseQueryException)
///    - Невалидная конфигурация (ConfigException)
///
/// 2. **Result<T>** — для бизнес-логики:
///    - Пустой текст → Result.failure('Empty text', code: 'EMPTY_INPUT')
///    - Нет перевода → Result.failure('No translation found', code: 'NOT_FOUND')
///    - Валидация → Result.failure('Invalid format', code: 'VALIDATION_ERROR')
///
/// 3. **TranslationResult** — для API translate():
///    - Всегда возвращается (без исключений)
///    - hasError=true + errorMessage для бизнес-ошибок
///    - Исключения выбрасываются только для фатальных состояний

/// Базовое исключение для фатальных ошибок перевода
class TranslationException implements Exception {
  final String message;
  TranslationException(this.message);
  
  @override
  String toString() => 'TranslationException: $message';
}

/// Фатальная ошибка инициализации базы данных / хранилища
class DatabaseInitException extends TranslationException {
  DatabaseInitException(super.message);
}

/// Фатальная ошибка выполнения запроса к базе данных
class DatabaseQueryException extends TranslationException {
  DatabaseQueryException(super.message);
}

/// Ошибка валидации данных при импорте/загрузке
/// Используется для критических нарушений схемы данных
class ValidationException extends TranslationException {
  ValidationException(super.message);
}

/// Ошибка конфигурации движка
class ConfigException extends TranslationException {
  ConfigException(super.message);
}
