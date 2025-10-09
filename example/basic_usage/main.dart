// ignore_for_file: avoid_print

import 'dart:io';
import 'package:translation_engine/src/core/translation_engine.dart';
import 'package:translation_engine/src/core/translation_context.dart';

Future<void> main() async {
  // Prepare a temporary database path (for demo)
  final tempDir = await Directory.systemTemp.createTemp('translation_engine_sample_');
  final dbPath = tempDir.path;

  final engine = TranslationEngine.instance(reset: true);
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
