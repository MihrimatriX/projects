import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/settings_group.dart';
import '../../habits/models/habit.dart';

class HabitFormDialog extends StatefulWidget {
  const HabitFormDialog({super.key, this.habit, this.allHabits = const []});

  final Habit? habit;
  final List<Habit> allHabits;

  static Future<HabitFormResult?> show(
    BuildContext context, {
    Habit? habit,
    List<Habit> allHabits = const [],
  }) {
    return showModalBottomSheet<HabitFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: HabitFormDialog(habit: habit, allHabits: allHabits),
      ),
    );
  }

  @override
  State<HabitFormDialog> createState() => _HabitFormDialogState();
}

class HabitFormResult {
  const HabitFormResult({
    required this.title,
    required this.icon,
    required this.color,
    required this.frequency,
    this.flexStreakEnabled = false,
    this.flexTargetPerWeek = 5,
    this.chainFromId,
  });

  final String title;
  final String icon;
  final int color;
  final HabitFrequency frequency;
  final bool flexStreakEnabled;
  final int flexTargetPerWeek;
  final String? chainFromId;
}

class _HabitFormDialogState extends State<HabitFormDialog> {
  late final TextEditingController _titleController;
  late String _icon;
  late int _color;
  late HabitFrequency _frequency;
  late bool _flexEnabled;
  late int _flexTarget;
  String? _chainFromId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.habit?.title ?? '');
    _icon = widget.habit?.icon ?? AppColors.habitIcons.first;
    _color = widget.habit?.color ?? AppColors.habitPalette.first;
    _frequency = widget.habit?.frequency ?? HabitFrequency.daily;
    _flexEnabled = widget.habit?.flexStreakEnabled ?? false;
    _flexTarget = widget.habit?.flexTargetPerWeek ?? 5;
    _chainFromId = widget.habit?.chainFromId;
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  List<Habit> get _chainOptions =>
      widget.allHabits.where((h) => h.id != widget.habit?.id).toList();

  @override
  Widget build(BuildContext context) {
    final editing = widget.habit != null;
    final titlePreview = _titleController.text.trim().isEmpty
        ? 'Alışkanlık adı'
        : _titleController.text.trim();
    final freqLabel = _frequency == HabitFrequency.daily ? 'Günlük' : 'Haftalık';

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.92,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Text(
                    editing ? 'Alışkanlığı düzenle' : 'Yeni alışkanlık',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(AppColors.radiusCard),
                      border: Border.all(color: AppTheme.border(context)),
                    ),
                    child: Row(
                      children: [
                        Text(_icon, style: const TextStyle(fontSize: 32)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(titlePreview, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                              Text(
                                '$freqLabel · ${editing ? 'Düzenleniyor' : 'Yeni'}',
                                style: TextStyle(fontSize: 12, color: AppTheme.muted(context)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Ad', style: _labelStyle(context)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'ör. 10 dk meditasyon'),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 24),
                  Text('İkon', style: _labelStyle(context)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppColors.habitIcons.map((icon) {
                      final selected = icon == _icon;
                      return InkWell(
                        onTap: () => setState(() => _icon = icon),
                        borderRadius: BorderRadius.circular(AppColors.radiusInput),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppColors.radiusInput),
                            border: Border.all(
                              color: selected ? AppColors.primary : AppTheme.border(context),
                            ),
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : Theme.of(context).cardTheme.color,
                          ),
                          child: Text(icon, style: const TextStyle(fontSize: 22)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Text('Renk', style: _labelStyle(context)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: AppColors.habitPalette.map((c) {
                      final selected = c == _color;
                      return GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Text('Sıklık', style: _labelStyle(context)),
                  const SizedBox(height: 8),
                  _FreqToggle(
                    value: _frequency,
                    onChanged: (f) => setState(() {
                      _frequency = f;
                      if (f != HabitFrequency.daily) _flexEnabled = false;
                    }),
                  ),
                  if (_frequency == HabitFrequency.daily) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppColors.radiusInput),
                        border: Border.all(color: AppTheme.border(context)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Esnek streak (5/7)', style: TextStyle(fontWeight: FontWeight.w500)),
                                Text(
                                  'Haftada $_flexTarget gün yeterli — seri kırılmaz',
                                  style: TextStyle(fontSize: 12, color: AppTheme.muted(context)),
                                ),
                              ],
                            ),
                          ),
                          DesignToggle(
                            value: _flexEnabled,
                            onChanged: (v) => setState(() => _flexEnabled = v),
                          ),
                        ],
                      ),
                    ),
                    if (_flexEnabled) ...[
                      const SizedBox(height: 8),
                      Slider(
                        value: _flexTarget.toDouble(),
                        min: 3,
                        max: 7,
                        divisions: 4,
                        label: '$_flexTarget/7',
                        onChanged: (v) => setState(() => _flexTarget = v.round()),
                      ),
                    ],
                  ],
                  if (_chainOptions.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Zincir', style: _labelStyle(context)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      initialValue: _chainFromId,
                      decoration: const InputDecoration(labelText: 'Tetikleyici alışkanlık'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Yok')),
                        ..._chainOptions.map(
                          (h) => DropdownMenuItem(
                            value: h.id,
                            child: Text('${h.icon} ${h.title}'),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _chainFromId = v),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.primary,
                    ),
                    child: Text(editing ? 'Kaydet' : 'Ekle'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _labelStyle(BuildContext context) =>
      const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.02);

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(
      context,
      HabitFormResult(
        title: title,
        icon: _icon,
        color: _color,
        frequency: _frequency,
        flexStreakEnabled: _flexEnabled,
        flexTargetPerWeek: _flexTarget,
        chainFromId: _chainFromId,
      ),
    );
  }
}

class _FreqToggle extends StatelessWidget {
  const _FreqToggle({required this.value, required this.onChanged});

  final HabitFrequency value;
  final ValueChanged<HabitFrequency> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(AppColors.radiusInput),
      ),
      child: Row(
        children: [
          _FreqButton(
            label: 'Günlük',
            selected: value == HabitFrequency.daily,
            onTap: () => onChanged(HabitFrequency.daily),
          ),
          _FreqButton(
            label: 'Haftalık',
            selected: value == HabitFrequency.weekly,
            onTap: () => onChanged(HabitFrequency.weekly),
          ),
        ],
      ),
    );
  }
}

class _FreqButton extends StatelessWidget {
  const _FreqButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? Theme.of(context).cardTheme.color : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        elevation: selected ? 1 : 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected ? Theme.of(context).colorScheme.onSurface : AppTheme.muted(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
