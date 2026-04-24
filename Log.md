# Project Log

## 2026-04-16
- **[NEW] Foliate Reader**: 新增 `lib/pages/foliate_reader_page.dart`。
    - **混合架构**：采用 Foliate (WebView) 渲染底层，保留 Flutter 原生控制 UI。
    - **交互同步**：实现 JS Bridge 同步主题（CSS 注入）、排版设置（字号/行高）、进度更新和目录提取。
    - **原生增强**：在 WebView 之上集成了 Flutter 编写的毛玻璃控制面板、全书进度条和原生目录列表。
- **[CLEANUP] 移除自研内核渲染层**: 
    - 删除 `lib/pages/reader_kernel_page.dart` 和 `lib/pages/epub_foliate_reader_page.dart`。
    - 删除 `lib/reader_core/renderer/` 和 `lib/reader_core/paginator/`。
    - 统一阅读入口至 `ReadingRouterService`，默认启用新混合阅读器。
- **[DOC] 文档同步**: 
    - 更新 `Log.md` 并新建 `Project.md` 以反映最新的混合架构索引。

## 2026-03-28
- **[DOC] 根目录阅读总文档**：新增 `/Users/xiaoyuan/work/Origo Reader/reading-architecture.md`
    - 将 Legado TXT/EPUB 阅读机制与跨平台可行性分析合并成一份总文档
    - 放置到 `Origo Reader` 根目录，使用更短文件名，便于作为统一入口阅读
- **[DOC] Legado 阅读架构拆解**：新增 `knowledge_base/LEGADO_TXT_EPUB_READING_ARCHITECTURE.md`
    - 系统分析 Legado 的 TXT 阅读链路：编码探测、目录规则选择、正则分章、无规则兜底、按字节偏移读取正文
    - 系统分析 Legado 的 EPUB 阅读链路：`epublib` 懒加载、TOC/spine 双路径建目录、fragment 级切章、XHTML 清洗、图片资源读取与章节缓存
    - 总结 TXT 与 EPUB 在 `ContentProcessor + TextChapterLayout` 上汇合的统一阅读内核
- **[DOC] Legado 方案跨平台可行性分析**：新增 `knowledge_base/LEGADO_SCHEME_CROSS_PLATFORM_ANALYSIS.md`
    - 按 Android、iOS、Flutter、桌面、Web、OHOS、Server 逐一评估这套方案的可迁移性
    - 明确哪些能力适合跨平台共享，哪些必须按平台重写
    - 给出面向当前 `OpenReading` 多端工程的推荐推进顺序与技术取舍

## 2025-12-15
- **[FIX] 分页算法优化**：修复"最后一行只显示一个字"的问题
    - 在高度计算时减去 2px 安全裕度，避免浮点精度问题导致文字溢出
    - 二分查找使用严格高度比较（去掉容差）
    - 扩大初始搜索范围从 2x 到 3x，避免估算不准导致过早终止
- **[FIX] 删除书籍彻底清理**：删除书籍时同步清理阅读进度缓存
    - 在 `_performBookDeletion` 中添加 `ReadingProgressService.clearProgress()` 调用
    - 确保删除书籍时彻底清理：书籍文件、封面、分页缓存、阅读进度、数据库记录

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
