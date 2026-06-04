import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/models/queued_prompt.dart';
import 'package:alper_cursor_remote/state/chat/chat_message_match.dart';
import 'package:alper_cursor_remote/state/queue/global_queue_picker.dart';
import 'package:alper_cursor_remote/state/queue/prompt_queue_logic.dart';
import 'package:alper_cursor_remote/state/session_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pickNextQueuedGlobally', () {
    test('en eski kuyruk mesajı seçilir (oturumlar arası)', () {
      final t0 = DateTime(2026, 5, 29, 10);
      final t1 = t0.add(const Duration(minutes: 1));
      final reg = SessionRegistry();
      reg.liveFor('s1').queue.add(
            QueuedPrompt(
              text: 'b',
              agentMode: 'agent',
              queuedAt: t1,
              localMessageId: 'b',
              sessionId: 's1',
            ),
          );
      reg.messagesFor('s1').add(
        ChatMessage(
          id: 'b',
          role: ChatRole.user,
          text: 'b',
          at: t1,
        ),
      );
      reg.liveFor('s2').queue.add(
            QueuedPrompt(
              text: 'a',
              agentMode: 'agent',
              queuedAt: t0,
              localMessageId: 'a',
              sessionId: 's2',
            ),
          );
      reg.messagesFor('s2').add(
        ChatMessage(
          id: 'a',
          role: ChatRole.user,
          text: 'a',
          at: t0,
        ),
      );
      final picked = pickNextQueuedGlobally(
        reg,
        userMessagesLikelySame: userMessagesLikelySame,
      );
      expect(picked?.prompt.localMessageId, 'a');
      expect(picked?.sessionId, 's2');
    });

    test('stale waitingResponse — kuyruk yine seçilir', () {
      final t0 = DateTime(2026, 5, 29, 11);
      final reg = SessionRegistry();
      reg.liveFor('s1').waitingResponse = true;
      reg.liveFor('s1').queue.add(
        QueuedPrompt(
          text: 'ilk',
          agentMode: 'agent',
          queuedAt: t0,
          localMessageId: 'm1',
          sessionId: 's1',
        ),
      );
      reg.messagesFor('s1').add(
        ChatMessage(
          id: 'm1',
          role: ChatRole.user,
          text: 'ilk',
          at: t0,
        ),
      );
      final picked = pickNextQueuedGlobally(
        reg,
        userMessagesLikelySame: userMessagesLikelySame,
      );
      expect(picked?.prompt.localMessageId, 'm1');
      expect(picked?.sessionId, 's1');
    });
  });

  group('effectiveQueuedCount', () {
    test('yetim kuyruk kaydı sayılmaz', () {
      final reg = SessionRegistry();
      reg.liveFor('a').queue.add(
            QueuedPrompt(
              text: 'x',
              agentMode: 'agent',
              queuedAt: DateTime(2026),
              localMessageId: 'orphan',
              sessionId: 'a',
            ),
          );
      expect(
        effectiveQueuedCount(reg, 'a', userMessagesLikelySame: userMessagesLikelySame),
        0,
      );
    });

    test('inFlight ile aynı id kuyrukta sayılmaz', () {
      final reg = SessionRegistry();
      reg.messagesFor('a').add(
        ChatMessage(
          id: 'u1',
          role: ChatRole.user,
          text: 'hi',
          at: DateTime(2026),
        ),
      );
      final q = QueuedPrompt(
        text: 'hi',
        agentMode: 'agent',
        queuedAt: DateTime(2026),
        localMessageId: 'u1',
        sessionId: 'a',
      );
      reg.liveFor('a').queue.add(q);
      reg.liveFor('a').inFlight = q;
      expect(
        effectiveQueuedCount(reg, 'a', userMessagesLikelySame: userMessagesLikelySame),
        0,
      );
    });

    test('plan ek — PC geçmişi gelince uçuşta tur sırada kalır', () {
      final reg = SessionRegistry();
      const mobil = '📎 scaled.jpg\n\nplanla';
      const pc = '''[Mobil ekler — workspace'e kaydedildi]
- Görsel scaled.jpg: @.cursor-remote-attachments/x/scaled.jpg''';
      reg.messagesFor('plan').addAll([
        ChatMessage(
          id: 'u1',
          role: ChatRole.user,
          text: mobil,
          at: DateTime(2026, 1, 1),
        ),
        ChatMessage(
          id: 'h-u-1',
          role: ChatRole.user,
          text: pc,
          at: DateTime(2026, 1, 1, 0, 0, 1),
        ),
        ChatMessage(
          id: 'u2',
          role: ChatRole.user,
          text: 'ikinci mesaj',
          at: DateTime(2026, 1, 1, 0, 2),
        ),
      ]);
      final q = QueuedPrompt(
        text: 'planla',
        agentMode: 'plan',
        queuedAt: DateTime(2026),
        localMessageId: 'u2',
        sessionId: 'plan',
      );
      reg.liveFor('plan').queue.add(q);
      reg.liveFor('plan').awaitingReplyForUserId = 'u1';
      reg.liveFor('plan').inFlight = QueuedPrompt(
        text: 'planla',
        agentMode: 'plan',
        queuedAt: DateTime(2026),
        localMessageId: 'u1',
        sessionId: 'plan',
      );
      expect(
        effectiveQueuedCount(
          reg,
          'plan',
          userMessagesLikelySame: userMessagesLikelySame,
        ),
        1,
      );
      expect(
        effectiveQueuedFor(
          reg,
          'plan',
          userMessagesLikelySame: userMessagesLikelySame,
        )
            .single
            .localMessageId,
        'u2',
      );
    });

    test('cevaplanmış tur kuyruktan düşer', () {
      final reg = SessionRegistry();
      reg.messagesFor('a').addAll([
        ChatMessage(
          id: 'u1',
          role: ChatRole.user,
          text: 'soru',
          at: DateTime(2026, 1, 1, 12),
        ),
        ChatMessage(
          id: 'a1',
          role: ChatRole.assistant,
          text: 'cevap',
          at: DateTime(2026, 1, 1, 12, 0, 1),
          kind: InboundKind.chatResponse,
        ),
      ]);
      reg.liveFor('a').queue.add(
        QueuedPrompt(
          text: 'soru',
          agentMode: 'agent',
          queuedAt: DateTime(2026),
          localMessageId: 'u1',
          sessionId: 'a',
        ),
      );
      sanitizeQueueForSession(
        reg,
        'a',
        userMessagesLikelySame: userMessagesLikelySame,
      );
      expect(
        effectiveQueuedCount(reg, 'a', userMessagesLikelySame: userMessagesLikelySame),
        0,
      );
    });
  });
}
