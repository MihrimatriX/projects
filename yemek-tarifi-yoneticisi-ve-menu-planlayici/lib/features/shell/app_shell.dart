import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const sidebarBreakpoint = AppLayout.sidebarBreakpoint;

  static const _nav = [
    _NavItem('/recipes', 'Tarifler', Icons.menu_book_outlined, Icons.menu_book),
    _NavItem('/planner', 'Plan', Icons.calendar_month_outlined, Icons.calendar_month),
    _NavItem('/shopping', 'Alışveriş', Icons.shopping_basket_outlined, Icons.shopping_basket),
    _NavItem('/settings', 'Ayarlar', Icons.settings_outlined, Icons.settings),
  ];

  static const _mobileNav = [
    _NavItem('/recipes', 'Tarifler', Icons.menu_book_outlined, Icons.menu_book),
    _NavItem('/planner', 'Plan', Icons.calendar_month_outlined, Icons.calendar_month),
    _NavItem('/shopping', 'Alışveriş', Icons.shopping_basket_outlined, Icons.shopping_basket),
  ];

  String? _activeRoute(String location) {
    if (location.startsWith('/recipes') || location == '/pantry') return '/recipes';
    if (location.startsWith('/planner')) return '/planner';
    if (location.startsWith('/shopping')) return '/shopping';
    if (location.startsWith('/settings')) return '/settings';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final active = _activeRoute(location);
    final wide = MediaQuery.sizeOf(context).width >= sidebarBreakpoint;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: Row(
        children: [
          if (wide) _Sidebar(active: active),
          Expanded(
            child: ColoredBox(
              color: AppColors.bgApp,
              child: child,
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : _BottomNav(
              items: _mobileNav,
              active: active,
              onTap: (path) => context.go(path),
            ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.active});

  final String? active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppColors.bgMuted,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => context.go('/'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.restaurant, color: AppColors.accent, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Yemek Planlayıcı',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.02,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 8),
            for (final item in AppShell._nav)
              _NavLink(
                item: item,
                selected: active == item.path,
                onTap: () => context.go(item.path),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? AppColors.bgSurface : Colors.transparent,
        elevation: selected ? 1 : 0,
        shadowColor: const Color(0x141C1917),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 22,
                  color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.items,
    required this.active,
    required this.onTap,
  });

  final List<_NavItem> items;
  final String? active;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              for (final item in items)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(item.path),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            active == item.path ? item.selectedIcon : item.icon,
                            size: 22,
                            color: active == item.path ? AppColors.accent : AppColors.textMuted,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: active == item.path ? AppColors.accent : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.path, this.label, this.icon, this.selectedIcon);

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
