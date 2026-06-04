import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_hub.dart';

/// Agent beklerken: ön planda in-app şerit; arka planda Android foreground service.
class AgentWorkNotification {
  AgentWorkNotification._();

  static const _notificationId = 41001;
  static bool _foregroundServiceActive = false;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      NotificationHub.plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> init() async {
    await NotificationHub.init();
  }

  /// [appInBackground] false → sistem bildirimi yok (AgentWorkingStrip vb.).
  static Future<void> sync({
    required bool connected,
    required bool connecting,
    required int activeSessions,
    required bool appInBackground,
    String? detail,
  }) async {
    if (!Platform.isAndroid) return;

    if (activeSessions <= 0 || !appInBackground) {
      await _stopForegroundService();
      return;
    }

    await NotificationHub.requestPermissionIfNeeded();

    final String title;
    final String body;
    if (!connected) {
      title = activeSessions == 1
          ? 'Agent bekleniyor — bağlantı kopuk'
          : '$activeSessions oturum — bağlantı kopuk';
      body = connecting
          ? 'Yeniden bağlanılıyor…'
          : 'PC bağlantısı kesildi; agent PC\'de sürebilir';
    } else {
      title = activeSessions == 1
          ? 'Cursor agent çalışıyor'
          : '$activeSessions oturumda agent çalışıyor';
      body = detail?.trim().isNotEmpty == true
          ? detail!.trim()
          : 'Arka planda bağlantı açık';
    }

    final android = AndroidNotificationDetails(
      NotificationHub.agentWorkChannelId,
      'Agent işlemleri',
      channelDescription:
          'Uzaktan agent çalışırken arka plan bağlantısı',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      onlyAlertOnce: true,
      showWhen: false,
      category: AndroidNotificationCategory.progress,
    );

    await _android?.startForegroundService(
      _notificationId,
      title,
      body,
      notificationDetails: android,
      foregroundServiceTypes: {
        AndroidServiceForegroundType.foregroundServiceTypeDataSync,
      },
    );
    _foregroundServiceActive = true;
  }

  static Future<void> _stopForegroundService() async {
    if (!_foregroundServiceActive) return;
    await _android?.stopForegroundService();
    _foregroundServiceActive = false;
  }

  static Future<void> dispose() async {
    await _stopForegroundService();
  }
}
