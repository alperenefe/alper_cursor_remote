import '../../models/chat_message.dart';
import '../../models/session_live_state.dart';

/// Tek mobil oturum — kendi mesaj listesi, kendi canlı durum.
class SessionRecord {
  SessionRecord({
    required this.localId,
    this.displayName,
    this.pcSessionId,
    this.isDraft = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Telefonda sabit kimlik (asla değişmez).
  final String localId;

  /// PC/Cursor `sessionId` (cevap gelince atanır).
  String? pcSessionId;

  String? displayName;

  /// «Yeni agent oturumu» — boş kutu başka oturuma çekilmez; ilk gönderimde PC yeni CLI.
  bool isDraft;

  final DateTime createdAt;

  final List<ChatMessage> messages = [];

  final SessionLiveState live = SessionLiveState();

  bool get hasPcSession =>
      pcSessionId != null && pcSessionId!.trim().isNotEmpty;

  /// PC'ye gönderilecek session (yoksa null → yeni CLI oturumu).
  String? get wireSessionIdForResume =>
      hasPcSession ? pcSessionId!.trim() : null;

  String displayLabel() {
    final n = displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    if (hasPcSession && pcSessionId!.length > 12) {
      return '${pcSessionId!.substring(0, 12)}…';
    }
    return 'Yeni oturum';
  }
}
