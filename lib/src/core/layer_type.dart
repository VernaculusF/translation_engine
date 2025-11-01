/// Layer Types - типы слоёв обработки в translation pipeline
library;

/// Типы слоев в pipeline
enum LayerType {
  preProcessing,
  phraseLookup,
  dictionary,
  grammar,
  wordOrder,
  postProcessing,
}
