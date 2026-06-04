/// Oturum listesinde / başlıkta gösterilen canlı durum.
enum SessionLiveBadgeKind {
  working,
  queued,
  unread,
}

class SessionLiveBadge {
  const SessionLiveBadge({
    required this.label,
    required this.kind,
    this.onPc = false,
  });

  final String label;
  final SessionLiveBadgeKind kind;
  /// PC agent şu an bu oturum için çalışıyor.
  final bool onPc;
}
