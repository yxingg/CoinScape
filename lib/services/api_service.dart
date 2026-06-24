import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// API 服务 - 封装所有与 Python 后端的 HTTP 通信
/// 仅在 Web 端使用，原生端仍然使用 Drift 本地数据库
class ApiService {
  // 后端地址，可通过设置页面修改
  static String _baseUrl = 'http://localhost:9876';
  static const String _backendUrlKey = 'backend_base_url';

  static String get baseUrl => _baseUrl;

  static void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// 从SharedPreferences加载保存的后端URL
  static Future<void> loadSavedBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_backendUrlKey);
      if (savedUrl != null && savedUrl.isNotEmpty) {
        setBaseUrl(savedUrl);
      }
    } catch (e) {
      // 如果加载失败，使用默认值
      // print('Failed to load saved backend URL: $e');
    }
  }

  /// 保存后端URL到SharedPreferences
  static Future<void> saveBaseUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_backendUrlKey, url);
      setBaseUrl(url);
    } catch (e) {
      // print('Failed to save backend URL: $e');
      rethrow;
    }
  }

  static String get apiUrl => '$_baseUrl/api';

  // ==========================================
  // 通用 HTTP 请求方法
  // ==========================================

  static Future<Map<String, dynamic>> _get(String path) async {
    final response = await http.get(Uri.parse('$apiUrl$path'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(response.statusCode, response.body);
  }

  static Future<List<dynamic>> _getList(String path) async {
    final response = await http.get(Uri.parse('$apiUrl$path'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw ApiException(response.statusCode, response.body);
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$apiUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(response.statusCode, response.body);
  }

  static Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$apiUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(response.statusCode, response.body);
  }

  static Future<Map<String, dynamic>> _delete(String path) async {
    final response = await http.delete(Uri.parse('$apiUrl$path'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(response.statusCode, response.body);
  }

  // ==========================================
  // Health & Config
  // ==========================================

  static Future<bool> checkHealth() async {
    // 在 Web 环境下进行真实的后端连通性检测
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('$_baseUrl/api/health'));
        return response.statusCode == 200;
      } catch (_) {
        return false;
      }
    }

    // 原生平台（Android/iOS）使用本地存储/本地 DB，不应在启动时尝试连接后端。
    // 因此默认返回 false，触发本地离线逻辑。针对设置界面的“检测连接”按钮，
    // UI 层会拦截并向用户展示“Android 端已启用本地独立模式”的提示。
    return false;
  }

  /// 获取后端配置（保存路径等）
  static Future<Map<String, dynamic>> getConfig() async {
    return _get('/config');
  }

  /// 更新后端保存路径
  static Future<Map<String, dynamic>> updateSavePath(String newPath) async {
    return _put('/config', {'save_path': newPath});
  }

  // ==========================================
  // Series API
  // ==========================================

  static Future<List<dynamic>> getSeriesList() async {
    return _getList('/series');
  }

  static Future<Map<String, dynamic>> getSeries(String id) async {
    return _get('/series/$id');
  }

  static Future<String> createSeries(Map<String, dynamic> data) async {
    final result = await _post('/series', data);
    return result['id'] as String;
  }

  static Future<void> updateSeries(String id, Map<String, dynamic> data) async {
    await _put('/series/$id', data);
  }

  static Future<void> deleteSeries(String id) async {
    await _delete('/series/$id');
  }

  static Future<void> deleteSeriesBatch(List<String> ids) async {
    await _post('/series/batch-delete', {'ids': ids});
  }

  // ==========================================
  // Coins API
  // ==========================================

  static Future<List<dynamic>> getCoinsList({String? seriesId}) async {
    if (seriesId != null) {
      return _getList('/coins?series_id=$seriesId');
    }
    return _getList('/coins');
  }

  static Future<Map<String, dynamic>> getCoin(String id) async {
    return _get('/coins/$id');
  }

  static Future<String> createCoin(Map<String, dynamic> data) async {
    final result = await _post('/coins', data);
    return result['id'] as String;
  }

  static Future<void> updateCoin(String id, Map<String, dynamic> data) async {
    await _put('/coins/$id', data);
  }

  static Future<void> deleteCoin(String id) async {
    await _delete('/coins/$id');
  }

  static Future<void> deleteCoinsBatch(List<String> ids) async {
    await _post('/coins/batch-delete', {'ids': ids});
  }

  // ==========================================
  // Links API
  // ==========================================

  static Future<List<String>> getSeriesIdsForCoin(String coinId) async {
    final result = await _get('/links/$coinId');
    return List<String>.from(result['series_ids'] as List);
  }

  static Future<void> linkCoinToSeries(String coinId, String seriesId) async {
    await _post('/links', {'coin_id': coinId, 'series_id': seriesId});
  }

  static Future<void> unlinkCoinFromSeries(String coinId, String seriesId) async {
    final response = await http.delete(Uri.parse('$apiUrl/links?coin_id=$coinId&series_id=$seriesId'));
    if (response.statusCode == 200) {
      return;
    }
    throw ApiException(response.statusCode, response.body);
  }

  static Future<void> setCoinSeriesTags(String coinId, List<String> seriesIds) async {
    await _post('/links/set-tags', {'coin_id': coinId, 'series_ids': seriesIds});
  }

  static Future<void> addCoinsToSeries(List<String> coinIds, List<String> seriesIds) async {
    await _post('/links/batch-add', {'coin_ids': coinIds, 'series_ids': seriesIds});
  }

  static Future<void> removeCoinsFromAllSeries(List<String> coinIds) async {
    await _post('/links/batch-remove', {'coin_ids': coinIds});
  }

  // ==========================================
  // Images API
  // ==========================================

  static Future<List<dynamic>> getCoinImages(String coinId) async {
    return _getList('/images/coin/$coinId');
  }

  static Future<void> replaceCoinImages(String coinId, List<String> imagePaths) async {
    await _post('/images/coin/$coinId', {'image_paths': imagePaths});
  }

  static Future<List<dynamic>> getSeriesImages(String seriesId) async {
    return _getList('/images/series/$seriesId');
  }

  static Future<void> replaceSeriesImages(String seriesId, List<String> imagePaths) async {
    await _post('/images/series/$seriesId', {'image_paths': imagePaths});
  }

  /// 上传图片文件到后端，返回图片路径
  static Future<String> uploadImage(Uint8List bytes, String filename) async {
    final request = http.MultipartRequest('POST', Uri.parse('$apiUrl/images/upload'));
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      return result['path'] as String;
    }
    throw ApiException(response.statusCode, response.body);
  }

  /// 获取图片文件的完整 URL
  static String getImageUrl(String imagePath) {
    return '$_baseUrl/api/images/file/$imagePath';
  }

  /// 获取缩略图 URL（后端按尺寸缩放并缓存，用于列表/网格展示）
  static String getThumbnailUrl(String imagePath, {int? width, int? height}) {
    final params = <String>[];
    if (width != null) params.add('width=$width');
    if (height != null) params.add('height=$height');
    if (params.isEmpty) return getImageUrl(imagePath);
    return '$_baseUrl/api/images/file/$imagePath?${params.join('&')}';
  }

  /// 清理后端无引用的孤立图片文件
  static Future<Map<String, dynamic>> cleanupOrphanFiles() async {
    return await _post('/cleanup/orphan-files', {});
  }

  // ==========================================
  // Fonts API
  // ==========================================

  /// 获取所有可用字体列表
  static Future<List<Map<String, dynamic>>> getFontsList() async {
    try {
      final result = await _get('/fonts/');
      final fonts = result['fonts'] as List;
      return fonts.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<String> uploadFont(Uint8List bytes, String filename) async {
    final request = http.MultipartRequest('POST', Uri.parse('$apiUrl/fonts/upload'));
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      return result['font_id'] as String;
    }
    throw ApiException(response.statusCode, response.body);
  }

  /// 获取字体文件的直接URL（用于动态加载）
  static String getFontUrl(String fontId) {
    return '$_baseUrl/api/fonts/$fontId';
  }

  /// 获取静态字体文件URL（用于CSS加载）
  static String getStaticFontUrl(String fontId, String ext) {
    return '$_baseUrl/fonts/$fontId$ext';
  }

  static Future<bool> checkFontExists(String fontId) async {
    try {
      final result = await _get('/fonts/check/$fontId');
      return result['exists'] as bool;
    } catch (_) {
      return false;
    }
  }

  static Future<void> deleteFont(String fontId) async {
    await _delete('/fonts/$fontId');
  }

  // ==========================================
  // Application Settings API
  // ==========================================

  /// 获取应用程序设置
  static Future<Map<String, dynamic>> getAppSettings() async {
    return await _get('/settings');
  }

  /// 登录
  static Future<bool> login(String username, String password) async {
    try {
      final resp = await _post('/auth/login', {'username': username, 'password': password});
      return resp['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// 更新应用程序设置
  static Future<Map<String, dynamic>> updateAppSettings(Map<String, dynamic> settings) async {
    return await _put('/settings', settings);
  }

  /// 更新特定类别的设置
  static Future<Map<String, dynamic>> updateSettingsCategory(String category, Map<String, dynamic> settings) async {
    return await _put('/settings/$category', settings);
  }

  // ==========================================
  // Backup API
  // ==========================================

  static Future<Map<String, dynamic>> exportAllData() async {
    return _get('/backup/export');
  }

  static Future<void> importAllData(Map<String, dynamic> data) async {
    await _post('/backup/import', data);
  }

  /// Scan local data directory for coinscape.db and import
  static Future<Map<String, dynamic>> importLocalDb() async {
    return await _post('/backup/import_local_db', {});
  }

  /// Read marker temp file, set last_local_change, delete file. Call AFTER merge.
  static Future<Map<String, dynamic>> applyMarker() async {
    return await _post('/sync/apply_marker', {});
  }

  // ==========================================
  // File Sync (backend-driven)
  // ==========================================

  /// Trigger server-side file sync push (scan + incremental upload)
  static Future<Map<String, dynamic>> startFileSyncPush() async {
    return await _post('/sync/files/push', {'force': true});
  }

  /// Trigger server-side file-level pull from WebDAV
  static Future<Map<String, dynamic>> startFileSyncPull() async {
    return await _post('/sync/files/pull', {});
  }

  static Future<Map<String, dynamic>> startFileSyncPullWithPolicy(String policy) async {
    return await _post('/sync/files/pull', {'policy': policy});
  }

  /// Scan local files and enqueue pending upload/delete tasks (no upload yet)
  static Future<Map<String, dynamic>> startFileSyncScan({bool force = false}) async {
    return await _post('/sync/files/scan', {'force': force});
  }

  /// Get full sync queue entries
  static Future<Map<String, dynamic>> getFileSyncQueue() async {
    return await _get('/sync/files/queue');
  }

  /// Get current file sync status (counts of pending/in_progress/done/failed)
  static Future<Map<String, dynamic>> getFileSyncStatus() async {
    return await _get('/sync/files/status');
  }

  /// Retry previously failed sync queue entries, or clear them when `clear=true`.
  static Future<Map<String, dynamic>> retryFailedSync({bool clear = false}) async {
    return await _post('/sync/files/retry_failed', {'clear': clear});
  }

  /// Preview remote vs local file differences
  static Future<Map<String, dynamic>> previewPull() async {
    final res = await _get('/sync/files/preview_pull');
    return res['preview'] as Map<String, dynamic>;
  }

  /// Pull a single file on the server by relative path
  static Future<Map<String, dynamic>> pullFile(String path) async {
    return await _post('/sync/files/pull_one', {'path': path});
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;

  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}
