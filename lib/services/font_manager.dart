import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:io' as io;
import 'api_service.dart';
import '../utils/logger.dart';

class FontManager {
  // Web端暂存字体字节用的内存映射 (fontId -> bytes) - 仅作为后备缓存
  static final Map<String, Uint8List> _webMemoryCache = {};

  static const Map<String, String> presetFontsUrls = {
    'preset_noto_sans_sc_regular': 'https://fonts.gstatic.com/s/notosanssc/v37/k3kCo84MPvpLmixcA63oeAL7Iqp5IZJF9bmaG9_FnYxNbPzS5HE.ttf',
    'preset_noto_sans_sc_bold': 'https://fonts.gstatic.com/s/notosanssc/v37/k3kCo84MPvpLmixcA63oeAL7Iqp5IZJF9bmaGzjCnYxNbPzS5HE.ttf',
    'preset_roboto_regular': 'https://fonts.gstatic.com/s/roboto/v30/KFOmCnqEu92Fr1Me5WZLCzYlKw.ttf',
  };

  /// 从特定 URL 下载预设字体并永久保存
  static Future<bool> downloadAndSavePresetFont(String fontId) async {
    final url = presetFontsUrls[fontId];
    if (url == null) return false;

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await saveFont(fontId, response.bodyBytes);
        return true;
      }
    } catch (e) {
      AppLogger.error(logPrefixFont, "Download font failed: $e");
    }
    return false;
  }

  /// 允许用户自行选择手机/电脑里的 .ttf 文件并保存
  static Future<String?> pickAndSaveCustomFont() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ttf', 'otf'],
      withData: kIsWeb, // Web端必须读取数据
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      Uint8List? bytes;

      if (kIsWeb) {
        bytes = file.bytes;
      } else {
        if (file.path != null) {
          bytes = await io.File(file.path!).readAsBytes();
        }
      }

      if (bytes != null) {
        // 使用时间戳或者文件名作为 fontId
        final fontId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
        await saveFont(fontId, bytes);
        return fontId;
      }
    }
    return null;
  }

  /// 储存字体字节到底层
  static Future<void> saveFont(String fontId, Uint8List bytes) async {
    if (kIsWeb) {
      // Web 端：上传到后端服务器
      try {
        final serverFontId = await ApiService.uploadFont(bytes, '$fontId.ttf');
        _webMemoryCache[fontId] = bytes;
        AppLogger.info(logPrefixFont, "Font saved to server: $serverFontId");
      } catch (e) {
        // 后端不可用时，回退到内存缓存
        _webMemoryCache[fontId] = bytes;
        AppLogger.warning(logPrefixFont, "Font saved to memory cache (backend unavailable): $e");
      }
      return;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = io.File('${dir.path}/fonts/$fontId.ttf');
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsBytes(bytes);
    }
  }

  /// 加载字体字节
  static Future<Uint8List?> loadFont(String fontId) async {
    if (kIsWeb) {
      // 先检查内存缓存
      if (_webMemoryCache.containsKey(fontId)) {
        return _webMemoryCache[fontId];
      }
      // 尝试从后端加载
      try {
        final response = await http.get(Uri.parse(ApiService.getFontUrl(fontId)));
        if (response.statusCode == 200) {
          _webMemoryCache[fontId] = response.bodyBytes;
          return response.bodyBytes;
        }
      } catch (e) {
        AppLogger.error(logPrefixFont, "Load font from server failed: $e");
      }
      return null;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = io.File('${dir.path}/fonts/$fontId.ttf');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    }
  }
  
  /// 检查字体是否存在
  static Future<bool> hasFont(String fontId) async {
    if (kIsWeb) {
      // 先检查内存缓存
      if (_webMemoryCache.containsKey(fontId)) {
        return true;
      }
      // 再检查后端
      try {
        return await ApiService.checkFontExists(fontId);
      } catch (_) {
        return false;
      }
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = io.File('${dir.path}/fonts/$fontId.ttf');
      return await file.exists();
    }
  }

  /// 删除字体
  static Future<void> deleteFont(String fontId) async {
    if (kIsWeb) {
      _webMemoryCache.remove(fontId);
      try {
        await ApiService.deleteFont(fontId);
      } catch (_) {}
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = io.File('${dir.path}/fonts/$fontId.ttf');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
