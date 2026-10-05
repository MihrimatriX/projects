import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_constrained.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _NavTab('/', 'Bugün', Icons.dashboard_outlined, Icons.dashboard),
    _NavTab('/stats', 'Isı haritası', Icons.grid_view_outlined, Icons.grid_view),
    _NavTab('/chain', 'Zincir', Icons.link_outlined, Icons.link),
    _NavTab('/settings', 'Ayarlar', Icons.settings_outlined, Icons.settings),
  ];

  int _indexForLocation(String location) {
    if (location.startsWith('/stats')) return 1;
    if (location.startsWith('/chain')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _indexForLocation(location);

    return AppConstrained(
      child: Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final tab in _tabs)
              NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.selectedIcon, color: AppColors.primary),
                label: tab.label,
              ),
          ],
          onDestinationSelected: (i) => context.go(_tabs[i].path),
        ),
      ),
    );
  }
}

class _NavTab {
  const _NavTab(this.path, this.label, this.icon, this.selectedIcon);

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class AppFab extends StatelessWidget {
  const AppFab({super.key, required this.onPressed, this.tooltip = 'Ekle'});

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 72),
      child: FloatingActionButton(
        onPressed: onPressed,
        tooltip: tooltip,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
