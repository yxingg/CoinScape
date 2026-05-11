import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

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
  )) {
    if (kIsWeb) {
      _loadFromServer();
    }
  }

  Future<void> _loadFromServer() async {
    try {
      final settings = await ApiService.getAppSettings();
      // backend.proxy_enabled preferred, fallback to sync.webdav.enabled
      bool proxy = false;
      final backend = settings['backend'] as Map<String, dynamic>?;
      final sync = settings['sync'] as Map<String, dynamic>?;
      if (backend != null && backend['proxy_enabled'] != null) {
        proxy = backend['proxy_enabled'] as bool;
      } else if (sync != null) {
        final webdav = sync['webdav'] as Map<String, dynamic>?;
        if (webdav != null && webdav['enabled'] != null) {
          proxy = webdav['enabled'] as bool;
        }
      }
      await _prefs.setBool(kWebDavProxyEnabled, proxy);
      state = WebDavConfig(url: state.url, user: state.user, password: state.password, proxyEnabled: proxy);
    } catch (_) {
      // ignore
    }
  }

  Future<void> saveConfig(String url, String user, String password) async {
    await _prefs.setString(kWebDavUrl, url);
    await _prefs.setString(kWebDavUser, user);
    // Only store password locally if provided (native apps may store); if empty, keep existing
    if (password.isNotEmpty) {
      await _prefs.setString(kWebDavPwd, password);
    }
    state = WebDavConfig(url: url, user: user, password: password.isNotEmpty ? password : state.password, proxyEnabled: state.proxyEnabled);

    // For web clients, update server-side settings so the backend can encrypt/store the password.
    if (kIsWeb) {
      try {
        final payload = {
          'sync': {
            'webdav': {
              'url': url,
              'username': user,
            }
          }
        };
        if (password.isNotEmpty) {
          payload['sync']!['webdav']!['password'] = password;
        }
        await ApiService.updateAppSettings(payload);
      } catch (_) {
        // ignore network errors
      }
    }
  }

  Future<void> setProxyEnabled(bool enabled) async {
    await _prefs.setBool(kWebDavProxyEnabled, enabled);
    state = WebDavConfig(
      url: state.url,
      user: state.user,
      password: state.password,
      proxyEnabled: enabled,
    );
    // If running as web, update server-side settings so app_settings.json stays in sync
    if (kIsWeb) {
      try {
        await ApiService.updateAppSettings({
          'backend': {'proxy_enabled': enabled},
          'sync': {'webdav': {'enabled': enabled}}
        });
      } catch (_) {
        // ignore network errors
      }
    }
  }
}
