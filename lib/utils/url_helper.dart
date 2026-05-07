// URL 工具函数，处理URL规范化和拼接

/// URL 规范化工具类
class UrlHelper {
  /// 规范化基础URL（确保结尾有斜杠但不多余）
  /// 例如: http://localhost:8000 -> http://localhost:8000/
  ///        http://localhost:8000/ -> http://localhost:8000/
  static String normalizeBaseUrl(String baseUrl) {
    if (baseUrl.isEmpty) return '';
    
    String url = baseUrl.trim();
    // 移除结尾的斜杠
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    // 添加单个斜杠
    return '$url/';
  }

  /// 规范化路径（确保开头有斜杠但不多余）
  /// 例如: proxy/webdav -> /proxy/webdav
  ///        /proxy/webdav -> /proxy/webdav
  ///        //proxy/webdav -> /proxy/webdav
  static String normalizePath(String path) {
    if (path.isEmpty) return '/';
    
    String p = path.trim();
    // 确保开头有斜杠
    if (!p.startsWith('/')) {
      p = '/$p';
    }
    // 移除开头重复的斜杠
    while (p.startsWith('//')) {
      p = p.substring(1);
    }
    return p;
  }

  /// 规范化WebDAV URL（确保以webdav期望的格式）
  /// 例如: http://localhost:5244/dav/PC -> http://localhost:5244/dav/PC
  ///        http://localhost:5244/dav/PC/ -> http://localhost:5244/dav/PC
  static String normalizeWebDavUrl(String url) {
    if (url.isEmpty) return '';
    
    String normalized = url.trim();
    // 移除结尾的斜杠，因为webdav客户端通常处理路径时需要
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  /// 构建代理URL - 新版本：支持WebDAV路径参数
  /// [baseUrl] - 后端基础URL，如 http://localhost:8000
  /// [targetBaseUrl] - 目标WebDAV基础URL，如 http://localhost:5244/dav/PC
  /// [webdavPath] - WebDAV路径，如 /latest_backup.ccm
  /// [username] - WebDAV用户名（可选）
  /// [password] - WebDAV密码（可选）
  /// 返回: http://localhost:8000/api/proxy/webdav/latest_backup.ccm?target=http%3A%2F%2Flocalhost%3A5244%2Fdav%2FPC&user=username&password=password
  static String buildProxyUrl({
    required String baseUrl,
    required String targetBaseUrl,
    String webdavPath = '',
    String proxyPath = '/api/proxy/webdav',
    String? username,
    String? password,
  }) {
    if (baseUrl.isEmpty || targetBaseUrl.isEmpty) {
      throw ArgumentError('baseUrl and targetBaseUrl must not be empty');
    }
    
    // 规范化基础URL
    final normalizedBase = normalizeBaseUrl(baseUrl);
    // 规范化代理路径
    final normalizedProxyPath = normalizePath(proxyPath);
    // 规范化WebDAV路径
    final normalizedWebDavPath = normalizePath(webdavPath);
    // 编码目标基础URL
    final encodedTarget = Uri.encodeComponent(targetBaseUrl);
    
    // 构建基础URL（包含WebDAV路径参数）
    String url = '$normalizedBase${normalizedProxyPath.substring(1)}';
    if (normalizedWebDavPath.isNotEmpty && normalizedWebDavPath != '/') {
      url += '${normalizedWebDavPath.substring(1)}';
    }
    url += '?target=$encodedTarget';
    
    // 添加用户认证参数（如果提供）
    final params = <String>[];
    if (username != null && username.isNotEmpty) {
      params.add('user=${Uri.encodeComponent(username)}');
    }
    if (password != null && password.isNotEmpty) {
      params.add('password=${Uri.encodeComponent(password)}');
    }
    
    if (params.isNotEmpty) {
      url += '&${params.join('&')}';
    }
    
    return url;
  }

  /// 构建代理URL - 旧版本兼容（仅用于PROPFIND根目录请求）
  static String buildLegacyProxyUrl({
    required String baseUrl,
    required String targetUrl,
    String proxyPath = '/api/proxy/webdav',
    String? username,
    String? password,
  }) {
    return buildProxyUrl(
      baseUrl: baseUrl,
      targetBaseUrl: targetUrl,
      webdavPath: '',
      proxyPath: proxyPath,
      username: username,
      password: password,
    );
  }

  /// 检查并自动重写WebDAV URL（用于Web环境）
  /// [rawUrl] - 原始WebDAV URL
  /// [backendBaseUrl] - 后端基础URL
  /// [useProxy] - 是否使用代理
  /// [username] - WebDAV用户名（可选）
  /// [password] - WebDAV密码（可选）
  /// 返回: 如果需要代理则返回代理URL，否则返回原始URL
  static String? rewriteWebDavUrlForWeb(
    String rawUrl,
    String backendBaseUrl,
    bool useProxy, {
    String? username,
    String? password,
  }) {
    if (!useProxy || backendBaseUrl.isEmpty || rawUrl.isEmpty) {
      return rawUrl;
    }
    
    try {
      return buildProxyUrl(
        baseUrl: backendBaseUrl,
        targetBaseUrl: normalizeWebDavUrl(rawUrl),
        proxyPath: '/api/proxy/webdav',
        username: username,
        password: password,
      );
    } catch (e) {
      // 如果构建失败，返回原始URL
      return rawUrl;
    }
  }

  /// 从代理URL中提取目标URL
  /// [proxyUrl] - 代理URL，如 http://localhost:8000/proxy/webdav?target=http%3A%2F%2Flocalhost%3A5244%2Fdav%2FPC
  /// 返回: http://localhost:5244/dav/PC
  static String? extractTargetFromProxyUrl(String proxyUrl) {
    try {
      final uri = Uri.parse(proxyUrl);
      final target = uri.queryParameters['target'];
      return target != null ? Uri.decodeComponent(target) : null;
    } catch (e) {
      return null;
    }
  }

  /// 检查URL是否为代理URL
  static bool isProxyUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.path.contains('/proxy/webdav') && 
             uri.queryParameters.containsKey('target');
    } catch (e) {
      return false;
    }
  }
}