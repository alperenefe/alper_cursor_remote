import '../session_registry.dart';

/// Bekleyen tek bir gönderim (oturum kutusu + balon id).
class WaitingDispatch {
  const WaitingDispatch({
    required this.bucketKey,
    required this.localMessageId,
    required this.waitingSince,
  });

  final String bucketKey;
  final String localMessageId;
  final DateTime waitingSince;
}

/// Gelen cevap hangi registry kutusuna yazılmalı?
///
/// PC `sessionId` yanlış olsa bile: gönderim anındaki bucket + FIFO ile eşleştir.
String? resolveInboundBucketKey({
  required String? wireSessionId,
  required List<WaitingDispatch> waiting,
  required Map<String, String> dispatchBucketByLocalMessageId,
}) {
  if (waiting.isEmpty) {
    final w = wireSessionId?.trim();
    if (w == null || w.isEmpty) return null;
    return sessionKey(w);
  }

  final wire = wireSessionId?.trim();
  final wireBucket = (wire != null && wire.isNotEmpty) ? sessionKey(wire) : null;

  if (waiting.length == 1) {
    final only = waiting.first;
    final assigned = dispatchBucketByLocalMessageId[only.localMessageId];
    if (assigned != null && assigned.isNotEmpty) {
      if (wireBucket != null &&
          wireBucket != assigned &&
          !_draftBucket(assigned)) {
        return assigned;
      }
      return assigned;
    }
    return only.bucketKey;
  }

  if (wireBucket != null) {
    for (final w in waiting) {
      final assigned = dispatchBucketByLocalMessageId[w.localMessageId];
      if (assigned == wireBucket) return wireBucket;
    }
  }

  final sorted = List<WaitingDispatch>.from(waiting)
    ..sort(
      (a, b) => a.waitingSince.compareTo(b.waitingSince),
    );
  final oldest = sorted.first;
  final oldestAssigned = dispatchBucketByLocalMessageId[oldest.localMessageId];
  if (oldestAssigned != null && oldestAssigned.isNotEmpty) {
    return oldestAssigned;
  }
  return oldest.bucketKey;
}

/// Bucket birleştirme: yalnızca bu cevaba ait taslak kutu (asla «pending dolu» kör fallback).
String? pickSessionRenameSourceKey({
  required String targetBucketKey,
  required List<WaitingDispatch> waiting,
  required Map<String, String> dispatchBucketByLocalMessageId,
  required String? wireSessionId,
  required bool pendingHasChat,
}) {
  if (waiting.isNotEmpty) {
    final bucket = resolveInboundBucketKey(
      wireSessionId: wireSessionId,
      waiting: waiting,
      dispatchBucketByLocalMessageId: dispatchBucketByLocalMessageId,
    );
    if (bucket != null && _draftBucket(bucket)) {
      return bucket;
    }
    return null;
  }
  return null;
}

bool _draftBucket(String key) =>
    key.startsWith('loc-') || key == kPendingSessionKey;
