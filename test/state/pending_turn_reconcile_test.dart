import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/models/queued_prompt.dart';
import 'package:alper_cursor_remote/models/session_live_state.dart';
import 'package:alper_cursor_remote/state/chat/chat_message_match.dart';
import 'package:alper_cursor_remote/state/sync/pending_turn_reconcile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cevapsız son tur kuyruktaysa beklemeyi geri yükler', () {
    final live = SessionLiveState();
    live.queue.add(
      QueuedPrompt(
        text: 'planla',
        agentMode: 'agent',
        queuedAt: DateTime(2026, 5, 30),
        localMessageId: 'u1',
        sessionId: 'loc-1',
      ),
    );
    final sorted = [
      ChatMessage(
        id: 'u1',
        role: ChatRole.user,
        text: 'planla',
        at: DateTime(2026, 5, 30),
      ),
    ];

    final r = reconcileUnansweredTurnFromQueue(
      live: live,
      sorted: sorted,
      userMessagesLikelySame: userMessagesLikelySame,
    );

    expect(r.restoredWaiting, isTrue);
    expect(r.removedFromQueue, 1);
    expect(live.waitingResponse, isTrue);
    expect(live.inFlight?.localMessageId, 'u1');
    expect(live.inFlightWireDispatched, isTrue);
    expect(live.queue, isEmpty);
  });

  test('cevap geldiyse kuyruk dokunulmaz', () {
    final live = SessionLiveState();
    live.queue.add(
      QueuedPrompt(
        text: 'x',
        agentMode: 'agent',
        queuedAt: DateTime(2026),
        localMessageId: 'u1',
        sessionId: 'loc-1',
      ),
    );
    final sorted = [
      ChatMessage(
        id: 'u1',
        role: ChatRole.user,
        text: 'x',
        at: DateTime(2026),
      ),
      ChatMessage(
        id: 'a1',
        role: ChatRole.assistant,
        text: 'tamam',
        at: DateTime(2026, 1, 1, 0, 1),
        replyToUserId: 'u1',
      ),
    ];

    final r = reconcileUnansweredTurnFromQueue(
      live: live,
      sorted: sorted,
      userMessagesLikelySame: userMessagesLikelySame,
    );

    expect(r.restoredWaiting, isFalse);
    expect(live.queue.length, 1);
  });
}
