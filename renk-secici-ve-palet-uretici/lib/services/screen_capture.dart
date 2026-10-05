import 'dart:typed_data';

import 'screen_capture_stub.dart'
    if (dart.library.js_interop) 'screen_capture_web.dart'
    if (dart.library.io) 'screen_capture_io.dart' as impl;

Future<Uint8List?> captureScreenFrame() => impl.captureScreenFrame();
