import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/player/widgets/mini_player_bar.dart';
import 'core/theme/app_theme.dart';

const _destinations = [
  (Icons.podcasts_outlined, Icons.podcasts, 'Kütüphane'),
  (Icons.queue_music_outlined, Icons.queue_music, 'Sıra'),
  (Icons.download_outlined, Icons.download, 'İndirilenler'),
  (Icons.settings_outlined, Icons.settings, 'Ayarlar'),
];

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.wideBreakpoint;

    // Genis pencerede alt cubuk gizlenir; Sira/Indirilenler/Ayarlar'a erisim icin sol rail gosterilir.
    final content = wide
        ? Row(
            children: [
              NavigationRail(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: navigationShell.goBranch,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final (icon, selected, label) in _destinations)
                    NavigationRailDestination(
                      icon: Icon(icon),
                      selectedIcon: Icon(selected),
                      label: Text(label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: navigationShell),
            ],
          )
        : navigationShell;

    return Column(
      children: [
        Expanded(child: content),
        const MiniPlayerBar(),
        if (!wide)
          NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: navigationShell.goBranch,
            height: AppLayout.navHeight,
            destinations: [
              for (final (icon, selected, label) in _destinations)
                NavigationDestination(
                  icon: Icon(icon),
                  selectedIcon: Icon(selected),
                  label: label,
                ),
            ],
          ),
      ],
    );
  }
}
