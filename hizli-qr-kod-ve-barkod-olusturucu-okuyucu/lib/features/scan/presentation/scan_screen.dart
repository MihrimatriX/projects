import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/history_display.dart';
import '../../../core/image_code_reader.dart';
import '../../../core/settings_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/url_utils.dart';
import '../../../core/widgets/app_layout.dart';
import '../../../core/widgets/app_panel.dart';
import '../providers/scan_history_provider.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  String? _result;
  String? _formatLabel;
  MobileScannerController? _controller;
  bool _cameraHintShown = false;
  bool _analyzingImage = false;
  bool _torchOn = false;

  bool get _cameraSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          // mobile_scanner 6.x'in Windows eklentisi yok; orada canlı kamera açılamaz.
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void initState() {
    super.initState();
    if (_cameraSupported) {
      _controller =
          MobileScannerController(detectionSpeed: DetectionSpeed.normal);
    }
    _loadCameraHint();
  }

  Future<void> _loadCameraHint() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() =>
        _cameraHintShown = prefs.getBool('camera_hint_shown_v1') ?? false);
  }

  Future<void> _showCameraHintIfNeeded() async {
    if (_cameraHintShown || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kamera izni'),
        content: const Text(
          'QR ve barkod okumak için kameraya erişim gerekir. '
          'Görüntü yalnızca cihazınızda işlenir.',
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anladım')),
        ],
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('camera_hint_shown_v1', true);
    if (mounted) setState(() => _cameraHintShown = true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// [force]: dosya/pano gibi bilinçli okumalarda aynı kod da yeniden gösterilir
  /// (kamera akışında aynı kodu art arda kaydetmemek için tekrarlar yok sayılır).
  void _setResult(String? code, {String? format, bool force = false}) {
    if (code == null || code.isEmpty || (code == _result && !force)) return;
    setState(() {
      _result = code;
      _formatLabel = format;
    });
    HapticFeedback.mediumImpact();
    ref.read(scanHistoryProvider.notifier).add(code);
  }

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    _setResult(barcode?.rawValue, format: barcode?.format.name);
  }

  /// Görsel seçip içindeki QR / barkodu okur. Mobilde galeri + mobile_scanner,
  /// diğer platformlarda (Windows, web) dosya seçici + Dart kod çözücü.
  Future<void> _pickImage() async {
    if (_analyzingImage) return;
    Uint8List? bytes;
    String? path;
    try {
      if (_cameraSupported) {
        final file = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (file == null) return;
        path = file.path;
        bytes = await file.readAsBytes();
      } else {
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
          dialogTitle: 'QR / barkod görseli seçin',
        );
        bytes = picked?.files.single.bytes;
        if (bytes == null) return;
      }
    } catch (e) {
      _snack('Görsel seçilemedi: $e');
      return;
    }
    if (!mounted) return;
    await _decodeImage(bytes, path: path);
  }

  Future<void> _decodeImage(Uint8List bytes, {String? path}) async {
    setState(() => _analyzingImage = true);
    try {
      DecodedCode? found;
      if (_cameraSupported && path != null) {
        // Yerel tarayıcı (ML Kit / Vision) daha fazla biçim tanır; sonuç yoksa Dart çözücüye düş.
        final scanner = _controller ?? MobileScannerController();
        try {
          final capture = await scanner.analyzeImage(path);
          final b = capture?.barcodes.firstOrNull;
          final value = b?.rawValue;
          if (b != null && value != null) {
            found = DecodedCode(value, b.format.name);
          }
        } catch (_) {
          // Yerel analiz başarısız: Dart çözücü denenecek.
        } finally {
          if (!identical(scanner, _controller)) scanner.dispose();
        }
      }
      found ??= await ImageCodeReader.decodeImageBytes(bytes);
      if (found != null) {
        _setResult(found.text, format: found.format, force: true);
      } else {
        _snack('Görselde QR kod veya barkod bulunamadı');
      }
    } on FormatException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Görsel okunamadı: $e');
    } finally {
      if (mounted) setState(() => _analyzingImage = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _snack('Panoda metin yok');
      return;
    }
    _setResult(text,
        format: UrlUtils.looksLikeUrl(text) ? 'URL' : 'Metin', force: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Panodan yapıştırıldı')),
    );
  }

  Future<void> _copyResult() async {
    if (_result == null) return;
    await Clipboard.setData(ClipboardData(text: _result!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kopyalandı')),
    );
  }

  Future<void> _openUrl() async {
    if (_result == null || !UrlUtils.looksLikeUrl(_result!)) return;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Harici bağlantı'),
        content: Text(
          'Bu URL harici bir siteye yönlendiriyor. Açmak istiyor musunuz?\n\n${_result!}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Aç')),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    final uri = Uri.tryParse(UrlUtils.normalizeUrl(_result!));
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final maskWifi = ref.watch(maskWifiPasswordsProvider).value ?? true;
    final isUrl = _result != null && UrlUtils.looksLikeUrl(_result!);
    final wide = MediaQuery.sizeOf(context).width >= 768;

    if (_cameraSupported && !_cameraHintShown) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _showCameraHintIfNeeded());
    }

    final cameraPanel = AppPanel(
      title: 'Kamera',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_cameraSupported && _controller != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(controller: _controller, onDetect: _onDetect),
                    _ScanFrameOverlay(),
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'QR kodu çerçeveye hizalayın',
                            style:
                                TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 200,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.bgRaised,
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'Bu platformda canlı kamera yok.\n'
                'QR / barkod görseli seçin (Ctrl+O) veya metni yapıştırın (Ctrl+V).',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_cameraSupported && _controller != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await _controller?.toggleTorch();
                      if (mounted) setState(() => _torchOn = !_torchOn);
                    },
                    icon: Icon(_torchOn
                        ? Icons.flashlight_on
                        : Icons.flashlight_on_outlined),
                    label: const Text('Fener'),
                  ),
                ),
              if (_cameraSupported && _controller != null)
                const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _analyzingImage ? null : _pickImage,
                  child: _analyzingImage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_cameraSupported
                          ? 'Galeriden seç'
                          : 'Görsel dosyası seç'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'İzin yalnızca bu sekme açıkken kullanılır.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );

    final resultPanel = AppPanel(
      title: 'Son okunan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_result == null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.bgRaised,
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                border: Border.all(
                    color: AppColors.border, style: BorderStyle.solid),
              ),
              child: const Column(
                children: [
                  Icon(Icons.qr_code_scanner, size: 28, color: AppColors.muted),
                  SizedBox(height: 8),
                  Text(
                    'Henüz okuma yok — kamerayı kullanın, görsel seçin veya yapıştırın',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                border:
                    Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_formatLabel != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.bgHover,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatLabel!.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  const Text(
                    'BAŞARILI OKUMA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.08,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    HistoryDisplay.mask(_result!, maskWifiPasswords: maskWifi),
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (isUrl)
                        FilledButton(
                          onPressed: _openUrl,
                          child: const Text('Tarayıcıda aç'),
                        ),
                      OutlinedButton(
                          onPressed: _copyResult, child: const Text('Kopyala')),
                      OutlinedButton(
                        onPressed: () => context.go('/', extra: _result),
                        child: const Text('QR oluştur'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          ...const [
            'URL okunursa açmadan önce onay gösterilir.',
            'Görsel dosyası (PNG/JPG) ve pano yapıştırma aynı sonuç kartını kullanır.',
          ].map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(tip,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _analyzingImage ? null : _pickImage,
            icon: const Icon(Icons.image_outlined),
            label: const Text('Dosya seç…'),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pasteFromClipboard,
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                    color: AppColors.border, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              ),
              child: const Row(
                children: [
                  Icon(Icons.content_paste, size: 18, color: AppColors.muted),
                  SizedBox(width: 8),
                  Text('Yapıştır: Ctrl+V',
                      style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyV, control: true):
            _pasteFromClipboard,
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            _pickImage,
      },
      child: Focus(
        autofocus: true,
        child: AppLayout(
          child: ListView(
            padding:
                const EdgeInsets.only(bottom: AppSpacing.navBarHeight + 16),
            children: [
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 12, child: cameraPanel),
                    const SizedBox(width: AppSpacing.section),
                    Expanded(flex: 10, child: resultPanel),
                  ],
                )
              else ...[
                cameraPanel,
                const SizedBox(height: AppSpacing.section),
                resultPanel,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanFrameOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Container(color: Colors.black.withValues(alpha: 0.45)),
          Center(
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width * 0.5,
              height: MediaQuery.sizeOf(context).width * 0.5,
              child: CustomPaint(painter: _CornerPainter()),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.foreground
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const len = 24.0;

    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, len), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height), Offset(0, size.height - len), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width - len, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - len), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
