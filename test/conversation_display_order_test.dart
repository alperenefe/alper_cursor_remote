import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/models/queued_prompt.dart';
import 'package:alper_cursor_remote/services/chat_history_applier.dart';
import 'package:alper_cursor_remote/state/display/conversation_display_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plan: cevap kullanıcıdan hemen sonra', () {
    final base = DateTime(2026, 5, 29);
    final visible = [
      ChatMessage(
        id: 'u1',
        role: ChatRole.user,
        text: 'planla',
        at: base,
        agentMode: 'plan',
      ),
      ChatMessage(
        id: 'u2',
        role: ChatRole.user,
        text: 'devam',
        at: base.add(const Duration(seconds: 5)),
        agentMode: 'plan',
      ),
      ChatMessage(
        id: 'a1',
        role: ChatRole.assistant,
        text: 'Plan metni',
        at: base.add(const Duration(seconds: 40)),
        replyToUserId: 'u1',
      ),
    ];
    final order = buildConversationDisplayMessages(
      visible: visible,
      effectiveQueue: const [],
    )
        .map((m) => m.id)
        .toList();
    expect(order, ['u1', 'a1', 'u2']);
  });

  test('uçuşta tur sıradan önce en altta', () {
    final base = DateTime(2026, 5, 29);
    final visible = [
      ChatMessage(id: 'u1', role: ChatRole.user, text: '1', at: base),
      ChatMessage(
        id: 'a1',
        role: ChatRole.assistant,
        text: 'c1',
        at: base.add(const Duration(seconds: 1)),
        replyToUserId: 'u1',
      ),
      ChatMessage(
        id: 'u2',
        role: ChatRole.user,
        text: 'çalışıyor',
        at: base.add(const Duration(seconds: 2)),
      ),
      ChatMessage(
        id: 'u3',
        role: ChatRole.user,
        text: 'sırada',
        at: base.add(const Duration(seconds: 3)),
      ),
    ];
    final order = buildConversationDisplayMessages(
      visible: visible,
      effectiveQueue: [
        QueuedPrompt(
          text: 'sırada',
          agentMode: 'plan',
          queuedAt: base,
          localMessageId: 'u3',
        ),
      ],
      inFlightUserMessageId: 'u2',
    )
        .map((m) => m.id)
        .toList();
    expect(order, ['u1', 'a1', 'u2', 'u3']);
  });

  test('sıradakiler en altta FIFO', () {
    final base = DateTime(2026, 5, 29);
    final visible = [
      ChatMessage(id: 'u1', role: ChatRole.user, text: '1', at: base),
      ChatMessage(
        id: 'a1',
        role: ChatRole.assistant,
        text: 'c1',
        at: base.add(const Duration(seconds: 1)),
        replyToUserId: 'u1',
      ),
      ChatMessage(
        id: 'u2',
        role: ChatRole.user,
        text: '2',
        at: base.add(const Duration(seconds: 2)),
      ),
      ChatMessage(
        id: 'u3',
        role: ChatRole.user,
        text: '3',
        at: base.add(const Duration(seconds: 3)),
      ),
    ];
    final queue = [
      QueuedPrompt(
        text: '2',
        agentMode: 'plan',
        queuedAt: base,
        localMessageId: 'u2',
      ),
      QueuedPrompt(
        text: '3',
        agentMode: 'plan',
        queuedAt: base.add(const Duration(seconds: 1)),
        localMessageId: 'u3',
      ),
    ];
  final order = buildConversationDisplayMessages(
      visible: visible,
      effectiveQueue: queue,
    )
        .map((m) => m.id)
        .toList();
    expect(order, ['u1', 'a1', 'u2', 'u3']);
  });

  test('PC geçmişi replyToUserId yok — tur aralığına göre', () {
    final base = DateTime(2026, 5, 29);
    final visible = [
      ChatMessage(id: 'u1', role: ChatRole.user, text: '1', at: base),
      ChatMessage(
        id: 'u2',
        role: ChatRole.user,
        text: '2',
        at: base.add(const Duration(seconds: 1)),
      ),
      ChatMessage(
        id: 'a1',
        role: ChatRole.assistant,
        text: 'plan cevabı',
        at: base.add(const Duration(seconds: 30)),
      ),
    ];
    final order = orderSettledByTurns(visible).map((m) => m.id).toList();
    expect(order, ['u1', 'u2', 'a1']);
  });

  test('PC geçmişi h-u/h-a replyToUserId — son turda cevap altta', () {
    final base = DateTime(2026, 5, 29, 15, 34, 41);
    final visible = [
      ChatMessage(
        id: 'h-u-prev',
        role: ChatRole.user,
        text: 'önceki',
        at: base.subtract(const Duration(hours: 1)),
      ),
      ChatMessage(
        id: 'h-a-prev',
        role: ChatRole.assistant,
        text: 'önceki cevap',
        at: base.subtract(const Duration(hours: 1, seconds: -1)),
        replyToUserId: 'h-u-prev',
      ),
      ChatMessage(
        id: 'h-u-last',
        role: ChatRole.user,
        text: 'başlık girmeden kaydet',
        at: base,
      ),
      ChatMessage(
        id: 'h-a-last',
        role: ChatRole.assistant,
        text: 'son cevap',
        at: base.add(const Duration(seconds: 1)),
        replyToUserId: 'h-u-last',
      ),
    ];
    final order = buildConversationDisplayMessages(
      visible: visible,
      effectiveQueue: const [],
    );
    expect(order.last.role, ChatRole.assistant);
    expect(order.last.id, 'h-a-last');
  });

  test('yerel userPrompt birleşince replyToUserId yeniden bağlanır', () {
    final base = DateTime(2026, 5, 29, 15, 34, 41);
    final visible = [
      ChatMessage(
        id: 'h-u-last',
        role: ChatRole.user,
        text: 'başlık girmeden kaydet',
        at: base,
      ),
      ChatMessage(
        id: 'h-a-last',
        role: ChatRole.assistant,
        text: 'son cevap',
        at: base.add(const Duration(seconds: 1)),
        replyToUserId: 'h-u-last',
      ),
      ChatMessage(
        id: 'local-msg',
        role: ChatRole.user,
        text: 'başlık girmeden kaydet',
        at: base.add(const Duration(seconds: 2)),
        kind: InboundKind.userPrompt,
      ),
    ];
    final deduped = dedupeEquivalentUserMessages(visible);
    final order = buildConversationDisplayMessages(
      visible: deduped,
      effectiveQueue: const [],
    );
    expect(order.last.role, ChatRole.assistant);
    expect(
      order.where((m) => m.role == ChatRole.user).last.id,
      'local-msg',
    );
  });
}
