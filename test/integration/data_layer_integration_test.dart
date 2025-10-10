import 'package:test/test.dart';

void main() {
  test(
    'integration (skipped)',
    () => expect(true, true),
    skip: 'Replaced by JSONL integration tests.',
  );
}
