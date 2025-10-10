import 'package:test/test.dart';

void main() {
  test(
    'deprecated DB manager (skipped)',
    () => expect(true, true),
    skip: 'SQLite removed; JSONL storage in use.',
  );
}
