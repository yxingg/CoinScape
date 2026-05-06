import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// API 服务 - 封装所有与 Python 后端的 HTTP 通信
/// 仅在 Web 端使用，原生端仍然使用 Drift 本地数据库
class ApiService {
  // 后端地址，可通过设置页面修改
  static String _baseUrl = 'http://localhost:9876';

  static String get baseUrl => _baseUrl;

  static void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
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
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/health'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
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

  // ==========================================
  // Fonts API
  // ==========================================

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

  static String getFontUrl(String fontId) {
    return '$_baseUrl/api/fonts/$fontId';
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
  // Backup API
  // ==========================================

  static Future<Map<String, dynamic>> exportAllData() async {
    return _get('/backup/export');
  }

  static Future<void> importAllData(Map<String, dynamic> data) async {
    await _post('/backup/import', data);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;

  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}
