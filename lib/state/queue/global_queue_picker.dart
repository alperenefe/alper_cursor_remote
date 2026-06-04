import '../../models/queued_prompt.dart';
import '../session_registry.dart';
import 'prompt_queue_logic.dart';

/// En eski kuyruk girdisi (oturumlar arası adil sıra).
({QueuedPrompt prompt, String? sessionId})? pickNextQueuedGlobally(
  SessionRegistry registry, {
  required bool Function(String a, String b) userMessagesLikelySame,
}) {
  QueuedPrompt? best;
  String? bestSid;
  for (final e in registry.liveEntries) {
    // Yalnızca PC'de gerçekten uçuşta tur varken bu oturumun kuyruğunu atla.
    final live = e.value;
    if (live.waitingResponse &&
        (live.inFlight != null || live.inFlightWireDispatched)) {
      continue;
    }
    final sid = e.key;
    final pending = effectiveQueuedFor(
      registry,
      sid,
      userMessagesLikelySame: userMessagesLikelySame,
    );
    if (pending.isEmpty) continue;
    final first = pending.first;
    if (best == null || first.queuedAt.isBefore(best.queuedAt)) {
      best = first;
      bestSid = sid;
    }
  }
  if (best == null) return null;
  return (prompt: best, sessionId: bestSid);
}
