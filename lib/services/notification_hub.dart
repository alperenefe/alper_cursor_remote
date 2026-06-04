import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Tek plugin — agent işi + oturum cevabı bildirimleri.
class NotificationHub {
  NotificationHub._();

  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  static const agentWorkChannelId = 'cursor_agent_work';
  static const sessionReplyChannelId = 'cursor_session_reply';

  static bool _initialized = false;

  /// Uygulama açılmadan bildirime tıklanırsa (soğuk başlatma).
  static String? pendingSessionId;

  /// Oturum bildirimine tıklanınca (MaterialApp hazır olunca bağlanır).
  static void Function(String sessionId)? onOpenSession;

  static Future<void> init() async {
    if (!Platform.isAndroid || _initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final androidImpl = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        agentWorkChannelId,
        'Agent işlemleri',
        description: 'Uzaktan agent çalışırken bağlantı bildirimi',
        importance: Importance.low,
      ),
    );
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        sessionReplyChannelId,
        'Oturum cevapları',
        description: 'Başka oturumda agent cevabı geldiğinde',
        importance: Importance.high,
      ),
    );

    final launch = await plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload?.trim();
    if (launch?.didNotificationLaunchApp == true &&
        payload != null &&
        payload.isNotEmpty) {
      pendingSessionId = payload;
    }

    _initialized = true;
  }

  static void _onNotificationResponse(NotificationResponse response) {
    final sid = response.payload?.trim();
    if (sid == null || sid.isEmpty) return;
    final open = onOpenSession;
    if (open != null) {
      open(sid);
    } else {
      pendingSessionId = sid;
    }
  }

  static Future<void> requestPermissionIfNeeded() async {
    if (!Platform.isAndroid) return;
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  static int notificationIdForSession(String sessionId) =>
      42000 + (sessionId.hashCode & 0x7FFF);
}
