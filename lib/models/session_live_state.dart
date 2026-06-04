import 'queued_prompt.dart';

/// Tek Cursor oturumunun canlı tur durumu (bekleme, kuyruk, okunmamış).
class SessionLiveState {
  bool waitingResponse = false;
  DateTime? waitingSince;
  String? awaitingReplyForUserId;
  String? pendingReplyForUserId;
  String? streamingMessageId;
  QueuedPrompt? inFlight;

  /// `insert_text` PC'ye gitti; bağlantı kopunca aynı turu kuyruğa alma.
  bool inFlightWireDispatched = false;

  final List<QueuedPrompt> queue = [];

  /// Aktif oturum dışındayken gelen tam cevaplar.
  int unreadReplies = 0;

  /// Bu oturumda agent çalışırken son WS/CLI sinyali.
  DateTime? lastPcActivityAt;

  /// Şerit genişletmede birikmiş cevap metni (tek paragraf akışı).
  String agentLiveStreamText = '';

  /// Son agent_progress satırı (ayrı durum; chunk'lara eklenmez).
  String agentLiveProgressLine = '';

  bool get hasQueuedPrompts => queue.isNotEmpty;

  bool get needsAttention =>
      unreadReplies > 0 || waitingResponse || hasQueuedPrompts;

  void clearWaiting() {
    waitingResponse = false;
    waitingSince = null;
    awaitingReplyForUserId = null;
    pendingReplyForUserId = null;
    streamingMessageId = null;
    inFlight = null;
    inFlightWireDispatched = false;
    lastPcActivityAt = null;
    agentLiveStreamText = '';
    agentLiveProgressLine = '';
  }
}
