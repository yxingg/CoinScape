import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' as io;
import 'dart:convert';
import '../utils/logger.dart';

/// 本地字体信息
class LocalFontInfo {
  final String id;
  final String name;
  final String fileExtension;
  final DateTime addedAt;
  
  LocalFontInfo({
    required this.id,
    required this.name,
    required this.fileExtension,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'fileExtension': fileExtension,
    'addedAt': addedAt.toIso8601String(),
  };

  factory LocalFontInfo.fromJson(Map<String, dynamic> json) => LocalFontInfo(
    id: json['id'],
    name: json['name'],
    fileExtension: json['fileExtension'],
    addedAt: DateTime.parse(json['addedAt']),
  );
}

class FontManager {
  // Web端暂存字体字节用的内存映射 (fontId -> bytes) - 仅作为后备缓存
  static final Map<String, Uint8List> _webMemoryCache = {};
  
  // 本地字体列表缓存
  static List<LocalFontInfo> _localFonts = [];
  
  // 默认使用的字体ID
  static const String defaultFontId = 'default_system';
  
  // 本地字体配置文件名
  static const String _fontsConfigFileName = 'local_fonts.json';

  /// 获取所有本地字体的列表
  static Future<List<LocalFontInfo>> getLocalFonts() async {
    if (_localFonts.isNotEmpty) return _localFonts;
    
    await _loadLocalFonts();
    return _localFonts;
  }
  
  /// 加载本地字体配置
  static Future<void> _loadLocalFonts() async {
    try {
      if (kIsWeb) {
        // Web端：从内存缓存加载
        final configBytes = _webMemoryCache[_fontsConfigFileName];
        if (configBytes != null) {
          final configJson = utf8.decode(configBytes);
          final data = jsonDecode(configJson) as List<dynamic>;
          _localFonts = data.map((item) => LocalFontInfo.fromJson(item as Map<String, dynamic>)).toList();
        }
      } else {
        // 桌面/移动端：从文件加载
        final dir = await getApplicationDocumentsDirectory();
        final configFile = io.File('${dir.path}/fonts/$_fontsConfigFileName');
        if (await configFile.exists()) {
          final content = await configFile.readAsString();
          final data = jsonDecode(content) as List<dynamic>;
          _localFonts = data.map((item) => LocalFontInfo.fromJson(item as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      AppLogger.error(logPrefixFont, "加载本地字体配置失败: $e");
      _localFonts = [];
    }
  }

  /// 允许用户自行选择手机/电脑里的 .ttf/.otf 文件并保存
  /// 可以同时选择多个文件
  static Future<List<String>> pickAndSaveCustomFonts() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ttf', 'otf'],
      allowMultiple: true, // 允许选择多个文件
      withData: kIsWeb, // Web端必须读取数据
    );

    final fontIds = <String>[];
    
    if (result != null && result.files.isNotEmpty) {
      for (final file in result.files) {
        Uint8List? bytes;

        if (kIsWeb) {
          bytes = file.bytes;
        } else {
          if (file.path != null) {
            bytes = await io.File(file.path!).readAsBytes();
          }
        }

        if (bytes != null && bytes.isNotEmpty) {
          // 使用文件名（移除扩展名）作为字体名
          String fileName = file.name;
          final lastDot = fileName.lastIndexOf('.');
          if (lastDot != -1) {
            fileName = fileName.substring(0, lastDot);
          }
          
          // 生成唯一ID
          final fontId = 'custom_${DateTime.now().millisecondsSinceEpoch}_${fontIds.length}';
          final fileExtension = file.extension ?? 'ttf';
          
          // 保存字体文件
          await _saveFontFile(fontId, bytes);
          
          // 添加字体信息到列表
          await _addLocalFontInfo(
            LocalFontInfo(
              id: fontId,
              name: fileName,
              fileExtension: fileExtension,
              addedAt: DateTime.now(),
            ),
          );
          
          fontIds.add(fontId);
        }
      }
    }
    
    return fontIds;
  }
  
  /// 添加单个字体文件
  static Future<String?> pickAndSaveSingleFont() async {
    final fontIds = await pickAndSaveCustomFonts();
    return fontIds.isNotEmpty ? fontIds.first : null;
  }
  
  /// 保存单个字体文件（内部方法）
  static Future<void> _saveFontFile(String fontId, Uint8List bytes) async {
    if (kIsWeb) {
      // Web 端：保存在内存缓存中
      _webMemoryCache['font_$fontId'] = bytes;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = io.File('${dir.path}/fonts/$fontId.ttf');
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsBytes(bytes);
    }
  }

  /// 添加字体信息到本地列表
  static Future<void> _addLocalFontInfo(LocalFontInfo fontInfo) async {
    // 避免重复添加
    if (_localFonts.any((font) => font.id == fontInfo.id || font.name == fontInfo.name)) {
      return;
    }
    
    _localFonts.add(fontInfo);
    await _saveLocalFontsConfig();
    
    AppLogger.info(logPrefixFont, "已添加字体: ${fontInfo.name} (ID: ${fontInfo.id})");
  }
  
  /// 移除字体
  static Future<void> removeFont(String fontId) async {
    // 从列表中移除
    _localFonts.removeWhere((font) => font.id == fontId);
    await _saveLocalFontsConfig();
    
    // 删除字体文件
    await _deleteFontFile(fontId);
    
    AppLogger.info(logPrefixFont, "已移除字体: $fontId");
  }
  
  /// 删除字体文件（内部方法）
  static Future<void> _deleteFontFile(String fontId) async {
    if (kIsWeb) {
      _webMemoryCache.remove(fontId);
      _webMemoryCache.remove('font_$fontId');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final ttfFile = io.File('${dir.path}/fonts/$fontId.ttf');
      final otfFile = io.File('${dir.path}/fonts/$fontId.otf');
      
      if (await ttfFile.exists()) {
        await ttfFile.delete();
      }
      if (await otfFile.exists()) {
        await otfFile.delete();
      }
    }
  }
  
  /// 保存本地字体配置
  static Future<void> _saveLocalFontsConfig() async {
    try {
      final configJson = jsonEncode(_localFonts.map((font) => font.toJson()).toList());
      
      if (kIsWeb) {
        // Web端：保存在内存缓存中
        _webMemoryCache[_fontsConfigFileName] = utf8.encode(configJson) as Uint8List;
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final configFile = io.File('${dir.path}/fonts/$_fontsConfigFileName');
        if (!await configFile.parent.exists()) {
          await configFile.parent.create(recursive: true);
        }
        await configFile.writeAsString(configJson);
      }
    } catch (e) {
      AppLogger.error(logPrefixFont, "保存本地字体配置失败: $e");
    }
  }
  
  /// Web端存储辅助方法
  static Future<void> _setWebStorageItem(String key, String value) async {
    if (kIsWeb) {
      // Web端：使用内存缓存替代localStorage
      // 注意：这会在页面刷新后丢失，但对于字体来说可以接受
      // 用户可以选择重新导入字体
      _webMemoryCache[key] = Uint8List.fromList(utf8.encode(value));
      AppLogger.warning(logPrefixFont, "Web端字体存储为内存缓存（页面刷新会丢失）");
    }
  }
  
  static Future<String?> _getWebStorageItem(String key) async {
    if (kIsWeb) {
      final bytes = _webMemoryCache[key];
      if (bytes != null) {
        return utf8.decode(bytes);
      }
    }
    return null;
  }
  
  static Future<void> _removeWebStorageItem(String key) async {
    if (kIsWeb) {
      _webMemoryCache.remove(key);
    }
  }

  /// 加载字体字节
  static Future<Uint8List?> loadFont(String fontId) async {
    if (fontId == defaultFontId) {
      // 默认系统字体，返回null让PDF使用默认字体
      return null;
    }
    
    if (kIsWeb) {
      // 从内存缓存加载
      return _webMemoryCache[fontId] ?? _webMemoryCache['font_$fontId'];
    } else {
      final dir = await getApplicationDocumentsDirectory();
      // 首先尝试.ttf扩展名
      final ttfFile = io.File('${dir.path}/fonts/$fontId.ttf');
      if (await ttfFile.exists()) {
        return await ttfFile.readAsBytes();
      }
      // 然后尝试.otf扩展名
      final otfFile = io.File('${dir.path}/fonts/$fontId.otf');
      if (await otfFile.exists()) {
        return await otfFile.readAsBytes();
      }
      return null;
    }
  }
  
  /// 检查字体是否存在
  static Future<bool> hasFont(String fontId) async {
    if (fontId == defaultFontId) return true;
    
    if (kIsWeb) {
      // 检查内存缓存
      return _webMemoryCache.containsKey(fontId) || _webMemoryCache.containsKey('font_$fontId');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final ttfFile = io.File('${dir.path}/fonts/$fontId.ttf');
      final otfFile = io.File('${dir.path}/fonts/$fontId.otf');
      return await ttfFile.exists() || await otfFile.exists();
    }
  }
  
  /// 获取字体名称，如果不存在则返回字体ID
  static String getFontName(String fontId) {
    if (fontId == defaultFontId) return '默认系统字体';
    
    final font = _localFonts.firstWhere(
      (font) => font.id == fontId,
      orElse: () => LocalFontInfo(
        id: fontId,
        name: fontId.startsWith('custom_') ? '自定义字体' : fontId,
        fileExtension: 'ttf',
        addedAt: DateTime.now(),
      ),
    );
    
    return font.name;
  }
  
  /// 清除所有本地字体
  static Future<void> clearAllLocalFonts() async {
    final fontIds = _localFonts.map((font) => font.id).toList();
    
    for (final fontId in fontIds) {
      await _deleteFontFile(fontId);
    }
    
    _localFonts.clear();
    await _saveLocalFontsConfig();
    
    AppLogger.info(logPrefixFont, '已清除所有本地字体');
  }
}
