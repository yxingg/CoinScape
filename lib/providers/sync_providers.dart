import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized before use');
});

// Keys
const kWebDavUrl = 'webdav_url';
const kWebDavUser = 'webdav_user';
const kWebDavPwd = 'webdav_password';
const kWebDavProxyEnabled = 'webdav_proxy_enabled';

final webDavConfigProvider = StateNotifierProvider<WebDavConfigNotifier, WebDavConfig>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return WebDavConfigNotifier(prefs);
});

class WebDavConfig {
  final String url;
  final String user;
  final String password;
  final bool proxyEnabled;

  WebDavConfig({
    this.url = '', 
    this.user = '', 
    this.password = '',
    this.proxyEnabled = false,
  });
  
  bool get isValid => url.isNotEmpty && user.isNotEmpty && password.isNotEmpty;
}

class WebDavConfigNotifier extends StateNotifier<WebDavConfig> {
  final SharedPreferences _prefs;

  WebDavConfigNotifier(this._prefs) : super(WebDavConfig(
    url: _prefs.getString(kWebDavUrl) ?? '',
    user: _prefs.getString(kWebDavUser) ?? '',
    password: _prefs.getString(kWebDavPwd) ?? '',
    proxyEnabled: _prefs.getBool(kWebDavProxyEnabled) ?? false,
  ));

  Future<void> saveConfig(String url, String user, String password) async {
    await _prefs.setString(kWebDavUrl, url);
    await _prefs.setString(kWebDavUser, user);
    await _prefs.setString(kWebDavPwd, password);
    state = WebDavConfig(url: url, user: user, password: password, proxyEnabled: state.proxyEnabled);
  }

  Future<void> setProxyEnabled(bool enabled) async {
    await _prefs.setBool(kWebDavProxyEnabled, enabled);
    state = WebDavConfig(
      url: state.url,
      user: state.user,
      password: state.password,
      proxyEnabled: enabled,
    );
  }
}
