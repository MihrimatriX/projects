import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// design/index.html `.app-shell` + `.app-bar`
class AppLayout extends StatelessWidget {
  const AppLayout({
    super.key,
    required this.child,
    this.showHeader = true,
  });

  final Widget child;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(AppColors.bgApp, AppColors.primary, 0.06)!,
                  AppColors.bgApp,
                ],
                stops: const [0.0, 0.55],
              )
            : null,
        color: isDark ? null : AppColors.bgAppLight,
      ),
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showHeader) ...[
                    _AppHeader(onSettings: () => context.push('/settings')),
                    const SizedBox(height: AppSpacing.section),
                  ],
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).brightness == Brightness.dark
        ? AppColors.border
        : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QR Kod & Barkod',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.01,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Oluştur, okut, dışa aktar',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const _OfflineBadge(),
          IconButton(
            onPressed: onSettings,
            tooltip: 'Ayarlar',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Çevrimdışı hazır',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
