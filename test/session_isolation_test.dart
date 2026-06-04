import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/state/sessions/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rename via linkPc keeps messages in local bucket', () {
    final store = SessionStore();
    const local = 'loc-test';
    store.of(local).messages.add(
          ChatMessage(
            id: 'u1',
            role: ChatRole.user,
            text: 'merhaba',
            at: DateTime(2026),
            sessionId: local,
          ),
        );
    store.of(local).live.waitingResponse = true;
    store.linkPcSession(local, 'real-session');
    expect(store.findByPcSessionId('real-session')?.localId, local);
    expect(store.of(local).messages.length, 1);
    expect(store.of(local).hasPcSession, true);
  });
}
