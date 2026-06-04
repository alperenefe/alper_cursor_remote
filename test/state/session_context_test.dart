import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/state/sessions/session_context.dart';
import 'package:alper_cursor_remote/state/sessions/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('boş PC linkli kutu atlanır, mesajlı loc seçilir', () {
    final store = SessionStore();
    const pc = 'pc-music-uuid';
    const musicLoc = 'loc-music';
    const emptyLoc = 'loc-empty';

    store.of(musicLoc).messages.add(
          ChatMessage(
            id: 'u1',
            role: ChatRole.user,
            text: 'müzik path nerede',
            at: DateTime(2026, 5, 29, 10),
            sessionId: musicLoc,
          ),
        );
    store.linkPcSession(emptyLoc, pc);

    final resolved = resolveSelectionLocalId(
      store,
      pc,
      historyEntries: [
        {
          'sessionId': pc,
          'userMessage': 'müzik path nerede',
          'assistantResponse': 'cevap',
        },
      ],
    );

    expect(resolved, musicLoc);
    expect(store.of(musicLoc).messages.length, 1);
    expect(store.findByPcSessionId(pc)?.localId, musicLoc);
  });

  test('boş loc-* seçilince mesajlı kutu seçilir', () {
    final store = SessionStore();
    const pc = 'pc-music-uuid';
    const musicLoc = 'loc-music';
    const emptyLoc = 'loc-empty';

    store.of(musicLoc).messages.add(
          ChatMessage(
            id: 'u1',
            role: ChatRole.user,
            text: 'müzik path nerede',
            at: DateTime(2026, 5, 29, 10),
            sessionId: musicLoc,
          ),
        );
    store.linkPcSession(emptyLoc, pc);

    final resolved = resolveSelectionLocalId(store, emptyLoc);
    expect(resolved, musicLoc);
    expect(store.findByPcSessionId(pc)?.localId, musicLoc);
  });

  test('iki yerel sohbet varken PC uuid geçmiş satırıyla doğru loc', () {
    final store = SessionStore();
    const pc = 'pc-music-uuid';
    const musicLoc = 'loc-music';
    const yurukLoc = 'loc-yuruk';

    store.of(musicLoc).messages.add(
          ChatMessage(
            id: 'u1',
            role: ChatRole.user,
            text: 'müzik path nerede',
            at: DateTime(2026, 5, 29, 10),
            sessionId: musicLoc,
          ),
        );
    store.of(yurukLoc).messages.add(
          ChatMessage(
            id: 'u2',
            role: ChatRole.user,
            text: 'yürük path nerede',
            at: DateTime(2026, 5, 29, 11),
            sessionId: yurukLoc,
          ),
        );
    store.of('loc-empty');
    store.linkPcSession('loc-empty', pc);

    final resolved = resolveSelectionLocalId(
      store,
      pc,
      historyEntries: [
        {
          'sessionId': pc,
          'userMessage': 'müzik path nerede',
          'assistantResponse': 'cevap',
        },
      ],
    );

    expect(resolved, musicLoc);
    expect(store.findByPcSessionId(pc)?.localId, musicLoc);
  });

  test('resolveSelectionLocalId PC uuid → loc + linkPcSession', () {
    final store = SessionStore();
    const pc = 'pc-uuid-abc';
    final loc = resolveSelectionLocalId(store, pc);
    expect(loc.startsWith('loc-'), isTrue);
    expect(store.findByPcSessionId(pc)?.localId, loc);
  });
}
