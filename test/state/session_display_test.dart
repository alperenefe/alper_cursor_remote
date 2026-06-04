import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/state/session_isolation.dart';
import 'package:alper_cursor_remote/state/session_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// İki oturum: balonlar yalnızca seçili `loc-*` kutusunda görünür.
void main() {
  test('strictMessagesForBucket oturum başına izole', () {
    final registry = SessionRegistry();
    const music = 'loc-music';
    const yuruk = 'loc-yuruk';

    registry.messagesFor(music).add(
      ChatMessage(
        id: 'm1',
        role: ChatRole.user,
        text: 'müzik',
        at: DateTime(2026, 5, 29, 10),
        sessionId: music,
      ),
    );
    registry.messagesFor(yuruk).add(
      ChatMessage(
        id: 'y1',
        role: ChatRole.user,
        text: 'yürük',
        at: DateTime(2026, 5, 29, 11),
        sessionId: yuruk,
      ),
    );

    final musicVisible =
        strictMessagesForBucket(registry.messagesFor(music), music);
    final yurukVisible =
        strictMessagesForBucket(registry.messagesFor(yuruk), yuruk);

    expect(musicVisible.length, 1);
    expect(musicVisible.first.text, 'müzik');
    expect(yurukVisible.length, 1);
    expect(yurukVisible.first.text, 'yürük');
  });
}
