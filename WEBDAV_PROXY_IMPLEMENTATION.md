# WebDAV 代理跨域解决方案实现文档

## 问题描述
在 Flutter Web 环境中，直接连接第三方 WebDAV 服务（如 AList 搭建的 WebDAV）会被浏览器同源策略（SOP）和跨域资源共享（CORS）机制拦截，导致同步失败。

## 解决方案
通过后端代理转发的方式解决跨域问题。Flutter Web 将 WebDAV 请求发送给运行在同一域的 FastAPI 后端，由后端代理转发到真实的 WebDAV 服务。

## 实现架构

### 1. 后端代理接口 (FastAPI)
- **位置**: `backend/main.py` - `/api/proxy/webdav`
- **功能**: 接收所有 WebDAV HTTP 方法，转发请求到目标 WebDAV 地址
- **关键技术**: 使用 `httpx` 异步客户端进行请求转发
- **CORS 处理**: 移除冲突的头，添加必要的跨域头

### 2. 前端设置界面 (Flutter)
- **位置**: `lib/screens/settings_screen.dart`
- **新增组件**: "开启后端代理 (解决网页版跨域)" 开关
- **持久化**: 使用 `SharedPreferences` 保存代理开关状态
- **后端地址配置**: 可配置后端服务地址并持久化保存

### 3. URL 重写逻辑 (Flutter)
- **位置**: `lib/utils/url_helper.dart`
- **功能**: URL 规范化、代理 URL 构建、目标 URL 提取
- **自动处理**: 尾部斜杠、重复斜杠、URL 编码

### 4. 同步服务改造 (Flutter)
- **位置**: `lib/services/sync_service.dart`
- **改造点**:
  - 支持 Web 环境检测 (`kIsWeb`)
  - 自动 URL 重写 (`UrlHelper.rewriteWebDavUrlForWeb`)
  - 工厂方法 `SyncService.fromConfig(ref)` 简化创建

## 使用流程

### 1. 配置后端服务器
1. 启动 FastAPI 后端服务 (`python main.py`)
2. 在 Flutter Web 设置页面中配置后端地址（默认 `http://localhost:9876`）
3. 测试后端连接状态

### 2. 配置 WebDAV 代理
1. 在 WebDAV 配置卡片中填写：
   - WebDAV 服务器地址（如 `http://localhost:5244/dav/PC`）
   - 用户名/密码
2. 启用 "开启后端代理" 开关
3. 保存配置

### 3. 使用同步功能
- **推送 (Push)**: 将本地数据备份到 WebDAV
- **拉取 (Pull)**: 从 WebDAV 下载并合并数据

## 技术细节

### URL 重写规则
```
原始 WebDAV URL: http://localhost:5244/dav/PC
后端地址: http://localhost:9876

重写为代理 URL:
http://localhost:9876/api/proxy/webdav?target=http%3A%2F%2Flocalhost%3A5244%2Fdav%2FPC
```

### 自动环境检测
```dart
// 在 SyncService 构造时自动确定最终 URL
_finalUrl = _determineFinalUrl(
  rawUrl: rawUrl,
  useProxy: useProxy ?? false,
  backendBaseUrl: backendBaseUrl,
);

String _determineFinalUrl({
  required String rawUrl,
  required bool useProxy,
  String? backendBaseUrl,
}) {
  if (kIsWeb && useProxy && backendBaseUrl != null && backendBaseUrl.isNotEmpty) {
    // Web环境下使用代理
    return UrlHelper.rewriteWebDavUrlForWeb(rawUrl, backendBaseUrl, useProxy);
  }
  // 非Web环境或未启用代理，使用原始URL
  return UrlHelper.normalizeWebDavUrl(rawUrl);
}
```

### 代理接口支持的 HTTP 方法
- GET, POST, PUT, DELETE
- OPTIONS (CORS 预检请求)
- WebDAV 特有方法: PROPFIND, PROPPATCH, MKCOL, COPY, MOVE, LOCK, UNLOCK

## 依赖变更

### 后端依赖 (requirements.txt)
```
fastapi>=0.110.0
uvicorn>=0.29.0
python-multipart>=0.0.9
aiofiles>=23.2.0
httpx>=0.27.0  # 新增，用于代理转发
```

### 前端依赖
- 无新增依赖，使用现有包:
  - `shared_preferences`: 持久化存储
  - `webdav_client`: WebDAV 客户端
  - `flutter_riverpod`: 状态管理

## 测试验证

### 1. 后端代理测试
运行测试脚本:
```bash
python test_proxy_example.py
```

### 2. Flutter Web 测试
1. 编译 Flutter Web 应用
2. 配置 WebDAV 和代理设置
3. 测试推送/拉取功能

### 3. 原生平台测试
- Android/iOS/桌面: 不使用代理，直接连接 WebDAV
- 验证功能正常

## 故障排除

### 常见问题
1. **代理无法连接**
   - 检查后端服务是否运行
   - 检查后端地址配置是否正确
   - 查看后端日志中的错误信息

2. **WebDAV 认证失败**
   - 检查 WebDAV 用户名密码
   - 验证代理转发时认证头是否正确携带

3. **URL 格式错误**
   - 检查 URL 规范化逻辑
   - 验证代理 URL 构建是否正确

### 调试信息
- 开启 Flutter Web 开发者工具
- 查看网络请求中的实际 URL
- 检查后端日志中的代理转发记录

## 性能考虑
1. **请求延迟**: 代理增加了一次网络跳转，可能略有延迟
2. **超时设置**: 代理接口设置 30 秒超时
3. **连接池**: `httpx.AsyncClient` 自动管理连接复用

## 安全考虑
1. **目标 URL 验证**: 代理接口验证目标 URL 格式
2. **头过滤**: 移除敏感头信息（如 Origin、Host）
3. **CORS 限制**: 代理接口允许所有来源 (`*`)，仅限内部网络使用

## 扩展性
1. **多 WebDAV 服务**: 可扩展支持多个不同 WebDAV 服务
2. **认证增强**: 可添加后端认证层
3. **日志记录**: 可添加详细的代理操作日志