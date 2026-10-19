import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/batch_export.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_panel.dart';

class BatchPanel extends StatefulWidget {
  const BatchPanel({super.key});

  @override
  State<BatchPanel> createState() => _BatchPanelState();
}

class _BatchPanelState extends State<BatchPanel> {
  bool _busy = false;
  double _progress = 0;
  String? _summary;
  BatchOutputMode _mode = BatchOutputMode.qrPng;

  String get _modeLabel => switch (_mode) {
        BatchOutputMode.qrPng => 'QR PNG',
        BatchOutputMode.qrSvg => 'QR SVG',
        BatchOutputMode.barcodeCode128 => 'Code128 SVG',
        BatchOutputMode.barcodeEan13 => 'EAN-13 SVG',
      };

  Future<void> _pickAndExport() async {
    if (_busy) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) return;

    final lines =
        BatchExport.parseLines(utf8.decode(bytes, allowMalformed: true));
    if (lines.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dosyada içerik satırı bulunamadı')),
        );
      }
      return;
    }

    setState(() {
      _busy = true;
      _progress = 0;
      _summary = '${result.files.single.name} taranıyor…';
    });

    try {
      final r = await BatchExport.shareZip(payloads: lines, mode: _mode);
      if (!mounted) return;
      final skipped = lines.length - r.count;
      setState(() {
        _summary = r.count == 0
            ? 'Geçerli satır yok: ${lines.length} satırın hiçbiri $_modeLabel için uygun değil.'
            : '${r.count} dosya ZIP arşivine eklendi (${lines.length} satır'
                '${skipped > 0 ? ', $skipped geçersiz satır atlandı' : ''}).';
        _progress = r.count == 0 ? 0 : 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            r.count == 0
                ? 'ZIP oluşturulmadı: geçerli satır yok'
                : r.path != null
                    ? 'Kaydedildi: ${r.path}'
                    : 'ZIP hazır (${r.count} × $_modeLabel)',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Toplu üretim başarısız: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadSampleCsv() async {
    // parseLines her satırın İLK sütununu içerik sayar; örnek de bu biçimde olmalı.
    const csv = 'https://ornek.com/1,not\nhttps://ornek.com/2,not\n';
    await Clipboard.setData(const ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Örnek CSV panoya kopyalandı')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.navBarHeight + 16),
      children: [
        AppPanel(
          title: 'Toplu üretim',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: AppColors.bgRaised,
                borderRadius: BorderRadius.circular(AppSpacing.panelRadius),
                child: InkWell(
                  onTap: _busy ? null : _pickAndExport,
                  borderRadius: BorderRadius.circular(AppSpacing.panelRadius),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 32, horizontal: 20),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.panelRadius),
                      border: Border.all(color: AppColors.border, width: 2),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.upload_file,
                            size: 32, color: AppColors.muted),
                        const SizedBox(height: 8),
                        const Text('CSV veya TXT seçin'),
                        TextButton(
                            onPressed: _downloadSampleCsv,
                            child: const Text('Örnek CSV kopyala')),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['CSV/TXT', '100 satır', 'ZIP dışa aktarım'].map((s) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.bgInput,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(s,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<BatchOutputMode>(
                initialValue: _mode,
                decoration: const InputDecoration(labelText: 'Çıktı türü'),
                items: const [
                  DropdownMenuItem(
                      value: BatchOutputMode.qrPng,
                      child: Text('QR — PNG ZIP')),
                  DropdownMenuItem(
                      value: BatchOutputMode.qrSvg,
                      child: Text('QR — SVG ZIP')),
                  DropdownMenuItem(
                      value: BatchOutputMode.barcodeCode128,
                      child: Text('Code128 — SVG ZIP')),
                  DropdownMenuItem(
                      value: BatchOutputMode.barcodeEan13,
                      child: Text('EAN-13 — SVG ZIP')),
                ],
                onChanged: _busy
                    ? null
                    : (v) {
                        if (v != null) setState(() => _mode = v);
                      },
              ),
              const SizedBox(height: 8),
              Text(
                'Maks. 100 satır — QR PNG, QR SVG, Code128 ve EAN-13 ZIP olarak dışa aktarılır.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              if (_summary != null) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _busy ? null : _progress,
                    minHeight: 8,
                    backgroundColor: AppColors.bgInput,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(_summary!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
