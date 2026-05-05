import 'package:drift/drift.dart';

@DataClassName('SeriesData')
class Series extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Coins extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get name => text()();
  IntColumn get year => integer().nullable()();
  RealColumn get faceValue => real().nullable()();
  TextColumn get material => text().nullable()();
  RealColumn get weight => real().nullable()();
  RealColumn get diameter => real().nullable()();
  TextColumn get mintage => text().nullable()();
  TextColumn get mint => text().nullable()();
  TextColumn get grade => text().nullable()();
  RealColumn get unitPrice => real().nullable()();
  IntColumn get quantity => integer().nullable()();
  TextColumn get quantityUnit => text().nullable()();
  DateTimeColumn get collectionTime => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()(); // 创建时间，非空
  TextColumn get comments => text().nullable()();
  TextColumn get firstImagePath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CoinImages extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get coinId => text().references(Coins, #id, onDelete: KeyAction.cascade)();
  TextColumn get imagePath => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class SeriesImages extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get seriesId => text().references(Series, #id, onDelete: KeyAction.cascade)();
  TextColumn get imagePath => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class CoinSeriesLink extends Table {
  TextColumn get coinId => text().references(Coins, #id)();
  TextColumn get seriesId => text().references(Series, #id)();

  @override
  Set<Column> get primaryKey => {coinId, seriesId};
}
