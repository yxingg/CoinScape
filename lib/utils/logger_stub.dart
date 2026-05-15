// 默认平台存根：不依赖 `dart:html`，提供安全的 no-op 实现
import 'dart:async';

Future<String?> initLogWriter() async {
  // 默认实现不提供持久化日志路径
  return null;
}

Future<void> appendLog(String line) async {
  // 默认不写入任何外部存储，仅保留在控制台（由 AppLogger 处理）
  return;
}

/// 日志配置类存根（默认实现）
class LogConfig {
  static Future<String?> getConfiguredLogPath() async {
    return null;
  }

  static Future<void> setLogPath(String path) async {
    // 默认为空实现
    return;
  }

  /// Web 专用的清理接口在默认实现下为空
  static Future<void> clearWebLogs() async {
    return;
  }

  /// 通用清空日志接口（供 AppLogger 调用）
  static Future<void> clearLogs() async {
    return;
  }
}