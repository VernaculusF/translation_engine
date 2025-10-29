/// Lightweight metrics registry for counters and timers
library;

class Counter {
  int _value = 0;
  void inc([int delta = 1]) => _value += delta;
  void dec([int delta = 1]) => _value -= delta;
  int get value => _value;
}

class TimerMetric {
  int _count = 0;
  int _totalMs = 0;
  int _maxMs = 0;
  void observe(Duration d) {
    final ms = d.inMilliseconds;
    _count++;
    _totalMs += ms;
    if (ms > _maxMs) _maxMs = ms;
  }

  Map<String, num> toMap() => {
        'count': _count,
        'total_ms': _totalMs,
        'avg_ms': _count > 0 ? _totalMs / _count : 0,
        'max_ms': _maxMs,
      };
}

class MetricsRegistry {
  static final MetricsRegistry _instance = MetricsRegistry._();
  static MetricsRegistry get instance => _instance;
  MetricsRegistry._();

  final Map<String, Counter> _counters = {};
  final Map<String, TimerMetric> _timers = {};

  Counter counter(String name) => _counters.putIfAbsent(name, () => Counter());
  TimerMetric timer(String name) => _timers.putIfAbsent(name, () => TimerMetric());

  Map<String, dynamic> snapshot() => {
        'counters': _counters.map((k, v) => MapEntry(k, v.value)),
        'timers': _timers.map((k, v) => MapEntry(k, v.toMap())),
      };
}