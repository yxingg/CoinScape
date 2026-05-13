// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_sync_db.dart';

// ignore_for_file: type=lint
class $FileIndexTableTable extends FileIndexTable
    with TableInfo<$FileIndexTableTable, FileIndexTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FileIndexTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mtimeMeta = const VerificationMeta('mtime');
  @override
  late final GeneratedColumn<double> mtime = GeneratedColumn<double>(
    'mtime',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<String> lastSeenAt = GeneratedColumn<String>(
    'last_seen_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<String> lastSyncedAt = GeneratedColumn<String>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remotePathMeta = const VerificationMeta(
    'remotePath',
  );
  @override
  late final GeneratedColumn<String> remotePath = GeneratedColumn<String>(
    'remote_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteEtagMeta = const VerificationMeta(
    'remoteEtag',
  );
  @override
  late final GeneratedColumn<String> remoteEtag = GeneratedColumn<String>(
    'remote_etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    path,
    sha256,
    size,
    mtime,
    lastSeenAt,
    lastSyncedAt,
    remotePath,
    remoteEtag,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'file_index_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<FileIndexTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('mtime')) {
      context.handle(
        _mtimeMeta,
        mtime.isAcceptableOrUnknown(data['mtime']!, _mtimeMeta),
      );
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('remote_path')) {
      context.handle(
        _remotePathMeta,
        remotePath.isAcceptableOrUnknown(data['remote_path']!, _remotePathMeta),
      );
    }
    if (data.containsKey('remote_etag')) {
      context.handle(
        _remoteEtagMeta,
        remoteEtag.isAcceptableOrUnknown(data['remote_etag']!, _remoteEtagMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  FileIndexTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FileIndexTableData(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      ),
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      ),
      mtime: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mtime'],
      ),
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_seen_at'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_synced_at'],
      ),
      remotePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_path'],
      ),
      remoteEtag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_etag'],
      ),
    );
  }

  @override
  $FileIndexTableTable createAlias(String alias) {
    return $FileIndexTableTable(attachedDatabase, alias);
  }
}

class FileIndexTableData extends DataClass
    implements Insertable<FileIndexTableData> {
  final String path;
  final String? sha256;
  final int? size;
  final double? mtime;
  final String? lastSeenAt;
  final String? lastSyncedAt;
  final String? remotePath;
  final String? remoteEtag;
  const FileIndexTableData({
    required this.path,
    this.sha256,
    this.size,
    this.mtime,
    this.lastSeenAt,
    this.lastSyncedAt,
    this.remotePath,
    this.remoteEtag,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    if (!nullToAbsent || sha256 != null) {
      map['sha256'] = Variable<String>(sha256);
    }
    if (!nullToAbsent || size != null) {
      map['size'] = Variable<int>(size);
    }
    if (!nullToAbsent || mtime != null) {
      map['mtime'] = Variable<double>(mtime);
    }
    if (!nullToAbsent || lastSeenAt != null) {
      map['last_seen_at'] = Variable<String>(lastSeenAt);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<String>(lastSyncedAt);
    }
    if (!nullToAbsent || remotePath != null) {
      map['remote_path'] = Variable<String>(remotePath);
    }
    if (!nullToAbsent || remoteEtag != null) {
      map['remote_etag'] = Variable<String>(remoteEtag);
    }
    return map;
  }

  FileIndexTableCompanion toCompanion(bool nullToAbsent) {
    return FileIndexTableCompanion(
      path: Value(path),
      sha256: sha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(sha256),
      size: size == null && nullToAbsent ? const Value.absent() : Value(size),
      mtime: mtime == null && nullToAbsent
          ? const Value.absent()
          : Value(mtime),
      lastSeenAt: lastSeenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenAt),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      remotePath: remotePath == null && nullToAbsent
          ? const Value.absent()
          : Value(remotePath),
      remoteEtag: remoteEtag == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteEtag),
    );
  }

  factory FileIndexTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FileIndexTableData(
      path: serializer.fromJson<String>(json['path']),
      sha256: serializer.fromJson<String?>(json['sha256']),
      size: serializer.fromJson<int?>(json['size']),
      mtime: serializer.fromJson<double?>(json['mtime']),
      lastSeenAt: serializer.fromJson<String?>(json['lastSeenAt']),
      lastSyncedAt: serializer.fromJson<String?>(json['lastSyncedAt']),
      remotePath: serializer.fromJson<String?>(json['remotePath']),
      remoteEtag: serializer.fromJson<String?>(json['remoteEtag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'sha256': serializer.toJson<String?>(sha256),
      'size': serializer.toJson<int?>(size),
      'mtime': serializer.toJson<double?>(mtime),
      'lastSeenAt': serializer.toJson<String?>(lastSeenAt),
      'lastSyncedAt': serializer.toJson<String?>(lastSyncedAt),
      'remotePath': serializer.toJson<String?>(remotePath),
      'remoteEtag': serializer.toJson<String?>(remoteEtag),
    };
  }

  FileIndexTableData copyWith({
    String? path,
    Value<String?> sha256 = const Value.absent(),
    Value<int?> size = const Value.absent(),
    Value<double?> mtime = const Value.absent(),
    Value<String?> lastSeenAt = const Value.absent(),
    Value<String?> lastSyncedAt = const Value.absent(),
    Value<String?> remotePath = const Value.absent(),
    Value<String?> remoteEtag = const Value.absent(),
  }) => FileIndexTableData(
    path: path ?? this.path,
    sha256: sha256.present ? sha256.value : this.sha256,
    size: size.present ? size.value : this.size,
    mtime: mtime.present ? mtime.value : this.mtime,
    lastSeenAt: lastSeenAt.present ? lastSeenAt.value : this.lastSeenAt,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    remotePath: remotePath.present ? remotePath.value : this.remotePath,
    remoteEtag: remoteEtag.present ? remoteEtag.value : this.remoteEtag,
  );
  FileIndexTableData copyWithCompanion(FileIndexTableCompanion data) {
    return FileIndexTableData(
      path: data.path.present ? data.path.value : this.path,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      size: data.size.present ? data.size.value : this.size,
      mtime: data.mtime.present ? data.mtime.value : this.mtime,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      remotePath: data.remotePath.present
          ? data.remotePath.value
          : this.remotePath,
      remoteEtag: data.remoteEtag.present
          ? data.remoteEtag.value
          : this.remoteEtag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FileIndexTableData(')
          ..write('path: $path, ')
          ..write('sha256: $sha256, ')
          ..write('size: $size, ')
          ..write('mtime: $mtime, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('remotePath: $remotePath, ')
          ..write('remoteEtag: $remoteEtag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    path,
    sha256,
    size,
    mtime,
    lastSeenAt,
    lastSyncedAt,
    remotePath,
    remoteEtag,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileIndexTableData &&
          other.path == this.path &&
          other.sha256 == this.sha256 &&
          other.size == this.size &&
          other.mtime == this.mtime &&
          other.lastSeenAt == this.lastSeenAt &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.remotePath == this.remotePath &&
          other.remoteEtag == this.remoteEtag);
}

class FileIndexTableCompanion extends UpdateCompanion<FileIndexTableData> {
  final Value<String> path;
  final Value<String?> sha256;
  final Value<int?> size;
  final Value<double?> mtime;
  final Value<String?> lastSeenAt;
  final Value<String?> lastSyncedAt;
  final Value<String?> remotePath;
  final Value<String?> remoteEtag;
  final Value<int> rowid;
  const FileIndexTableCompanion({
    this.path = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.size = const Value.absent(),
    this.mtime = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.remotePath = const Value.absent(),
    this.remoteEtag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FileIndexTableCompanion.insert({
    required String path,
    this.sha256 = const Value.absent(),
    this.size = const Value.absent(),
    this.mtime = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.remotePath = const Value.absent(),
    this.remoteEtag = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : path = Value(path);
  static Insertable<FileIndexTableData> custom({
    Expression<String>? path,
    Expression<String>? sha256,
    Expression<int>? size,
    Expression<double>? mtime,
    Expression<String>? lastSeenAt,
    Expression<String>? lastSyncedAt,
    Expression<String>? remotePath,
    Expression<String>? remoteEtag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (sha256 != null) 'sha256': sha256,
      if (size != null) 'size': size,
      if (mtime != null) 'mtime': mtime,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (remotePath != null) 'remote_path': remotePath,
      if (remoteEtag != null) 'remote_etag': remoteEtag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FileIndexTableCompanion copyWith({
    Value<String>? path,
    Value<String?>? sha256,
    Value<int?>? size,
    Value<double?>? mtime,
    Value<String?>? lastSeenAt,
    Value<String?>? lastSyncedAt,
    Value<String?>? remotePath,
    Value<String?>? remoteEtag,
    Value<int>? rowid,
  }) {
    return FileIndexTableCompanion(
      path: path ?? this.path,
      sha256: sha256 ?? this.sha256,
      size: size ?? this.size,
      mtime: mtime ?? this.mtime,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      remotePath: remotePath ?? this.remotePath,
      remoteEtag: remoteEtag ?? this.remoteEtag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (mtime.present) {
      map['mtime'] = Variable<double>(mtime.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<String>(lastSeenAt.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<String>(lastSyncedAt.value);
    }
    if (remotePath.present) {
      map['remote_path'] = Variable<String>(remotePath.value);
    }
    if (remoteEtag.present) {
      map['remote_etag'] = Variable<String>(remoteEtag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FileIndexTableCompanion(')
          ..write('path: $path, ')
          ..write('sha256: $sha256, ')
          ..write('size: $size, ')
          ..write('mtime: $mtime, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('remotePath: $remotePath, ')
          ..write('remoteEtag: $remoteEtag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTableTable extends SyncQueueTable
    with TableInfo<$SyncQueueTableTable, SyncQueueTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<String> lastAttemptAt = GeneratedColumn<String>(
    'last_attempt_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    path,
    action,
    status,
    attempts,
    lastAttemptAt,
    error,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_attempt_at'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
    );
  }

  @override
  $SyncQueueTableTable createAlias(String alias) {
    return $SyncQueueTableTable(attachedDatabase, alias);
  }
}

class SyncQueueTableData extends DataClass
    implements Insertable<SyncQueueTableData> {
  final int id;
  final String path;
  final String action;
  final String status;
  final int attempts;
  final String? lastAttemptAt;
  final String? error;
  const SyncQueueTableData({
    required this.id,
    required this.path,
    required this.action,
    required this.status,
    required this.attempts,
    this.lastAttemptAt,
    this.error,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['action'] = Variable<String>(action);
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<String>(lastAttemptAt);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    return map;
  }

  SyncQueueTableCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueTableCompanion(
      id: Value(id),
      path: Value(path),
      action: Value(action),
      status: Value(status),
      attempts: Value(attempts),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
    );
  }

  factory SyncQueueTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueTableData(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      action: serializer.fromJson<String>(json['action']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastAttemptAt: serializer.fromJson<String?>(json['lastAttemptAt']),
      error: serializer.fromJson<String?>(json['error']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'action': serializer.toJson<String>(action),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'lastAttemptAt': serializer.toJson<String?>(lastAttemptAt),
      'error': serializer.toJson<String?>(error),
    };
  }

  SyncQueueTableData copyWith({
    int? id,
    String? path,
    String? action,
    String? status,
    int? attempts,
    Value<String?> lastAttemptAt = const Value.absent(),
    Value<String?> error = const Value.absent(),
  }) => SyncQueueTableData(
    id: id ?? this.id,
    path: path ?? this.path,
    action: action ?? this.action,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    error: error.present ? error.value : this.error,
  );
  SyncQueueTableData copyWithCompanion(SyncQueueTableCompanion data) {
    return SyncQueueTableData(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      action: data.action.present ? data.action.value : this.action,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      error: data.error.present ? data.error.value : this.error,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueTableData(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('action: $action, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, path, action, status, attempts, lastAttemptAt, error);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueTableData &&
          other.id == this.id &&
          other.path == this.path &&
          other.action == this.action &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.error == this.error);
}

class SyncQueueTableCompanion extends UpdateCompanion<SyncQueueTableData> {
  final Value<int> id;
  final Value<String> path;
  final Value<String> action;
  final Value<String> status;
  final Value<int> attempts;
  final Value<String?> lastAttemptAt;
  final Value<String?> error;
  const SyncQueueTableCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.action = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.error = const Value.absent(),
  });
  SyncQueueTableCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    required String action,
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.error = const Value.absent(),
  }) : path = Value(path),
       action = Value(action);
  static Insertable<SyncQueueTableData> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<String>? action,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<String>? lastAttemptAt,
    Expression<String>? error,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (action != null) 'action': action,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (error != null) 'error': error,
    });
  }

  SyncQueueTableCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<String>? action,
    Value<String>? status,
    Value<int>? attempts,
    Value<String?>? lastAttemptAt,
    Value<String?>? error,
  }) {
    return SyncQueueTableCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      action: action ?? this.action,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      error: error ?? this.error,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<String>(lastAttemptAt.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueTableCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('action: $action, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }
}

abstract class _$FileSyncDb extends GeneratedDatabase {
  _$FileSyncDb(QueryExecutor e) : super(e);
  $FileSyncDbManager get managers => $FileSyncDbManager(this);
  late final $FileIndexTableTable fileIndexTable = $FileIndexTableTable(this);
  late final $SyncQueueTableTable syncQueueTable = $SyncQueueTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    fileIndexTable,
    syncQueueTable,
  ];
}

typedef $$FileIndexTableTableCreateCompanionBuilder =
    FileIndexTableCompanion Function({
      required String path,
      Value<String?> sha256,
      Value<int?> size,
      Value<double?> mtime,
      Value<String?> lastSeenAt,
      Value<String?> lastSyncedAt,
      Value<String?> remotePath,
      Value<String?> remoteEtag,
      Value<int> rowid,
    });
typedef $$FileIndexTableTableUpdateCompanionBuilder =
    FileIndexTableCompanion Function({
      Value<String> path,
      Value<String?> sha256,
      Value<int?> size,
      Value<double?> mtime,
      Value<String?> lastSeenAt,
      Value<String?> lastSyncedAt,
      Value<String?> remotePath,
      Value<String?> remoteEtag,
      Value<int> rowid,
    });

class $$FileIndexTableTableFilterComposer
    extends Composer<_$FileSyncDb, $FileIndexTableTable> {
  $$FileIndexTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get mtime => $composableBuilder(
    column: $table.mtime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remotePath => $composableBuilder(
    column: $table.remotePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteEtag => $composableBuilder(
    column: $table.remoteEtag,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FileIndexTableTableOrderingComposer
    extends Composer<_$FileSyncDb, $FileIndexTableTable> {
  $$FileIndexTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get mtime => $composableBuilder(
    column: $table.mtime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remotePath => $composableBuilder(
    column: $table.remotePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteEtag => $composableBuilder(
    column: $table.remoteEtag,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FileIndexTableTableAnnotationComposer
    extends Composer<_$FileSyncDb, $FileIndexTableTable> {
  $$FileIndexTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<double> get mtime =>
      $composableBuilder(column: $table.mtime, builder: (column) => column);

  GeneratedColumn<String> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remotePath => $composableBuilder(
    column: $table.remotePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteEtag => $composableBuilder(
    column: $table.remoteEtag,
    builder: (column) => column,
  );
}

class $$FileIndexTableTableTableManager
    extends
        RootTableManager<
          _$FileSyncDb,
          $FileIndexTableTable,
          FileIndexTableData,
          $$FileIndexTableTableFilterComposer,
          $$FileIndexTableTableOrderingComposer,
          $$FileIndexTableTableAnnotationComposer,
          $$FileIndexTableTableCreateCompanionBuilder,
          $$FileIndexTableTableUpdateCompanionBuilder,
          (
            FileIndexTableData,
            BaseReferences<
              _$FileSyncDb,
              $FileIndexTableTable,
              FileIndexTableData
            >,
          ),
          FileIndexTableData,
          PrefetchHooks Function()
        > {
  $$FileIndexTableTableTableManager(_$FileSyncDb db, $FileIndexTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FileIndexTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FileIndexTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FileIndexTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<int?> size = const Value.absent(),
                Value<double?> mtime = const Value.absent(),
                Value<String?> lastSeenAt = const Value.absent(),
                Value<String?> lastSyncedAt = const Value.absent(),
                Value<String?> remotePath = const Value.absent(),
                Value<String?> remoteEtag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FileIndexTableCompanion(
                path: path,
                sha256: sha256,
                size: size,
                mtime: mtime,
                lastSeenAt: lastSeenAt,
                lastSyncedAt: lastSyncedAt,
                remotePath: remotePath,
                remoteEtag: remoteEtag,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                Value<String?> sha256 = const Value.absent(),
                Value<int?> size = const Value.absent(),
                Value<double?> mtime = const Value.absent(),
                Value<String?> lastSeenAt = const Value.absent(),
                Value<String?> lastSyncedAt = const Value.absent(),
                Value<String?> remotePath = const Value.absent(),
                Value<String?> remoteEtag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FileIndexTableCompanion.insert(
                path: path,
                sha256: sha256,
                size: size,
                mtime: mtime,
                lastSeenAt: lastSeenAt,
                lastSyncedAt: lastSyncedAt,
                remotePath: remotePath,
                remoteEtag: remoteEtag,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FileIndexTableTableProcessedTableManager =
    ProcessedTableManager<
      _$FileSyncDb,
      $FileIndexTableTable,
      FileIndexTableData,
      $$FileIndexTableTableFilterComposer,
      $$FileIndexTableTableOrderingComposer,
      $$FileIndexTableTableAnnotationComposer,
      $$FileIndexTableTableCreateCompanionBuilder,
      $$FileIndexTableTableUpdateCompanionBuilder,
      (
        FileIndexTableData,
        BaseReferences<_$FileSyncDb, $FileIndexTableTable, FileIndexTableData>,
      ),
      FileIndexTableData,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueTableTableCreateCompanionBuilder =
    SyncQueueTableCompanion Function({
      Value<int> id,
      required String path,
      required String action,
      Value<String> status,
      Value<int> attempts,
      Value<String?> lastAttemptAt,
      Value<String?> error,
    });
typedef $$SyncQueueTableTableUpdateCompanionBuilder =
    SyncQueueTableCompanion Function({
      Value<int> id,
      Value<String> path,
      Value<String> action,
      Value<String> status,
      Value<int> attempts,
      Value<String?> lastAttemptAt,
      Value<String?> error,
    });

class $$SyncQueueTableTableFilterComposer
    extends Composer<_$FileSyncDb, $SyncQueueTableTable> {
  $$SyncQueueTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableTableOrderingComposer
    extends Composer<_$FileSyncDb, $SyncQueueTableTable> {
  $$SyncQueueTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableTableAnnotationComposer
    extends Composer<_$FileSyncDb, $SyncQueueTableTable> {
  $$SyncQueueTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);
}

class $$SyncQueueTableTableTableManager
    extends
        RootTableManager<
          _$FileSyncDb,
          $SyncQueueTableTable,
          SyncQueueTableData,
          $$SyncQueueTableTableFilterComposer,
          $$SyncQueueTableTableOrderingComposer,
          $$SyncQueueTableTableAnnotationComposer,
          $$SyncQueueTableTableCreateCompanionBuilder,
          $$SyncQueueTableTableUpdateCompanionBuilder,
          (
            SyncQueueTableData,
            BaseReferences<
              _$FileSyncDb,
              $SyncQueueTableTable,
              SyncQueueTableData
            >,
          ),
          SyncQueueTableData,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableTableManager(_$FileSyncDb db, $SyncQueueTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastAttemptAt = const Value.absent(),
                Value<String?> error = const Value.absent(),
              }) => SyncQueueTableCompanion(
                id: id,
                path: path,
                action: action,
                status: status,
                attempts: attempts,
                lastAttemptAt: lastAttemptAt,
                error: error,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                required String action,
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastAttemptAt = const Value.absent(),
                Value<String?> error = const Value.absent(),
              }) => SyncQueueTableCompanion.insert(
                id: id,
                path: path,
                action: action,
                status: status,
                attempts: attempts,
                lastAttemptAt: lastAttemptAt,
                error: error,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableTableProcessedTableManager =
    ProcessedTableManager<
      _$FileSyncDb,
      $SyncQueueTableTable,
      SyncQueueTableData,
      $$SyncQueueTableTableFilterComposer,
      $$SyncQueueTableTableOrderingComposer,
      $$SyncQueueTableTableAnnotationComposer,
      $$SyncQueueTableTableCreateCompanionBuilder,
      $$SyncQueueTableTableUpdateCompanionBuilder,
      (
        SyncQueueTableData,
        BaseReferences<_$FileSyncDb, $SyncQueueTableTable, SyncQueueTableData>,
      ),
      SyncQueueTableData,
      PrefetchHooks Function()
    >;

class $FileSyncDbManager {
  final _$FileSyncDb _db;
  $FileSyncDbManager(this._db);
  $$FileIndexTableTableTableManager get fileIndexTable =>
      $$FileIndexTableTableTableManager(_db, _db.fileIndexTable);
  $$SyncQueueTableTableTableManager get syncQueueTable =>
      $$SyncQueueTableTableTableManager(_db, _db.syncQueueTable);
}
