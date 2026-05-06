import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../providers/sync_providers.dart';
import '../providers/coin_providers.dart';
import '../providers/settings_provider.dart';
import '../services/sync_service.dart';
import '../services/font_manager.dart';
import '../services/api_service.dart';
import '../models/sync_models.dart';
import '../database/database.dart';
import '../utils/logger.dart';

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
  late TextEditingController _backendUrlCtrl;
  late TextEditingController _savePathCtrl;

  bool _isSyncing = false;
  bool _isBackendConnected = false;
  bool _isCheckingBackend = false;
  bool _isLoadingConfig = false;
  bool _isSavingPath = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(webDavConfigProvider);
    _urlCtrl = TextEditingController(text: config.url);
    _userCtrl = TextEditingController(text: config.user);
    _pwdCtrl = TextEditingController(text: config.password);
    _backendUrlCtrl = TextEditingController(text: ApiService.baseUrl);
    _savePathCtrl = TextEditingController();
    _checkBackendConnection();
    _loadSavePath();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _pwdCtrl.dispose();
    _backendUrlCtrl.dispose();
    _savePathCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkBackendConnection() async {
    setState(() => _isCheckingBackend = true);
    final connected = await ApiService.checkHealth();
    if (mounted) {
      setState(() {
        _isBackendConnected = connected;
        _isCheckingBackend = false;
      });
    }
  }

  Future<void> _loadSavePath() async {
    if (!kIsWeb) return;
    setState(() => _isLoadingConfig = true);
    try {
      final config = await ApiService.getConfig();
      if (mounted) {
        _savePathCtrl.text = config['save_path'] as String? ?? '';
      }
    } catch (_) {
      // 忽略加载失败
    } finally {
      if (mounted) setState(() => _isLoadingConfig = false);
    }
  }

  Future<void> _saveSavePath() async {
    final path = _savePathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() => _isSavingPath = true);
    try {
      final result = await ApiService.updateSavePath(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] as String? ?? '保存路径已更新，重启服务器后生效')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingPath = false);
    }
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
       AppLogger.warning(logPrefixSettings, 'WebDAV 未配置');
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先配置并保存 WebDAV')));
       return;
    }
    setState(() => _isSyncing = true);
    AppLogger.info(logPrefixSettings, '开始 WebDAV 上传...');
    try {
      final repo = ref.read(coinRepositoryProvider);
      final series = await repo.getAllSeries();
      final coins = await repo.getAllCoins();
      final links = <CoinSeriesLinkData>[];
      final coinImages = <CoinImage>[];
      final seriesImages = <SeriesImage>[];

      // 收集所有关联数据
      for (final coin in coins) {
        final linkIds = await repo.getSeriesIdsForCoin(coin.id);
        for (final sid in linkIds) {
          links.add(CoinSeriesLinkData(coinId: coin.id, seriesId: sid));
        }
        final imgs = await repo.getCoinImages(coin.id);
        coinImages.addAll(imgs);
      }
      for (final s in series) {
        final imgs = await repo.getSeriesImages(s.id);
        seriesImages.addAll(imgs);
      }

      AppLogger.info(logPrefixSettings, '数据汇总: ${series.length} 个业务, ${coins.length} 枚纪念币');
      final service = _getService();
      await service.pushBackup(series, coins, links, coinImages, seriesImages);
      
      AppLogger.info(logPrefixSettings, 'WebDAV 上传成功');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('推送(上传)成功！')));
      }
    } catch (e, st) {
      AppLogger.error(logPrefixSettings, '上传失败: $e', st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('云同步上传失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _pull() async {
    if (!ref.read(webDavConfigProvider).isValid) {
       AppLogger.warning(logPrefixSettings, 'WebDAV 未配置');
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先配置并保存 WebDAV')));
       return;
    }
    setState(() => _isSyncing = true);
    AppLogger.info(logPrefixSettings, '开始 WebDAV 下载...');
    try {
      final service = _getService();
      final data = await service.pullBackup();
      
      AppLogger.info(logPrefixSettings, '下载完成, 开始合并数据...');
      if (mounted) {
        await _mergeData(data);
      }
      
      AppLogger.info(logPrefixSettings, '拉取下载並合并成功');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('拉取(下载)并合并成功！')));
      }
    } catch (e, st) {
      AppLogger.error(logPrefixSettings, '下载失败: $e', st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('云同步下载失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _mergeData(SyncData data) async {
    final repo = ref.read(coinRepositoryProvider);

    // 解析云端数据 
    final incomingSeries = data.series.map((e) => SeriesData.fromJson(e as Map<String, dynamic>)).toList();
    final incomingCoins = data.coins.map((e) => Coin.fromJson(e as Map<String, dynamic>)).toList();
    final incomingLinks = data.links.map((e) => CoinSeriesLinkData.fromJson(e as Map<String, dynamic>)).toList();
    final incomingCoinImages = data.coinImages.map((e) => CoinImage.fromJson(e as Map<String, dynamic>)).toList();
    final incomingSeriesImages = data.seriesImages.map((e) => SeriesImage.fromJson(e as Map<String, dynamic>)).toList();

    // 筛选冲突
    final existingSeries = await repo.getAllSeries();
    final existingSeriesIds = existingSeries.map((e) => e.id).toSet();
    
    final existingCoins = await repo.getAllCoins();
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
        await repo.updateSeries(SeriesCompanion(
          id: drift.Value(s.id),
          name: drift.Value(s.name),
          description: drift.Value(s.description),
          createdAt: drift.Value(s.createdAt),
        ));
      } else {
        await repo.insertSeries(SeriesCompanion.insert(
          id: s.id,
          name: s.name,
          description: drift.Value(s.description),
          createdAt: s.createdAt,
        ));
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
        await repo.updateCoin(CoinsCompanion(
          id: drift.Value(c.id),
          name: drift.Value(c.name),
          year: drift.Value(c.year),
          faceValue: drift.Value(c.faceValue),
          material: drift.Value(c.material),
          weight: drift.Value(c.weight),
          diameter: drift.Value(c.diameter),
          mintage: drift.Value(c.mintage),
          mint: drift.Value(c.mint),
          grade: drift.Value(c.grade),
          unitPrice: drift.Value(c.unitPrice),
          quantity: drift.Value(c.quantity),
          quantityUnit: drift.Value(c.quantityUnit),
          collectionTime: drift.Value(c.collectionTime),
          createdAt: drift.Value(c.createdAt),
          comments: drift.Value(c.comments),
          firstImagePath: drift.Value(c.firstImagePath),
        ));
      } else {
        await repo.insertCoin(CoinsCompanion.insert(
          id: c.id,
          name: c.name,
          year: drift.Value(c.year),
          faceValue: drift.Value(c.faceValue),
          material: drift.Value(c.material),
          weight: drift.Value(c.weight),
          diameter: drift.Value(c.diameter),
          mintage: drift.Value(c.mintage),
          mint: drift.Value(c.mint),
          grade: drift.Value(c.grade),
          unitPrice: drift.Value(c.unitPrice),
          quantity: drift.Value(c.quantity),
          quantityUnit: drift.Value(c.quantityUnit),
          collectionTime: drift.Value(c.collectionTime),
          createdAt: c.createdAt,
          comments: drift.Value(c.comments),
          firstImagePath: drift.Value(c.firstImagePath),
        ));
      }
    }

    // 处理Links
    for (final l in incomingLinks) {
      await repo.linkCoinToSeries(l.coinId, l.seriesId);
    }

    // 图片关系
    for (final img in incomingCoinImages) {
      await repo.replaceCoinImages(img.coinId, [img.imagePath]);
    }
    for (final img in incomingSeriesImages) {
      await repo.replaceSeriesImages(img.seriesId, [img.imagePath]);
    }
  }

  Widget _buildFontSettingsCard(BuildContext context, AppSettings settings) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 24),
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

  /// 构建后端服务器配置卡片（仅 Web 端显示）
  Widget _buildBackendConfigCard() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dns, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('后端服务器配置', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Python 后端服务默认运行在 http://localhost:9876，数据将存储在后端服务器上。', 
              style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            // 后端连接状态
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isBackendConnected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isBackendConnected ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isCheckingBackend ? Icons.sync : (_isBackendConnected ? Icons.check_circle : Icons.error),
                    color: _isCheckingBackend ? Colors.orange : (_isBackendConnected ? Colors.green : Colors.red),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isCheckingBackend ? '正在检查连接...' :
                          (_isBackendConnected ? '后端服务已连接' : '后端服务未连接'),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: _isCheckingBackend ? Colors.orange : (_isBackendConnected ? Colors.green : Colors.red),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isBackendConnected 
                              ? '服务地址: ${ApiService.baseUrl}' 
                              : '请确保后端服务正在运行',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _isCheckingBackend ? null : _checkBackendConnection,
                    tooltip: '刷新连接状态',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            // 数据保存路径
            Row(
              children: [
                Icon(Icons.folder, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('数据保存路径', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('设置后端数据文件的存储目录，修改后需重启服务器生效。', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _savePathCtrl,
                    decoration: InputDecoration(
                      labelText: '保存路径',
                      hintText: _isLoadingConfig ? '正在加载...' : '例如: /data/coinscape',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.folder_open),
                      suffixIcon: _isLoadingConfig
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (_isSavingPath || _isLoadingConfig) ? null : _saveSavePath,
                  child: _isSavingPath
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('应用'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建 WebDAV 云同步配置卡片
  Widget _buildWebDavConfigCard() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_sync, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('WebDAV 云同步配置', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('配置支持 WebDAV 的网盘（例如坚果云），以实现数据的无服务器同步。', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'WebDAV 服务器地址',
                hintText: 'https://dav.jianguoyun.com/dav/',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              validator: (v) => v!.isEmpty ? '地址不能为空' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _userCtrl,
              decoration: const InputDecoration(
                labelText: '用户名/邮箱',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) => v!.isEmpty ? '用户名不能为空' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pwdCtrl,
              decoration: const InputDecoration(
                labelText: '应用授权密码',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              validator: (v) => v!.isEmpty ? '密码不能为空' : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSyncing ? null : _saveConfig,
                icon: const Icon(Icons.save),
                label: const Text('保存配置'),
              ),
            ),
            const Divider(height: 32),
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
              // ===== 后端服务器配置（仅 Web 端显示） =====
              if (kIsWeb) _buildBackendConfigCard(),

              // ===== PDF 字体配置 =====
              _buildFontSettingsCard(context, settings),

              // ===== WebDAV 云同步配置 =====
              _buildWebDavConfigCard(),
            ],
          ),
        ),
      ),
    );
  }
}
