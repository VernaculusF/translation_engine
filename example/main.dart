// ignore_for_file: avoid_print

import 'package:fluent_translate/fluent_translate.dart';

/// Minimal example for pub.dev
/// Run with:
///   dart run example/main.dart
Future<void> main() async {
  final engine = TranslationEngine();
  await engine.initialize(customDatabasePath: './translation_data');

  final result = await engine.translate(
    'Hello, world!',
    sourceLanguage: 'en',
    targetLanguage: 'ru',
  );

  if (result.errorMessage != null && result.errorMessage!.isNotEmpty) {
    print('Error: ${result.errorMessage}');
  } else {
    print('Translated: ${result.translatedText}');
  }

  await engine.dispose();
}
