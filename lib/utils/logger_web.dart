import 'dart:developer' as developer;
import 'dart:html' as html;

Future<String?> initLogWriter() async {
  return 'web://localStorage/logs/coinscape.log';
}

Future<void> appendLog(String line) async {
  try {
    final storage = html.window.localStorage;
    const key = 'coinscape_logs';

    String existingLogs = storage[key] ?? '';
    final updatedLogs = '$existingLogs$line\n';

    final lines = updatedLogs.split('\n');
    if (lines.length > 1000) {
      final recentLines = lines.sublist(lines.length - 1000);
      storage[key] = recentLines.join('\n');
    } else {
      storage[key] = updatedLogs;
    }
  } catch (e) {
    developer.log('Web日志存储失败: $e\n原始日志: $line', level: 1000, name: 'LOGGER');
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
      developer.log('清空Web日志失败: $e', level: 1000, name: 'LOGGER');
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
 
