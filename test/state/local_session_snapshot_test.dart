import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/models/local_session_snapshot.dart';
import 'package:alper_cursor_remote/state/sessions/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('export/import snapshot korur', () {
    final store = SessionStore();
    final id = store.createSession(displayName: 'Müzik');
    store.of(id).messages.add(
          ChatMessage(
            id: 'u1',
            role: ChatRole.user,
            text: 'test',
            at: DateTime(2026),
            sessionId: id,
          ),
        );
    store.linkPcSession(id, 'pc-uuid-1');

    final snap = store.exportSnapshot(
      activeSessionId: id,
      sessionNames: {id: 'Müzik'},
    );
    final store2 = SessionStore();
    store2.importSnapshot(snap);

    expect(store2.contains(id), isTrue);
    expect(store2.of(id).messages.length, 1);
    expect(store2.of(id).pcSessionId, 'pc-uuid-1');
    expect(store2.activeLocalId, id);
  });
}
