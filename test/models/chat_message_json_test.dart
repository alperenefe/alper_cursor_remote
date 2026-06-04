import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/models/chat_message_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ChatMessage JSON roundtrip', () {
    final m = ChatMessage(
      id: 'u1',
      role: ChatRole.user,
      text: 'merhaba',
      at: DateTime(2026, 5, 30, 12),
      kind: InboundKind.userPrompt,
      sessionId: 'loc-1',
    );
    final back = ChatMessageJson.fromJson(m.toJson());
    expect(back.id, m.id);
    expect(back.role, m.role);
    expect(back.text, m.text);
    expect(back.kind, m.kind);
  });
}
