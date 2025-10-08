#!/usr/bin/env python3
"""
Automated script to fix all translation layers to match BaseTranslationLayer interface.
This script fixes the common issues found in PostProcessingLayer and WordOrderLayer.
"""

import re
import os

def fix_layer_file(file_path, layer_name, layer_description, layer_priority):
    """Fix a single layer file"""
    print(f"Fixing {file_path}...")
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Remove unused imports
    content = re.sub(r"import '../models/translation_result\.dart';\n", "", content)
    content = re.sub(r"import '../utils/exceptions\.dart';\n", "", content)
    
    # Add description getter
    content = re.sub(
        r"(@override\n  String get name => layerName;\n\n  @override\n  int get priority => layerPriority;)",
        f"@override\n  String get name => layerName;\n\n  @override\n  String get description => '{layer_description}';\n\n  @override\n  LayerPriority get priority => LayerPriority.{layer_priority};",
        content
    )
    
    # Fix canHandle method signature
    content = re.sub(
        r"bool canHandle\(TranslationContext context\)",
        "bool canHandle(String text, TranslationContext context)",
        content
    )
    
    # Fix process method signature
    content = re.sub(
        r"Future<LayerResult> process\(TranslationContext context\)",
        "Future<LayerResult> process(String text, TranslationContext context)",
        content
    )
    
    # Fix LayerDebugInfo creation
    content = re.sub(
        r"final debugInfo = LayerDebugInfo\(\s*layerName: name,\s*startTime: DateTime\.now\(\),\s*\);",
        "final startTime = DateTime.now();",
        content, flags=re.MULTILINE | re.DOTALL
    )
    
    # Fix text processing logic
    content = re.sub(
        r"String currentText = context\.translatedText \?\? '';",
        "String currentText = context.translatedText ?? text;",
        content
    )
    
    # Fix _createResult calls and method
    content = re.sub(
        r"return _createResult\(false, context, stopwatch, debugInfo, '([^']+)'\);",
        r"return _createResult(text, false, stopwatch, startTime, '\1');",
        content
    )
    
    # Replace debugInfo.details usage with additional info parameter
    content = re.sub(
        r"debugInfo\.details\['([^']+)'\] = ([^;]+);",
        r"// \1: \2 (moved to additionalInfo)",
        content
    )
    
    # Fix the main _createResult method
    old_create_result = re.search(
        r"LayerResult _createResult\(\s*.*?\s*\) \{.*?\}",
        content, 
        re.MULTILINE | re.DOTALL
    )
    
    if old_create_result:
        new_create_result = """LayerResult _createResult(
    String processedText,
    bool success, 
    Stopwatch stopwatch, 
    DateTime startTime,
    [String? error,
    Map<String, dynamic>? additionalInfo]
  ) {
    stopwatch.stop();
    
    final debugInfo = LayerDebugInfo(
      layerName: name,
      processingTimeMs: stopwatch.elapsedMilliseconds,
      isSuccessful: success,
      hasError: error != null,
      errorMessage: error,
      additionalInfo: additionalInfo ?? {},
    );

    if (success) {
      return LayerResult.success(
        processedText: processedText,
        debugInfo: debugInfo,
      );
    } else {
      return LayerResult.error(
        originalText: processedText,
        errorMessage: error ?? 'Unknown error',
        debugInfo: debugInfo,
      );
    }
  }"""
        content = content.replace(old_create_result.group(0), new_create_result)
    
    # Save the fixed file
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Fixed {file_path}")

def main():
    # PostProcessingLayer
    fix_layer_file(
        "lib/src/layers/post_processing_layer.dart",
        "PostProcessingLayer", 
        "Post-processing layer: final text formatting, capitalization, punctuation, and quality assessment",
        "postProcessing"
    )
    
    # WordOrderLayer  
    fix_layer_file(
        "lib/src/layers/word_order_layer.dart",
        "WordOrderLayer",
        "Word order layer: reorders words according to target language syntax (SVO, SOV, VSO, etc.)",
        "wordOrder"
    )
    
    print("All layers have been fixed!")

if __name__ == "__main__":
    main()