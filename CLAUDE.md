# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

**小元读书 (xxread)** - 优雅的 Flutter 跨平台电子书阅读器，支持多种书籍格式（EPUB、PDF、TXT），提供舒适的阅读体验。

**技术栈：** Flutter 3.4+ / Dart 3.4+ / SQLite / Riverpod

## 常用命令

```bash
# 开发流程
flutter pub get                    # 安装依赖
flutter run                        # 运行调试版本
flutter run --release              # 运行发布版本

# 代码质量
flutter analyze --no-fatal-infos   # 静态分析
dart format .                      # 代码格式化
flutter test                       # 运行测试

# 构建打包
flutter build apk                  # Android APK
flutter build ios                  # iOS
flutter build windows              # Windows
flutter build macos                # macOS

# 清理缓存
flutter clean                      # 清理构建缓存
```

## 核心架构

### 分层结构

```
lib/
├── models/           # 数据模型 (Book, Chapter, Bookmark, Note, Highlight)
├── providers/        # 状态管理 (Riverpod - reader_providers.dart)
├── pages/            # 页面组件 (reader_page.dart, home_page_responsive.dart)
├── services/         # 业务逻辑层
│   ├── enhanced_paginator.dart        # 核心分页器 v2.0
│   ├── pagination_cache_service.dart  # 分页缓存
│   ├── reading_router_service.dart    # 阅读路由
│   ├── text_preprocessor.dart         # 文本预处理
│   ├── book_import_service.dart       # 书籍导入
│   ├── database_service.dart          # 数据库服务
│   ├── tts_service.dart               # TTS 朗读
│   └── *_dao.dart                     # 数据访问对象
├── utils/            # 工具类
└── widgets/          # 自定义组件
```

### 阅读器核心架构 (reader_page.dart + reader_providers.dart)

**重要约束：** `reader_page.dart` 必须使用 Riverpod 状态管理。可使用 `ConsumerStatefulWidget` 作为壳组件（用于 `AnimationController`），但业务状态必须集中在 `StateNotifier`/`Notifier` 中。

**状态管理流程：**
```
ReadingRouterService.openBook()
    → ReaderPage (ConsumerStatefulWidget 壳)
        → ReaderPaginationNotifier (StateNotifier)
            → EnhancedPaginator.paginateProgressive()
                → PaginationCacheService (磁盘缓存)
```

**分页策略：**
- **EnhancedPaginator** (`lib/services/enhanced_paginator.dart`) - 主要分页器，使用纯二分法实现高性能分页
- 支持渐进式分页：快速采样前10页 → 后台精确计算全部
- 图片独占一页，通过 `<img src="绝对路径" />` 标记
- 分页结果通过 `PaginationCacheService` 缓存到本地磁盘

**阅读设置 (ReaderSettings)：**
- 字体大小、行距、字间距、页边距
- 阅读主题（8种预设）
- 翻页模式（cover/slide/scroll/simulation）
- 首行缩进、段落间距

### 数据库架构

**核心表：**
- `books` - 书籍信息（含封面、缓存内容、分页数据）
- `bookmarks` - 书签
- `book_notes` - 笔记/高亮统一系统
- `reading_stats` - 阅读统计
- `book_sources` - 书源系统

**数据访问层 (DAO)：**
- `BookDao`, `BookmarkDao`, `BookNoteDao`, `HighlightDao`, `ReadingStatsDao`
- 所有数据库操作通过 DAO 层进行
- 数据库版本管理：`DatabaseService`

### 书籍导入流程

```
BookImportService.importBook()
    ├── TXT → EnhancedTxtImportService → TextPreprocessor (格式化)
    ├── EPUB → EpubImageExtractor (提取图片) + BookImageMapService (路径映射)
    └── PDF  → Pdfx (直接渲染)
```

**图片处理：**
- EPUB 图片在导入时提取到 `app_flutter/book_images/`
- 使用 `BookImageMapService` 管理图片路径映射
- 分页时图片标记为 `<img src="/path/to/image" />`

### TTS 朗读系统

- 基类：`BaseTts` (lib/services/tts/base_tts.dart)
- 实现：`SystemTts` (lib/services/tts/system_tts.dart)
- 朗读时根据当前页内句子高亮显示

### WebDAV 同步

- `lib/services/sync/webdav_sync_service.dart`
- 支持书籍元数据、书签、进度、笔记、书籍文件同步
- 差异化同步：移除大字段，减少传输量

## 开发规范

### 决策前必须询问

**需要用户确认的操作：**
1. 架构变更（添加/删除模块、修改项目结构）
2. 功能实现方案选择（多种实现方式）
3. 删除现有代码文件（除非明确是临时测试文件）
4. 配置修改（构建配置、依赖版本）

**可直接执行的操作：**
1. 明确的 Bug 修复（编译错误、运行时错误、逻辑错误）
2. 性能优化（不改变功能前提下）
3. 代码格式化、添加注释

### 代码风格

- **注释：** 使用中文，关键操作添加 emoji 标记（📖 📄 ✅ ❌）
- **日志：** 重要状态变化使用 `debugPrint` 输出
- **命名：** 不使用其他项目名称（如 Legado），使用简洁明了的命名

### UI/UX 约束

- **禁止随意修改 UI 风格**，未经用户允许不得更改设计、布局、颜色
- **禁止删除或简化功能**，不能通过删除代码来"解决"问题
- **保持设计一致性**，维护项目现有的设计语言

### Reader Page 构建约束

- 必须使用 Riverpod 进行状态管理
- 阅读分页复用 `EnhancedPaginator` 和 `PaginationCacheService`
- UI 分层：根组件 `ReaderPage` 负责组合子组件；复杂组件独立成私有类
- 工具栏动画使用 `AnimationController` + `FadeTransition`/`SlideTransition`，禁止使用隐式动画
- 每种翻页模式封装为独立 widget：`_SlidePaginationView`, `_ScrollPaginationView` 等

### 测试验证流程

代码修改后必须执行：
```bash
flutter analyze --no-fatal-infos   # 修复所有错误和警告
dart format .                      # 格式化代码
flutter test                       # 运行测试
flutter build apk --debug          # 验证构建
```

## 关键文件索引

| 文件 | 用途 |
|------|------|
| [lib/services/enhanced_paginator.dart](lib/services/enhanced_paginator.dart) | 核心分页器 v2.0（二分法高性能分页）|
| [lib/services/pagination_cache_service.dart](lib/services/pagination_cache_service.dart) | 分页缓存服务 |
| [lib/services/reading_router_service.dart](lib/services/reading_router_service.dart) | 阅读器入口路由 |
| [lib/services/text_preprocessor.dart](lib/services/text_preprocessor.dart) | 文本预处理（缩进、空行压缩）|
| [lib/providers/reader_providers.dart](lib/providers/reader_providers.dart) | 阅读器状态管理（ReaderSettings, ReaderPaginationNotifier）|
| [lib/pages/reader_page.dart](lib/pages/reader_page.dart) | 阅读页面主组件 |
| [lib/services/database_service.dart](lib/services/database_service.dart) | 数据库版本管理 |
| [lib/services/book_import_service.dart](lib/services/book_import_service.dart) | 书籍导入服务 |

## 常见问题

### 分页结果不准确
- 检查 TextPainter 配置是否与 Text Widget 一致
- 确认行高、字间距等参数正确传递
- 验证 `EnhancedPaginator` 的 `pageSize` 计算

### 图片显示异常
- 验证图片文件路径是否存在
- 检查 `BookImageMapService` 映射是否正确
- 确认图片格式支持

### 性能问题
- 启用分页缓存 (`PaginationCacheService`)
- 检查是否有重复分页计算
- 考虑使用渐进式分页

## 知识库

技术方案和问题解决记录存放在 `knowledge_base/` 目录：
- [pagination_research_2025.md](knowledge_base/pagination_research_2025.md) - 分页技术调研
- [LEGADO_PAGINATION_IMPLEMENTATION.md](knowledge_base/LEGADO_PAGINATION_IMPLEMENTATION.md) - 分页实施计划
- [text_pagination_solutions.md](knowledge_base/text_pagination_solutions.md) - 文本分页方案

## 更新记录

### 2025-12-23
- 清理根目录临时文档（14个英文标题文档）
- 更新 CLAUDE.md 架构说明

### 2025-01-19
- 清理未使用的分页器文件
- 创建本文档

---

**记住：遇到不确定的决策时，先询问，再执行！**
