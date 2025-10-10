import 'package:test/test.dart';

void main() {
  test(
    'integration compatible (skipped)',
    () => expect(true, true),
    skip: 'Replaced by JSONL integration tests.',
  );
}
