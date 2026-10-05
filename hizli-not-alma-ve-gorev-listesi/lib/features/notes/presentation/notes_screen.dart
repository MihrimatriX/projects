import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../models/note_item.dart';
import '../providers/notes_provider.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _controller = TextEditingController();
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(quickNotesProvider);
    final brightness = Theme.of(context).brightness;
    final secondary = TextStyle(color: AppColors.secondaryTextFor(brightness));

    return notesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Notlar yüklenemedi: $e')),
      data: (notes) {
        final visible = filterNotes(notes, _query);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppLayout.pagePaddingV),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('note-input'),
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Not yaz…',
                        prefixIcon: Icon(Icons.note_outlined, size: 20),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: _add,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _add(_controller.text),
                    child: const Text('Ekle'),
                  ),
                ],
              ),
            ),
            if (notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppLayout.pagePaddingV,
                  0,
                  AppLayout.pagePaddingV,
                  AppLayout.pagePaddingV,
                ),
                child: TextField(
                  key: const Key('note-search'),
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Notlarda ara',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Aramayı temizle',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() {
                              _searchController.clear();
                              _query = '';
                            }),
                          ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            Expanded(
              child: notes.isEmpty
                  ? Center(
                      child: Text(
                        'Henüz not yok.\nHızlı fikirleri buraya yaz.',
                        textAlign: TextAlign.center,
                        style: secondary,
                      ),
                    )
                  : visible.isEmpty
                      ? Center(child: Text('"$_query" ile eşleşen not yok.', style: secondary))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppLayout.pagePaddingV,
                          ),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => _noteCard(visible[i], brightness),
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _noteCard(NoteItem n, Brightness brightness) {
    return Card(
      child: ListTile(
        onTap: () => _edit(n),
        title: Text(
          n.text,
          style: TextStyle(color: AppColors.primaryTextFor(brightness)),
        ),
        subtitle: Text(
          DateFormat.yMMMd('tr_TR').add_Hm().format(n.updatedAt),
          style: TextStyle(
            fontSize: 12,
            color: AppColors.secondaryTextFor(brightness),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Düzenle',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(n),
            ),
            IconButton(
              tooltip: 'Sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _remove(n.id),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add(String text) async {
    await ref.read(quickNotesProvider.notifier).add(text);
    _controller.clear();
  }

  Future<void> _remove(String id) async {
    final notifier = ref.read(quickNotesProvider.notifier);
    final removed = await notifier.remove(id);
    if (removed == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Not silindi'),
        action: SnackBarAction(
          label: 'Geri al',
          onPressed: () => notifier.restore(removed),
        ),
      ),
    );
  }

  Future<void> _edit(NoteItem note) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _NoteEditDialog(initial: note.text),
    );
    if (result != null) {
      await ref.read(quickNotesProvider.notifier).edit(note.id, result);
    }
  }
}

/// Denetleyicisini kendi yaşam döngüsünde tutar (kapanış animasyonunda
/// dispose edilmiş controller kullanılmasın).
class _NoteEditDialog extends StatefulWidget {
  const _NoteEditDialog({required this.initial});

  final String initial;

  @override
  State<_NoteEditDialog> createState() => _NoteEditDialogState();
}

class _NoteEditDialogState extends State<_NoteEditDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Notu düzenle'),
      content: SizedBox(
        width: 480,
        child: TextField(
          key: const Key('note-edit'),
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 10,
          keyboardType: TextInputType.multiline,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (_, v, __) => FilledButton(
            onPressed: v.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, _controller.text),
            child: const Text('Kaydet'),
          ),
        ),
      ],
    );
  }
}