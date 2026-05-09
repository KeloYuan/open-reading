# Open Reading · 小元阅读器

A cross-platform ebook reader built with Flutter.

English name: **Open Reading**
Chinese name: **小元阅读器**

## Features

- 📖 Multi-format support — EPUB, PDF, TXT
- 📄 Smart pagination with layout-aware caching
- 🔊 Text-to-Speech (TTS) reading
- ☁️ WebDAV sync across devices
- 🔖 Bookmarks, highlights & notes
- 📊 Reading statistics
- 🌍 Internationalization (i18n)
- 🖥️ Runs on Android, iOS, macOS, Windows

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x / Dart 3.x |
| State Management | Riverpod + Provider |
| Local Storage | SQLite |
| Reader Engine | WebView (Foliate) + Native Reader Core |
| Backend Sync | WebDAV / Supabase |

## Getting Started

```bash
# Clone the repo
git clone https://github.com/KeloYuan/open-reading.git
cd open-reading

# Install dependencies
flutter pub get

# Run
flutter run
```

## Build

```bash
# Android
flutter build apk

# iOS
flutter build ios

# macOS
flutter build macos

# Windows
flutter build windows
```

## Project Structure

```
lib/
├── main.dart              # Entry point
├── models/                # Data models (books, chapters, bookmarks)
├── pages/                 # UI pages & home components
├── reader_core/           # Reader engine core (parser, document model)
├── services/              # Business services (import, DAO, sync, reading, TTS)
├── utils/                 # Themes, layout, encoding utilities
├── widgets/               # Reusable UI components
└── l10n/                  # Generated localization files
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is currently private. All rights reserved.
