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
const kWebDavRemotePath = 'webdav_remote_path';

final webDavConfigProvider = StateNotifierProvider<WebDavConfigNotifier, WebDavConfig>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return WebDavConfigNotifier(prefs);
});

class WebDavConfig {
  final String url;
  final String user;
  final String password;
  final bool proxyEnabled;
  final String remotePath;

  WebDavConfig({
    this.url = '', 
    this.user = '', 
    this.password = '',
    this.proxyEnabled = false,
    this.remotePath = '',
  });
  
  bool get isValid => url.isNotEmpty && user.isNotEmpty && password.isNotEmpty;

  Map<String, dynamic> toSyncCfg() => {
    'url': url,
    'username': user,
    'password': password,
    'remote_path': remotePath,
  };
}

class WebDavConfigNotifier extends StateNotifier<WebDavConfig> {
  final SharedPreferences _prefs;

  WebDavConfigNotifier(this._prefs) : super(WebDavConfig(
    url: _prefs.getString(kWebDavUrl) ?? '',
    user: _prefs.getString(kWebDavUser) ?? '',
    password: _prefs.getString(kWebDavPwd) ?? '',
    proxyEnabled: _prefs.getBool(kWebDavProxyEnabled) ?? false,
    remotePath: _prefs.getString(kWebDavRemotePath) ?? '',
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
      String remotePath = state.remotePath;
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
      if (sync != null) {
        final webdav = sync['webdav'] as Map<String, dynamic>?;
        if (webdav != null && webdav['remote_path'] is String) {
          remotePath = webdav['remote_path'] as String;
          await _prefs.setString(kWebDavRemotePath, remotePath);
        }
        // Also load URL/username from server to keep in sync
        if (webdav != null) {
          if (webdav['url'] is String && (webdav['url'] as String).isNotEmpty) {
            await _prefs.setString(kWebDavUrl, webdav['url'] as String);
          }
          if (webdav['username'] is String) {
            await _prefs.setString(kWebDavUser, webdav['username'] as String);
          }
        }
      }
      await _prefs.setBool(kWebDavProxyEnabled, proxy);
      state = WebDavConfig(
        url: _prefs.getString(kWebDavUrl) ?? state.url,
        user: _prefs.getString(kWebDavUser) ?? state.user,
        password: state.password,
        proxyEnabled: proxy,
        remotePath: remotePath,
      );
    } catch (_) {
      // ignore
    }
  }

  Future<void> saveConfig(String url, String user, String password, {String remotePath = ''}) async {
    await _prefs.setString(kWebDavUrl, url);
    await _prefs.setString(kWebDavUser, user);
    await _prefs.setString(kWebDavRemotePath, remotePath);
    // Only store password locally if provided (native apps may store); if empty, keep existing
    if (password.isNotEmpty) {
      await _prefs.setString(kWebDavPwd, password);
    }
    state = WebDavConfig(
      url: url,
      user: user,
      password: password.isNotEmpty ? password : state.password,
      proxyEnabled: state.proxyEnabled,
      remotePath: remotePath,
    );

    // For web clients, update server-side settings so the backend can encrypt/store the password.
    if (kIsWeb) {
      try {
        final payload = {
          'sync': {
            'webdav': {
              'url': url,
              'username': user,
              'remote_path': remotePath,
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
      remotePath: state.remotePath,
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
