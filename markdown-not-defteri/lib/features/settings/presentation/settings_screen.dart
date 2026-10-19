import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/widgets/app_shell.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pref = ref.watch(themePreferenceProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? AppColors.borderDark : AppColors.border;

    return Scaffold(
      appBar: const AppNav(active: 'settings'),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ayarlar',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.02,
                      color: dark
                          ? AppColors.foregroundDark
                          : AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _SettingRow(
                    border: border,
                    label: 'Tema',
                    description: 'Sepia varsayılan; koyu mod uzun okuma için.',
                    trailing: _ThemeOptions(
                      selected: pref,
                      onChanged: (p) =>
                          ref.read(themePreferenceProvider.notifier).set(p),
                    ),
                  ),
                  _SettingRow(
                    border: border,
                    label: 'Editör font boyutu',
                    badge: 'Faz 2',
                    description: '14–20 px arası; varsayılan 16 px.',
                    trailing: Text(
                      '16 px',
                      style: TextStyle(
                        fontSize: 13,
                        color: dark ? AppColors.mutedDark : AppColors.muted,
                      ),
                    ),
                  ),
                  _SettingRow(
                    border: border,
                    label: 'Otomatik kaydetme',
                    description: '2 sn debounce ile diske yazar.',
                    trailing: Text(
                      'Açık',
                      style: TextStyle(
                        fontSize: 13,
                        color: dark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _Swatch(
                          label: 'Sepia',
                          bg: AppColors.bg,
                          fg: AppColors.foreground,
                          border: border,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: _Swatch(
                          label: 'Koyu',
                          bg: AppColors.bgDark,
                          fg: AppColors.foregroundDark,
                          border: AppColors.borderDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Sürüm 1.0.0',
                    style: TextStyle(
                      fontSize: 13,
                      color: dark ? AppColors.mutedDark : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.border,
    required this.label,
    required this.description,
    required this.trailing,
    this.badge,
  });

  final Color border;
  final String label;
  final String description;
  final Widget trailing;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
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
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: dark
                            ? AppColors.foregroundDark
                            : AppColors.foreground,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: border),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.06,
                            color: dark ? AppColors.mutedDark : AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: dark ? AppColors.mutedDark : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );
  }
}

class _ThemeOptions extends StatelessWidget {
  const _ThemeOptions({required this.selected, required this.onChanged});

  final AppThemePreference selected;
  final ValueChanged<AppThemePreference> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? AppColors.borderDark : AppColors.border;

    return Wrap(
      spacing: 8,
      children: [
        for (final (pref, label) in [
          (AppThemePreference.sepia, 'Sepia'),
          (AppThemePreference.dark, 'Koyu'),
          (AppThemePreference.system, 'Sistem'),
        ])
          _ThemeChip(
            label: label,
            selected: selected == pref,
            border: border,
            onTap: () => onChanged(pref),
          ),
      ],
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.selected,
    required this.border,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? AppColors.primary : border,
          ),
          borderRadius: BorderRadius.circular(6),
          color: selected ? AppColors.accentSoft : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected
                ? AppColors.primary
                : (dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
  });

  final String label;
  final Color bg;
  final Color fg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.all(8),
      alignment: Alignment.bottomLeft,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}
