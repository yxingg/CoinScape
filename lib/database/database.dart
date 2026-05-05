import 'package:drift/drift.dart';
import 'tables.dart';
import 'connection/connection.dart' as impl;

part 'database.g.dart';

@DriftDatabase(tables: [Coins, Series, CoinSeriesLink, CoinImages, SeriesImages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(impl.connect());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(coinImages);
            await m.createTable(seriesImages);
          }
          if (from < 3) {
            // 为 Coins 表添加 createdAt 列
            await m.addColumn(coins, coins.createdAt);
            // 为已有的记录设置 createdAt 为当前时间
            await customStatement(
              'UPDATE coins SET created_at = ? WHERE created_at IS NULL',
              [DateTime.now().toIso8601String()],
            );
          }

        },
      );
}
