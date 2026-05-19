import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

class SyncPreviewScreen extends StatefulWidget {
  const SyncPreviewScreen({super.key});

  @override
  State<SyncPreviewScreen> createState() => _SyncPreviewScreenState();
}

class _SyncPreviewScreenState extends State<SyncPreviewScreen> {
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
    setState(() {
      _loading = true;
    });
    try {
      final preview = await ApiService.previewPull();
      setState(() {
        _counts = preview['counts'] as Map<String, dynamic>? ?? {};
        _entries = preview['entries'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (e) {
      AppLogger.error('[SYNC]', '预览拉取失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('获取预览失败: $e')));
      }
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _pullOne(String path, int index) async {
    setState(() {
      _itemLoading[path] = true;
    });
    try {
      final resp = await ApiService.pullFile(path);
      final result = resp['result'] as Map<String, dynamic>?;
      final ok = result != null && result['success'] == true;
      if (ok) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('拉取成功')));
        setState(() {
          _entries[index]['status'] = 'pulled';
        });
      } else {
        final err = result != null && result.containsKey('error') ? result['error'] : resp.toString();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('拉取失败: $err')));
      }
    } catch (e) {
      AppLogger.error('[SYNC]', '拉取单文件失败: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('拉取失败: $e')));
    } finally {
      setState(() {
        _itemLoading[path] = false;
      });
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
      trailing: (status == 'new_remote' || status == 'modified_remote')
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
