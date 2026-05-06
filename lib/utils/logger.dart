import 'dart:async';
import 'dart:developer' as developer;

import 'logger_stub.dart' if (dart.library.io) 'logger_io.dart' as platform;

/// 日志前缀常量
const String logPrefixApp = '[APP]';
const String logPrefixDb = '[DATABASE]';
const String logPrefixUI = '[UI]';
const String logPrefixFont = '[FONT]';
const String logPrefixSettings = '[SETTINGS]';
const String logPrefixSync = '[SYNC]';
const String logPrefixApi = '[API]';
const String logPrefixImage = '[IMAGE]';

/// 日志级别枚举
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// 应用日志管理器
class AppLogger {
  static String? _logFilePath;

  /// 初始化日志系统
  static Future<void> init() async {
    _logFilePath = await platform.initLogWriter();
    if (_logFilePath != null) {
      info(logPrefixApp, '日志输出路径: $_logFilePath');
    } else {
      info(logPrefixApp, '当前平台未启用日志文件，仅输出到控制台');
    }
  }

  static String? get logFilePath => _logFilePath;

  /// 调试日志
  static void debug(String prefix, String message) {
    _log(LogLevel.debug, prefix, message);
  }

  /// 信息日志
  static void info(String prefix, String message) {
    _log(LogLevel.info, prefix, message);
  }

  /// 警告日志
  static void warning(String prefix, String message) {
    _log(LogLevel.warning, prefix, message);
  }

  /// 错误日志
  static void error(String prefix, String message, [StackTrace? stackTrace]) {
    _log(LogLevel.error, prefix, message);
    if (stackTrace != null) {
      final timestamp = DateTime.now().toIso8601String();
      final stackMessage = '[$timestamp] ERROR $prefix Stack trace: $stackTrace';
      developer.log(
        stackMessage,
        level: 1000,
        name: '$prefix.stacktrace',
      );
      print(stackMessage);
      unawaited(platform.appendLog(stackMessage));
    }
  }

  /// 内部日志方法
  static void _log(LogLevel level, String prefix, String message) {
    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.toString().split('.').last.toUpperCase();
    final logMessage = '[$timestamp] $levelStr $prefix $message';

    // 使用 dart:developer 的 log 函数记录日志
    developer.log(
      logMessage,
      level: _getLoglevel(level),
      name: prefix,
    );

    // 在开发模式下同时打印到控制台
    print(logMessage);
    unawaited(platform.appendLog(logMessage));
  }

  /// 将 LogLevel 转换为 dart:developer 的日志级别
  static int _getLoglevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 400;
      case LogLevel.info:
        return 500;
      case LogLevel.warning:
        return 800;
      case LogLevel.error:
        return 1000;
    }
  }
}
