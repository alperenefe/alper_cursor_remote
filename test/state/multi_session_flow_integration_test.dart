import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/state/session_isolation.dart';
import 'package:alper_cursor_remote/state/sessions/session_resolver.dart';
import 'package:alper_cursor_remote/state/sessions/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Token yok — store/resolver ile müzik↔yürük izolasyonu (CI her zaman).
void main() {
  test('iki oturum: mesajlar karışmaz, boş kutu müziğe çekilmez', () {
    final store = SessionStore();
    final resolver = SessionResolver(store);
    const music = 'loc-music';
    const yuruk = 'loc-yuruk';
    const pcMusic = 'pc-uuid-music';

    store.of(music).messages.addAll([
      ChatMessage(
        id: 'u1',
        role: ChatRole.user,
        text: 'müzik projesinin path nerede',
        at: DateTime(2026, 5, 29, 10),
        sessionId: music,
      ),
    ]);
    store.of(yuruk).messages.addAll([
      ChatMessage(
        id: 'u2',
        role: ChatRole.user,
        text: 'yürük projesinin path nerede',
        at: DateTime(2026, 5, 29, 11),
        sessionId: yuruk,
      ),
    ]);

    store.of('loc-empty');
    store.linkPcSession('loc-empty', pcMusic);

    final history = [
      {
        'sessionId': pcMusic,
        'userMessage': 'müzik projesinin path nerede',
        'assistantResponse': 'cevap',
      },
    ];

    expect(resolver.resolve(pcMusic, historyEntries: history), music);
    expect(resolver.resolve('loc-empty', historyEntries: history), music);

    final musicUi =
        strictMessagesForBucket(store.of(music).messages, music);
    final yurukUi =
        strictMessagesForBucket(store.of(yuruk).messages, yuruk);

    expect(musicUi.any((m) => m.text.contains('müzik')), isTrue);
    expect(musicUi.any((m) => m.text.contains('yürük')), isFalse);
    expect(yurukUi.any((m) => m.text.contains('yürük')), isTrue);
    expect(yurukUi.any((m) => m.text.contains('müzik')), isFalse);
  });

  test('taslak oturum yürük/müzik kutusuna kaymaz', () {
    final store = SessionStore();
    final draft = store.beginDraftSession();
    store.of('loc-music').messages.add(
          ChatMessage(
            id: 'u1',
            role: ChatRole.user,
            text: 'müzik',
            at: DateTime(2026, 5, 29, 10),
            sessionId: 'loc-music',
          ),
        );
    expect(SessionResolver(store).resolve(draft), draft);
  });
}
