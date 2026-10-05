import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.06,
                color: AppTheme.muted(context),
              ),
            ),
          ),
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
    this.trailing,
    this.onTap,
    this.borderTop = true,
  });

  final String label;
  final String? description;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool borderTop;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: borderTop
                ? Border(top: BorderSide(color: AppTheme.border(context)))
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        description!,
                        style: TextStyle(fontSize: 12, color: AppTheme.muted(context)),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class ThemeSegment extends StatelessWidget {
  const ThemeSegment({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: AppThemeMode.values.map((mode) {
        final selected = mode == value;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(mode),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? AppColors.primary : AppTheme.border(context),
                ),
              ),
              child: Text(
                themeModeLabel(mode),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected ? AppColors.primary : AppTheme.muted(context),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class DesignToggle extends StatelessWidget {
  const DesignToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 28,
          decoration: BoxDecoration(
            color: value ? AppColors.primary : AppTheme.border(context),
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 150),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
