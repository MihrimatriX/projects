import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_shell.dart';
import '../../notes/data/markdown_files.dart';
import '../../notes/data/recent_files_repository.dart';
import '../../notes/models/editor_args.dart';
import '../../notes/models/note.dart';
import '../../notes/providers/notes_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _recentRepo = RecentFilesRepository();
  List<String> _recentFiles = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final list = await _recentRepo.load();
    if (mounted) setState(() => _recentFiles = list);
  }

  void _showError(Object e) {
    if (!mounted) return;
    final msg = e is FormatException ? e.message : 'Dosya açılamadı: $e';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Web'de dosya yolu yok: içerik yeni hızlı not olarak içe aktarılır.
  Future<void> _openFile() async {
    final PickedMarkdown? picked;
    try {
      picked = await pickMarkdown();
    } catch (e) {
      _showError(e);
      return;
    }
    if (picked == null) return;
    if (picked.path != null) await _recentRepo.add(picked.path!);
    if (!mounted) return;
    await context.push(
      '/notes/edit',
      extra: EditorArgs(
        filePath: picked.path,
        initialTitle: picked.title,
        initialBody: picked.body,
      ),
    );
    await _loadRecent();
  }

  Future<void> _openRecent(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      await _recentRepo.remove(path);
      await _loadRecent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dosya bulunamadı')),
        );
      }
      return;
    }
    final String body;
    try {
      body = await readMarkdownFile(path);
    } catch (e) {
      _showError(e);
      return;
    }
    final name = path.split(Platform.pathSeparator).last;
    if (!mounted) return;
    await context.push(
      '/notes/edit',
      extra: EditorArgs(
        filePath: path,
        initialTitle: name.replaceAll(RegExp(r'\.(md|markdown|txt)$'), ''),
        initialBody: body,
      ),
    );
    await _loadRecent();
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider).value ?? [];
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? AppColors.borderDark : AppColors.border;
    final quickNotes = notes.take(5).toList();

    return Scaffold(
      appBar: const AppNav(active: 'home'),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hoş geldiniz',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.02,
                      height: 1.2,
                      color: dark ? AppColors.foregroundDark : AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yerel markdown dosyalarınızı açın veya hızlı not oluşturun.',
                    style: TextStyle(
                      fontSize: 15,
                      color: dark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      PrimaryButton(
                        label: 'Yeni not',
                        onPressed: () => context.push('/notes/edit'),
                      ),
                      GhostButton(label: 'Dosya aç…', onPressed: _openFile),
                    ],
                  ),
                  const SizedBox(height: 40),
                  const SectionTitle('Son dosyalar'),
                  if (_recentFiles.isEmpty)
                    _EmptyHint(
                      text: 'Henüz açılmış dosya yok.',
                      border: border,
                    )
                  else
                    _RecentCard(
                      paths: _recentFiles,
                      onOpen: _openRecent,
                    ),
                  const SizedBox(height: 32),
                  const SectionTitle('Hızlı notlar'),
                  if (quickNotes.isEmpty)
                    _EmptyHint(
                      text: 'Hızlı not eklemek için yeni not oluşturun.',
                      border: border,
                    )
                  else
                    ...quickNotes.map(
                      (n) => _QuickNoteTile(
                        note: n,
                        onTap: () => context.push('/notes/edit', extra: n),
                      ),
                    ),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/notes'),
                      child: const Text('Tüm notları gör →'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text, required this.border});

  final String text;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: border, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.mutedDark
              : AppColors.muted,
        ),
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.paths, required this.onOpen});

  final List<String> paths;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.surfaceDark : AppColors.surface,
        border: Border.all(
          color: dark ? AppColors.borderDark : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          for (final path in paths.take(10))
            _RecentFileRow(path: path, onOpen: () => onOpen(path)),
        ],
      ),
    );
  }
}

class _RecentFileRow extends StatelessWidget {
  const _RecentFileRow({required this.path, required this.onOpen});

  final String path;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final name = path.split(Platform.pathSeparator).last;
    final dir = shortenPath(
      path.substring(0, path.lastIndexOf(Platform.pathSeparator)),
    );
    final file = File(path);
    final modified = file.existsSync()
        ? formatRelativeTime(file.lastModifiedSync())
        : '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 20,
                color: dark ? AppColors.mutedDark : AppColors.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: dark
                            ? AppColors.foregroundDark
                            : AppColors.foreground,
                      ),
                    ),
                    Text(
                      modified.isEmpty ? dir : '$dir · $modified',
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 11,
                        color: dark ? AppColors.mutedDark : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickNoteTile extends StatelessWidget {
  const _QuickNoteTile({required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? AppColors.borderDark : AppColors.border;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(6),
          ),
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  note.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: dark
                        ? AppColors.foregroundDark
                        : AppColors.foreground,
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
            ],
          ),
        ),
      ),
    );
  }
}
