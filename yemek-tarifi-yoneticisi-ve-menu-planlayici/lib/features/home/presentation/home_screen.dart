import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/week_utils.dart';
import '../../planner/providers/planner_provider.dart';
import '../../recipes/providers/recipes_provider.dart';
import '../../shopping/providers/shopping_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(recipesProvider).value?.length ?? 0;
    final weekStart = ref.watch(activeWeekStartProvider);
    final weekKeyStr = weekKey(weekStart);
    final mealCount = ref.watch(weekPlanProvider(weekKeyStr)).value?.plannedMealCount ?? 0;
    final shoppingCount = ref.watch(mergedShoppingListProvider(weekKeyStr)).length;
    final wide = MediaQuery.sizeOf(context).width >= 600;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(24, wide ? 48 : 24, 24, 96),
        children: [
          Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.restaurant, color: AppColors.accent, size: 28),
              ),
              const SizedBox(height: 20),
              Text(
                'Yemek Tarifi Yöneticisi',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.03,
                    ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tarif arşivi, haftalık menü planı ve birleşik alışveriş listesi — tamamen yerel, Türkçe birimlerle.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                '$count tarif · $mealCount planlı öğün · $shoppingCount alışveriş kalemi',
                style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
              Text(
                formatWeekRange(weekStart),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 900 ? 2 : 1;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: cols == 1 ? 1.6 : 1.35,
                children: [
                  _LauncherCard(
                    icon: Icons.menu_book,
                    title: 'Tarif Arşivi',
                    body: 'Etiket filtreleri, arama ve fotoğraf odaklı tarif kartları.',
                    link: 'Tariflere git →',
                    onTap: () => context.go('/recipes'),
                  ),
                  _LauncherCard(
                    icon: Icons.calendar_month,
                    title: 'Haftalık Planlayıcı',
                    body: '7×3 öğün grid; öğün slotlarına tarif atayın.',
                    link: 'Planlayıcıya git →',
                    onTap: () => context.go('/planner'),
                  ),
                  _LauncherCard(
                    icon: Icons.shopping_basket,
                    title: 'Alışveriş Listesi',
                    body: 'Plandan birleşen malzemeler; kiler stok durumu.',
                    link: 'Listeye git →',
                    onTap: () => context.go('/shopping'),
                  ),
                  _LauncherCard(
                    icon: Icons.inventory_2_outlined,
                    title: 'Kiler',
                    body: 'Evdeki malzemeleri işaretleyin; alışverişten düşün.',
                    link: 'Kilere git →',
                    onTap: () => context.go('/pantry'),
                  ),
                  _LauncherCard(
                    icon: Icons.settings_outlined,
                    title: 'Ayarlar',
                    body: 'Veri içe/dışa aktarma ve tema.',
                    link: 'Ayarlara git →',
                    onTap: () => context.go('/settings'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LauncherCard extends StatelessWidget {
  const _LauncherCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.link,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.accent),
                ),
                const SizedBox(height: 16),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Expanded(child: Text(body, style: const TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.5))),
                Text(link, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accent)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
