import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/od_card.dart';
import '../../../core/widgets/page_header.dart';
import '../../../data/database_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _day = DateTime.now();
  Duration _total = Duration.zero;
  Map<int, Duration> _byProject = {};
  Map<int, String> _names = {};
  Map<int, int> _colors = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = ref.read(databaseProvider);
    final total = await db.dayTotal(_day);
    final byProject = await db.dayByProject(_day);
    final projects = await db.getAllProjects();
    if (!mounted) return;
    setState(() {
      _total = total;
      _byProject = byProject;
      _names = {for (final p in projects) p.id: p.name};
      _colors = {for (final p in projects) p.id: p.colorArgb};
      _loading = false;
    });
  }

  Color _color(int projectId, int index) =>
      AppColors.projectColor(_colors[projectId] == 0 ? null : _colors[projectId], index);

  Future<void> _exportCsv() async {
    final db = ref.read(databaseProvider);
    final entries = await db.getDayEntriesForExport(_day);
    if (entries.isEmpty) {
      _toast('Export için kayıt gerekli');
      return;
    }
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    final buf = StringBuffer('proje,baslangic,bitis,dakika\n');
    for (final e in entries) {
      final name = (_names[e.projectId] ?? 'Proje ${e.projectId}').replaceAll('"', '""');
      final mins = e.endedAt!.difference(e.startedAt).inMinutes;
      buf.writeln('"$name",${fmt.format(e.startedAt)},${fmt.format(e.endedAt!)},$mins');
    }
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'odaklanma-${DateFormat('yyyy-MM-dd').format(_day)}.csv';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(buf.toString());
    _toast('CSV kaydedildi: ${file.path}');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _shiftDay(int delta) {
    setState(() => _day = DateTime(_day.year, _day.month, _day.day + delta));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final label = DateFormat.yMMMEd('tr').format(_day);
    final entries = _byProject.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxMin = entries.isEmpty ? 1.0 : entries.first.value.inMinutes.toDouble().clamp(1, double.infinity);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _shiftDay(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _shiftDay(1),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Raporlar',
              subtitle: 'Günlük proje dağılımı — yerel SQLite verisinden.',
            ),
            Row(
              children: [
                IconButton(onPressed: () => _shiftDay(-1), icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ),
                IconButton(onPressed: () => _shiftDay(1), icon: const Icon(Icons.chevron_right)),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: entries.isEmpty ? null : _exportCsv,
                  icon: const Icon(Icons.download, size: 20),
                  label: const Text('CSV Export'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
            else ...[
              OdCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Proje dağılımı', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Text(formatDurationTr(_total), style: const TextStyle(fontFamily: 'Consolas', fontSize: 14, color: AppColors.accent)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (entries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: Text('Bugün kayıt yok', style: TextStyle(color: AppColors.textMuted))),
                      )
                    else
                      SizedBox(
                        height: 160,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < entries.length; i++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        formatDurationTr(entries[i].value),
                                        style: const TextStyle(fontFamily: 'Consolas', fontSize: 10, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: FractionallySizedBox(
                                            heightFactor: entries[i].value.inMinutes / maxMin,
                                            child: Container(
                                              width: double.infinity,
                                              constraints: const BoxConstraints(maxWidth: 48),
                                              decoration: BoxDecoration(
                                                color: _color(entries[i].key, i),
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        (_names[entries[i].key] ?? '?').split('-').first,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < entries.length; i++)
                    OdCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: _color(entries[i].key, i), shape: BoxShape.circle)),
                          const SizedBox(width: 12),
                          Text(_names[entries[i].key] ?? '?', style: const TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(width: 16),
                          Text(formatDurationTr(entries[i].value), style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
