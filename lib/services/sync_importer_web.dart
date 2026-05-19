import '../models/sync_models.dart';

class SyncImporter {
  /// Web 环境不支持直接从本地 sqlite 文件解析并导入。
  /// 如果需要在 Web 上支持整包导入，应该在后端导出 JSON 并由前端调用后端接口获取。
  static Future<SyncData> importFromSqlite(String dbPath) async {
    throw UnsupportedError('Importing sqlite DB is not supported on Web. Use backend export/JSON instead.');
  }
}
