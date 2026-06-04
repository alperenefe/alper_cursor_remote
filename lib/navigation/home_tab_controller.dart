import 'package:flutter/material.dart';

/// Alt sekmeler arası geçiş (Sohbet → Bağlantı vb.).
class HomeTabController extends InheritedWidget {
  const HomeTabController({
    required this.goToTab,
    required super.child,
    super.key,
  });

  final ValueChanged<int> goToTab;

  static HomeTabController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HomeTabController>();
  }

  static void goToConnection(BuildContext context) {
    maybeOf(context)?.goToTab(1);
  }

  static bool goToChat(BuildContext context) {
    final c = maybeOf(context);
    if (c == null) return false;
    c.goToTab(0);
    return true;
  }

  @override
  bool updateShouldNotify(HomeTabController oldWidget) =>
      oldWidget.goToTab != goToTab;
}
