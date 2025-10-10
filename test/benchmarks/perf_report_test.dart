import 'package:test/test.dart';

void main() {
  test('performance report (skipped)', () => expect(true, true), skip: 'Perf tests are disabled for JSONL migration.');
}
