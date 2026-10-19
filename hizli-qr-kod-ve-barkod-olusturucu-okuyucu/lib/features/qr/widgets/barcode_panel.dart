import 'dart:ui' show ImageByteFormat;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../core/barcode_utils.dart';
import '../../../core/file_output.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_panel.dart';

class BarcodePanel extends StatefulWidget {
  const BarcodePanel({super.key});

  @override
  State<BarcodePanel> createState() => _BarcodePanelState();
}

class _BarcodePanelState extends State<BarcodePanel> {
  final _controller = TextEditingController(text: '8690632001234');
  AppBarcodeType _type = AppBarcodeType.ean13;
  final _exportKey = GlobalKey();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _data => BarcodeUtils.normalize(_type, _controller.text);
  String? get _error => BarcodeUtils.validate(_type, _controller.text);

  Future<void> _shareImage() async {
    if (_error != null) return;
    final boundary =
        _exportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    image.dispose();
    if (bytes == null || !mounted) return;
    await runExport(
      context,
      () => FileOutput.saveOrShare(
        bytes: bytes.buffer.asUint8List(),
        fileName:
            'barkod_$_data.png'.replaceAll(RegExp(r'[\\/:*?"<>|\s]'), '_'),
        mimeType: 'image/png',
        text: 'Barkod',
      ),
    );
  }

  Future<void> _shareText() async {
    if (_error != null) return;
    await Clipboard.setData(ClipboardData(text: _data));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Barkod kopyalandı')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final barcode = BarcodeUtils.barcodeFor(_type);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final form = AppPanel(
      title: 'Barkod içeriği',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<AppBarcodeType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Format'),
            items: const [
              DropdownMenuItem(
                  value: AppBarcodeType.code128, child: Text('Code128')),
              DropdownMenuItem(
                  value: AppBarcodeType.ean13, child: Text('EAN-13')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _type = v);
            },
          ),
          const SizedBox(height: AppSpacing.field),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Değer',
              errorText: _error,
            ),
            keyboardType: _type == AppBarcodeType.ean13
                ? TextInputType.number
                : TextInputType.text,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(
            _type == AppBarcodeType.ean13
                ? 'EAN-13 için 13 haneli ürün kodu girin.'
                : 'Code128 alfanumerik metin kabul eder.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );

    final preview = AppPanel(
      title: 'Önizleme',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _error == null ? Colors.white : AppColors.bgRaised,
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              border: Border.all(
                color: _error == null ? AppColors.border : AppColors.border,
                style: _error == null ? BorderStyle.solid : BorderStyle.none,
              ),
            ),
            child: _error == null
                ? RepaintBoundary(
                    key: _exportKey,
                    child: BarcodeWidget(
                      barcode: barcode,
                      data: _data,
                      width: 280,
                      height: 56,
                      drawText: true,
                    ),
                  )
                : Text(
                    _error ?? 'Geçerli kod girin',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _error == null ? _shareImage : null,
                  child: const Text('İndir PNG'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _error == null ? _shareText : null,
                child: const Icon(Icons.share_outlined),
              ),
            ],
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.navBarHeight + 16),
      children: [
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: form),
              const SizedBox(width: AppSpacing.section),
              SizedBox(width: 340, child: preview),
            ],
          )
        else ...[
          preview,
          const SizedBox(height: AppSpacing.section),
          form,
        ],
      ],
    );
  }
}
