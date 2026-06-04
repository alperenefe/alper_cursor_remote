import '../../models/chat_message.dart';
import '../../models/queued_prompt.dart';
import '../chat/chat_turn_logic.dart';

/// Tamamlanmış turlar: kullanıcı → ona bağlı cevap(lar); sonra sıradakiler en altta.
List<ChatMessage> orderSettledByTurns(List<ChatMessage> messages) {
  final chat = messages
      .where((m) => m.role == ChatRole.user || m.role == ChatRole.assistant)
      .toList();
  if (chat.isEmpty) return const [];

  final users = chat.where((m) => m.role == ChatRole.user).toList()
    ..sort((a, b) {
      final t = a.at.compareTo(b.at);
      if (t != 0) return t;
      return a.id.compareTo(b.id);
    });

  final assistants =
      chat.where((m) => m.role == ChatRole.assistant).toList();
  final chron = sortedUserAssistantMessages(chat);
  final result = <ChatMessage>[];
  final usedAssistants = <String>{};

  for (final u in users) {
    result.add(u);

    final bound = assistants
        .where(
          (a) =>
              a.replyToUserId == u.id && !usedAssistants.contains(a.id),
        )
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    for (final a in bound) {
      result.add(a);
      usedAssistants.add(a.id);
    }

    if (bound.isEmpty) {
      final userOrder = users.indexWhere((x) => x.id == u.id);
      final ui = chron.indexWhere((m) => m.id == u.id);
      if (ui < 0) continue;
      final nextUserAt = userOrder + 1 < users.length
          ? users[userOrder + 1].at
          : null;
      for (var j = ui + 1; j < chron.length; j++) {
        final m = chron[j];
        if (m.role == ChatRole.user) break;
        if (m.role != ChatRole.assistant ||
            usedAssistants.contains(m.id) ||
            (m.replyToUserId != null && m.replyToUserId != u.id)) {
          continue;
        }
        if (nextUserAt != null && m.at.isAfter(nextUserAt)) break;
        result.add(m);
        usedAssistants.add(m.id);
      }
    }
  }

  // replyToUserId yok: cevabı, zamanına en yakın önceki cevapsız tura yaz.
  final orphans = assistants
      .where((a) => !usedAssistants.contains(a.id))
      .toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  for (final a in orphans) {
    ChatMessage? owner;
    for (var ui = users.length - 1; ui >= 0; ui--) {
      final u = users[ui];
      if (u.at.isAfter(a.at)) continue;
      final hasBound = assistants.any(
        (x) => x.replyToUserId == u.id && usedAssistants.contains(x.id),
      );
      if (!hasBound) {
        owner = u;
        break;
      }
    }
    if (owner == null) continue;
    final at = result.indexWhere((m) => m.id == owner!.id);
    if (at < 0) continue;
    result.insert(at + 1, a);
    usedAssistants.add(a.id);
  }

  final progress = messages.where((m) => m.role == ChatRole.progress);
  return [...result, ...progress];
}

/// Görünür liste: yerleşmiş turlar + (isteğe bağlı uçuşta tur) + sıra (FIFO) en altta.
List<ChatMessage> buildConversationDisplayMessages({
  required List<ChatMessage> visible,
  required List<QueuedPrompt> effectiveQueue,
  String? inFlightUserMessageId,
}) {
  final byId = {for (final m in visible) m.id: m};
  final queuedIds = effectiveQueue.map((q) => q.localMessageId).toSet();
  final pinnedIds = {...queuedIds};
  if (inFlightUserMessageId != null) {
    pinnedIds.add(inFlightUserMessageId);
  }

  final settled = visible.where((m) => !pinnedIds.contains(m.id)).toList();
  final orderedSettled = orderSettledByTurns(settled);

  final pinned = <ChatMessage>[];
  if (inFlightUserMessageId != null &&
      byId.containsKey(inFlightUserMessageId) &&
      !queuedIds.contains(inFlightUserMessageId)) {
    pinned.add(byId[inFlightUserMessageId]!);
  }
  for (final q in effectiveQueue) {
    if (byId.containsKey(q.localMessageId)) {
      pinned.add(byId[q.localMessageId]!);
    }
  }

  return [...orderedSettled, ...pinned];
}
