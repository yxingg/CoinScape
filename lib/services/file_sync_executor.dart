export 'file_sync_executor_unsupported.dart'
    if (dart.library.io) 'file_sync_executor_native.dart'
    if (dart.library.html) 'file_sync_executor_web.dart';
