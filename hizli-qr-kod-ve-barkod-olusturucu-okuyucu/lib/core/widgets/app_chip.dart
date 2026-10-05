import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// design/index.html `.chip`
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.border : AppColors.borderLight;

    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : (isDark ? AppColors.bgInput : AppColors.bgPanelLight),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary : border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
