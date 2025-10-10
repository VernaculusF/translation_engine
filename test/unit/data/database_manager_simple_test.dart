import 'package:test/test.dart';

void main() {
  test(
    'deprecated DB simple (skipped)',
    () => expect(true, true),
    skip: 'SQLite removed; JSONL storage in use.',
  );
}
