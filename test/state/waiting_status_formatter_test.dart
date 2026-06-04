import 'package:alper_cursor_remote/state/waiting/waiting_status_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PC aktif metni', () {
    final now = DateTime(2026, 5, 29, 12, 0, 10);
    final text = formatWaitingStatusText(
      waitingSince: now.subtract(const Duration(seconds: 30)),
      lastPcActivityAt: now.subtract(const Duration(seconds: 5)),
      now: now,
    );
    expect(text, contains('Agent çalışıyor'));
    expect(text, contains('PC aktif'));
  });

  test('uzun sessizlik metni', () {
    final now = DateTime(2026, 5, 29, 12, 0, 0);
    final text = formatWaitingStatusText(
      waitingSince: now.subtract(const Duration(minutes: 2)),
      lastPcActivityAt: now.subtract(const Duration(seconds: 45)),
      now: now,
    );
    expect(text, contains('Son sinyal 45 sn önce'));
  });
}
