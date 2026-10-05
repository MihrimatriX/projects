import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:barcode/barcode.dart';

import 'barcode_utils.dart';
import 'batch_export.dart';

enum BarcodeBatchType { code128, ean13 }

abstract final class BarcodeBatchExport {
  static Future<ZipResult> shareSvgZip({
    required List<String> lines,
    required BarcodeBatchType type,
  }) async {
    if (lines.isEmpty) return (count: 0, path: null);

    final archive = Archive();
    var index = 0;

    for (final raw in lines) {
      final error = BarcodeUtils.validate(
        type == BarcodeBatchType.code128
            ? AppBarcodeType.code128
            : AppBarcodeType.ean13,
        raw,
      );
      if (error != null) continue;

      final data = BarcodeUtils.normalize(
        type == BarcodeBatchType.code128
            ? AppBarcodeType.code128
            : AppBarcodeType.ean13,
        raw,
      );
      final barcode = type == BarcodeBatchType.code128
          ? Barcode.code128()
          : Barcode.ean13();

      final svg = barcode.toSvg(
        data,
        width: 280,
        height: 100,
        drawText: true,
      );
      final bytes = utf8.encode(svg);
      index++;
      archive.addFile(
        ArchiveFile(
          'barkod_${index.toString().padLeft(3, '0')}.svg',
          bytes.length,
          bytes,
        ),
      );
    }

    return BatchExport.shareArchive(archive, 'barkod_toplu');
  }

  static Future<ZipResult> shareFromText({
    required String content,
    required BarcodeBatchType type,
  }) {
    return shareSvgZip(lines: BatchExport.parseLines(content), type: type);
  }
}
