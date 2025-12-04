# Project Log

## 2025-12-04
- **[OPTIMIZE] Reader Page Status UI**：优化阅读页面四角状态UI的边距适配
    - 水平边距从 `8%` 改为 `2%`，使UI更贴近屏幕边缘
    - 底部边距从固定 `15px` 改为 `1%屏高`，实现响应式适配不同分辨率
- **[REWRITE] 高性能分页器 v2.0**：重写 `optimized_stable_paginator.dart`
    - **核心优化**：用二分法按行测量替代逐字符测量，速度提升 100x+
    - **智能断行**：在标点符号（。！？等）处自然断开
    - **配置一致性**：TextPainter 与 Text 渲染配置完全一致，确保分页精确
- **[FIX] 分页区域避开四角UI**：
    - 修改 `getResponsivePadding`：顶部=1%屏高+44+8px，底部=1%屏高+30+8px
    - 行数向下取整（18.9行→18行），确保文字不溢出

## 2025-11-29
- **[NEW] iOS Migration**: Started the migration from Flutter to Native iOS.
    - Created `iOS_PROJECT_PLAN.md` with migration roadmap.
    - **Project Structure**: Code migrated to `xxread-ios/xxread/xxread`.
    - **Infrastructure**:
        - Implemented `NetworkManager` (URLSession).
        - Implemented `DatabaseManager` (SwiftData) and Models (`Book`, `BookSource`).
        - Implemented `AppTheme` and `ThemeManager`.
    - **Features**:
        - Implemented `HomeView` with TabView navigation.
        - Implemented `DashboardView` (Stats & Recent).
        - **Bookshelf**:
            - Implemented `BookshelfView` with grid display.
            - **[NEW] EPUB Import**: Added `EPUBParser` for EPUB file support.
            - **[NEW] Auto-format Detection**: Updated import to detect TXT/EPUB.
            - Updated `DocumentPicker` to accept `.epub` files.
        - **Reader Engine**:
            - Implemented `BookParser` for text processing (now supports EPUB).
            - Implemented `Paginator` using TextKit for layout calculation.
            - Implemented `ReaderViewModel` for state management.
            - Implemented `ReaderView` with tap-to-turn-page and immersive UI.
            - Implemented Reader Settings (Font Size, Theme).
            - Implemented Progress Saving.
        - **Book Source Management**:
            - Created `OnlineBookSource` model with rule structures.
            - Implemented `BookSourceService` for CRUD operations.
            - Implemented `BookSourceView` and `BookSourceViewModel`.
            - Added JSON import functionality.
    - **[FIX] Critical Bugs**:
        - Fixed `OnlineBookSource` enum duplicate key issue.
        - Fixed syntax error in `BookSourceService.swift`.
        - Added missing `import Combine`.
        - Fixed UIColor conversion in `Paginator.swift`.
    - **[NEW] File Import**: Implemented `DocumentPicker` for TXT and EPUB import.
    - **[NEW] Settings**: Implemented `SettingsView` with theme switching.
