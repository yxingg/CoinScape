import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import '../services/api_service.dart';

/// 数据仓库 - 根据平台选择数据源
/// Web 端：通过 HTTP API 调用 Python 后端
/// 原生端：使用 Drift 本地数据库
class CoinRepository {
  final AppDatabase? _db;

  CoinRepository(this._db);

  /// Record local data change timestamp for sync status tracking
  Future<void> _markLocalChange() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sync.last_local_change', DateTime.now().toUtc().toIso8601String());
    } catch (_) {}
  }

  bool get _useApi => kIsWeb;

  AppDatabase get db {
    if (_db == null) throw UnsupportedError('Database not available on web platform');
    return _db;
  }

  // ==========================================
  // Series (系列) 相关操作
  // ==========================================

  /// 获取所有系列列表（非响应式，用于 Web API 模式）
  Future<List<SeriesData>> getAllSeries() async {
    if (_useApi) {
      final list = await ApiService.getSeriesList();
      return list.map((e) => SeriesData(
        id: e['id'] as String,
        name: e['name'] as String,
        description: e['description'] as String?,
        createdAt: DateTime.parse(e['created_at'] as String),
      )).toList();
    }
    return db.select(db.series).get();
  }

  /// 监听所有系列（响应式数据流，仅原生端支持）
  Stream<List<SeriesData>> watchAllSeries() {
    if (_useApi) {
      // Web 端不支持响应式流，使用周期性轮询
      return Stream.periodic(const Duration(seconds: 2), (_) => null)
          .asyncMap((_) => getAllSeries())
          .asBroadcastStream();
    }
    return (db.select(db.series)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  /// 添加一个新系列
  Future<String> insertSeries(SeriesCompanion series) async {
    if (_useApi) {
      final data = <String, dynamic>{
        'id': series.id.value,
        'name': series.name.value,
        'description': series.description.value,
        'created_at': (series.createdAt.value).toIso8601String(),
      };
      return await ApiService.createSeries(data);
    }
    await db.into(db.series).insert(series, mode: InsertMode.insertOrReplace);
    await _markLocalChange();
    return series.id.value;
  }

  /// 修改系列信息
  Future<bool> updateSeries(SeriesCompanion series) async {
    if (_useApi) {
      final data = <String, dynamic>{
        'name': series.name.value,
        'description': series.description.value,
        'created_at': (series.createdAt.value).toIso8601String(),
      };
      await ApiService.updateSeries(series.id.value, data);
      return true;
    }
    final r = await db.update(db.series).replace(series);
    await _markLocalChange();
    return r;
  }

  /// 删除系列
  Future<void> deleteSeries(String seriesId) async {
    if (_useApi) {
      return ApiService.deleteSeries(seriesId);
    }
    // Collect series image paths first
    final rows = await (db.select(db.seriesImages)..where((t) => t.seriesId.equals(seriesId))).get();
    final imagePaths = rows.map((r) => r.imagePath).whereType<String>().toSet().toList();

    // Delete DB records
    await db.transaction(() async {
      await (db.delete(db.coinSeriesLink)..where((t) => t.seriesId.equals(seriesId))).go();
      await (db.delete(db.seriesImages)..where((t) => t.seriesId.equals(seriesId))).go();
      await (db.delete(db.series)..where((t) => t.id.equals(seriesId))).go();
    });
    await _markLocalChange();

    // Best-effort: delete local files that are no longer referenced
    try {
      final dir = await getApplicationDocumentsDirectory();
      for (final rel in imagePaths) {
        final file = File(p.join(dir.path, rel.replaceAll('/', p.separator)));

        // check remaining references
        final otherCoinImgs = await (db.select(db.coinImages)..where((t) => t.imagePath.equals(rel))).get();
        final otherSeriesImgs = await (db.select(db.seriesImages)..where((t) => t.imagePath.equals(rel))).get();
        final otherFirst = await (db.select(db.coins)..where((t) => t.firstImagePath.equals(rel))).get();

        if (otherCoinImgs.isEmpty && otherSeriesImgs.isEmpty && otherFirst.isEmpty) {
          try {
            if (await file.exists()) await file.delete();
            // remove thumbnail cache if present
            final cacheDir = Directory(p.join(dir.path, 'images', '.thumb_cache'));
            if (await cacheDir.exists()) {
              final base = p.basenameWithoutExtension(file.path);
              for (final f in cacheDir.listSync()) {
                final name = p.basename(f.path);
                if (name.startsWith('${base}_') || name.startsWith(base)) {
                  try {
                    File(f.path).deleteSync();
                  } catch (_) {}
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// 批量删除系列
  Future<void> deleteSeriesBatch(List<String> seriesIds) async {
    if (_useApi) {
      return ApiService.deleteSeriesBatch(seriesIds);
    }
    // collect image paths for all series
    final imagePaths = <String>{};
    for (final seriesId in seriesIds) {
      final rows = await (db.select(db.seriesImages)..where((t) => t.seriesId.equals(seriesId))).get();
      imagePaths.addAll(rows.map((r) => r.imagePath).whereType<String>());
    }

    await db.transaction(() async {
      for (final seriesId in seriesIds) {
        await (db.delete(db.coinSeriesLink)..where((t) => t.seriesId.equals(seriesId))).go();
        await (db.delete(db.seriesImages)..where((t) => t.seriesId.equals(seriesId))).go();
        await (db.delete(db.series)..where((t) => t.id.equals(seriesId))).go();
      }
    });
    await _markLocalChange();

    // cleanup files
    try {
      final dir = await getApplicationDocumentsDirectory();
      for (final rel in imagePaths) {
        final file = File(p.join(dir.path, rel.replaceAll('/', p.separator)));
        final otherCoinImgs = await (db.select(db.coinImages)..where((t) => t.imagePath.equals(rel))).get();
        final otherSeriesImgs = await (db.select(db.seriesImages)..where((t) => t.imagePath.equals(rel))).get();
        final otherFirst = await (db.select(db.coins)..where((t) => t.firstImagePath.equals(rel))).get();
        if (otherCoinImgs.isEmpty && otherSeriesImgs.isEmpty && otherFirst.isEmpty) {
          try {
            if (await file.exists()) await file.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  // ==========================================
  // Coin (纪念币) 相关操作
  // ==========================================

  /// 获取指定系列下的所有纪念币
  Future<List<Coin>> getCoinsBySeries(String seriesId) async {
    if (_useApi) {
      final list = await ApiService.getCoinsList(seriesId: seriesId);
      return list.map((e) => _coinFromJson(e)).toList();
    }
    final query = db.select(db.coins).join([
      innerJoin(
        db.coinSeriesLink,
        db.coinSeriesLink.coinId.equalsExp(db.coins.id),
      )
    ])
      ..where(db.coinSeriesLink.seriesId.equals(seriesId));

    _applyCoinOrderBy(query);

    return query.map((row) => row.readTable(db.coins)).get();
  }

  /// 获取所有纪念币
  Future<List<Coin>> getAllCoins() async {
    if (_useApi) {
      final list = await ApiService.getCoinsList();
      return list.map((e) => _coinFromJson(e)).toList();
    }
    return (db.select(db.coins)
          ..orderBy([
            (t) => OrderingTerm(expression: t.collectionTime, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// 监听指定系列下的所有纪念币（响应式，仅原生端）
  Stream<List<Coin>> watchCoinsBySeries(String seriesId) {
    if (_useApi) {
      return Stream.periodic(const Duration(seconds: 2), (_) => null)
          .asyncMap((_) => getCoinsBySeries(seriesId))
          .asBroadcastStream();
    }
    final query = db.select(db.coins).join([
      innerJoin(
        db.coinSeriesLink,
        db.coinSeriesLink.coinId.equalsExp(db.coins.id),
      )
    ])
      ..where(db.coinSeriesLink.seriesId.equals(seriesId));

    _applyCoinOrderBy(query);

    return query.map((row) => row.readTable(db.coins)).watch();
  }

  /// 监听所有纪念币（响应式，仅原生端）
  Stream<List<Coin>> watchAllCoins() {
    if (_useApi) {
      return Stream.periodic(const Duration(seconds: 2), (_) => null)
          .asyncMap((_) => getAllCoins())
          .asBroadcastStream();
    }
    return (db.select(db.coins)
          ..orderBy([
            (t) => OrderingTerm(expression: t.collectionTime, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// 添加新纪念币
  Future<String> insertCoin(CoinsCompanion coin) async {
    if (_useApi) {
      final data = _coinCompanionToJson(coin);
      return await ApiService.createCoin(data);
    }
    await db.into(db.coins).insert(coin, mode: InsertMode.insertOrReplace);
    await _markLocalChange();
    return coin.id.value;
  }

  /// 修改纪念币
  Future<bool> updateCoin(CoinsCompanion coin) async {
    if (_useApi) {
      final data = _coinCompanionToJson(coin);
      await ApiService.updateCoin(coin.id.value, data);
      return true;
    }
    final r = await db.update(db.coins).replace(coin);
    await _markLocalChange();
    return r;
  }

  /// 删除纪念币
  Future<void> deleteCoin(String coinId) async {
    if (_useApi) {
      return ApiService.deleteCoin(coinId);
    }
    // collect image paths
    final rows = await (db.select(db.coinImages)..where((t) => t.coinId.equals(coinId))).get();
    final imagePaths = rows.map((r) => r.imagePath).whereType<String>().toSet().toList();
    final coinRow = await (db.select(db.coins)..where((t) => t.id.equals(coinId))).getSingleOrNull();
    if (coinRow != null && coinRow.firstImagePath != null) imagePaths.add(coinRow.firstImagePath!);

    await db.transaction(() async {
      await (db.delete(db.coinImages)..where((t) => t.coinId.equals(coinId))).go();
      await (db.delete(db.coinSeriesLink)..where((t) => t.coinId.equals(coinId))).go();
      await (db.delete(db.coins)..where((t) => t.id.equals(coinId))).go();
    });
    await _markLocalChange();

    // cleanup files
    try {
      final dir = await getApplicationDocumentsDirectory();
      for (final rel in imagePaths) {
        final file = File(p.join(dir.path, rel.replaceAll('/', p.separator)));
        final otherCoinImgs = await (db.select(db.coinImages)..where((t) => t.imagePath.equals(rel))).get();
        final otherSeriesImgs = await (db.select(db.seriesImages)..where((t) => t.imagePath.equals(rel))).get();
        final otherFirst = await (db.select(db.coins)..where((t) => t.firstImagePath.equals(rel))).get();
        if (otherCoinImgs.isEmpty && otherSeriesImgs.isEmpty && otherFirst.isEmpty) {
          try {
            if (await file.exists()) await file.delete();
            final cacheDir = Directory(p.join(dir.path, 'images', '.thumb_cache'));
            if (await cacheDir.exists()) {
              final base = p.basenameWithoutExtension(file.path);
              for (final f in cacheDir.listSync()) {
                final name = p.basename(f.path);
                if (name.startsWith('${base}_') || name.startsWith(base)) {
                  try {
                    File(f.path).deleteSync();
                  } catch (_) {}
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// 批量删除纪念币
  Future<void> deleteCoinsBatch(List<String> coinIds) async {
    if (_useApi) {
      return ApiService.deleteCoinsBatch(coinIds);
    }
    // collect image paths for all coins
    final imagePaths = <String>{};
    for (final coinId in coinIds) {
      final rows = await (db.select(db.coinImages)..where((t) => t.coinId.equals(coinId))).get();
      imagePaths.addAll(rows.map((r) => r.imagePath).whereType<String>());
      final coinRow = await (db.select(db.coins)..where((t) => t.id.equals(coinId))).getSingleOrNull();
      if (coinRow != null && coinRow.firstImagePath != null) imagePaths.add(coinRow.firstImagePath!);
    }

    await db.transaction(() async {
      for (final coinId in coinIds) {
        await (db.delete(db.coinImages)..where((t) => t.coinId.equals(coinId))).go();
        await (db.delete(db.coinSeriesLink)..where((t) => t.coinId.equals(coinId))).go();
        await (db.delete(db.coins)..where((t) => t.id.equals(coinId))).go();
      }
    });
    await _markLocalChange();

    try {
      final dir = await getApplicationDocumentsDirectory();
      for (final rel in imagePaths) {
        final file = File(p.join(dir.path, rel.replaceAll('/', p.separator)));
        final otherCoinImgs = await (db.select(db.coinImages)..where((t) => t.imagePath.equals(rel))).get();
        final otherSeriesImgs = await (db.select(db.seriesImages)..where((t) => t.imagePath.equals(rel))).get();
        final otherFirst = await (db.select(db.coins)..where((t) => t.firstImagePath.equals(rel))).get();
        if (otherCoinImgs.isEmpty && otherSeriesImgs.isEmpty && otherFirst.isEmpty) {
          try {
            if (await file.exists()) await file.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  // ==========================================
  // CoinSeriesLink (多对多映射) 相关操作
  // ==========================================

  /// 为某个纪念币绑定一个系列
  Future<void> linkCoinToSeries(String coinId, String seriesId) async {
    if (_useApi) {
      return ApiService.linkCoinToSeries(coinId, seriesId);
    }
    await db.into(db.coinSeriesLink).insert(
      CoinSeriesLinkCompanion.insert(coinId: coinId, seriesId: seriesId),
      mode: InsertMode.insertOrIgnore,
    );
    await _markLocalChange();
  }

  /// 解除某个纪念币和系列的绑定
  Future<void> unlinkCoinFromSeries(String coinId, String seriesId) async {
    if (_useApi) {
      return ApiService.unlinkCoinFromSeries(coinId, seriesId);
    }
    await (db.delete(db.coinSeriesLink)
          ..where((t) => t.coinId.equals(coinId) & t.seriesId.equals(seriesId)))
        .go();
    await _markLocalChange();
  }

  Future<List<String>> getSeriesIdsForCoin(String coinId) async {
    if (_useApi) {
      return ApiService.getSeriesIdsForCoin(coinId);
    }
    final rows = await (db.select(db.coinSeriesLink)..where((t) => t.coinId.equals(coinId))).get();
    return rows.map((e) => e.seriesId).toList();
  }

  Future<void> setCoinSeriesTags(String coinId, List<String> seriesIds) async {
    if (_useApi) {
      return ApiService.setCoinSeriesTags(coinId, seriesIds);
    }
    await db.transaction(() async {
      await (db.delete(db.coinSeriesLink)..where((t) => t.coinId.equals(coinId))).go();
      for (final sid in seriesIds) {
        await db.into(db.coinSeriesLink).insert(
              CoinSeriesLinkCompanion.insert(coinId: coinId, seriesId: sid),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
    await _markLocalChange();
  }

  /// 批量将多个纪念币添加到多个系列
  Future<void> addCoinsToSeries(List<String> coinIds, List<String> seriesIds) async {
    if (_useApi) {
      return ApiService.addCoinsToSeries(coinIds, seriesIds);
    }
    await db.transaction(() async {
      for (final coinId in coinIds) {
        for (final seriesId in seriesIds) {
          await db.into(db.coinSeriesLink).insert(
                CoinSeriesLinkCompanion.insert(coinId: coinId, seriesId: seriesId),
                mode: InsertMode.insertOrIgnore,
              );
        }
      }
    });
    await _markLocalChange();
  }

  /// 批量将多个纪念币从所有系列中移除
  Future<void> removeCoinsFromAllSeries(List<String> coinIds) async {
    if (_useApi) {
      return ApiService.removeCoinsFromAllSeries(coinIds);
    }
    await db.transaction(() async {
      for (final coinId in coinIds) {
        await (db.delete(db.coinSeriesLink)..where((t) => t.coinId.equals(coinId))).go();
      }
    });
    await _markLocalChange();
  }

  // ==========================================
  // Images 相关操作
  // ==========================================

  Future<List<CoinImage>> getCoinImages(String coinId) async {
    if (_useApi) {
      final list = await ApiService.getCoinImages(coinId);
      return list.map((e) => CoinImage(
        id: e['id'] as String,
        coinId: e['coin_id'] as String,
        imagePath: e['image_path'] as String,
        sortOrder: e['sort_order'] as int? ?? 0,
      )).toList();
    }
    return (db.select(db.coinImages)
          ..where((t) => t.coinId.equals(coinId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  Future<void> replaceCoinImages(String coinId, List<String> imagePaths) async {
    if (_useApi) {
      return ApiService.replaceCoinImages(coinId, imagePaths);
    }
    await db.transaction(() async {
      await (db.delete(db.coinImages)..where((t) => t.coinId.equals(coinId))).go();
      for (var i = 0; i < imagePaths.length; i++) {
        await db.into(db.coinImages).insert(
              CoinImagesCompanion.insert(
                id: 'coin_img_${coinId}_$i',
                coinId: coinId,
                imagePath: imagePaths[i],
                sortOrder: Value(i),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
      await (db.update(db.coins)..where((t) => t.id.equals(coinId))).write(
        CoinsCompanion(
          firstImagePath: Value(imagePaths.isNotEmpty ? imagePaths.first : null),
        ),
      );
    });
  }

  Future<List<SeriesImage>> getSeriesImages(String seriesId) async {
    if (_useApi) {
      final list = await ApiService.getSeriesImages(seriesId);
      return list.map((e) => SeriesImage(
        id: e['id'] as String,
        seriesId: e['series_id'] as String,
        imagePath: e['image_path'] as String,
        sortOrder: e['sort_order'] as int? ?? 0,
      )).toList();
    }
    return (db.select(db.seriesImages)
          ..where((t) => t.seriesId.equals(seriesId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  Future<String?> getSeriesCoverImagePath(String seriesId) async {
    final images = await getSeriesImages(seriesId);
    return images.isNotEmpty ? images.first.imagePath : null;
  }

  Future<void> replaceSeriesImages(String seriesId, List<String> imagePaths) async {
    if (_useApi) {
      return ApiService.replaceSeriesImages(seriesId, imagePaths);
    }
    await db.transaction(() async {
      await (db.delete(db.seriesImages)..where((t) => t.seriesId.equals(seriesId))).go();
      for (var i = 0; i < imagePaths.length; i++) {
        await db.into(db.seriesImages).insert(
              SeriesImagesCompanion.insert(
                id: 'series_img_${seriesId}_$i',
                seriesId: seriesId,
                imagePath: imagePaths[i],
                sortOrder: Value(i),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  // ==========================================
  // 辅助方法
  // ==========================================

  /// 排序辅助：返回适用于 `query.orderBy(...)` 的排序函数列表
  List<OrderingTerm Function(dynamic)> _coinOrderByTerms() {
    return [
      (t) => OrderingTerm(
            expression: db.coins.collectionTime,
            mode: OrderingMode.desc,
          ),
      (t) => OrderingTerm(
            expression: db.coins.createdAt,
            mode: OrderingMode.desc,
          ),
    ];
  }

  void _applyCoinOrderBy(dynamic query) {
    // Drift 要求将排序条件以 List<OrderingTerm Function(Table)> 传入 orderBy
    // 例如: query.orderBy([(t) => OrderingTerm(...), ...]);
    try {
      query.orderBy(_coinOrderByTerms());
    } catch (e) {
      // 如果由于动态类型导致失败，尝试以兼容方式调用（保守降级）
      try {
        final terms = _coinOrderByTerms().map((f) => f.call(db.coins)).toList();
        // 有些 query 实现可能接受直接的 OrderingTerm 列表
        query.orderBy(terms);
      } catch (_) {
        // 最后兜底：忽略排序，避免因排序失败导致整体崩溃
      }
    }
  }

  /// 将 API 返回的 JSON 转为 Coin 对象
  Coin _coinFromJson(Map<String, dynamic> e) {
    return Coin(
      id: e['id'] as String,
      name: e['name'] as String,
      year: e['year'] as int?,
      faceValue: (e['face_value'] as num?)?.toDouble(),
      material: e['material'] as String?,
      weight: (e['weight'] as num?)?.toDouble(),
      diameter: (e['diameter'] as num?)?.toDouble(),
      mintage: e['mintage'] as String?,
      mint: e['mint'] as String?,
      grade: e['grade'] as String?,
      unitPrice: (e['unit_price'] as num?)?.toDouble(),
      quantity: e['quantity'] as int?,
      quantityUnit: e['quantity_unit'] as String?,
      collectionTime: e['collection_time'] != null ? DateTime.parse(e['collection_time'] as String) : null,
      createdAt: DateTime.parse(e['created_at'] as String),
      comments: e['comments'] as String?,
      firstImagePath: e['first_image_path'] as String?,
    );
  }

  /// 将 CoinsCompanion 转为 JSON
  Map<String, dynamic> _coinCompanionToJson(CoinsCompanion c) {
    return {
      'id': c.id.value,
      'name': c.name.value,
      'year': c.year.value,
      'face_value': c.faceValue.value,
      'material': c.material.value,
      'weight': c.weight.value,
      'diameter': c.diameter.value,
      'mintage': c.mintage.value,
      'mint': c.mint.value,
      'grade': c.grade.value,
      'unit_price': c.unitPrice.value,
      'quantity': c.quantity.value,
      'quantity_unit': c.quantityUnit.value,
      'collection_time': c.collectionTime.value?.toIso8601String(),
      'created_at': c.createdAt.value.toIso8601String(),
      'comments': c.comments.value,
      'first_image_path': c.firstImagePath.value,
    };
  }

  // ==========================================
  // 存储清理
  // ==========================================

  /// 清理无引用的孤立图片文件和缩略图缓存
  /// Web 端调用后端 API，原生端扫描本地文件系统
  Future<Map<String, int>> cleanupOrphanFiles() async {
    if (_useApi) {
      final res = await ApiService.cleanupOrphanFiles();
      final result = res['result'] as Map<String, dynamic>? ?? {};
      return {
        'deleted_files': result['deleted_files'] as int? ?? 0,
        'deleted_thumbs': result['deleted_thumbs'] as int? ?? 0,
        'total_scanned': result['total_scanned'] as int? ?? 0,
        'referenced_count': result['referenced_count'] as int? ?? 0,
      };
    }

    // Native: collect all referenced image paths from DB
    final referencedPaths = <String>{};

    final coinImgRows = await db.select(db.coinImages).get();
    for (final r in coinImgRows) {
      if (r.imagePath.isNotEmpty) referencedPaths.add(r.imagePath);
    }

    final seriesImgRows = await db.select(db.seriesImages).get();
    for (final r in seriesImgRows) {
      if (r.imagePath.isNotEmpty) referencedPaths.add(r.imagePath);
    }

    final coinRows = await (db.select(db.coins)
          ..where((t) => t.firstImagePath.isNotNull()))
        .get();
    for (final r in coinRows) {
      if (r.firstImagePath != null && r.firstImagePath!.isNotEmpty) {
        referencedPaths.add(r.firstImagePath!);
      }
    }

    // Normalize to bare filenames (strip images/ prefix, lowercase)
    final referencedBare = <String>{};
    for (final path in referencedPaths) {
      final normalized = path.replaceAll('\\', '/').replaceFirst(RegExp(r'^images/'), '').toLowerCase();
      if (normalized.isNotEmpty && !normalized.startsWith('base64:')) {
        referencedBare.add(normalized);
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, 'images'));
    var deletedFiles = 0;
    var totalScanned = 0;

    if (await imagesDir.exists()) {
      await for (final entity in imagesDir.list(recursive: false)) {
        if (entity is! File) continue;
        final fname = p.basename(entity.path);
        if (fname.startsWith('.')) continue;
        totalScanned++;

        if (!referencedBare.contains(fname.toLowerCase())) {
          try {
            await entity.delete();
            deletedFiles++;
          } catch (_) {}
        }
      }
    }

    // Clean orphan thumbnails
    var deletedThumbs = 0;
    final thumbDir = Directory(p.join(imagesDir.path, '.thumb_cache'));
    if (await thumbDir.exists()) {
      final referencedBases = <String>{};
      for (final bare in referencedBare) {
        referencedBases.add(p.basenameWithoutExtension(bare).toLowerCase());
      }

      await for (final entity in thumbDir.list(recursive: false)) {
        if (entity is! File) continue;
        final fname = p.basename(entity.path);
        final thumbBase = fname.split('_').first.toLowerCase();
        final thumbBaseNoExt = p.basenameWithoutExtension(thumbBase);
        if (!referencedBases.contains(thumbBaseNoExt)) {
          try {
            await entity.delete();
            deletedThumbs++;
          } catch (_) {}
        }
      }
    }

    return {
      'deleted_files': deletedFiles,
      'deleted_thumbs': deletedThumbs,
      'total_scanned': totalScanned,
      'referenced_count': referencedBare.length,
    };
  }
}
