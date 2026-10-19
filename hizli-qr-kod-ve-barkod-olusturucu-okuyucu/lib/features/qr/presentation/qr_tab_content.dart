import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/contrast_utils.dart';
import '../../../core/debouncer.dart';
import '../../../core/file_output.dart';
import '../../../core/history_display.dart';
import '../../../core/qr_export.dart';
import '../../../core/qr_preset_kind.dart';
import '../../../core/qr_presets.dart';
import '../../../core/qr_svg_export.dart';
import '../../../core/settings_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/url_utils.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_panel.dart';
import '../providers/qr_history_provider.dart';

class QrTabContent extends ConsumerStatefulWidget {
  const QrTabContent({super.key, this.initialText});

  final String? initialText;

  @override
  ConsumerState<QrTabContent> createState() => _QrTabContentState();
}

class _QrTabContentState extends ConsumerState<QrTabContent> {
  QrPresetKind _preset = QrPresetKind.url;
  late final TextEditingController _url;
  late final TextEditingController _text;
  late final TextEditingController _ssid;
  late final TextEditingController _wifiPass;
  late final TextEditingController _vcardName;
  late final TextEditingController _vcardTel;
  late final TextEditingController _vcardEmail;
  late final Debouncer _debouncer;

  int _eccLevel = QrErrorCorrectLevel.M;
  int _exportSize = 512;
  bool _exporting = false;
  bool _wifiPassVisible = false;
  String _previewData = '';
  String? _urlError;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(
        text: widget.initialText ?? 'https://ornek.com/kampanya');
    _text = TextEditingController();
    _ssid = TextEditingController(text: 'EvWiFi');
    _wifiPass = TextEditingController();
    _vcardName = TextEditingController();
    _vcardTel = TextEditingController();
    _vcardEmail = TextEditingController();
    _debouncer = Debouncer();
    _previewData = _buildContent();
    // Okunan içerik düz metin/WiFi/vCard olabilir; türüne göre doğru sekmeye yükle.
    if (widget.initialText != null) _loadHistoryItem(widget.initialText!);
  }

  // "Oku" sekmesinden "QR oluştur" ile gelindiğinde sekme durumu korunur
  // (initState tekrar çalışmaz); yeni metni burada forma yükle.
  @override
  void didUpdateWidget(covariant QrTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = widget.initialText;
    if (text != null && text != oldWidget.initialText) _loadHistoryItem(text);
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _url.dispose();
    _text.dispose();
    _ssid.dispose();
    _wifiPass.dispose();
    _vcardName.dispose();
    _vcardTel.dispose();
    _vcardEmail.dispose();
    super.dispose();
  }

  String _buildContent() {
    return switch (_preset) {
      QrPresetKind.url => QrPresets.url(_url.text),
      QrPresetKind.text => _text.text.trim(),
      QrPresetKind.wifi => QrPresets.wifi(
          ssid: _ssid.text.trim().isEmpty ? 'EvWiFi' : _ssid.text.trim(),
          password: _wifiPass.text,
          encryption: _wifiEncryption,
        ),
      QrPresetKind.vcard => QrPresets.vcard(
          name: _vcardName.text.trim(),
          phone: _vcardTel.text.trim(),
          email: _vcardEmail.text.trim(),
        ),
    };
  }

  String get _wifiEncryption => _wifiType;

  String _wifiType = 'WPA';

  void _schedulePreviewUpdate() {
    _debouncer.run(() {
      if (!mounted) return;
      final content = _buildContent();
      String? urlErr;
      if (_preset == QrPresetKind.url && content.isNotEmpty) {
        urlErr =
            UrlUtils.looksLikeUrl(content) ? null : 'Geçerli bir URL girin';
      }
      setState(() {
        _previewData = content;
        _urlError = urlErr;
      });
    });
  }

  bool get _hasValidPreview =>
      _previewData.isNotEmpty &&
      (_preset != QrPresetKind.url || _urlError == null);

  String get _eccLabel => switch (_eccLevel) {
        QrErrorCorrectLevel.L => 'L',
        QrErrorCorrectLevel.M => 'M',
        QrErrorCorrectLevel.Q => 'Q',
        _ => 'H',
      };

  Future<void> _sharePng() async {
    if (!_hasValidPreview || _exporting) return;
    setState(() => _exporting = true);
    try {
      await runExport(
        context,
        () => QrExport.sharePng(
          data: _previewData,
          size: _exportSize,
          foreground: AppColors.qrFg,
          background: AppColors.qrBg,
          errorCorrectionLevel: _eccLevel,
        ),
      );
      await ref.read(qrHistoryProvider.notifier).add(_previewData);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareSvg() async {
    if (!_hasValidPreview || _exporting) return;
    setState(() => _exporting = true);
    try {
      await runExport(
        context,
        () => QrSvgExport.shareSvg(
          data: _previewData,
          foreground: AppColors.qrFg,
          background: AppColors.qrBg,
          errorCorrectionLevel: _eccLevel,
        ),
      );
      await ref.read(qrHistoryProvider.notifier).add(_previewData);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _copyText() async {
    if (!_hasValidPreview) return;
    await Clipboard.setData(ClipboardData(text: _previewData));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Panoya kopyalandı')),
    );
  }

  // Wi-Fi / vCard alanları da doldurulur: önceden yalnızca önizleme değişiyor,
  // form varsayılan değerlerde kalıyordu; bir alan düzenlenince içerik kayboluyordu.
  void _loadHistoryItem(String item) {
    final wifi = QrPresets.parseWifi(item);
    final vcard = wifi == null ? QrPresets.parseVcard(item) : null;
    if (wifi != null) {
      _ssid.text = wifi.ssid;
      _wifiPass.text = wifi.password;
      setState(() {
        _preset = QrPresetKind.wifi;
        _wifiType = wifi.encryption;
      });
    } else if (vcard != null) {
      _vcardName.text = vcard.name;
      _vcardTel.text = vcard.phone;
      _vcardEmail.text = vcard.email;
      setState(() => _preset = QrPresetKind.vcard);
    } else if (UrlUtils.looksLikeUrl(item)) {
      setState(() => _preset = QrPresetKind.url);
      _url.text = item;
    } else {
      setState(() => _preset = QrPresetKind.text);
      _text.text = item;
    }
    setState(() {
      _previewData = item;
      _urlError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(qrHistoryProvider).value ?? [];
    final maskWifi = ref.watch(maskWifiPasswordsProvider).value ?? true;
    final lowContrast = _hasValidPreview &&
        !ContrastUtils.hasReadableQrContrast(AppColors.qrFg, AppColors.qrBg);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final formPanel = AppPanel(
      title: 'İçerik',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: QrPresetKind.values.map((p) {
              return AppChip(
                label: p.label,
                selected: _preset == p,
                onTap: () {
                  setState(() => _preset = p);
                  _schedulePreviewUpdate();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.section),
          _buildPresetFields(),
          const SizedBox(height: AppSpacing.field),
          Row(
            children: [
              Expanded(child: _eccDropdown()),
              const SizedBox(width: AppSpacing.field),
              Expanded(child: _sizeDropdown()),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Veriler yalnızca cihazınızda işlenir; sunucuya gönderilmez.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );

    final previewPanel = AppPanel(
      title: 'Önizleme',
      child: Column(
        children: [
          _QrPreviewBox(
            data: _hasValidPreview ? _previewData : null,
            eccLevel: _eccLevel,
          ),
          const SizedBox(height: 16),
          _PreviewMeta(
            type: _preset.label,
            settings: '$_eccLabel / $_exportSize px',
            length: '${_previewData.length} karakter',
          ),
          if (lowContrast) ...[
            const SizedBox(height: 12),
            const _WarnBanner(
              text:
                  'Modül kontrastı WCAG 4.5:1 altında — baskıda okunmayabilir.',
            ),
          ],
          const SizedBox(height: 16),
          _ExportBar(
            exporting: _exporting,
            canExport: _hasValidPreview,
            onPng: _sharePng,
            onSvg: _shareSvg,
            onCopy: _copyText,
          ),
        ],
      ),
    );

    final historyPanel = AppPanel(
      title: 'Geçmiş',
      child: history.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Henüz QR oluşturulmadı',
                    style: TextStyle(color: AppColors.muted)),
              ),
            )
          : Column(
              children: history.map((item) {
                return _HistoryRow(
                  text: HistoryDisplay.mask(item, maskWifiPasswords: maskWifi),
                  onTap: () => _loadHistoryItem(item),
                  onDelete: () =>
                      ref.read(qrHistoryProvider.notifier).remove(item),
                );
              }).toList(),
            ),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.navBarHeight + 16),
      children: [
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: formPanel),
              const SizedBox(width: AppSpacing.section),
              SizedBox(width: 340, child: previewPanel),
            ],
          )
        else ...[
          previewPanel,
          const SizedBox(height: AppSpacing.section),
          formPanel,
        ],
        const SizedBox(height: AppSpacing.section),
        historyPanel,
      ],
    );
  }

  Widget _eccDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _eccLevel,
      decoration: const InputDecoration(labelText: 'Hata düzeltme'),
      items: const [
        DropdownMenuItem(
            value: QrErrorCorrectLevel.L, child: Text('L - Düşük (%7)')),
        DropdownMenuItem(
            value: QrErrorCorrectLevel.M, child: Text('M - Orta (%15)')),
        DropdownMenuItem(
            value: QrErrorCorrectLevel.Q, child: Text('Q - Yüksek (%25)')),
        DropdownMenuItem(
            value: QrErrorCorrectLevel.H, child: Text('H - En yüksek (%30)')),
      ],
      onChanged: (v) {
        if (v != null) {
          setState(() => _eccLevel = v);
          _schedulePreviewUpdate();
        }
      },
    );
  }

  Widget _sizeDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _exportSize,
      decoration: const InputDecoration(labelText: 'Boyut'),
      items: const [
        DropdownMenuItem(value: 512, child: Text('512 px')),
        DropdownMenuItem(value: 1024, child: Text('1024 px')),
      ],
      onChanged: (v) {
        if (v != null) setState(() => _exportSize = v);
      },
    );
  }

  Widget _buildPresetFields() {
    return switch (_preset) {
      QrPresetKind.url => TextField(
          controller: _url,
          decoration: InputDecoration(
            labelText: 'Web adresi',
            hintText: 'https://...',
            errorText: _urlError,
          ),
          keyboardType: TextInputType.url,
          onChanged: (_) => _schedulePreviewUpdate(),
        ),
      QrPresetKind.text => TextField(
          controller: _text,
          decoration: const InputDecoration(
            labelText: 'Metin',
            hintText: 'QR kodda görünecek metin…',
          ),
          maxLines: 4,
          onChanged: (_) => _schedulePreviewUpdate(),
        ),
      QrPresetKind.wifi => Column(
          children: [
            TextField(
              controller: _ssid,
              decoration: const InputDecoration(labelText: 'Ağ adı (SSID)'),
              onChanged: (_) => _schedulePreviewUpdate(),
            ),
            const SizedBox(height: AppSpacing.field),
            TextField(
              controller: _wifiPass,
              decoration: InputDecoration(
                labelText: 'Şifre',
                suffixIcon: IconButton(
                  icon: Icon(_wifiPassVisible
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _wifiPassVisible = !_wifiPassVisible),
                ),
              ),
              obscureText: !_wifiPassVisible,
              onChanged: (_) => _schedulePreviewUpdate(),
            ),
            const SizedBox(height: AppSpacing.field),
            DropdownButtonFormField<String>(
              // initialValue yalnızca ilk çizimde okunur; geçmişten yüklenen türü yansıtmak için anahtar.
              key: ValueKey('wifi-type-$_wifiType'),
              initialValue: _wifiType,
              decoration: const InputDecoration(labelText: 'Güvenlik'),
              items: const [
                DropdownMenuItem(value: 'WPA', child: Text('WPA/WPA2')),
                DropdownMenuItem(value: 'WEP', child: Text('WEP')),
                DropdownMenuItem(value: 'nopass', child: Text('Açık ağ')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _wifiType = v);
                  _schedulePreviewUpdate();
                }
              },
            ),
          ],
        ),
      QrPresetKind.vcard => Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _vcardName,
                    decoration: const InputDecoration(labelText: 'Ad Soyad'),
                    onChanged: (_) => _schedulePreviewUpdate(),
                  ),
                ),
                const SizedBox(width: AppSpacing.field),
                Expanded(
                  child: TextField(
                    controller: _vcardTel,
                    decoration: const InputDecoration(labelText: 'Telefon'),
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => _schedulePreviewUpdate(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.field),
            TextField(
              controller: _vcardEmail,
              decoration: const InputDecoration(labelText: 'E-posta'),
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => _schedulePreviewUpdate(),
            ),
          ],
        ),
    };
  }
}

class _QrPreviewBox extends StatelessWidget {
  const _QrPreviewBox({required this.data, required this.eccLevel});

  final String? data;
  final int eccLevel;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context).width.clamp(200.0, 280.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.qrBg,
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: data == null
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: AppColors.muted, size: 28),
                SizedBox(height: 8),
                Text('Geçersiz içerik',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
              ],
            )
          : QrImageView(
              data: data!,
              size: size - 32,
              backgroundColor: AppColors.qrBg,
              errorCorrectionLevel: eccLevel,
            ),
    );
  }
}

class _PreviewMeta extends StatelessWidget {
  const _PreviewMeta({
    required this.type,
    required this.settings,
    required this.length,
  });

  final String type;
  final String settings;
  final String length;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _MetaItem(label: 'Tür', value: type)),
        const SizedBox(width: 8),
        Expanded(child: _MetaItem(label: 'Ayar', value: settings)),
        const SizedBox(width: 8),
        Expanded(child: _MetaItem(label: 'İçerik', value: length)),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.08,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarnBanner extends StatelessWidget {
  const _WarnBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12, color: AppColors.warning)),
          ),
        ],
      ),
    );
  }
}

class _ExportBar extends StatelessWidget {
  const _ExportBar({
    required this.exporting,
    required this.canExport,
    required this.onPng,
    required this.onSvg,
    required this.onCopy,
  });

  final bool exporting;
  final bool canExport;
  final VoidCallback onPng;
  final VoidCallback onSvg;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: canExport && !exporting ? onPng : null,
            icon: exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download, size: 18),
            label: const Text('İndir PNG'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: canExport && !exporting ? onSvg : null,
            icon: const Icon(Icons.code, size: 18),
            label: const Text('SVG'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: canExport ? onCopy : null,
            icon: const Icon(Icons.content_copy, size: 18),
            label: const Text('Panoya'),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.text,
    required this.onTap,
    required this.onDelete,
  });

  final String text;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
