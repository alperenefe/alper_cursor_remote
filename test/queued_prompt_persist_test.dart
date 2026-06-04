import 'package:alper_cursor_remote/models/queued_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('QueuedPrompt json roundtrip', () {
    final original = QueuedPrompt(
      text: 'merhaba',
      agentMode: 'plan',
      queuedAt: DateTime.utc(2026, 5, 28, 12, 0),
      localMessageId: 'msg-1',
      attachments: const [],
    );
    final restored = QueuedPrompt.fromJson(original.toJson());
    expect(restored.text, original.text);
    expect(restored.agentMode, original.agentMode);
    expect(restored.localMessageId, original.localMessageId);
    expect(restored.queuedAt, original.queuedAt);
  });
}
