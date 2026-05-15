import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_browser.dart' as idb_browser;

/// Browser/Worker 实现：从 idb_shim 提供的浏览器工厂返回 `idbFactory`。
IdbFactory get idbFactory => idb_browser.idbFactoryBrowser;
