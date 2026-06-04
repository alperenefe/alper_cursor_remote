import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/models/queued_prompt.dart';
import 'package:alper_cursor_remote/state/inbound/inbound_bucket_resolver.dart';
import 'package:alper_cursor_remote/state/sessions/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cevap gelmeden 2. oturum: ayrı loc kutular — karışmamalı.
void main() {
  test('müzik cevabı yürük kutusuna yazılmaz', () {
    final store = SessionStore();
    const musicLocal = 'loc-music';
    const yurukLocal = 'loc-yuruk';
    const msgMusic = 'id-music';
    const msgYuruk = 'id-yuruk';
    final t0 = DateTime(2026, 5, 29, 12);
    final t1 = t0.add(const Duration(seconds: 2));

    store.of(musicLocal).messages.add(
          ChatMessage(
            id: msgMusic,
            role: ChatRole.user,
            text: 'müzik path nerede',
            at: t0,
            sessionId: musicLocal,
          ),
        );
    store.of(yurukLocal).messages.add(
          ChatMessage(
            id: msgYuruk,
            role: ChatRole.user,
            text: 'yürük path nerede',
            at: t1,
            sessionId: yurukLocal,
          ),
        );

    final musicLive = store.of(musicLocal).live;
    musicLive
      ..waitingResponse = true
      ..waitingSince = t0
      ..inFlight = QueuedPrompt(
        text: 'müzik path nerede',
        agentMode: 'agent',
        queuedAt: t0,
        localMessageId: msgMusic,
      );

    final yurukLive = store.of(yurukLocal).live;
    yurukLive
      ..waitingResponse = true
      ..waitingSince = t1
      ..inFlight = QueuedPrompt(
        text: 'yürük path nerede',
        agentMode: 'agent',
        queuedAt: t1,
        localMessageId: msgYuruk,
      );

    final dispatch = {
      msgMusic: musicLocal,
      msgYuruk: yurukLocal,
    };

    final waiting = store.waitingDispatches();

    final musicAnswerBucket = resolveInboundBucketKey(
      wireSessionId: 'pc-uuid-music',
      waiting: waiting,
      dispatchBucketByLocalMessageId: dispatch,
    );
    expect(musicAnswerBucket, musicLocal);

    store.linkPcSession(musicLocal, 'pc-uuid-music');
    expect(store.findByPcSessionId('pc-uuid-music')?.localId, musicLocal);
    expect(store.of(yurukLocal).messages.first.text, contains('yürük'));
    expect(store.of(musicLocal).messages.length, 1);
  });
}
