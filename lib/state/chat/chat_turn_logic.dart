import '../../models/chat_message.dart';
import 'chat_message_match.dart';

/// Kullanıcı mesajından sonra (kronolojik) tam asistan cevabı var mı?
bool userMessageHasAssistantReplyAfter(
  List<ChatMessage> sortedChat,
  String userMessageId,
) {
  // replyToUserId ile bağlı cevap (plan/agent turu).
  for (final m in sortedChat) {
    if (m.role != ChatRole.assistant) continue;
    if (m.kind == InboundKind.chatResponseChunk) continue;
    if (m.replyToUserId == userMessageId) return true;
  }

  // Eski PC geçmişi: bu kullanıcı ile sonraki kullanıcı arasındaki ilk cevap.
  final userIdx = sortedChat.indexWhere((m) => m.id == userMessageId);
  if (userIdx < 0) return false;
  for (var i = userIdx + 1; i < sortedChat.length; i++) {
    final m = sortedChat[i];
    if (m.role == ChatRole.user) break;
    if (m.role == ChatRole.assistant &&
        m.kind != InboundKind.chatResponseChunk) {
      if (m.replyToUserId != null && m.replyToUserId != userMessageId) {
        continue;
      }
      return true;
    }
  }
  return false;
}

/// Yerel tur id'si ile PC `h-u-*` farklı olsa bile aynı metinli turda cevap var mı?
bool userTurnHasVisibleAssistantReply(
  List<ChatMessage> sorted,
  String userMessageId, {
  bool Function(String a, String b)? sameUserText,
}) {
  if (userMessageHasAssistantReplyAfter(sorted, userMessageId)) return true;
  final same = sameUserText ?? userMessagesLikelySame;
  ChatMessage? userMsg;
  for (final m in sorted) {
    if (m.id == userMessageId && m.role == ChatRole.user) {
      userMsg = m;
      break;
    }
  }
  if (userMsg == null) return false;
  for (final m in sorted) {
    if (m.role != ChatRole.user || m.id == userMessageId) continue;
    if (!same(m.text, userMsg.text)) continue;
    if (userMessageHasAssistantReplyAfter(sorted, m.id)) return true;
  }
  return false;
}

void sortChatMessagesChronologically(List<ChatMessage> list) {
  list.sort((a, b) {
    final t = a.at.compareTo(b.at);
    if (t != 0) return t;
    if (a.role == ChatRole.user && b.role == ChatRole.assistant) {
      return -1;
    }
    if (a.role == ChatRole.assistant && b.role == ChatRole.user) {
      return 1;
    }
    return a.id.compareTo(b.id);
  });
}

List<ChatMessage> sortedUserAssistantMessages(List<ChatMessage> messages) {
  final sorted = messages
      .where(
        (m) => m.role == ChatRole.user || m.role == ChatRole.assistant,
      )
      .toList();
  sortChatMessagesChronologically(sorted);
  return sorted;
}

/// Asistan cevabını ilgili kullanıcı turunun hemen altına yerleştir.
int insertIndexAfterUserTurn(List<ChatMessage> list, String userId) {
  final userIdx = list.indexWhere((m) => m.id == userId);
  if (userIdx < 0) return list.length;
  var at = userIdx + 1;
  while (at < list.length) {
    final m = list[at];
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

int insertAssistantAfterUser(
  List<ChatMessage> list,
  ChatMessage msg,
  String userId,
) {
  final at = insertIndexAfterUserTurn(list, userId);
  list.insert(at, msg);
  return at;
}
