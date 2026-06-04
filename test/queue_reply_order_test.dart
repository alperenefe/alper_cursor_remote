import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/models/queued_prompt.dart';
import 'package:alper_cursor_remote/state/display/conversation_display_order.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> orderForDisplay(
  List<ChatMessage> visible,
  List<QueuedPrompt> effectiveQueue,
) =>
    buildConversationDisplayMessages(
      visible: visible,
      effectiveQueue: effectiveQueue,
    )
        .map((m) => m.id)
        .toList();

void main() {
  test('cevap kullanıcıdan sonra, sıradakiler en altta', () {
    final u1 = ChatMessage(
      id: 'u1',
      role: ChatRole.user,
      text: 'ilk',
      at: DateTime.now(),
      kind: InboundKind.userPrompt,
    );
    final a1 = ChatMessage(
      id: 'a1',
      role: ChatRole.assistant,
      text: 'cevap1',
      at: DateTime.now(),
      replyToUserId: 'u1',
    );
    final u2 = ChatMessage(
      id: 'u2',
      role: ChatRole.user,
      text: 'ikinci sırada',
      at: DateTime.now(),
      kind: InboundKind.userPrompt,
    );
    final visible = [u1, a1, u2];
    final queue = [
      QueuedPrompt(
        text: 'ikinci',
        agentMode: 'agent',
        queuedAt: DateTime.now(),
        localMessageId: 'u2',
      ),
    ];
    expect(orderForDisplay(visible, queue), ['u1', 'a1', 'u2']);
  });

  test('sıradakiler kuyruk FIFO ile en altta', () {
    final base = DateTime(2026, 1, 1);
    final u1 = ChatMessage(
      id: 'u1',
      role: ChatRole.user,
      text: 'ilk',
      at: base,
    );
    final u2 = ChatMessage(
      id: 'u2',
      role: ChatRole.user,
      text: 'ikinci',
      at: base.add(const Duration(minutes: 1)),
    );
    final u3 = ChatMessage(
      id: 'u3',
      role: ChatRole.user,
      text: 'üçüncü',
      at: base.add(const Duration(minutes: 2)),
    );
    final visible = [u1, u3, u2];
    final queue = [
      QueuedPrompt(
        text: 'ikinci',
        agentMode: 'agent',
        queuedAt: base,
        localMessageId: 'u2',
      ),
      QueuedPrompt(
        text: 'üçüncü',
        agentMode: 'agent',
        queuedAt: base,
        localMessageId: 'u3',
      ),
    ];
    expect(orderForDisplay(visible, queue), ['u1', 'u2', 'u3']);
  });
}
