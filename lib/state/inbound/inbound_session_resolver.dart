import '../../models/session_live_state.dart';
import '../session_registry.dart';

/// WS mesajı hangi oturuma ait?
///
/// [allowActiveUiFallback] false iken asistan cevabı açık sekme oturumuna düşmez
/// (yanlış balon / «planlayıcı mesajı remote’da» karışıklığı).
String resolveInboundSessionId({
  required Map<String, dynamic>? map,
  required String? pcBusySessionKey,
  required Iterable<MapEntry<String, SessionLiveState>> liveEntries,
  required String? cursorSessionId,
  bool allowActiveUiFallback = true,
}) {
  final raw = map?['sessionId'] as String?;
  if (raw != null && raw.trim().isNotEmpty) return raw.trim();
  if (pcBusySessionKey != null) return pcBusySessionKey;
  for (final e in liveEntries) {
    if (e.value.inFlight != null) return e.key;
  }
  for (final e in liveEntries) {
    if (e.value.waitingResponse) return e.key;
  }
  if (allowActiveUiFallback) {
    final c = cursorSessionId?.trim();
    if (c != null && c.isNotEmpty) return c;
  }
  final busy = pcBusySessionKey?.trim();
  if (busy != null && busy.isNotEmpty) return busy;
  return '';
}
