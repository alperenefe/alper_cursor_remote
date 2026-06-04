import 'package:alper_cursor_remote/services/assistant_text_sanitize.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NDJSON system satırı çöp sayılır', () {
    expect(
      isGarbageAssistantText(
        '{"type":"system","subtype":"init","session_id":"abc"}',
      ),
      isTrue,
    );
  });

  test('normal markdown cevap çöp değil', () {
    expect(
      isGarbageAssistantText('**Özet:** Planlayıcı iyi durumda.'),
      isFalse,
    );
  });
}
