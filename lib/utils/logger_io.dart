import 'dart:io' as io;
import 'package:shared_preferences/shared_preferences.dart';

String? _logFilePath;

/// 日志配置类
class LogConfig {
  static const String _prefKeyLogPath = 'log_directory_path';
  static const String _defaultLogFileName = 'coinscape.log';
  
  /// 获取用户配置的日志路径，如果未配置则使用默认路径
  static Future<String?> getConfiguredLogPath() async {
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString(_prefKeyLogPath);
    
    if (customPath != null && customPath.isNotEmpty) {
      // 用户配置了自定义路径
      return customPath;
    }
    
    // 使用默认路径：backend/data/logs/ 或应用数据目录
    return await _getDefaultLogPath();
  }
  
  /// 设置自定义日志路径
  static Future<void> setLogPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyLogPath, path);
    // 重置日志文件路径，以便下次init使用新的路径
    _logFilePath = null;
  }
  
  /// 获取默认日志路径
  static Future<String> _getDefaultLogPath() async {
    try {
      // 优先尝试连接到后端API获取配置
      // 这里简化处理，使用固定路径
      final current = io.Directory.current;
      final backendDataDir = _findBackendDataDirectory(current);
      
      if (backendDataDir != null) {
        final defaultLogDir = io.Directory('${backendDataDir.path}${io.Platform.pathSeparator}logs');
        if (!await defaultLogDir.exists()) {
          await defaultLogDir.create(recursive: true);
        }
        return '${defaultLogDir.path}${io.Platform.pathSeparator}$_defaultLogFileName';
      }
      
      // 找不到backend/data，使用应用支持目录
      final appDocDir = await _getApplicationSupportDirectory();
      final logDir = io.Directory('${appDocDir.path}${io.Platform.pathSeparator}coinscape${io.Platform.pathSeparator}logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      return '${logDir.path}${io.Platform.pathSeparator}$_defaultLogFileName';
      
    } catch (e) {
      // 如果所有方法都失败，使用当前目录下的logs文件夹
      final current = io.Directory.current;
      final logDir = io.Directory('${current.path}${io.Platform.pathSeparator}logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      return '${logDir.path}${io.Platform.pathSeparator}$_defaultLogFileName';
    }
  }
  
  /// 获取应用支持目录（平台相关）
  static Future<io.Directory> _getApplicationSupportDirectory() async {
    if (io.Platform.isWindows) {
      final appData = io.Platform.environment['APPDATA'] ?? '';
      final appDataDir = io.Directory('$appData${io.Platform.pathSeparator}CoinScape');
      if (!await appDataDir.exists()) {
        await appDataDir.create(recursive: true);
      }
      return appDataDir;
    } else {
      // 对于非Windows平台，使用当前目录
      return io.Directory.current;
    }
  }
  
  /// 清空日志文件（非Web平台）
  static Future<void> clearWebLogs() async {
    // 对于非Web平台，这是一个空实现
    // 对于移动/桌面平台，日志文件存储在文件系统中，需要不同的清理方式
    return;
  }
}

Future<String?> initLogWriter() async {
  if (_logFilePath != null) return _logFilePath;

  final logPath = await LogConfig.getConfiguredLogPath();
  if (logPath == null) return null;
  
  final logFile = io.File(logPath);
  final logDir = logFile.parent;
  
  // 创建日志目录
  if (!await logDir.exists()) {
    try {
      await logDir.create(recursive: true);
    } catch (e) {
      // 静默失败，返回 null 让调用方处理
      return null;
    }
  }
  
  // 创建日志文件
  if (!await logFile.exists()) {
    try {
      await logFile.create(recursive: true);
    } catch (e) {
      // 静默失败，返回 null 让调用方处理
      return null;
    }
  }

  _logFilePath = logFile.path;
  
  // 定期检查日志文件大小，如果超过限制则旋转
  _checkLogFileSize(logFile);
  
  return _logFilePath;
}

io.Directory? _findBackendDataDirectory(io.Directory start) {
  var dir = start;
  while (true) {
    final candidate = io.Directory('${dir.path}${io.Platform.pathSeparator}backend${io.Platform.pathSeparator}data');
    if (candidate.existsSync()) {
      return candidate;
    }

    final parent = dir.parent;
    if (parent.path == dir.path) {
      return null;
    }
    dir = parent;
  }
}

/// 检查日志文件大小，如果超过10MB则执行旋转
Future<void> _checkLogFileSize(io.File logFile) async {
  try {
    final stat = await logFile.stat();
    // 如果文件超过10MB，旋转日志
    if (stat.size > 10 * 1024 * 1024) {
      await _rotateLogFile(logFile);
    }
  } catch (e) {
    // 忽略文件大小检查错误
  }
}

/// 旋转日志文件
Future<void> _rotateLogFile(io.File logFile) async {
  try {
    final logDir = logFile.parent;
    
    // 查找现有的日志备份文件
    final backupPattern = RegExp(r'coinscape\.log\.(\d+)');
    int maxBackupNumber = 0;
    
    final files = await logDir.list().toList();
    for (final file in files) {
      final fileName = file.path.split(io.Platform.pathSeparator).last;
      final match = backupPattern.firstMatch(fileName);
      if (match != null) {
        final num = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (num > maxBackupNumber) {
          maxBackupNumber = num;
        }
      }
    }
    
    // 保留最多5个备份文件
    if (maxBackupNumber >= 5) {
      // 删除最旧的备份
      final oldest = io.File('${logDir.path}${io.Platform.pathSeparator}coinscape.log.$maxBackupNumber');
      if (await oldest.exists()) {
        await oldest.delete();
      }
      maxBackupNumber--;
    }
    
    // 重命名现有日志文件
    for (var i = maxBackupNumber; i >= 1; i--) {
      final oldFile = io.File('${logDir.path}${io.Platform.pathSeparator}coinscape.log.$i');
      final newFile = io.File('${logDir.path}${io.Platform.pathSeparator}coinscape.log.${i + 1}');
      if (await oldFile.exists()) {
        await oldFile.rename(newFile.path);
      }
    }
    
    // 重命名当前日志文件为第一个备份
    final backupFile = io.File('${logDir.path}${io.Platform.pathSeparator}coinscape.log.1');
    if (await logFile.exists()) {
      await logFile.rename(backupFile.path);
    }
    
    // 创建新的日志文件
    await logFile.create(recursive: true);
    
    // 记录日志旋转事件
    await backupFile.writeAsString(
      '\n========== 日志文件已旋转 ========== ${DateTime.now().toIso8601String()}\n',
      mode: io.FileMode.append,
      flush: true,
    );
    
  } catch (e) {
    // 忽略日志旋转失败
  }
}

Future<void> appendLog(String line) async {
  final path = _logFilePath;
  if (path == null) return;

  try {
    await io.File(path).writeAsString(
      '$line${io.Platform.lineTerminator}',
      mode: io.FileMode.append,
      flush: true,
    );
    
    // 每次写入后检查文件大小
    final logFile = io.File(path);
    await _checkLogFileSize(logFile);
  } catch (e) {
    // 如果写入失败，重置日志文件路径，下次自动重新创建
    _logFilePath = null;
  }
}