import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/state/chat/chat_message_match.dart';
import 'package:alper_cursor_remote/state/chat/chat_turn_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('userMessageHasAssistantReplyAfter', () {
    final msgs = [
      ChatMessage(
        id: 'u1',
        role: ChatRole.user,
        text: 'q',
        at: DateTime(2026, 1, 1),
      ),
      ChatMessage(
        id: 'a1',
        role: ChatRole.assistant,
        text: 'a',
        at: DateTime(2026, 1, 1, 0, 0, 1),
        kind: InboundKind.chatResponse,
      ),
    ];
    expect(userMessageHasAssistantReplyAfter(msgs, 'u1'), isTrue);
    expect(userMessageHasAssistantReplyAfter(msgs, 'missing'), isFalse);
  });

  test('sonraki kullanıcı turu önceki cevapla karışmaz', () {
    final msgs = [
      ChatMessage(
        id: 'u1',
        role: ChatRole.user,
        text: 'plan',
        at: DateTime(2026, 1, 1),
      ),
      ChatMessage(
        id: 'a1',
        role: ChatRole.assistant,
        text: 'plan metni',
        at: DateTime(2026, 1, 1, 0, 0, 1),
        replyToUserId: 'u1',
        kind: InboundKind.chatResponse,
      ),
      ChatMessage(
        id: 'u2',
        role: ChatRole.user,
        text: 'devam',
        at: DateTime(2026, 1, 1, 0, 1),
      ),
    ];
    expect(userMessageHasAssistantReplyAfter(msgs, 'u1'), isTrue);
    expect(userMessageHasAssistantReplyAfter(msgs, 'u2'), isFalse);
  });

  test('userTurnHasVisibleAssistantReply eşdeğer h-u turunda cevap bulur', () {
    final msgs = [
      ChatMessage(
        id: 'h-u-pc',
        role: ChatRole.user,
        text: 'başlık girmeden kaydet',
        at: DateTime(2026, 5, 29, 12, 34, 41),
      ),
      ChatMessage(
        id: 'h-a-pc',
        role: ChatRole.assistant,
        text: 'kaydetme cevabı',
        at: DateTime(2026, 5, 29, 12, 35),
        kind: InboundKind.chatResponse,
      ),
    ];
    expect(
      userTurnHasVisibleAssistantReply(msgs, 'local-msg-1'),
      isFalse,
    );
    final withLocal = [
      ...msgs,
      ChatMessage(
        id: 'local-msg-1',
        role: ChatRole.user,
        text: 'başlık girmeden kaydet',
        at: DateTime(2026, 5, 29, 12, 34, 40),
      ),
    ];
    expect(
      userTurnHasVisibleAssistantReply(
        withLocal,
        'local-msg-1',
        sameUserText: userMessagesLikelySame,
      ),
      isTrue,
    );
    expect(userMessageHasAssistantReplyAfter(withLocal, 'local-msg-1'), isFalse);
  });

  test('insertAssistantAfterUser başka tura karışmaz', () {
    final list = [
      ChatMessage(
        id: 'u1',
        role: ChatRole.user,
        text: '1',
        at: DateTime(2026, 1, 1),
      ),
      ChatMessage(
        id: 'a-old',
        role: ChatRole.assistant,
        text: 'old',
        at: DateTime(2026, 1, 1, 0, 0, 1),
        replyToUserId: 'u2',
      ),
      ChatMessage(
        id: 'u2',
        role: ChatRole.user,
        text: '2',
        at: DateTime(2026, 1, 1, 0, 1),
      ),
    ];
    insertAssistantAfterUser(
      list,
      ChatMessage(
        id: 'a-new',
        role: ChatRole.assistant,
        text: 'new',
        at: DateTime(2026, 1, 1, 0, 2),
        replyToUserId: 'u1',
      ),
      'u1',
    );
    expect(list[1].id, 'a-new');
    expect(list[2].id, 'a-old');
  });
}
