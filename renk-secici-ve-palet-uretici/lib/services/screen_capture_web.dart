import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<Uint8List?> captureScreenFrame() async {
  try {
    final media = web.window.navigator.mediaDevices;
    final stream = await media
        .getDisplayMedia(web.DisplayMediaStreamOptions(video: true.toJS, audio: false.toJS))
        .toDart;

    final video = web.HTMLVideoElement()
      ..autoplay = true
      ..muted = true
      ..srcObject = stream;
    await video.play().toDart;
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final w = video.videoWidth;
    final h = video.videoHeight;
    if (w == 0 || h == 0) {
      _stopTracks(stream);
      return null;
    }

    final canvas = web.HTMLCanvasElement()
      ..width = w
      ..height = h;
    canvas.context2D.drawImage(video, 0, 0);
    _stopTracks(stream);

    final dataUrl = canvas.toDataUrl('image/jpeg', 0.9);
    return base64Decode(dataUrl.split(',').last);
  } catch (_) {
    return null;
  }
}

void _stopTracks(web.MediaStream stream) {
  for (final track in stream.getTracks().toDart) {
    track.stop();
  }
}
