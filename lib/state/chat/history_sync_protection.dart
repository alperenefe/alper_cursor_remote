import '../../models/chat_message.dart';
import '../../models/session_live_state.dart';
import '../../services/chat_history_applier.dart';

/// PC geçmişi yenilenirken henüz dosyaya yazılmamış yerel turu silme.
List<ChatMessage> protectMessagesDuringHistorySync({
  required List<ChatMessage> current,
  required SessionLiveState live,
}) {
  final protectIds = <String>{
    for (final q in live.queue) q.localMessageId,
    if (live.awaitingReplyForUserId != null) live.awaitingReplyForUserId!,
    if (live.pendingReplyForUserId != null) live.pendingReplyForUserId!,
    if (live.streamingMessageId != null) live.streamingMessageId!,
    if (live.inFlight != null) live.inFlight!.localMessageId,
  };

  final protected = <ChatMessage>[];
  for (final m in current) {
    final isChat = m.role == ChatRole.user ||
        m.role == ChatRole.assistant ||
        m.kind == InboundKind.chatResponseChunk;
    if (!isChat) continue;

    if (m.kind == InboundKind.userPrompt) {
      protected.add(m);
      continue;
    }
    if (protectIds.contains(m.id)) {
      protected.add(m);
      continue;
    }
    if (m.role == ChatRole.assistant &&
        (m.kind == InboundKind.chatResponse ||
            m.kind == InboundKind.chatResponseComplete) &&
        !m.id.startsWith('h-')) {
      protected.add(m);
      continue;
    }
    if (m.isStreaming) {
      protected.add(m);
      continue;
    }
    final replyTo = m.replyToUserId;
    if (replyTo != null && protectIds.contains(replyTo)) {
      protected.add(m);
    }
  }
  return protected;
}

void mergeProtectedIntoList(
  List<ChatMessage> list,
  List<ChatMessage> protected, {
  required bool Function(ChatMessage local, ChatMessage existing) localIsRicher,
  required bool Function(ChatMessage a, ChatMessage b) messagesEquivalent,
  required void Function(List<ChatMessage>) sortChronologically,
}) {
  for (final m in protected) {
    final equivIdx = list.indexWhere(
      (x) => x.id == m.id || messagesEquivalent(x, m),
    );
    if (equivIdx >= 0) {
      final existing = list[equivIdx];
      if (localIsRicher(m, existing)) {
        if (existing.id != m.id) {
          rewireAssistantRepliesAfterUserIdChange(list, existing.id, m.id);
        }
        list[equivIdx] = ChatMessage(
          id: m.id,
          role: m.role,
          text: m.text,
          at: m.at,
          kind: m.kind,
          agentMode: m.agentMode ?? existing.agentMode,
          isStreaming: m.isStreaming,
          replyToUserId: m.replyToUserId ?? existing.replyToUserId,
          sessionId: m.sessionId ?? existing.sessionId,
        );
      }
      continue;
    }
    list.add(m);
  }
  sortChronologically(list);
}
