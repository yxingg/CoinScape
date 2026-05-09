import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/font_manager.dart';
import 'settings_provider.dart';
import '../utils/logger.dart';

/// 全局字体族提供程序，用于动态加载和应用自定义字体
final fontFamilyProvider = FutureProvider.autoDispose<String?>((ref) async {
  // 获取当前设置
  final settings = ref.watch(settingsProvider);
  
  // 如果字体是默认字体，则不加载自定义字体
  if (settings.chineseFontId == FontManager.defaultFontId) {
    return null;
  }
  
  // 检查字体是否存在
  final hasFont = await FontManager.hasFont(settings.chineseFontId);
  if (!hasFont) {
    AppLogger.error(logPrefixFont, 'Font ${settings.chineseFontId} not found');
    return null;
  }
  
  try {
    // 目前使用简单实现：仅返回字体族名称
    // 实际字体加载将由前端CSS或通过其他机制处理
    final fontFamilyName = 'CustomFont_${settings.chineseFontId}';
    AppLogger.info(logPrefixFont, 'Using font family: $fontFamilyName');
    
    return fontFamilyName;
  } catch (e) {
    AppLogger.error(logPrefixFont, 'Error loading font ${settings.chineseFontId}: $e');
    return null;
  }
});

/// 获取当前活跃的字体族名称
final activeFontFamilyProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsProvider);
  final loadedFontAsync = ref.watch(fontFamilyProvider);
  
  // 如果字体正在加载或加载成功，使用自定义字体
  if (loadedFontAsync is AsyncData<String?>) {
    final loadedFont = loadedFontAsync.value;
    if (loadedFont != null) {
      return loadedFont;
    }
  }
  
  // 否则使用系统默认字体
  if (settings.chineseFontId != FontManager.defaultFontId) {
    return 'CustomFont_${settings.chineseFontId}';
  }
  
  // 返回默认字体
  return 'default';
});

/// 构建使用自定义字体的主题
final appThemeWithFontProvider = Provider<ThemeData>((ref) {
  final baseTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blueGrey,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );
  
  final fontFamily = ref.watch(activeFontFamilyProvider);
  
  // 如果字体不是默认字体，应用自定义字体
  if (fontFamily != 'default') {
    return baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(
        fontFamily: fontFamily,
      ),
      primaryTextTheme: baseTheme.primaryTextTheme.apply(
        fontFamily: fontFamily,
      ),
    );
  }
  
  return baseTheme;
});