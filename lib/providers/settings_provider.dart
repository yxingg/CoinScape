import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AppSettings {
  final String chineseFontId;
  final String englishFontId;
  final String theme;
  final double fontSize;
  final String density;
  final bool autoSave;
  final bool confirmDeletions;

  AppSettings({
    required this.chineseFontId,
    required this.englishFontId,
    this.theme = 'system',
    this.fontSize = 14.0,
    this.density = 'comfortable',
    this.autoSave = true,
    this.confirmDeletions = true,
  });

  AppSettings copyWith({
    String? chineseFontId,
    String? englishFontId,
    String? theme,
    double? fontSize,
    String? density,
    bool? autoSave,
    bool? confirmDeletions,
  }) {
    return AppSettings(
      chineseFontId: chineseFontId ?? this.chineseFontId,
      englishFontId: englishFontId ?? this.englishFontId,
      theme: theme ?? this.theme,
      fontSize: fontSize ?? this.fontSize,
      density: density ?? this.density,
      autoSave: autoSave ?? this.autoSave,
      confirmDeletions: confirmDeletions ?? this.confirmDeletions,
    );
  }

  /// 转换为后端API可用的格式
  Map<String, dynamic> toJson() {
    return {
      'appearance': {
        'theme': theme,
        'font_family': chineseFontId,
        'font_size': fontSize,
        'density': density,
      },
      'behavior': {
        'auto_save': autoSave,
        'confirm_deletions': confirmDeletions,
      },
    };
  }

  /// 从后端API数据创建实例
  static AppSettings fromJson(Map<String, dynamic> json) {
    final appearance = json['appearance'] as Map<String, dynamic>? ?? {};
    final behavior = json['behavior'] as Map<String, dynamic>? ?? {};
    
    return AppSettings(
      chineseFontId: appearance['font_family'] as String? ?? 'default',
      englishFontId: appearance['font_family'] as String? ?? 'default', // 暂时使用相同字体
      theme: appearance['theme'] as String? ?? 'system',
      fontSize: (appearance['font_size'] as num?)?.toDouble() ?? 14.0,
      density: appearance['density'] as String? ?? 'comfortable',
      autoSave: behavior['auto_save'] as bool? ?? true,
      confirmDeletions: behavior['confirm_deletions'] as bool? ?? true,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings(chineseFontId: 'default', englishFontId: 'default')) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      // 首先尝试从后端API加载设置
      if (kIsWeb) {
        final settingsData = await ApiService.getAppSettings();
        state = AppSettings.fromJson(settingsData);
        // 同时保存到本地缓存
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('chineseFontId', state.chineseFontId);
        await prefs.setString('englishFontId', state.englishFontId);
      } else {
        // 原生端：使用本地存储
        final prefs = await SharedPreferences.getInstance();
        state = AppSettings(
          chineseFontId: prefs.getString('chineseFontId') ?? 'preset_noto_sans_sc',
          englishFontId: prefs.getString('englishFontId') ?? 'preset_noto_sans_sc',
        );
      }
    } catch (e) {
      // 如果加载失败，使用默认值
      // print('Failed to load settings: $e');
      final prefs = await SharedPreferences.getInstance();
      state = AppSettings(
        chineseFontId: prefs.getString('chineseFontId') ?? 'preset_noto_sans_sc',
        englishFontId: prefs.getString('englishFontId') ?? 'preset_noto_sans_sc',
      );
    }
  }

  Future<void> setChineseFont(String fontId) async {
    if (kIsWeb) {
      try {
        await ApiService.updateSettingsCategory('appearance', {'font_family': fontId});
      } catch (e) {
        // print('Failed to save font to backend: $e');
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chineseFontId', fontId);
    state = state.copyWith(chineseFontId: fontId);
  }

  Future<void> setEnglishFont(String fontId) async {
    if (kIsWeb) {
      try {
        // 英文字体也需要保存，但目前API只支持一个主字体
        // 我们可以将英文字体保存在其他字段
        await ApiService.updateSettingsCategory('appearance', {'font_family': fontId});
      } catch (e) {
        // print('Failed to save font to backend: $e');
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('englishFontId', fontId);
    state = state.copyWith(englishFontId: fontId);
  }

  Future<void> updateAppSettings(Map<String, dynamic> updates) async {
    if (kIsWeb) {
      try {
        final settingsData = await ApiService.updateAppSettings(updates);
        state = AppSettings.fromJson(settingsData['settings']);
      } catch (e) {
        // print('Failed to update settings on backend: $e');
      }
    }
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
