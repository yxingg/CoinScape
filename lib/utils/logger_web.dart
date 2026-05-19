import 'dart:html' as html;
import 'package:flutter/foundation.dart';

Future<String?> initLogWriter() async {
  // Web平台使用localStorage存储日志
  // 返回虚拟路径用于标识
  return 'web://localStorage/logs/coinscape.log';
}

Future<void> appendLog(String line) async {
  try {
    // 尝试使用localStorage存储日志
    final storage = html.window.localStorage;
    const key = 'coinscape_logs';

    // 获取现有的日志
    String existingLogs = storage[key] ?? '';

    // 添加新日志行
    final updatedLogs = '$existingLogs$line\n';

    // 限制日志大小（最多保留最近1000行）
    final lines = updatedLogs.split('\n');
    if (lines.length > 1000) {
      // 只保留最近1000行
      final recentLines = lines.sublist(lines.length - 1000);
      storage[key] = recentLines.join('\n');
    } else {
      storage[key] = updatedLogs;
    }
  } catch (e) {
    // 如果localStorage失败，至少打印到控制台
    debugPrint('Web日志存储失败: $e\n原始日志: $line');
  }
}

/// 日志配置类 - Web 实现
class LogConfig {
  static Future<String?> getConfiguredLogPath() async {
    return 'web://localStorage/logs/coinscape.log';
  }

  static Future<void> setLogPath(String path) async {
    // Web平台忽略路径设置
    return;
  }

  /// 清空Web平台日志
  static Future<void> clearWebLogs() async {
    try {
      final storage = html.window.localStorage;
      storage.remove('coinscape_logs');
    } catch (e) {
      debugPrint('清空Web日志失败: $e');
    }
  }

  /// 通用清空日志接口（供 AppLogger 调用）
  static Future<void> clearLogs() async {
    await clearWebLogs();
  }

  /// 导出日志到目标路径（Web 平台不支持文件系统导出，提供返回失败的占位实现）
  static Future<void> exportLog(String destPath) async {
    throw Exception('Web platform does not support exporting logs to filesystem');
  }
}

/// 读取 Web 平台日志内容
Future<String> readLog({int maxChars = 20000}) async {
  try {
    final storage = html.window.localStorage;
    final key = 'coinscape_logs';
    final content = storage[key] ?? '';
    if (content.length <= maxChars) return content;
    return content.substring(content.length - maxChars);
  } catch (e) {
    return '读取 Web 日志失败: $e';
  }
}
 
