/// Minimal tracing primitives (traceId/spanId) without external deps
library;

class TraceContext {
  final String traceId;
  String? currentSpanId;
  TraceContext(this.traceId);
}

class Span {
  final TraceContext ctx;
  final String name;
  final String spanId;
  final DateTime start;
  bool _ended = false;
  Span(this.ctx, this.name)
      : spanId = _genId(),
        start = DateTime.now() {
    ctx.currentSpanId = spanId;
  }

  Duration end() {
    if (_ended) return Duration.zero;
    _ended = true;
    final dur = DateTime.now().difference(start);
    if (ctx.currentSpanId == spanId) ctx.currentSpanId = null;
    return dur;
  }
}

String newTraceId() => _genId();

String _genId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  final rnd = (now * 6364136223846793005 + 1) & 0xFFFFFFFFFFFF;
  return now.toRadixString(16) + rnd.toRadixString(16);
}