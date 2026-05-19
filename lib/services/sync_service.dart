import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';

import '../database/database.dart';
import '../models/sync_models.dart';
import '../utils/logger.dart';
import '../utils/url_helper.dart';
import '../services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sync_providers.dart';

Future<Uint8List> generateBackupDataBytes(
  List<SeriesData> series,
  List<Coin> coins,
  List<CoinSeriesLinkData> links,
  List<CoinImage> coinImages,
  List<SeriesImage> seriesImages,
) async {
  AppLogger.info(logPrefixSync, '开始生成备份数据: series=${series.length}, coins=${coins.length}, links=${links.length}, coinImages=${coinImages.length}, seriesImages=${seriesImages.length}');

  // 1. Prepare JSON payload
  final data = SyncData(
    series: series.map((s) => s.toJson()).toList(),
    coins: coins.map((c) => c.toJson()).toList(),
    links: links.map((l) => l.toJson()).toList(),
    coinImages: coinImages.map((i) => i.toJson()).toList(),
    seriesImages: seriesImages.map((i) => i.toJson()).toList(),
  );
  final jsonStr = jsonEncode(data.toJson());
  
  // 2. Create Archive
  final archive = Archive();
  
  // Add json file to archive
  final jsonBytes = utf8.encode(jsonStr);
  archive.addFile(ArchiveFile('db.json', jsonBytes.length, jsonBytes));
  
  if (!kIsWeb) {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/images');
    if (await imagesDir.exists()) {
      final coinImagePaths = coins.map((c) => c.firstImagePath).where((p) => p != null && p.isNotEmpty).toSet();
      
      final list = imagesDir.listSync(recursive: true);
      for (var entity in list) {
        if (entity is File) {
          final name = 'images/${entity.path.split(Platform.pathSeparator).last.split('/').last}';
          if (coinImagePaths.contains(entity.path) || coins.length > coinImagePaths.length) {
             final bytes = await entity.readAsBytes();
             archive.addFile(ArchiveFile(name, bytes.length, bytes));
          }
        }
      }
    }
  }
  
  // 3. Zip Encoder
  final encoder = ZipEncoder();
  final zipList = encoder.encode(archive);
  final result = Uint8List.fromList(zipList);
  AppLogger.info(logPrefixSync, '备份包生成完成, 大小: ${result.length} bytes');
  return result;
}

/// WebDAV同步服务，支持后端代理解决Flutter Web跨域问题
class SyncService {
  final String rawUrl;
  final String user;
  final String password;
  final bool useProxy;
  
  /// 内部使用的最终URL（可能是原始URL或代理URL）
  late final String _finalUrl;

  SyncService({
    required this.rawUrl,
    required this.user,
    required this.password,
    bool? useProxy,
    String? backendBaseUrl,
  }) : useProxy = useProxy ?? false {
    // 在构造时确定最终URL
    _finalUrl = _determineFinalUrl(
      rawUrl: rawUrl,
      user: user,
      password: password,
      useProxy: useProxy ?? false,
      backendBaseUrl: backendBaseUrl,
    );
  }

  /// 工厂方法，从Provider获取配置创建服务
  factory SyncService.fromConfig(WidgetRef ref) {
    final config = ref.read(webDavConfigProvider);
    final backendBaseUrl = ApiService.baseUrl;
    
    return SyncService(
      rawUrl: config.url,
      user: config.user,
      password: config.password,
      useProxy: config.proxyEnabled,
      backendBaseUrl: backendBaseUrl,
    );
  }

  /// 确定最终URL：如果是Web环境且启用了代理，则使用代理URL
  String _determineFinalUrl({
    required String rawUrl,
    required String user,
    required String password,
    required bool useProxy,
    String? backendBaseUrl,
  }) {
    if (kIsWeb && useProxy && backendBaseUrl != null && backendBaseUrl.isNotEmpty) {
      // Web环境下使用代理
      final proxyUrl = UrlHelper.rewriteWebDavUrlForWeb(
        rawUrl,
        backendBaseUrl,
        useProxy,
        username: user,
        password: password,
      );
      AppLogger.debug(logPrefixSync, 'Web环境下使用代理URL: $proxyUrl (原始URL: $rawUrl)');
      return proxyUrl ?? rawUrl;
    }
    
    // 非Web环境或未启用代理，使用原始URL
    return UrlHelper.normalizeWebDavUrl(rawUrl);
  }

  webdav.Client get client {
    AppLogger.debug(logPrefixSync, '创建WebDAV客户端: url=$_finalUrl, user=${user.isNotEmpty ? '[已设置]' : '[未设置]'}, useProxy=$useProxy');
    
    // 在Web环境下使用代理时，认证信息已经包含在URL中了
    // 所以不要再次设置用户名和密码，否则会导致重复认证或冲突
    final shouldSetAuth = !(kIsWeb && useProxy);
    
    final c = webdav.newClient(
      _finalUrl,
      user: shouldSetAuth ? user : '',  // Web代理模式下不设置用户
      password: shouldSetAuth ? password : '',  // Web代理模式下不设置密码
      debug: kDebugMode,
    );
    
    // 增加超时时间以处理大文件和网络延迟
    // 特别是对于包含图片的备份文件
    c.setConnectTimeout(15000);  // 连接超时: 15秒
    c.setSendTimeout(30000);     // 上传超时: 30秒
    c.setReceiveTimeout(30000);  // 下载超时: 30秒
    
    AppLogger.debug(logPrefixSync, 'WebDAV客户端创建完成，超时设置: connect=15000, send=30000, receive=30000');
    return c;
  }

  Future<void> pushBackup(
    List<SeriesData> series,
    List<Coin> coins,
    List<CoinSeriesLinkData> links,
    List<CoinImage> coinImages,
    List<SeriesImage> seriesImages,
  ) async {
    final c = client;
    AppLogger.info(logPrefixSync, '尝试连接到 WebDAV 服务器: $_finalUrl');
    AppLogger.debug(logPrefixSync, '尝试连接到 WebDAV 服务器: $_finalUrl');
    
    try {
      // 先尝试连接和验证
      AppLogger.debug(logPrefixSync, '验证 WebDAV 连接...');
      await c.readProps('/');
      AppLogger.info(logPrefixSync, 'WebDAV 连接验证成功');
    } catch (e, st) {
      AppLogger.error(logPrefixSync, 'WebDAV 连接验证失败: $e', st);
      rethrow;
    }
    
    final zipData = await generateBackupDataBytes(series, coins, links, coinImages, seriesImages);
    const remotePath = '/latest_backup.ccm';
    AppLogger.info(logPrefixSync, '开始上传 WebDAV 备份到 $remotePath, 大小: ${zipData.length} bytes');
    
    try {
      AppLogger.debug(logPrefixSync, '执行 WebDAV write: $remotePath');
      await c.write(remotePath, zipData);

      AppLogger.debug(logPrefixSync, '写入完成，开始校验远端文件是否存在');
      final remoteFile = await c.readProps(remotePath);
      AppLogger.info(logPrefixSync, '远端文件校验成功: ${remoteFile.path}');
      // 尝试写入远端备份标记，便于其他设备判断最新备份
      try {
        final prefs = await SharedPreferences.getInstance();
        var deviceId = prefs.getString('sync.device_id');
        if (deviceId == null || deviceId.isEmpty) {
          deviceId = Uuid().v4();
          await prefs.setString('sync.device_id', deviceId);
        }
        final payload = {
          'timestamp': DateTime.now().toIso8601String(),
          'device_id': deviceId,
          'user': prefs.getString('auth.username')
        };
        final sorted = Map.fromEntries(payload.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
        final checksum = sha256.convert(utf8.encode(jsonEncode(sorted))).toString();
        payload['checksum'] = checksum;
        final metaPath = '/.coinscape/last_cloud_backup.txt';
        try {
          await c.write(metaPath, utf8.encode(jsonEncode(payload)));
          AppLogger.info(logPrefixSync, '写入远端备份标记成功: $metaPath');
        } catch (e) {
          AppLogger.warning(logPrefixSync, '写入远端备份标记失败: $e');
        }
      } catch (e) {
        AppLogger.warning(logPrefixSync, '准备远端备份标记失败: $e');
      }
    } catch (e, st) {
      // 检查错误类型以提供更有用的信息
      final errorMessage = e.toString().toLowerCase();
      String detailedMessage = 'WebDAV 上传失败: $e';
      
      if (errorMessage.contains('connection') || errorMessage.contains('timeout')) {
        detailedMessage = '网络连接失败或超时: $e';
      } else if (errorMessage.contains('auth') || errorMessage.contains('401') || errorMessage.contains('403')) {
        detailedMessage = '身份验证失败（用户名或密码错误）: $e';
      } else if (errorMessage.contains('not found') || errorMessage.contains('404')) {
        detailedMessage = '服务器路径不存在: $e';
      } else if (errorMessage.contains('no such host')) {
        detailedMessage = '无法解析服务器地址: $e';
      }
      
      AppLogger.error(logPrefixSync, detailedMessage, st);
      rethrow;
    }
  }

  Future<SyncData> pullBackup() async {
    final c = client;
    AppLogger.info(logPrefixSync, '尝试连接到 WebDAV 服务器: $_finalUrl');
    AppLogger.debug(logPrefixSync, '尝试连接到 WebDAV 服务器: $_finalUrl');
    
    try {
      // 先尝试连接和验证
      AppLogger.debug(logPrefixSync, '验证 WebDAV 连接...');
      await c.readProps('/');
      AppLogger.info(logPrefixSync, 'WebDAV 连接验证成功');
    } catch (e, st) {
      AppLogger.error(logPrefixSync, 'WebDAV 连接验证失败: $e', st);
      rethrow;
    }
    
    const remotePath = '/latest_backup.ccm';
    AppLogger.info(logPrefixSync, '开始从 WebDAV 下载备份: $remotePath');
    
    List<int>? bytes;
    try {
      // Download into memory byte array
      AppLogger.debug(logPrefixSync, '执行 WebDAV read: $remotePath');
      bytes = await c.read(remotePath);
      AppLogger.info(logPrefixSync, '备份下载完成, 字节数: ${bytes.length}');
    } catch (e, st) {
      // 检查错误类型以提供更有用的信息
      final errorMessage = e.toString().toLowerCase();
      String detailedMessage = 'WebDAV 下载失败: $e';
      
      if (errorMessage.contains('connection') || errorMessage.contains('timeout')) {
        detailedMessage = '网络连接失败或超时: $e';
      } else if (errorMessage.contains('auth') || errorMessage.contains('401') || errorMessage.contains('403')) {
        detailedMessage = '身份验证失败（用户名或密码错误）: $e';
      } else if (errorMessage.contains('not found') || errorMessage.contains('404')) {
        detailedMessage = '备份文件不存在: $e';
      } else if (errorMessage.contains('no such host')) {
        detailedMessage = '无法解析服务器地址: $e';
      }
      
      AppLogger.error(logPrefixSync, detailedMessage, st);
      rethrow;
    }
    
    if (bytes.isEmpty) {
      throw Exception('下载的备份文件为空');
    }
    
    // Decode zip
    final archive = ZipDecoder().decodeBytes(Uint8List.fromList(bytes));
    AppLogger.debug(logPrefixSync, '备份压缩包解压完成, 条目数: ${archive.length}');
    
    SyncData? syncData;
    var restoredImageCount = 0;
    
    for (final archiveFile in archive) {
      if (archiveFile.name == 'db.json') {
        final content = utf8.decode(archiveFile.content as List<int>);
        syncData = SyncData.fromJson(jsonDecode(content));
      } else if (!kIsWeb && archiveFile.name.startsWith('images/')) {
         final appDir = await getApplicationDocumentsDirectory();
         final imgPath = '${appDir.path}/${archiveFile.name}';
         final imgFile = File(imgPath);
         if (!await imgFile.exists()) {
           await imgFile.create(recursive: true);
         }
         await imgFile.writeAsBytes(archiveFile.content as List<int>);
         restoredImageCount++;
      }
    }
    
    if (syncData == null) throw Exception("Invalid backup file: db.json is missing.");
    AppLogger.info(logPrefixSync, '下载数据合并准备完成, 恢复图片数量: $restoredImageCount');
    
    return syncData;
  }
}