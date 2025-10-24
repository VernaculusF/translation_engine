// ignore_for_file: avoid_print

import 'dart:io';
import 'package:fluent_translate/fluent_translate.dart';

Future<void> main() async {
  // Prepare a temporary database path (for demo)
  final tempDir = await Directory.systemTemp.createTemp('translation_engine_sample_');
  final dbPath = tempDir.path;

  final engine = TranslationEngine();
  await engine.initialize(customDatabasePath: dbPath);

  final result = await engine.translate(
    'Hello,   world!!!',
    sourceLanguage: 'en',
    targetLanguage: 'en',
    context: TranslationContext(
      sourceLanguage: 'en',
      targetLanguage: 'en',
      debugMode: true,
    ),
  );

  print('Original:  ${result.originalText}');
  print('Translated: ${result.translatedText}');
  print('Layers:     ${result.layerResults.length}');
  print('Time:       ${result.processingTimeMs}ms');

  await engine.dispose();
  if (tempDir.existsSync()) {
    await tempDir.delete(recursive: true);
  }
}
