import '../models/chat_message.dart';
import 'ws_logger.dart';

/// PC geçmişi → UI balon izleme (release logcat).
class HistoryTraceLog {
  static String sidShort(String? s) {
    if (s == null || s.isEmpty) return 'pending';
    return s.length >= 8 ? s.substring(0, 8) : s;
  }

  static String preview(String? text, [int max = 44]) {
    final t = (text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return '—';
    return t.length > max ? '${t.substring(0, max)}…' : t;
  }

  static void loadChatHistory({
    required String? sessionId,
    required int limit,
    required bool replace,
    required bool force,
    required String source,
  }) {
    WsLogger.history(
      'loadChatHistory sid=${sidShort(sessionId)} limit=$limit '
      'replace=$replace force=$force kaynak=$source',
    );
  }

  static void pcRawEntries(String? sessionId, List<Map<String, dynamic>> entries) {
    WsLogger.history('PC ham sid=${sidShort(sessionId)} tur=${entries.length}');
    for (var i = 0; i < entries.length; i++) {
      logPcTurn('  pc[$i]', entries[i]);
    }
  }

  static void normalizeDrop(String reason, Map<String, dynamic> entry) {
    WsLogger.history('normalize ATLA ($reason) ${turnLine(entry)}');
  }

  static void afterNormalize(String? sessionId, List<Map<String, dynamic>> entries) {
    WsLogger.history(
      'normalize sonrası sid=${sidShort(sessionId)} tur=${entries.length}',
    );
    for (var i = 0; i < entries.length; i++) {
      logPcTurn('  norm[$i]', entries[i]);
    }
  }

  static void applyHistory({
    required String? sessionId,
    required bool replace,
    required int rawTurns,
    required int importedBubbles,
    required int protectedCount,
    required int listSizeAfter,
    required String? bottomRole,
    required String? bottomPreview,
    required String? bottomAt,
  }) {
    WsLogger.history(
      'applyHistory sid=${sidShort(sessionId)} replace=$replace '
      'hamTur=$rawTurns balon=$importedBubbles korunan=$protectedCount '
      'liste=$listSizeAfter',
    );
    WsLogger.history(
      'applyHistory EN ALT: $bottomRole @ $bottomAt «$bottomPreview»',
    );
  }

  /// Sohbet ekranında gerçekten render edilen sıra (displayMessages).
  static void uiRenderList(String? sessionId, List<ChatMessage> messages) {
    WsLogger.history(
      'RENDER sid=${sidShort(sessionId)} adet=${messages.length}',
    );
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final local = m.at.toLocal();
      final clock =
          '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}:'
          '${local.second.toString().padLeft(2, '0')}';
      final role = m.role == ChatRole.user ? 'USER' : 'ASST';
      WsLogger.history(
        '  render[$i] $clock $role id=${m.id} «${preview(m.text, 36)}»',
      );
    }
    if (messages.isNotEmpty) {
      final last = messages.last;
      WsLogger.history(
        'RENDER EN ALT: ${last.role.name} id=${last.id} «${preview(last.text, 40)}»',
      );
    }
  }

  static void uiBubbleList(String? sessionId, List<ChatMessage> messages) {
    WsLogger.history(
      'depo (ham liste) sid=${sidShort(sessionId)} adet=${messages.length}',
    );
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final local = m.at.toLocal();
      final clock =
          '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}:'
          '${local.second.toString().padLeft(2, '0')}';
      final role = m.role == ChatRole.user ? 'USER' : 'ASST';
      WsLogger.history(
        '  ui[$i] $clock $role id=${m.id} «${preview(m.text, 36)}»',
      );
    }
  }

  static void selectSession(String sessionId, String label) {
    WsLogger.history(
      'selectSession sid=${sidShort(sessionId)} etiket=$label',
    );
  }

  static void sendPrompt({
    required String? wireSessionId,
    required String? cursorSessionId,
    required String localMsgId,
    required String textPreview,
  }) {
    WsLogger.history(
      'sendPrompt wire=${sidShort(wireSessionId)} aktif=${sidShort(cursorSessionId)} '
      'localId=$localMsgId «$textPreview»',
    );
  }

  static void logPcTurn(String prefix, Map<String, dynamic> e) {
    final ts = e['timestamp'] as String? ?? '';
    final um = (e['userMessage'] as String? ?? '').trim();
    final ar = (e['assistantResponse'] as String? ?? '').trim();
    WsLogger.history(
      '$prefix ts=$ts user=«${preview(um, 32)}» asst=${ar.isEmpty ? "BOŞ" : "${ar.length}chr"}',
    );
  }

  static String turnLine(Map<String, dynamic> e) {
    final ts = e['timestamp'] as String? ?? '?';
    final um = preview(e['userMessage'] as String?, 28);
    final ar = (e['assistantResponse'] as String? ?? '').trim();
    return 'ts=$ts user=«$um» asst=${ar.isEmpty ? "BOŞ" : "${ar.length}chr"}';
  }
}
