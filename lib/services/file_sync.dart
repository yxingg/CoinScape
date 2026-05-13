import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

import 'file_sync_db.dart';

/// Lightweight client-side file sync manager
/// - maintains a local SQLite index at <appDoc>/file_sync.db
/// - scans app documents directory for files (images, local DB, fonts)
/// - uses size+mtime quick-check and SHA256 for verification (computed in isolate)
/// - enqueues upload/delete tasks and processes queue asynchronously
/// - uploads to remote with .part temporary file then MOVE -> atomic replace
/// - fallback: if MOVE not supported, PUT to final path and cleanup tmp
class FileSyncManager {
  static final FileSyncManager instance = FileSyncManager._internal();

  late final String _baseDir;
  FileSyncDb? _db;
  bool _running = false;
  Future<void>? _initFuture;

  FileSyncManager._internal() {
    _initFuture = _init();
  }

  Future<void> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    _baseDir = dir.path;
    _db = await FileSyncDb.getInstance();
  }

  // ------------------------------ helpers ------------------------------
  Future<void> _ensureInit() async {
    if (_initFuture != null) await _initFuture;
  }

  // ------------------------------ helpers (using Drift DB) ------------------------------

  Future<void> _upsertIndexEntry(String relPath, String sha, int size, double mtime, String lastSeenAt,
      {String? lastSyncedAt, String? remotePath, String? remoteEtag}) async {
    await _db!.upsertIndex(
      pathStr: relPath,
      sha256: sha,
      size: size,
      mtime: mtime,
      lastSeenAt: lastSeenAt,
      lastSyncedAt: lastSyncedAt,
      remotePath: remotePath,
      remoteEtag: remoteEtag,
    );
  }

  Future<void> _updateIndexSeen(String relPath, String lastSeenAt) async {
    await _db!.updateIndexSeen(relPath, lastSeenAt);
  }

  // Removed unused _removeIndex helper to avoid lints

  Future<void> _enqueue(String relPath, String action) async {
    // avoid duplicate pending/in-progress
    final all = await _db!.getAllQueue();
    final exists = all.any((e) => e.path == relPath && e.action == action && (e.status == 'pending' || e.status == 'in-progress'));
    if (exists) return;
    await _db!.enqueue(relPath, action);
  }

  // ------------------------------ scan & queue ------------------------------
  Future<Map<String, int>> scanAndQueue() async {
    await _ensureInit();
    final startTs = DateTime.now().toIso8601String();
    final seen = <String>{};

    final root = Directory(_baseDir);
    if (!root.existsSync()) return {'scanned': 0, 'deletions_enqueued': 0};

    await for (final ent in root.list(recursive: true, followLinks: false)) {
      if (ent is! File) continue;
      final rel = p.relative(ent.path, from: _baseDir).replaceAll('\\\\', '/');
      if (rel == 'file_sync.db') continue;
      if (rel.endsWith('coinscape.log') || p.basename(ent.path) == 'coinscape.log') continue;

      FileStat st;
      try {
        st = ent.statSync();
      } catch (e) {
        continue;
      }
      final size = st.size;
      final mtime = st.modified.millisecondsSinceEpoch / 1000.0;

      final entry = await _db!.getIndexByPath(rel);
      if (entry != null && entry.size == size && (entry.mtime ?? 0.0) == mtime) {
        await _updateIndexSeen(rel, startTs);
        seen.add(rel);
        continue;
      }

      // compute sha256 in isolate (reading file synchronously in isolate)
      String sha = '';
      try {
        sha = await compute(_sha256FileSync, ent.path);
      } catch (e) {
        sha = '';
      }

      if (entry == null || sha != (entry.sha256 ?? '')) {
        await _upsertIndexEntry(rel, sha, size, mtime, startTs);
        await _enqueue(rel, 'upload');
      } else {
        await _upsertIndexEntry(rel, sha, size, mtime, startTs,
            lastSyncedAt: entry.lastSyncedAt, remotePath: entry.remotePath, remoteEtag: entry.remoteEtag);
      }

      seen.add(rel);
    }

    // deletions
    final allIndex = await _db!.select(_db!.fileIndexTable).get();
    var deletedCount = 0;
    for (final r in allIndex) {
      final pth = r.path;
      final lastSynced = r.lastSyncedAt;
      if (!seen.contains(pth)) {
        if (lastSynced != null) {
          await _enqueue(pth, 'delete');
          deletedCount += 1;
        }
      }
    }

    return {'scanned': seen.length, 'deletions_enqueued': deletedCount};
  }

  // ------------------------------ remote URL builder ------------------------------
  Uri _buildRemoteUri(String baseUrl, String remoteRoot, String relPath) {
    final parsed = Uri.parse(baseUrl);
    final baseSegments = parsed.pathSegments.where((s) => s.isNotEmpty).toList();
    final rootSegments = remoteRoot.split('/').where((s) => s.isNotEmpty).toList();
    final relSegments = relPath.split('/').where((s) => s.isNotEmpty).toList();
    final all = <String>[];
    all.addAll(baseSegments);
    all.addAll(rootSegments);
    all.addAll(relSegments);
    return Uri(scheme: parsed.scheme, host: parsed.host, port: parsed.hasPort ? parsed.port : null, pathSegments: all);
  }

  Future<void> _ensureRemoteParentDirs(http.Client client, Uri url, Map<String, String> headers) async {
    final segs = url.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.isEmpty) return;
    for (var i = 1; i < segs.length; i++) {
      final prefix = '/' + segs.sublist(0, i).join('/');
      final uri = Uri(scheme: url.scheme, host: url.host, port: url.hasPort ? url.port : null, path: prefix);
      try {
        final req = http.Request('MKCOL', uri);
        req.headers.addAll(headers);
        final streamed = await client.send(req).timeout(const Duration(seconds: 10));
        final sc = streamed.statusCode;
        if (sc == 201 || sc == 405 || sc == 200 || sc == 204) continue;
      } catch (_) {
        // ignore
        continue;
      }
    }
  }

  // ------------------------------ process queue ------------------------------
  Future<Map<String, int>> processQueue(Map<String, dynamic> webdavCfg, {int maxAttempts = 3}) async {
    await _ensureInit();
    final url = webdavCfg['url'] as String? ?? '';
    if (url.isEmpty) throw ArgumentError('WebDAV url not provided');

    final user = webdavCfg['username'] as String? ?? '';
    final password = webdavCfg['password'] as String? ?? '';
    final remoteRoot = webdavCfg['remote_path'] as String? ?? '';

    String? basicAuth;
    if (user.isNotEmpty || password.isNotEmpty) {
      basicAuth = 'Basic ' + base64Encode(utf8.encode('$user:$password'));
    }

    final client = http.Client();
    var processed = 0, succeeded = 0, failed = 0;

    try {
      while (true) {
        final tasks = await _db!.getPendingQueue(limit: 1);
        if (tasks.isEmpty) break;
        final task = tasks.first;
        final taskId = task.id;
        final relPath = task.path;
        final action = task.action;

        // mark in-progress
        await _db!.markQueueInProgress(taskId);

        try {
          if (action == 'upload') {
            final local = p.join(_baseDir, relPath);
            final f = File(local);
            if (!f.existsSync()) {
              await _db!.updateQueueResult(taskId, 'failed', error: 'local_missing');
              failed += 1;
              continue;
            }

            final targetUri = _buildRemoteUri(url, remoteRoot, relPath);
            final parsedTmp = targetUri.replace(path: targetUri.path + '.part');

            final headers = <String, String>{};
            if (basicAuth != null) headers['Authorization'] = basicAuth;

            try {
              await _ensureRemoteParentDirs(client, parsedTmp, headers);
            } catch (_) {}

            // read bytes in isolate
            Uint8List data;
            try {
              data = await compute(_readFileBytesSync, local);
            } catch (e) {
              await _db!.updateQueueResult(taskId, 'failed', error: e.toString());
              failed += 1;
              continue;
            }

            // PUT to tmp
            http.Response putTmpResp;
            try {
              putTmpResp = await client.put(parsedTmp, headers: headers, body: data).timeout(const Duration(seconds: 60));
            } catch (e) {
              await _db!.updateQueueResult(taskId, 'failed', error: 'put_tmp_error:$e');
              failed += 1;
              continue;
            }

            if (putTmpResp.statusCode == 200 || putTmpResp.statusCode == 201 || putTmpResp.statusCode == 204) {
              // try MOVE
              try {
                final moveReq = http.Request('MOVE', parsedTmp);
                moveReq.headers.addAll(headers);
                moveReq.headers['Destination'] = targetUri.toString();
                moveReq.headers['Overwrite'] = 'T';
                final moveStreamed = await client.send(moveReq).timeout(const Duration(seconds: 30));
                final moveStatus = moveStreamed.statusCode;
                if (moveStatus == 200 || moveStatus == 201 || moveStatus == 204) {
                  // HEAD to fetch ETag
                  String? etag;
                  try {
                    final headResp = await client.head(targetUri, headers: headers).timeout(const Duration(seconds: 10));
                    if (headResp.statusCode == 200 || headResp.statusCode == 201) {
                      etag = headResp.headers['etag'] ?? headResp.headers['ETag'];
                    }
                  } catch (_) {}
                  etag ??= putTmpResp.headers['etag'] ?? putTmpResp.headers['ETag'];

                  final existing = await _db!.getIndexByPath(relPath);
                  await _db!.upsertIndex(
                    pathStr: relPath,
                    sha256: existing?.sha256 ?? '',
                    size: existing?.size ?? 0,
                    mtime: existing?.mtime ?? 0.0,
                    lastSeenAt: existing?.lastSeenAt ?? DateTime.now().toIso8601String(),
                    lastSyncedAt: DateTime.now().toIso8601String(),
                    remotePath: targetUri.toString(),
                    remoteEtag: etag,
                  );
                  await _db!.updateQueueResult(taskId, 'done');
                  succeeded += 1;
                } else {
                  // MOVE failed -> fallback to PUT final
                  try {
                    final putFinal = await client.put(targetUri, headers: headers, body: data).timeout(const Duration(seconds: 60));
                    if (putFinal.statusCode == 200 || putFinal.statusCode == 201 || putFinal.statusCode == 204) {
                      try {
                        await client.delete(parsedTmp, headers: headers).timeout(const Duration(seconds: 10));
                      } catch (_) {}
                      final etag = putFinal.headers['etag'] ?? putFinal.headers['ETag'];
                      final existing = await _db!.getIndexByPath(relPath);
                      await _db!.upsertIndex(
                        pathStr: relPath,
                        sha256: existing?.sha256 ?? '',
                        size: existing?.size ?? 0,
                        mtime: existing?.mtime ?? 0.0,
                        lastSeenAt: existing?.lastSeenAt ?? DateTime.now().toIso8601String(),
                        lastSyncedAt: DateTime.now().toIso8601String(),
                        remotePath: targetUri.toString(),
                        remoteEtag: etag,
                      );
                      await _db!.updateQueueResult(taskId, 'done');
                      succeeded += 1;
                    } else {
                      try {
                        await client.delete(parsedTmp, headers: headers).timeout(const Duration(seconds: 10));
                      } catch (_) {}
                      final err = 'move_failed:${moveStatus}, put_target:${putFinal.statusCode}';
                      await _db!.updateQueueResult(taskId, 'failed', error: err);
                      failed += 1;
                    }
                  } catch (e) {
                    try {
                      await client.delete(parsedTmp, headers: headers).timeout(const Duration(seconds: 10));
                    } catch (_) {}
                    await _db!.updateQueueResult(taskId, 'failed', error: 'fallback_put_error:$e');
                    failed += 1;
                  }
                }
              } catch (e) {
                try {
                  await client.delete(parsedTmp, headers: headers).timeout(const Duration(seconds: 10));
                } catch (_) {}
                await _db!.updateQueueResult(taskId, 'failed', error: 'move_error:$e');
                failed += 1;
              }
            } else {
              final err = 'put_tmp_failed:${putTmpResp.statusCode}';
              await _db!.updateQueueResult(taskId, 'failed', error: err);
              failed += 1;
            }
          } else if (action == 'delete') {
            final targetUri = _buildRemoteUri(url, remoteRoot, relPath);
            try {
              final resp = await client.delete(targetUri, headers: basicAuth != null ? {'Authorization': basicAuth} : {}).timeout(const Duration(seconds: 30));
              if (resp.statusCode == 200 || resp.statusCode == 204 || resp.statusCode == 404) {
                await _db!.deleteIndex(relPath);
                await _db!.updateQueueResult(taskId, 'done');
                succeeded += 1;
              } else {
                final err = 'delete_failed:${resp.statusCode}';
                await _db!.updateQueueResult(taskId, 'failed', error: err);
                failed += 1;
              }
            } catch (e) {
              await _db!.updateQueueResult(taskId, 'failed', error: e.toString());
              failed += 1;
            }
          }
        } catch (e) {
          await _db!.updateQueueResult(taskId, 'failed', error: e.toString());
          failed += 1;
        }

        processed += 1;
      }
    } finally {
      client.close();
    }

    return {'processed': processed, 'succeeded': succeeded, 'failed': failed};
  }

  Future<Map<String, int>> getStatus() async {
    await _ensureInit();
    return _db!.getStatusCounts();
  }

  Future<Map<String, dynamic>> getDetailedStatus({int limit = 100}) async {
    await _ensureInit();
    final counts = await _db!.getStatusCounts();
    final all = await _db!.getAllQueue();
    final inprog = all.where((e) => e.status == 'in-progress').map((e) => {
          'id': e.id,
          'path': e.path,
          'action': e.action,
          'attempts': e.attempts,
          'error': e.error,
        }).toList();
    final failed = all.where((e) => e.status == 'failed').map((e) => {
          'id': e.id,
          'path': e.path,
          'action': e.action,
          'attempts': e.attempts,
          'error': e.error,
        }).toList();
    final pending = all.where((e) => e.status == 'pending').take(limit).map((e) => {
          'id': e.id,
          'path': e.path,
          'action': e.action,
        }).toList();
    return {'counts': counts, 'in_progress': inprog, 'failed': failed, 'pending_preview': pending};
  }

  Future<Map<String, dynamic>> pushAll(Map<String, dynamic> webdavCfg) async {
    if (_running) return {'started': false, 'reason': 'already_running'};
    _running = true;
    try {
      await _ensureInit();
      final scan = await scanAndQueue();
      final proc = await processQueue(webdavCfg);
      return {'started': true, 'scan': scan, 'process': proc};
    } finally {
      _running = false;
    }
  }
}

// ------------------------------ isolate helpers ------------------------------

String _sha256FileSync(String path) {
  try {
    final b = File(path).readAsBytesSync();
    final d = sha256.convert(b);
    return d.toString();
  } catch (e) {
    return '';
  }
}

Uint8List _readFileBytesSync(String path) {
  return File(path).readAsBytesSync();
}
