import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:xml/xml.dart' as xml;
import 'package:flutter/foundation.dart' show compute;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../utils/logger.dart';
import 'package:crypto/crypto.dart';

import 'file_sync_db.dart';

/// Lightweight client-side file sync manager
/// - maintains a local SQLite index at [appDoc]/file_sync.db
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

  // Removed unused _updateIndexSeen and _removeIndex helpers to avoid lints

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

    var fileCount = 0, enqueuedCount = 0;
    await for (final ent in root.list(recursive: true, followLinks: false)) {
      if (ent is! File) continue;
      final rel = p.relative(ent.path, from: _baseDir).replaceAll('\\', '/');
      final basename = p.basename(ent.path);
      
      // Skip internal sync DB and journals
      if (rel == 'file_sync.db' || rel.endsWith('/file_sync.db')) continue;
      if (basename == 'file_sync.db-wal' || basename == 'file_sync.db-shm') continue;
      
      // Skip log files and rotated backups
      if (basename == 'coinscape.log' || basename.startsWith('coinscape.log.')) continue;
      
      // Skip config files
      if (rel == 'app_config.json' || rel.endsWith('/app_config.json')) continue;
      if (rel == 'app_settings.json' || rel.endsWith('/app_settings.json')) continue;
      
      // Skip staging/temp directories
      if (rel.startsWith('.imported_dbs/') || rel.contains('/.imported_dbs/')) continue;
      if (rel.startsWith('.thumb_cache/') || rel.contains('/.thumb_cache/')) continue;
      if (rel.startsWith('uploads/') || rel.contains('/uploads/')) continue;
      
      // Skip temp files and SQLite journals
      if (basename.endsWith('.tmp') || basename.endsWith('.tmp.tmp')) continue;
      if (basename.endsWith('-wal') || basename.endsWith('-shm')) continue;
      
      // Skip .ccm backup archives (transient staging)
      if (basename.endsWith('.ccm')) continue;

      fileCount++;

      FileStat st;
      try {
        st = ent.statSync();
      } catch (e) {
        continue;
      }
      final size = st.size;
      final mtime = st.modified.millisecondsSinceEpoch / 1000.0;

      // Always compute SHA256 and enqueue; remote-side dedup happens in processQueue
      String sha = '';
      try {
        sha = await compute(_sha256FileSync, ent.path);
      } catch (e) {
        sha = '';
      }

      await _upsertIndexEntry(rel, sha, size, mtime, startTs);
      await _enqueue(rel, 'upload');
      enqueuedCount++;

      seen.add(rel);
    }

    AppLogger.info(logPrefixSync, 'scanAndQueue done: scanned=$fileCount, enqueued=$enqueuedCount');

    // deletions: indexed paths not seen locally
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

    return {'scanned': fileCount, 'enqueued': enqueuedCount, 'deletions_enqueued': deletedCount};
  }

  // ------------------------------ remote URL builder ------------------------------
  Uri _buildRemoteUri(String baseUrl, String remoteRoot, String relPath) {
    final parsed = Uri.parse(baseUrl);
    // Ensure base path ends with a slash so resolve treats it as a directory
    var base = parsed;
    if (!base.path.endsWith('/')) {
      base = base.replace(path: '${base.path}/');
    }

    // Use posix join to avoid backslashes on Windows and normalize segments
    final reference = p.posix.join(remoteRoot, relPath);
    if (reference.isEmpty) return base;

    try {
      final resolved = base.resolve(reference);
      return resolved;
    } catch (_) {
      // Fallback to manual construction similar to previous implementation
      final baseSegments = parsed.pathSegments.where((s) => s.isNotEmpty).toList();
      final rootSegments = remoteRoot.split('/').where((s) => s.isNotEmpty).toList();
      final relSegments = relPath.split('/').where((s) => s.isNotEmpty).toList();
      final all = <String>[];
      all.addAll(baseSegments);
      all.addAll(rootSegments);
      all.addAll(relSegments);
      return Uri(scheme: parsed.scheme, host: parsed.host, port: parsed.hasPort ? parsed.port : null, pathSegments: all);
    }
  }

  Future<void> _ensureRemoteParentDirs(http.Client client, Uri url, Map<String, String> headers) async {
    final segs = url.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.isEmpty) return;
    for (var i = 1; i < segs.length; i++) {
      final prefix = '/${segs.sublist(0, i).join('/')}';
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
  Future<Map<String, int>> processQueue(Map<String, dynamic> webdavCfg, {int maxAttempts = 3, int concurrencyLimit = 6}) async {
    await _ensureInit();
    final url = webdavCfg['url'] as String? ?? '';
    if (url.isEmpty) throw ArgumentError('WebDAV url not provided');

    final user = webdavCfg['username'] as String? ?? '';
    final password = webdavCfg['password'] as String? ?? '';
    final remoteRoot = webdavCfg['remote_path'] as String? ?? '';

    String? basicAuth;
    if (user.isNotEmpty || password.isNotEmpty) {
      basicAuth = 'Basic ${base64Encode(utf8.encode('$user:$password'))}';
    }

    AppLogger.info(logPrefixSync, 'processQueue: url=$url user=$user remoteRoot=$remoteRoot');
    final client = http.Client();
    var processed = 0, succeeded = 0, failed = 0;

    try {
      while (true) {
        // fetch a chunk of pending tasks up to concurrencyLimit
        final tasks = await _db!.getPendingQueue(limit: concurrencyLimit);
        if (tasks.isEmpty) break;

        // mark all tasks in this chunk as in-progress to avoid duplication
        for (final t in tasks) {
          await _db!.markQueueInProgress(t.id);
        }

        // process chunk concurrently but limited to concurrencyLimit
        final futures = tasks.map((task) async {
          final taskId = task.id;
          final relPath = task.path;
          final action = task.action;

          try {
            if (action == 'upload') {
              final local = p.join(_baseDir, relPath);
              final f = File(local);
              if (!f.existsSync()) {
                AppLogger.warning(logPrefixSync, 'processQueue: local file missing: $local');
                await _db!.updateQueueResult(taskId, 'failed', error: 'local_missing');
                failed += 1;
                return;
              }

              final targetUri = _buildRemoteUri(url, remoteRoot, relPath);
              final parsedTmp = targetUri.replace(path: '${targetUri.path}.part');

              final headers = <String, String>{};
              if (basicAuth != null) headers['Authorization'] = basicAuth;
              // HEAD check: skip upload if remote file exists with same size
              final localSize = f.lengthSync();
              try {
                final headResp = await client.head(targetUri, headers: headers).timeout(const Duration(seconds: 10));
                if (headResp.statusCode == 200) {
                  final remoteSize = int.tryParse(headResp.headers['content-length'] ?? '');
                  if (remoteSize == localSize) {
                    AppLogger.info(logPrefixSync, 'processQueue: skip (remote exists, same size): $relPath');
                    await _db!.upsertIndex(
                      pathStr: relPath,
                      sha256: '',
                      size: localSize,
                      mtime: 0.0,
                      lastSeenAt: DateTime.now().toIso8601String(),
                      lastSyncedAt: DateTime.now().toIso8601String(),
                      remotePath: targetUri.toString(),
                      remoteEtag: headResp.headers['etag'] ?? headResp.headers['ETag'],
                    );
                    await _db!.updateQueueResult(taskId, 'done');
                    succeeded += 1;
                    return;
                  }
                }
              } catch (_) {
                // HEAD failed (file doesn't exist or network error) — proceed with upload
              }
              try {
                await _ensureRemoteParentDirs(client, parsedTmp, headers);
              } catch (_) {}

              AppLogger.info(logPrefixSync, 'processQueue: uploading $relPath -> ${targetUri}');
              // read bytes in isolate
              Uint8List data;
              try {
                data = await compute(_readFileBytesSync, local);
              } catch (e) {
                await _db!.updateQueueResult(taskId, 'failed', error: e.toString());
                failed += 1;
                return;
              }

              // PUT to tmp
              http.Response putTmpResp;
              try {
                putTmpResp = await client.put(parsedTmp, headers: headers, body: data).timeout(const Duration(seconds: 60));
              } catch (e) {
                await _db!.updateQueueResult(taskId, 'failed', error: 'put_tmp_error:$e');
                failed += 1;
                return;
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
                    return;
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
                        return;
                      } else {
                        try {
                          await client.delete(parsedTmp, headers: headers).timeout(const Duration(seconds: 10));
                        } catch (_) {}
                        final err = 'move_failed:$moveStatus, put_target:${putFinal.statusCode}';
                        await _db!.updateQueueResult(taskId, 'failed', error: err);
                        failed += 1;
                        return;
                      }
                    } catch (e) {
                      try {
                        await client.delete(parsedTmp, headers: headers).timeout(const Duration(seconds: 10));
                      } catch (_) {}
                      await _db!.updateQueueResult(taskId, 'failed', error: 'fallback_put_error:$e');
                      failed += 1;
                      return;
                    }
                  }
                } catch (e) {
                  try {
                    await client.delete(parsedTmp, headers: headers).timeout(const Duration(seconds: 10));
                  } catch (_) {}
                  await _db!.updateQueueResult(taskId, 'failed', error: 'move_error:$e');
                  failed += 1;
                  return;
                }
              } else {
                final err = 'put_tmp_failed:${putTmpResp.statusCode}';
                await _db!.updateQueueResult(taskId, 'failed', error: err);
                failed += 1;
                return;
              }
            } else if (action == 'delete') {
              final targetUri = _buildRemoteUri(url, remoteRoot, relPath);
              try {
                final resp = await client.delete(targetUri, headers: basicAuth != null ? {'Authorization': basicAuth} : {}).timeout(const Duration(seconds: 30));
                if (resp.statusCode == 200 || resp.statusCode == 204 || resp.statusCode == 404) {
                  await _db!.deleteIndex(relPath);
                  await _db!.updateQueueResult(taskId, 'done');
                  succeeded += 1;
                  return;
                } else {
                  final err = 'delete_failed:${resp.statusCode}';
                  await _db!.updateQueueResult(taskId, 'failed', error: err);
                  failed += 1;
                  return;
                }
              } catch (e) {
                await _db!.updateQueueResult(taskId, 'failed', error: e.toString());
                failed += 1;
                return;
              }
            }
          } catch (e) {
            await _db!.updateQueueResult(taskId, 'failed', error: e.toString());
            failed += 1;
            return;
          } finally {
            processed += 1;
          }
        }).toList();

        // wait for this chunk to finish
        try {
          await Future.wait(futures);
        } catch (_) {
          // individual task errors are handled per-task; ignore
        }
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

  Future<Map<String, dynamic>> getDetailedStatus({int limit = 100, Map<String, dynamic>? webdavCfg}) async {
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
    // remote enumeration if webdav configuration provided
    final remotePreview = <Map<String, dynamic>>[];
    if (webdavCfg != null && webdavCfg['url'] != null && (webdavCfg['url'] as String).isNotEmpty) {
      final url = webdavCfg['url'] as String;
      final user = webdavCfg['username'] as String? ?? '';
      final password = webdavCfg['password'] as String? ?? '';
      final remoteRoot = webdavCfg['remote_path'] as String? ?? '';

      String? basicAuth;
      if (user.isNotEmpty || password.isNotEmpty) {
        basicAuth = 'Basic ${base64Encode(utf8.encode('$user:$password'))}';
      }

      final client = http.Client();
      try {
        Uri startUri = _buildRemoteUri(url, remoteRoot, '');
        var startUrlStr = startUri.toString();
        if (!startUrlStr.endsWith('/')) startUrlStr = '$startUrlStr/';

        final propfindBody = '<?xml version="1.0" encoding="utf-8"?>\n<d:propfind xmlns:d="DAV:">\n  <d:prop>\n    <d:getcontentlength/>\n    <d:getlastmodified/>\n    <d:resourcetype/>\n    <d:getetag/>\n  </d:prop>\n</d:propfind>';

        final toVisit = <String>[startUrlStr];
        final seen = <String>{};
        final remoteFiles = <Map<String, dynamic>>[];

        while (toVisit.isNotEmpty) {
          final urlStr = toVisit.removeAt(0);
          if (seen.contains(urlStr)) continue;
          seen.add(urlStr);

          final uri = Uri.parse(urlStr);
          final req = http.Request('PROPFIND', uri);
          req.headers['Depth'] = '1';
          req.headers['Content-Type'] = 'text/xml';
          if (basicAuth != null) req.headers['Authorization'] = basicAuth;
          req.body = propfindBody;

          http.StreamedResponse streamed;
          try {
            streamed = await client.send(req).timeout(const Duration(seconds: 12));
          } catch (e) {
            continue;
          }
          final resp = await http.Response.fromStream(streamed);
          AppLogger.info(logPrefixSync, 'PROPFIND ${urlStr}: status=${resp.statusCode}, bodyLen=${resp.body.length}');
          if (resp.statusCode < 200 || resp.statusCode >= 400) continue;

          xml.XmlDocument doc;
          try {
            doc = xml.XmlDocument.parse(resp.body);
          } catch (e) {
          AppLogger.warning(logPrefixSync, 'PROPFIND XML parse failed: $e');
            continue;
          }

          // Parse PROPFIND XML - try namespace-aware first, fall back to local-name
          final ns = 'DAV:';
          var responseEls = doc.findAllElements('response', namespace: ns).toList();
          if (responseEls.isEmpty) {
            responseEls = doc.findAllElements('response').toList();
          }
          AppLogger.info(logPrefixSync, 'PROPFIND XML: found ${responseEls.length} response elements');
          if (responseEls.isEmpty) {
            final snippet = resp.body.length > 500 ? resp.body.substring(0, 500) : resp.body;
            AppLogger.warning(logPrefixSync, 'PROPFIND no responses parsed, body: $snippet');
          }

          for (final responseEl in responseEls) {
            var hrefEl = responseEl.getElement('href', namespace: ns);
            hrefEl ??= responseEl.getElement('href');
            if (hrefEl == null) continue;
            final href = hrefEl.innerText;
            final parsedHref = Uri.parse(href);
            final hrefUrl = '${parsedHref.scheme.isEmpty ? uri.scheme : parsedHref.scheme}://${parsedHref.hasAuthority ? parsedHref.authority : uri.authority}${parsedHref.path}';

            bool isDir = false;
            int? size;
            String? lastModified;
            String? etag;

            var propstatEls = responseEl.findAllElements('propstat', namespace: ns).toList();
              if (propstatEls.isEmpty) propstatEls = responseEl.findAllElements('propstat').toList();
              for (final propstat in propstatEls) {
              var statusEl = propstat.getElement('status', namespace: ns);
                statusEl ??= propstat.getElement('status');
              if (statusEl != null && !(statusEl.innerText).contains('200')) continue;
              var prop = propstat.getElement('prop', namespace: ns);
                prop ??= propstat.getElement('prop');
              if (prop != null) {
                var rt = prop.getElement('resourcetype', namespace: ns);
                rt ??= prop.getElement('resourcetype');
                if (rt != null && (rt.findElements('collection', namespace: ns).isNotEmpty || rt.findElements('collection').isNotEmpty)) isDir = true;
                var gl = prop.getElement('getcontentlength', namespace: ns);
                gl ??= prop.getElement('getcontentlength');
                if (gl != null && (gl.innerText).isNotEmpty) {
                  try { size = int.parse(gl.innerText); } catch (_) { size = null; }
                }
                var gm = prop.getElement('getlastmodified', namespace: ns);
                gm ??= prop.getElement('getlastmodified');
                if (gm != null) lastModified = gm.innerText;
                var ge = prop.getElement('getetag', namespace: ns);
                ge ??= prop.getElement('getetag');
                if (ge != null) etag = ge.innerText;
              }
              break;
            }

            if (isDir) {
              var addUrl = hrefUrl;
              if (!addUrl.endsWith('/')) addUrl = '$addUrl/';
              if (!seen.contains(addUrl)) toVisit.add(addUrl);
            } else {
              // compute relative path
              final parsedBase = Uri.parse(startUrlStr);
              final baseSegments = parsedBase.path.split('/').where((s) => s.isNotEmpty).toList();
              final hrefSegments = parsedHref.path.split('/').where((s) => s.isNotEmpty).toList();
              if (hrefSegments.length <= baseSegments.length) continue;
              final relSegments = hrefSegments.sublist(baseSegments.length);
              final rel = relSegments.map((s) => Uri.decodeComponent(s)).join('/');

              if (rel.startsWith('.coinscape')) continue;
              if (rel.endsWith('coinscape.log') || rel.split('/').last == 'coinscape.log') continue;

              remoteFiles.add({'path': rel, 'href': hrefUrl, 'size': size, 'last_modified': lastModified, 'etag': etag});
            }
          }
        }

        AppLogger.info(logPrefixSync, 'PROPFIND found ${remoteFiles.length} remote files');
        for (final rf in remoteFiles) { AppLogger.info(logPrefixSync, '  remote: ${rf["path"]}'); }
        // compare with local index
        final newRemote = <Map<String, dynamic>>[];
        final modifiedRemote = <Map<String, dynamic>>[];
        final syncedRemote = <Map<String, dynamic>>[];
        for (final rf in remoteFiles) {
          final rel = rf['path'] as String;
          final local = await _db!.getIndexByPath(rel);
          final rsize = rf['size'] as int?;
          final retag = rf['etag'] as String?;
          if (local == null) {
            newRemote.add({'path': rel, 'status': 'new_remote', 'remote': {'size': rsize, 'last_modified': rf['last_modified'], 'etag': retag}});
          } else {
            final lsize = local.size;
            final letag = local.remoteEtag;
            if ((lsize == null && rsize != null) || (lsize != null && rsize != null && lsize != rsize) || (retag != null && letag != null && retag != letag)) {
              modifiedRemote.add({'path': rel, 'status': 'modified_remote', 'remote': {'size': rsize, 'last_modified': rf['last_modified'], 'etag': retag}});
            } else {
              syncedRemote.add({'path': rel, 'status': 'synced', 'remote': {'size': rsize, 'last_modified': rf['last_modified'], 'etag': retag}, 'local': {'size': lsize, 'last_synced_at': local.lastSyncedAt}});
            }
          }
        }

        remotePreview.addAll(newRemote.take(limit));
        remotePreview.addAll(modifiedRemote.take(limit));
        remotePreview.addAll(syncedRemote.take(limit));
        counts['new_remote'] = newRemote.length;
        counts['modified_remote'] = modifiedRemote.length;
        counts['synced'] = syncedRemote.length;
      } finally {
        client.close();
      }
    } else {
      counts['new_remote'] = 0;
      counts['modified_remote'] = 0;
    }

    return {'counts': counts, 'in_progress': inprog, 'failed': failed, 'pending_preview': pending, 'remote_preview': remotePreview};
  }

  Future<Map<String, dynamic>> pushAll(Map<String, dynamic> webdavCfg) async {
    if (_running) return {'started': false, 'reason': 'already_running'};
    _running = true;
    try {
      await _ensureInit();
      // reset historic queue entries so counts are per-run (do not accumulate)
      try {
        await _db!.clearHistoricQueue();
      } catch (_) {}
      AppLogger.info(logPrefixSync, 'Starting client-side pushAll');
      final scan = await scanAndQueue();
      AppLogger.info(logPrefixSync, 'scanAndQueue result: ${scan.toString()}');
      final proc = await processQueue(webdavCfg);
      AppLogger.info(logPrefixSync, 'processQueue result: ${proc.toString()}');

      // attempt to write remote backup marker so other devices can see latest backup
      bool remoteMarkerSet = false;
      String? lastCloudBackup;
      try {
        final prefs = await SharedPreferences.getInstance();
        // Use a single UTC timestamp for both local and remote to avoid drift
        final nowUtc = DateTime.now().toUtc().toIso8601String();
        final localTs = prefs.getString('sync.last_local_change');
        final isoToWrite = localTs ?? nowUtc;
        // Ensure prefs has a timestamp (first run or missing)
        if (localTs == null) {
          await prefs.setString('sync.last_local_change', nowUtc);
        }
        remoteMarkerSet = await _writeRemoteBackupMarker(webdavCfg, isoToWrite);
        if (remoteMarkerSet) lastCloudBackup = isoToWrite;
      } catch (e, st) {
        AppLogger.error(logPrefixSync, 'Failed to set remote backup marker: $e', st);
      }

      return {
        'started': true,
        'scan': scan,
        'process': proc,
        'remote_marker_set': remoteMarkerSet,
        'last_cloud_backup': lastCloudBackup,
      };
    } finally {
      _running = false;
    }
  }

  Future<Map<String, dynamic>> pullAll(Map<String, dynamic> webdavCfg) async {
    await _ensureInit();

    // reset historic queue entries to avoid cumulative counts from previous runs
    try {
      await _db!.clearHistoricQueue();
    } catch (_) {}

    final url = webdavCfg['url'] as String? ?? '';
    if (url.isEmpty) throw ArgumentError('WebDAV url not provided');

    final user = webdavCfg['username'] as String? ?? '';
    final password = webdavCfg['password'] as String? ?? '';
    final remoteRoot = webdavCfg['remote_path'] as String? ?? '';

    String? basicAuth;
    if (user.isNotEmpty || password.isNotEmpty) {
      basicAuth = 'Basic ${base64Encode(utf8.encode('$user:$password'))}';
    }

    final client = http.Client();
    var downloaded = 0, failed = 0;
    String? importedDbPath;

    try {
      // build start url
      Uri startUri = _buildRemoteUri(url, remoteRoot, '');
      var startUrlStr = startUri.toString();
      if (!startUrlStr.endsWith('/')) startUrlStr = '$startUrlStr/';

      // perform breadth-first PROPFIND (Depth:1) recursion to enumerate files
      final propfindBody = '<?xml version="1.0" encoding="utf-8"?>\n<d:propfind xmlns:d="DAV:">\n  <d:prop>\n    <d:getcontentlength/>\n    <d:getlastmodified/>\n    <d:resourcetype/>\n    <d:getetag/>\n  </d:prop>\n</d:propfind>';

      final toVisit = <String>[startUrlStr];
      final seen = <String>{};
      final files = <Map<String, dynamic>>[];

      while (toVisit.isNotEmpty) {
        final urlStr = toVisit.removeAt(0);
        if (seen.contains(urlStr)) continue;
        seen.add(urlStr);

        final uri = Uri.parse(urlStr);
        final req = http.Request('PROPFIND', uri);
        req.headers['Depth'] = '1';
        req.headers['Content-Type'] = 'text/xml';
        if (basicAuth != null) req.headers['Authorization'] = basicAuth;
        req.body = propfindBody;

        http.StreamedResponse streamed;
        try {
          streamed = await client.send(req).timeout(const Duration(seconds: 20));
        } catch (e) {
          continue;
        }
        final resp = await http.Response.fromStream(streamed);
        if (resp.statusCode < 200 || resp.statusCode >= 400) continue;

        xml.XmlDocument doc;
        try {
          doc = xml.XmlDocument.parse(resp.body);
        } catch (e) {
          continue;
        }

        final ns = 'DAV:';
        var responseEls = doc.findAllElements('response', namespace: ns).toList();
        if (responseEls.isEmpty) responseEls = doc.findAllElements('response').toList();
        for (final responseEl in responseEls) {
          var hrefEl = responseEl.getElement('href', namespace: ns);
          hrefEl ??= responseEl.getElement('href');
          if (hrefEl == null) continue;
          final href = hrefEl.innerText;
          final parsedHref = Uri.parse(href);
          final hrefUrl = '${parsedHref.scheme.isEmpty ? uri.scheme : parsedHref.scheme}://${parsedHref.hasAuthority ? parsedHref.authority : uri.authority}${parsedHref.path}';

          bool isDir = false;
          int? size;
          String? lastModified;
          String? etag;

          var propstatEls = responseEl.findAllElements('propstat', namespace: ns).toList();
              if (propstatEls.isEmpty) propstatEls = responseEl.findAllElements('propstat').toList();
              for (final propstat in propstatEls) {
            var statusEl = propstat.getElement('status', namespace: ns);
                statusEl ??= propstat.getElement('status');
            if (statusEl != null && !(statusEl.innerText).contains('200')) continue;
            var prop = propstat.getElement('prop', namespace: ns);
                prop ??= propstat.getElement('prop');
            if (prop != null) {
              var rt = prop.getElement('resourcetype', namespace: ns);
                rt ??= prop.getElement('resourcetype');
              if (rt != null && (rt.findElements('collection', namespace: ns).isNotEmpty || rt.findElements('collection').isNotEmpty)) isDir = true;
              var gl = prop.getElement('getcontentlength', namespace: ns);
                gl ??= prop.getElement('getcontentlength');
              if (gl != null && (gl.innerText).isNotEmpty) {
                try { size = int.parse(gl.innerText); } catch (_) { size = null; }
              }
              var gm = prop.getElement('getlastmodified', namespace: ns);
                gm ??= prop.getElement('getlastmodified');
              if (gm != null) lastModified = gm.innerText;
              var ge = prop.getElement('getetag', namespace: ns);
                ge ??= prop.getElement('getetag');
              if (ge != null) etag = ge.innerText;
            }
            break;
          }

          if (isDir) {
            var addUrl = hrefUrl;
            if (!addUrl.endsWith('/')) addUrl = '$addUrl/';
            if (!seen.contains(addUrl)) toVisit.add(addUrl);
          } else {
            files.add({'href': hrefUrl, 'size': size, 'last_modified': lastModified, 'etag': etag});
          }
        }
      }

      // Now download files
      for (final f in files) {
        final href = f['href'] as String?;
        if (href == null) continue;
        // compute relative path
        final parsedBase = Uri.parse(startUrlStr);
        final parsedHref = Uri.parse(href);
        final baseSegments = parsedBase.path.split('/').where((s) => s.isNotEmpty).toList();
        final hrefSegments = parsedHref.path.split('/').where((s) => s.isNotEmpty).toList();
        if (hrefSegments.length <= baseSegments.length) continue;
        final relSegments = hrefSegments.sublist(baseSegments.length);
        final rel = relSegments.map((s) => Uri.decodeComponent(s)).join('/');

        // skip metadata
        if (rel.startsWith('.coinscape')) continue;
        if (rel.endsWith('coinscape.log') || rel.split('/').last == 'coinscape.log') continue;

        final relPathNormalized = rel.replaceAll('/', p.separator);
        final targetLocal = p.join(_baseDir, relPathNormalized);
        // If downloading coinscape.db, store it in an isolated import directory
        // to avoid overwriting the live DB that the app may have open.
        String actualTargetLocal = targetLocal;
        final basename = p.basename(targetLocal);
        if (basename == 'coinscape.db') {
          final importDir = p.join(_baseDir, '.imported_dbs');
          final importDirObj = Directory(importDir);
          if (!await importDirObj.exists()) await importDirObj.create(recursive: true);
          actualTargetLocal = p.join(importDir, 'coinscape_imported_${Uuid().v4()}.db');
        }
        final parentDir = Directory(p.dirname(actualTargetLocal));
        if (!await parentDir.exists()) await parentDir.create(recursive: true);

        try {
          final getReq = http.Request('GET', Uri.parse(href));
          if (basicAuth != null) getReq.headers['Authorization'] = basicAuth;
          final streamedGet = await client.send(getReq).timeout(const Duration(seconds: 120));
          final getResp = await http.Response.fromStream(streamedGet);
          if (getResp.statusCode == 200 || getResp.statusCode == 201) {
            final tmpFile = File('$actualTargetLocal.tmp');
            await tmpFile.writeAsBytes(getResp.bodyBytes);
            await tmpFile.rename(actualTargetLocal);
            // detect if downloaded sqlite DB (coinscape.db under db/) and
            // point importedDbPath to the isolated imported copy
            if (basename == 'coinscape.db') {
              importedDbPath = actualTargetLocal;
            }
            downloaded += 1;
            // update index
            final existing = await _db!.getIndexByPath(rel);
            await _db!.upsertIndex(pathStr: rel, sha256: existing?.sha256 ?? '', size: existing?.size ?? 0, mtime: existing?.mtime ?? 0.0, lastSeenAt: existing?.lastSeenAt ?? DateTime.now().toIso8601String(), lastSyncedAt: DateTime.now().toIso8601String(), remotePath: href, remoteEtag: getResp.headers['etag'] ?? getResp.headers['ETag']);
          } else {
            failed += 1;
            // Clean up orphaned .tmp file
            try { await File('$actualTargetLocal.tmp').delete(); } catch (_) {}
          }
        } catch (e) {
          failed += 1;
          // Clean up orphaned .tmp file
          try { await File('$actualTargetLocal.tmp').delete(); } catch (_) {}
        }
      }

      return {'downloaded': downloaded, 'failed': failed, 'imported_db_path': importedDbPath};
    } finally {
      client.close();
    }
  }

    /// Pull a single file from the remote WebDAV into local storage.
    /// Returns a map similar to the pullAll result but scoped to one file.
    Future<Map<String, dynamic>> pullOne(String relPath, Map<String, dynamic> webdavCfg) async {
      await _ensureInit();
      final url = webdavCfg['url'] as String? ?? '';
      if (url.isEmpty) throw ArgumentError('WebDAV url not provided');

      final user = webdavCfg['username'] as String? ?? '';
      final password = webdavCfg['password'] as String? ?? '';
      final remoteRoot = webdavCfg['remote_path'] as String? ?? '';

      String? basicAuth;
      if (user.isNotEmpty || password.isNotEmpty) {
        basicAuth = 'Basic ${base64Encode(utf8.encode('$user:$password'))}';
      }

      final client = http.Client();
      try {
        // build target URI for this file
        final target = _buildRemoteUri(url, remoteRoot, relPath);

        final getReq = http.Request('GET', target);
        if (basicAuth != null) getReq.headers['Authorization'] = basicAuth;
        final streamedGet = await client.send(getReq).timeout(const Duration(seconds: 120));
        final getResp = await http.Response.fromStream(streamedGet);

        if (getResp.statusCode == 200 || getResp.statusCode == 201) {
          final relPathNormalized = relPath.replaceAll('/', p.separator);
          final targetLocal = p.join(_baseDir, relPathNormalized);
          String actualTargetLocal = targetLocal;
          final basename = p.basename(targetLocal);
          String? importedDbPath;
          if (basename == 'coinscape.db') {
            final importDir = p.join(_baseDir, '.imported_dbs');
            final importDirObj = Directory(importDir);
            if (!await importDirObj.exists()) await importDirObj.create(recursive: true);
            actualTargetLocal = p.join(importDir, 'coinscape_imported_${Uuid().v4()}.db');
            importedDbPath = actualTargetLocal;
          }

          final parentDir = Directory(p.dirname(actualTargetLocal));
          if (!await parentDir.exists()) await parentDir.create(recursive: true);

          final tmpFile = File('$actualTargetLocal.tmp');
          await tmpFile.writeAsBytes(getResp.bodyBytes);
          await tmpFile.rename(actualTargetLocal);

          // update index entry
          final existing = await _db!.getIndexByPath(relPath);
          await _db!.upsertIndex(pathStr: relPath, sha256: existing?.sha256 ?? '', size: existing?.size ?? 0, mtime: existing?.mtime ?? 0.0, lastSeenAt: existing?.lastSeenAt ?? DateTime.now().toIso8601String(), lastSyncedAt: DateTime.now().toIso8601String(), remotePath: target.toString(), remoteEtag: getResp.headers['etag'] ?? getResp.headers['ETag']);

          return {'result': {'success': true}, 'downloaded': 1, 'imported_db_path': importedDbPath};
        }

        return {'result': {'success': false, 'error': 'http:${getResp.statusCode}'}};
      } catch (e) {
        return {'result': {'success': false, 'error': e.toString()}};
      } finally {
        client.close();
      }
    }

  Future<bool> _writeRemoteBackupMarker(Map<String, dynamic> webdavCfg, String? isoTs) async {
    try {
      final url = (webdavCfg['url'] ?? '') as String;
      if (url.isEmpty) return false;
      final username = (webdavCfg['username'] ?? '') as String;
      final password = (webdavCfg['password'] ?? '') as String;
      final remoteRoot = (webdavCfg['remote_path'] ?? '') as String;

      final prefs = await SharedPreferences.getInstance();
      var deviceId = prefs.getString('sync.device_id');
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = Uuid().v4();
        await prefs.setString('sync.device_id', deviceId);
      }
      String? userInfo = prefs.getString('auth.username');

      final payload = <String, dynamic>{
        'timestamp': isoTs ?? DateTime.now().toIso8601String(),
        'device_id': deviceId,
        'user': userInfo,
      };
      // checksum
      final sorted = Map.fromEntries(payload.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
      final jsonBytes = utf8.encode(jsonEncode(sorted));
      final checksum = sha256.convert(jsonBytes).toString();
      payload['checksum'] = checksum;
      final body = utf8.encode(jsonEncode(payload));

      // build target URL using robust join/resolution to avoid double-slash or missing segment bugs
      final meta = '.coinscape/last_cloud_backup.txt';
      final target = _buildRemoteUri(url, remoteRoot, meta);

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (username.isNotEmpty || password.isNotEmpty) {
        final basic = base64.encode(utf8.encode('$username:$password'));
        headers['Authorization'] = 'Basic $basic';
      }

      AppLogger.info(logPrefixSync, 'Writing remote backup marker to $target');
      final client = http.Client();
      try {
        try {
          await _ensureRemoteParentDirs(client, target, headers);
        } catch (e) {
          AppLogger.debug(logPrefixSync, 'ensureRemoteParentDirs failed (continuing): $e');
        }

        final resp = await client.put(target, headers: headers, body: body).timeout(const Duration(seconds: 30));
        if (resp.statusCode == 200 || resp.statusCode == 201 || resp.statusCode == 204) {
          AppLogger.info(logPrefixSync, 'Remote backup marker written: ${resp.statusCode}');
          return true;
        }

        AppLogger.warning(logPrefixSync, 'Remote marker write failed: ${resp.statusCode}');
        return false;
      } finally {
        client.close();
      }
    } catch (e, st) {
      AppLogger.error(logPrefixSync, 'Exception writing remote marker: $e', st);
      return false;
    }
  }

  /// Read the remote backup marker (.coinscape/last_cloud_backup.txt) from WebDAV.
  /// Returns the timestamp string (UTC ISO) if available, null otherwise.
  Future<String?> readRemoteBackupMarker(Map<String, dynamic> webdavCfg) async {
    final url = (webdavCfg['url'] ?? '') as String;
    if (url.isEmpty) return null;
    final username = (webdavCfg['username'] ?? '') as String;
    final password = (webdavCfg['password'] ?? '') as String;
    final remoteRoot = (webdavCfg['remote_path'] ?? '') as String;

    String? basicAuth;
    if (username.isNotEmpty || password.isNotEmpty) {
      basicAuth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    }

    final meta = '.coinscape/last_cloud_backup.txt';
    final target = _buildRemoteUri(url, remoteRoot, meta);

    final client = http.Client();
    try {
      final headers = <String, String>{};
      if (basicAuth != null) headers['Authorization'] = basicAuth;
      final resp = await client.get(target, headers: headers).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final text = resp.body.trim();
        if (text.isEmpty) return null;
        // Try parse as JSON (new format)
        try {
          final j = jsonDecode(text);
          if (j is Map && j.containsKey('timestamp')) {
            return j['timestamp'] as String?;
          }
        } catch (_) {}
        // Fallback: treat as plain ISO text (old format)
        return text;
      }
      return null;
    } catch (e) {
      AppLogger.debug(logPrefixSync, 'readRemoteBackupMarker failed: $e');
      return null;
    } finally {
      client.close();
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
