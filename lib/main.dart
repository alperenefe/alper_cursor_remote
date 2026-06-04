import 'package:flutter/material.dart';

import 'app.dart';
import 'services/agent_work_notification.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AgentWorkNotification.init();
  runApp(const AlperCursorRemoteApp());
}
