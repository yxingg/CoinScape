import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import '../utils/logger.dart';

class LocalConfigService {
  static const String _configFileName = 'app_config.json';
  static Map<String, dynamic>? _cache;

  static Future<io.File?> _getConfigFile() async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = io.File('${dir.path}/$_configFileName');
      return file;
    } catch (e) {
      AppLogger.error('Config', '获取配置文件路径失败: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> load() async {
    if (_cache != null) return _cache!;

    if (kIsWeb) {
      _cache = {};
      return _cache!;
    }

    try {
      final file = await _getConfigFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        _cache = jsonDecode(content) as Map<String, dynamic>;
        // 平台劫持：在原始 JSON 中保留字段结构，但在 Android/iOS 等原生平台执行 IO 时，
        // 强制将 backend.save_path 重定向到应用私有目录，避免使用不可用的外部路径。
        try {
          final dir = await getApplicationDocumentsDirectory();
          final backend = _cache!['backend'] as Map<String, dynamic>?;
          if (backend != null) {
            backend['save_path'] = dir.path;
          } else {
            _cache!['backend'] = {'save_path': dir.path};
          }
        } catch (e) {
          // 忽略重定向失败，保留原始配置
        }
        AppLogger.info('Config', '已加载本地配置文件');
        return _cache!;
      }
    } catch (e) {
      AppLogger.error('Config', '加载配置文件失败: $e');
    }

    _cache = {};
    return _cache!;
  }

  static Future<void> save(Map<String, dynamic> data) async {
    _cache = data;

    if (kIsWeb) return;

    try {
      final file = await _getConfigFile();
      if (file != null) {
        final content = jsonEncode(data);
        await file.writeAsString(content);
        AppLogger.info('Config', '已保存本地配置文件');
      }
    } catch (e) {
      AppLogger.error('Config', '保存配置文件失败: $e');
    }
  }

  static Future<T?> get<T>(String key) async {
    final data = await load();
    return data[key] as T?;
  }

  static Future<void> set(String key, dynamic value) async {
    final data = await load();
    data[key] = value;
    await save(data);
  }

  static Future<Map<String, dynamic>> getSection(String section) async {
    final data = await load();
    return (data[section] as Map<String, dynamic>?) ?? {};
  }

  static Future<void> setSection(String section, Map<String, dynamic> sectionData) async {
    final data = await load();
    data[section] = sectionData;
    await save(data);
  }
}
