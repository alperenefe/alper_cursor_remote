import '../models/chat_message.dart';
import '../models/session_live_state.dart';
import 'sessions/session_record.dart';
import 'sessions/session_store.dart';

export 'sessions/session_record.dart';
export 'sessions/session_store.dart';

/// Eski API uyumu — yeni kodda `loc-…` kullan.
const String kPendingSessionKey = '__pending__';

@Deprecated('Mobil oturumlar artık loc-… kimlik; null için SessionStore.activeOrCreate')
String sessionKey(String? sessionId) {
  final s = sessionId?.trim() ?? '';
  return s.isEmpty ? kPendingSessionKey : s;
}

/// [SessionStore] üzerinde eski isimler (kademeli geçiş).
class SessionRegistry {
  final SessionStore store = SessionStore();

  Iterable<String> get sessionKeys => store.localIds;

  Iterable<SessionLiveState> get liveStates =>
      store.liveEntries.map((e) => e.value);

  Iterable<MapEntry<String, SessionLiveState>> get liveEntries =>
      store.liveEntries;

  bool hasBucket(String key) =>
      key != kPendingSessionKey && store.contains(key);

  List<ChatMessage> messagesFor(String? sessionId) {
    if (sessionId == kPendingSessionKey ||
        sessionId == null ||
        sessionId.trim().isEmpty) {
      return store.activeOrCreate().messages;
    }
    return store.of(sessionId).messages;
  }

  SessionLiveState liveFor(String? sessionId) {
    if (sessionId == kPendingSessionKey ||
        sessionId == null ||
        sessionId.trim().isEmpty) {
      return store.activeOrCreate().live;
    }
    return store.of(sessionId).live;
  }

  void setMessages(String? sessionId, List<ChatMessage> list) {
    final id = _resolveId(sessionId);
    store.setMessages(id, list);
  }

  void clearMessages(String? sessionId) {
    final id = _resolveId(sessionId);
    store.clearMessages(id);
  }

  void clearAllConversation() => store.clearAll();

  /// Eski bucket taşıma — artık yalnızca PC sessionId bağlar, mesaj birleştirmez.
  void renameSessionBucket(String fromKey, String toKey) {
    if (fromKey == kPendingSessionKey || fromKey == toKey) return;
    if (!fromKey.startsWith('loc-')) return;
    final pc = toKey.startsWith('loc-') ? null : toKey.trim();
    if (pc != null && pc.isNotEmpty) {
      store.linkPcSession(fromKey, pc);
    }
  }

  int indexOfMessage(String sessionId, String messageId) =>
      store.indexOfMessage(_resolveId(sessionId), messageId);

  String _resolveId(String? sessionId) {
    if (sessionId == kPendingSessionKey ||
        sessionId == null ||
        sessionId.trim().isEmpty) {
      return store.activeOrCreate().localId;
    }
    return sessionId.trim();
  }
}
