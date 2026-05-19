import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../models/sync_models.dart';

class SyncImporter {
  /// 从本地 sqlite 文件读取数据并转换为 SyncData
  static Future<SyncData> importFromSqlite(String dbPath) async {
    final f = File(dbPath);
    if (!await f.exists()) throw ArgumentError('DB file not found: $dbPath');

    final database = sqlite3.open(dbPath);
    try {
      // series
      final series = <Map<String, dynamic>>[];
      try {
        final rows = database.select('SELECT id, name, description, created_at FROM series');
        for (final row in rows) {
          series.add({
            'id': row['id'],
            'name': row['name'],
            'description': row['description'],
            'createdAt': _toIso(row['created_at']),
          });
        }
      } catch (_) {
        // table missing or query failed -> empty
      }

      // coins
      final coins = <Map<String, dynamic>>[];
      try {
        final rows = database.select('SELECT id, name, year, face_value, material, weight, diameter, mintage, mint, grade, unit_price, quantity, quantity_unit, collection_time, created_at, comments, first_image_path FROM coins');
        for (final row in rows) {
          coins.add({
            'id': row['id'],
            'name': row['name'],
            'year': row['year'],
            'faceValue': row['face_value'],
            'material': row['material'],
            'weight': row['weight'],
            'diameter': row['diameter'],
            'mintage': row['mintage'],
            'mint': row['mint'],
            'grade': row['grade'],
            'unitPrice': row['unit_price'],
            'quantity': row['quantity'],
            'quantityUnit': row['quantity_unit'],
            'collectionTime': row['collection_time'] == null ? null : _toIso(row['collection_time']),
            'createdAt': _toIso(row['created_at']),
            'comments': row['comments'],
            'firstImagePath': row['first_image_path'],
          });
        }
      } catch (_) {}

      // links
      final links = <Map<String, dynamic>>[];
      try {
        final rows = database.select('SELECT coin_id, series_id FROM coin_series_link');
        for (final row in rows) {
          links.add({'coinId': row['coin_id'], 'seriesId': row['series_id']});
        }
      } catch (_) {}

      // coin images
      final coinImages = <Map<String, dynamic>>[];
      try {
        final rows = database.select('SELECT id, coin_id, image_path, sort_order FROM coin_images');
        for (final row in rows) {
          coinImages.add({
            'id': row['id'],
            'coinId': row['coin_id'],
            'imagePath': row['image_path'],
            'sortOrder': row['sort_order'],
          });
        }
      } catch (_) {}

      // series images
      final seriesImages = <Map<String, dynamic>>[];
      try {
        final rows = database.select('SELECT id, series_id, image_path, sort_order FROM series_images');
        for (final row in rows) {
          seriesImages.add({
            'id': row['id'],
            'seriesId': row['series_id'],
            'imagePath': row['image_path'],
            'sortOrder': row['sort_order'],
          });
        }
      } catch (_) {}

      return SyncData(
        series: series,
        coins: coins,
        links: links,
        coinImages: coinImages,
        seriesImages: seriesImages,
      );
    } finally {
      database.dispose();
    }
  }

  static String? _toIso(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value).toIso8601String();
      } catch (_) {
        return value.toString();
      }
    }
    if (value is String) {
      // if it's a numeric string, try to parse
      final iv = int.tryParse(value);
      if (iv != null) {
        return DateTime.fromMillisecondsSinceEpoch(iv).toIso8601String();
      }
      return value;
    }
    return value.toString();
  }
}
