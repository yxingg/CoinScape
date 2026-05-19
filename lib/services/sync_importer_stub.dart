import '../models/sync_models.dart';

class SyncImporter {
  static Future<SyncData> importFromSqlite(String dbPath) async {
    throw UnsupportedError('No SyncImporter implementation available for this platform.');
  }
}
