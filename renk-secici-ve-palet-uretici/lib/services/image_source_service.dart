import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'screen_capture.dart';

enum PickSource { file, camera, screen }

class ImageSourceService {
  final _picker = ImagePicker();

  Future<Uint8List?> pick(PickSource source) async {
    return switch (source) {
      PickSource.file => _pickFile(),
      PickSource.camera => _pickCamera(),
      PickSource.screen => _pickScreen(),
    };
  }

  bool get screenCaptureNative =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  String screenSourceHint() {
    if (screenCaptureNative) return 'Ekran veya pencere seçin';
    return 'Kayıtlı ekran görüntüsünü galeriden seçin';
  }

  Future<Uint8List?> _pickFile() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      return file?.readAsBytes();
    }
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return null;
    return result.files.first.bytes;
  }

  Future<Uint8List?> _pickCamera() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    return file?.readAsBytes();
  }

  Future<Uint8List?> _pickScreen() async {
    final captured = await captureScreenFrame();
    if (captured != null) return captured;

    // ponytail: Android/iOS'ta OS ekran yakalama API yok; galeri fallback
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      return file?.readAsBytes();
    }
    return null;
  }
}
