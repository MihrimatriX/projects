import 'dart:async';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/tool_registry.dart';

class TextToolsScreen extends StatefulWidget {
  const TextToolsScreen({super.key});

  @override
  State<TextToolsScreen> createState() => _TextToolsScreenState();
}

class _TextToolsScreenState extends State<TextToolsScreen> {
  static const _largeTextChars = 1024 * 1024;
  static const _isolateThreshold = 200 * 1000;
  static const _previewChars = 200 * 1000;
  static const _lastToolKey = 'last_tool_id';

  final _inputController = TextEditingController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _inputFocus = FocusNode();

  String _output = '';
  String _search = '';
  TextTool _selected = allTextTools.first;
  bool _copied = false;
  bool _warningDismissed = false;
  bool _perfWarning = false;
  bool _busy = false;
  int _transformSeq = 0;
  Timer? _debounce;
  final _collapsedCategories = <ToolCategory, bool>{};

  @override
  void initState() {
    super.initState();
    for (final c in ToolCategory.values) {
      _collapsedCategories[c] = false;
    }
    _runTransform();
    _restoreLastTool();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _inputController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  List<TextTool> get _filtered => filterTools(_search);

  Map<ToolCategory, List<TextTool>> get _grouped {
    final map = <ToolCategory, List<TextTool>>{};
    for (final t in _filtered) {
      map.putIfAbsent(t.category, () => []).add(t);
    }
    return map;
  }

  bool get _showSensitiveWarning =>
      !_warningDismissed && looksSensitive(_inputController.text);

  Future<void> _restoreLastTool() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tool = findToolById(prefs.getString(_lastToolKey) ?? '');
      if (tool == null || !mounted || tool.id == _selected.id) return;
      setState(() => _selected = tool);
      _runTransform(force: true);
    } catch (_) {
      // Tercih okunamazsa varsayılan araçla devam et.
    }
  }

  void _selectTool(TextTool tool) {
    setState(() => _selected = tool);
    _runTransform(force: true);
    SharedPreferences.getInstance()
        .then((p) => p.setString(_lastToolKey, tool.id))
        .catchError((_) => false);
  }

  void _scheduleTransform() {
    _debounce?.cancel();
    final big = _inputController.text.length > _isolateThreshold;
    _debounce = Timer(Duration(milliseconds: big ? 400 : 150), () {
      if (mounted) _runTransform();
    });
  }

  Future<void> _runTransform({bool force = false}) async {
    final input = _inputController.text;
    final tool = _selected;
    final seq = ++_transformSeq;
    final big = input.length > _largeTextChars;

    if (input.length <= _isolateThreshold) {
      setState(() {
        _perfWarning = big;
        _busy = false;
        _output = tool.transform(input);
        if (force) _warningDismissed = false;
      });
      return;
    }

    // Büyük girdi: arayüz donmasın diye ayrı isolate'te dönüştür. Bu arada
    // yeni bir tuş vuruşu gelirse eski sonuç atılır.
    setState(() {
      _perfWarning = big;
      _busy = true;
      if (force) _warningDismissed = false;
    });
    String result;
    try {
      result = await compute(tool.transform, input);
    } catch (_) {
      // Isolate başlatılamazsa (kısıtlı ortam) aynı iş parçacığında çalıştır.
      result = tool.transform(input);
    }
    if (!mounted || seq != _transformSeq) return;
    setState(() {
      _busy = false;
      _output = result;
    });
  }

  /// Çıktıyı girdiye taşır; dönüşümleri zincirlemek için (ör. JSON minify →
  /// Base64 encode).
  void _useOutputAsInput() {
    if (_output.isEmpty || isTransformError(_output, _selected) || _busy) return;
    _inputController.value = TextEditingValue(
      text: _output,
      selection: TextSelection.collapsed(offset: _output.length),
    );
    _runTransform(force: true);
  }

  String get _outputPreview => _output.length > _previewChars
      ? '${_output.substring(0, _previewChars)}\n\n… (önizleme ilk $_previewChars karakteri '
          'gösteriyor; kopyalama tam çıktıyı alır — toplam ${_output.length} karakter)'
      : _output;

  Future<void> _copyOutput() async {
    if (_output.isEmpty || isTransformError(_output, _selected) || _busy) return;
    await Clipboard.setData(ClipboardData(text: _output));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _clearInput() {
    _inputController.clear();
    _runTransform(force: true);
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    if (ctrl && shift && event.logicalKey == LogicalKeyboardKey.keyC) {
      _copyOutput();
      return KeyEventResult.handled;
    }
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyL) {
      _clearInput();
      return KeyEventResult.handled;
    }
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyF) {
      _searchFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (ctrl && shift && event.logicalKey == LogicalKeyboardKey.enter) {
      _useOutputAsInput();
      return KeyEventResult.handled;
    }
    if (ctrl && event.logicalKey == LogicalKeyboardKey.enter) {
      _runTransform(force: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final wide = width >= 900;
    final iconSidebar = width >= 600 && width < 900;
    final narrow = width < 600;
    final tokens = AppThemeTokens.of(context);

    return Focus(
      onKeyEvent: _handleKey,
      child: Scaffold(
        body: narrow
            ? _buildNarrowLayout(tokens, reduceMotion)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSidebar(tokens, wide ? 260 : 72, iconOnly: iconSidebar),
                  VerticalDivider(width: 1, color: tokens.border),
                  Expanded(child: _buildMain(tokens, reduceMotion)),
                ],
              ),
      ),
    );
  }

  Widget _buildNarrowLayout(AppThemeTokens tokens, bool reduceMotion) {
    return Column(
      children: [
        _buildToolHeader(tokens),
        if (_showSensitiveWarning) _buildWarningBanner(tokens),
        if (_perfWarning) _buildPerfBanner(tokens),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Material(
                  color: tokens.panel,
                  child: TabBar(
                    labelColor: AppColors.accent,
                    unselectedLabelColor: tokens.textMuted,
                    indicatorColor: AppColors.accent,
                    tabs: const [
                      Tab(text: 'Araçlar'),
                      Tab(text: 'Dönüştür'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildSidebar(tokens, double.infinity, iconOnly: false),
                      _buildMain(tokens, reduceMotion, embedded: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar(AppThemeTokens tokens, double width, {required bool iconOnly}) {
    return Container(
      width: width == double.infinity ? null : width,
      color: tokens.sidebar,
      child: Column(
        children: [
          if (!iconOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Araç ara…',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                tooltip: 'Araç ara (Ctrl+F)',
                icon: const Icon(Icons.search, size: 20),
                onPressed: () => _searchFocus.requestFocus(),
              ),
            ),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'Araç bulunamadı',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: tokens.textMuted,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    children: [
                      for (final entry in _grouped.entries) ...[
                        if (!iconOnly) _buildCategoryHeader(entry.key, entry.value.length, tokens),
                        if (!_collapsedCategories[entry.key]!)
                          for (final tool in entry.value)
                            _buildToolRow(tool, tokens, iconOnly: iconOnly),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(ToolCategory cat, int count, AppThemeTokens tokens) {
    final collapsed = _collapsedCategories[cat]!;
    return InkWell(
      onTap: () => setState(() => _collapsedCategories[cat] = !collapsed),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
        child: Row(
          children: [
            Icon(
              collapsed ? Icons.chevron_right : Icons.expand_more,
              size: 16,
              color: tokens.textMuted,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                cat.label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.44,
                  color: tokens.textMuted,
                ),
              ),
            ),
            Text(
              '($count)',
              style: GoogleFonts.inter(fontSize: 11, color: tokens.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolRow(TextTool tool, AppThemeTokens tokens, {required bool iconOnly}) {
    final active = _selected.id == tool.id;
    final row = Material(
      color: active ? tokens.selected : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: () => _selectTool(tool),
        borderRadius: BorderRadius.circular(6),
        hoverColor: tokens.hover,
        child: Container(
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: iconOnly ? 0 : 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: active ? AppColors.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: iconOnly
              ? Center(
                  child: Tooltip(
                    message: tool.name,
                    child: Icon(tool.category.icon, size: 20,
                        color: active ? AppColors.accent : tokens.textSecondary),
                  ),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tool.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                      color: active
                          ? Theme.of(context).colorScheme.onSurface
                          : tokens.textSecondary,
                    ),
                  ),
                ),
        ),
      ),
    );
    return Padding(padding: const EdgeInsets.only(bottom: 2), child: row);
  }

  Widget _buildMain(AppThemeTokens tokens, bool reduceMotion, {bool embedded = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!embedded) _buildToolHeader(tokens),
        if (_showSensitiveWarning) _buildWarningBanner(tokens),
        if (_perfWarning) _buildPerfBanner(tokens),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildSplitPanels(tokens, reduceMotion),
          ),
        ),
      ],
    );
  }

  Widget _buildToolHeader(AppThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _selected.name,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '● Çevrimdışı çalışır',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.success),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ayarlar',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner(AppThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: AppColors.warning.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_outlined, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hassas veri algılandı (JWT veya private key). Veriler yalnızca cihazınızda işlenir.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.warning),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: AppColors.warning,
                onPressed: () => setState(() => _warningDismissed = true),
                tooltip: 'Kapat',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerfBanner(AppThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(
        '1 milyon karakterin üzerinde metin — dönüşüm arka planda yapılır, önizleme kısaltılır.',
        style: GoogleFonts.inter(fontSize: 12, color: AppColors.warning),
      ),
    );
  }

  Widget _buildSplitPanels(AppThemeTokens tokens, bool reduceMotion) {
    final hasError = isTransformError(_output, _selected);
    final animDuration = reduceMotion ? Duration.zero : const Duration(milliseconds: 120);

    return AnimatedSwitcher(
      duration: animDuration,
      child: LayoutBuilder(
        key: ValueKey(_selected.id),
        builder: (context, constraints) {
          final vertical = constraints.maxWidth < 520;
          final panels = [
            _buildPanel(
              label: 'Girdi',
              child: Semantics(
                label: 'Girdi metni',
                child: TextField(
                  controller: _inputController,
                  focusNode: _inputFocus,
                  maxLines: null,
                  expands: true,
                  style: monoStyle(context),
                  decoration: InputDecoration(
                    hintText: 'Metninizi buraya yapıştırın…',
                    filled: true,
                    fillColor: tokens.input,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.borderFocus, width: 2),
                    ),
                  ),
                  onChanged: (_) => _scheduleTransform(),
                ),
              ),
              footer: Text(
                '${_inputController.text.length} karakter',
                style: GoogleFonts.inter(fontSize: 11, color: tokens.textMuted),
              ),
              tokens: tokens,
            ),
            _buildPanel(
              label: 'Çıktı',
              child: Semantics(
                label: 'Çıktı',
                liveRegion: hasError,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    _busy
                        ? 'İşleniyor…'
                        : _output.isEmpty
                            ? 'Çıktı burada görünür'
                            : _outputPreview,
                    style: monoStyle(context).copyWith(
                      color: hasError ? AppColors.error : null,
                    ),
                  ),
                ),
              ),
              footer: Row(
                children: [
                  if (hasError) ...[
                    const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Dönüşüm hatası',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.error),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.move_up, size: 18),
                    tooltip: 'Çıktıyı girdi yap (Ctrl+Shift+Enter)',
                    onPressed: _output.isEmpty || hasError || _busy ? null : _useOutputAsInput,
                  ),
                  const SizedBox(width: 4),
                  _buildCopyButton(),
                ],
              ),
              tokens: tokens,
            ),
          ];

          if (vertical) {
            return Column(
              children: [
                Expanded(child: panels[0]),
                Divider(height: 1, color: tokens.border),
                Expanded(child: panels[1]),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: panels[0]),
              VerticalDivider(width: 1, color: tokens.border),
              Expanded(child: panels[1]),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPanel({
    required String label,
    required Widget child,
    required Widget footer,
    required AppThemeTokens tokens,
  }) {
    return Container(
      color: tokens.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.44,
                color: tokens.textMuted,
              ),
            ),
          ),
          Divider(height: 1, color: tokens.border),
          Expanded(child: child),
          Divider(height: 1, color: tokens.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: footer,
          ),
        ],
      ),
    );
  }

  Widget _buildCopyButton() {
    final disabled = _output.isEmpty || isTransformError(_output, _selected) || _busy;
    final label = _copied ? 'Kopyalandı!' : 'Panoya Kopyala';
    final color = _copied ? AppColors.success : AppColors.accent;

    return AnimatedScale(
      scale: _copied ? 1.05 : 1,
      duration: const Duration(milliseconds: 200),
      child: OutlinedButton.icon(
        onPressed: disabled ? null : _copyOutput,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: disabled ? color.withValues(alpha: 0.3) : color),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        ),
        icon: Icon(_copied ? Icons.check : Icons.content_copy, size: 18),
        label: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
