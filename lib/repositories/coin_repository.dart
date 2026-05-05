import 'package:drift/drift.dart';
import '../database/database.dart';

class CoinRepository {
  final AppDatabase db;

  CoinRepository(this.db);

  // ==========================================
  // Series (系列) 相关操作
  // ==========================================

  /// 监听所有系列（响应式数据流）
  Stream<List<SeriesData>> watchAllSeries() {
    return (db.select(db.series)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  /// 添加一个新系列
  Future<int> insertSeries(SeriesCompanion series) {
    return db.into(db.series).insert(series);
  }

  /// 修改系列信息
  Future<bool> updateSeries(SeriesCompanion series) {
    return db.update(db.series).replace(series);
  }

  /// 删除系列：要求必须同时删除关联映射，但【绝对不可删除纪念币实体】
  Future<void> deleteSeries(String seriesId) async {
    return db.transaction(() async {
      // 先删除多对多映射表中的记录
      await (db.delete(db.coinSeriesLink)..where((t) => t.seriesId.equals(seriesId))).go();
      // 再删除系列本身
      await (db.delete(db.series)..where((t) => t.id.equals(seriesId))).go();
    });
  }

  /// 批量删除系列
  Future<void> deleteSeriesBatch(List<String> seriesIds) async {
    return db.transaction(() async {
      for (final seriesId in seriesIds) {
        await (db.delete(db.coinSeriesLink)..where((t) => t.seriesId.equals(seriesId))).go();
        await (db.delete(db.series)..where((t) => t.id.equals(seriesId))).go();
      }
    });
  }

  // ==========================================
  // Coin (纪念币) 相关操作
  // ==========================================

  /// 排序辅助：按 collectionTime DESC，NULL 值按 createdAt DESC
  /// 用于 select 查询（非 join）
  List<OrderingTerm> _coinOrderByTerms() {
    return [
      OrderingTerm(
        expression: db.coins.collectionTime,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(
        expression: db.coins.createdAt,
        mode: OrderingMode.desc,
      ),
    ];
  }

  /// 用于 join 查询的排序
  void _applyCoinOrderBy(dynamic query) {
    for (final term in _coinOrderByTerms()) {
      query.orderBy.add(term);
    }
  }

  /// 监听指定系列下的所有纪念币（关联查询）
  Stream<List<Coin>> watchCoinsBySeries(String seriesId) {
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

  /// 监听所有纪念币（如果不区分系列展示时使用）
  Stream<List<Coin>> watchAllCoins() {
    return (db.select(db.coins)
          ..orderBy([
            (t) => OrderingTerm(expression: t.collectionTime, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }


  /// 添加新纪念币
  Future<int> insertCoin(CoinsCompanion coin) {
    return db.into(db.coins).insert(coin);
  }

  /// 修改纪念币
  Future<bool> updateCoin(CoinsCompanion coin) {
    return db.update(db.coins).replace(coin);
  }

  /// 删除纪念币（同时删除其所有的系列关联映射）
  Future<void> deleteCoin(String coinId) async {
    return db.transaction(() async {
      await (db.delete(db.coinImages)..where((t) => t.coinId.equals(coinId))).go();
      // 先删除关联映射
      await (db.delete(db.coinSeriesLink)..where((t) => t.coinId.equals(coinId))).go();
      // 删除纪念币实体
      await (db.delete(db.coins)..where((t) => t.id.equals(coinId))).go();
    });
  }

  /// 批量删除纪念币
  Future<void> deleteCoinsBatch(List<String> coinIds) async {
    return db.transaction(() async {
      for (final coinId in coinIds) {
        await (db.delete(db.coinImages)..where((t) => t.coinId.equals(coinId))).go();
        await (db.delete(db.coinSeriesLink)..where((t) => t.coinId.equals(coinId))).go();
        await (db.delete(db.coins)..where((t) => t.id.equals(coinId))).go();
      }
    });
  }

  // ==========================================
  // CoinSeriesLink (多对多映射) 相关操作
  // ==========================================

  /// 为某个纪念币绑定一个系列
  Future<int> linkCoinToSeries(String coinId, String seriesId) {
    return db.into(db.coinSeriesLink).insert(
      CoinSeriesLinkCompanion.insert(coinId: coinId, seriesId: seriesId),
      mode: InsertMode.insertOrIgnore, // 避免重复插入报错
    );
  }

  /// 解除某个纪念币和系列的绑定
  Future<int> unlinkCoinFromSeries(String coinId, String seriesId) {
    return (db.delete(db.coinSeriesLink)
          ..where((t) => t.coinId.equals(coinId) & t.seriesId.equals(seriesId)))
        .go();
  }

  Future<List<String>> getSeriesIdsForCoin(String coinId) async {
    final rows = await (db.select(db.coinSeriesLink)..where((t) => t.coinId.equals(coinId))).get();
    return rows.map((e) => e.seriesId).toList();
  }

  Future<void> setCoinSeriesTags(String coinId, List<String> seriesIds) async {
    await db.transaction(() async {
      await (db.delete(db.coinSeriesLink)..where((t) => t.coinId.equals(coinId))).go();
      for (final sid in seriesIds) {
        await db.into(db.coinSeriesLink).insert(
              CoinSeriesLinkCompanion.insert(coinId: coinId, seriesId: sid),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }

  /// 批量将多个纪念币添加到多个系列
  Future<void> addCoinsToSeries(List<String> coinIds, List<String> seriesIds) async {
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
  }

  /// 批量将多个纪念币从所有系列中移除
  Future<void> removeCoinsFromAllSeries(List<String> coinIds) async {
    await db.transaction(() async {
      for (final coinId in coinIds) {
        await (db.delete(db.coinSeriesLink)..where((t) => t.coinId.equals(coinId))).go();
      }
    });
  }

  Future<List<CoinImage>> getCoinImages(String coinId) {
    return (db.select(db.coinImages)
          ..where((t) => t.coinId.equals(coinId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  Future<void> replaceCoinImages(String coinId, List<String> imagePaths) async {
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

  Future<List<SeriesImage>> getSeriesImages(String seriesId) {
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
}
