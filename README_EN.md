# CoinScape 🪙

> Coin Collection Manager — Easily manage your commemorative coin collection

---

## Introduction

CoinScape is a cross-platform commemorative coin collection management app built with Flutter. It helps collectors systematically manage their coin collections, supporting series grouping, batch operations, timeline browsing, image management, PDF export, and WebDAV cloud sync backup.

Supports **Windows**, **Android**, and **Web** platforms.

---

## Features

### 📦 Series Management
- Create, edit, and delete series (a series is a thematic group for your coins, e.g., "Chinese Zodiac Series", "Olympic Commemorative Coins")
- Left sidebar series list supports fixed display or manual toggle to adapt to different screen widths
- Long press for multi-selection in series list; batch delete, PDF export, or CCM data export supported after selection

### 🪙 Coin Management
- Add, edit, and delete coins with the following fields:
  - **Basic Info**: Name, year, denomination, country
  - **Physical Attributes**: Material, weight (g), diameter (mm)
  - **Issue Info**: Mintage, issue date
  - **Collection Info**: Collection date, purchase price (unit price × quantity), condition grade, notes
- Coin list sorts by collection date (falls back to creation date if collection date is not set)
- Cross-series multi-selection supported; batch delete, batch add to a series, or remove from all series

### 🖼️ Image Management
- Add images to coins and series (take photo or pick from gallery)
- Image preview maintains original aspect ratio (no stretching)
- Support for multiple images per item

### ⏱️ Timeline
- Right-side timeline displays coin distribution by year
- Click a year to quickly jump to coins from that year
- Interactive navigation for browsing collections across years

### 📄 PDF Export
- Export coin collection information to PDF files
- Support single or batch export
- Preview or share directly within the app

### ☁️ WebDAV Cloud Sync
- Backup data to cloud storage via WebDAV protocol (supports NextCloud, Nutstore, etc.)
- Manual backup (Push) and restore (Pull)
- Backup/Restore buttons located at the top-right corner of the main page for easy access
- Data stored as compressed archives for security and reliability

### 🔍 Search & Filter
- Search coins by name
- Filter coins by series

### 🎨 Material 3 Design
- Built with Material Design 3
- Customizable theme colors
- Responsive layout adapting to desktop and mobile

---

## Tech Stack

| Technology | Purpose |
|------------|---------|
| [Flutter](https://flutter.dev/) | Cross-platform UI framework |
| [Riverpod](https://riverpod.dev/) | State management |
| [Drift](https://drift.simonbinder.eu/) | SQLite local database (Web-compatible) |
| [WebDAV Client](https://pub.dev/packages/webdav_client) | Cloud sync |
| [PDF](https://pub.dev/packages/pdf) | PDF generation |
| [Printing](https://pub.dev/packages/printing) | PDF printing/preview |
| [Share Plus](https://pub.dev/packages/share_plus) | File sharing |
| [Image Picker](https://pub.dev/packages/image_picker) | Image selection |
| [File Picker](https://pub.dev/packages/file_picker) | File selection |
| [Archive](https://pub.dev/packages/archive) | Compression |
| [Intl](https://pub.dev/packages/intl) | Internationalization/date formatting |

---

## Quick Start

### Prerequisites

- Flutter SDK ^3.11.5
- Dart SDK ^3.11.5
- Supported platforms: Windows / Web / Android

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/coinscape.git
cd coinscape

# Install dependencies
flutter pub get

# Run (Windows)
flutter run -d windows

# Run (Web)
flutter run -d chrome

# Run (Android)
flutter run -d android
```

### Build

```bash
# Windows desktop
flutter build windows

# Web
flutter build web

# Android APK
flutter build apk

---

## Web deployment notes (backend & fonts)

- **Backend address priority:**
  - The web client will first try to load a saved backend address from browser storage (SharedPreferences / localStorage key = `backend_base_url`).
  - If no saved address is found, the web app will prefer the current page origin (`Uri.base`), i.e. the same host that served the static files. This avoids incorrectly targeting the client's `localhost`.
  - Only if neither is available will the default `http://localhost:9876` be used.
  - If you see `GET http://localhost:9876/api/settings net::ERR_CONNECTION_REFUSED` on a remote device, it means the client is still using the localhost default. You can temporarily save the correct backend address in the browser console:

    ```javascript
    localStorage.setItem('backend_base_url', 'http://10.168.72.54:9876');
    location.reload();
    ```

- **Font default strategy:**
  - The backend exposes fonts placed under `backend/data/fonts` via REST API: `GET /api/fonts/` returns a list of available fonts, and `GET /api/fonts/{font_id}` serves the font file.
  - When the front-end setting `displayFontId` is `default` (no explicit user selection), the app will request `/api/fonts/` at startup and automatically set the first font returned as the default display font. This means you can drop your preferred fonts into `backend/data/fonts/` and the app will pick the first one automatically.
  - Alternatively, you can bundle fonts into the Flutter app by placing them in `assets/fonts/` and registering them in `pubspec.yaml`.

- **About web renderer (CanvasKit / HTML):**
  - If fonts are packaged or served same-origin by the backend, the web page will not need to fetch fonts from external CDNs (e.g. `fonts.gstatic.com`). In that case, switching to `--web-renderer html` is generally **not required** to fix font loading problems.
  - To ensure the build does not rewrite static asset URLs to external CDNs, build with:

    ```bash
    flutter build web --no-web-resources-cdn
    ```

  - If you still encounter rendering differences on particular devices, switching renderers can be used for testing, but hosting fonts same-origin remains the recommended approach.

- **Implementation notes:**
  - The client-side startup logic lives in `lib/providers/settings_provider.dart`. It calls `ApiService.loadSavedBaseUrl()` to load any saved backend address, falls back to `Uri.base` when not saved, and — when `displayFontId` is `default` — calls `ApiService.getFontsList()` and picks the first available font as the default.

```

---

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── database/                    # Database layer
│   ├── database.dart            # AppDatabase definition
│   ├── tables.dart              # Table definitions (5 tables)
│   └── connection/              # Database connection (platform-specific)
├── models/                      # Data models
├── providers/                   # Riverpod state management
├── repositories/                # Data repository (CRUD operations)
├── screens/                     # Pages
│   ├── home_screen.dart         # Home page (responsive layout)
│   ├── coin_list_screen.dart    # Coin list (with timeline)
│   ├── coin_edit_screen.dart    # Coin edit/details
│   ├── series_edit_screen.dart  # Series edit
│   └── settings_screen.dart     # Settings (fonts + WebDAV)
├── services/                    # Service layer
│   ├── sync_service.dart        # WebDAV sync service
│   ├── image_service.dart       # Image processing service
│   └── font_manager.dart        # Font management service
├── utils/                       # Utilities
│   ├── pdf_helper.dart          # PDF generation
│   └── export_helper*.dart      # Export (platform-specific)
└── widgets/                     # Reusable components
    ├── coin_image_widget.dart   # Image widget
    └── series_list_drawer.dart  # Series sidebar
```

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## Acknowledgements

- [Flutter](https://flutter.dev/) — Excellent cross-platform framework
- [Drift](https://drift.simonbinder.eu/) — Powerful SQLite ORM
- [Riverpod](https://riverpod.dev/) — Elegant state management solution
- All open-source dependency maintainers

---

**Icons & Cleanup (English)**

- The new application icon file is located at the repository root: `图标.png`. To generate and apply launcher icons for platforms locally, follow these steps:

  ```bash
  flutter pub get
  flutter pub run flutter_launcher_icons:main
  ```

  This will use the `图标.png` file at the project root to generate and replace iOS / Android / desktop launcher icons. For Web, copy `图标.png` into the `web/` directory and replace `favicon.png` and files under `web/icons/`.

- Recommended cleanup (optional — confirm before removal):
  - `.kilo/`: local worktree/tool metadata — safe to remove from repository.
  - `build/`: Flutter build artifacts — should be ignored and removed from VCS to reduce repo size.
  - `backend/data/`: runtime data — usually should not be kept in repository; please confirm before deleting.

I can list and delete these candidates one by one; I'll ask for your confirmation before performing any removals.

