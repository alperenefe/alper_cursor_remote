/// Oturum listesi rozeti: `2:35` veya `12 sn`.
String formatWaitingElapsedShort(
  DateTime waitingSince, {
  DateTime? now,
}) {
  final elapsed = (now ?? DateTime.now()).difference(waitingSince);
  final em = elapsed.inMinutes;
  final es = elapsed.inSeconds % 60;
  if (em > 0) return '$em:${es.toString().padLeft(2, '0')}';
  return '${elapsed.inSeconds} sn';
}

/// Agent beklerken alt şerit metni (saf formatlama).
String formatWaitingStatusText({
  required DateTime waitingSince,
  required DateTime? lastPcActivityAt,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final elapsed = clock.difference(waitingSince);
  final em = elapsed.inMinutes;
  final es = elapsed.inSeconds % 60;
  final elapsedStr =
      em > 0 ? '$em:${es.toString().padLeft(2, '0')}' : '${elapsed.inSeconds} sn';
  var text = 'Agent çalışıyor · $elapsedStr';
  if (lastPcActivityAt != null) {
    final gap = clock.difference(lastPcActivityAt).inSeconds;
    if (gap <= 15) {
      text += ' · PC aktif';
    } else {
      text += ' · Son sinyal $gap sn önce (uzun iş olabilir)';
    }
  }
  return text;
}
