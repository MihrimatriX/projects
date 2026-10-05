import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/week_utils.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/recipe_card.dart';
import '../../pantry/providers/pantry_provider.dart';
import '../../planner/providers/planner_provider.dart';
import '../providers/shopping_provider.dart';

class ShoppingScreen extends ConsumerWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = ref.watch(activeWeekStartProvider);
    final weekKeyStr = weekKey(weekStart);
    final entries = ref.watch(shoppingEntriesProvider(weekKeyStr));
    final checkedAsync = ref.watch(shoppingCheckedProvider(weekKeyStr));
    final planAsync = ref.watch(weekPlanProvider(weekKeyStr));
    final hidePantry = ref.watch(hidePantryItemsProvider);

    final assignedCount = planAsync.value?.plannedMealCount ?? 0;
    final visible = hidePantry ? entries.where((e) => !e.inPantry).toList() : entries;
    final pantryCount = entries.where((e) => e.inPantry).length;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
          children: [
            PageHeader(
              title: 'Alışveriş Listesi',
              subtitle: formatWeekRange(weekStart),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(onPressed: () => context.go('/planner'), child: const Text('Plan')),
                  TextButton(onPressed: () => context.go('/pantry'), child: const Text('Kiler')),
                  if (visible.isNotEmpty)
                    IconButton(
                      tooltip: 'Kalanları panoya kopyala',
                      icon: const Icon(Icons.copy_all_outlined),
                      onPressed: () async {
                        final text = shoppingListText(visible, checkedAsync.value ?? const {});
                        final messenger = ScaffoldMessenger.of(context);
                        if (text.isEmpty) {
                          messenger.showSnackBar(const SnackBar(content: Text('Alınacak kalem kalmadı')));
                          return;
                        }
                        await Clipboard.setData(ClipboardData(text: text));
                        messenger.showSnackBar(const SnackBar(content: Text('Liste panoya kopyalandı')));
                      },
                    ),
                  if (entries.isNotEmpty)
                    IconButton(
                      tooltip: 'İşaretleri temizle',
                      onPressed: () => ref.read(shoppingCheckedProvider(weekKeyStr).notifier).clearAll(),
                      icon: const Icon(Icons.done_all),
                    ),
                ],
              ),
            ),
            checkedAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Hata: $e'),
              data: (checked) {
                final done = visible.where((e) => checked.contains(e.item.key)).length;
                final complete = visible.isNotEmpty && done == visible.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: complete
                            ? Color.alphaBlend(const Color(0x1F16A34A), AppColors.bgSurface)
                            : AppColors.bgMuted,
                        borderRadius: BorderRadius.circular(14),
                        border: complete ? Border.all(color: AppColors.success.withValues(alpha: 0.3)) : null,
                      ),
                      child: Text(
                        assignedCount == 0
                            ? 'Bu hafta plana tarif ekleyin; malzemeler otomatik birleşir.'
                            : '$assignedCount öğün · ${entries.length} kalem'
                                '${pantryCount > 0 ? ' · $pantryCount stokta' : ''}'
                                '${visible.isNotEmpty ? ' · $done/${visible.length} alındı' : ''}',
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Stoktakileri gizle'),
                      subtitle: const Text('Kilerde olan malzemeleri listeden çıkar'),
                      value: hidePantry,
                      onChanged: (v) => ref.read(hidePantryItemsProvider.notifier).state = v,
                    ),
                    if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            const Icon(Icons.shopping_basket_outlined, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              entries.isEmpty
                                  ? 'Planlanan öğünlerden malzeme yok.\nHaftalık plana tarif atayın.'
                                  : 'Tüm kalemler kilerde.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 16),
                            YtpPrimaryButton(
                              label: 'Haftalık plan',
                              icon: Icons.calendar_month,
                              onPressed: () => context.go('/planner'),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final entry in visible)
                        _ShoppingRow(
                          entry: entry,
                          checked: checked.contains(entry.item.key),
                          onToggle: (v) => ref
                              .read(shoppingCheckedProvider(weekKeyStr).notifier)
                              .toggle(entry.item.key, v),
                          onPantry: entry.inPantry
                              ? () => ref.read(pantryProvider.notifier).remove(entry.item.name)
                              : () => ref.read(pantryProvider.notifier).add(entry.item.name),
                        ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingRow extends StatelessWidget {
  const _ShoppingRow({
    required this.entry,
    required this.checked,
    required this.onToggle,
    required this.onPantry,
  });

  final ShoppingListEntry entry;
  final bool checked;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPantry;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final qty = item.quantityLabel;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Checkbox(value: checked, onChanged: (v) => onToggle(v ?? false), activeColor: AppColors.accent),
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(
                fontSize: 15,
                color: checked ? AppColors.textMuted : AppColors.textPrimary,
                decoration: checked ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (entry.inPantry)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('STOKTA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning)),
            ),
          if (qty.isNotEmpty)
            SizedBox(
              width: 80,
              child: Text(qty, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
          IconButton(
            tooltip: entry.inPantry ? 'Kilerden çıkar' : 'Kilere ekle',
            onPressed: onPantry,
            icon: Icon(entry.inPantry ? Icons.inventory_2_outlined : Icons.add_box_outlined),
          ),
        ],
      ),
    );
  }
}
