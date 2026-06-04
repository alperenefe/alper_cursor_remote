import '../../models/chat_message.dart';
import '../../models/queued_prompt.dart';
import '../../models/session_live_state.dart';
import '../chat/chat_message_match.dart';
import '../chat/chat_turn_logic.dart';

/// Kopma sonrası yanlışlıkla kuyruğa alınmış, PC'de zaten işlenen tur.
class PendingTurnReconcileResult {
  const PendingTurnReconcileResult({
    this.restoredWaiting = false,
    this.removedFromQueue = 0,
  });

  final bool restoredWaiting;
  final int removedFromQueue;
}

/// Son kullanıcı turu cevapsız ve kuyruk aynı mesajı taşıyorsa yeniden gönderme —
/// beklemeyi geri yükle.
PendingTurnReconcileResult reconcileUnansweredTurnFromQueue({
  required SessionLiveState live,
  required List<ChatMessage> sorted,
  required bool Function(String a, String b) userMessagesLikelySame,
}) {
  if (live.waitingResponse) {
    return const PendingTurnReconcileResult();
  }

  // Önizleme tamamlandıysa yeniden «bekliyor» yapma.
  if (live.agentLiveStreamText.trim().length >= 48 ||
      live.agentLiveProgressLine.trim().length >= 48) {
    return const PendingTurnReconcileResult();
  }

  ChatMessage? lastUser;
  for (var i = sorted.length - 1; i >= 0; i--) {
    if (sorted[i].role == ChatRole.user) {
      lastUser = sorted[i];
      break;
    }
  }
  if (lastUser == null) {
    return const PendingTurnReconcileResult();
  }
  if (userMessageHasAssistantReplyAfter(sorted, lastUser.id)) {
    return const PendingTurnReconcileResult();
  }

  QueuedPrompt? matched;
  var removed = 0;
  for (final q in List<QueuedPrompt>.from(live.queue)) {
    final sameTurn = q.localMessageId == lastUser.id ||
        userMessagesLikelySame(q.text, lastUser.text);
    if (!sameTurn) continue;
    matched ??= q;
    live.queue.removeWhere((x) => x.localMessageId == q.localMessageId);
    removed++;
  }

  if (matched == null) {
    return PendingTurnReconcileResult(removedFromQueue: removed);
  }

  live.waitingResponse = true;
  live.waitingSince ??= DateTime.now();
  live.awaitingReplyForUserId = lastUser.id;
  live.pendingReplyForUserId = lastUser.id;
  live.inFlight = QueuedPrompt(
    text: matched.text,
    agentMode: matched.agentMode,
    queuedAt: matched.queuedAt,
    localMessageId: lastUser.id,
    sessionId: matched.sessionId,
    attachments: matched.attachments,
  );
  live.inFlightWireDispatched = true;

  return PendingTurnReconcileResult(
    restoredWaiting: true,
    removedFromQueue: removed,
  );
}
