import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/local_config_service.dart';
import '../utils/logger.dart';

class AppSettings {
  final String displayFontId;
  final String pdfChineseFontId;
  final String pdfEnglishFontId;
  final double fontSize;
  final String density;
  final String theme;
  final bool imageViewMode;
  final bool autoSave;
  final bool confirmDeletions;
  final String backendUrl;
  final String savePath;
  final String logLevel;
  final String webDavUrl;
  final String webDavUser;
  final String webDavPassword;
  final bool webDavProxyEnabled;

  AppSettings({
    this.displayFontId = 'default',
    this.pdfChineseFontId = 'default',
    this.pdfEnglishFontId = 'default',
    this.fontSize = 14.0,
    this.density = 'comfortable',
    this.theme = 'system',
    this.imageViewMode = false,
    this.autoSave = true,
    this.confirmDeletions = true,
    this.backendUrl = 'http://localhost:9876',
    this.savePath = '',
    this.logLevel = 'info',
    this.webDavUrl = '',
    this.webDavUser = '',
    this.webDavPassword = '',
    this.webDavProxyEnabled = true,
  });

  AppSettings copyWith({
    String? displayFontId,
    String? pdfChineseFontId,
    String? pdfEnglishFontId,
    double? fontSize,
    String? density,
    String? theme,
    bool? imageViewMode,
    bool? autoSave,
    bool? confirmDeletions,
    String? backendUrl,
    String? savePath,
    String? logLevel,
    String? webDavUrl,
    String? webDavUser,
    String? webDavPassword,
    bool? webDavProxyEnabled,
  }) {
    return AppSettings(
      displayFontId: displayFontId ?? this.displayFontId,
      pdfChineseFontId: pdfChineseFontId ?? this.pdfChineseFontId,
      pdfEnglishFontId: pdfEnglishFontId ?? this.pdfEnglishFontId,
      fontSize: fontSize ?? this.fontSize,
      density: density ?? this.density,
      theme: theme ?? this.theme,
      imageViewMode: imageViewMode ?? this.imageViewMode,
      autoSave: autoSave ?? this.autoSave,
      confirmDeletions: confirmDeletions ?? this.confirmDeletions,
      backendUrl: backendUrl ?? this.backendUrl,
      savePath: savePath ?? this.savePath,
      logLevel: logLevel ?? this.logLevel,
      webDavUrl: webDavUrl ?? this.webDavUrl,
      webDavUser: webDavUser ?? this.webDavUser,
      webDavPassword: webDavPassword ?? this.webDavPassword,
      webDavProxyEnabled: webDavProxyEnabled ?? this.webDavProxyEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'displayFontId': displayFontId,
      'pdfChineseFontId': pdfChineseFontId,
      'pdfEnglishFontId': pdfEnglishFontId,
      'fontSize': fontSize,
      'density': density,
      'theme': theme,
      'imageViewMode': imageViewMode,
      'autoSave': autoSave,
      'confirmDeletions': confirmDeletions,
      'backendUrl': backendUrl,
      'savePath': savePath,
      'logLevel': logLevel,
      'webDavUrl': webDavUrl,
      'webDavUser': webDavUser,
      'webDavPassword': _encryptPassword(webDavPassword),
      'webDavProxyEnabled': webDavProxyEnabled,
    };
  }

  static AppSettings fromJson(Map<String, dynamic> json) {
    return AppSettings(
      displayFontId: json['displayFontId'] as String? ?? 'default',
      pdfChineseFontId: json['pdfChineseFontId'] as String? ?? 'default',
      pdfEnglishFontId: json['pdfEnglishFontId'] as String? ?? 'default',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14.0,
      density: json['density'] as String? ?? 'comfortable',
      theme: json['theme'] as String? ?? 'system',
      imageViewMode: json['imageViewMode'] as bool? ?? false,
      autoSave: json['autoSave'] as bool? ?? true,
      confirmDeletions: json['confirmDeletions'] as bool? ?? true,
      backendUrl: json['backendUrl'] as String? ?? 'http://localhost:9876',
      savePath: json['savePath'] as String? ?? '',
      logLevel: json['logLevel'] as String? ?? 'info',
      webDavUrl: json['webDavUrl'] as String? ?? '',
      webDavUser: json['webDavUser'] as String? ?? '',
      webDavPassword: _decryptPassword(json['webDavPassword'] as String? ?? ''),
      webDavProxyEnabled: json['webDavProxyEnabled'] as bool? ?? true,
    );
  }

  static String _encryptPassword(String plain) {
    if (plain.isEmpty) return '';
    try {
      return 'enc:${base64Encode(utf8.encode(plain))}';
    } catch (_) {
      return plain;
    }
  }

  static String _decryptPassword(String encrypted) {
    if (encrypted.isEmpty || !encrypted.startsWith('enc:')) return encrypted;
    try {
      return utf8.decode(base64Decode(encrypted.substring(4)));
    } catch (_) {
      return encrypted;
    }
  }

  Map<String, dynamic> toBackendJson() {
    return {
      'appearance': {
        'theme': theme,
        'display_font': displayFontId,
        'pdf_chinese_font': pdfChineseFontId,
        'pdf_english_font': pdfEnglishFontId,
        'font_size': fontSize,
        'density': density,
      },
      'behavior': {
        'auto_save': autoSave,
        'confirm_deletions': confirmDeletions,
      },
      'backend': {
        'service_address': backendUrl,
        'save_path': savePath,
        'log_level': logLevel,
      },
      'sync': {
        'webdav': {
          'enabled': webDavProxyEnabled,
          'url': webDavUrl,
          'username': webDavUser,
          // only include password when it's non-empty to avoid overwriting existing secret
          if (webDavPassword.isNotEmpty) 'password': webDavPassword,
          'remote_path': ''
        }
      }
    };
  }

  static AppSettings fromBackendJson(Map<String, dynamic> json) {
    final appearance = json['appearance'] as Map<String, dynamic>? ?? {};
    final behavior = json['behavior'] as Map<String, dynamic>? ?? {};
    // backend settings
    final backend = json['backend'] as Map<String, dynamic>? ?? {};
    final sync = json['sync'] as Map<String, dynamic>? ?? {};
    final webdav = sync['webdav'] as Map<String, dynamic>? ?? {};
    // mergePolicy not used in AppSettings directly; ignore if present.

    return AppSettings(
      displayFontId: appearance['display_font'] as String? ?? 'default',
      pdfChineseFontId: appearance['pdf_chinese_font'] as String? ?? 'default',
      pdfEnglishFontId: appearance['pdf_english_font'] as String? ?? 'default',
      theme: appearance['theme'] as String? ?? 'system',
      fontSize: (appearance['font_size'] as num?)?.toDouble() ?? 14.0,
      density: appearance['density'] as String? ?? 'comfortable',
      autoSave: behavior['auto_save'] as bool? ?? true,
      confirmDeletions: behavior['confirm_deletions'] as bool? ?? true,
      backendUrl: backend['service_address'] as String? ?? 'http://localhost:9876',
      savePath: backend['save_path'] as String? ?? '',
      logLevel: backend['log_level'] as String? ?? 'info',
      webDavUrl: webdav['url'] as String? ?? '',
      webDavUser: webdav['username'] as String? ?? '',
      // Do not expose encrypted password strings from backend to UI. If backend reports an encrypted value,
      // treat it as "set but hidden" and leave the UI password empty.
      webDavPassword: (webdav['password'] as String? ?? '').startsWith('enc:') ? '' : (webdav['password'] as String? ?? ''),
      webDavProxyEnabled: webdav['enabled'] as bool? ?? false,
      // store merge policy locally in webdav password field? No; we will handle separately via SettingsNotifier update
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final localData = await LocalConfigService.load();
      if (localData.isNotEmpty) {
        state = AppSettings.fromJson(localData);
        AppLogger.info('Settings', '已从本地配置文件加载设置');
        return;
      }

      if (kIsWeb) {
        try {
          // Ensure any previously saved backend base URL is loaded before
          // attempting to contact the backend. Otherwise the default
          // `http://localhost:9876` may be used and cause connection errors
          // when the real backend runs on a different host/IP.
          await ApiService.loadSavedBaseUrl();

          // If there's no saved base URL, prefer the current page origin
          // (so the web app will call the same host that served the files).
          if (ApiService.baseUrl == 'http://localhost:9876') {
            try {
              final origin = '${Uri.base.scheme}://${Uri.base.host}${Uri.base.hasPort ? ':${Uri.base.port}' : ''}';
              ApiService.setBaseUrl(origin);
            } catch (_) {}
          }

          final settingsData = await ApiService.getAppSettings();
          state = AppSettings.fromBackendJson(settingsData);
          // 更新 API 服务的 baseUrl，确保后续请求使用后端配置
          try {
            ApiService.setBaseUrl(state.backendUrl);
          } catch (_) {}

          // 如果 UI 的 displayFontId 是 'default'（未指定字体），尝试从后端 fonts 目录
          // 获取可用字体列表并将第一个字体设为默认。这样用户平时放在
          // backend/data/fonts 下的第一个字体会自动作为默认字体被选中。
          try {
            final fonts = await ApiService.getFontsList();
            if (fonts.isNotEmpty && (state.displayFontId == 'default' || state.displayFontId.isEmpty)) {
              final first = fonts.first;
              final fontId = (first['id'] as String?) ?? (first['filename'] as String).split('.').first;
              state = state.copyWith(displayFontId: fontId);
            }
          } catch (_) {}

          await LocalConfigService.save(state.toJson());
        } catch (_) {
          _loadFromPrefs();
        }
      } else {
        _loadFromPrefs();
      }
    } catch (_) {
      _loadFromPrefs();
    }
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      displayFontId: prefs.getString('displayFontId') ?? 'default',
      pdfChineseFontId: prefs.getString('pdfChineseFontId') ?? 'default',
      pdfEnglishFontId: prefs.getString('pdfEnglishFontId') ?? 'default',
      fontSize: prefs.getDouble('fontSize') ?? 14.0,
      density: prefs.getString('density') ?? 'comfortable',
      theme: prefs.getString('theme') ?? 'system',
      imageViewMode: prefs.getBool('imageViewMode') ?? false,
      backendUrl: prefs.getString('backendUrl') ?? 'http://localhost:9876',
      savePath: prefs.getString('savePath') ?? '',
      logLevel: prefs.getString('logLevel') ?? 'info',
      webDavUrl: prefs.getString('webDavUrl') ?? '',
      webDavUser: prefs.getString('webDavUser') ?? '',
      webDavPassword: prefs.getString('webDavPassword') ?? '',
      webDavProxyEnabled: prefs.getBool('webDavProxyEnabled') ?? true,
    );
    try {
      ApiService.setBaseUrl(state.backendUrl);
    } catch (_) {}
  }

  Future<void> _save() async {
    await LocalConfigService.save(state.toJson());
    if (kIsWeb) {
      try {
        await ApiService.updateAppSettings(state.toBackendJson());
      } catch (_) {}
    }
  }

  Future<void> update(AppSettings Function(AppSettings) updater) async {
    state = updater(state);
    await _save();
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
