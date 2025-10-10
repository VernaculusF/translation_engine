/// Translation Engine Library
/// 
/// A Flutter library for offline text translation with local database support.
/// 
/// Example usage:
/// ```dart
/// import 'package:fluent_translate/fluent_translate.dart';
/// 
/// final engine = TranslationEngine();
/// await engine.initialize();
/// 
/// final result = await engine.translate(
///   'Hello world',
///   sourceLanguage: 'en',
///   targetLanguage: 'ru',
/// );
/// 
/// print('Translation: ${result.translatedText}');
/// ```
library fluent_translate;

// Core exports
export 'src/core/translation_engine.dart';
export 'src/core/translation_context.dart';
export 'src/core/engine_config.dart';

// Models
export 'src/models/translation_result.dart';
export 'src/models/layer_debug_info.dart';

// Data types for advanced usage
export 'src/data/database_types.dart';

// Exceptions
export 'src/utils/exceptions.dart';
