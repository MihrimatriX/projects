import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Kaydetme/paylaşım sonucunu bildirir: masaüstünde yol, hata olursa mesaj.
Future<void> runExport(
    BuildContext context, Future<String?> Function() action) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final path = await action();
    if (path != null) {
      messenger.showSnackBar(SnackBar(content: Text('Kaydedildi: $path')));
    }
  } on FormatException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Dışa aktarılamadı: $e')));
  }
}

/// Üretilen dosyaları kullanıcıya verir.
///
/// Masaüstünde (Windows/macOS/Linux) "Farklı kaydet" iletişim kutusu açılır;
/// önceden burada da paylaşım sayfası açılıyordu ve "İndir PNG" dosya
/// kaydetmiyordu. Mobil ve web'de sistem paylaşım sayfası kullanılır.
abstract final class FileOutput {
  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Masaüstünde kaydedilen dosyanın yolunu döndürür; iptal edilirse veya
  /// paylaşım sayfası kullanıldıysa `null`.
  static Future<String?> saveOrShare({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? text,
  }) async {
    if (isDesktop) {
      final ext = _ext(fileName);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Kaydet',
        fileName: fileName,
        type: ext.isEmpty ? FileType.any : FileType.custom,
        allowedExtensions: ext.isEmpty ? null : [ext],
        bytes: bytes,
      );
      if (path == null) return null;
      final target = ext.isNotEmpty && _ext(path).isEmpty ? '$path.$ext' : path;
      await writeBytes(target, bytes);
      return target;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
        text: text,
      ),
    );
    return null;
  }

  static String _ext(String name) {
    final base = name.split(RegExp(r'[\\/]')).last;
    final dot = base.lastIndexOf('.');
    return dot <= 0 ? '' : base.substring(dot + 1);
  }

  /// file_picker masaüstünde baytları her sürümde yazmıyor; dosyayı her zaman biz yazarız.
  static Future<void> writeBytes(String path, Uint8List bytes) =>
      File(path).writeAsBytes(bytes, flush: true);
}
