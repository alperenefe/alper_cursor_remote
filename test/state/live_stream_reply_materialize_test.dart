import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/models/session_live_state.dart';
import 'package:alper_cursor_remote/state/chat/chat_message_match.dart';
import 'package:alper_cursor_remote/state/sync/live_stream_reply_materialize.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('akış metni varken asistan balonu eklenir', () {
    final live = SessionLiveState()
      ..waitingResponse = true
      ..awaitingReplyForUserId = 'u1'
      ..agentLiveStreamText =
          '## Müzik Teorisi — durum özeti\n\n- Telefonda sürüm 1.0.2+10';
    final list = [
      ChatMessage(
        id: 'u1',
        role: ChatRole.user,
        text: 'uygulama şu an hangi durumda',
        at: DateTime(2026, 5, 31),
      ),
    ];

    final ok = tryMaterializeLiveStreamReply(
      live: live,
      list: list,
      sessionId: 'loc-1',
      newMessageId: () => 'a1',
      sameUserText: userMessagesLikelySame,
      isDuplicateReply: (_, __, ___) => false,
    );

    expect(ok, isTrue);
    expect(list.length, 2);
    expect(list[1].role, ChatRole.assistant);
    expect(list[1].replyToUserId, 'u1');
    expect(list[1].text, contains('Müzik Teorisi'));
  });
}
