import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';

import '../providers/settings_provider.dart';
import '../providers/sync_providers.dart';
import '../providers/coin_providers.dart';
import '../providers/auth_provider.dart';
import '../services/sync_service.dart';
import '../services/file_sync.dart';
import '../services/api_service.dart';
import '../services/font_manager.dart';
import '../database/database.dart';
import '../utils/logger.dart';
import '../models/sync_models.dart';
import '../utils/dialog_helper.dart';

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
  // Account management controllers
  late TextEditingController _acctUserCtrl;
  late TextEditingController _acctCurrentPwdCtrl;
  late TextEditingController _acctNewPwdCtrl;
  late TextEditingController _acctConfirmPwdCtrl;
  String _storedAuthUsername = '';
  bool _isChangingPassword = false;
  String? _acctError;

  bool _isSyncing = false;
  bool _isBackendConnected = false;
  bool _isCheckingBackend = false;
  bool _isSavingPath = false;
  Timer? _statusTimer;
  Map<String, dynamic>? _syncStatus;
  String? _latestChangeSource;
  String? _latestChangeTime;
  String? _localLatestTime;
  String? _cloudLatestTime;
  bool _hasQueriedLatestChange = false;
  String _mergePolicy = 'prefer_local';
  // upload queue UI
  List<Map<String, dynamic>> _uploadQueue = [];
  bool _showUploadQueue = false;
  Timer? _uploadPollTimer;
  
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
    _acctUserCtrl = TextEditingController();
    _acctCurrentPwdCtrl = TextEditingController();
    _acctNewPwdCtrl = TextEditingController();
    _acctConfirmPwdCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettingsToUI();
      _checkBackendConnection();
    });
  }

  void _loadSettingsToUI() {
    final settings = ref.read(settingsProvider);
    _backendUrlCtrl.text = settings.backendUrl;
    _savePathCtrl.text = settings.savePath;
    _urlCtrl.text = settings.webDavUrl;
    _userCtrl.text = settings.webDavUser;
    // For security, do not prefill the password field. User must re-enter to change.
    _pwdCtrl.text = '';

    final level = LogLevel.values.firstWhere(
      (e) => e.name == settings.logLevel,
      orElse: () => LogLevel.info,
    );
    setState(() => _selectedLogLevel = level);
    AppLogger.setLogLevel(level);

    // Load auth username from backend settings if possible
    _loadAuthUsername();
  }

  Future<void> _loadAuthUsername() async {
    try {
      final map = await ApiService.getAppSettings();
      final auth = map['auth'] as Map<String, dynamic>?;
      final user = auth != null && auth['username'] is String ? auth['username'] as String : '';
      setState(() {
        _acctUserCtrl.text = user;
        _storedAuthUsername = user;
      });
      // load merge policy from backend settings if present
      try {
        final sync = map['sync'] as Map<String, dynamic>?;
        final mp = sync != null && (sync['merge_policy'] is String || sync['mergePolicy'] is String)
            ? (sync['merge_policy'] ?? sync['mergePolicy']) as String
            : null;
        if (mp != null && mounted) setState(() => _mergePolicy = mp);
      } catch (_) {}
    } catch (_) {
      // ignore
    }
    // 同步最新修改信息（仅在启动时执行）
    _loadLatestChangeInfo();
  }

  Future<void> _loadLatestChangeInfo() async {
    try {
      final map = await ApiService.getAppSettings();
      final sync = map['sync'] as Map<String, dynamic>?;
      final src = sync != null && sync['latest_change_source'] is String ? sync['latest_change_source'] as String : null;
      final t = sync != null && sync['latest_change_time'] is String ? sync['latest_change_time'] as String : null;
      final local = sync != null && sync['last_local_change'] is String ? sync['last_local_change'] as String : null;
      final cloud = sync != null && sync['last_cloud_change'] is String ? sync['last_cloud_change'] as String : null;
      if (mounted) {
        setState(() {
          _latestChangeSource = src;
          _latestChangeTime = _formatBeijing(t);
          _localLatestTime = _formatBeijing(local);
          _cloudLatestTime = _formatBeijing(cloud);
          _hasQueriedLatestChange = true;
        });
      }
    } catch (_) {
      // ignore failures; UI will fall back to default text
    }
  }

  String? _formatBeijing(String? iso) {
    if (iso == null) return null;
    try {
      // server timestamps are stored as UTC ISO without timezone marker; if no timezone present,
      // append 'Z' to force UTC parsing. Then convert to Beijing time (UTC+8).
      final hasZone = RegExp(r'[Zz]|[+-]\d\d:\d\d').hasMatch(iso);
      final parsed = DateTime.parse(hasZone ? iso : (iso + 'Z'));
      final utc = parsed.toUtc();
      final bj = utc.add(const Duration(hours: 8));
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(bj);
    } catch (_) {
      return iso;
    }
  }

  Color _buildSyncBoxColor() {
    if (!_hasQueriedLatestChange) return Colors.grey.shade200;
    if (_latestChangeSource == 'equal') return Colors.green.shade50;
    return Colors.red.shade50;
  }

  Color _buildSyncBoxBorderColor() {
    if (!_hasQueriedLatestChange) return Colors.grey.shade400;
    if (_latestChangeSource == 'equal') return Colors.green.shade200;
    return Colors.red.shade200;
  }

  Color _buildSyncBoxTextColor() {
    if (!_hasQueriedLatestChange) return Colors.grey.shade700;
    if (_latestChangeSource == 'equal') return Colors.green.shade700;
    return Colors.red.shade700;
  }

  Widget _buildSyncBoxIcon() {
    if (!_hasQueriedLatestChange) {
      return Icon(Icons.sync, size: 16, color: Colors.grey[700]);
    }
    if (_latestChangeSource == 'equal') {
      return Icon(Icons.check_circle, size: 16, color: Colors.green);
    }
    if (_latestChangeSource == 'cloud') {
      return Icon(Icons.arrow_downward, size: 16, color: Colors.red);
    }
    // local
    return Icon(Icons.arrow_upward, size: 16, color: Colors.red);
  }

  String _buildSyncBoxLabel() {
    if (!_hasQueriedLatestChange) return '同步状态尚未查询';
    if (_latestChangeSource == 'equal') return '已同步';
    if (_latestChangeSource == 'cloud') return '待拉取';
    return '待备份';
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _pwdCtrl.dispose();
    _backendUrlCtrl.dispose();
    _savePathCtrl.dispose();
    _acctUserCtrl.dispose();
    _acctCurrentPwdCtrl.dispose();
    _acctNewPwdCtrl.dispose();
    _acctConfirmPwdCtrl.dispose();
    _statusTimer?.cancel();
    _uploadPollTimer?.cancel();
    
    super.dispose();
  }

  Future<void> _fetchQueueOnce() async {
    try {
      final res = await ApiService.getFileSyncQueue();
      if (res['success'] == true && res['queue'] is List) {
        final list = (res['queue'] as List).map((e) => Map<String, dynamic>.from(e as Map)).where((e) => e['action'] == 'upload').toList();
        if (mounted) setState(() {
          _uploadQueue = list;
        });
        // stop polling if no pending or in-progress items remain
        final hasActive = list.any((e) {
          final s = (e['status'] ?? '') as String;
          return s == 'pending' || s == 'in-progress' || s == 'in_progress';
        });
        if (!hasActive) {
          _stopUploadPolling();
        }
      }
    } catch (_) {}
  }

  void _startUploadPolling() {
    _uploadPollTimer?.cancel();
    _uploadPollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _fetchQueueOnce();
    });
  }

  void _stopUploadPolling() {
    _uploadPollTimer?.cancel();
    _uploadPollTimer = null;
  }

  Future<void> _updateSyncStatus() async {
    // Prefer backend status; fall back to local FileSyncManager status when backend is unreachable
    try {
      final res = await ApiService.getFileSyncStatus();
      if (res['success'] == true) {
        final st = res['status'] as Map<String, dynamic>?;
        if (mounted) setState(() => _syncStatus = st);
        return;
      }
    } catch (_) {
      // ignore and try local
    }
    try {
      final st = await FileSyncManager.instance.getDetailedStatus();
      if (mounted) setState(() => _syncStatus = st);
    } catch (_) {
      // ignore
    }
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    _updateSyncStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) => _updateSyncStatus());
  }

  void _stopStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  Future<void> _changeAccount() async {
    final newUser = _acctUserCtrl.text.trim();
    final curPwd = _acctCurrentPwdCtrl.text;
    final newPwd = _acctNewPwdCtrl.text;
    final confirm = _acctConfirmPwdCtrl.text;

    if (curPwd.isEmpty) {
      setState(() => _acctError = '请输入当前密码以确认身份');
      return;
    }
    if (newPwd.isNotEmpty && newPwd != confirm) {
      setState(() => _acctError = '两次新密码输入不一致');
      return;
    }

    setState(() {
      _isChangingPassword = true;
      _acctError = null;
    });

    try {
      // verify current credentials
      final ok = await ApiService.login(_storedAuthUsername, curPwd);
      if (!ok) {
        setState(() {
          _acctError = '当前密码错误';
          _isChangingPassword = false;
        });
        return;
      }

      final Map<String, dynamic> payload = {'auth': {}};
      if (newUser.isNotEmpty && newUser != _storedAuthUsername) {
        payload['auth']['username'] = newUser;
      }
      if (newPwd.isNotEmpty) {
        payload['auth']['password'] = newPwd;
      }

      if ((payload['auth'] as Map).isEmpty) {
        setState(() {
          _acctError = '未检测到变更';
          _isChangingPassword = false;
        });
        return;
      }

      final res = await ApiService.updateAppSettings(payload);
      if (res['success'] == true) {
        // force logout to require re-login with new credentials
        await ref.read(authProvider.notifier).logout();
        if (mounted) {
          DialogHelper.showSuccessSnackBar(context, '账户已更新，请重新登录');
        }
      } else {
        setState(() => _acctError = '更新失败');
      }
    } catch (e) {
      setState(() => _acctError = '更新失败: $e');
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
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

  Future<void> _saveSavePath() async {
    final path = _savePathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() => _isSavingPath = true);
    try {
      final result = await ApiService.updateSavePath(path);
      await ref.read(settingsProvider.notifier).update((s) => s.copyWith(savePath: path));
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
      await ref.read(settingsProvider.notifier).update((s) => s.copyWith(backendUrl: url));
      if (mounted) {
        DialogHelper.showSuccessSnackBar(context, '后端服务地址已保存');
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
      final url = _urlCtrl.text.trim();
      final user = _userCtrl.text.trim();
      final pwd = _pwdCtrl.text.trim();
      await ref.read(webDavConfigProvider.notifier).saveConfig(url, user, pwd);
      await ref.read(settingsProvider.notifier).update((s) => s.copyWith(
        webDavUrl: url,
        webDavUser: user,
        webDavPassword: pwd.isNotEmpty ? pwd : s.webDavPassword,
      ));
      // persist merge policy to backend settings as well
      try {
        await ApiService.updateAppSettings({'sync': {'merge_policy': _mergePolicy}});
      } catch (_) {}
      if (mounted) {
        DialogHelper.showSuccessSnackBar(context, '配置已保存');
      }
    }
  }

  SyncService _getService() {
    return SyncService.fromConfig(ref);
  }

  Future<void> _push() async {
    if (!ref.read(webDavConfigProvider).isValid) {
          AppLogger.warning(logPrefixSettings, 'WebDAV 未配置');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先配置并保存 WebDAV')));
          return;
    }
    setState(() => _isSyncing = true);
    AppLogger.info(logPrefixSettings, '开始触发文件同步 (push)...');
    try {
          final backendOk = await ApiService.checkHealth();
          if (backendOk) {
            // First scan and show pending files without processing
            setState(() {
              _isSyncing = true;
              _showUploadQueue = true;
              _uploadQueue = [];
            });
            try {
              final scanRes = await ApiService.startFileSyncScan();
              if (scanRes['success'] == true) {
                final status = scanRes['status'] as Map<String, dynamic>?;
                final pending = status != null && status['pending_preview'] is List ? (status['pending_preview'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String,dynamic>>[];
                if (mounted) setState(() {
                  _uploadQueue = pending;
                });
                // start polling queue to update statuses
                _startUploadPolling();
                // show list and then proceed to upload
                final confirmed = await DialogHelper.showConfirmDialog(context: context, title: '开始上传', content: '发现 ${_uploadQueue.length} 个要上传的文件，是否开始上传？');
                if (confirmed == true) {
                  final pushFuture = ApiService.startFileSyncPush();
                  _startStatusPolling();
                  final res = await pushFuture;
                  if (res['success'] == true) {
                    if (mounted) DialogHelper.showSuccessSnackBar(context, '后端推送已完成');
                  } else {
                    if (mounted) DialogHelper.showErrorSnackBar(context, '后端推送失败');
                  }
                  _stopStatusPolling();
                }
              } else {
                if (mounted) DialogHelper.showErrorSnackBar(context, '扫描失败');
              }
            } catch (e) {
              if (mounted) DialogHelper.showErrorSnackBar(context, '扫描或上传触发失败: $e');
            } finally {
              if (mounted) setState(() => _isSyncing = false);
            }
          } else {
        // fallback to local file-level incremental sync
        final wcfg = ref.read(webDavConfigProvider);
        if (!wcfg.isValid) {
          if (mounted) DialogHelper.showWarningSnackBar(context, '未配置 WebDAV，无法本地上传');
          return;
        }
        _startStatusPolling();
        final cfg = {
          'url': wcfg.url,
          'username': wcfg.user,
          'password': wcfg.password,
          'remote_path': ''
        };
        try {
          final res = await FileSyncManager.instance.pushAll(cfg);
          if (res['process'] != null && (res['process']['succeeded'] as int) > 0) {
            if (mounted) DialogHelper.showSuccessSnackBar(context, '本地上传已完成');
          } else {
            if (mounted) DialogHelper.showErrorSnackBar(context, '本地上传完成（无文件或全部失败）');
          }
        } catch (e) {
          if (mounted) DialogHelper.showErrorSnackBar(context, '本地上传失败: $e');
        } finally {
          _stopStatusPolling();
        }
      }
    } catch (e, st) {
      AppLogger.error(logPrefixSettings, '推送失败: $e', st);
      if (mounted) DialogHelper.showErrorSnackBar(context, '云端备份失败: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
      AppLogger.info(logPrefixSettings, '上传操作完成');
    }
  }

  Future<void> _pull() async {
    if (!ref.read(webDavConfigProvider).isValid) {
AppLogger.warning(logPrefixSettings, 'WebDAV 未配置');
        DialogHelper.showWarningSnackBar(context, '请先配置并保存 WebDAV');
       return;
    }
    setState(() => _isSyncing = true);
    AppLogger.info(logPrefixSettings, '开始 WebDAV 下载...');
    try {
      final backendOk = await ApiService.checkHealth();
      if (backendOk) {
        // Use server-side file-level pull, then fetch exported JSON and merge locally
        final res = await ApiService.startFileSyncPullWithPolicy(_mergePolicy);
        if (res['success'] == true) {
          // server performed pull and merged according to policy; fetch exported JSON and merge locally
          final exported = await ApiService.exportAllData();
          final SyncDataImported = SyncData.fromJson(exported);
          AppLogger.info(logPrefixSettings, '服务器拉取并合并完成, 开始本地合并...');
          if (mounted) await _mergeData(SyncDataImported);
          AppLogger.info(logPrefixSettings, '拉取下载並合并成功');
          if (mounted) DialogHelper.showSuccessSnackBar(context, '拉取(下载)并合并成功！');
        } else {
          if (mounted) DialogHelper.showErrorSnackBar(context, '后端拉取失败');
        }
      } else {
        // fallback to client-side archive pull
        final service = _getService();
        final data = await service.pullBackup();
        AppLogger.info(logPrefixSettings, '下载完成, 开始合并数据...');
        if (mounted) {
          await _mergeData(data);
        }
        AppLogger.info(logPrefixSettings, '拉取下载並合并成功');
        if (mounted) {
          DialogHelper.showSuccessSnackBar(context, '拉取(下载)并合并成功！');
        }
      }
    } catch (e, st) {
      // 显示更详细的错误信息
      final errorStr = e.toString();
      final fullError = '下载失败: $errorStr\n类型: ${e.runtimeType}\n栈追踪: $st';
      AppLogger.error(logPrefixSettings, fullError, st);
AppLogger.error(logPrefixSettings, '下载失败 - $errorStr');

      AppLogger.error(logPrefixSettings, '下载失败类型: ${e.runtimeType}');

      AppLogger.error(logPrefixSettings, '堆栈跟踪: $st');
      if (mounted) {
        DialogHelper.showErrorSnackBar(context, '云端备份下载失败: $errorStr');
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

  Widget _buildAccountCard() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            const ListTile(
              title: Text('账户管理', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('修改登录用户名或密码'),
              leading: Icon(Icons.person),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _acctUserCtrl,
                    decoration: const InputDecoration(labelText: '用户名'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _acctCurrentPwdCtrl,
                    decoration: const InputDecoration(labelText: '当前密码'),
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _acctNewPwdCtrl,
                    decoration: const InputDecoration(labelText: '新密码（留空则不修改）'),
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _acctConfirmPwdCtrl,
                    decoration: const InputDecoration(labelText: '确认新密码'),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 12),
                  if (_acctError != null) ...[
                    Text(_acctError!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isChangingPassword ? null : _changeAccount,
                      icon: _isChangingPassword
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(_isChangingPassword ? '保存中...' : '保存账户'),
                    ),
                  ),
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
              title: Text('字体设置', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('配置界面显示字体和导出PDF字体'),
              leading: Icon(Icons.font_download),
            ),
            const Divider(),
            // 显示字体
            ListTile(
              title: const Text('显示字体'),
              subtitle: FutureBuilder<String>(
                future: _getFontName(settings.displayFontId),
                builder: (context, snapshot) {
                  return Text(snapshot.data ?? settings.displayFontId);
                },
              ),
              trailing: const Icon(Icons.edit),
              onTap: () => _showFontPickerForField(context, 'displayFontId'),
            ),
            // 字号 和 界面密度 同行显示
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showFontSizePicker(context, settings),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('字号', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('${settings.fontSize.toInt()} sp', style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showDensityPicker(context, settings),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('界面密度', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(_densityLabel(settings.density), style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // PDF 字体标题
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('导出 PDF 字体', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showFontPickerForField(context, 'pdfChineseFontId'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('中文字体', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            FutureBuilder<String>(
                              future: _getFontName(settings.pdfChineseFontId),
                              builder: (context, snapshot) {
                                return Text(snapshot.data ?? settings.pdfChineseFontId, style: const TextStyle(color: Colors.grey));
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showFontPickerForField(context, 'pdfEnglishFontId'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('英文/数字字体', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            FutureBuilder<String>(
                              future: _getFontName(settings.pdfEnglishFontId),
                              builder: (context, snapshot) {
                                return Text(snapshot.data ?? settings.pdfEnglishFontId, style: const TextStyle(color: Colors.grey));
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _densityLabel(String density) {
    switch (density) {
      case 'compact': return '紧凑';
      case 'comfortable': return '舒适';
      case 'expanded': return '宽松';
      default: return '舒适';
    }
  }

  Future<void> _showFontPickerForField(BuildContext context, String fieldKey) async {
    final settings = ref.read(settingsProvider);
    final curId = settings.toJson()[fieldKey] as String? ?? 'default';
    if (!mounted) return;

    final localFonts = await FontManager.getLocalFonts();

    DialogHelper.showCustomDialog<String>(
      context: context,
      title: '选择字体',
      content: SizedBox(
        width: double.maxFinite,
        child: StatefulBuilder(
          builder: (ctx, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFontOption(ctx, FontManager.defaultFontId, FontManager.getFontName(FontManager.defaultFontId), curId),
                if (localFonts.isNotEmpty) ...[
                  const Divider(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.font_download, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('本地字体 (${localFonts.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
                      ],
                    ),
                  ),
                  ...localFonts.map((font) => _buildFontOption(ctx, font.id, font.name, curId)).toList(),
                ],
                const Divider(height: 20),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('添加本地字体文件...'),
                  subtitle: const Text('支持 .ttf 和 .otf 格式'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _importLocalFonts();
                  },
                ),
                if (localFonts.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text('管理本地字体...'),
                    subtitle: const Text('查看或删除已添加的字体'),
                    onTap: () async {
                      Navigator.pop(context);
                      await _manageLocalFonts();
                    },
                  ),
              ],
            );
          },
        ),
      ),
    ).then((selectedId) async {
      if (selectedId != null && selectedId.isNotEmpty) {
        await ref.read(settingsProvider.notifier).update((s) {
          switch (fieldKey) {
            case 'displayFontId': return s.copyWith(displayFontId: selectedId);
            case 'pdfChineseFontId': return s.copyWith(pdfChineseFontId: selectedId);
            case 'pdfEnglishFontId': return s.copyWith(pdfEnglishFontId: selectedId);
            default: return s;
          }
        });
        if (mounted) {
          DialogHelper.showSuccessSnackBar(context, '已应用字体: ${FontManager.getFontName(selectedId)}');
        }
      }
    });
  }

  Future<void> _showFontSizePicker(BuildContext context, AppSettings settings) async {
    double tempSize = settings.fontSize;
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('字号设置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${tempSize.toInt()} sp', style: TextStyle(fontSize: tempSize)),
              const SizedBox(height: 16),
              Slider(
                value: tempSize,
                min: 10,
                max: 24,
                divisions: 14,
                label: '${tempSize.toInt()} sp',
                onChanged: (v) => setDialogState(() => tempSize = v),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('10', style: TextStyle(fontSize: 10)), Text('24', style: TextStyle(fontSize: 24))],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, tempSize), child: const Text('确定')),
          ],
        ),
      ),
    );
    if (result != null) {
      await ref.read(settingsProvider.notifier).update((s) => s.copyWith(fontSize: result));
    }
  }

  Future<void> _showDensityPicker(BuildContext context, AppSettings settings) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('界面密度'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'compact'), child: const Text('紧凑')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'comfortable'), child: const Text('舒适')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'expanded'), child: const Text('宽松')),
        ],
      ),
    );
    if (result != null) {
      await ref.read(settingsProvider.notifier).update((s) => s.copyWith(density: result));
    }
  }

  Future<void> _importLocalFonts() async {
    final fontIds = await FontManager.pickAndSaveCustomFonts();
      if (fontIds.isNotEmpty && mounted) {
      DialogHelper.showSuccessSnackBar(context, '已导入 ${fontIds.length} 个字体文件');
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _showFontPickerForField(context, 'displayFontId');
      }
    }
  }

  Future<void> _manageLocalFonts() async {
    final localFonts = await FontManager.getLocalFonts();
    if (localFonts.isEmpty) {
      if (mounted) DialogHelper.showWarningSnackBar(context, '暂无本地字体文件');
      return;
    }
    await DialogHelper.showCustomDialog<String>(
      context: context,
      title: '管理本地字体',
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: ListView.builder(
          itemCount: localFonts.length,
          itemBuilder: (context, index) {
            final font = localFonts[index];
            return ListTile(
              leading: const Icon(Icons.font_download),
              title: Text(font.name),
              subtitle: Text('${font.fileExtension}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () async {
                  final confirmed = await DialogHelper.showConfirmDialog(
                    context: context,
                    title: '删除字体',
                    content: '确定要删除字体 "${font.name}" 吗？',
                    confirmText: '删除',
                    isDestructive: true,
                  );
                  if (confirmed == true) {
                    await FontManager.removeFont(font.id);
                    if (mounted) {
                      DialogHelper.showSuccessSnackBar(context, '已删除字体: ${font.name}');
                      Navigator.pop(context);
                      _manageLocalFonts();
                    }
                  }
                },
              ),
            );
          },
        ),
      ),
    );
    if (mounted) {
      _showFontPickerForField(context, 'displayFontId');
    }
  }

  Widget _buildFontOption(BuildContext ctx, String id, String name, String curId) {
    return ListTile(
      leading: Icon(curId == id ? Icons.check_circle : Icons.circle_outlined,
               color: curId == id ? Colors.green : Colors.grey),
      title: Text(name),
      subtitle: id == FontManager.defaultFontId ? const Text('系统默认字体') : null,
      onTap: () => Navigator.pop(ctx, id),
    );
  }

  Future<void> _saveLogLevel() async {
    setState(() => _isLoadingLogLevel = true);
    try {
      AppLogger.setLogLevel(_selectedLogLevel);
      await ref.read(settingsProvider.notifier).update((s) => s.copyWith(logLevel: _selectedLogLevel.name));
      if (mounted) {
        DialogHelper.showSuccessSnackBar(context, '日志级别已设置为: ${_selectedLogLevel.name.toUpperCase()}');
      }
    } catch (e) {
      AppLogger.error(logPrefixSettings, '保存日志级别失败: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLogLevel = false);
    }
  }

  Future<void> _clearLogFile() async {
    try {
      if (kIsWeb) {
        try {
          await AppLogger.clearWebLogs();
          if (mounted) DialogHelper.showSuccessSnackBar(context, 'Web日志已清空');
        } catch (e) {
          if (mounted) DialogHelper.showErrorSnackBar(context, '清空日志失败: $e');
        }
        return;
      }
      final logPath = await AppLogger.getConfiguredLogPath();
      if (logPath != null) {
        try {
          await AppLogger.clearLogs();
          if (mounted) DialogHelper.showSuccessSnackBar(context, '日志文件已清空');
        } catch (e) {
          if (mounted) DialogHelper.showErrorSnackBar(context, '清空日志失败: $e');
        }
      } else {
        if (mounted) DialogHelper.showWarningSnackBar(context, '无法获取日志路径');
      }
    } catch (e) {
      if (mounted) DialogHelper.showErrorSnackBar(context, '清空日志文件失败: $e');
    }
  }

  Future<String?> _askConflict(String entityType, String entityName) async {
    return DialogHelper.showCustomDialog<String>(
      context: context,
      title: '发现冲突',
      content: Text('检测到本地已存在 $entityType: "$entityName"。\n请选择如何处理：'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, 'skip'), child: const Text('跳过')),
        TextButton(onPressed: () => Navigator.pop(context, 'skip_all'), child: const Text('全部跳过')),
        TextButton(onPressed: () => Navigator.pop(context, 'overwrite'), child: const Text('覆盖本地')),
        TextButton(onPressed: () => Navigator.pop(context, 'overwrite_all'), child: const Text('全部覆盖')),
      ],
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
                const SizedBox(width: 8),
                // 连接状态指示器
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isBackendConnected ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isBackendConnected ? Colors.green.shade200 : Colors.red.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isCheckingBackend 
                            ? Icons.sync 
                            : (_isBackendConnected ? Icons.check_circle : Icons.error),
                        size: 16,
                        color: _isCheckingBackend 
                            ? Colors.orange 
                            : (_isBackendConnected ? Colors.green : Colors.red),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isCheckingBackend 
                            ? '检查中' 
                            : (_isBackendConnected ? '已连接' : '未连接'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _isCheckingBackend 
                              ? Colors.orange 
                              : (_isBackendConnected ? Colors.green : Colors.red),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (!_isCheckingBackend)
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 16),
                          onPressed: _checkBackendConnection,
                          tooltip: '刷新连接状态',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        ),
                    ],
                  ),
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
                      hintText: '例如: /data/coinscape',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.folder_open),
                      suffixIcon: null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSavingPath ? null : _saveSavePath,
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
DialogHelper.showSuccessSnackBar(context, value ? '已启用后端代理' : '已禁用后端代理');
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
              validator: (v) => null,
            ),
            const SizedBox(height: 12),
            // 合并策略（放在云同步配置中）
            Row(
              children: [
                const Expanded(child: Text('合并策略', style: TextStyle(fontWeight: FontWeight.w500))),
                DropdownButton<String>(
                  value: _mergePolicy,
                  items: const [
                    DropdownMenuItem(value: 'prefer_local', child: Text('保留本地（默认）')),
                    DropdownMenuItem(value: 'prefer_remote', child: Text('以远端为准')),
                    DropdownMenuItem(value: 'merge_fields', child: Text('字段级合并')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _mergePolicy = v);
                  },
                  underline: const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
              LayoutBuilder(builder: (ctx, constraints) {
                final syncBox = Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _buildSyncBoxColor(),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _buildSyncBoxBorderColor(),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSyncBoxIcon(),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_buildSyncBoxLabel(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _buildSyncBoxTextColor())),
                            const SizedBox(height: 6),
                            Text('本地: ${_localLatestTime ?? '未查询'}', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                            Text('云端: ${_cloudLatestTime ?? '未查询'}', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (!_isCheckingBackend && _hasQueriedLatestChange)
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 16),
                          onPressed: _loadLatestChangeInfo,
                          tooltip: '刷新同步状态',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        ),
                    ],
                  ),
                );

                if (constraints.maxWidth < 520) {
                  // narrow layout: stack vertically
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _push, icon: const Icon(Icons.cloud_upload), label: const Text('云端备份 (Push)'), style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColorLight))),
                      const SizedBox(height: 8),
                      syncBox,
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _pull, icon: const Icon(Icons.cloud_download), label: const Text('拉取合并 (Pull)'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade100))),
                    ],
                  );
                }

                // wide layout: buttons + expanded sync box
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _push,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('云端备份 (Push)'),
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColorLight),
                    ),
                    Expanded(child: syncBox),
                    ElevatedButton.icon(
                      onPressed: _pull,
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('拉取合并 (Pull)'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade100),
                    ),
                  ],
                );
              }),
            const SizedBox(height: 12),
            // 显示同步状态（支持后端简要状态与本地详细状态）
            if (_syncStatus != null) ...[
              Builder(builder: (ctx) {
                final counts = _syncStatus!['counts'] ?? _syncStatus!;
                final inProg = _syncStatus!.containsKey('in_progress')
                  ? (_syncStatus!['in_progress'] is List ? (_syncStatus!['in_progress'] as List<dynamic>) : <dynamic>[])
                  : <dynamic>[];
                final failedList = _syncStatus!.containsKey('failed')
                  ? (_syncStatus!['failed'] is List ? (_syncStatus!['failed'] as List<dynamic>) : <dynamic>[])
                  : <dynamic>[];

                return Column(
                  children: [
                    if (_uploadQueue.isNotEmpty) ...[
                      Align(alignment: Alignment.centerLeft, child: Text('待上传文件 (${_uploadQueue.length})', style: TextStyle(fontWeight: FontWeight.w600))),
                      const SizedBox(height: 8),
                      Column(
                        children: _uploadQueue.map<Widget>((e) {
                          final status = (e['status'] ?? 'pending') as String;
                          Icon leading;
                          Widget trailing = const SizedBox.shrink();
                          if (status == 'in-progress' || status == 'in-progress') {
                            leading = Icon(Icons.sync, color: Theme.of(context).colorScheme.primary);
                          } else if (status == 'done') {
                            leading = Icon(Icons.check_circle, color: Colors.green);
                          } else if (status == 'failed') {
                            leading = Icon(Icons.error_outline, color: Colors.red);
                          } else {
                            leading = Icon(Icons.hourglass_top, color: Colors.grey[700]);
                          }
                          final subtitleParts = <String>[];
                          subtitleParts.add('状态: $status');
                          if (e['attempts'] != null) subtitleParts.add('尝试: ${e['attempts']}');
                          if (e['error'] != null && (e['error'] as String).isNotEmpty) subtitleParts.add('错误: ${e['error']}');
                          return ListTile(
                            dense: true,
                            leading: leading,
                            title: Text(e['path'] ?? ''),
                            subtitle: Text(subtitleParts.join(' · '), style: const TextStyle(fontSize: 12)),
                            trailing: trailing,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FilledButton(
                            onPressed: () async {
                              try {
                                setState(() => _isSyncing = true);
                                final res = await ApiService.retryFailedSync();
                                if (res['success'] == true) {
                                  DialogHelper.showSuccessSnackBar(context, '已触发重试');
                                } else {
                                  DialogHelper.showErrorSnackBar(context, '重试请求返回失败');
                                }
                              } catch (e) {
                                DialogHelper.showErrorSnackBar(context, '重试失败: $e');
                              } finally {
                                setState(() => _isSyncing = false);
                                _startUploadPolling();
                              }
                            },
                            child: const Text('重试失败项'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () async {
                              try {
                                final res = await ApiService.retryFailedSync(clear: true);
                                if (res['success'] == true) {
                                  DialogHelper.showSuccessSnackBar(context, '已清理失败记录');
                                  _startUploadPolling();
                                } else {
                                  DialogHelper.showErrorSnackBar(context, '清理失败记录失败');
                                }
                              } catch (e) {
                                DialogHelper.showErrorSnackBar(context, '清理失败: $e');
                              }
                            },
                            child: const Text('清理失败记录'),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Fallback: show current detailed status without count chips
                      if (_isSyncing) const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: LinearProgressIndicator(),
                      ),
                      const SizedBox(height: 8),
                      // 进行中项（展示前3）
                      if (inProg.isNotEmpty) ...[
                        Align(alignment: Alignment.centerLeft, child: Text('进行中任务', style: TextStyle(fontWeight: FontWeight.w600))),
                        const SizedBox(height: 6),
                        Column(
                          children: inProg.take(3).map<Widget>((e) {
                            final item = e as Map<String, dynamic>;
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.sync, size: 18),
                              title: Text(item['path'] ?? ''),
                              subtitle: Text('尝试: ${item['attempts'] ?? 0}'),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 6),
                      ],
                      // 失败项（展示前5，含错误信息）
                      if (failedList.isNotEmpty) ...[
                        Align(alignment: Alignment.centerLeft, child: Text('失败任务', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red[700]))),
                        const SizedBox(height: 6),
                        Column(
                          children: failedList.take(5).map<Widget>((e) {
                            final item = e as Map<String, dynamic>;
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.error_outline, size: 18, color: Colors.red),
                              title: Text(item['path'] ?? ''),
                              subtitle: Text(item['error'] ?? '错误未知', style: const TextStyle(fontSize: 12)),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            FilledButton(
                              onPressed: () async {
                                try {
                                  setState(() => _isSyncing = true);
                                  final res = await ApiService.retryFailedSync();
                                  if (res['success'] == true) {
                                    DialogHelper.showSuccessSnackBar(context, '已触发重试');
                                  } else {
                                    DialogHelper.showErrorSnackBar(context, '重试请求返回失败');
                                  }
                                } catch (e) {
                                  DialogHelper.showErrorSnackBar(context, '重试失败: $e');
                                } finally {
                                  setState(() => _isSyncing = false);
                                  _startStatusPolling();
                                }
                              },
                              child: const Text('重试失败项'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () async {
                                try {
                                  final res = await ApiService.retryFailedSync(clear: true);
                                  if (res['success'] == true) {
                                    DialogHelper.showSuccessSnackBar(context, '已清理失败记录');
                                    _startStatusPolling();
                                  } else {
                                    DialogHelper.showErrorSnackBar(context, '清理失败记录失败');
                                  }
                                } catch (e) {
                                  DialogHelper.showErrorSnackBar(context, '清理失败: $e');
                                }
                              },
                              child: const Text('清理失败记录'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                );
              }),
            ],
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

                // ===== 账户管理 =====
                _buildAccountCard(),

              // ===== 字体设置 =====
              _buildFontSettingsCard(context, settings),

              // ===== WebDAV 云同步配置 =====
              _buildWebDavConfigCard(),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 获取字体名称
  Future<String> _getFontName(String fontId) async {
    await FontManager.getLocalFonts(); // 确保字体列表已加载
    return FontManager.getFontName(fontId);
  }
}
