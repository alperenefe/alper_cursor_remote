import '../../models/chat_message.dart';
import '../../models/session_live_state.dart';
import '../../services/assistant_text_sanitize.dart';
import '../chat/chat_turn_logic.dart';

/// PC `chat_response_chunk` önizlemesi dolu ama tam `chat_response` gelmediyse
/// beklemeyi kapatmak için akış metnini asistan balonuna yaz.
bool tryMaterializeLiveStreamReply({
  required SessionLiveState live,
  required List<ChatMessage> list,
  required String sessionId,
  required String Function() newMessageId,
  required bool Function(String a, String b) sameUserText,
  required bool Function(List<ChatMessage> list, String text, String userId)
      isDuplicateReply,
  int minChars = 48,
}) {
  if (!live.waitingResponse) return false;

  final uid =
      live.pendingReplyForUserId ?? live.awaitingReplyForUserId;
  if (uid == null) return false;

  final sorted = list
      .where((m) => m.role == ChatRole.user || m.role == ChatRole.assistant)
      .toList();
  sortChatMessagesChronologically(sorted);
  if (userTurnHasVisibleAssistantReply(
    sorted,
    uid,
    sameUserText: sameUserText,
  )) {
    return false;
  }

  var raw = live.agentLiveStreamText.trim();
  if (raw.length < minChars) {
    final prog = live.agentLiveProgressLine.trim();
    if (prog.length >= minChars) {
      raw = prog;
    } else {
      return false;
    }
  }
  if (isGarbageAssistantText(raw) || _looksLikeTransientProgressOnly(raw)) {
    return false;
  }

  final cleaned = sanitizeAssistantTextForDisplay(raw);
  if (cleaned.trim().length < minChars) return false;
  if (isDuplicateReply(list, cleaned, uid)) return false;

  final reply = ChatMessage(
    id: newMessageId(),
    role: ChatRole.assistant,
    text: cleaned,
    at: DateTime.now(),
    kind: InboundKind.chatResponse,
    isStreaming: false,
    replyToUserId: uid,
    sessionId: sessionId,
  );
  insertAssistantAfterUser(list, reply, uid);
  live.pendingReplyForUserId = null;
  return true;
}

bool _looksLikeTransientProgressOnly(String text) {
  final t = text.trim();
  if (t.length >= 120) return false;
  final low = t.toLowerCase();
  const markers = [
    'planlıyor',
    'planlama',
    'düşünüyor',
    'kontrol ediyorum',
    'çalışıyor',
    'bekleyin',
  ];
  var hits = 0;
  for (final m in markers) {
    if (low.contains(m)) hits++;
  }
  return hits >= 1 && t.length < 100;
}
