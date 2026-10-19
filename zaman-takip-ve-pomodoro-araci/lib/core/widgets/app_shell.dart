import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;

    final content = Expanded(
      child: ColoredBox(
        color: AppColors.bgApp,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(compact ? 16 : 32, compact ? 20 : 28, compact ? 16 : 32, 32),
          child: child,
        ),
      ),
    );
    final sidebar = _Sidebar(
      compact: compact,
      location: location,
      onNavigate: (path) => context.go(path),
    );

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: compact
          ? Column(children: [sidebar, content])
          : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [sidebar, content]),
    );
  }
}

class _NavItem {
  const _NavItem(this.path, this.icon, this.label);
  final String path;
  final IconData icon;
  final String label;
}

const _routes = [
  _NavItem('/timer', Icons.timer_outlined, 'Timer'),
  _NavItem('/pomodoro', Icons.eco_outlined, 'Pomodoro'),
  _NavItem('/reports', Icons.bar_chart_outlined, 'Raporlar'),
  _NavItem('/settings', Icons.settings_outlined, 'Ayarlar'),
];

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.compact,
    required this.location,
    required this.onNavigate,
  });

  final bool compact;
  final String location;
  final void Function(String path) onNavigate;

  @override
  Widget build(BuildContext context) {
    final nav = _routes
        .map(
          (r) => _NavButton(
            item: r,
            active: location == r.path,
            compact: compact,
            onTap: () => onNavigate(r.path),
          ),
        )
        .toList();

    if (compact) {
      return Material(
        color: AppColors.bgSurface,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              const _Brand(compact: true),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(children: nav.map((n) => Expanded(child: n)).toList()),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: AppColors.bgSurface,
      child: Container(
        width: 220,
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Brand(compact: false),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(children: nav),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 12, 16),
              child: Text('Drift SQLite · yerel', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 10 : 22, compact ? 12 : 24, 10, compact ? 12 : 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.schedule, size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: 10),
          const Text(
            'Odaklanma',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  final _NavItem item;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active ? AppColors.accentSoft : Colors.transparent;
    final fg = active ? AppColors.accent : AppColors.textSecondary;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: AppColors.bgHover,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 12, vertical: compact ? 8 : 10),
          child: Row(
            mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(item.icon, size: compact ? 18 : 20, color: fg),
              if (!compact) ...[
                const SizedBox(width: 10),
                Text(item.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
