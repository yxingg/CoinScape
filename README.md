# CoinScape 🪙

> 纪念币收藏管理应用 — 轻松管理您的纪念币收藏

---

## 简介

CoinScape 是一款跨平台纪念币收藏管理应用，基于 Flutter 构建。它帮助收藏爱好者系统化管理纪念币藏品，支持系列分组、批量操作、时间轴浏览、图片管理、PDF 导出以及 WebDAV 云同步备份。

支持 **Windows**、**Android** 和 **Web** 平台。

---

## 功能特性

### 📦 系列管理
- 创建、编辑、删除系列（系列即纪念币的收藏主题分组，如"中国生肖系列"、"奥运会纪念币"等）
- 左侧系列列表支持固定显示或手动开关，适应不同屏幕宽度
- 系列支持长按多选，多选后可批量删除、导出 PDF 或 CCM 数据包

### 🪙 纪念币管理
- 添加、编辑、删除纪念币，支持以下字段：
  - **基本信息**：名称、年份、面值、国家
  - **物理属性**：材质、重量（g）、直径（mm）
  - **发行信息**：发行量、发行日期
  - **收藏信息**：收藏时间、购买价格（单价 × 数量）、品相评级、备注
- 纪念币列表支持按收藏时间排序（未填写收藏时间的按创建时间排序）
- 支持跨系列多选纪念币，多选后可批量删除、批量添加到指定系列、或从所有系列中移除

### 🖼️ 图片管理
- 为纪念币和系列添加图片（支持拍照或从相册选择）
- 图片预览按原始比例显示，不会拉伸变形
- 支持多张图片管理

### ⏱️ 时间轴
- 右侧时间轴按年份展示纪念币分布
- 点击年份可快速跳转到对应年份的纪念币
- 交互式导航，方便浏览多年收藏

### 📄 PDF 导出
- 将纪念币收藏信息导出为 PDF 文件
- 支持单个或批量导出
- 可在应用中预览或直接分享

### ☁️ WebDAV 云同步
- 通过 WebDAV 协议将数据备份到云盘（支持 NextCloud、坚果云等）
- 支持手动备份（Push）和恢复（Pull）
- 备份/恢复按钮位于主页面右上角，方便操作
- 数据以压缩包形式存储，安全可靠

### 🔍 搜索筛选
- 按名称搜索纪念币
- 按系列筛选查看

### 🎨 Material 3 设计
- 采用 Material Design 3 设计语言
- 支持主题颜色定制
- 响应式布局，适配桌面和移动端

---

## 技术栈

| 技术 | 用途 |
|------|------|
| [Flutter](https://flutter.dev/) | 跨平台 UI 框架 |
| [Riverpod](https://riverpod.dev/) | 状态管理 |
| [Drift](https://drift.simonbinder.eu/) | SQLite 本地数据库（支持 Web） |
| [WebDAV Client](https://pub.dev/packages/webdav_client) | 云同步 |
| [PDF](https://pub.dev/packages/pdf) | PDF 生成 |
| [Printing](https://pub.dev/packages/printing) | PDF 打印/预览 |
| [Share Plus](https://pub.dev/packages/share_plus) | 文件分享 |
| [Image Picker](https://pub.dev/packages/image_picker) | 图片选择 |
| [File Picker](https://pub.dev/packages/file_picker) | 文件选择 |
| [Archive](https://pub.dev/packages/archive) | 压缩打包 |
| [Intl](https://pub.dev/packages/intl) | 国际化/日期格式化 |

---

## 快速开始

### 环境要求

- Flutter SDK ^3.11.5
- Dart SDK ^3.11.5
- 支持平台：Windows / Web / Android

### 安装步骤

```bash
# 克隆仓库
git clone https://github.com/yourusername/coinscape.git
cd coinscape

# 安装依赖
flutter pub get

# 运行（Windows）
flutter run -d windows

# 运行（Web）
flutter run -d chrome

# 运行（Android）
flutter run -d android
```

### 构建

```bash
# Windows 桌面版
flutter build windows

# Web 版
flutter build web

# Android APK
flutter build apk
```

---

**Web 部署注意（后端地址与字体）**

- 后端地址来源与优先级：
  - 前端在启动时会优先读取浏览器保存的后端地址（SharedPreferences / localStorage key = `backend_base_url`）。
  - 若未保存地址，Web 端会优先使用当前页面的 origin（`Uri.base`），也就是同源主机（this is useful when static files are served by the same backend）。
  - 仅当以上都不可用时，才会使用内置默认 `http://localhost:9876`。
  - 如果你从其它设备打开页面但控制台显示 `GET http://localhost:9876/api/settings net::ERR_CONNECTION_REFUSED`，说明客户端还在用默认的 `localhost`；可以在浏览器 Console 里临时运行下面命令保存正确的后端地址：

    ```javascript
    localStorage.setItem('backend_base_url', 'http://10.168.72.54:9876');
    location.reload();
    ```

- 字体默认策略：
  - 后端会读取 `backend/data/fonts` 目录下的字体文件并暴露 REST API（`GET /api/fonts/` 返回字体列表，`GET /api/fonts/{font_id}` 返回字体文件）。
  - 当前端设置中的显示字体为 `default`（即未显式选择字体）时，前端会在启动时请求 `/api/fonts/`，并把返回列表的第一个字体自动设置为默认显示字体（这样你把常用字体放在 `backend/data/fonts` 下，系统会自动使用第一个字体）。
  - 如果你希望前端直接使用内嵌字体资源，也可以把字体文件放到 `assets/fonts/` 并在 `pubspec.yaml` 的 `fonts:` 中注册（项目默认注释了该段）。

- 关于 web 渲染器（CanvasKit / HTML）：
  - 将字体打包/同源托管后，页面不再依赖外部 CDN（如 fonts.gstatic.com），因此通常**不需要**切换到 `--web-renderer html` 来修复字体加载问题。CanvasKit（默认）或 HTML 渲染器对字体的表现会有差异，但只要字体是同源可用，字体渲染应当正常。
  - 若你遇到特定设备的渲染差异，可以尝试 `flutter build web --no-web-resources-cdn`（确保构建不把静态资源指向外部 CDN），并按需切换渲染器测试。但这一切在把字体打包或由后端同源提供后通常不是必须步骤。

以上改动的实现细节位于 `lib/providers/settings_provider.dart`：
- 启动时调用 `ApiService.loadSavedBaseUrl()` 来加载浏览器保存的后端地址。
- 若无保存地址则使用页面 `Uri.base` 作为 fallback，从而避免将请求错误地发送到客户端本机的 `localhost`。
- 若 `displayFontId` 为 `'default'`，会从 `ApiService.getFontsList()` 取回字体列表并使用第一个字体的 `id` 作为默认。


---

## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── database/                    # 数据库层
│   ├── database.dart            # AppDatabase 定义
│   ├── tables.dart              # 数据表定义（5张表）
│   └── connection/              # 数据库连接（平台适配）
├── models/                      # 数据模型
├── providers/                   # Riverpod 状态管理
├── repositories/                # 数据仓库（CRUD 操作）
├── screens/                     # 页面
│   ├── home_screen.dart         # 主页（响应式布局）
│   ├── coin_list_screen.dart    # 纪念币列表（含时间轴）
│   ├── coin_edit_screen.dart    # 纪念币编辑/详情
│   ├── series_edit_screen.dart  # 系列编辑
│   └── settings_screen.dart     # 设置页（字体 + WebDAV）
├── services/                    # 服务层
│   ├── sync_service.dart        # WebDAV 同步服务
│   ├── image_service.dart       # 图片处理服务
│   └── font_manager.dart        # 字体管理服务
├── utils/                       # 工具
│   ├── pdf_helper.dart          # PDF 生成
│   └── export_helper*.dart      # 导出（平台适配）
└── widgets/                     # 可复用组件
    ├── coin_image_widget.dart   # 图片组件
    └── series_list_drawer.dart  # 系列侧边栏
```

---

## 开源协议

本项目采用 **MIT License** — 详见 [LICENSE](LICENSE) 文件。

---

## 致谢

- [Flutter](https://flutter.dev/) — 优秀的跨平台框架
- [Drift](https://drift.simonbinder.eu/) — 强大的 SQLite ORM
- [Riverpod](https://riverpod.dev/) — 优雅的状态管理方案
- 所有开源依赖的维护者们
