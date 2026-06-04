import 'package:alper_cursor_remote/models/queued_prompt.dart';
import 'package:alper_cursor_remote/models/session_live_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kopmada wire-dispatched uçuş turu kuyruğa alınmamalı (app_state mantığı özeti).
void main() {
  test('wireDispatched iken requeue atlanır', () {
    final live = SessionLiveState();
    final q = QueuedPrompt(
      text: 'merhaba',
      agentMode: 'agent',
      queuedAt: DateTime(2026),
      localMessageId: 'u1',
      sessionId: 'loc-1',
    );
    live.inFlight = q;
    live.inFlightWireDispatched = true;
    live.waitingResponse = true;
    live.awaitingReplyForUserId = 'u1';

    // app_state._requeueInFlightForSession eşdeğeri
    if (!live.inFlightWireDispatched && live.inFlight != null) {
      live.queue.insert(0, live.inFlight!);
      live.inFlight = null;
      live.clearWaiting();
    }

    expect(live.queue, isEmpty);
    expect(live.waitingResponse, isTrue);
    expect(live.inFlight?.localMessageId, 'u1');
  });

  test('wire gönderilmediyse kuyruğa alınır', () {
    final live = SessionLiveState();
    final q = QueuedPrompt(
      text: 'merhaba',
      agentMode: 'agent',
      queuedAt: DateTime(2026),
      localMessageId: 'u1',
      sessionId: 'loc-1',
    );
    live.inFlight = q;
    live.inFlightWireDispatched = false;
    live.waitingResponse = true;

    if (!live.inFlightWireDispatched && live.inFlight != null) {
      live.queue.insert(0, live.inFlight!);
      live.inFlight = null;
      live.clearWaiting();
    }

    expect(live.queue.length, 1);
    expect(live.waitingResponse, isFalse);
    expect(live.inFlight, isNull);
  });
}
