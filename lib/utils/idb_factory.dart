// Conditional export that provides a top-level `idbFactory` getter
export 'idb_factory_stub.dart'
  if (dart.library.html) 'idb_factory_browser.dart'
  if (dart.library.js_interop) 'idb_factory_browser.dart';
