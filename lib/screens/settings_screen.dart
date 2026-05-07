import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/settings_provider.dart';
import '../providers/sync_providers.dart';
import '../providers/coin_providers.dart';
import '../services/sync_service.dart';
import '../services/api_service.dart';
import '../services/font_manager.dart';
import '../database/database.dart';
import '../utils/logger.dart';
import '../models/sync_models.dart';

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
  
  // 日志配置相关
  LogLevel _selectedLogLevel = LogLevel.info;
  bool _isLoadingLogLevel = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController();
    _userCtrl = TextEditingController();
    _pwdCtrl = TextEditingController();
    _backendUrlCtrl = TextEditingController(text: ApiService.baseUrl);
    _savePathCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFromProvider();
      _checkBackendConnection();
      _loadSavePath();
      _loadLogLevel();
      
      // 测试日志系统是否工作
      print('SETTINGS SCREEN INIT: 设置屏幕初始化完成');
      AppLogger.info(logPrefixSettings, '设置屏幕初始化完成 - 测试日志');
    });
  }

  void _initializeFromProvider() {
    final config = ref.read(webDavConfigProvider);
    _urlCtrl.text = config.url;
    _userCtrl.text = config.user;
    _pwdCtrl.text = config.password;
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
    setState(() => _isLoadingConfig = true);
    try {
      final config = await ApiService.getConfig();
      if (mounted) {
        _savePathCtrl.text = config['save_path'] as String? ?? '';
      }
    } catch (e) {
      // 忽略错误，保持空值
    } finally {
      if (mounted) {
        setState(() => _isLoadingConfig = false);
      }
    }
  }

  /// 加载日志级别
  Future<void> _loadLogLevel() async {
    setState(() => _isLoadingLogLevel = true);
    try {
      // 从SharedPreferences加载保存的日志级别
      final prefs = await SharedPreferences.getInstance();
      final savedLevel = prefs.getString('log_level');
      if (savedLevel != null) {
        final level = LogLevel.values.firstWhere(
          (e) => e.name == savedLevel,
          orElse: () => LogLevel.info,
        );
        setState(() => _selectedLogLevel = level);
        AppLogger.setLogLevel(level);
      }
    } catch (e) {
      AppLogger.error(logPrefixSettings, '加载日志级别失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingLogLevel = false);
      }
    }
  }

  /// 保存日志级别
  Future<void> _saveLogLevel() async {
    setState(() => _isLoadingLogLevel = true);
    try {
      // 保存到SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('log_level', _selectedLogLevel.name);
      
      // 更新AppLogger
      AppLogger.setLogLevel(_selectedLogLevel);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('日志级别已设置为: ${_selectedLogLevel.name.toUpperCase()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      AppLogger.error(logPrefixSettings, '保存日志级别失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存日志级别失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLogLevel = false);
      }
    }
  }

  /// 清空日志文件
  Future<void> _clearLogFile() async {
    try {
      if (kIsWeb) {
        // Web平台使用localStorage
        try {
          await AppLogger.clearWebLogs();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Web日志已清空'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          AppLogger.info(logPrefixSettings, 'Web日志已清空');
        } catch (e) {
          AppLogger.error(logPrefixSettings, '清空Web日志失败: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('清空日志失败: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
        return;
      }
      
      // 桌面/移动平台使用文件系统
      final logPath = await AppLogger.getConfiguredLogPath();
      if (logPath != null) {
        final file = File(logPath);
        if (await file.exists()) {
          await file.writeAsString('');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('日志文件已清空'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          AppLogger.info(logPrefixSettings, '日志文件已清空');
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('日志文件不存在'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无法获取日志文件路径'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error(logPrefixSettings, '清空日志文件失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('清空日志文件失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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

  Future<void> _saveBackendUrl() async {
    final url = _backendUrlCtrl.text.trim();
    if (url.isEmpty) return;
    
    try {
      await ApiService.saveBaseUrl(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('后端服务地址已保存')),
        );
        // 刷新连接状态
        await _checkBackendConnection();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
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
    return SyncService.fromConfig(ref);
  }

  Future<void> _push() async {
    if (!ref.read(webDavConfigProvider).isValid) {
       AppLogger.warning(logPrefixSettings, 'WebDAV 未配置');
       print('SETTINGS DEBUG: WebDAV 未配置'); // 调试输出
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先配置并保存 WebDAV')));
       return;
    }
    setState(() => _isSyncing = true);
    AppLogger.info(logPrefixSettings, '开始 WebDAV 上传...');
    print('SETTINGS DEBUG: 开始 WebDAV 上传...'); // 调试输出
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
      print('SETTINGS DEBUG: 数据汇总: ${series.length} 个业务, ${coins.length} 枚纪念币'); // 调试输出
      final service = _getService();
      print('SETTINGS DEBUG: 调用 service.pushBackup()...'); // 调试输出
      await service.pushBackup(series, coins, links, coinImages, seriesImages);
      
      AppLogger.info(logPrefixSettings, 'WebDAV 上传成功');
      print('SETTINGS DEBUG: WebDAV 上传成功'); // 调试输出
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('推送(上传)成功！')));
      }
    } catch (e, st) {
      // 显示更详细的错误信息
      final errorStr = e.toString();
      final fullError = '上传失败: $errorStr\n类型: ${e.runtimeType}\n栈追踪: $st';
      AppLogger.error(logPrefixSettings, fullError, st);
      print('🎯 SETTINGS ERROR: 上传失败 - $errorStr');
      print('🎯 SETTINGS ERROR TYPE: ${e.runtimeType}');
      print('🎯 SETTINGS ERROR STACK: $st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('云端备份失败: $errorStr')));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
      print('SETTINGS DEBUG: 上传操作完成'); // 调试输出
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
      // 显示更详细的错误信息
      final errorStr = e.toString();
      final fullError = '下载失败: $errorStr\n类型: ${e.runtimeType}\n栈追踪: $st';
      AppLogger.error(logPrefixSettings, fullError, st);
      print('🎯 SETTINGS ERROR: 下载失败 - $errorStr');
      print('🎯 SETTINGS ERROR TYPE: ${e.runtimeType}');
      print('🎯 SETTINGS ERROR STACK: $st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('云端备份下载失败: $errorStr')));
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

  /// 构建日志配置卡片
  Widget _buildLogSettingsCard() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            const ListTile(
              title: Text('日志配置', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('配置日志级别和清理日志文件'),
              leading: Icon(Icons.article),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 当前日志文件路径显示（仅信息）
                  if (AppLogger.logFilePath != null && !kIsWeb)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '日志文件: ${AppLogger.logFilePath}',
                              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 日志级别选择标题
                  const Text('日志级别:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  const SizedBox(height: 8),
                  
                  // 日志级别选择Radio按钮
                  ...LogLevel.values.map((level) {
                    return RadioListTile<LogLevel>(
                      title: Text(
                        '${level.name.toUpperCase()} (${_getLogLevelDescription(level)})',
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(_getLogLevelDetails(level)),
                      value: level,
                      groupValue: _selectedLogLevel,
                      onChanged: _isLoadingLogLevel ? null : (value) {
                        if (value != null) {
                          setState(() => _selectedLogLevel = value);
                        }
                      },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                  
                  const SizedBox(height: 16),
                  
                  // 操作按钮
                  Column(
                    children: [
                      // 保存日志级别按钮
                      ElevatedButton.icon(
                        onPressed: _isLoadingLogLevel ? null : _saveLogLevel,
                        icon: _isLoadingLogLevel
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save, size: 18),
                        label: Text(_isLoadingLogLevel ? '保存中...' : '保存日志级别'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // 清空日志文件按钮
                      ElevatedButton.icon(
                        onPressed: _clearLogFile,
                        icon: const Icon(Icons.delete_sweep, size: 18),
                        label: const Text('清空日志文件'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          backgroundColor: Colors.orange.shade100,
                          foregroundColor: Colors.orange.shade900,
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // 生成测试日志按钮
                      ElevatedButton.icon(
                        onPressed: _generateTestLogs,
                        icon: const Icon(Icons.bug_report, size: 18),
                        label: const Text('生成测试日志'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          backgroundColor: Colors.blueGrey.shade100,
                          foregroundColor: Colors.blueGrey.shade800,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  

  /// 获取日志级别描述
  String _getLogLevelDescription(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '所有日志';
      case LogLevel.info:
        return '信息及以上';
      case LogLevel.warning:
        return '警告及以上';
      case LogLevel.error:
        return '仅错误';
    }
  }

  /// 获取日志级别详细信息
  String _getLogLevelDetails(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '记录DEBUG, INFO, WARNING, ERROR所有级别';
      case LogLevel.info:
        return '记录INFO, WARNING, ERROR级别（不记录DEBUG）';
      case LogLevel.warning:
        return '记录WARNING, ERROR级别（不记录DEBUG, INFO）';
      case LogLevel.error:
        return '仅记录ERROR级别';
    }
  }

  /// 生成测试日志
  Future<void> _generateTestLogs() async {
    try {
      AppLogger.debug(logPrefixSettings, '这是一个调试级别的测试日志');
      AppLogger.info(logPrefixSettings, '这是一个信息级别的测试日志');
      AppLogger.warning(logPrefixSettings, '这是一个警告级别的测试日志');
      AppLogger.error(logPrefixSettings, '这是一个错误级别的测试日志');
      
      // 使用模块化的日志方法
      AppLogger.moduleInfo('database', '数据库连接测试');
      AppLogger.moduleWarning('sync', '同步过程警告');
      AppLogger.moduleError('api', 'API调用失败', StackTrace.current);
      
      // 测试方法调用日志
      AppLogger.methodCall('SettingsScreen', '_generateTestLogs');
      AppLogger.methodCall('TestService', 'processData', params: {
        'id': '12345',
        'name': '测试数据',
        'count': 42,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('测试日志已生成，请检查日志文件'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      AppLogger.error(logPrefixSettings, '生成测试日志失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('生成测试日志失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
color: _isBackendConnected ? const Color.fromRGBO(76, 175, 80, 0.1) : const Color.fromRGBO(244, 67, 54, 0.1),
                 borderRadius: BorderRadius.circular(8),
                 border: Border.all(
                   color: _isBackendConnected ? const Color.fromRGBO(76, 175, 80, 0.3) : const Color.fromRGBO(244, 67, 54, 0.3),
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
            // 后端服务地址配置
            Row(
              children: [
                Icon(Icons.link, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('后端服务地址', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('设置Flutter Web连接的后端服务器地址，用于WebDAV代理等功能。', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _backendUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: '后端服务地址',
                      hintText: '例如: http://localhost:9876',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.dns),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveBackendUrl,
                  child: const Text('保存'),
                ),
              ],
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
    final webDavConfig = ref.watch(webDavConfigProvider);
    
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
            
            // 后端代理设置（仅Web端显示）
            if (kIsWeb) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 1,
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flutter Web 跨域解决方案',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        title: const Text('开启后端代理 (解决网页版跨域)'),
                        subtitle: const Text('启用后，WebDAV请求将通过后端服务中转，避免浏览器同源策略限制'),
                        value: webDavConfig.proxyEnabled,
                        onChanged: (value) async {
                          await ref.read(webDavConfigProvider.notifier).setProxyEnabled(value);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(value ? '已启用后端代理' : '已禁用后端代理'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Text(
                          '当前后端地址: ${ApiService.baseUrl}',
                          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
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

              // ===== 日志配置 =====
              _buildLogSettingsCard(),

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
