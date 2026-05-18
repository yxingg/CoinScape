import 'dart:async';
import 'package:idb_shim/idb.dart';
import 'idb_factory.dart';

/// Worker/WASM 环境下的日志实现：不依赖 `dart:html` 或 `dart:io`。
/// 使用 IndexedDB 持久化日志，若打开失败则回退到内存缓冲。

const String _dbName = 'coinscape_logs_db';
const String _storeName = 'logs';

Database? _db;
bool _dbOpening = false;
final List<Map<String, dynamic>> _buffer = <Map<String, dynamic>>[];

Future<String?> initLogWriter() async {
  if (_db != null) return 'worker://indexeddb/$_dbName';
  await _openDb();
  return _db != null ? 'worker://indexeddb/$_dbName' : 'worker://memory/logs/coinscape.log';
}

Future<void> _openDb() async {
  if (_db != null || _dbOpening) return;
  _dbOpening = true;
  try {
    final factory = idbFactory; // idbFactory from idb_factory.dart
    _db = await factory.open(_dbName, version: 1, onUpgradeNeeded: (VersionChangeEvent e) {
      final db = e.database;
      if (!db.objectStoreNames.contains(_storeName)) {
        db.createObjectStore(_storeName, autoIncrement: true);
      }
    });

    // flush buffer to IndexedDB
    if (_buffer.isNotEmpty) {
      final txn = _db!.transaction(_storeName, idbModeReadWrite);
      final store = txn.objectStore(_storeName);
      for (final item in _buffer) {
        await store.add(item);
      }
      await txn.completed;
      _buffer.clear();
    }
  } catch (e) {
    // 如果打开 IndexedDB 失败，就保留在内存缓冲中
  } finally {
    _dbOpening = false;
  }
}

Future<void> appendLog(String line) async {
  final record = {'timestamp': DateTime.now().toIso8601String(), 'line': line};
  if (_db != null) {
    try {
      final txn = _db!.transaction(_storeName, idbModeReadWrite);
      final store = txn.objectStore(_storeName);
      await store.add(record);
      await txn.completed;
    } catch (e) {
      // 如果写入出错则回退到内存缓冲
      _buffer.add(record);
      if (_buffer.length > 1000) {
        _buffer.removeRange(0, _buffer.length - 1000);
      }
    }
  } else {
    _buffer.add(record);
    if (_buffer.length > 1000) {
      _buffer.removeRange(0, _buffer.length - 1000);
    }
    // 尝试异步打开 DB（不阻塞调用方）
    unawaited(_openDb());
  }
}

/// 读取所有日志（按插入顺序）。仅为调试/导出使用，谨慎调用以免阻塞 UI/worker。
Future<List<Map<String, dynamic>>> readAllLogs() async {
  if (_db == null) await _openDb();
  if (_db == null) {
    // 返回缓冲区的副本
    return List<Map<String, dynamic>>.from(_buffer);
  }
  final txn = _db!.transaction(_storeName, idbModeReadOnly);
  final store = txn.objectStore(_storeName);
  final List<Map<String, dynamic>> out = [];
  try {
    final cursorStream = store.openCursor(autoAdvance: false);
    await for (final cursor in cursorStream) {
      final value = cursor.value;
      if (value is Map<String, dynamic>) {
        out.add(Map<String, dynamic>.from(value));
      }
    }
    await txn.completed;
  } catch (_) {
    // 忽略读取错误
  }
  // 合并缓冲区尾部（尚未刷到 DB 的日志）
  out.addAll(_buffer);
  return out;
}

class LogConfig {
  static Future<String?> getConfiguredLogPath() async {
    return _db != null ? 'worker://indexeddb/$_dbName' : 'worker://memory/logs/coinscape.log';
  }

  static Future<void> setLogPath(String path) async {
    // Worker 环境不支持外部路径配置，空实现以保证兼容性
    return;
  }

  static Future<void> clearWebLogs() async {
    _buffer.clear();
    if (_db != null) {
      try {
        final txn = _db!.transaction(_storeName, idbModeReadWrite);
        final store = txn.objectStore(_storeName);
        await store.clear();
        await txn.completed;
      } catch (_) {}
    }
  }

  static Future<void> clearLogs() async {
    await clearWebLogs();
  }
}

/// 读取 Worker/IndexedDB 中的日志并返回字符串形式（尾部限制）
Future<String> readLog({int maxChars = 20000}) async {
  try {
    final entries = await readAllLogs();
    final buffer = StringBuffer();
    for (final e in entries) {
      final line = e['line'] as String? ?? '';
      buffer.writeln(line);
    }
    final result = buffer.toString();
    if (result.length <= maxChars) return result;
    return result.substring(result.length - maxChars);
  } catch (e) {
    return '读取 Worker 日志失败: $e';
  }
}
