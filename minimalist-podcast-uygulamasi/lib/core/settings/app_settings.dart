import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const _smartSpeed = 'smart_speed_v1';
  static const _wifiOnly = 'wifi_only_downloads_v1';
  static const _corsProxy = 'cors_proxy_base_v1';

  Future<bool> getSmartSpeedEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_smartSpeed) ?? false;
  }

  Future<void> setSmartSpeedEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_smartSpeed, value);
  }

  Future<bool> getWifiOnlyDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_wifiOnly) ?? true;
  }

  Future<void> setWifiOnlyDownloads(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wifiOnly, value);
  }

  Future<String?> getCorsProxyBase() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_corsProxy);
  }

  Future<void> setCorsProxyBase(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(_corsProxy);
    } else {
      await prefs.setString(_corsProxy, value.trim());
    }
  }
}

class AppSettingsState {
  const AppSettingsState({
    this.smartSpeedEnabled = false,
    this.wifiOnlyDownloads = true,
    this.corsProxyBase,
  });

  final bool smartSpeedEnabled;
  final bool wifiOnlyDownloads;
  final String? corsProxyBase;

  AppSettingsState copyWith({
    bool? smartSpeedEnabled,
    bool? wifiOnlyDownloads,
    String? corsProxyBase,
    bool clearCorsProxy = false,
  }) {
    return AppSettingsState(
      smartSpeedEnabled: smartSpeedEnabled ?? this.smartSpeedEnabled,
      wifiOnlyDownloads: wifiOnlyDownloads ?? this.wifiOnlyDownloads,
      corsProxyBase: clearCorsProxy ? null : (corsProxyBase ?? this.corsProxyBase),
    );
  }
}

final appSettingsServiceProvider = Provider((ref) => AppSettings());

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettingsState>(AppSettingsNotifier.new);

class AppSettingsNotifier extends AsyncNotifier<AppSettingsState> {
  AppSettings get _svc => ref.read(appSettingsServiceProvider);

  @override
  Future<AppSettingsState> build() async {
    return AppSettingsState(
      smartSpeedEnabled: await _svc.getSmartSpeedEnabled(),
      wifiOnlyDownloads: await _svc.getWifiOnlyDownloads(),
      corsProxyBase: await _svc.getCorsProxyBase(),
    );
  }

  Future<void> setSmartSpeed(bool value) async {
    await _svc.setSmartSpeedEnabled(value);
    final current = state.value ?? const AppSettingsState();
    state = AsyncData(current.copyWith(smartSpeedEnabled: value));
  }

  Future<void> setWifiOnly(bool value) async {
    await _svc.setWifiOnlyDownloads(value);
    final current = state.value ?? const AppSettingsState();
    state = AsyncData(current.copyWith(wifiOnlyDownloads: value));
  }

  Future<void> setCorsProxyBase(String? value) async {
    await _svc.setCorsProxyBase(value);
    final current = state.value ?? const AppSettingsState();
    state = AsyncData(
      value == null || value.trim().isEmpty
          ? current.copyWith(clearCorsProxy: true)
          : current.copyWith(corsProxyBase: value.trim()),
    );
  }
}
