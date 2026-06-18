import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import '../services/file_sync.dart';
import '../providers/sync_providers.dart';
import '../utils/logger.dart';

class SyncPreviewScreen extends ConsumerStatefulWidget {
  const SyncPreviewScreen({super.key});

  @override
  ConsumerState<SyncPreviewScreen> createState() => _SyncPreviewScreenState();
}

class _TreeNode {
  final String name;
  final String path; // full path from root
  final Map<String, _TreeNode> children = {};
  Map<String, dynamic>? entry; // only set for file nodes

  _TreeNode(this.name, this.path);

  bool get isDir => children.isNotEmpty;
}

class _SyncPreviewScreenState extends ConsumerState<SyncPreviewScreen> {
  bool _loading = true;
  List<dynamic> _entries = [];
  Map<String, dynamic> _counts = {};
  final Map<String, bool> _itemLoading = {};
  final Map<String, bool> _selected = {};

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
          _selected.clear();
          _loading = false;
        });
        return;
      }

      // Native fallback: reuse local file sync preview if available
      final fs = FileSyncManager.instance;
      final cfg = {
        'url': webdavCfg.url,
        'username': webdavCfg.user,
        'password': webdavCfg.password,
        'remote_path': ''
      };
      final detailed = await fs.getDetailedStatus(webdavCfg: cfg);

      final counts = detailed['counts'] as Map<String, dynamic>? ?? {};
      final remotePreview = detailed['remote_preview'] as List<dynamic>? ?? [];
      final pending = detailed['pending_preview'] as List<dynamic>? ?? [];

      final entries = <Map<String, dynamic>>[];
      for (final r in remotePreview) {
        if (r is Map) entries.add(r as Map<String, dynamic>);
      }
      for (final pitem in pending) {
        final path = (pitem is Map && pitem.containsKey('path')) ? (pitem['path'] as String) : (pitem.toString());
        entries.add({'path': path, 'status': 'local_only', 'remote': null, 'local': null});
      }

      setState(() {
        _counts = {
          'new_remote': counts['new_remote'] ?? 0,
          'modified_remote': counts['modified_remote'] ?? 0,
          'synced': counts['synced'] ?? 0,
          'local_only': counts['pending'] ?? 0,
        };
        _entries = entries;
        _selected.clear();
        _loading = false;
      });
    } catch (e, st) {
      AppLogger.error('[SYNC]', '预览拉取失败: $e', st);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('获取预览失败: $e')));
      setState(() => _loading = false);
    }
  }

  // Build a tree structure from flat entry list
  _TreeNode _buildTree() {
    final root = _TreeNode('', '');
    for (final item in _entries) {
      if (item is! Map) continue;
      final path = (item['path'] as String?) ?? '';
      if (path.isEmpty) continue;
      final parts = path.split('/');
      var node = root;
      var acc = '';
      for (var i = 0; i < parts.length; i++) {
        final seg = parts[i];
        acc = acc.isEmpty ? seg : '$acc/$seg';
        if (!node.children.containsKey(seg)) {
          node.children[seg] = _TreeNode(seg, acc);
        }
        node = node.children[seg]!;
      }
      node.entry = Map<String, dynamic>.from(item);
    }
    return root;
  }

  Future<void> _pullOne(String path) async {
    setState(() => _itemLoading[path] = true);
    final webdavCfg = ref.read(webDavConfigProvider);
    try {
      if (kIsWeb || webdavCfg.proxyEnabled) {
        final resp = await ApiService.pullFile(path);
        final result = resp['result'] as Map<String, dynamic>?;
        final ok = result != null && result['success'] == true;
        if (ok) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('拉取成功')));
          await _loadPreview();
        } else {
          final err = result != null && result.containsKey('error') ? result['error'] : resp.toString();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('拉取失败: $err')));
        }
        return;
      }

      // Native fallback: use local FileSyncManager to pull a single file and
      // refresh the preview. This allows preview-screen pulls on Android/iOS.
      final fs = FileSyncManager.instance;
      final cfg = {
        'url': webdavCfg.url,
        'username': webdavCfg.user,
        'password': webdavCfg.password,
        'remote_path': ''
      };
      final resp = await fs.pullOne(path, cfg);
      final result = resp['result'] as Map<String, dynamic>?;
      final ok = result != null && result['success'] == true;
      if (ok) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('拉取成功')));
        await _loadPreview();
      } else {
        final err = result != null && result.containsKey('error') ? result['error'] : resp.toString();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('拉取失败: $err')));
      }
    } catch (e, st) {
      AppLogger.error('[SYNC]', '拉取单文件失败: $e', st);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('拉取失败: $e')));
    } finally {
      setState(() => _itemLoading[path] = false);
    }
  }

  Future<void> _pullSelected() async {
    final selectedPaths = _selected.keys.where((k) => _selected[k] == true).toList();
    if (selectedPaths.isEmpty) return;
    for (final p in selectedPaths) {
      await _pullOne(p);
    }
  }

  Widget _buildFileTile(_TreeNode node) {
    final entry = node.entry ?? {};
    final path = node.path;
    final status = entry['status'] ?? '';
    final remote = entry['remote'] as Map<String, dynamic>?;
    final local = entry['local'] as Map<String, dynamic>?;

    final remoteExists = remote != null;
    final remoteLm = remoteExists ? (remote['last_modified'] ?? '-') : '-';

    final localExists = local != null;
    final localSynced = localExists ? (local['last_synced_at'] ?? '-') : '-';

    final loading = _itemLoading[path] == true;

    return ListTile(
      leading: Checkbox(
        value: _selected[path] == true,
        onChanged: (v) => setState(() => _selected[path] = v == true),
      ),
      title: Text(node.name),
      subtitle: Row(
        children: [
          Expanded(child: Text('云端: ${remoteExists ? '存在' : '不存在'}  更新时间: $remoteLm', style: TextStyle(fontSize: 12))),
          const SizedBox(width: 8),
          Expanded(child: Text('本地: ${localExists ? '存在' : '不存在'}  同步时间: $localSynced', style: TextStyle(fontSize: 12))),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'synced')
            const Icon(Icons.check_circle, color: Colors.green, size: 20)
          else if (status == 'new_remote' || status == 'modified_remote' || status == 'local_only')
            ElevatedButton(
              onPressed: loading ? null : () => _pullOne(path),
              child: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('拉取'),
            ),
        ],
      ),
    );
  }

  Widget _buildNodeWidget(_TreeNode node) {
    if (node.isDir) {
      final children = node.children.values.toList()..sort((a, b) => a.name.compareTo(b.name));
      return ExpansionTile(
        title: Text(node.name.isEmpty ? '根目录' : node.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        children: children.map((c) => _buildNodeWidget(c)).toList(),
      );
    }
    return _buildFileTile(node);
  }

  @override
  Widget build(BuildContext context) {
    final tree = _buildTree();

    return Scaffold(
      appBar: AppBar(
        title: const Text('远端文件预览与选择拉取'),
        actions: [
          IconButton(onPressed: _loadPreview, icon: const Icon(Icons.refresh), tooltip: '刷新预览'),
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
                      Expanded(child: Text('已同步: ${_counts['synced'] ?? 0}')),
                      Expanded(child: Text('本地独有: ${_counts['local_only'] ?? 0}')),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    children: () {
                      final topNodes = tree.children.values.toList();
                      topNodes.sort((a, b) => a.name.compareTo(b.name));
                      return topNodes.map((c) => _buildNodeWidget(c)).toList();
                    }(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => setState(() {
                          final all = tree.children.values.expand((d) => _collectPaths(d)).toList();
                          for (final p in all) {
                            _selected[p] = true;
                          }
                        }),
                        child: const Text('全选'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setState(() => _selected.clear()),
                        child: const Text('取消全选'),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _pullSelected,
                        icon: const Icon(Icons.cloud_download),
                        label: const Text('拉取选中'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  List<String> _collectPaths(_TreeNode node) {
    final List<String> paths = [];
    if (node.entry != null) paths.add(node.path);
    for (final c in node.children.values) {
      paths.addAll(_collectPaths(c));
    }
    return paths;
  }
}
