import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'chat_bubble_format.dart';
import 'notification_hub.dart';

/// Başka oturumda cevap gelince — tıklanınca o oturuma git.
class SessionReplyNotification {
  SessionReplyNotification._();

  static Future<void> show({
    required String sessionId,
    required String sessionName,
    required String preview,
  }) async {
    if (!Platform.isAndroid || sessionId.trim().isEmpty) return;

    await NotificationHub.requestPermissionIfNeeded();

    var body = formatAssistantBubbleForDisplay(preview.trim());
    if (body.isEmpty) body = 'Yeni agent cevabı';
    if (body.length > 180) {
      body = '${body.substring(0, 177)}…';
    }

    final name = sessionName.trim().isEmpty ? 'Oturum' : sessionName.trim();

    await NotificationHub.plugin.show(
      NotificationHub.notificationIdForSession(sessionId),
      '«$name» — cevap var',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationHub.sessionReplyChannelId,
          'Oturum cevapları',
          channelDescription: 'Başka oturumda agent cevabı',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'Cursor uzaktan cevap',
          category: AndroidNotificationCategory.message,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      payload: sessionId,
    );
  }

  static Future<void> cancel(String sessionId) async {
    if (!Platform.isAndroid || sessionId.trim().isEmpty) return;
    await NotificationHub.plugin.cancel(
      NotificationHub.notificationIdForSession(sessionId),
    );
  }
}
