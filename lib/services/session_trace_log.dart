import '../models/chat_message.dart';
import 'ws_logger.dart';

/// Oturum geçişi — logcat: adb logcat | findstr SESSION
class SessionTraceLog {
  static String sid(String? s) {
    if (s == null || s.isEmpty) return '—';
    return s.length >= 8 ? s.substring(0, 8) : s;
  }

  static void _log(String msg) => WsLogger.session('SESSION $msg');

  static void listTap({
    required String sessionId,
    required String title,
    required bool goToTabOk,
  }) {
    _log(
      'listeTık sid=${sid(sessionId)} «$title» goToTab=${goToTabOk ? "ok" : "YOK"}',
    );
  }

  static void select({
    required String? fromSid,
    required String toSid,
    required String label,
    required int cacheTurns,
    required bool pcRefresh,
  }) {
    _log(
      'select ${sid(fromSid)}→${sid(toSid)} «$label» '
      'önbellekTur=$cacheTurns pcYenile=$pcRefresh',
    );
  }

  static void loadHistory({
    required String? sessionId,
    required bool replace,
    required bool force,
    required bool silent,
    required String phase,
    int? ms,
    int? turns,
  }) {
    final dur = ms != null ? ' ${ms}ms' : '';
    final tur = turns != null ? ' tur=$turns' : '';
    _log(
      'geçmiş $phase sid=${sid(sessionId)} replace=$replace '
      'force=$force silent=$silent$dur$tur',
    );
  }

  static void renderBottom({
    required String? sessionId,
    required int count,
    required ChatRole? bottomRole,
    required String? bottomId,
  }) {
    _log(
      'ekran sid=${sid(sessionId)} balon=$count '
      'enAlt=${bottomRole?.name ?? "?"} id=${bottomId ?? "—"}',
    );
  }

  static void isolationPurge(String? sessionId, int removed) {
    _log('izolasyon sid=${sid(sessionId)} yabancıBalon=$removed');
  }

  static void draftFrozen({
    required String freezeKey,
    required bool hadChat,
    required bool waiting,
  }) {
    _log(
      'taslakDonduruldu key=${sid(freezeKey)} sohbet=$hadChat bekliyor=$waiting',
    );
  }

  static void adoptRejected({
    required String? busySid,
    required String wireSid,
    required String? uiSid,
  }) {
    _log(
      'adoptReddedildi meşgul=${sid(busySid)} wire=${sid(wireSid)} '
      'ui=${sid(uiSid)} (bucket taşınmadı)',
    );
  }

  static void sendPrompt({
    required String? wireSid,
    required String? uiSid,
    required String localId,
    required String preview,
  }) {
    _log(
      'gönder wire=${sid(wireSid)} ui=${sid(uiSid)} id=$localId «$preview»',
    );
  }

  static void appliedPcTurns({
    required String? targetSid,
    required String label,
    required List<Map<String, dynamic>> turns,
  }) {
    _log('pcTur sid=${sid(targetSid)} «$label» adet=${turns.length}');
    for (var i = 0; i < turns.length; i++) {
      final um = _preview(turns[i]['userMessage'] as String?, 40);
      final ar = (turns[i]['assistantResponse'] as String? ?? '').trim();
      final fileSid = (turns[i]['sessionId'] as String? ?? '').trim();
      final sidOk = fileSid.isEmpty || fileSid == targetSid;
      final flag = !sidOk ? ' YANLIŞ-DOSYA-SID' : _crossLabelHint(targetSid, um);
      _log('  [$i] user=«$um» asst=${ar.isEmpty ? "BOŞ" : "${ar.length}ch"}$flag');
    }
  }

  static void inbound({
    required String kind,
    required String? wireSid,
    required String? activeSid,
    required String? resolvedSid,
    required String preview,
  }) {
    final cross = wireSid != null &&
        activeSid != null &&
        wireSid.trim().isNotEmpty &&
        activeSid.trim().isNotEmpty &&
        wireSid.trim() != activeSid.trim();
    _log(
      'gelen $kind wire=${sid(wireSid)} aktif=${sid(activeSid)} '
      'çözüm=${sid(resolvedSid)}${cross ? " ÇAPRAZ" : ""} «${_preview(preview, 36)}»',
    );
  }

  static String _preview(String? text, int max) {
    final t = (text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return '—';
    return t.length > max ? '${t.substring(0, max)}…' : t;
  }

  static String _crossLabelHint(String? targetSid, String userText) {
    final t = userText.toLowerCase();
    if (t.isEmpty) return '';
    const music = '0c988c83-81d3-4632-ba1f-6ffb6b9dd838';
    const plan = 'a0ba8aa5-e56f-4d16-8536-d49818f446f4';
    const remote = 'd5241cc5-930e-4a00-b32b-a9d3219478fa';
    final sid = targetSid ?? '';
    bool mentions(String k) => t.contains(k);
    if (sid.startsWith(music.substring(0, 8)) || sid == music) {
      if (mentions('remote') && !mentions('müzik') && !mentions('muzik')) {
        return ' UYARI:remote-metni-müzik-oturumunda';
      }
      if (mentions('planlay') || mentions('planner')) {
        return ' UYARI:plan-metni-müzik-oturumunda';
      }
    }
    if (sid.startsWith(plan.substring(0, 8)) || sid == plan) {
      if (mentions('remote') && !mentions('plan')) {
        return ' UYARI:remote-metni-plan-oturumunda';
      }
      if ((mentions('müzik') || mentions('muzik')) && !mentions('plan')) {
        return ' UYARI:müzik-metni-plan-oturumunda';
      }
    }
    if (sid.startsWith(remote.substring(0, 8)) || sid == remote) {
      if ((mentions('müzik') || mentions('muzik')) && !mentions('remote')) {
        return ' UYARI:müzik-metni-remote-oturumunda';
      }
      if (mentions('planlay') && !mentions('remote')) {
        return ' UYARI:plan-metni-remote-oturumunda';
      }
    }
    return '';
  }
}
