import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/recipe_card.dart';
import '../providers/pantry_provider.dart';

const _quickAdd = ['un', 'şeker', 'tuz', 'zeytinyağı', 'süt', 'yumurta', 'domates', 'soğan', 'sarımsak', 'pirinç'];

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    await ref.read(pantryProvider.notifier).add(text);
    if (!mounted) return;
    _input.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pantryAsync = ref.watch(pantryProvider);
    final items = pantryAsync.value?.toList() ?? []..sort();

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
          children: [
            const PageHeader(
              title: 'Kiler',
              subtitle: 'Evdeki malzemeler — alışverişte "Stokta" olarak işaretlenir',
            ),
            DetailPanel(
              title: 'Malzeme ekle',
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: const InputDecoration(hintText: 'ör. un, süt'),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  YtpPrimaryButton(label: 'Ekle', icon: Icons.add, onPressed: _add),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Hızlı ekle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.06)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickAdd.map((name) {
                final inPantry = items.contains(name);
                return YtpChip(
                  label: name,
                  selected: inPantry,
                  onTap: () async {
                    if (inPantry) {
                      await ref.read(pantryProvider.notifier).remove(name);
                    } else {
                      await ref.read(pantryProvider.notifier).add(name);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            DetailPanel(
              title: 'Stoktaki malzemeler (${items.length})',
              child: pantryAsync.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? const Text('Henüz kiler boş', style: TextStyle(color: AppColors.textMuted))
                      : Column(
                          children: [
                            for (final key in items)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.inventory_2_outlined, color: AppColors.accent),
                                title: Text(key),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                                  onPressed: () => ref.read(pantryProvider.notifier).remove(key),
                                ),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
