// ignore_for_file: avoid_print

import 'package:fluent_translate/translation_engine.dart';

void main() async {
  try {
    print('Initializing Translation Engine...');
    final engine = TranslationEngine.instance();
    await engine.initialize();
    
    print('Engine initialized successfully!');
    
    // Test simple words
    final testWords = ['he', 'hello', 'world', 'good', 'morning'];
    
    for (final word in testWords) {
      print('\nTesting: "$word"');
      final result = await engine.translate(
        word,
        sourceLanguage: 'en',
        targetLanguage: 'ru',
      );
      
      print('  Result: "${result.translatedText}"');
      if (result.layerResults.isNotEmpty) {
        print('  Layers:');
        for (final layer in result.layerResults) {
          print('    ${layer.layerName}: ${layer.processingTimeMs}ms');
        }
      }
    }
    
    await engine.dispose();
    print('\nTest completed!');
  } catch (e) {
    print('Error: $e');
  }
}