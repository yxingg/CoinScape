import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../providers/sync_providers.dart';
import '../providers/coin_providers.dart';
import '../providers/settings_provider.dart';
import '../services/sync_service.dart';
import '../services/font_manager.dart';
import '../models/sync_models.dart';
import '../database/database.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _urlCtrl;
  late TextEditingController _userCtrl;
  late TextEditingController _pwdCtrl;

  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(webDavConfigProvider);
    _urlCtrl = TextEditingController(text: config.url);
    _userCtrl = TextEditingController(text: config.user);
    _pwdCtrl = TextEditingController(text: config.password);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    if (_formKey.currentState!.validate()) {
      await ref.read(webDavConfigProvider.notifier).saveConfig(
        _urlCtrl.text.trim(),
        _userCtrl.text.trim(),
        _pwdCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('配置已保存')));
      }
    }
  }

  SyncService _getService() {
    final config = ref.read(webDavConfigProvider);
    return SyncService(url: config.url, user: config.user, password: config.password);
  }

  Future<void> _push() async {
    if (!ref.read(webDavConfigProvider).isValid) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先配置并保存 WebDAV')));
       return;
    }
    setState(() => _isSyncing = true);
    try {
      final repo = ref.read(coinRepositoryProvider);
      final series = await repo.db.select(repo.db.series).get();
      final coins = await repo.db.select(repo.db.coins).get();
      final links = await repo.db.select(repo.db.coinSeriesLink).get();
      final coinImages = await repo.db.select(repo.db.coinImages).get();
      final seriesImages = await repo.db.select(repo.db.seriesImages).get();

      final service = _getService();
      await service.pushBackup(series, coins, links, coinImages, seriesImages);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('推送(上传)成功！')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('云同步上传失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _pull() async {
    if (!ref.read(webDavConfigProvider).isValid) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先配置并保存 WebDAV')));
       return;
    }
    setState(() => _isSyncing = true);
    try {
      final service = _getService();
      final data = await service.pullBackup();
      
      if (mounted) {
        await _mergeData(data);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('拉取(下载)并合并成功！')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('云同步下载失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _mergeData(SyncData data) async {
    final repo = ref.read(coinRepositoryProvider);
    final db = repo.db;

    // 解析云端数据 
    final incomingSeries = data.series.map((e) => SeriesData.fromJson(e)).toList();
    final incomingCoins = data.coins.map((e) => Coin.fromJson(e)).toList();
    final incomingLinks = data.links.map((e) => CoinSeriesLinkData.fromJson(e)).toList();
    final incomingCoinImages = data.coinImages.map((e) => CoinImage.fromJson(e)).toList();
    final incomingSeriesImages = data.seriesImages.map((e) => SeriesImage.fromJson(e)).toList();

    // 筛选冲突
    final existingSeries = await db.select(db.series).get();
    final existingSeriesIds = existingSeries.map((e) => e.id).toSet();
    
    final existingCoins = await db.select(db.coins).get();
    final existingCoinsIds = existingCoins.map((e) => e.id).toSet();

    bool overwriteAllConflicts = false;
    bool skipAllConflicts = false;

    // 处理 Series
    for (final s in incomingSeries) {
      if (existingSeriesIds.contains(s.id)) {
        if (!overwriteAllConflicts && !skipAllConflicts) {
          final res = await _askConflict('冲突的系列', s.name);
          if (res == 'overwrite_all') overwriteAllConflicts = true;
          if (res == 'skip_all') skipAllConflicts = true;
          if (res == 'skip' || res == 'skip_all') continue;
        } else if (skipAllConflicts) {
          continue;
        }
        await db.update(db.series).replace(s);
      } else {
        await db.into(db.series).insert(s);
      }
    }

    // 重置状态
    overwriteAllConflicts = false;
    skipAllConflicts = false;

    // 处理 Coins
    for (final c in incomingCoins) {
      if (existingCoinsIds.contains(c.id)) {
        if (!overwriteAllConflicts && !skipAllConflicts) {
          final res = await _askConflict('冲突的纪念币', c.name);
          if (res == 'overwrite_all') overwriteAllConflicts = true;
          if (res == 'skip_all') skipAllConflicts = true;
          if (res == 'skip' || res == 'skip_all') continue;
        } else if (skipAllConflicts) {
          continue;
        }
        await db.update(db.coins).replace(c);
      } else {
        await db.into(db.coins).insert(c);
      }
    }

    // 处理Links (安全地忽略重复)
    for (final l in incomingLinks) {
       await db.into(db.coinSeriesLink).insert(l, mode: drift.InsertMode.insertOrIgnore);
    }

    // 图片关系按主键覆盖
    for (final img in incomingCoinImages) {
      await db.into(db.coinImages).insert(img, mode: drift.InsertMode.insertOrReplace);
    }
    for (final img in incomingSeriesImages) {
      await db.into(db.seriesImages).insert(img, mode: drift.InsertMode.insertOrReplace);
    }
  }

  Widget _buildFontSettingsCard(BuildContext context, AppSettings settings) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            const ListTile(
              title: Text('导出 PDF 字体配置', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('设置 PDF 报告的默认排版字体'),
              leading: Icon(Icons.font_download),
            ),
            const Divider(),
            ListTile(
              title: const Text('主要字体 (中文)'),
              subtitle: Text(settings.chineseFontId),
              trailing: const Icon(Icons.edit),
              onTap: () => _showFontPicker(context, true),
            ),
            ListTile(
              title: const Text('次要字体 (英文/数字)'),
              subtitle: Text(settings.englishFontId),
              trailing: const Icon(Icons.edit),
              onTap: () => _showFontPicker(context, false),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFontPicker(BuildContext context, bool isChinese) async {
    final curId = isChinese ? ref.read(settingsProvider).chineseFontId : ref.read(settingsProvider).englishFontId;
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: Text(isChinese ? '选择中文字体' : '选择英文字体'),
          children: [
            _buildFontOption(ctx, 'preset_noto_sans_sc_regular', 'Noto Sans SC (常规)', curId),
            _buildFontOption(ctx, 'preset_noto_sans_sc_bold', 'Noto Sans SC (加粗)', curId),
            _buildFontOption(ctx, 'preset_roboto_regular', 'Roboto (常规)', curId),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('从本地导入 .ttf 字体...'),
              onTap: () => Navigator.pop(ctx, 'pick_custom'),
            ),
          ],
        );
      }
    );

    if (result != null) {
      if (result == 'pick_custom') {
        final customId = await FontManager.pickAndSaveCustomFont();
        if (customId != null) {
          if (isChinese) {
            await ref.read(settingsProvider.notifier).setChineseFont(customId);
          } else {
            await ref.read(settingsProvider.notifier).setEnglishFont(customId);
          }
          if (!mounted) return;
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已导入并应用自定义字体')));
        }
      } else {
        // 选择的是预设字体
        bool hasFont = await FontManager.hasFont(result);
        if (!hasFont) {
          if (!mounted) return;
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('开始下载预设字体，此过程可能需要几秒钟...')));
          final success = await FontManager.downloadAndSavePresetFont(result);
          if (!success) {
            if (!mounted) return;
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('字体下载失败')));
            return;
          }
        }
        if (isChinese) {
          await ref.read(settingsProvider.notifier).setChineseFont(result);
        } else {
          await ref.read(settingsProvider.notifier).setEnglishFont(result);
        }
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已应用字体')));
      }
    }
  }

  Widget _buildFontOption(BuildContext ctx, String id, String name, String curId) {
    return ListTile(
      leading: Icon(curId == id ? Icons.check_circle : Icons.circle_outlined, 
               color: curId == id ? Colors.green : Colors.grey),
      title: Text(name),
      onTap: () => Navigator.pop(ctx, id),
    );
  }

  Future<String?> _askConflict(String entityType, String entityName) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('发现冲突'),
        content: Text('检测到本地已存在 $entityType: "$entityName"。\n请选择如何处理：'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'skip'), child: const Text('跳过')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'skip_all'), child: const Text('全部跳过')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'overwrite'), child: const Text('覆盖本地')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'overwrite_all'), child: const Text('全部覆盖')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFontSettingsCard(context, settings),
              const SizedBox(height: 24),
              const Text('配置支持 WebDAV 的网盘（例如坚果云），以实现数据的无服务器同步。', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlCtrl,
                decoration: const InputDecoration(labelText: 'WebDAV 服务器地址', hintText: 'https://dav.jianguoyun.com/dav/'),
                validator: (v) => v!.isEmpty ? '地址不能为空' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _userCtrl,
                decoration: const InputDecoration(labelText: '用户名/邮箱'),
                validator: (v) => v!.isEmpty ? '用户名不能为空' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pwdCtrl,
                decoration: const InputDecoration(labelText: '应用授权密码'),
                obscureText: true,
                validator: (v) => v!.isEmpty ? '密码不能为空' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSyncing ? null : _saveConfig,
                child: const Text('保存配置'),
              ),
              const Divider(height: 48),
              if (_isSyncing)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _push,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('云端备份 (Push)'),
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColorLight),
                    ),
                    ElevatedButton.icon(
                      onPressed: _pull,
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('拉取合并 (Pull)'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade100),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
