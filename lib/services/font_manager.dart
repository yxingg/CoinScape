import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' as io;
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';
import 'api_service.dart';

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

  /// 获取所有可用字体的列表（包含后端字体）
  static Future<List<LocalFontInfo>> getLocalFonts() async {
    if (kIsWeb && _localFonts.isEmpty) {
      await _loadServerFonts();
    } else if (_localFonts.isEmpty) {
      await _loadLocalFonts();
    }
    return _localFonts;
  }

  /// 从后端服务器加载字体列表
  static Future<void> _loadServerFonts() async {
    try {
      final fontsData = await ApiService.getFontsList();
      _localFonts = fontsData.map((fontData) {
        final filename = fontData['filename'] as String;
        final fontId = fontData['id'] as String;
        final name = fontId.replaceAll('_', ' ').replaceAll('custom', '自定义');
        final ext = filename.toLowerCase().endsWith('.otf') ? 'otf' : 'ttf';
        
        return LocalFontInfo(
          id: fontId,
          name: name,
          fileExtension: ext,
          addedAt: DateTime.fromMillisecondsSinceEpoch((fontData['modified_at'] as num).toInt() * 1000),
        );
      }).toList();
      
      AppLogger.info(logPrefixFont, "从后端加载了 ${_localFonts.length} 个字体");
    } catch (e) {
      AppLogger.error(logPrefixFont, "从后端加载字体列表失败: $e");
      _localFonts = await _loadLocalFontsFallback();
    }
  }

  /// 加载本地字体配置（原生端备用）
  static Future<List<LocalFontInfo>> _loadLocalFonts() async {
    try {
      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        final configFile = io.File('${dir.path}/fonts/$_fontsConfigFileName');
        if (await configFile.exists()) {
          final content = await configFile.readAsString();
          final data = jsonDecode(content) as List<dynamic>;
          _localFonts = data.map((item) => LocalFontInfo.fromJson(item as Map<String, dynamic>)).toList();
          return _localFonts;
        }
      }
    } catch (e) {
      AppLogger.error(logPrefixFont, "加载本地字体配置失败: $e");
    }
    return _localFonts = [];
  }

  /// 后备加载方案
  static Future<List<LocalFontInfo>> _loadLocalFontsFallback() async {
    // Web端失败时使用一个空的列表
    if (kIsWeb) {
      return [];
    }
    return await _loadLocalFonts();
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
          String fontId;
          
          if (kIsWeb) {
            // Web端：上传到后端服务器
            try {
              fontId = await ApiService.uploadFont(bytes, file.name);
              
              // 重新加载字体列表以获取最新字体信息
              await _loadServerFonts();
            } catch (e) {
              AppLogger.error(logPrefixFont, "字体上传到服务器失败: $e");
              continue;
            }
          } else {
            // 原生端：本地保存
            // 使用文件名（移除扩展名）作为字体名
            String fileName = file.name;
            final lastDot = fileName.lastIndexOf('.');
            if (lastDot != -1) {
              fileName = fileName.substring(0, lastDot);
            }
            
            // 生成唯一ID
            fontId = 'custom_${DateTime.now().millisecondsSinceEpoch}_${fontIds.length}';
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
          }
          
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
    if (kIsWeb) {
      // Web端：调用后端API删除字体
      try {
        await ApiService.deleteFont(fontId);
        // 从本地缓存中移除
        _localFonts.removeWhere((font) => font.id == fontId);
        AppLogger.info(logPrefixFont, "已从后端删除字体: $fontId");
      } catch (e) {
        AppLogger.error(logPrefixFont, "删除字体失败: $e");
        rethrow;
      }
    } else {
      // 原生端：本地删除
      // 从列表中移除
      _localFonts.removeWhere((font) => font.id == fontId);
      await _saveLocalFontsConfig();
      
      // 删除字体文件
      await _deleteFontFile(fontId);
      
      AppLogger.info(logPrefixFont, "已移除字体: $fontId");
    }
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
        _webMemoryCache[_fontsConfigFileName] = Uint8List.fromList(utf8.encode(configJson));
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
  
  

  /// 加载字体字节
  static Future<Uint8List?> loadFont(String fontId) async {
    if (fontId == defaultFontId) {
      // 默认系统字体，返回null让PDF使用默认字体
      return null;
    }
    
    if (kIsWeb) {
      // Web端：从后端服务器下载字体
      try {
        final response = await http.get(Uri.parse(ApiService.getFontUrl(fontId)));
        if (response.statusCode == 200) {
          return response.bodyBytes;
        }
        AppLogger.warning(logPrefixFont, "字体加载失败 (${response.statusCode}): $fontId");
        return null;
      } catch (e) {
        AppLogger.error(logPrefixFont, "字体加载错误: $e");
        return null;
      }
    } else {
      // 原生端：从本地文件加载
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
      // Web端：检查后端API
      try {
        return await ApiService.checkFontExists(fontId);
      } catch (e) {
        AppLogger.warning(logPrefixFont, "检查字体存在失败: $e");
        return false;
      }
    } else {
      // 原生端：检查本地文件
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
