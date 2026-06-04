import '../../models/chat_message.dart';
import '../chat/chat_message_match.dart';
import '../session_isolation.dart';
import 'session_resolver.dart';
import 'session_store.dart';

export 'session_resolver.dart';

/// PC geçmiş filtresi (`CHAT_HISTORY.json` sessionId alanı).
String? historyFilterForLocal(SessionStore store, String sessionId) {
  final id = sessionId.trim();
  if (id.isEmpty) return null;
  if (id.startsWith('loc-')) {
    final r = store.of(id);
    if (r.hasPcSession) return r.pcSessionId!.trim();
    return null;
  }
  return id;
}

String resolveSelectionLocalId(
  SessionStore store,
  String sessionRef, {
  List<Map<String, dynamic>> historyEntries = const [],
}) =>
    SessionResolver(store).resolve(
      sessionRef,
      historyEntries: historyEntries,
    );

String? wireSessionIdForSend(
  SessionStore store,
  String? localId, {
  required bool newSession,
}) {
  if (newSession) return null;
  final id = localId?.trim();
  if (id == null || id.isEmpty) return null;
  final r = store.of(id);
  return r.hasPcSession ? r.pcSessionId!.trim() : null;
}

String? resolveRestoredLocalId(
  SessionStore store,
  String? saved, {
  List<Map<String, dynamic>> historyEntries = const [],
}) {
  final s = saved?.trim();
  if (s == null || s.isEmpty) return null;
  if (s.startsWith('loc-') && !store.contains(s)) return null;
  return SessionResolver(store).resolve(
    s,
    historyEntries: historyEntries,
  );
}

/// PC tek `sessionId` altında birden fazla mobil oturum olunca yalnızca bu kutunun
/// kullanıcı mesajlarıyla eşleşen turları al (çapraz sızıntı / boşaltma önlenir).
List<Map<String, dynamic>> filterPcHistoryForLocalBucket(
  SessionStore store,
  String localId,
  List<Map<String, dynamic>> entries,
) {
  final localUsers = store
      .of(localId)
      .messages
      .where((m) => m.role == ChatRole.user)
      .map((m) => m.text)
      .toList();
  if (localUsers.isEmpty) return const [];

  final pc = historyFilterForLocal(store, localId);
  final scoped = pc != null && pc.isNotEmpty
      ? strictFilterEntriesBySession(entries, pc)
      : entries;

  return scoped.where((e) {
    final um = (e['userMessage'] as String? ?? '').trim();
    if (um.isEmpty) return false;
    return localUsers.any((t) => userMessagesLikelySame(t, um));
  }).toList();
}
