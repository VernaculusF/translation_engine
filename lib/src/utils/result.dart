/// Result type для унифицированной обработки ошибок
///
/// Используется для бизнес-логики где ошибка — это валидное состояние
/// (пустой текст, отсутствие перевода, валидационные ошибки).
/// Для фатальных ошибок (не инициализирован, сбой I/O) используются исключения.
library;

/// Результат операции: успех или ошибка
sealed class Result<T> {
  const Result();
  
  /// Успешный результат
  const factory Result.success(T value) = Success<T>;
  
  /// Ошибка с сообщением
  const factory Result.failure(String error, {String? code, Map<String, dynamic>? details}) = Failure<T>;
  
  /// Проверка успешности
  bool get isSuccess => this is Success<T>;
  
  /// Проверка ошибки
  bool get isFailure => this is Failure<T>;
  
  /// Получить значение (выбрасывает исключение если ошибка)
  T get value {
    return switch (this) {
      Success(value: final v) => v,
      Failure(error: final err) => throw StateError('Result is failure: $err'),
    };
  }
  
  /// Получить значение или null
  T? get valueOrNull {
    return switch (this) {
      Success(value: final v) => v,
      Failure() => null,
    };
  }
  
  /// Получить ошибку или null
  String? get errorOrNull {
    return switch (this) {
      Success() => null,
      Failure(error: final err) => err,
    };
  }
  
  /// Применить функцию к значению, если успех
  Result<R> map<R>(R Function(T value) mapper) {
    return switch (this) {
      Success(value: final v) => Result.success(mapper(v)),
      Failure(error: final err, code: final c, details: final d) => 
        Result.failure(err, code: c, details: d),
    };
  }
  
  /// Применить функцию, возвращающую Result
  Result<R> flatMap<R>(Result<R> Function(T value) mapper) {
    return switch (this) {
      Success(value: final v) => mapper(v),
      Failure(error: final err, code: final c, details: final d) => 
        Result.failure(err, code: c, details: d),
    };
  }
  
  /// Получить значение или дефолтное
  T getOrElse(T defaultValue) {
    return switch (this) {
      Success(value: final v) => v,
      Failure() => defaultValue,
    };
  }
  
  /// Получить значение или выполнить функцию
  T getOrElseGet(T Function() defaultProvider) {
    return switch (this) {
      Success(value: final v) => v,
      Failure() => defaultProvider(),
    };
  }
  
  /// Выполнить функцию в зависимости от результата
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(String error, String? code, Map<String, dynamic>? details) onFailure,
  }) {
    return switch (this) {
      Success(value: final v) => onSuccess(v),
      Failure(error: final err, code: final c, details: final d) => onFailure(err, c, d),
    };
  }
}

/// Успешный результат
final class Success<T> extends Result<T> {
  @override
  final T value;
  
  const Success(this.value);
  
  @override
  String toString() => 'Success($value)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Success<T> && other.value == value;
  }
  
  @override
  int get hashCode => value.hashCode;
}

/// Ошибка с деталями
final class Failure<T> extends Result<T> {
  /// Сообщение об ошибке
  final String error;
  
  /// Код ошибки (опционально)
  final String? code;
  
  /// Дополнительные детали (опционально)
  final Map<String, dynamic>? details;
  
  const Failure(this.error, {this.code, this.details});
  
  @override
  String toString() {
    final codeStr = code != null ? ' (code: $code)' : '';
    final detailsStr = details != null ? ', details: $details' : '';
    return 'Failure($error$codeStr$detailsStr)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Failure<T> && 
      other.error == error && 
      other.code == code;
  }
  
  @override
  int get hashCode => Object.hash(error, code);
}

/// Расширения для работы с nullable Result
extension NullableResultExtension<T> on Result<T>? {
  /// Получить значение или null
  T? get valueOrNull {
    final result = this;
    if (result == null) return null;
    return result.valueOrNull;
  }
  
  /// Проверка успешности (null = false)
  bool get isSuccess => this?.isSuccess ?? false;
}
