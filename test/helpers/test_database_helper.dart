import 'dart:io';

/// Вспомогательные утилиты для тестов JSONL-хранилища
class TestDataSession {
  final Directory baseDir; // уникальная временная папка
  final Directory dataDir; // baseDir/translation_data

  TestDataSession(this.baseDir, this.dataDir);

  Future<void> cleanup() async {
    if (baseDir.existsSync()) {
      await baseDir.delete(recursive: true);
    }
  }
}

class TestDataHelper {
  /// Создать тестовую сессию с отдельной translation_data директорией
  static Future<TestDataSession> createSession() async {
    final base = await Directory.systemTemp.createTemp('translation_engine_jsonl_test_');
final data = Directory('${base.path}${Platform.pathSeparator}translation_data');
    if (!data.existsSync()) {
      data.createSync(recursive: true);
    }
    return TestDataSession(base, data);
  }
}
