import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';

/// Ayarlar ekranı bölüm kartı — design/ayarlar.html ile uyumlu.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.banner,
  });

  final String title;
  final List<Widget> children;
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final surface = isDark ? AppColors.bgGridDark : AppColors.bgGridLight;
    final sidebar = isDark ? AppColors.bgSidebarDark : AppColors.bgSidebarLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: sidebar,
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.02,
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
              ),
            ),
          ),
          if (banner != null) banner!,
          ...children,
        ],
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.description,
    required this.trailing,
    this.onTap,
  });

  final String label;
  final String? description;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class ThemeSegmentedControl extends StatelessWidget {
  const ThemeSegmentedControl({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final AppThemeMode mode;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebar = isDark ? AppColors.bgSidebarDark : AppColors.bgSidebarLight;
    final accent = AppColors.accentOf(isDark);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: sidebar,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: AppThemeMode.values.map((m) {
          final selected = m == mode;
          return Material(
            color: selected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => onChanged(m),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text(
                  themeModeLabel(m),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected
                        ? Colors.white
                        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
