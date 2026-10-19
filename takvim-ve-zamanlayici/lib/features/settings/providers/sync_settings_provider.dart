import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncSettings {
  const SyncSettings({
    this.caldavUrl = '',
    this.caldavUsername = '',
    this.googleSyncEnabled = false,
  });

  final String caldavUrl;
  final String caldavUsername;
  final bool googleSyncEnabled;

  SyncSettings copyWith({
    String? caldavUrl,
    String? caldavUsername,
    bool? googleSyncEnabled,
  }) {
    return SyncSettings(
      caldavUrl: caldavUrl ?? this.caldavUrl,
      caldavUsername: caldavUsername ?? this.caldavUsername,
      googleSyncEnabled: googleSyncEnabled ?? this.googleSyncEnabled,
    );
  }
}

final syncSettingsProvider =
    AsyncNotifierProvider<SyncSettingsNotifier, SyncSettings>(
  SyncSettingsNotifier.new,
);

class SyncSettingsNotifier extends AsyncNotifier<SyncSettings> {
  static const _urlKey = 'sync_caldav_url';
  static const _userKey = 'sync_caldav_user';

  @override
  Future<SyncSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return SyncSettings(
      caldavUrl: prefs.getString(_urlKey) ?? '',
      caldavUsername: prefs.getString(_userKey) ?? '',
    );
  }

  Future<void> save(SyncSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, settings.caldavUrl);
    await prefs.setString(_userKey, settings.caldavUsername);
    state = AsyncData(settings);
  }
}
