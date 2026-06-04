import '../state/session_registry.dart';

/// PC agent CLI oturumu (sessionId) özeti.
class SessionSummary {
  const SessionSummary({
    required this.sessionId,
    required this.preview,
    this.lastTimestamp,
    this.entryCount = 0,
    this.customName,
  });

  final String sessionId;
  final String preview;
  final String? lastTimestamp;
  final int entryCount;
  /// Telefonda kayıtlı özel isim (PC'ye gitmez).
  final String? customName;

  String get shortId {
    if (sessionId.startsWith('loc-')) return 'Yeni oturum';
    return sessionId.length > 10
        ? '${sessionId.substring(0, 10)}…'
        : sessionId;
  }

  String get title {
    final n = customName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return shortId;
  }

  /// Henüz mesaj/PC kaydı olmayan yeni kutu (isim verilmemiş taslak).
  bool get isLocalDraft =>
      sessionId.startsWith('loc-') &&
      entryCount == 0 &&
      (preview.trim().isEmpty ||
          preview == '(yeni oturum)' ||
          preview == 'Yeni oturum');
}
