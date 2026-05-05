import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'dart:io';

import '../database/database.dart';
import '../models/sync_models.dart';

Future<Uint8List> generateBackupDataBytes(
  List<SeriesData> series,
  List<Coin> coins,
  List<CoinSeriesLinkData> links,
  List<CoinImage> coinImages,
  List<SeriesImage> seriesImages,
) async {
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
  return Uint8List.fromList(zipList);
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
    // Ignore self-signed certs for webdav connection if needed
    c.setConnectTimeout(8000);
    c.setSendTimeout(8000);
    c.setReceiveTimeout(8000);
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
    await c.write('/latest_backup.ccm', zipData);
  }

  Future<SyncData> pullBackup() async {
    final c = client;
    
    // Download into memory byte array
    final bytes = await c.read('/latest_backup.ccm');
    
    // Decode zip
    final archive = ZipDecoder().decodeBytes(bytes);
    
    SyncData? syncData;
    
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
      }
    }
    
    if (syncData == null) throw Exception("Invalid backup file: db.json is missing.");
    
    return syncData;
  }
}