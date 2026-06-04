import 'package:alper_cursor_remote/models/chat_message.dart';
import 'package:alper_cursor_remote/state/chat/chat_message_match.dart';
import 'package:flutter_test/flutter_test.dart';

/// AppState._insertIndexAfterUserTurn ile aynı mantık (regresyon).
int insertIndexAfterUserTurn(List<ChatMessage> messages, String userId) {
  final userIdx = messages.indexWhere((m) => m.id == userId);
  if (userIdx < 0) return messages.length;
  var at = userIdx + 1;
  while (at < messages.length) {
    final m = messages[at];
    if (m.role == ChatRole.user) break;
    if (m.role == ChatRole.assistant &&
        m.replyToUserId != null &&
        m.replyToUserId != userId) {
      break;
    }
    if (m.role == ChatRole.assistant) {
      at++;
      continue;
    }
    break;
  }
  return at;
}

void main() {
  test('menekşe harfleri: her cevap kendi harfinin altında', () {
    final now = DateTime.now();
    final letters = 'mene'.split('');
    final messages = <ChatMessage>[];

    for (var i = 0; i < letters.length; i++) {
      final uid = 'u$i';
      messages.add(
        ChatMessage(
          id: uid,
          role: ChatRole.user,
          text: letters[i],
          at: now.add(Duration(seconds: i)),
          kind: InboundKind.userPrompt,
        ),
      );
      final at = insertIndexAfterUserTurn(messages, uid);
      messages.insert(
        at,
        ChatMessage(
          id: 'a$i',
          role: ChatRole.assistant,
          text: 'cevap-${letters[i]}',
          at: now.add(Duration(seconds: i, milliseconds: 500)),
          replyToUserId: uid,
        ),
      );
    }

    expect(messages[0].text, 'm');
    expect(messages[1].text, 'cevap-m');
    expect(messages[1].replyToUserId, 'u0');
    expect(messages[2].text, 'e');
    expect(messages[3].text, 'cevap-e');
    expect(messages[3].replyToUserId, 'u1');
  });

  test('farklı harf cevapları aynı balon sayılmaz', () {
    expect(
      normalizedAssistantBody('cevap-m') == normalizedAssistantBody('cevap-e'),
      isFalse,
    );
  });
}
