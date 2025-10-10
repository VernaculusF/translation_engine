import 'package:test/test.dart';

void main() {
  test(
    'translation pipeline (skipped)',
    () => expect(true, true),
    skip: 'Updated for JSONL; pipeline covered by integration tests.',
  );
}
