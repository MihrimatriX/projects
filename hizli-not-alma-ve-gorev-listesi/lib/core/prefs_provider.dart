import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final showCompletedProvider =
    NotifierProvider<ShowCompletedNotifier, bool>(ShowCompletedNotifier.new);

class ShowCompletedNotifier extends Notifier<bool> {
  static const _key = 'show_completed';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final searchQueryProvider = StateProvider<String>((ref) => '');
