/// Layer Health Monitor - мониторинг здоровья слоёв и автоматическое отключение проблемных
///
/// Реализует паттерн Circuit Breaker для translation layers.
/// При превышении порога ошибок слой автоматически отключается на определённое время.
library;

import 'dart:async';
import '../core/layer_type.dart';
import 'debug_logger.dart';
import 'metrics.dart';

/// Состояния Circuit Breaker
enum CircuitState {
  /// Слой работает нормально
  closed,
  
  /// Слой временно отключен (высокий уровень ошибок)
  open,
  
  /// Пробный режим (слой включен для тестирования восстановления)
  halfOpen,
}

/// Статистика здоровья слоя
class LayerHealth {
  final LayerType layerType;
  CircuitState circuitState;
  int totalRequests;
  int errorCount;
  DateTime? lastErrorTime;
  DateTime? circuitOpenedAt;
  
  LayerHealth({
    required this.layerType,
    this.circuitState = CircuitState.closed,
    this.totalRequests = 0,
    this.errorCount = 0,
    this.lastErrorTime,
    this.circuitOpenedAt,
  });
  
  /// Коэффициент ошибок (0.0 - 1.0)
  double get errorRate => totalRequests > 0 ? errorCount / totalRequests : 0.0;
  
  /// JSON-представление для отчётности
  Map<String, dynamic> toJson() => {
    'layer_type': layerType.name,
    'circuit_state': circuitState.name,
    'total_requests': totalRequests,
    'error_count': errorCount,
    'error_rate': errorRate.toStringAsFixed(3),
    'last_error_time': lastErrorTime?.toIso8601String(),
    'circuit_opened_at': circuitOpenedAt?.toIso8601String(),
  };
}

/// Layer Health Monitor - мониторинг и управление здоровьем слоёв
class LayerHealthMonitor {
  /// Порог ошибок для открытия circuit (0.0 - 1.0)
  final double errorThreshold;
  
  /// Минимальное количество запросов для оценки
  final int minRequests;
  
  /// Время ожидания перед переходом в halfOpen (секунды)
  final int resetTimeoutSeconds;
  
  /// Количество успешных запросов в halfOpen для закрытия circuit
  final int successThreshold;
  
  /// Период окна для подсчёта статистики (секунды)
  final int windowSeconds;
  
  final Map<LayerType, LayerHealth> _health = {};
  final Map<LayerType, Timer?> _resetTimers = {};
  
  /// Callbacks для событий изменения состояния
  final List<void Function(LayerType, CircuitState, CircuitState)> _stateChangeListeners = [];
  
  LayerHealthMonitor({
    this.errorThreshold = 0.5, // 50% ошибок
    this.minRequests = 10,
    this.resetTimeoutSeconds = 60,
    this.successThreshold = 3,
    this.windowSeconds = 300, // 5 минут
  });
  
  /// Получить здоровье слоя
  LayerHealth getHealth(LayerType layerType) {
    return _health.putIfAbsent(
      layerType,
      () => LayerHealth(layerType: layerType),
    );
  }
  
  /// Проверить, доступен ли слой для обработки
  bool isLayerAvailable(LayerType layerType) {
    final health = getHealth(layerType);
    return health.circuitState == CircuitState.closed ||
           health.circuitState == CircuitState.halfOpen;
  }
  
  /// Зарегистрировать успешную обработку слоем
  void recordSuccess(LayerType layerType) {
    final health = getHealth(layerType);
    health.totalRequests++;
    
    // В режиме halfOpen учитываем успехи для восстановления
    if (health.circuitState == CircuitState.halfOpen) {
      // Считаем последовательные успехи
      final metric = MetricsRegistry.instance.counter('layer.${layerType.name}.consecutive_success');
      metric.inc();
      
      final consecutiveSuccess = metric.value.toInt();
      if (consecutiveSuccess >= successThreshold) {
        _closeCircuit(layerType);
      }
    }
    
    // Периодическая очистка старой статистики
    _maybeResetWindow(health);
    
    MetricsRegistry.instance.counter('layer.${layerType.name}.success').inc();
  }
  
  /// Зарегистрировать ошибку слоя
  void recordError(LayerType layerType, Object error) {
    final health = getHealth(layerType);
    health.totalRequests++;
    health.errorCount++;
    health.lastErrorTime = DateTime.now();
    
    DebugLogger.instance.warning('layer.health.error', fields: {
      'layer_type': layerType.name,
      'error': error.toString(),
      'error_rate': health.errorRate.toStringAsFixed(3),
      'total_requests': health.totalRequests,
    });
    
    MetricsRegistry.instance.counter('layer.${layerType.name}.errors').inc();
    // Сбрасываем consecutive_success через dec до 0
    final consecutiveCounter = MetricsRegistry.instance.counter('layer.${layerType.name}.consecutive_success');
    consecutiveCounter.dec(consecutiveCounter.value);
    
    // Проверка порога для открытия circuit
    if (health.circuitState == CircuitState.closed) {
      if (health.totalRequests >= minRequests && health.errorRate >= errorThreshold) {
        _openCircuit(layerType);
      }
    } else if (health.circuitState == CircuitState.halfOpen) {
      // В режиме halfOpen одна ошибка снова открывает circuit
      _openCircuit(layerType);
    }
    
    _maybeResetWindow(health);
  }
  
  /// Открыть circuit (отключить слой)
  void _openCircuit(LayerType layerType) {
    final health = getHealth(layerType);
    final oldState = health.circuitState;
    
    health.circuitState = CircuitState.open;
    health.circuitOpenedAt = DateTime.now();
    
    DebugLogger.instance.error('layer.health.circuit_opened', fields: {
      'layer_type': layerType.name,
      'error_rate': health.errorRate.toStringAsFixed(3),
      'total_requests': health.totalRequests,
      'error_count': health.errorCount,
      'reset_timeout_sec': resetTimeoutSeconds,
    });
    
    MetricsRegistry.instance.counter('layer.${layerType.name}.circuit_opened').inc();
    _notifyStateChange(layerType, oldState, CircuitState.open);
    
    // Установить таймер для перехода в halfOpen
    _resetTimers[layerType]?.cancel();
    _resetTimers[layerType] = Timer(
      Duration(seconds: resetTimeoutSeconds),
      () => _halfOpenCircuit(layerType),
    );
  }
  
  /// Перевести circuit в halfOpen (пробный режим)
  void _halfOpenCircuit(LayerType layerType) {
    final health = getHealth(layerType);
    final oldState = health.circuitState;
    
    health.circuitState = CircuitState.halfOpen;
    // Сбрасываем consecutive_success через dec до 0
    final consecutiveCounter = MetricsRegistry.instance.counter('layer.${layerType.name}.consecutive_success');
    consecutiveCounter.dec(consecutiveCounter.value);
    
    DebugLogger.instance.info('layer.health.circuit_half_open', fields: {
      'layer_type': layerType.name,
      'success_threshold': successThreshold,
    });
    
    _notifyStateChange(layerType, oldState, CircuitState.halfOpen);
  }
  
  /// Закрыть circuit (восстановить слой)
  void _closeCircuit(LayerType layerType) {
    final health = getHealth(layerType);
    final oldState = health.circuitState;
    
    health.circuitState = CircuitState.closed;
    health.circuitOpenedAt = null;
    
    // Сброс статистики для нового окна
    health.totalRequests = 0;
    health.errorCount = 0;
    
    DebugLogger.instance.info('layer.health.circuit_closed', fields: {
      'layer_type': layerType.name,
    });
    
    MetricsRegistry.instance.counter('layer.${layerType.name}.circuit_closed').inc();
    _notifyStateChange(layerType, oldState, CircuitState.closed);
    
    _resetTimers[layerType]?.cancel();
    _resetTimers[layerType] = null;
  }
  
  /// Принудительно закрыть circuit (для ручного восстановления)
  void forceCloseCircuit(LayerType layerType) {
    _closeCircuit(layerType);
  }
  
  /// Сброс окна статистики при необходимости
  void _maybeResetWindow(LayerHealth health) {
    if (health.lastErrorTime != null) {
      final elapsed = DateTime.now().difference(health.lastErrorTime!);
      if (elapsed.inSeconds > windowSeconds && health.circuitState == CircuitState.closed) {
        // Плавное затухание статистики
        health.totalRequests = (health.totalRequests * 0.5).ceil();
        health.errorCount = (health.errorCount * 0.5).ceil();
      }
    }
  }
  
  /// Подписаться на изменения состояния
  void addStateChangeListener(void Function(LayerType, CircuitState, CircuitState) listener) {
    _stateChangeListeners.add(listener);
  }
  
  /// Уведомить слушателей об изменении состояния
  void _notifyStateChange(LayerType layerType, CircuitState oldState, CircuitState newState) {
    for (final listener in _stateChangeListeners) {
      try {
        listener(layerType, oldState, newState);
      } catch (e) {
        DebugLogger.instance.error('layer.health.listener_error', error: e);
      }
    }
  }
  
  /// Получить отчёт о здоровье всех слоёв
  Map<String, dynamic> getHealthReport() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'config': {
        'error_threshold': errorThreshold,
        'min_requests': minRequests,
        'reset_timeout_seconds': resetTimeoutSeconds,
        'success_threshold': successThreshold,
        'window_seconds': windowSeconds,
      },
      'layers': _health.values.map((h) => h.toJson()).toList(),
      'degraded_layers': _health.values
          .where((h) => h.circuitState != CircuitState.closed)
          .map((h) => h.layerType.name)
          .toList(),
    };
  }
  
  /// Очистка ресурсов
  void dispose() {
    for (final timer in _resetTimers.values) {
      timer?.cancel();
    }
    _resetTimers.clear();
    _stateChangeListeners.clear();
  }
}
