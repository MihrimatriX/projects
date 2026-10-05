import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notification_service.dart';
import '../habits/providers/habits_provider.dart';

Future<void> handleHabitToggle(BuildContext context, WidgetRef ref, String id) async {
  final result = await ref.read(habitsProvider.notifier).toggle(id);
  if (!context.mounted || result.chainReminders.isEmpty) return;

  final messenger = ScaffoldMessenger.of(context);
  for (final h in result.chainReminders) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Zincir: ${h.icon} ${h.title} — sıra sende!'),
        action: SnackBarAction(
          label: 'Tamamla',
          onPressed: () {
            if (context.mounted) handleHabitToggle(context, ref, h.id);
          },
        ),
      ),
    );
    await NotificationService.showChainReminder(h.title, h.icon);
  }
}
