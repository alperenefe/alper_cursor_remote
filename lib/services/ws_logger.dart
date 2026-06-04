import 'dart:developer' as developer;

/// WebSocket trafiğini adb logcat'te okunabilir yapar.
/// Filtre: adb logcat | findstr CursorUzaktan
class WsLogger {
  static const logName = 'CursorUzaktan';
  static const _chunkSize = 3500;

  static void traffic(String direction, String summary, String body) {
    final arrow = direction == 'out' ? 'GİDEN' : 'GELEN';
    _log('$arrow $summary (${body.length} bayt)');
    if (body.isEmpty) return;
    if (body.length <= _chunkSize) {
      _log(body);
      return;
    }
    for (var i = 0; i < body.length; i += _chunkSize) {
      final end = i + _chunkSize < body.length ? i + _chunkSize : body.length;
      _log('…parça ${i ~/ _chunkSize + 1}: ${body.substring(i, end)}');
    }
  }

  static void info(String message) => _log(message);

  /// Oturum / kuyruk durumu (logcat: adb logcat -s flutter | findstr CursorUzaktan).
  static void session(String message) => _log('OTURUM $message');

  /// Geçmiş senkron / balon (logcat: findstr HIST veya CursorUzaktan).
  static void history(String message) => _log('HIST $message');

  static void error(Object e, [StackTrace? st]) {
    _log('HATA: $e');
    if (st != null) _log(st.toString());
  }

  static void _log(String message) {
    developer.log(message, name: logName);
    // Release APK'da da logcat'e düşsün (kişisel debug).
    // ignore: avoid_print
    print('[$logName] $message');
  }
}
