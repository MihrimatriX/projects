import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}
