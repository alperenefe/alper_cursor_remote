import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'navigation/home_tab_controller.dart';
import 'screens/home_shell.dart';
import 'services/notification_hub.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

class AlperCursorRemoteApp extends StatelessWidget {
  const AlperCursorRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: _AppLifecycleHost(
        child: MaterialApp(
          title: 'Cursor Uzaktan',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: const HomeShell(),
        ),
      ),
    );
  }
}

/// Ön plana dönünce yeniden bağlan, PC geçmişi senkronu, kuyruk devam.
class _AppLifecycleHost extends StatefulWidget {
  const _AppLifecycleHost({required this.child});

  final Widget child;

  @override
  State<_AppLifecycleHost> createState() => _AppLifecycleHostState();
}

class _AppLifecycleHostState extends State<_AppLifecycleHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _wireNotificationNavigation());
  }

  void _wireNotificationNavigation() {
    if (!mounted) return;
    final appState = context.read<AppState>();
    NotificationHub.onOpenSession = (sessionId) {
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      HomeTabController.goToChat(context);
      appState.selectSession(sessionId);
    };
    final pending = NotificationHub.pendingSessionId;
    if (pending != null && pending.isNotEmpty) {
      NotificationHub.pendingSessionId = null;
      FocusManager.instance.primaryFocus?.unfocus();
      HomeTabController.goToChat(context);
      appState.selectSession(pending);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final appState = context.read<AppState>();
    if (state == AppLifecycleState.resumed) {
      appState.setAppInBackground(false);
      appState.handleAppResumed();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      appState.setAppInBackground(true);
      unawaited(appState.flushLocalCache());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
