import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/markdown_styles.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_shell.dart';
import '../data/markdown_files.dart';
import '../data/recent_files_repository.dart';
import '../models/editor_args.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';

enum EditorViewMode { split, edit, preview }

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({
    super.key,
    this.note,
    this.filePath,
    this.initialBody,
    this.initialTitle,
  });

  final Note? note;
  final String? filePath;
  final String? initialBody;
  final String? initialTitle;

  factory NoteEditorScreen.fromArgs(EditorArgs? args) {
    return NoteEditorScreen(
      note: args?.note,
      filePath: args?.filePath,
      initialBody: args?.initialBody,
      initialTitle: args?.initialTitle,
    );
  }

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _body;
  final _recentRepo = RecentFilesRepository();
  final _bodyFocus = FocusNode();
  late final String? _filePath = widget.filePath;
  late Note? _note = widget.note;
  late final AppLifecycleListener _lifecycle;
  EditorViewMode _mode = EditorViewMode.split;
  Timer? _autoSaveTimer;
  Future<void> _saving = Future.value();
  var _dirty = false;
  var _savedFlash = false;
  int _cursorLine = 1;
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _body = TextEditingController(
      text: widget.note?.body ??
          widget.initialBody ??
          '# Yeni not\n\nMarkdown desteklenir.',
    );
    _lastText = _body.text;
    _body.addListener(_onBodyChanged);
    // Web'de içe aktarılan dosya (yolu yok): hemen hızlı not olarak saklanır.
    if (widget.note == null && _filePath == null && widget.initialBody != null) {
      _dirty = true;
      _scheduleAutoSave();
    }
    // Pencere kapatılırken / uygulama arka plana alınırken bekleyen yazma diske
    // aktarılır; 2 sn'lik gecikme penceresinde yazılanlar kaybolmaz.
    _lifecycle = AppLifecycleListener(
      onHide: () => _flush(),
      onExitRequested: () async {
        await _flush();
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _autoSaveTimer?.cancel();
    _body.removeListener(_onBodyChanged);
    _body.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _onBodyChanged() {
    _updateCursorLine();
    // Dinleyici imleç/seçim değişince de tetiklenir; yalnızca metin değiştiyse
    // kirli say. Her metin değişiminde setState: önizleme ve sayaçlar canlı kalır.
    if (_body.text == _lastText) return;
    _lastText = _body.text;
    setState(() => _dirty = true);
    _scheduleAutoSave();
  }

  void _updateCursorLine() {
    final offset = _body.selection.baseOffset.clamp(0, _body.text.length);
    final line = '\n'.allMatches(_body.text.substring(0, offset)).length + 1;
    if (line != _cursorLine) setState(() => _cursorLine = line);
  }

  // Hem .md dosyaları hem hızlı notlar otomatik kaydedilir: her tuşta
  // zamanlayıcı yeniden kurulur, yazma son değişiklikten 2 sn sonra yapılır.
  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _flush);
  }

  /// Bekleyen değişikliği hemen yazar. Yazmalar sıraya alınır: yeni not iki kez
  /// eklenmez, eski içerik yenisinin üstüne yazılmaz.
  Future<void> _flush() {
    _autoSaveTimer?.cancel();
    return _saving = _saving.then((_) => _persist());
  }

  Future<void> _persist() async {
    if (!_dirty) return;
    final text = _body.text;
    try {
      final path = _filePath;
      if (path != null) {
        await File(path).writeAsString(text, flush: true);
        await _recentRepo.add(path);
      } else {
        final notifier = ref.read(notesProvider.notifier);
        final title = _titleForSave();
        final note = _note;
        if (note == null) {
          _note = await notifier.add(title, text);
        } else {
          await notifier.editNote(note, title: title, body: text);
        }
      }
      // Yazma sırasında yeni tuşlara basıldıysa kirli kalır (zamanlayıcı kurulu).
      if (mounted && _body.text == text) setState(() => _dirty = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydedilemedi: $e')),
        );
      }
    }
  }

  /// Ekrandan çıkmadan önce kaydeder; kayıt başarısızsa kullanıcıya sorar.
  Future<bool> _confirmLeave() async {
    await _flush();
    if (!mounted) return false;
    if (!_dirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Değişiklikler kaydedilemedi'),
        content: const Text('Çıkarsanız son değişiklikler kaybolur.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yine de çık'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _leave() async {
    if (await _confirmLeave() && mounted) context.pop();
  }

  String get _docName {
    final path = _filePath;
    if (path != null) return path.split(Platform.pathSeparator).last;
    final title = _note?.title ?? widget.initialTitle;
    if (title != null) return '$title.md';
    return 'yeni-not.md';
  }

  String? get _docDir {
    final path = _filePath;
    if (path == null) return null;
    final idx = path.lastIndexOf(Platform.pathSeparator);
    if (idx <= 0) return null;
    return path.substring(0, idx);
  }

  String _titleForSave() {
    if (widget.note != null) return widget.note!.title;
    final match = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(_body.text);
    if (match != null) return match.group(1)!.trim();
    final first = _body.text.split('\n').firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => '',
        );
    final cleaned = first.replaceAll(RegExp(r'^#+\s*'), '').trim();
    if (cleaned.isNotEmpty) return cleaned;
    return widget.initialTitle ?? 'Başlıksız';
  }

  void _wrapSelection(String before, String after, {String placeholder = 'metin'}) {
    final sel = _body.selection;
    final text = _body.text;
    // Editör hiç odaklanmadıysa seçim yoktur: metnin sonuna ekle.
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final selected = start == end ? placeholder : text.substring(start, end);
    final replaced = before + selected + after;
    _body.value = TextEditingValue(
      text: text.replaceRange(start, end, replaced),
      selection: TextSelection.collapsed(offset: start + replaced.length),
    );
  }

  // Başlık işareti imlecin olduğu yerin değil, satırın başına eklenir.
  void _insertHeading() {
    final text = _body.text;
    final sel = _body.selection;
    final cursor = sel.isValid ? sel.start : text.length;
    final lineStart = cursor == 0 ? 0 : text.lastIndexOf('\n', cursor - 1) + 1;
    final prefix = text.startsWith('#', lineStart) ? '#' : '# ';
    _body.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(offset: cursor + prefix.length),
    );
  }

  bool get _canLink {
    final sel = _body.selection;
    return sel.isValid && sel.start != sel.end;
  }

  Future<void> _save() async {
    await _flush();
    if (!mounted || _dirty) return;
    if (_filePath != null) {
      setState(() => _savedFlash = true);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _savedFlash = false);
      });
      return;
    }
    context.pop();
  }

  // Başka dosya açmadan önce mevcut belge kaydedilir; yeni belge bu ekranın yerini alır.
  Future<void> _openFile() async {
    final PickedMarkdown? picked;
    try {
      picked = await pickMarkdown();
    } catch (e) {
      if (mounted) {
        final msg = e is FormatException ? e.message : 'Dosya açılamadı: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      return;
    }
    if (picked == null || !await _confirmLeave() || !mounted) return;
    if (picked.path != null) await _recentRepo.add(picked.path!);
    if (!mounted) return;
    context.pushReplacement(
      '/notes/edit',
      extra: EditorArgs(
        filePath: picked.path,
        initialTitle: picked.title,
        initialBody: picked.body,
      ),
    );
  }

  Future<void> _export(String extension) async {
    final base = safeFileName(_docName.replaceAll(RegExp(r'\.(md|markdown|txt)$'), ''));
    final content = extension == 'html'
        ? markdownToHtmlDocument(base, _body.text)
        : _body.text;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (kIsWeb) {
        await Clipboard.setData(ClipboardData(text: content));
        messenger.showSnackBar(
          SnackBar(content: Text('Web\'de dosya kaydı yok; ${extension.toUpperCase()} panoya kopyalandı')),
        );
        return;
      }
      final path = await exportText(
        fileName: '$base.$extension',
        content: content,
        extension: extension,
      );
      if (path != null) {
        messenger.showSnackBar(SnackBar(content: Text('Dışa aktarıldı: $path')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Dışa aktarılamadı: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final effectiveMode = width < 600 && _mode == EditorViewMode.split
        ? EditorViewMode.edit
        : _mode;
    final dir = _docDir;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
          const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
              _wrapSelection('**', '**'),
          const SingleActivator(LogicalKeyboardKey.keyI, control: true): () =>
              _wrapSelection('*', '*'),
        },
        child: Scaffold(
          backgroundColor: dark ? AppColors.bgEditorDark : AppColors.bgEditor,
          body: Column(
            children: [
              _TitleBar(
                docName: _docName,
                docPath: dir == null ? null : shortenPath(dir),
                dirty: _dirty,
                mode: effectiveMode,
                onModeChanged: (m) => setState(() => _mode = m),
                hideSplit: width < 600,
                onBack: _leave,
              ),
              _FormatToolbar(
                canLink: _canLink,
                savedFlash: _savedFlash,
                onBold: () => _wrapSelection('**', '**'),
                onItalic: () => _wrapSelection('*', '*'),
                onCode: () => _wrapSelection('`', '`'),
                onH1: _insertHeading,
                onLink: () => _wrapSelection('[', '](url)'),
                onOpen: _openFile,
                onExport: _export,
                onSave: _save,
              ),
              Expanded(
                child: _SplitView(
                  mode: effectiveMode,
                  width: width,
                  editor: _EditorPane(controller: _body, focusNode: _bodyFocus),
                  preview: MarkdownPreview(
                    markdown: _body.text,
                    dark: dark,
                    baseDirectory: dir,
                  ),
                ),
              ),
              _StatusBar(
                words: countWords(_body.text),
                minutes: readingMinutes(_body.text),
                line: _cursorLine,
                dirty: _dirty,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.docName,
    required this.docPath,
    required this.dirty,
    required this.mode,
    required this.onModeChanged,
    required this.hideSplit,
    required this.onBack,
  });

  final String docName;
  final String? docPath;
  final bool dirty;
  final EditorViewMode mode;
  final ValueChanged<EditorViewMode> onModeChanged;
  final bool hideSplit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? AppColors.borderDark : AppColors.border;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: dark ? AppColors.bgToolbarDark : AppColors.bgToolbar,
        border: Border(bottom: BorderSide(color: border)),
        boxShadow: [
          BoxShadow(
            color: border.withValues(alpha: 0.5),
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 18),
            onPressed: onBack,
            tooltip: 'Geri',
          ),
          if (dirty)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 10),
              decoration: const BoxDecoration(
                color: AppColors.unsaved,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            docName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: dark ? AppColors.foregroundDark : AppColors.foreground,
            ),
          ),
          if (docPath != null) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                docPath!,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 11,
                  color: dark ? AppColors.mutedDark : AppColors.muted,
                ),
              ),
            ),
          ],
          const Spacer(),
          _ModeSwitcher(
            mode: mode,
            hideSplit: hideSplit,
            onChanged: onModeChanged,
          ),
        ],
      ),
    );
  }
}

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({
    required this.mode,
    required this.hideSplit,
    required this.onChanged,
  });

  final EditorViewMode mode;
  final bool hideSplit;
  final ValueChanged<EditorViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? AppColors.borderDark : AppColors.border;
    final bg = dark ? AppColors.bgEditorDark : AppColors.bg;

    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hideSplit)
            _ModeTab(
              label: 'Bölünmüş',
              selected: mode == EditorViewMode.split,
              onTap: () => onChanged(EditorViewMode.split),
            ),
          _ModeTab(
            label: 'Düzenle',
            selected: mode == EditorViewMode.edit,
            onTap: () => onChanged(EditorViewMode.edit),
          ),
          _ModeTab(
            label: 'Önizle',
            selected: mode == EditorViewMode.preview,
            onTap: () => onChanged(EditorViewMode.preview),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected
                    ? AppColors.primary
                    : (dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary),
              ),
            ),
            if (selected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                height: 2,
                width: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FormatToolbar extends StatelessWidget {
  const _FormatToolbar({
    required this.canLink,
    required this.savedFlash,
    required this.onBold,
    required this.onItalic,
    required this.onCode,
    required this.onH1,
    required this.onLink,
    required this.onOpen,
    required this.onExport,
    required this.onSave,
  });

  final bool canLink;
  final bool savedFlash;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onCode;
  final VoidCallback onH1;
  final VoidCallback onLink;
  final VoidCallback onOpen;
  final ValueChanged<String> onExport;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? AppColors.borderDark : AppColors.border;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: dark ? AppColors.bgToolbarDark : AppColors.bgToolbar,
        border: Border(bottom: BorderSide(color: border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _TbBtn(icon: Icons.format_bold, tooltip: 'Kalın', onPressed: onBold),
          _TbBtn(icon: Icons.format_italic, tooltip: 'İtalik', onPressed: onItalic),
          _TbBtn(icon: Icons.code, tooltip: 'Kod', onPressed: onCode),
          _Divider(hover: border),
          _TbBtn(label: 'H1', tooltip: 'Başlık', onPressed: onH1),
          _TbBtn(
            icon: Icons.link,
            tooltip: 'Link',
            onPressed: canLink ? onLink : null,
          ),
          const Spacer(),
          GhostButton(label: 'Aç', compact: true, onPressed: onOpen),
          PopupMenuButton<String>(
            tooltip: 'Dışa aktar',
            icon: const Icon(Icons.ios_share, size: 16),
            onSelected: onExport,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'md', child: Text('Markdown (.md)')),
              PopupMenuItem(value: 'html', child: Text('HTML (.html)')),
            ],
          ),
          const SizedBox(width: 8),
          AnimatedScale(
            scale: savedFlash ? 0.96 : 1,
            duration: const Duration(milliseconds: 150),
            child: PrimaryButton(label: 'Kaydet', compact: true, onPressed: onSave),
          ),
        ],
      ),
    );
  }
}

class _TbBtn extends StatelessWidget {
  const _TbBtn({
    this.icon,
    this.label,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData? icon;
  final String? label;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: label != null
            ? Text(label!, style: const TextStyle(fontSize: 14))
            : Icon(icon, size: 16),
        style: IconButton.styleFrom(
          minimumSize: const Size(32, 32),
          maximumSize: const Size(32, 32),
          disabledForegroundColor:
              (dark ? AppColors.mutedDark : AppColors.muted).withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.hover});
  final Color hover;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: hover,
    );
  }
}

class _SplitView extends StatelessWidget {
  const _SplitView({
    required this.mode,
    required this.width,
    required this.editor,
    required this.preview,
  });

  final EditorViewMode mode;
  final double width;
  final Widget editor;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    if (mode == EditorViewMode.edit) return editor;
    if (mode == EditorViewMode.preview) return preview;

    final editorFlex = width >= 900 ? 1 : (width >= 600 ? 4 : 1);
    final previewFlex = width >= 900 ? 1 : (width >= 600 ? 6 : 1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: editorFlex, child: editor),
        VerticalDivider(
          width: 1,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.borderDark
              : AppColors.border,
        ),
        Expanded(flex: previewFlex, child: preview),
      ],
    );
  }
}

class _EditorPane extends StatelessWidget {
  const _EditorPane({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return ColoredBox(
      color: dark ? AppColors.bgEditorDark : AppColors.bgEditor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: null,
            expands: true,
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 16,
              height: 1.75,
              color: dark ? AppColors.foregroundDark : AppColors.foreground,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            ),
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
          ),
        ),
      ),
    );
  }
}

class MarkdownPreview extends StatelessWidget {
  const MarkdownPreview({
    super.key,
    required this.markdown,
    required this.dark,
    this.baseDirectory,
  });

  final String markdown;
  final bool dark;

  /// Açık dosyanın klasörü: `![](resim.png)` gibi göreli görseller buradan yüklenir.
  final String? baseDirectory;

  @override
  Widget build(BuildContext context) {
    final body = stripFrontMatter(markdown);
    final dir = baseDirectory;
    return ColoredBox(
      color: dark ? AppColors.bgPreviewDark : AppColors.bgPreview,
      child: Markdown(
        data: body.trim().isEmpty ? '*Önizleme boş*' : body,
        styleSheet: markdownStyleSheet(context, dark: dark),
        // flutter_markdown görsel yolunu `imageDirectory + yol` ile Uri'ye çevirir;
        // düz Windows yolu (C:\...) geçersiz Uri olur, bu yüzden file:/// biçimi.
        imageDirectory: dir == null || kIsWeb
            ? null
            : Uri.directory(dir, windows: Platform.isWindows).toString(),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.words,
    required this.minutes,
    required this.line,
    required this.dirty,
  });

  final int words;
  final int minutes;
  final int line;
  final bool dirty;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? AppColors.borderDark : AppColors.border;

    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: dark ? AppColors.bgToolbarDark : AppColors.bgToolbar,
        border: Border(top: BorderSide(color: border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            '$words kelime',
            style: _mono(dark),
          ),
          const SizedBox(width: 16),
          Text(
            '$minutes dk okuma',
            style: _mono(dark),
          ),
          const SizedBox(width: 16),
          Text('Satır $line', style: _mono(dark)),
          const Spacer(),
          Text(
            dirty ? 'Kaydedilmedi' : 'Kaydedildi',
            style: _mono(dark),
          ),
        ],
      ),
    );
  }

  TextStyle _mono(bool dark) => TextStyle(
        fontFamily: 'Consolas',
        fontSize: 11,
        color: dark ? AppColors.mutedDark : AppColors.muted,
      );
}
