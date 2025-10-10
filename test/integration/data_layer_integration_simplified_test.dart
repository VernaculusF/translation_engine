import 'package:test/test.dart';

void main() {
  test(
    'integration simplified (skipped)',
    () => expect(true, true),
    skip: 'Replaced by JSONL integration tests.',
  );
}
