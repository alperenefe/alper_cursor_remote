import '../session_isolation.dart';
import 'session_store.dart';

/// PC uuid ↔ `loc-*` eşlemesi — tek giriş noktası (yönlendirme / taslak / liste).
class SessionResolver {
  SessionResolver(this._store);

  final SessionStore _store;

  /// Oturum listesi, seçim, restore, geçmiş merge hedefi.
  String resolve(
    String sessionRef, {
    List<Map<String, dynamic>> historyEntries = const [],
  }) {
    final ref = sessionRef.trim();
    if (ref.isEmpty) return _store.activeOrCreate().localId;
    if (ref.startsWith('loc-')) {
      return _resolveLocal(ref, historyEntries);
    }
    return _resolvePc(ref, historyEntries);
  }

  String _resolveLocal(String loc, List<Map<String, dynamic>> history) {
    final record = _store.of(loc);
    if (record.isDraft) {
      _store.setActive(loc);
      return loc;
    }
    if (_store.chatBubbleCount(record) == 0) {
      final better = _redirectEmptyBucket(loc, history);
      if (better != null) return better;
    }
    _store.setActive(loc);
    return loc;
  }

  String _resolvePc(String pc, List<Map<String, dynamic>> history) {
    final linked = _store.findByPcSessionId(pc);
    if (linked != null && _store.chatBubbleCount(linked) > 0) {
      _store.setActive(linked.localId);
      return linked.localId;
    }
    if (linked != null && _store.chatBubbleCount(linked) == 0) {
      linked.pcSessionId = null;
    }

    final hint = _firstUserLine(history, pc);
    final byHint = _store.findLocalIdByUserMessageHint(hint);
    if (byHint != null) {
      _store.linkPcSession(byHint, pc);
      _store.setActive(byHint);
      return byHint;
    }

    var orphan = _store.findLocalIdWithChatForPc(userHint: hint);
    orphan ??= _store.findLocalIdMatchingPcHistory(pc, history);
    if (orphan != null) {
      _store.linkPcSession(orphan, pc);
      _store.setActive(orphan);
      return orphan;
    }

    final loc = _store.createSession();
    _store.linkPcSession(loc, pc);
    return loc;
  }

  /// Boş `loc-*` (PC uuid çalması) → mesajlı doğru kutu.
  String? _redirectEmptyBucket(
    String emptyLoc,
    List<Map<String, dynamic>> history,
  ) {
    final record = _store.of(emptyLoc);
    final pc = record.pcSessionId?.trim();
    String? hint;
    if (pc != null && pc.isNotEmpty) {
      hint = _firstUserLine(history, pc);
      final byHint = _store.findLocalIdByUserMessageHint(hint);
      if (byHint != null && byHint != emptyLoc) {
        _store.linkPcSession(byHint, pc);
        _store.setActive(byHint);
        return byHint;
      }
      final owned = _store.findByPcSessionId(pc);
      if (owned != null &&
          owned.localId != emptyLoc &&
          _store.chatBubbleCount(owned) > 0) {
        _store.setActive(owned.localId);
        return owned.localId;
      }
      record.pcSessionId = null;
    } else if (history.isNotEmpty) {
      for (final row in history) {
        final pcRow = (row['sessionId'] as String? ?? '').trim();
        if (pcRow.isEmpty) continue;
        final owned = _store.findByPcSessionId(pcRow);
        if (owned != null &&
            owned.localId != emptyLoc &&
            _store.chatBubbleCount(owned) > 0) {
          _store.setActive(owned.localId);
          return owned.localId;
        }
      }
    }

    var target = _store.findLocalIdWithChatForPc(userHint: hint);
    if (target == null && pc != null && pc.isNotEmpty) {
      target = _store.findLocalIdMatchingPcHistory(pc, history);
    }
    if (target != null && target != emptyLoc) {
      if (pc != null && pc.isNotEmpty) {
        _store.linkPcSession(target, pc);
      }
      _store.setActive(target);
      return target;
    }
    return null;
  }

  static String? _firstUserLine(
    List<Map<String, dynamic>> entries,
    String pcSessionId,
  ) {
    final rows = strictFilterEntriesBySession(entries, pcSessionId);
    if (rows.isEmpty) return null;
    final text = (rows.first['userMessage'] as String? ?? '').trim();
    return text.isEmpty ? null : text;
  }
}
