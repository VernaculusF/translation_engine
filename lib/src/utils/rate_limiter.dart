/// Simple rate limiter based on minimal interval between requests
library;

class SimpleRateLimiter {
  final int maxPerMinute;
  DateTime _nextAllowed = DateTime.fromMillisecondsSinceEpoch(0);

  SimpleRateLimiter(this.maxPerMinute);

  Duration untilNextAllowed() {
    if (maxPerMinute <= 0) return Duration.zero;
    final now = DateTime.now();
    if (now.isBefore(_nextAllowed)) {
      return _nextAllowed.difference(now);
    }
    return Duration.zero;
  }

  Future<void> waitTurn() async {
    final delay = untilNextAllowed();
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    final intervalMs = (60000 / (maxPerMinute <= 0 ? 1 : maxPerMinute)).floor();
    _nextAllowed = DateTime.now().add(Duration(milliseconds: intervalMs));
  }
}