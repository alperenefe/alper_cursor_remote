import '../../models/session_summary.dart';
import '../../services/chat_history_applier.dart';
import 'session_store.dart';

/// Oturum listesi — her PC uuid ayrı satır; `resolve()` ile birleştirme yok.
List<SessionSummary> buildSessionSummaries({
  required SessionStore store,
  required Map<String, String> sessionNames,
  required List<Map<String, dynamic>> historyEntries,
  required Iterable<String> registryKeys,
  String? cursorSessionId,
  required SessionSummary? Function(String localId) summaryFromLocalChat,
}) {
  final byId = <String, SessionSummary>{};

  SessionSummary? summaryForLocal(String sid) {
    final fromChat = summaryFromLocalChat(sid);
    final custom = sessionNames[sid]?.trim();
    if (fromChat != null) {
      return SessionSummary(
        sessionId: sid,
        preview: fromChat.preview,
        lastTimestamp: fromChat.lastTimestamp,
        entryCount: fromChat.entryCount,
        customName: custom ?? fromChat.customName,
      );
    }
    // İsim verilmiş ama mesaj yok → sahte önizleme/boş satır oluşturma (çift liste).
    if (store.of(sid).isDraft) {
      return SessionSummary(
        sessionId: sid,
        preview: '(yeni oturum)',
        entryCount: 0,
        customName: custom,
      );
    }
    return null;
  }

  void put(String id, SessionSummary s) {
    byId[id] = s;
  }

  for (final key in registryKeys) {
    final sum = summaryForLocal(key);
    if (sum != null) put(key, sum);
  }

  for (final pc in extractSessionSummaries(historyEntries)) {
    final linked = store.findByPcSessionId(pc.sessionId)?.localId;
    final listId = linked ?? pc.sessionId;
    // Bağlı loc-* zaten listede — ham PC uuid ile ikinci satır açma.
    if (linked != null && linked != pc.sessionId) {
      final existing = byId[linked];
      if (existing != null) continue;
    }
    final custom =
        sessionNames[listId]?.trim() ?? sessionNames[pc.sessionId]?.trim();
    final existing = byId[listId];
    if (existing == null) {
      put(
        listId,
        SessionSummary(
          sessionId: listId,
          preview: pc.preview,
          lastTimestamp: pc.lastTimestamp,
          entryCount: pc.entryCount,
          customName: custom,
        ),
      );
    } else if (pc.lastTimestamp != null &&
        _isNewer(pc.lastTimestamp, existing.lastTimestamp)) {
      put(
        listId,
        SessionSummary(
          sessionId: listId,
          preview: pc.preview,
          lastTimestamp: pc.lastTimestamp,
          entryCount: pc.entryCount > existing.entryCount
              ? pc.entryCount
              : existing.entryCount,
          customName: custom ?? existing.customName,
        ),
      );
    }
  }

  final active = cursorSessionId?.trim();
  if (active != null && active.isNotEmpty) {
    final sum = summaryForLocal(active);
    if (sum != null) put(active, sum);
  }

  _dropDuplicatePcRows(byId, store);

  final list = byId.values.toList();
  list.sort((a, b) {
    if (active != null && active.isNotEmpty) {
      if (a.sessionId == active && b.sessionId != active) return -1;
      if (b.sessionId == active && a.sessionId != active) return 1;
    }
    final ta = a.lastTimestamp ?? '';
    final tb = b.lastTimestamp ?? '';
    return tb.compareTo(ta);
  });
  return list;
}

/// Aynı PC oturumu hem `loc-*` hem ham uuid ile iki kez listelenmesin.
void _dropDuplicatePcRows(
  Map<String, SessionSummary> byId,
  SessionStore store,
) {
  final remove = <String>[];
  for (final id in byId.keys) {
    if (id.startsWith('loc-')) continue;
    final linked = store.findByPcSessionId(id);
    if (linked != null && byId.containsKey(linked.localId)) {
      remove.add(id);
    }
  }
  for (final id in remove) {
    byId.remove(id);
  }
}

bool _isNewer(String? candidate, String? existing) {
  if (existing == null || existing.isEmpty) return true;
  if (candidate == null || candidate.isEmpty) return false;
  final dc = DateTime.tryParse(candidate);
  final de = DateTime.tryParse(existing);
  if (dc == null || de == null) return candidate.compareTo(existing) > 0;
  return dc.isAfter(de);
}

/// Liste satırı şu an seçili oturum mu (loc veya aynı PC uuid).
bool isListSessionActive(
  SessionStore store,
  String listSessionId,
  String? cursorSessionId,
) {
  final active = cursorSessionId?.trim() ?? '';
  final list = listSessionId.trim();
  if (list.isEmpty || active.isEmpty) return false;
  if (list == active) return true;

  String? pcFor(String id) {
    if (!id.startsWith('loc-')) return id;
    final r = store.of(id);
    return r.hasPcSession ? r.pcSessionId!.trim() : null;
  }

  final activePc = pcFor(active);
  final listPc = pcFor(list);
  if (activePc != null && (activePc == list || activePc == listPc)) {
    return true;
  }
  if (listPc != null && listPc == active) return true;
  if (activePc != null &&
      listPc != null &&
      activePc.isNotEmpty &&
      activePc == listPc) {
    return true;
  }
  return false;
}
