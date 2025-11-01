/// Memory Manager - управление памятью для in-memory индексов репозиториев
///
/// Контролирует потребление памяти, реализует lazy-loading и LRU-выгрузку
/// языковых пар для масштабируемости системы.
library;

import 'dart:async';
import 'debug_logger.dart';
import 'metrics.dart';

/// Метаданные загруженной языковой пары
class LanguagePairMetadata {
  final String languagePair;
  DateTime lastAccessTime;
  int estimatedSizeBytes;
  int accessCount;
  
  LanguagePairMetadata({
    required this.languagePair,
    required this.lastAccessTime,
    this.estimatedSizeBytes = 0,
    this.accessCount = 0,
  });
  
  /// Обновить время последнего доступа
  void touch() {
    lastAccessTime = DateTime.now();
    accessCount++;
  }
  
  Map<String, dynamic> toJson() => {
    'language_pair': languagePair,
    'last_access_time': lastAccessTime.toIso8601String(),
    'estimated_size_bytes': estimatedSizeBytes,
    'estimated_size_mb': (estimatedSizeBytes / (1024 * 1024)).toStringAsFixed(2),
    'access_count': accessCount,
  };
}

/// Callback для выгрузки языковой пары из репозитория
typedef UnloadCallback = Future<void> Function(String languagePair);

/// Callback для оценки размера языковой пары
typedef SizeEstimator = int Function(String languagePair);

/// Memory Manager - управление памятью репозиториев
class MemoryManager {
  /// Максимальное потребление памяти (байты)
  final int maxMemoryBytes;
  
  /// Максимальное количество загруженных языковых пар
  final int maxLanguagePairs;
  
  /// Порог для запуска выгрузки (0.0 - 1.0)
  final double evictionThreshold;
  
  /// Callback для выгрузки языковой пары
  final Map<String, UnloadCallback> _unloadCallbacks = {};
  
  /// Callback для оценки размера языковой пары
  final Map<String, SizeEstimator> _sizeEstimators = {};
  
  /// Загруженные языковые пары
  final Map<String, LanguagePairMetadata> _loaded = {};
  
  /// Лок для безопасной работы
  final _lock = <String>{};
  
  MemoryManager({
    this.maxMemoryBytes = 256 * 1024 * 1024, // 256 MB по умолчанию
    this.maxLanguagePairs = 50, // Макс. 50 пар одновременно
    this.evictionThreshold = 0.8, // Начать выгрузку при 80%
  });
  
  /// Регистрация репозитория для управления памятью
  void registerRepository(
    String repositoryName,
    UnloadCallback unloadCallback,
    SizeEstimator sizeEstimator,
  ) {
    _unloadCallbacks[repositoryName] = unloadCallback;
    _sizeEstimators[repositoryName] = sizeEstimator;
    
    DebugLogger.instance.info('memory.repository_registered', fields: {
      'repository': repositoryName,
    });
  }
  
  /// Отметить доступ к языковой паре
  Future<void> touchLanguagePair(
    String repositoryName,
    String languagePair,
  ) async {
    final key = '$repositoryName:$languagePair';
    
    if (_loaded.containsKey(key)) {
      _loaded[key]!.touch();
    } else {
      // Новая загрузка
      final estimator = _sizeEstimators[repositoryName];
      final estimatedSize = estimator != null ? estimator(languagePair) : 0;
      
      _loaded[key] = LanguagePairMetadata(
        languagePair: languagePair,
        lastAccessTime: DateTime.now(),
        estimatedSizeBytes: estimatedSize,
        accessCount: 1,
      );
      
      MetricsRegistry.instance.counter('memory.lang_pairs_loaded').inc();
      DebugLogger.instance.debug('memory.lang_pair_loaded', fields: {
        'repository': repositoryName,
        'language_pair': languagePair,
        'estimated_size_mb': (estimatedSize / (1024 * 1024)).toStringAsFixed(2),
      });
    }
    
    // Проверка необходимости выгрузки
    await _checkEviction();
  }
  
  /// Принудительная выгрузка языковой пары
  Future<void> unloadLanguagePair(
    String repositoryName,
    String languagePair,
  ) async {
    final key = '$repositoryName:$languagePair';
    
    if (_lock.contains(key)) {
      DebugLogger.instance.warning('memory.unload_skipped_locked', fields: {
        'key': key,
      });
      return;
    }
    
    _lock.add(key);
    try {
      final callback = _unloadCallbacks[repositoryName];
      if (callback != null) {
        await callback(languagePair);
      }
      
      final metadata = _loaded.remove(key);
      if (metadata != null) {
        MetricsRegistry.instance.counter('memory.lang_pairs_unloaded').inc();
        DebugLogger.instance.info('memory.lang_pair_unloaded', fields: {
          'repository': repositoryName,
          'language_pair': languagePair,
          'was_accessed': metadata.accessCount,
        });
      }
    } finally {
      _lock.remove(key);
    }
  }
  
  /// Проверка необходимости выгрузки и выполнение LRU
  Future<void> _checkEviction() async {
    final currentMemory = estimatedMemoryUsage;
    final currentCount = _loaded.length;
    
    // Проверка лимитов
    final memoryExceeded = currentMemory > (maxMemoryBytes * evictionThreshold);
    final countExceeded = currentCount > (maxLanguagePairs * evictionThreshold);
    
    if (!memoryExceeded && !countExceeded) {
      return;
    }
    
    DebugLogger.instance.warning('memory.eviction_triggered', fields: {
      'current_memory_mb': (currentMemory / (1024 * 1024)).toStringAsFixed(2),
      'max_memory_mb': (maxMemoryBytes / (1024 * 1024)).toStringAsFixed(2),
      'current_count': currentCount,
      'max_count': maxLanguagePairs,
    });
    
    // Сортировка по LRU (от старых к новым)
    final sorted = _loaded.entries.toList()
      ..sort((a, b) => a.value.lastAccessTime.compareTo(b.value.lastAccessTime));
    
    // Выгружаем самые старые до достижения целевого порога
    final targetMemory = (maxMemoryBytes * 0.6).toInt(); // Целевой уровень 60%
    final targetCount = (maxLanguagePairs * 0.6).toInt();
    
    int freedMemory = 0;
    int freedCount = 0;
    
    for (final entry in sorted) {
      if (currentMemory - freedMemory <= targetMemory &&
          currentCount - freedCount <= targetCount) {
        break;
      }
      
      final parts = entry.key.split(':');
      if (parts.length == 2) {
        final repositoryName = parts[0];
        final languagePair = parts[1];
        
        await unloadLanguagePair(repositoryName, languagePair);
        freedMemory += entry.value.estimatedSizeBytes;
        freedCount++;
      }
    }
    
    MetricsRegistry.instance.counter('memory.evictions_performed').inc(freedCount);
    DebugLogger.instance.info('memory.eviction_completed', fields: {
      'freed_count': freedCount,
      'freed_memory_mb': (freedMemory / (1024 * 1024)).toStringAsFixed(2),
      'remaining_count': _loaded.length,
      'remaining_memory_mb': (estimatedMemoryUsage / (1024 * 1024)).toStringAsFixed(2),
    });
  }
  
  /// Оценка текущего потребления памяти
  int get estimatedMemoryUsage {
    return _loaded.values.fold(0, (sum, metadata) => sum + metadata.estimatedSizeBytes);
  }
  
  /// Получить статистику памяти
  Map<String, dynamic> getMemoryReport() {
    final currentMemory = estimatedMemoryUsage;
    final memoryUsagePercent = maxMemoryBytes > 0
        ? (currentMemory / maxMemoryBytes * 100).toStringAsFixed(1)
        : '0.0';
    
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'limits': {
        'max_memory_bytes': maxMemoryBytes,
        'max_memory_mb': (maxMemoryBytes / (1024 * 1024)).toStringAsFixed(2),
        'max_language_pairs': maxLanguagePairs,
        'eviction_threshold_percent': (evictionThreshold * 100).toStringAsFixed(0),
      },
      'current': {
        'estimated_memory_bytes': currentMemory,
        'estimated_memory_mb': (currentMemory / (1024 * 1024)).toStringAsFixed(2),
        'memory_usage_percent': memoryUsagePercent,
        'loaded_language_pairs': _loaded.length,
        'pairs_usage_percent': maxLanguagePairs > 0
            ? (_loaded.length / maxLanguagePairs * 100).toStringAsFixed(1)
            : '0.0',
      },
      'loaded_pairs': _loaded.values.map((m) => m.toJson()).toList(),
      'repositories': {
        'registered': _unloadCallbacks.keys.toList(),
        'count': _unloadCallbacks.length,
      },
    };
  }
  
  /// Принудительная очистка всех загруженных пар
  Future<void> clearAll() async {
    final keys = List<String>.from(_loaded.keys);
    for (final key in keys) {
      final parts = key.split(':');
      if (parts.length == 2) {
        await unloadLanguagePair(parts[0], parts[1]);
      }
    }
    DebugLogger.instance.info('memory.cleared_all');
  }
  
  /// Очистка ресурсов
  void dispose() {
    _unloadCallbacks.clear();
    _sizeEstimators.clear();
    _loaded.clear();
    _lock.clear();
  }
}
