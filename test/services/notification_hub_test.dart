import 'package:alper_cursor_remote/services/notification_hub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('oturum bildirim id kararlı', () {
    const sid = 'loc-123';
    expect(
      NotificationHub.notificationIdForSession(sid),
      NotificationHub.notificationIdForSession(sid),
    );
  });
}
