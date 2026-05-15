import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart'; // ignore: unused_import

/// 占位：旧 Android sqlite3 打开兼容性处理（保留为空实现以便编译通过）
Future<void> applyWorkaroundToOpenSqlite3OnOldAndroidVersions() async {
  return;
}

QueryExecutor createFileSyncExecutor() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dir.path, 'file_sync.db'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    return NativeDatabase.createInBackground(dbFile);
  });
}
