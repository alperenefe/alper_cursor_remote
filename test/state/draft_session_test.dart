import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/state/sessions/session_resolver.dart';
import 'package:alper_cursor_remote/state/sessions/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('taslak oturum boş-kutu yönlendirmesine girmez', () {
    final store = SessionStore();
    const music = 'loc-music';

    final draftId = store.beginDraftSession();
    store.of(music).messages.add(
          ChatMessage(
            id: 'u1',
            role: ChatRole.user,
            text: 'müzik sorusu',
            at: DateTime(2026, 5, 29, 10),
            sessionId: music,
          ),
        );

    expect(SessionResolver(store).resolve(draftId), draftId);
    expect(store.of(draftId).isDraft, isTrue);
  });
}
