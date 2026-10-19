import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class PodcastCover extends StatelessWidget {
  const PodcastCover({
    super.key,
    this.imageUrl,
    this.size = 48,
    this.borderRadius = AppLayout.artRadius,
  });

  final String? imageUrl;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return _placeholder();
                },
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF533483), Color(0xFFE94560)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.podcasts,
        color: AppColors.foreground.withValues(alpha: 0.7),
        size: size * 0.45,
      ),
    );
  }
}
