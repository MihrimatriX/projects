import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/od_card.dart';
import '../../../core/widgets/page_header.dart';
import '../../../data/database.dart';
import '../../../data/database_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _newProject = TextEditingController();

  @override
  void dispose() {
    _newProject.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final db = ref.watch(databaseProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'Ayarlar',
          subtitle: 'Pomodoro süreleri, projeler ve odak hedefleri — veriler cihazında kalır.',
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              _Section(
                title: 'Pomodoro süreleri',
                subtitle: 'Odak seansı ve mola dakikalarını özelleştir.',
                child: Column(
                  children: [
                    _NumberRow(label: 'Odak (dakika)', value: settings.workMinutes, onChanged: ref.read(settingsProvider.notifier).setWorkMinutes),
                    _NumberRow(label: 'Kısa mola (dakika)', value: settings.breakMinutes, onChanged: ref.read(settingsProvider.notifier).setBreakMinutes),
                    _NumberRow(label: 'Uzun mola (dakika)', hint: 'Her 4 seans sonrası', value: settings.longBreakMinutes, onChanged: ref.read(settingsProvider.notifier).setLongBreakMinutes),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _Section(
                title: 'Günlük hedef',
                subtitle: 'Timer özet çubuğunda gösterilir.',
                child: _NumberRow(
                  label: 'Hedef süre',
                  suffix: 'saat / gün',
                  value: settings.goalHours,
                  onChanged: ref.read(settingsProvider.notifier).setGoalHours,
                ),
              ),
              const SizedBox(height: 20),
              _Section(
                title: 'Projeler',
                subtitle: 'Renk noktası + ad — raporlarda gruplanır.',
                child: FutureBuilder(
                  future: db.getAllProjects(),
                  builder: (context, snap) {
                    final projects = snap.data ?? [];
                    return Column(
                      children: [
                        if (projects.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text('Henüz proje yok — aşağıdan ekle.', style: TextStyle(color: AppColors.textMuted)),
                          ),
                        for (var i = 0; i < projects.length; i++)
                          _ProjectRow(
                            project: projects[i],
                            colorIndex: i,
                            onRename: (name) => db.updateProject(projects[i].id, name: name),
                            // Yazma bitince yeniden kur: FutureBuilder listeyi DB'den tazeler.
                            onColor: (c) async {
                              await db.updateProject(projects[i].id, colorArgb: c);
                              if (mounted) setState(() {});
                            },
                            onDelete: () async {
                              await db.deleteProject(projects[i].id);
                              if (mounted) setState(() {});
                            },
                          ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newProject,
                                decoration: const InputDecoration(hintText: 'Yeni proje adı…'),
                                onSubmitted: (_) => _addProject(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: _addProject,
                              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                              child: const Text('Ekle'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('v1.0.0 · yerel SQLite', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addProject() async {
    final name = _newProject.text.trim();
    if (name.isEmpty) return;
    final db = ref.read(databaseProvider);
    final count = (await db.getAllProjects()).length;
    await db.insertProject(name, colorArgb: AppColors.chart[count % AppColors.chart.length].toARGB32());
    _newProject.clear();
    if (mounted) setState(() {});
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return OdCard(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.suffix,
  });

  final String label;
  final String? hint;
  final String? suffix;
  final int value;
  final Future<void> Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                if (hint != null) Text(hint!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          SizedBox(
            width: suffix != null ? 120 : 72,
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: '$value',
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Consolas'),
                    onFieldSubmitted: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n > 0) onChanged(n);
                    },
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: 8),
                  Text(suffix!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatefulWidget {
  const _ProjectRow({
    required this.project,
    required this.colorIndex,
    required this.onRename,
    required this.onColor,
    required this.onDelete,
  });

  final Project project;
  final int colorIndex;
  final Future<void> Function(String name) onRename;
  final Future<void> Function(int color) onColor;
  final VoidCallback onDelete;

  @override
  State<_ProjectRow> createState() => _ProjectRowState();
}

class _ProjectRowState extends State<_ProjectRow> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.project.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Color get _current => AppColors.projectColor(
        widget.project.colorArgb == 0 ? null : widget.project.colorArgb,
        widget.colorIndex,
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: _current, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _name,
              // Boş ad DB kısıtına (1-200 karakter) takılıp istisna fırlatırdı.
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) widget.onRename(v.trim());
              },
            ),
          ),
          const SizedBox(width: 8),
          for (final c in AppColors.chart)
            GestureDetector(
              onTap: () {
                widget.onColor(c.toARGB32());
                setState(() {});
              },
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: _current == c ? Border.all(color: AppColors.textPrimary, width: 2) : null,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }
}
