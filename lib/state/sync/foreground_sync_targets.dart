import '../../models/chat_message.dart';
import '../chat/chat_turn_logic.dart';
import '../session_registry.dart';

/// Ön plana dönünce PC geçmişi çekilecek oturumlar.
Set<String> collectForegroundHistorySyncTargets({
  required SessionRegistry registry,
  required String activeLocalId,
}) {
  final targets = <String>{};
  for (final e in registry.liveEntries) {
    final live = e.value;
    if (live.waitingResponse || live.queue.isNotEmpty) {
      targets.add(e.key);
    }
  }
  if (_sessionNeedsHistoryCatchUp(registry, activeLocalId)) {
    targets.add(activeLocalId);
  }
  return targets;
}

bool _sessionNeedsHistoryCatchUp(SessionRegistry registry, String sessionId) {
  final sorted = sortedUserAssistantMessages(registry.messagesFor(sessionId));
  if (sorted.isEmpty) return false;
  ChatMessage? lastUser;
  for (var i = sorted.length - 1; i >= 0; i--) {
    if (sorted[i].role == ChatRole.user) {
      lastUser = sorted[i];
      break;
    }
  }
  if (lastUser == null) return false;
  return !userMessageHasAssistantReplyAfter(sorted, lastUser.id);
}
