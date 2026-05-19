import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'logger_stub.dart'
  if (dart.library.io) 'logger_io.dart'
  if (dart.library.html) 'logger_web.dart'
  if (dart.library.js_interop) 'logger_worker.dart' as platform;

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
  static bool _initialized = false;
  static LogLevel _currentLogLevel = LogLevel.info;
  static final Map<String, String> _modulePrefixes = {
    'app': logPrefixApp,
    'database': logPrefixDb,
    'ui': logPrefixUI,
    'font': logPrefixFont,
    'settings': logPrefixSettings,
    'sync': logPrefixSync,
    'api': logPrefixApi,
    'image': logPrefixImage,
  };

  /// 初始化日志系统
  static Future<void> init() async {
    if (_initialized) return;
    
    _logFilePath = await platform.initLogWriter();
    if (_logFilePath != null) {
      info(logPrefixApp, '日志输出路径: $_logFilePath');
    } else {
      info(logPrefixApp, '当前平台未启用日志文件，仅输出到控制台');
    }
    
    // 捕获未处理的异常
    _setupGlobalExceptionHandlers();
    
    _initialized = true;
  }

  /// 重新初始化日志系统（当路径更改时使用）
  static Future<void> reinit() async {
    _logFilePath = null;
    _initialized = false;
    await init();
  }

  static String? get logFilePath => _logFilePath;
  
  /// 获取当前配置的日志路径
  static Future<String?> getConfiguredLogPath() async {
    try {
      return await platform.LogConfig.getConfiguredLogPath();
    } catch (e) {
      // 如果平台不支持，返回null
      return null;
    }
  }

  /// 设置日志路径
  static Future<void> setLogPath(String path) async {
    try {
      await platform.LogConfig.setLogPath(path);
      await reinit();
    } catch (e) {
      error(logPrefixApp, '设置日志路径失败: $e');
      rethrow;
    }
  }
  
  /// 清空Web平台日志
  static Future<void> clearWebLogs() async {
    try {
      await platform.LogConfig.clearWebLogs();
    } catch (e) {
      error(logPrefixApp, '清空Web日志失败: $e');
      rethrow;
    }
  }

  /// 获取当前日志级别
  static LogLevel get currentLogLevel => _currentLogLevel;

  /// 设置日志级别
  static void setLogLevel(LogLevel level) {
    _currentLogLevel = level;
    info(logPrefixApp, '日志级别已设置为: ${level.name.toUpperCase()}');
  }

  /// 检查是否应该记录指定级别的日志
  static bool _shouldLog(LogLevel level) {
    // 如果日志级别为debug，记录所有日志
    // 如果为info，记录info、warning、error
    // 如果为warning，记录warning、error
    // 如果为error，只记录error
    switch (_currentLogLevel) {
      case LogLevel.debug:
        return true; // 记录所有
      case LogLevel.info:
        return level == LogLevel.info || level == LogLevel.warning || level == LogLevel.error;
      case LogLevel.warning:
        return level == LogLevel.warning || level == LogLevel.error;
      case LogLevel.error:
        return level == LogLevel.error;
    }
  }

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
      debugPrint(stackMessage);
      unawaited(platform.appendLog(stackMessage));
    }
  }

  /// 内部日志方法
  static void _log(LogLevel level, String prefix, String message) {
    // 检查是否应该记录此级别的日志
    if (!_shouldLog(level)) {
      return;
    }

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.toString().split('.').last.toUpperCase();
    final logMessage = '[$timestamp] $levelStr $prefix $message';

    // 使用 dart:developer 的 log 函数记录日志
    developer.log(
      logMessage,
      level: _getLoglevel(level),
      name: prefix,
    );

    // 总是打印到控制台用于调试（使用 debugPrint 避免 analyzer 的 avoid_print 警告）
    debugPrint('🎯 LOG [$levelStr]: $logMessage');
    unawaited(platform.appendLog(logMessage));
  }

  /// 清空当前平台的日志（Web/Native 都支持）
  static Future<void> clearLogs() async {
    try {
      await platform.LogConfig.clearLogs();
    } catch (e) {
      error(logPrefixApp, '清空日志失败: $e');
      rethrow;
    }
  }

  /// 导出日志到目标路径（本地平台），返回成功或抛出异常
  static Future<void> exportLog(String destPath) async {
    try {
      await platform.LogConfig.exportLog(destPath);
    } catch (e) {
      error(logPrefixApp, '导出日志失败: $e');
      rethrow;
    }
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

  /// 设置全局异常处理器
  static void _setupGlobalExceptionHandlers() {
    // 捕获Flutter框架异常
    FlutterError.onError = (FlutterErrorDetails details) {
      error(
        logPrefixApp, 
        'FlutterError: ${details.exceptionAsString()}\nLibrary: ${details.library}\nStack: ${details.stack}',
        details.stack,
      );
      
      // 仍然转发给默认的Flutter错误处理
      FlutterError.presentError(details);
    };
  }

  /// 获取指定模块的日志前缀
  static String getModulePrefix(String moduleName) {
    return _modulePrefixes[moduleName.toLowerCase()] ?? '[${moduleName.toUpperCase()}]';
  }

  /// 记录带有自动模块前缀的日志
  static void moduleDebug(String module, String message) {
    debug(getModulePrefix(module), message);
  }
  
  static void moduleInfo(String module, String message) {
    info(getModulePrefix(module), message);
  }
  
  static void moduleWarning(String module, String message) {
    warning(getModulePrefix(module), message);
  }
  
  static void moduleError(String module, String message, [StackTrace? stackTrace]) {
    error(getModulePrefix(module), message, stackTrace);
  }

  /// 记录方法调用日志（用于调试）
  static void methodCall(String className, String methodName, {Map<String, dynamic>? params}) {
    final paramStr = params != null ? ' 参数: ${_formatParams(params)}' : '';
    debug(logPrefixApp, '$className.$methodName()$paramStr');
  }
  
  static String _formatParams(Map<String, dynamic> params) {
    final items = params.entries.map((e) {
      final value = e.value;
      if (value == null) return '${e.key}=null';
      if (value is String) return '${e.key}="${value.length > 50 ? '${value.substring(0, 50)}...' : value}"';
      if (value is Map || value is List) return '${e.key}=${value.runtimeType}';
      return '${e.key}=$value';
    }).toList();
    return items.join(', ');
  }

  /// 读取平台日志内容（仅用于调试/查看），返回字符串
  static Future<String> readLog({int maxChars = 20000}) async {
    try {
      return await platform.readLog(maxChars: maxChars);
    } catch (e) {
      return '读取日志失败: $e';
    }
  }
}
