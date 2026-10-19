import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_shell.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  Note? _selected;
  String _query = '';

  Future<void> _delete(Note note) async {
    final notifier = ref.read(notesProvider.notifier);
    await notifier.remove(note.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('"${note.title}" silindi'),
          action: SnackBarAction(
            label: 'Geri al',
            onPressed: () => notifier.restore(note),
          ),
        ),
      );
  }

  String _previewSnippet(Note note) {
    final lines = note.body
        .split('\n')
        .where((l) => l.trim().isNotEmpty && !l.startsWith('#'))
        .take(4)
        .join('\n');
    return lines.isEmpty ? note.body.split('\n').first : lines;
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? AppColors.borderDark : AppColors.border;
    final wide = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      appBar: AppNav(
        active: 'notes',
        trailing: PrimaryButton(
          label: '+ Yeni',
          compact: true,
          onPressed: () => context.push('/notes/edit'),
        ),
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (notes) {
          if (notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Henüz hızlı not yok',
                    style: TextStyle(
                      color: dark ? AppColors.mutedDark : AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'İlk notu yaz',
                    onPressed: () => context.push('/notes/edit'),
                  ),
                ],
              ),
            );
          }

          // Seçimi id ile güncel listeden al: düzenlenen/silinen not eski haliyle kalmasın.
          final visible = filterNotes(notes, _query);
          final selected = visible.isEmpty
              ? null
              : visible.firstWhere(
                  (n) => n.id == _selected?.id,
                  orElse: () => visible.first,
                );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: wide ? 280 : double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: border),
                              right: wide
                                  ? BorderSide(color: border)
                                  : BorderSide.none,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(
                                'Hızlı Notlar',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: dark
                                      ? AppColors.foregroundDark
                                      : AppColors.foreground,
                                ),
                              )),
                              const SizedBox(width: 8),
                              Text(
                                _query.isEmpty
                                    ? '${notes.length} not'
                                    : '${visible.length}/${notes.length} not',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: dark
                                      ? AppColors.mutedDark
                                      : AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Notlarda ara',
                              prefixIcon: Icon(Icons.search, size: 18),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => setState(() => _query = v),
                          ),
                        ),
                        if (visible.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Eşleşen not yok',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: dark
                                    ? AppColors.mutedDark
                                    : AppColors.muted,
                              ),
                            ),
                          ),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(
                                right: wide
                                    ? BorderSide(color: border)
                                    : BorderSide.none,
                              ),
                            ),
                            child: ListView.builder(
                              itemCount: visible.length,
                              itemBuilder: (_, i) {
                                final note = visible[i];
                                final isSelected = note.id == selected?.id;
                                return _NoteRow(
                                  note: note,
                                  selected: isSelected,
                                  // Dar ekranda detay paneli yok: dokunuş notu açar.
                                  onTap: wide
                                      ? () => setState(() => _selected = note)
                                      : () => context.push('/notes/edit',
                                          extra: note),
                                  onDelete: () => _delete(note),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (wide && selected != null)
                    Expanded(
                      child: _NoteDetail(
                        note: selected,
                        snippet: _previewSnippet(selected),
                        onOpen: () =>
                            context.push('/notes/edit', extra: selected),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.note,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  final Note note;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? AppColors.borderDark : AppColors.border;
    final hover = dark ? AppColors.bgHoverDark : AppColors.bgHover;

    return Material(
      color: selected ? hover : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: border),
              left: selected
                  ? const BorderSide(color: AppColors.primary, width: 3)
                  : BorderSide.none,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  note.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color:
                        dark ? AppColors.foregroundDark : AppColors.foreground,
                  ),
                ),
              ),
              Text(
                formatNoteDate(note.updatedAt),
                style: TextStyle(
                  fontSize: 12,
                  color: dark ? AppColors.mutedDark : AppColors.muted,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: onDelete,
                tooltip: 'Sil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteDetail extends StatelessWidget {
  const _NoteDetail({
    required this.note,
    required this.snippet,
    required this.onOpen,
  });

  final Note note;
  final String snippet;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? AppColors.borderDark : AppColors.border;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Not seçin veya yeni oluşturun',
            style: TextStyle(
              color: dark ? AppColors.mutedDark : AppColors.muted,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            constraints: const BoxConstraints(maxWidth: 480),
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: dark ? AppColors.bgPreviewDark : AppColors.bgPreview,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color:
                        dark ? AppColors.foregroundDark : AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  snippet,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 15,
                    height: 1.6,
                    color: dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Editörde aç', onPressed: onOpen),
        ],
      ),
    );
  }
}
