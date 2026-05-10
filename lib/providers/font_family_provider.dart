import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/font_manager.dart';
import 'settings_provider.dart';
import '../utils/logger.dart';

String? _registeredFontFamily;

Future<String?> _loadAndRegisterFont(String fontId) async {
  if (fontId == FontManager.defaultFontId || fontId == 'default') {
    return null;
  }

  final fontBytes = await FontManager.loadFont(fontId);
  if (fontBytes == null) return null;

  final fontLoader = FontLoader(fontId);
  fontLoader.addFont(Future.value(fontBytes.buffer.asByteData()));
  await fontLoader.load();

  return fontId;
}

final fontFamilyProvider = FutureProvider.autoDispose<String?>((ref) async {
  final settings = ref.watch(settingsProvider);

  final fontId = settings.displayFontId;
  if (fontId == FontManager.defaultFontId || fontId == 'default') {
    _registeredFontFamily = null;
    return null;
  }

  try {
    final familyName = await _loadAndRegisterFont(fontId);
    if (familyName != null) {
      _registeredFontFamily = familyName;
      AppLogger.info(logPrefixFont, '已注册显示字体: $familyName');
    }
    return familyName;
  } catch (e) {
    AppLogger.error(logPrefixFont, '加载显示字体失败 $fontId: $e');
    return null;
  }
});

final activeFontFamilyProvider = Provider<String>((ref) {
  final loadedFontAsync = ref.watch(fontFamilyProvider);

  if (loadedFontAsync is AsyncData<String?>) {
    final loadedFont = loadedFontAsync.value;
    if (loadedFont != null) {
      return loadedFont;
    }
  }

  if (_registeredFontFamily != null) {
    return _registeredFontFamily!;
  }

  return 'default';
});

double _densityToVisualDensity(String density) {
  switch (density) {
    case 'compact':
      return -2.0;
    case 'comfortable':
      return 0.0;
    case 'expanded':
      return 2.0;
    default:
      return 0.0;
  }
}

final appThemeWithFontProvider = Provider<ThemeData>((ref) {
  final settings = ref.watch(settingsProvider);

  final baseTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blueGrey,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    visualDensity: VisualDensity(
      horizontal: _densityToVisualDensity(settings.density),
      vertical: _densityToVisualDensity(settings.density),
    ),
  );

  final fontFamily = ref.watch(activeFontFamilyProvider);
  final fontSize = settings.fontSize;

  if (fontFamily != 'default') {
    return baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(
        fontFamily: fontFamily,
        fontSizeFactor: fontSize / 14.0,
      ),
      primaryTextTheme: baseTheme.primaryTextTheme.apply(
        fontFamily: fontFamily,
        fontSizeFactor: fontSize / 14.0,
      ),
    );
  }

  if (fontSize != 14.0) {
    return baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontSizeFactor: fontSize / 14.0),
      primaryTextTheme: baseTheme.primaryTextTheme.apply(fontSizeFactor: fontSize / 14.0),
    );
  }

  return baseTheme;
});
