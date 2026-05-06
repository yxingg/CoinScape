import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'dart:io';

import '../database/database.dart';
import '../models/sync_models.dart';
import '../utils/logger.dart';

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

class SyncService {
  final String url;
  final String user;
  final String password;

  SyncService({
    required this.url,
    required this.user,
    required this.password,
  });

  webdav.Client get client {
    final c = webdav.newClient(
      url,
      user: user,
      password: password,
      debug: kDebugMode,
    );
    // 增加超时时间以处理大文件和网络延迟
    // 特别是对于包含图片的备份文件
    c.setConnectTimeout(15000);  // 连接超时: 15秒
    c.setSendTimeout(30000);     // 上传超时: 30秒
    c.setReceiveTimeout(30000);  // 下载超时: 30秒
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
    final zipData = await generateBackupDataBytes(series, coins, links, coinImages, seriesImages);
    const remotePath = '/latest_backup.ccm';
    AppLogger.info(logPrefixSync, '开始上传 WebDAV 备份到 $remotePath, 大小: ${zipData.length} bytes');
    try {
      AppLogger.debug(logPrefixSync, '执行 WebDAV write: $remotePath');
      await c.write(remotePath, zipData);

      AppLogger.debug(logPrefixSync, '写入完成，开始校验远端文件是否存在');
      final remoteFile = await c.readProps(remotePath);
      AppLogger.info(logPrefixSync, '远端文件校验成功: ${remoteFile.path}');
    } catch (e, st) {
      AppLogger.error(logPrefixSync, 'WebDAV 上传失败: $e', st);
      rethrow;
    }
  }

  Future<SyncData> pullBackup() async {
    final c = client;
    const remotePath = '/latest_backup.ccm';
    AppLogger.info(logPrefixSync, '开始从 WebDAV 下载备份: $remotePath');
    
    List<int>? bytes;
    try {
      // Download into memory byte array
      bytes = await c.read(remotePath);
      AppLogger.info(logPrefixSync, '备份下载完成, 字节数: ${bytes.length}');
    } catch (e, st) {
      AppLogger.error(logPrefixSync, 'WebDAV 下载失败: $e', st);
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