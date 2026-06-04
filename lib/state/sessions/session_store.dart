import '../../models/chat_message.dart';
import '../../models/local_session_snapshot.dart';
import '../../models/queued_prompt.dart';
import '../../models/session_live_state.dart';
import '../chat/chat_message_match.dart';
import '../inbound/inbound_bucket_resolver.dart';
import 'session_record.dart';

/// Oturumlar: her biri ayrı liste — pending/local-* yok.
class SessionStore {
  final Map<String, SessionRecord> _byLocalId = {};
  String? _activeLocalId;

  Iterable<String> get localIds => _byLocalId.keys;

  Iterable<MapEntry<String, SessionLiveState>> get liveEntries =>
      _byLocalId.entries.map((e) => MapEntry(e.key, e.value.live));

  String? get activeLocalId => _activeLocalId;

  bool contains(String localId) => _byLocalId.containsKey(localId);

  /// Yeni oturum oluştur ve aktif yap.
  String createSession({String? displayName, bool draft = false}) {
    final id = _newLocalId();
    _byLocalId[id] = SessionRecord(
      localId: id,
      displayName: displayName?.trim().isEmpty == true
          ? null
          : displayName?.trim(),
      isDraft: draft,
    );
    _activeLocalId = id;
    return id;
  }

  String beginDraftSession() => createSession(draft: true);

  String _newLocalId() => 'loc-${DateTime.now().microsecondsSinceEpoch}';

  SessionRecord activeOrCreate() {
    if (_activeLocalId != null && _byLocalId.containsKey(_activeLocalId!)) {
      return _byLocalId[_activeLocalId!]!;
    }
    final id = createSession();
    return _byLocalId[id]!;
  }

  SessionRecord of(String? localId) {
    final key = localId?.trim();
    if (key != null && key.isNotEmpty) {
      return _byLocalId.putIfAbsent(
        key,
        () => SessionRecord(localId: key),
      );
    }
    return activeOrCreate();
  }

  void setActive(String? localId) {
    final key = localId?.trim();
    if (key != null && key.isNotEmpty && _byLocalId.containsKey(key)) {
      _activeLocalId = key;
    }
  }

  void remove(String localId) {
    _byLocalId.remove(localId);
    if (_activeLocalId == localId) {
      _activeLocalId =
          _byLocalId.keys.isEmpty ? null : _byLocalId.keys.last;
    }
  }

  void clearAll() {
    _byLocalId.clear();
    _activeLocalId = null;
  }

  void setDisplayName(String localId, String? name) {
    final r = _byLocalId[localId];
    if (r == null) return;
    final trimmed = name?.trim();
    r.displayName =
        trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  int chatBubbleCount(SessionRecord r) => _chatBubbleCount(r);

  int _chatBubbleCount(SessionRecord r) =>
      r.messages
          .where(
            (m) =>
                m.role == ChatRole.user ||
                m.role == ChatRole.assistant,
          )
          .length;

  /// Aynı PC uuid birden fazla `loc-*`'a bağlanmasın (boş kutu seçilmesin).
  void linkPcSession(String localId, String pcSessionId) {
    final r = of(localId);
    final pc = pcSessionId.trim();
    if (pc.isEmpty) return;
    for (final e in _byLocalId.entries) {
      if (e.key != localId && e.value.pcSessionId == pc) {
        e.value.pcSessionId = null;
      }
    }
    r.pcSessionId = pc;
    r.isDraft = false;
  }

  SessionRecord? findByPcSessionId(String pcSessionId) {
    final pc = pcSessionId.trim();
    if (pc.isEmpty) return null;
    SessionRecord? best;
    var bestCount = -1;
    for (final r in _byLocalId.values) {
      if (r.pcSessionId != pc) continue;
      final n = _chatBubbleCount(r);
      if (n > bestCount) {
        bestCount = n;
        best = r;
      }
    }
    return best;
  }

  String? findLocalIdByUserMessageHint(String? userMessageHint) {
    final hint = userMessageHint?.trim();
    if (hint == null || hint.isEmpty) return null;
    String? bestKey;
    var bestCount = -1;
    for (final e in _byLocalId.entries) {
      final match = e.value.messages.any(
        (m) =>
            m.role == ChatRole.user &&
            userMessagesLikelySame(m.text, hint),
      );
      if (!match) continue;
      final n = _chatBubbleCount(e.value);
      if (n > bestCount) {
        bestCount = n;
        bestKey = e.key;
      }
    }
    return bestKey;
  }

  /// Bağlantısız sohbet kutuları; [userHint] ile müzik/yürük ayrılır.
  String? findLocalIdWithChatForPc({String? userHint}) {
    final unlinked = <String>[];
    for (final e in _byLocalId.entries) {
      if (e.value.hasPcSession) continue;
      if (_chatBubbleCount(e.value) > 0) unlinked.add(e.key);
    }
    if (unlinked.isEmpty) return null;
    final hint = userHint?.trim();
    if (hint != null && hint.isNotEmpty) {
      final match = findLocalIdByUserMessageHint(hint);
      if (match != null && unlinked.contains(match)) return match;
    }
    final chatBuckets =
        _byLocalId.values.where((r) => _chatBubbleCount(r) > 0).length;
    if (unlinked.length == 1 && chatBuckets <= 1) return unlinked.first;
    return null;
  }

  /// PC geçmiş satırlarındaki kullanıcı metniyle eşleşen yerel kutu.
  String? findLocalIdMatchingPcHistory(
    String pcSessionId,
    List<Map<String, dynamic>> historyEntries,
  ) {
    final pc = pcSessionId.trim();
    if (pc.isEmpty) return null;
    for (final e in historyEntries) {
      if ((e['sessionId'] as String? ?? '').trim() != pc) continue;
      final hint = (e['userMessage'] as String? ?? '').trim();
      if (hint.isEmpty) continue;
      final id = findLocalIdByUserMessageHint(hint);
      if (id != null) return id;
    }
    return null;
  }

  List<WaitingDispatch> waitingDispatches() {
    final out = <WaitingDispatch>[];
    for (final e in _byLocalId.entries) {
      final inf = e.value.live.inFlight;
      if (!e.value.live.waitingResponse || inf == null) continue;
      out.add(
        WaitingDispatch(
          bucketKey: e.key,
          localMessageId: inf.localMessageId,
          waitingSince: e.value.live.waitingSince ?? DateTime.now(),
        ),
      );
    }
    return out;
  }

  /// Gelen WS cevabı hangi oturuma? (wire tek başına yetmez)
  String resolveInboundLocalId({
    required String? wirePcSessionId,
    required Map<String, String> dispatchBucketByMessageId,
    String? pcBusyLocalId,
  }) {
    final waiting = waitingDispatches();
    final wire = wirePcSessionId?.trim();

    if (waiting.isNotEmpty) {
      final bucket = resolveInboundBucketKey(
        wireSessionId: wire,
        waiting: waiting,
        dispatchBucketByLocalMessageId: dispatchBucketByMessageId,
      );
      if (bucket != null && _byLocalId.containsKey(bucket)) {
        return bucket;
      }
    }

    if (wire != null && wire.isNotEmpty) {
      final byPc = findByPcSessionId(wire);
      if (byPc != null) return byPc.localId;
      if (_byLocalId.containsKey(wire)) return wire;
    }

    if (pcBusyLocalId != null && _byLocalId.containsKey(pcBusyLocalId)) {
      return pcBusyLocalId;
    }

    return _activeLocalId ?? of(null).localId;
  }

  void setMessages(String localId, List<ChatMessage> list) {
    final r = of(localId);
    r.messages
      ..clear()
      ..addAll(list);
  }

  void clearMessages(String localId) {
    _byLocalId.remove(localId);
    if (_activeLocalId == localId) {
      _activeLocalId =
          _byLocalId.keys.isEmpty ? null : _byLocalId.keys.last;
    }
  }

  int indexOfMessage(String localId, String messageId) {
    return of(localId).messages.indexWhere((m) => m.id == messageId);
  }

  LocalSessionSnapshot exportSnapshot({
    String? activeSessionId,
    Map<String, String> sessionNames = const {},
  }) {
    final sessions = <PersistedSessionRecord>[];
    for (final e in _byLocalId.entries) {
      final r = e.value;
      if (_chatBubbleCount(r) == 0 && !r.hasPcSession && !r.isDraft) {
        continue;
      }
      sessions.add(
        PersistedSessionRecord(
          localId: e.key,
          pcSessionId: r.pcSessionId,
          isDraft: r.isDraft,
          createdAt: r.createdAt,
          messages: List<ChatMessage>.from(r.messages),
        ),
      );
    }
    return LocalSessionSnapshot(
      activeSessionId: activeSessionId ?? _activeLocalId,
      sessionNames: Map<String, String>.from(sessionNames),
      sessions: sessions,
    );
  }

  void importSnapshot(LocalSessionSnapshot snapshot) {
    _byLocalId.clear();
    for (final s in snapshot.sessions) {
      final id = s.localId.trim();
      if (id.isEmpty) continue;
      final r = SessionRecord(
        localId: id,
        pcSessionId: s.pcSessionId?.trim().isEmpty == true
            ? null
            : s.pcSessionId?.trim(),
        isDraft: s.isDraft,
        createdAt: s.createdAt,
        displayName: snapshot.sessionNames[id],
      );
      r.messages.addAll(s.messages);
      _byLocalId[id] = r;
    }
    final active = snapshot.activeSessionId?.trim();
    if (active != null &&
        active.isNotEmpty &&
        _byLocalId.containsKey(active)) {
      _activeLocalId = active;
    } else if (_byLocalId.isNotEmpty) {
      _activeLocalId = _byLocalId.keys.last;
    } else {
      _activeLocalId = null;
    }
  }
}
