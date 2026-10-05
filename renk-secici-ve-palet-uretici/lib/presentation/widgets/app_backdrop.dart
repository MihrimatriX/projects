import 'package:flutter/material.dart';

import '../../domain/palette_core.dart';

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.theme, required this.child});

  final ExtractedTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.accent.withValues(alpha: 0.08),
                theme.bgApp,
                theme.bgApp,
              ],
              stops: const [0, 0.35, 1],
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -80,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [theme.accent.withValues(alpha: 0.12), Colors.transparent],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class CircleIconBtn extends StatelessWidget {
  const CircleIconBtn({
    super.key,
    required this.theme,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.active = false,
  });

  final ExtractedTheme theme;
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: active ? theme.accent.withValues(alpha: 0.18) : theme.bgElevated,
      shape: CircleBorder(side: BorderSide(color: active ? theme.accent : theme.border)),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: active ? theme.accent : theme.textPrimary),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
