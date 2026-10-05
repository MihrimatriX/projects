import 'dart:io';
import 'dart:typed_data';

import 'package:screen_capturer/screen_capturer.dart';

Future<Uint8List?> captureScreenFrame() async {
  if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return null;
  try {
    final data = await ScreenCapturer.instance.capture(mode: CaptureMode.screen);
    if (data == null) return null;
    if (data.imageBytes != null) return data.imageBytes;
    final path = data.imagePath;
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}
