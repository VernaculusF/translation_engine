class TranslationException implements Exception {
  final String message;
  TranslationException(this.message);
  
  @override
  String toString() => 'TranslationException: $message';
}

class DatabaseInitException extends TranslationException {
  DatabaseInitException(super.message);
}

class DatabaseQueryException extends TranslationException {
  DatabaseQueryException(super.message);
}

class ValidationException extends TranslationException {
  ValidationException(super.message);
}
