import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final maskWifiPasswordsProvider =
    AsyncNotifierProvider<MaskWifiPasswordsNotifier, bool>(
  MaskWifiPasswordsNotifier.new,
);

class MaskWifiPasswordsNotifier extends AsyncNotifier<bool> {
  static const _key = 'mask_wifi_passwords_v1';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    state = AsyncData(value);
  }
}
