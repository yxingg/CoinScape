import 'package:idb_shim/idb.dart';

/// 非浏览器环境的占位实现：尝试访问 `idbFactory` 会抛出异常，调用方应捕获并回退到内存缓冲。
IdbFactory get idbFactory => throw UnsupportedError('idbFactory is not available on this platform');
