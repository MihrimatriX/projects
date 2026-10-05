import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../data/palette_history_repository.dart';
import '../domain/palette_core.dart';
import '../services/image_source_service.dart';
import 'widgets/app_backdrop.dart';
import 'widgets/app_logo.dart';

class PaletteScreen extends StatefulWidget {
  const PaletteScreen({super.key});

  @override
  State<PaletteScreen> createState() => _PaletteScreenState();
}

class _PaletteScreenState extends State<PaletteScreen> {
  HarmonicMode _mode = HarmonicMode.complementary;
  List<PaletteSlot> _slots = PaletteCore.initialPalette(HarmonicMode.complementary);
  int _selectedIndex = 0;
  bool _historyOpen = false;
  bool _generating = false;
  String _exportTab = 'css';
  ExtractedTheme? _extractedTheme;
  List<PaletteHistoryEntry> _history = [];

  final _historyRepo = PaletteHistoryRepository();
  final _imageSources = ImageSourceService();
  final _exportCodeCtrl = TextEditingController();
  final _focusNode = FocusNode();

  ExtractedTheme get _theme => _extractedTheme ?? _defaultTheme;
  String get _baseColorHex => PaletteCore.colorToHex(_theme.bgApp);

  static const _defaultTheme = ExtractedTheme(
    bgApp: AppColors.bg,
    bgPanel: AppColors.bgPanel,
    bgElevated: AppColors.bgElevated,
    bgHover: AppColors.bgHover,
    border: AppColors.border,
    borderFocus: AppColors.accent,
    textPrimary: AppColors.foreground,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.muted,
    accent: AppColors.accent,
    isDark: true,
  );

  @override
  void initState() {
    super.initState();
    // Önce yaz, sonra oku: ikisi paralel çalışınca liste ilk palet olmadan yükleniyordu.
    _saveHistory(force: true);
  }

  @override
  void dispose() {
    _exportCodeCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final h = await _historyRepo.load();
    if (mounted) setState(() => _history = h);
  }

  bool get _allLocked => _slots.every((s) => s.locked);

  bool get _allContrastFail =>
      _slots.every((s) => PaletteCore.contrastBadge(s.hex, _baseColorHex).level == ContrastLevel.fail);

  void _saveHistory({bool force = false}) {
    _historyRepo.add(_slots.map((s) => s.hex).toList(), force: force).then((_) => _loadHistory());
  }

  void _regenerate() {
    if (_allLocked) {
      _toast('En az bir slot kilitsiz olmalı', ToastType.warn);
      return;
    }
    setState(() => _slots = PaletteCore.regenerateUnlocked(_slots, _mode));
    _saveHistory();
  }

  void _toggleLock([int? index]) {
    final i = index ?? _selectedIndex;
    setState(() {
      _slots = List.of(_slots);
      _slots[i] = _slots[i].copyWith(locked: !_slots[i].locked);
    });
  }

  void _selectSlot(int i) => setState(() => _selectedIndex = i);

  Future<void> _copyHex(String hex) async {
    await Clipboard.setData(ClipboardData(text: hex));
    _toast('HEX panoya kopyalandı: $hex');
  }

  /// Seçili (ya da verilen) slota elle HEX girer; girilen renk kilitlenir ki
  /// yeni palet üretiminde kaybolmasın.
  Future<void> _editHex([int? index]) async {
    final i = index ?? _selectedIndex;
    final ctrl = TextEditingController(text: _slots[i].hex);
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Theme(
        data: _buildTheme(),
        child: StatefulBuilder(
          builder: (ctx, setLocal) {
            void submit() {
              final hex = PaletteCore.normalizeHex(ctrl.text);
              if (hex == null) {
                setLocal(() => error = 'Geçerli bir HEX girin (ör. #3B82F6 veya #38F)');
              } else {
                Navigator.pop(ctx, hex);
              }
            }

            return AlertDialog(
              title: Text('Renk ${i + 1} — HEX düzenle'),
              content: TextField(
                key: const Key('hex-input'),
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(hintText: '#RRGGBB', errorText: error),
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
                FilledButton(onPressed: submit, child: const Text('Uygula')),
              ],
            );
          },
        ),
      ),
    );
    // ctrl burada dispose edilmez: diyalog kapanış animasyonu hâlâ kullanıyor.
    if (result == null || !mounted) return;
    setState(() {
      _slots = List.of(_slots);
      _slots[i] = PaletteSlot(hex: result, locked: true);
      _selectedIndex = i;
    });
    _saveHistory();
  }

  void _setMode(HarmonicMode mode) {
    if (mode == _mode) return;
    final prev = _mode;
    setState(() => _mode = mode);
    if (prev != mode && !_allLocked) {
      setState(() => _slots = PaletteCore.regenerateUnlocked(_slots, _mode));
      _saveHistory();
    }
  }

  void _openExport([String? tab]) {
    _exportTab = tab ?? 'css';
    final warn = _slots.any((s) => PaletteCore.contrastBadge(s.hex, _baseColorHex).level == ContrastLevel.fail);
    _exportCodeCtrl.text = PaletteCore.export(
      _exportTab,
      _slots,
      warning: warn ? 'Uyarı: bazı renkler taban arka plana karşı düşük kontrast' : null,
    );
    _showDialog(_ExportDialog(
      tab: _exportTab,
      controller: _exportCodeCtrl,
      theme: _theme,
      onTab: (t) {
        Navigator.pop(context);
        _openExport(t);
      },
      onCopy: () async {
        await Clipboard.setData(ClipboardData(text: _exportCodeCtrl.text));
        _toast('Panoya kopyalandı');
      },
    ));
  }

  void _toggleHistory() {
    setState(() => _historyOpen = !_historyOpen);
    if (_historyOpen) _loadHistory();
  }

  void _loadHistoryPalette(PaletteHistoryEntry entry) {
    setState(() {
      _slots = entry.colors.take(PaletteCore.slotCount).toList().asMap().entries.map((e) {
        final locked = e.key < _slots.length ? _slots[e.key].locked : false;
        return PaletteSlot(hex: e.value, locked: locked);
      }).toList();
      while (_slots.length < PaletteCore.slotCount) {
        _slots.add(PaletteSlot(hex: entry.colors.last));
      }
    });
    _toast('Palet yüklendi');
  }

  Future<void> _openExtract() async {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final sheet = _ExtractSheet(
      theme: _theme,
      imageSources: _imageSources,
      isMobile: isMobile,
      onProcess: (bytes) async {
        setState(() => _generating = true);
        try {
          return PaletteCore.extractThemeAndPalette(bytes);
        } finally {
          if (mounted) setState(() => _generating = false);
        }
      },
      onApply: (result, autoApply) {
        if (result.palette.isEmpty) return;
        setState(() {
          _slots = PaletteCore.applyColorsToSlots(_slots, result.palette);
          if (autoApply && result.theme != null) _extractedTheme = result.theme;
        });
        _saveHistory();
        _toast(autoApply && result.theme != null ? 'Tema ve palet uygulandı' : 'Palet uygulandı');
      },
    );

    if (isMobile) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Theme(data: _buildTheme(), child: sheet),
      );
    } else {
      await _showDialog(sheet);
    }
  }

  void _showShortcuts() {
    _showDialog(_ShortcutsDialog(theme: _theme));
  }

  Future<void> _showDialog(Widget child) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => Theme(
        data: _buildTheme(),
        child: child,
      ),
    );
  }

  void _toast(String msg, [ToastType type = ToastType.success]) {
    final color = switch (type) {
      ToastType.success => AppColors.passAa,
      ToastType.error => AppColors.failContrast,
      ToastType.warn => AppColors.warning,
    };
    final textColor = type == ToastType.warn ? Colors.black : Colors.white;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 96),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.space) {
      _regenerate();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyL) {
      _toggleLock();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter) {
      _copyHex(_slots[_selectedIndex].hex);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit1) {
      _selectSlot(0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit2) {
      _selectSlot(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit3) {
      _selectSlot(2);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit4) {
      _selectSlot(3);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit5) {
      _selectSlot(4);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyC) {
      _openExport('css');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyT) {
      _openExport('tailwind');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyE) {
      _editHex();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyH) {
      _toggleHistory();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyI) {
      _openExtract();
      return KeyEventResult.handled;
    }
    if (event.character == '?') {
      _showShortcuts();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  ThemeData _buildTheme() => AppTheme.fromExtracted(_theme);

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    AppTheme.applySystemChrome(t);
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return Theme(
      data: _buildTheme(),
      child: Focus(
        focusNode: _focusNode,
        autofocus: !isMobile,
        onKeyEvent: _onKey,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: AppBackdrop(
            theme: t,
            child: isMobile ? _buildMobileBody(t) : _buildDesktopBody(t),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopBody(ExtractedTheme t) {
    return Column(
      children: [
        _TitleBar(theme: t),
        _AppHeader(
          theme: t,
          mode: _mode,
          allLocked: _allLocked,
          historyOpen: _historyOpen,
          onMode: _setMode,
          onExtract: _openExtract,
          onHistory: _toggleHistory,
          onExport: () => _openExport('css'),
        ),
        if (_allContrastFail) _ContrastBanner(theme: t),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: t.border.withValues(alpha: 0.8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _PaletteStrip(
                  theme: t,
                  slots: _slots,
                  selectedIndex: _selectedIndex,
                  baseHex: _baseColorHex,
                  generating: _generating,
                  onSelect: _selectSlot,
                  onToggleLock: _toggleLock,
                  onCopyHex: _copyHex,
                  onEdit: _editHex,
                ),
              ),
            ),
          ),
        ),
        _BottomToolbar(
          theme: t,
          allLocked: _allLocked,
          onRegenerate: _regenerate,
          onCss: () => _openExport('css'),
          onTailwind: () => _openExport('tailwind'),
          onShortcuts: _showShortcuts,
        ),
        if (_historyOpen) _HistoryRail(theme: t, history: _history, onSelect: _loadHistoryPalette),
      ],
    );
  }

  Widget _buildMobileBody(ExtractedTheme t) {
    return SafeArea(
      child: Column(
        children: [
          _MobileTopBar(
            theme: t,
            locked: _slots[_selectedIndex].locked,
            onExtract: _openExtract,
            onLock: () => _toggleLock(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.bgElevated.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: t.border),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(4),
                child: _HarmonicPicker(theme: t, mode: _mode, disabled: _allLocked, onMode: _setMode),
              ),
            ),
          ),
          if (_allContrastFail)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _ContrastBanner(theme: t, compact: true),
            ),
          Expanded(
            child: _MobilePaletteStack(
              theme: t,
              slots: _slots,
              selectedIndex: _selectedIndex,
              baseHex: _baseColorHex,
              generating: _generating,
              onSelect: _selectSlot,
              onToggleLock: _toggleLock,
              onCopyHex: _copyHex,
              onEdit: _editHex,
            ),
          ),
          if (_historyOpen) _HistoryRail(theme: t, history: _history, onSelect: _loadHistoryPalette),
          _MobileBottomBar(
            theme: t,
            allLocked: _allLocked,
            historyOpen: _historyOpen,
            onHistory: _toggleHistory,
            onRegenerate: _regenerate,
            onExport: () => _openExport('css'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Dokun: seç · seçiliye dokun: HEX düzenle · çift dokun: kopyala · uzun bas: kilitle',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: t.textMuted, letterSpacing: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

enum ToastType { success, error, warn }

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.theme});

  final ExtractedTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.bgPanel,
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: Row(
        children: [
          const AppLogo(size: 16, radius: 4),
          const SizedBox(width: 10),
          Text(
            'Palet Üretici',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.textSecondary),
          ),
          const Spacer(),
          const Row(
            children: [
              _WinDot(Color(0xFFEAB308)),
              SizedBox(width: 8),
              _WinDot(Color(0xFF22C55E)),
              SizedBox(width: 8),
              _WinDot(Color(0xFFEF4444)),
            ],
          ),
        ],
      ),
    );
  }
}

class _WinDot extends StatelessWidget {
  const _WinDot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({
    required this.theme,
    required this.mode,
    required this.allLocked,
    required this.historyOpen,
    required this.onMode,
    required this.onExtract,
    required this.onHistory,
    required this.onExport,
  });

  final ExtractedTheme theme;
  final HarmonicMode mode;
  final bool allLocked;
  final bool historyOpen;
  final ValueChanged<HarmonicMode> onMode;
  final VoidCallback onExtract;
  final VoidCallback onHistory;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.border))),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HarmonicPicker(theme: theme, mode: mode, disabled: allLocked, onMode: onMode),
              const SizedBox(width: 12),
              _ToolbarBtn(
                  theme: theme, icon: Icons.photo_camera_outlined, onPressed: onExtract, tooltip: 'Görselden tema (I)'),
              const SizedBox(width: 8),
              _ToolbarBtn(
                theme: theme,
                icon: Icons.history,
                onPressed: onHistory,
                tooltip: 'Geçmiş (H)',
                primary: historyOpen,
              ),
              const SizedBox(width: 8),
              _ToolbarBtn(
                theme: theme,
                icon: Icons.download_outlined,
                label: 'Dışa aktar',
                onPressed: onExport,
                tooltip: 'Dışa aktar (C)',
                filled: true,
              ),
            ],
          );

          if (constraints.maxWidth < 900) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBrandTitle(theme: theme, compact: true),
                const SizedBox(height: 12),
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: actions),
              ],
            );
          }

          return Row(
            children: [
              AppBrandTitle(theme: theme),
              const Spacer(),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _HarmonicPicker extends StatelessWidget {
  const _HarmonicPicker({
    required this.theme,
    required this.mode,
    required this.disabled,
    required this.onMode,
  });

  final ExtractedTheme theme;
  final HarmonicMode mode;
  final bool disabled;
  final ValueChanged<HarmonicMode> onMode;

  @override
  Widget build(BuildContext context) {
    const modes = [
      (HarmonicMode.complementary, 'Tamamlayıcı'),
      (HarmonicMode.analogous, 'Analog'),
      (HarmonicMode.triadic, 'Üçlü'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.bgElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.border.withValues(alpha: 0.9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: modes.map((m) {
          final selected = mode == m.$1;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Material(
              color: selected ? theme.accent.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: disabled ? null : () => onMode(m.$1),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text(
                    m.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selected ? theme.accent : theme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  const _ToolbarBtn({
    required this.theme,
    required this.icon,
    required this.onPressed,
    this.label,
    this.tooltip,
    this.filled = false,
    this.primary = false,
  });

  final ExtractedTheme theme;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;
  final String? tooltip;
  final bool filled;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final bg = filled || primary ? (filled ? theme.accent : theme.accent.withValues(alpha: 0.15)) : theme.bgElevated;
    final fg = filled ? Colors.white : (primary ? theme.accent : theme.textPrimary);
    final border = filled ? theme.accent : theme.border;

    final btn = Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: border),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: label != null ? 14 : 10, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: fg),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(label!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

class _ContrastBanner extends StatelessWidget {
  const _ContrastBanner({required this.theme, this.compact = false});
  final ExtractedTheme theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      children: [
        const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Bazı renkler taban arka plana karşı düşük kontrast — export\'ta uyarı eklenecek',
            style: TextStyle(fontSize: compact ? 12 : 13, color: AppColors.warning),
          ),
        ),
      ],
    );
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: child,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        border: Border(bottom: BorderSide(color: AppColors.warning.withValues(alpha: 0.3))),
      ),
      child: child,
    );
  }
}

class _PaletteStrip extends StatelessWidget {
  const _PaletteStrip({
    required this.theme,
    required this.slots,
    required this.selectedIndex,
    required this.baseHex,
    required this.generating,
    required this.onSelect,
    required this.onToggleLock,
    required this.onCopyHex,
    required this.onEdit,
  });

  final ExtractedTheme theme;
  final List<PaletteSlot> slots;
  final int selectedIndex;
  final String baseHex;
  final bool generating;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onToggleLock;
  final ValueChanged<String> onCopyHex;
  final ValueChanged<int> onEdit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: List.generate(slots.length, (i) {
            final slot = slots[i];
            final badge = PaletteCore.contrastBadge(slot.hex, baseHex);
            final textColor = PaletteCore.textColorForBg(slot.hex);
            final rgb = PaletteCore.hexToRgb(slot.hex);
            final hsl = PaletteCore.hexToHsl(slot.hex);
            final selected = i == selectedIndex;

            return Expanded(
              child: _ColorBlock(
                hex: slot.hex,
                locked: slot.locked,
                selected: selected,
                generating: generating,
                badge: badge,
                textColor: textColor,
                rgbHint: 'rgb(${rgb.r}, ${rgb.g}, ${rgb.b})\nhsl(${hsl.h}, ${hsl.s}%, ${hsl.l}%)',
                onTap: () => i == selectedIndex ? onEdit(i) : onSelect(i),
                onDoubleTap: () => onCopyHex(slot.hex),
                onLongPress: () => onToggleLock(i),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ColorBlock extends StatefulWidget {
  const _ColorBlock({
    required this.hex,
    required this.locked,
    required this.selected,
    required this.generating,
    required this.badge,
    required this.textColor,
    required this.rgbHint,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
  });

  final String hex;
  final bool locked;
  final bool selected;
  final bool generating;
  final ContrastBadge badge;
  final Color textColor;
  final String rgbHint;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;

  @override
  State<_ColorBlock> createState() => _ColorBlockState();
}

class _ColorBlockState extends State<_ColorBlock> {
  bool _hovered = false;

  Color get _badgeColor => switch (widget.badge.level) {
        ContrastLevel.aaa => AppColors.passAaa,
        ContrastLevel.aa => AppColors.passAa,
        ContrastLevel.warn => Colors.transparent,
        ContrastLevel.fail => AppColors.failContrast,
      };

  @override
  Widget build(BuildContext context) {
    final color = PaletteCore.hexToColor(widget.hex);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: widget.generating ? Duration.zero : const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: color,
            border: Border(
              right: BorderSide(color: Colors.black.withValues(alpha: 0.15)),
              bottom: widget.selected ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
            ),
          ),
          child: Stack(
            children: [
              if (_hovered)
                Positioned.fill(
                  child: ColoredBox(color: Colors.white.withValues(alpha: 0.04)),
                ),
              if (widget.locked)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Icon(Icons.lock, size: 20, color: widget.textColor.withValues(alpha: 0.95)),
                ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.badge.level == ContrastLevel.warn ? Colors.transparent : _badgeColor,
                    borderRadius: BorderRadius.circular(999),
                    border: widget.badge.level == ContrastLevel.warn ? Border.all(color: AppColors.warning) : null,
                  ),
                  child: Text(
                    widget.badge.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: widget.badge.level == ContrastLevel.warn ? AppColors.warning : Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.hex,
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: widget.textColor,
                        shadows: const [Shadow(blurRadius: 4, color: Colors.black45)],
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: _hovered ? 0.9 : 0,
                      duration: const Duration(milliseconds: 120),
                      child: Text(
                        widget.rgbHint,
                        style: TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 12,
                          color: widget.textColor,
                          height: 1.35,
                          shadows: const [Shadow(blurRadius: 3, color: Colors.black54)],
                        ),
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

class _BottomToolbar extends StatelessWidget {
  const _BottomToolbar({
    required this.theme,
    required this.allLocked,
    required this.onRegenerate,
    required this.onCss,
    required this.onTailwind,
    required this.onShortcuts,
  });

  final ExtractedTheme theme;
  final bool allLocked;
  final VoidCallback onRegenerate;
  final VoidCallback onCss;
  final VoidCallback onTailwind;
  final VoidCallback onShortcuts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.bgPanel,
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onShortcuts,
              child: Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 13, color: theme.textMuted),
                  children: [
                    const TextSpan(text: ' '),
                    _kbd('Boşluk', theme),
                    const TextSpan(text: ' yeni palet · '),
                    _kbd('L', theme),
                    const TextSpan(text: ' kilitle · '),
                    _kbd('Enter', theme),
                    const TextSpan(text: ' HEX kopyala · '),
                    _kbd('?', theme),
                    const TextSpan(text: ' kısayollar'),
                  ],
                ),
              ),
            ),
          ),
          _ToolbarBtn(
              theme: theme, icon: Icons.refresh, label: 'Yeni palet', onPressed: allLocked ? null : onRegenerate),
          const SizedBox(width: 10),
          _ToolbarBtn(theme: theme, icon: Icons.code, label: 'CSS :root', onPressed: onCss),
          const SizedBox(width: 10),
          _ToolbarBtn(
              theme: theme, icon: Icons.integration_instructions_outlined, label: 'Tailwind', onPressed: onTailwind),
        ],
      ),
    );
  }

  InlineSpan _kbd(String text, ExtractedTheme theme) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: theme.bgElevated,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.border),
        ),
        child: Text(text, style: const TextStyle(fontFamily: 'Consolas', fontSize: 11, letterSpacing: 0.5)),
      ),
    );
  }
}

class _HistoryRail extends StatelessWidget {
  const _HistoryRail({required this.theme, required this.history, required this.onSelect});

  final ExtractedTheme theme;
  final List<PaletteHistoryEntry> history;
  final ValueChanged<PaletteHistoryEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: theme.bgApp,
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: history.isEmpty
          ? Center(child: Text('Henüz kaydedilmiş palet yok', style: TextStyle(color: theme.textMuted, fontSize: 13)))
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final entry = history[i];
                return _HistoryCard(theme: theme, entry: entry, onTap: () => onSelect(entry));
              },
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.theme, required this.entry, required this.onTap});

  final ExtractedTheme theme;
  final PaletteHistoryEntry entry;
  final VoidCallback onTap;

  String _formatDate(DateTime d) {
    const months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 128,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SizedBox(
                height: 36,
                child: Row(
                  children: entry.colors.take(5).map((hex) {
                    return Expanded(child: ColoredBox(color: PaletteCore.hexToColor(hex)));
                  }).toList(),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                color: theme.bgElevated,
                child: Text(_formatDate(entry.date), style: TextStyle(fontSize: 11, color: theme.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportDialog extends StatelessWidget {
  const _ExportDialog({
    required this.tab,
    required this.controller,
    required this.theme,
    required this.onTab,
    required this.onCopy,
  });

  final String tab;
  final TextEditingController controller;
  final ExtractedTheme theme;
  final ValueChanged<String> onTab;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: theme.bgPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModalHeader(title: 'Dışa aktar', theme: theme, onClose: () => Navigator.pop(context)),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in PaletteCore.exportFormats.entries)
                    _ExportTab(theme: theme, label: f.value, active: tab == f.key, onTap: () => onTab(f.key)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                controller: controller,
                readOnly: true,
                maxLines: 8,
                style: TextStyle(fontFamily: 'Consolas', fontSize: 13, color: theme.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.bgApp,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.border)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ToolbarBtn(theme: theme, icon: Icons.content_copy, label: 'Panoya kopyala', onPressed: onCopy),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportTab extends StatelessWidget {
  const _ExportTab({required this.theme, required this.label, required this.active, required this.onTap});

  final ExtractedTheme theme;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: active ? theme.accent : Colors.transparent, width: 2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: active ? theme.accent : theme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({
    required this.theme,
    required this.locked,
    required this.onExtract,
    required this.onLock,
  });

  final ExtractedTheme theme;
  final bool locked;
  final VoidCallback onExtract;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 4),
      child: Row(
        children: [
          AppBrandTitle(theme: theme, compact: true),
          const Spacer(),
          CircleIconBtn(theme: theme, icon: Icons.photo_camera_outlined, tooltip: 'Tema ayıkla', onPressed: onExtract),
          const SizedBox(width: 6),
          CircleIconBtn(
            theme: theme,
            icon: locked ? Icons.lock : Icons.lock_open_outlined,
            tooltip: 'Kilitle',
            active: locked,
            onPressed: onLock,
          ),
        ],
      ),
    );
  }
}

class _MobilePaletteStack extends StatelessWidget {
  const _MobilePaletteStack({
    required this.theme,
    required this.slots,
    required this.selectedIndex,
    required this.baseHex,
    required this.generating,
    required this.onSelect,
    required this.onToggleLock,
    required this.onCopyHex,
    required this.onEdit,
  });

  final ExtractedTheme theme;
  final List<PaletteSlot> slots;
  final int selectedIndex;
  final String baseHex;
  final bool generating;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onToggleLock;
  final ValueChanged<String> onCopyHex;
  final ValueChanged<int> onEdit;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      itemCount: slots.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final slot = slots[i];
        final badge = PaletteCore.contrastBadge(slot.hex, baseHex);
        final textColor = PaletteCore.textColorForBg(slot.hex);
        final selected = i == selectedIndex;
        final color = PaletteCore.hexToColor(slot.hex);

        return GestureDetector(
          onTap: () => i == selectedIndex ? onEdit(i) : onSelect(i),
          onDoubleTap: () => onCopyHex(slot.hex),
          onLongPress: () => onToggleLock(i),
          child: AnimatedScale(
            scale: selected ? 1.01 : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: generating ? Duration.zero : const Duration(milliseconds: 220),
              height: MediaQuery.sizeOf(context).height * 0.105,
              constraints: const BoxConstraints(minHeight: 76),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, Color.lerp(color, Colors.black, 0.12)!],
                ),
                border: Border.all(
                  color: selected ? Colors.white : Colors.white.withValues(alpha: 0.1),
                  width: selected ? 2.5 : 1,
                ),
                boxShadow: selected
                    ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))]
                    : null,
              ),
              child: Stack(
                children: [
                  if (slot.locked)
                    Positioned(top: 12, left: 14, child: Icon(Icons.lock_rounded, size: 18, color: textColor)),
                  Positioned(top: 12, right: 14, child: _ContrastBadgeChip(badge: badge)),
                  Positioned(
                    left: 18,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RENK ${i + 1}',
                          style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.72), letterSpacing: 0.8),
                        ),
                        Text(
                          slot.hex,
                          style: TextStyle(
                            fontFamily: AppTypography.mono,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
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
      },
    );
  }
}

class _ContrastBadgeChip extends StatelessWidget {
  const _ContrastBadgeChip({required this.badge});
  final ContrastBadge badge;

  @override
  Widget build(BuildContext context) {
    final bg = switch (badge.level) {
      ContrastLevel.aaa => AppColors.passAaa,
      ContrastLevel.aa => AppColors.passAa,
      ContrastLevel.warn => Colors.transparent,
      ContrastLevel.fail => AppColors.failContrast,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: badge.level == ContrastLevel.warn ? Border.all(color: AppColors.warning) : null,
      ),
      child: Text(
        badge.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: badge.level == ContrastLevel.warn ? AppColors.warning : Colors.white,
        ),
      ),
    );
  }
}

class _MobileBottomBar extends StatelessWidget {
  const _MobileBottomBar({
    required this.theme,
    required this.allLocked,
    required this.historyOpen,
    required this.onHistory,
    required this.onRegenerate,
    required this.onExport,
  });

  final ExtractedTheme theme;
  final bool allLocked;
  final bool historyOpen;
  final VoidCallback onHistory;
  final VoidCallback onRegenerate;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.bgPanel.withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: theme.border)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, -4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BarAction(
                theme: theme, icon: Icons.history_rounded, label: 'Geçmiş', primary: historyOpen, onTap: onHistory),
            Transform.translate(
              offset: const Offset(0, -18),
              child: Material(
                elevation: 8,
                shadowColor: theme.accent.withValues(alpha: 0.45),
                color: allLocked ? theme.accent.withValues(alpha: 0.45) : theme.accent,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: allLocked ? null : onRegenerate,
                  borderRadius: BorderRadius.circular(18),
                  child: const SizedBox(
                      width: 58, height: 58, child: Icon(Icons.refresh_rounded, color: Colors.white, size: 28)),
                ),
              ),
            ),
            _BarAction(theme: theme, icon: Icons.ios_share_rounded, label: 'Export', primary: true, onTap: onExport),
          ],
        ),
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final ExtractedTheme theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final color = primary ? theme.accent : theme.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }
}

class _ExtractSheet extends StatefulWidget {
  const _ExtractSheet({
    required this.theme,
    required this.imageSources,
    required this.isMobile,
    required this.onProcess,
    required this.onApply,
  });

  final ExtractedTheme theme;
  final ImageSourceService imageSources;
  final bool isMobile;
  final Future<ExtractResult> Function(Uint8List bytes) onProcess;
  final void Function(ExtractResult result, bool autoApply) onApply;

  @override
  State<_ExtractSheet> createState() => _ExtractSheetState();
}

class _ExtractSheetState extends State<_ExtractSheet> {
  bool _autoApply = true;
  bool _processing = false;
  PickSource? _activeSource;
  Uint8List? _previewBytes;
  ExtractResult? _result;

  Future<void> _pick(PickSource source) async {
    setState(() => _activeSource = source);
    final bytes = await widget.imageSources.pick(source);
    if (!mounted || bytes == null) return;

    setState(() {
      _previewBytes = bytes;
      _processing = true;
      _result = null;
    });

    try {
      final result = await widget.onProcess(bytes);
      if (!mounted) return;
      setState(() => _result = result);
      if (_autoApply && result.palette.isNotEmpty) {
        widget.onApply(result, true);
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModalHeader(title: 'Görselden tema ve palet ayıkla', theme: t, onClose: () => Navigator.pop(context)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'Dosya, kamera veya ekran görüntüsünden 5 renk ve UI teması çıkarılır. Kilitli slotlar korunur.',
            style: TextStyle(fontSize: 12, color: t.textMuted, height: 1.45),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                  child: _SourceTile(
                      theme: t,
                      icon: Icons.folder_open,
                      label: 'Dosya',
                      active: _activeSource == PickSource.file,
                      onTap: _processing ? null : () => _pick(PickSource.file))),
              const SizedBox(width: 10),
              Expanded(
                  child: _SourceTile(
                      theme: t,
                      icon: Icons.photo_camera,
                      label: 'Kamera',
                      active: _activeSource == PickSource.camera,
                      onTap: _processing ? null : () => _pick(PickSource.camera))),
              const SizedBox(width: 10),
              Expanded(
                child: _SourceTile(
                  theme: t,
                  icon: Icons.screenshot_monitor,
                  label: widget.imageSources.screenCaptureNative ? 'Ekran' : 'Ekran görüntüsü',
                  active: _activeSource == PickSource.screen,
                  onTap: _processing ? null : () => _pick(PickSource.screen),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(widget.imageSources.screenSourceHint(), style: TextStyle(fontSize: 11, color: t.textMuted)),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.bgApp,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.border),
              ),
              child: _previewBytes == null
                  ? Center(child: Text('Kaynak seçin', style: TextStyle(color: t.textMuted, fontSize: 13)))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(_previewBytes!, fit: BoxFit.contain),
                    ),
            ),
          ),
        ),
        if (_result != null && _result!.palette.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: _result!.palette.map((hex) {
                return Expanded(
                  child: Container(
                    height: 32,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: PaletteCore.hexToColor(hex),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: t.border),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_result!.theme != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  _ThemeChip(theme: t, color: _result!.theme!.bgApp, label: 'Arka plan'),
                  _ThemeChip(theme: t, color: _result!.theme!.bgPanel, label: 'Panel'),
                  _ThemeChip(theme: t, color: _result!.theme!.accent, label: 'Vurgu'),
                  _ThemeChip(theme: t, color: _result!.theme!.textPrimary, label: 'Metin'),
                ],
              ),
            ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Checkbox(
                  value: _autoApply, activeColor: t.accent, onChanged: (v) => setState(() => _autoApply = v ?? true)),
              Expanded(
                  child:
                      Text('Tema ve paleti otomatik uygula', style: TextStyle(fontSize: 12, color: t.textSecondary))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ToolbarBtn(theme: t, icon: Icons.close, label: 'İptal', onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 10),
              _ToolbarBtn(
                theme: t,
                icon: Icons.palette_outlined,
                label: _processing ? 'İşleniyor…' : 'Uygula',
                filled: true,
                onPressed: _result == null || _processing
                    ? null
                    : () {
                        widget.onApply(_result!, _autoApply);
                        Navigator.pop(context);
                      },
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.isMobile) {
      return Container(
        decoration: BoxDecoration(
          color: t.bgPanel,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          border: Border.all(color: t.border),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHandle(color: t.textMuted),
              Flexible(child: SingleChildScrollView(child: content)),
            ],
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: t.bgPanel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: t.border)),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: content),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.theme,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final ExtractedTheme theme;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? theme.accent.withValues(alpha: 0.15) : theme.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: active ? theme.accent : theme.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 88,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: theme.textPrimary),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: theme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({required this.theme, required this.color, required this.label});

  final ExtractedTheme theme;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final fg = PaletteCore.textColorForBg(PaletteCore.colorToHex(color));
    return Expanded(
      child: Container(
        height: 28,
        margin: const EdgeInsets.only(right: 6),
        alignment: Alignment.bottomCenter,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.border),
        ),
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }
}

class _ShortcutsDialog extends StatelessWidget {
  const _ShortcutsDialog({required this.theme});
  final ExtractedTheme theme;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Yeni palet', 'Boşluk'),
      ('Kilitle / aç', 'L'),
      ('HEX kopyala', 'Enter'),
      ('Slot seç', '1–5'),
      ('HEX düzenle', 'E'),
      ('CSS export', 'C'),
      ('Tailwind export', 'T'),
      ('Geçmiş', 'H'),
      ('Görselden tema/palet', 'I'),
      ('Kapat', 'Esc'),
    ];
    return Dialog(
      backgroundColor: theme.bgPanel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: theme.border)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModalHeader(title: 'Klavye kısayolları', theme: theme, onClose: () => Navigator.pop(context)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.8,
                children: rows.map((r) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(r.$1, style: TextStyle(fontSize: 13, color: theme.textSecondary)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.bgElevated,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: theme.border),
                        ),
                        child: Text(r.$2, style: const TextStyle(fontFamily: 'Consolas', fontSize: 11)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModalHeader extends StatelessWidget {
  const _ModalHeader({required this.title, required this.theme, required this.onClose});

  final String title;
  final ExtractedTheme theme;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(
        children: [
          Expanded(
              child:
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textPrimary))),
          IconButton(icon: const Icon(Icons.close), color: theme.textSecondary, onPressed: onClose),
        ],
      ),
    );
  }
}
