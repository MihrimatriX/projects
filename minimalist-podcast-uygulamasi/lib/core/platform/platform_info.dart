import 'package:flutter/foundation.dart' show kIsWeb;

abstract final class PlatformInfo {
  static bool get isWeb => kIsWeb;
  static bool get supportsOfflineDownload => !kIsWeb;
}
