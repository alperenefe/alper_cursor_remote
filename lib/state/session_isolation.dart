import '../models/chat_message.dart';
import '../services/chat_history_applier.dart';

/// Oturum kutusu için kanonik id (mobil `loc-…` veya PC uuid).
String? canonicalBucketId(String? sessionId) {
  final s = sessionId?.trim();
  if (s == null || s.isEmpty) return null;
  return s;
}

/// PC geçmiş kaydı bu oturuma ait mi?
bool historyEntryBelongsToSession(
  Map<String, dynamic> entry,
  String targetSessionId,
) {
  final sid = targetSessionId.trim();
  if (sid.isEmpty) return false;
  final es = (entry['sessionId'] as String? ?? '').trim();
  if (es.isEmpty) return false;
  return es == sid;
}

List<Map<String, dynamic>> strictFilterEntriesBySession(
  List<Map<String, dynamic>> entries,
  String sessionId,
) {
  final sid = sessionId.trim();
  if (sid.isEmpty) return const [];
  final out = entries.where((e) => historyEntryBelongsToSession(e, sid)).toList();
  out.sort(
    (a, b) => (parseEntryTimestamp(a) ?? DateTime(0))
        .compareTo(parseEntryTimestamp(b) ?? DateTime(0)),
  );
  return out;
}

/// Balon bu kutuda gösterilmeli mi?
List<ChatMessage> strictMessagesForBucket(
  List<ChatMessage> messages,
  String? sessionId,
) {
  final bucket = sessionId?.trim() ?? '';
  if (bucket.isEmpty) {
    return messages
        .where((m) {
          final tag = m.sessionId?.trim() ?? '';
          return tag.isEmpty;
        })
        .toList();
  }
  return messages
      .where((m) {
        final tag = m.sessionId?.trim() ?? '';
        if (tag.isEmpty) return true;
        return tag == bucket;
      })
      .toList();
}

int purgeForeignMessagesInBucket(
  List<ChatMessage> bucket,
  String? sessionId,
) {
  final kept = strictMessagesForBucket(bucket, sessionId);
  final removed = bucket.length - kept.length;
  if (removed > 0) {
    bucket
      ..clear()
      ..addAll(kept);
  }
  return removed;
}
