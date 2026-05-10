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
    };
  }

  static AppSettings fromBackendJson(Map<String, dynamic> json) {
    final appearance = json['appearance'] as Map<String, dynamic>? ?? {};
    final behavior = json['behavior'] as Map<String, dynamic>? ?? {};

    return AppSettings(
      displayFontId: appearance['display_font'] as String? ?? 'default',
      pdfChineseFontId: appearance['pdf_chinese_font'] as String? ?? 'default',
      pdfEnglishFontId: appearance['pdf_english_font'] as String? ?? 'default',
      theme: appearance['theme'] as String? ?? 'system',
      fontSize: (appearance['font_size'] as num?)?.toDouble() ?? 14.0,
      density: appearance['density'] as String? ?? 'comfortable',
      autoSave: behavior['auto_save'] as bool? ?? true,
      confirmDeletions: behavior['confirm_deletions'] as bool? ?? true,
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
          final settingsData = await ApiService.getAppSettings();
          state = AppSettings.fromBackendJson(settingsData);
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
