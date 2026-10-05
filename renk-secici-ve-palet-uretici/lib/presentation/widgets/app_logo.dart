import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/palette_core.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32, this.radius = 8});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        size >= 40 ? 'assets/icon-64.png' : 'assets/icon-48.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _LogoFallback(size: size, radius: radius),
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback({required this.size, required this.radius});

  final double size;
  final double radius;

  static const _bars = [
    Color(0xFFA855F7),
    Color(0xFF7C3AED),
    Color(0xFF22C55E),
    Color(0xFFEAB308),
    Color(0xFFEF4444),
  ];

  @override
  Widget build(BuildContext context) {
    final barW = size * 0.11;
    final gap = size * 0.025;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_bars.length, (i) {
          return Container(
            width: barW,
            height: size * 0.58,
            margin: EdgeInsets.only(right: i < _bars.length - 1 ? gap : 0),
            decoration: BoxDecoration(
              color: _bars[i],
              borderRadius: BorderRadius.circular(size * 0.06),
            ),
          );
        }),
      ),
    );
  }
}

class AppBrandTitle extends StatelessWidget {
  const AppBrandTitle({super.key, required this.theme, this.compact = false});

  final ExtractedTheme theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogo(size: compact ? 28 : 32, radius: compact ? 7 : 8),
        SizedBox(width: compact ? 10 : 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Palet Üretici',
              style: TextStyle(
                fontSize: compact ? 18 : 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: theme.textPrimary,
                height: 1.1,
              ),
            ),
            if (!compact)
              Text(
                'Harmonik renk paletleri',
                style: TextStyle(fontSize: 12, color: theme.textMuted, height: 1.2),
              ),
          ],
        ),
      ],
    );
  }
}
