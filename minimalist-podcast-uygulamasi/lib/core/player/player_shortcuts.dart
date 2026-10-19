import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_provider.dart';

/// Masaüstü ve web için oynatıcı klavye kısayolları.
class PlayerShortcuts extends ConsumerWidget {
  const PlayerShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(playerProvider.notifier);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () {
          if (ref.read(playerProvider).hasTrack) {
            notifier.togglePlayPause();
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (ref.read(playerProvider).hasTrack) notifier.seekBack15();
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (ref.read(playerProvider).hasTrack) notifier.seekForward30();
        },
      },
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }
}
