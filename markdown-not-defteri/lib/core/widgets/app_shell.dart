import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class AppNav extends StatelessWidget implements PreferredSizeWidget {
  const AppNav({
    super.key,
    required this.active,
    this.trailing,
  });

  final String active;
  final Widget? trailing;

  static const _routes = [
    ('home', '/', 'Ana Sayfa'),
    ('notes', '/notes', 'Notlar'),
    ('editor', '/notes/edit', 'Editör'),
    ('settings', '/settings', 'Ayarlar'),
  ];

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? AppColors.bgToolbarDark : AppColors.bgToolbar;
    final border = dark ? AppColors.borderDark : AppColors.border;

    return Material(
      color: bg,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (final (id, path, label) in _routes)
              _NavLink(
                label: label,
                active: active == id,
                onTap: () {
                  if (id == 'editor') {
                    context.push(path);
                  } else {
                    context.go(path);
                  }
                },
              ),
            const Spacer(),
            if (trailing != null) trailing!,
            _NavIcon(
              icon: Icons.settings_outlined,
              onTap: () => context.go('/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppColors.foregroundDark : AppColors.foreground;
    final muted = dark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: active ? AppColors.primary : muted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? AppColors.primary : fg.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        minimumSize: const Size(32, 32),
        maximumSize: const Size(32, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.08,
          color: dark ? AppColors.mutedDark : AppColors.muted,
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: Size(0, compact ? 32 : 36),
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: TextStyle(
          fontSize: compact ? 12 : 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size(0, compact ? 32 : 36),
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 12),
        foregroundColor:
            dark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 12 : 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
