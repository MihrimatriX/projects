import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class OdCard extends StatelessWidget {
  const OdCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );
  }
}
