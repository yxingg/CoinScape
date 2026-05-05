import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final String chineseFontId;
  final String englishFontId;

  AppSettings({
    required this.chineseFontId,
    required this.englishFontId,
  });

  AppSettings copyWith({
    String? chineseFontId,
    String? englishFontId,
  }) {
    return AppSettings(
      chineseFontId: chineseFontId ?? this.chineseFontId,
      englishFontId: englishFontId ?? this.englishFontId,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings(chineseFontId: 'default', englishFontId: 'default')) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      chineseFontId: prefs.getString('chineseFontId') ?? 'preset_noto_sans_sc',
      englishFontId: prefs.getString('englishFontId') ?? 'preset_noto_sans_sc',
    );
  }

  Future<void> setChineseFont(String fontId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chineseFontId', fontId);
    state = state.copyWith(chineseFontId: fontId);
  }

  Future<void> setEnglishFont(String fontId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('englishFontId', fontId);
    state = state.copyWith(englishFontId: fontId);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
