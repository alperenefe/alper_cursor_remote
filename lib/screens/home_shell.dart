import 'package:flutter/material.dart';

import '../navigation/home_tab_controller.dart';
import '../testing/e2e_keys.dart';
import 'chat_screen.dart';
import 'connection_screen.dart';
import 'traffic_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static IconData _selectedIcon(IconData outline) => switch (outline) {
        Icons.chat_bubble_outline => Icons.chat_bubble,
        Icons.lan_outlined => Icons.lan,
        Icons.code => Icons.code,
        _ => outline,
      };

  static const _tabs = [
    (icon: Icons.chat_bubble_outline, label: 'Sohbet'),
    (icon: Icons.lan_outlined, label: 'Bağlantı'),
    (icon: Icons.code, label: 'Trafik'),
  ];

  @override
  Widget build(BuildContext context) {
    return HomeTabController(
      goToTab: (i) => setState(() => _index = i),
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: const [
            ChatScreen(),
            ConnectionScreen(),
            TrafficScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (var i = 0; i < _tabs.length; i++)
              NavigationDestination(
                key: i == 0 ? E2eKeys.tabChat : null,
                icon: Icon(_tabs[i].icon),
                selectedIcon: Icon(_selectedIcon(_tabs[i].icon)),
                label: _tabs[i].label,
              ),
          ],
        ),
      ),
    );
  }
}
