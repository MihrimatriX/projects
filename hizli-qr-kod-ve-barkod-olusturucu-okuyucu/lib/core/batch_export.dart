import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'barcode_batch_export.dart';
import 'file_output.dart';
import 'qr_export.dart';
import 'qr_svg_export.dart';

enum BatchOutputMode { qrPng, qrSvg, barcodeCode128, barcodeEan13 }

/// ZIP'e giren dosya sayısı ve (masaüstünde) kaydedilen yol.
typedef ZipResult = ({int count, String? path});

abstract final class BatchExport {
  static List<String> parseLines(String content) {
    final lines = content.split(RegExp(r'\r?\n'));
    final result = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final value =
          trimmed.contains(',') ? trimmed.split(',').first.trim() : trimmed;
      if (value.isNotEmpty) result.add(value);
    }
    return result.take(100).toList();
  }

  static Future<ZipResult> shareZip({
    required List<String> payloads,
    required BatchOutputMode mode,
    Color foreground = Colors.black,
    Color background = Colors.white,
    int errorCorrectionLevel = QrErrorCorrectLevel.M,
    int pngSize = 512,
  }) async {
    if (payloads.isEmpty) return (count: 0, path: null);

    switch (mode) {
      case BatchOutputMode.qrPng:
        return _shareQrPngZip(
          payloads: payloads,
          foreground: foreground,
          background: background,
          errorCorrectionLevel: errorCorrectionLevel,
          size: pngSize,
        );
      case BatchOutputMode.qrSvg:
        return _shareQrSvgZip(
          payloads: payloads,
          foreground: foreground,
          background: background,
          errorCorrectionLevel: errorCorrectionLevel,
        );
      case BatchOutputMode.barcodeCode128:
        return BarcodeBatchExport.shareSvgZip(
          lines: payloads,
          type: BarcodeBatchType.code128,
        );
      case BatchOutputMode.barcodeEan13:
        return BarcodeBatchExport.shareSvgZip(
          lines: payloads,
          type: BarcodeBatchType.ean13,
        );
    }
  }

  static Future<ZipResult> _shareQrPngZip({
    required List<String> payloads,
    required Color foreground,
    required Color background,
    required int errorCorrectionLevel,
    required int size,
  }) async {
    final archive = Archive();
    var index = 0;
    for (final data in payloads) {
      index++;
      final bytes = await QrExport.renderPng(
        data: data,
        size: size,
        foreground: foreground,
        background: background,
        errorCorrectionLevel: errorCorrectionLevel,
      );
      if (bytes == null) continue;
      archive.addFile(
        ArchiveFile(
          'qr_${index.toString().padLeft(3, '0')}.png',
          bytes.length,
          bytes,
        ),
      );
    }
    return shareArchive(archive, 'qr_toplu');
  }

  static Future<ZipResult> _shareQrSvgZip({
    required List<String> payloads,
    required Color foreground,
    required Color background,
    required int errorCorrectionLevel,
  }) async {
    final archive = Archive();
    var index = 0;
    for (final data in payloads) {
      index++;
      final svg = QrSvgExport.buildSvg(
        data: data,
        foreground: foreground,
        background: background,
        errorCorrectionLevel: errorCorrectionLevel,
      );
      final bytes = utf8.encode(svg);
      archive.addFile(
        ArchiveFile(
          'qr_${index.toString().padLeft(3, '0')}.svg',
          bytes.length,
          bytes,
        ),
      );
    }
    return shareArchive(archive, 'qr_toplu_svg');
  }

  /// Boş arşivde kaydetme/paylaşım açılmaz.
  static Future<ZipResult> shareArchive(
      Archive archive, String namePrefix) async {
    if (archive.files.isEmpty) return (count: 0, path: null);

    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
    final path = await FileOutput.saveOrShare(
      bytes: zipBytes,
      fileName: '${namePrefix}_${archive.files.length}.zip',
      mimeType: 'application/zip',
      text: '${archive.files.length} dosya',
    );
    return (count: archive.files.length, path: path);
  }
}
