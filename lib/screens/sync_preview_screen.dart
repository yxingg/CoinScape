import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

import '../services/api_service.dart';
import '../services/file_sync.dart';
import '../services/sync_service.dart';
import '../services/file_sync_db.dart';
import '../providers/sync_providers.dart';
import '../utils/logger.dart';

class SyncPreviewScreen extends ConsumerStatefulWidget {
  const SyncPreviewScreen({super.key});

  @override
  ConsumerState<SyncPreviewScreen> createState() => _SyncPreviewScreenState();
}

class _SyncPreviewScreenState extends ConsumerState<SyncPreviewScreen> {
  bool _loading = true;
  List<dynamic> _entries = [];
  Map<String, dynamic> _counts = {};
  final Map<String, bool> _itemLoading = {};

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() => _loading = true);

    final webdavCfg = ref.read(webDavConfigProvider);
    try {
      if (kIsWeb || webdavCfg.proxyEnabled) {
        final preview = await ApiService.previewPull();
        setState(() {
          _counts = preview['counts'] as Map<String, dynamic>? ?? {};
          _entries = preview['entries'] as List<dynamic>? ?? [];
          _loading = false;
        });
        return;
      }

      // Native (Android/iOS) and proxy disabled: use local FileSyncManager for preview
      final fs = FileSyncManager.instance;
      final detailed = await fs.getDetailedStatus();

      // Map local status to a preview-like structure
      final counts = detailed['counts'] as Map<String, dynamic>? ?? {};
      final pending = detailed['pending_preview'] as List<dynamic>? ?? [];

      final entries = <Map<String, dynamic>>[];
      for (final pitem in pending) {
        final path = (pitem is Map && pitem.containsKey('path')) ? (pitem['path'] as String) : (pitem.toString());
        entries.add({
          'path': path,
          // mark as local-only pending uploads so user knows these are local changes
          'status': 'local_only',
          'remote': null,
        });
      }

      setState(() {
        _counts = {
          'new_remote': 0,
          'modified_remote': 0,
          'local_only': counts['pending'] ?? 0,
        };
        _entries = entries;
        _loading = false;
      });
    } catch (e, st) {
      AppLogger.error('[SYNC]', '预览拉取失败: $e', st);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('获取预览失败: $e')));
      setState(() => _loading = false);
    }
  }

  Future<void> _pullOne(String path, int index) async {
    setState(() => _itemLoading[path] = true);
    final webdavCfg = ref.read(webDavConfigProvider);
    try {
      if (kIsWeb || webdavCfg.proxyEnabled) {
        final resp = await ApiService.pullFile(path);
        final result = resp['result'] as Map<String, dynamic>?;
        final ok = result != null && result['success'] == true;
        if (ok) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('拉取成功')));
          setState(() => _entries[index]['status'] = 'pulled');
        } else {
          final err = result != null && result.containsKey('error') ? result['error'] : resp.toString();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('拉取失败: $err')));
        }
        return;
      }

      // Native local pull: use SyncService to read remote file and write into app documents
      final syncService = SyncService.fromConfig(ref);
      final client = syncService.client;
      final bytes = await client.read(path);
      if (bytes == null || bytes.isEmpty) throw Exception('下载文件为空');

      final appDir = await getApplicationDocumentsDirectory();
      final dest = File(p.join(appDir.path, path));
      await dest.parent.create(recursive: true);
      await dest.writeAsBytes(bytes);

      // compute metadata and update index DB
      final sha = sha256.convert(bytes).toString();
      final stat = await dest.stat();
      final size = stat.size;
      final mtime = stat.modified.millisecondsSinceEpoch / 1000.0;

      final db = await FileSyncDb.getInstance();
      await db.upsertIndex(
        pathStr: path,
        sha256: sha,
        size: size,
        mtime: mtime,
        lastSeenAt: DateTime.now().toIso8601String(),
        lastSyncedAt: DateTime.now().toIso8601String(),
        remotePath: '',
        remoteEtag: null,
      );

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('拉取成功')));
      setState(() => _entries[index]['status'] = 'pulled');
    } catch (e, st) {
      AppLogger.error('[SYNC]', '拉取单文件失败: $e', st);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('拉取失败: $e')));
    } finally {
      setState(() => _itemLoading[path] = false);
    }
  }

  Widget _buildItem(BuildContext context, int index) {
    final e = _entries[index] as Map<String, dynamic>;
    final path = e['path'] as String? ?? '';
    final status = e['status'] as String? ?? '';
    final remote = e['remote'] as Map<String, dynamic>?;
    final size = remote != null && remote['size'] != null ? remote['size'].toString() : '-';
    final lm = remote != null && remote['last_modified'] != null ? remote['last_modified'].toString() : '';

    final loading = _itemLoading[path] == true;

    return ListTile(
      title: Text(path),
      subtitle: Text('状态: $status  大小: $size  更新时间: $lm'),
      trailing: (status == 'new_remote' || status == 'modified_remote' || status == 'local_only')
          ? ElevatedButton(
              onPressed: loading ? null : () => _pullOne(path, index),
              child: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('拉取'),
            )
          : Text(status),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('远端文件预览与选择拉取'),
        actions: [
          IconButton(
            onPressed: _loadPreview,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新预览',
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(child: Text('新文件: ${_counts['new_remote'] ?? 0}')),
                      Expanded(child: Text('改动: ${_counts['modified_remote'] ?? 0}')),
                      Expanded(child: Text('本地独有: ${_counts['local_only'] ?? 0}')),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: _buildItem,
                  ),
                ),
              ],
            ),
    );
  }
}
