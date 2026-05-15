export 'file_sync_executor_unsupported.dart'
    if (dart.library.ffi) 'file_sync_executor_native.dart'
    if (dart.library.js) 'file_sync_executor_web.dart';
