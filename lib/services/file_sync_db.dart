import 'package:drift/drift.dart';
import 'file_sync_executor.dart';

part 'file_sync_db.g.dart';

class FileIndexTable extends Table {
  TextColumn get path => text()();
  TextColumn get sha256 => text().nullable()();
  IntColumn get size => integer().nullable()();
  RealColumn get mtime => real().nullable()();
  TextColumn get lastSeenAt => text().nullable().named('last_seen_at')();
  TextColumn get lastSyncedAt => text().nullable().named('last_synced_at')();
  TextColumn get remotePath => text().nullable().named('remote_path')();
  TextColumn get remoteEtag => text().nullable().named('remote_etag')();

  @override
  Set<Column> get primaryKey => {path};
}

class SyncQueueTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text()();
  TextColumn get action => text()(); // upload | delete
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending|in-progress|done|failed
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastAttemptAt => text().nullable().named('last_attempt_at')();
  TextColumn get error => text().nullable()();
}

@DriftDatabase(tables: [FileIndexTable, SyncQueueTable])
class FileSyncDb extends _$FileSyncDb {
  static FileSyncDb? _instance;

  FileSyncDb._internal(super.e);

  static Future<FileSyncDb> getInstance() async {
    if (_instance != null) return _instance!;
    final executor = createFileSyncExecutor();
    _instance = FileSyncDb._internal(executor);
    return _instance!;
  }

  @override
  int get schemaVersion => 1;

  // Index helpers
  Future<FileIndexTableData?> getIndexByPath(String pathStr) {
    return (select(fileIndexTable)..where((t) => t.path.equals(pathStr))).getSingleOrNull();
  }

  Future<void> upsertIndex({
    required String pathStr,
    String? sha256,
    int? size,
    double? mtime,
    String? lastSeenAt,
    String? lastSyncedAt,
    String? remotePath,
    String? remoteEtag,
  }) async {
    final companion = FileIndexTableCompanion(
      path: Value(pathStr),
      sha256: Value(sha256),
      size: Value(size),
      mtime: Value(mtime),
      lastSeenAt: Value(lastSeenAt),
      lastSyncedAt: Value(lastSyncedAt),
      remotePath: Value(remotePath),
      remoteEtag: Value(remoteEtag),
    );
    await into(fileIndexTable).insertOnConflictUpdate(companion);
  }

  Future<void> updateIndexSeen(String pathStr, String lastSeenAt) async {
    await (update(fileIndexTable)..where((t) => t.path.equals(pathStr))).write(
      FileIndexTableCompanion(lastSeenAt: Value(lastSeenAt)),
    );
  }

  Future<void> deleteIndex(String pathStr) async {
    await (delete(fileIndexTable)..where((t) => t.path.equals(pathStr))).go();
  }

  // Queue helpers
  Future<int> enqueue(String pathStr, String action) async {
    final entry = SyncQueueTableCompanion(
      path: Value(pathStr),
      action: Value(action),
      status: const Value('pending'),
    );
    return into(syncQueueTable).insert(entry);
  }

  Future<List<SyncQueueTableData>> getPendingQueue({int limit = 100}) async {
    return (select(syncQueueTable)..where((t) => t.status.equals('pending'))..limit(limit)).get();
  }

  Future<void> markQueueInProgress(int id) async {
    await (update(syncQueueTable)..where((t) => t.id.equals(id))).write(
      SyncQueueTableCompanion(status: const Value('in-progress'), attempts: const Value(1)),
    );
  }

  Future<void> updateQueueResult(int id, String status, {String? error}) async {
    await (update(syncQueueTable)..where((t) => t.id.equals(id))).write(
      SyncQueueTableCompanion(
        status: Value(status),
        error: Value(error),
        lastAttemptAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  Future<Map<String, int>> getStatusCounts() async {
    final pending = await (select(syncQueueTable)..where((t) => t.status.equals('pending'))).get();
    final inProgress = await (select(syncQueueTable)..where((t) => t.status.equals('in-progress'))).get();
    final done = await (select(syncQueueTable)..where((t) => t.status.equals('done'))).get();
    final failed = await (select(syncQueueTable)..where((t) => t.status.equals('failed'))).get();
    return {
      'pending': pending.length,
      'in_progress': inProgress.length,
      'done': done.length,
      'failed': failed.length,
    };
  }

  /// Clear historic completed/failed queue entries so per-run counts don't accumulate.
  Future<void> clearHistoricQueue() async {
    await (delete(syncQueueTable)..where((t) => t.status.isIn(['done', 'failed']))).go();
  }

  Future<List<SyncQueueTableData>> getAllQueue() async {
    return select(syncQueueTable).get();
  }
}
