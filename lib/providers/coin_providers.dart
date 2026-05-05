import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../repositories/coin_repository.dart';

// ====================================================
// 核心数据库及 Repository 实例对象 Provider
// ====================================================

/// 全局持有的单一数据库实例
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  // 当 Provider 被销毁时安全关闭数据库连接
  ref.onDispose(() => db.close());
  return db;
});

/// 数据访问层（注入了 databaseProvider）
final coinRepositoryProvider = Provider<CoinRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CoinRepository(db);
});

// ====================================================
// UI 监听使用的数据流 Providers (Streams)
// ====================================================

/// 监听所有的系列列表
final seriesListProvider = StreamProvider<List<SeriesData>>((ref) {
  final repo = ref.watch(coinRepositoryProvider);
  return repo.watchAllSeries();
});

/// 监听特定 ID 系列下属的所有纪念币（基于系列 ID）
final coinsBySeriesProvider = StreamProvider.family<List<Coin>, String>((ref, seriesId) {
  final repo = ref.watch(coinRepositoryProvider);
  return repo.watchCoinsBySeries(seriesId);
});

/// 监听库中的所有纪念币（如果需要展示“全部”视图）
final allCoinsProvider = StreamProvider<List<Coin>>((ref) {
  final repo = ref.watch(coinRepositoryProvider);
  return repo.watchAllCoins();
});
