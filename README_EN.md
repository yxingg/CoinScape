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

