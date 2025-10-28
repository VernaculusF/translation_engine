library;

import '../layers/base_translation_layer.dart' as base;
import '../layers/pre_processing_layer.dart';
import '../layers/phrase_translation_layer.dart';
import '../layers/dictionary_layer.dart';
import '../layers/grammar_layer.dart';
import '../layers/word_order_layer.dart';
import '../layers/post_processing_layer.dart';
import '../data/grammar_rules_repository.dart';
import '../data/word_order_rules_repository.dart';
import '../data/post_processing_rules_repository.dart';
import '../data/dictionary_repository.dart';
import '../data/phrase_repository.dart';
import '../models/layer_debug_info.dart';
import 'translation_context.dart';
import 'translation_pipeline.dart';

/// Generic adapter to bridge BaseTranslationLayer to TranslationLayer
class LayerAdapter implements TranslationLayer {
  final base.BaseTranslationLayer _layer;
  final LayerType _type;
  bool _enabled;

  LayerAdapter(this._layer, this._type, {bool enabled = true}) : _enabled = enabled;

  @override
  LayerType get layerType => _type;

  @override
  String get name => _layer.name;

  @override
  int get priority => _layer.priority.value;

  @override
  bool get isEnabled => _enabled;

  void setEnabled(bool enabled) => _enabled = enabled;

  @override
  bool canProcess(String text, TranslationContext context) {
    return _layer.canHandle(text, context);
  }

  @override
  Future<({String processedText, LayerDebugInfo debugInfo})> process(
    String text,
    TranslationContext context,
  ) async {
    // Используем оболочку с метриками и валидацией
    final result = await _layer.processWithMetrics(text, context);
    return (processedText: result.processedText, debugInfo: result.debugInfo);
  }
}

/// Factory helpers to create adapters for each concrete layer
class LayerAdaptersFactory {
  static LayerAdapter preProcessing() {
    return LayerAdapter(PreProcessingLayer(), LayerType.preProcessing);
  }

  static LayerAdapter phraseLookup({required PhraseRepository repo}) {
    return LayerAdapter(PhraseTranslationLayer(phraseRepository: repo), LayerType.phraseLookup);
  }

  static LayerAdapter dictionary({required DictionaryRepository repo}) {
    return LayerAdapter(DictionaryLayer(dictionaryRepository: repo), LayerType.dictionary);
  }

  static LayerAdapter grammar({GrammarRulesRepository? repo}) {
    return LayerAdapter(GrammarLayer(grammarRulesRepository: repo), LayerType.grammar);
  }

  static LayerAdapter wordOrder({WordOrderRulesRepository? repo}) {
    return LayerAdapter(WordOrderLayer(wordOrderRepository: repo), LayerType.wordOrder);
  }

  static LayerAdapter postProcessing({PostProcessingRulesRepository? repo}) {
    return LayerAdapter(PostProcessingLayer(postProcessingRepository: repo), LayerType.postProcessing);
  }
}