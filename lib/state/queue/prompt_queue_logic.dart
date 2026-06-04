import '../../models/chat_message.dart';
import '../../models/queued_prompt.dart';
import '../chat/chat_turn_logic.dart';
import '../session_registry.dart';

/// Kuyruk kaydı artık «sırada» sayılmasın (cevaplanmış, PC kopyası, uçuşta).
bool shouldDropQueueEntry({
  required QueuedPrompt q,
  required List<ChatMessage> msgs,
  required List<ChatMessage> sortedChat,
  required String? inflightId,
  required String? awaitingReplyUserId,
  required bool Function(String a, String b) userMessagesLikelySame,
}) {
  if (q.localMessageId == inflightId) return true;

  ChatMessage? bubble;
  for (final m in msgs) {
    if (m.id == q.localMessageId && m.role == ChatRole.user) {
      bubble = m;
      break;
    }
  }
  if (bubble == null) return true;

  final stillWaitingThisTurn =
      q.localMessageId == awaitingReplyUserId;

  if (!stillWaitingThisTurn &&
      userMessageHasAssistantReplyAfter(sortedChat, q.localMessageId)) {
    return true;
  }

  for (final m in msgs) {
    if (m.id == q.localMessageId) continue;
    if (m.role == ChatRole.user &&
        m.id.startsWith('h-u-') &&
        userMessagesLikelySame(bubble.text, m.text)) {
      // Plan + ek: PC geçmişi gelince yerel tur hâlâ bekliyorsa sıradan düşme.
      if (stillWaitingThisTurn) return false;
      return true;
    }
  }
  return false;
}

/// Gerçekten sırada bekleyen (PC'ye gitmemiş, balonu görünen) kayıtlar.
List<QueuedPrompt> effectiveQueuedFor(
  SessionRegistry registry,
  String? sessionId, {
  required bool Function(String a, String b) userMessagesLikelySame,
}) {
  pruneOrphanQueueForSession(registry, sessionId);
  final live = registry.liveFor(sessionId);
  if (live.queue.isEmpty) return const [];

  final inflightId = live.inFlight?.localMessageId;
  final awaitingId =
      live.awaitingReplyForUserId ?? live.pendingReplyForUserId;
  final msgs = registry.messagesFor(sessionId);
  final sortedChat = sortedUserAssistantMessages(msgs);

  final pending = live.queue
      .where(
        (q) =>
            q.localMessageId != inflightId &&
            !shouldDropQueueEntry(
              q: q,
              msgs: msgs,
              sortedChat: sortedChat,
              inflightId: inflightId,
              awaitingReplyUserId: awaitingId,
              userMessagesLikelySame: userMessagesLikelySame,
            ),
      )
      .toList()
    ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
  return pending;
}

int effectiveQueuedCount(
  SessionRegistry registry,
  String? sessionId, {
  required bool Function(String a, String b) userMessagesLikelySame,
}) {
  return effectiveQueuedFor(
    registry,
    sessionId,
    userMessagesLikelySame: userMessagesLikelySame,
  ).length;
}

void pruneOrphanQueueForSession(SessionRegistry registry, String? sessionId) {
  final live = registry.liveFor(sessionId);
  final msgs = registry.messagesFor(sessionId);
  live.queue.removeWhere(
    (q) => !msgs.any(
      (m) => m.id == q.localMessageId && m.role == ChatRole.user,
    ),
  );
}

void sanitizeQueueForSession(
  SessionRegistry registry,
  String? sessionId, {
  required bool Function(String a, String b) userMessagesLikelySame,
  void Function()? onQueueChanged,
}) {
  pruneOrphanQueueForSession(registry, sessionId);
  final live = registry.liveFor(sessionId);
  if (live.queue.isEmpty) return;

  final inflightId = live.inFlight?.localMessageId;
  final awaitingId =
      live.awaitingReplyForUserId ?? live.pendingReplyForUserId;
  final msgs = registry.messagesFor(sessionId);
  final sortedChat = sortedUserAssistantMessages(msgs);
  final before = live.queue.length;
  live.queue.removeWhere(
    (q) {
      if (q.localMessageId == inflightId) return false;
      return shouldDropQueueEntry(
        q: q,
        msgs: msgs,
        sortedChat: sortedChat,
        inflightId: inflightId,
        awaitingReplyUserId: awaitingId,
        userMessagesLikelySame: userMessagesLikelySame,
      );
    },
  );
  if (before != live.queue.length) {
    onQueueChanged?.call();
  }
}

void sanitizeAllSessionQueues(
  SessionRegistry registry, {
  required bool Function(String a, String b) userMessagesLikelySame,
  void Function()? onQueueChanged,
}) {
  for (final key in registry.liveEntries.map((e) => e.key).toList()) {
    final sid = key;
    sanitizeQueueForSession(
      registry,
      sid,
      userMessagesLikelySame: userMessagesLikelySame,
      onQueueChanged: onQueueChanged,
    );
  }
}
