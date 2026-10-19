import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DesignFilterChip extends StatelessWidget {
  const DesignFilterChip({
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.muted : AppColors.border),
            color: selected ? AppColors.bgPlaying : Colors.transparent,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? AppColors.foreground : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class EpisodeEqualizer extends StatefulWidget {
  const EpisodeEqualizer({super.key});

  @override
  State<EpisodeEqualizer> createState() => _EpisodeEqualizerState();
}

class _EpisodeEqualizerState extends State<EpisodeEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = (_controller.value + i * 0.2) % 1.0;
              final h = 6.0 + (t < 0.5 ? t * 16 : (1 - t) * 16);
              return Container(
                width: 3,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class CorsBanner extends StatelessWidget {
  const CorsBanner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
