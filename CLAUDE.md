# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

**小元读书 (xxread)** - 优雅的 Flutter 跨平台电子书阅读器，支持多种书籍格式（EPUB、PDF、TXT），提供舒适的阅读体验。

**技术栈：** Flutter 3.8+ / Dart 3.8+ / SQLite / Riverpod / vector_math

**项目规模：** 79 个 Dart 文件，跨平台支持（Android/iOS/macOS/Windows）

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

### 项目结构

```
lib/
├── main.dart                      # 应用入口，配置全局主题
├── l10n/                          # 国际化 (中文/英文)
│   ├── app_*.arb                  # 翻译资源
│   └── app_localizations*.dart    # 生成代码
├── models/                        # 数据模型层 (9个文件)
│   ├── book.dart                  # 书籍模型
│   ├── chapter.dart               # 章节模型
│   ├── bookmark.dart              # 书签模型
│   ├── book_note.dart             # 笔记模型
│   ├── book_source.dart           # 书源模型
│   ├── page_turning_config.dart   # 翻页配置
│   ├── text_page_data.dart        # 文本页面数据
│   ├── highlight.dart             # 兼容层
│   └── note.dart                  # 兼容层
├── providers/                     # 状态管理层 (Riverpod)
│   └── reader_providers.dart      # 阅读器核心Provider
├── pages/                         # 页面组件层 (10个文件)
│   ├── reader_page.dart           # 阅读页面（核心）
│   ├── home_page_responsive.dart  # 首页容器
│   ├── home_content_enhanced.dart # 首页内容
│   ├── library_page.dart          # 书库页面
│   ├── import_book_page.dart      # 导入书籍页面
│   ├── settings_page.dart         # 设置页面
│   ├── book_source_page.dart      # 书源管理页面
│   ├── detailed_stats_page.dart   # 详细统计页面
│   ├── user_agreement_page.dart   # 用户协议页面
│   └── cover_pagination_view.dart # 覆盖翻页视图
├── services/                      # 业务逻辑层 (30+个文件)
│   ├── app_state_service.dart     # 应用状态服务
│   ├── data_manager.dart          # 数据管理器
│   ├── database_service.dart      # 数据库服务
│   ├── enhanced_database_service.dart # 增强数据库服务
│   ├── book_dao.dart              # 书籍数据访问
│   ├── bookmark_dao.dart          # 书签数据访问
│   ├── book_note_dao.dart         # 笔记数据访问
│   ├── reading_stats_dao.dart     # 统计数据访问
│   ├── book_source_dao.dart       # 书源数据访问
│   ├── book_import_service.dart   # 书籍导入服务
│   ├── book_import_isolate.dart   # 导入隔离进程
│   ├── enhanced_txt_import_service.dart  # TXT导入服务
│   ├── enhanced_paginator.dart    # 核心分页器 v2.0
│   ├── pagination_cache_service.dart  # 分页缓存
│   ├── reading_router_service.dart    # 阅读路由
│   ├── reader_settings_service.dart   # 阅读设置持久化
│   ├── reading_progress_service.dart  # 阅读进度
│   ├── text_preprocessor.dart     # 文本预处理
│   ├── book_image_manager.dart    # 书籍图片缓存
│   ├── epub_image_extractor.dart  # EPUB图片提取
│   ├── book_image_map_service.dart # 图片路径映射
│   ├── cover_generator.dart       # 封面生成
│   ├── tts_service.dart           # TTS服务入口
│   ├── tts/                       # TTS模块
│   │   ├── base_tts.dart          # TTS基类
│   │   ├── system_tts.dart        # 系统TTS实现
│   │   └── tts_preferences.dart   # TTS偏好设置
│   └── sync/                      # 同步模块
│       ├── webdav_sync_service.dart # WebDAV同步
│       └── sync_utils.dart        # 同步工具
├── utils/                         # 工具类层 (7个文件)
│   ├── responsive_helper.dart     # 响应式布局辅助
│   ├── app_themes.dart            # 应用主题
│   ├── glass_config.dart          # 毛玻璃效果配置
│   ├── progressive_blur.dart      # 渐进式模糊
│   ├── theme_mixin.dart           # 主题混合
│   ├── page_transitions.dart      # 页面转场
│   └── encoding_detector_helper.dart # 编码检测辅助
└── widgets/                       # 自定义组件层 (9个文件)
    ├── toc_widget.dart            # 目录组件
    ├── enhanced_text_selection_toolbar.dart  # 文本选择工具栏
    ├── highlight_color_picker.dart # 高亮颜色选择器
    ├── tts_settings_sheet.dart    # TTS设置面板
    ├── page_turning_settings_sheet.dart # 翻页设置面板
    ├── webdav_config_dialog.dart  # WebDAV配置对话框
    ├── side_toast.dart            # 侧边提示
    ├── tap_zone_diagram.dart      # 点击区域示意
    └── scrolling_text.dart        # 滚动文本组件
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
- **EnhancedPaginator** (`lib/services/enhanced_paginator.dart`) - 主要分页器
  - 纯二分法实现高性能分页
  - 支持图片混合内容分页
  - 图片独占一页，通过 `<img src="绝对路径" data-height="高度"/>` 标记
- **渐进式分页**：
  - 阶段1: 快速采样前10页，立即显示
  - 阶段2: 后台精确计算全部页数
  - 分页结果通过 `PaginationCacheService` 缓存到本地磁盘

**阅读设置 (ReaderSettings)：**
- 字体大小、行距、字间距、页边距
- 阅读主题（8种预设 + 自定义）
- 翻页模式（cover/slide/scroll/simulation）
- 首行缩进、段落间距
- 响应式边距（平板/手机自适应）

**翻页模式实现：**
| 模式 | 组件 | 特点 |
|------|------|------|
| 覆盖 | `_CoverPaginationView` | 模拟真实翻页效果 |
| 滑动 | `_SlidePaginationView` | 左右滑动切换 |
| 滚动 | `_ScrollPaginationView` | 连续滚动 |
| 仿真 | `_SimulationPaginationView` | 3D翻页动画 |

### 数据库架构

**核心表结构：**
```sql
books                 -- 书籍信息表
├── id                -- 主键
├── title             -- 书名
├── author            -- 作者
├── file_path         -- 文件路径
├── format            -- 格式(txt/epub/pdf)
├── current_page      -- 当前页码
├── total_pages       -- 总页数
├── cached_content    -- 缓存内容(大文本)
├── cached_pages      -- 缓存分页数据(JSON)
├── content_hash      -- 内容哈希(用于增量更新)
├── cover_image_path  -- 封面图片路径
└── text_encoding     -- TXT编码

bookmarks             -- 书签表
├── id
├── book_id
├── page_index
├── chapter_title
├── created_at

book_notes            -- 笔记/高亮统一表
├── id
├── book_id
├── page_index
├── content           -- 笔记内容
├── note_type         -- 类型(highlight/note)
├── color             -- 高亮颜色
├── created_at

reading_stats         -- 阅读统计表
├── id
├── book_id
├── date              -- 阅读日期
├── duration_seconds  -- 阅读时长
├── pages_read        -- 阅读页数

book_sources          -- 书源表
├── id
├── source_name       -- 书源名称
├── source_url        -- 书源URL
├── enabled           -- 是否启用
```

**数据访问层 (DAO)：**
- `BookDao` - 书籍CRUD、进度更新、分页缓存
- `BookmarkDao` - 书签CRUD
- `BookNoteDao` - 笔记CRUD
- `ReadingStatsDao` - 统计数据CRUD
- `BookSourceDao` - 书源CRUD
- 所有数据库操作通过 DAO 层进行，数据库版本管理：`DatabaseService`

### 书籍导入流程

```
BookImportService.importBook()
    ├── 格式检测（BookImportService 内部）
    ├── TXT → EnhancedTxtImportService
    │   ├── 编码检测 (GBK/UTF-8/UTF-16)
    │   ├── TextPreprocessor (格式化、缩进、空行压缩)
    │   └── 章节提取 (可选)
    ├── EPUB → EpubImageExtractor
    │   ├── 提取图片到 app_flutter/book_images/
    │   ├── BookImageMapService (路径映射)
    │   └── 解析文本内容
    └── PDF → Pdfx (直接渲染)
```

**图片处理策略：**
- EPUB 图片在导入时提取到 `app_flutter/book_images/{bookId}/`
- 使用 `BookImageMapService` 管理原始路径到本地路径的映射
- 分页时图片标记为 `<img src="/path/to/image" data-height="高度"/>`
- 图片高度按页面宽度比例计算（默认占页面45%高度）

### TTS 朗读系统

**架构设计：**
```
TtsService (ChangeNotifier)
    └── SystemTts (系统TTS实现)
        ├── Android: TextToSpeech
        ├── iOS: AVSpeechSynthesizer
        └── TtsPreferences (语速/音调/音量/引擎偏好)
```

**核心功能：**
- 朗读时根据当前页内句子高亮显示
- 支持语速、音调、音量调节
- 支持定时停止
- 支持跳过当前句子

### WebDAV 同步

- **文件位置：** `lib/services/sync/webdav_sync_service.dart`
- **同步内容：**
  - 书籍元数据（不含大字段）
  - 书签
  - 阅读进度
  - 笔记/高亮
  - 书籍文件（可选）
- **差异化同步：** 只传输变更字段，减少网络流量
- **冲突处理：** 基于时间戳的自动合并

### 全屏处理 (Android/iOS)

**Android：**
- 使用原生方法通道 `com.niki.xxread/fullscreen`
- MainActivity 配置 `edge-to-edge` 模式
- 优先调用原生 `hideSystemUI()` / `showSystemUI()`
- 后备方案：`SystemChrome.setEnabledSystemUIMode()`

**iOS：**
- 使用 `SystemChrome.setEnabledSystemUIMode()`
- 先切换到 `edgeToEdge`，再切换到 `immersive`
- 使用100ms延迟确保状态栏能正确隐藏

**调用时机：**
- 进入阅读页面：调用 `_hideSystemUI()`
- 工具栏显示：调用 `_showSystemUI()`
- 工具栏隐藏：调用 `_hideSystemUI()`

## 开发规范

### 决策前必须询问

**需要用户确认的操作：**
1. 架构变更（添加/删除模块、修改项目结构）
2. 功能实现方案选择（多种实现方式）
3. 删除现有代码文件（除非明确是临时测试文件）
4. 配置修改（构建配置、依赖版本）
5. UI/UX 修改（设计、布局、颜色）

**可直接执行的操作：**
1. 明确的 Bug 修复（编译错误、运行时错误、逻辑错误）
2. 性能优化（不改变功能前提下）
3. 代码格式化、添加注释
4. 删除明显的冗余代码

### 代码风格

- **注释：** 使用中文，关键操作添加 emoji 标记（📖 📄 ✅ ❌ ⚠️）
- **日志：** 重要状态变化使用 `debugPrint` 输出
- **命名：**
  - 类名：大驼峰 `ReaderPage`
  - 方法/变量：小驼峰 `currentPage`
  - 私有成员：前缀下划线 `_currentPage`
  - 常量：小驼峰前缀下划线 `maxLines`
- **不使用其他项目名称**（如 Legado），使用简洁明了的命名

### UI/UX 约束

- **禁止随意修改 UI 风格**，未经用户允许不得更改设计、布局、颜色
- **禁止删除或简化功能**，不能通过删除代码来"解决"问题
- **保持设计一致性**，维护项目现有的设计语言
- **响应式设计：** 使用 `ResponsiveHelper` 判断设备类型

### Reader Page 构建约束

- 必须使用 Riverpod 进行状态管理
- 阅读分页复用 `EnhancedPaginator` 和 `PaginationCacheService`
- UI 分层：根组件 `ReaderPage` 负责组合子组件；复杂组件独立成私有类
- 工具栏动画使用 `AnimationController` + `FadeTransition`/`SlideTransition`，禁止使用隐式动画
- 每种翻页模式封装为独立 widget：`_CoverPaginationView`, `_SlidePaginationView` 等

### 数据库操作规范

- 所有数据库操作必须通过 DAO 层
- 禁止在 UI 线程执行耗时数据库操作
- 使用事务处理批量操作
- 大字段（如 cached_content）谨慎使用，考虑增量更新

### 测试验证流程

代码修改后必须执行：
```bash
flutter analyze --no-fatal-infos   # 修复所有错误和警告
dart format .                      # 格式化代码
flutter test                       # 运行测试
flutter build apk --debug          # 验证构建
```

## 关键文件索引

### 核心文件

| 文件 | 用途 | 重要程度 |
|------|------|----------|
| [lib/main.dart](lib/main.dart) | 应用入口，主题配置 | ⭐⭐⭐ |
| [lib/pages/reader_page.dart](lib/pages/reader_page.dart) | 阅读页面主组件 | ⭐⭐⭐⭐⭐ |
| [lib/providers/reader_providers.dart](lib/providers/reader_providers.dart) | 阅读器状态管理 | ⭐⭐⭐⭐⭐ |

### 分页系统

| 文件 | 用途 | 重要程度 |
|------|------|----------|
| [lib/services/enhanced_paginator.dart](lib/services/enhanced_paginator.dart) | 核心分页器 v2.0 | ⭐⭐⭐⭐⭐ |
| [lib/services/pagination_cache_service.dart](lib/services/pagination_cache_service.dart) | 分页缓存服务 | ⭐⭐⭐⭐ |
| [lib/services/reading_router_service.dart](lib/services/reading_router_service.dart) | 阅读器入口路由 | ⭐⭐⭐⭐ |
| [lib/services/text_preprocessor.dart](lib/services/text_preprocessor.dart) | 文本预处理 | ⭐⭐⭐ |

### 数据层

| 文件 | 用途 | 重要程度 |
|------|------|----------|
| [lib/services/database_service.dart](lib/services/database_service.dart) | 数据库版本管理 | ⭐⭐⭐⭐ |
| [lib/services/book_dao.dart](lib/services/book_dao.dart) | 书籍数据访问 | ⭐⭐⭐⭐ |
| [lib/services/bookmark_dao.dart](lib/services/bookmark_dao.dart) | 书签数据访问 | ⭐⭐⭐ |
| [lib/services/book_note_dao.dart](lib/services/book_note_dao.dart) | 笔记数据访问 | ⭐⭐⭐ |
| [lib/services/reading_stats_dao.dart](lib/services/reading_stats_dao.dart) | 统计数据访问 | ⭐⭐⭐ |

### 导入系统

| 文件 | 用途 | 重要程度 |
|------|------|----------|
| [lib/services/book_import_service.dart](lib/services/book_import_service.dart) | 书籍导入服务 | ⭐⭐⭐⭐ |
| [lib/services/enhanced_txt_import_service.dart](lib/services/enhanced_txt_import_service.dart) | TXT导入服务 | ⭐⭐⭐⭐ |
| [lib/services/epub_image_extractor.dart](lib/services/epub_image_extractor.dart) | EPUB图片提取 | ⭐⭐⭐ |
| [lib/services/book_image_map_service.dart](lib/services/book_image_map_service.dart) | 图片路径映射 | ⭐⭐⭐ |

### TTS系统

| 文件 | 用途 | 重要程度 |
|------|------|----------|
| [lib/services/tts/base_tts.dart](lib/services/tts/base_tts.dart) | TTS基类 | ⭐⭐⭐⭐ |
| [lib/services/tts/system_tts.dart](lib/services/tts/system_tts.dart) | 系统TTS实现 | ⭐⭐⭐⭐ |
| [lib/services/tts/tts_preferences.dart](lib/services/tts/tts_preferences.dart) | TTS偏好设置 | ⭐⭐⭐ |

### 同步系统

| 文件 | 用途 | 重要程度 |
|------|------|----------|
| [lib/services/sync/webdav_sync_service.dart](lib/services/sync/webdav_sync_service.dart) | WebDAV同步 | ⭐⭐⭐ |

### 页面组件

| 文件 | 用途 | 重要程度 |
|------|------|----------|
| [lib/pages/home_page_responsive.dart](lib/pages/home_page_responsive.dart) | 首页容器 | ⭐⭐⭐⭐ |
| [lib/pages/home_content_enhanced.dart](lib/pages/home_content_enhanced.dart) | 首页内容 | ⭐⭐⭐⭐ |
| [lib/pages/library_page.dart](lib/pages/library_page.dart) | 书库页面 | ⭐⭐⭐⭐ |
| [lib/pages/import_book_page.dart](lib/pages/import_book_page.dart) | 导入书籍 | ⭐⭐⭐ |
| [lib/pages/settings_page.dart](lib/pages/settings_page.dart) | 设置页面 | ⭐⭐⭐ |
| [lib/pages/book_source_page.dart](lib/pages/book_source_page.dart) | 书源管理 | ⭐⭐ |

### 自定义组件

| 文件 | 用途 | 重要程度 |
|------|------|----------|
| [lib/widgets/toc_widget.dart](lib/widgets/toc_widget.dart) | 目录组件 | ⭐⭐⭐ |
| [lib/widgets/tts_settings_sheet.dart](lib/widgets/tts_settings_sheet.dart) | TTS 设置面板 | ⭐⭐⭐ |
| [lib/widgets/page_turning_settings_sheet.dart](lib/widgets/page_turning_settings_sheet.dart) | 翻页设置面板 | ⭐⭐⭐ |
| [lib/widgets/enhanced_text_selection_toolbar.dart](lib/widgets/enhanced_text_selection_toolbar.dart) | 文本选择工具栏 | ⭐⭐⭐ |
| [lib/widgets/highlight_color_picker.dart](lib/widgets/highlight_color_picker.dart) | 高亮颜色选择 | ⭐⭐⭐ |
| [lib/widgets/webdav_config_dialog.dart](lib/widgets/webdav_config_dialog.dart) | WebDAV 配置 | ⭐⭐⭐ |
| [lib/widgets/side_toast.dart](lib/widgets/side_toast.dart) | 侧边提示 | ⭐⭐⭐ |

### 工具类

| 文件 | 用途 | 重要程度 |
|------|------|----------|
| [lib/utils/responsive_helper.dart](lib/utils/responsive_helper.dart) | 响应式布局辅助 | ⭐⭐⭐⭐ |
| [lib/utils/app_themes.dart](lib/utils/app_themes.dart) | 应用主题 | ⭐⭐⭐ |
| [lib/utils/glass_config.dart](lib/utils/glass_config.dart) | 毛玻璃配置 | ⭐⭐⭐ |
| [lib/utils/progressive_blur.dart](lib/utils/progressive_blur.dart) | 渐进式模糊 | ⭐⭐⭐ |
| [lib/utils/page_transitions.dart](lib/utils/page_transitions.dart) | 页面转场 | ⭐⭐⭐ |
| [lib/utils/encoding_detector_helper.dart](lib/utils/encoding_detector_helper.dart) | 编码检测辅助 | ⭐⭐⭐ |

## 常见问题

### 分页结果不准确
**症状：** 分页后的文本显示与预期不符，出现截断或留白

**排查步骤：**
1. 检查 TextPainter 配置是否与 Text Widget 一致
2. 确认行高、字间距等参数正确传递
3. 验证 `EnhancedPaginator` 的 `pageSize` 计算
4. 检查是否有图片高度计算错误
5. 确认响应式 padding 计算是否正确

### 图片显示异常
**症状：** 图片无法显示或路径错误

**排查步骤：**
1. 验证图片文件路径是否存在
2. 检查 `BookImageMapService` 映射是否正确
3. 确认图片格式支持（支持 JPG、PNG、GIF）
4. 检查图片是否正确提取到 `app_flutter/book_images/`

### 全屏不生效（Android）
**症状：** 状态栏或导航栏无法隐藏

**排查步骤：**
1. 确认 MainActivity 配置了 `edge-to-edge` 模式
2. 检查是否正确调用了原生方法通道
3. 验证方法通道名称 `com.niki.xxread/fullscreen`
4. 检查 `_hideSystemUI()` 是否在 `initState` 后调用

### 性能问题
**症状：** 页面卡顿、加载缓慢

**排查步骤：**
1. 启用分页缓存 (`PaginationCacheService`)
2. 检查是否有重复分页计算
3. 考虑使用渐进式分页
4. 使用 Flutter DevTools 监控性能
5. 检查大字段查询是否必要

### 平板首页改动未生效
**症状：** 平板上修改首页代码后没有变化

**原因：**
- 首页在侧边导航模式下，`HomeContentEnhanced` 的宽度会被 `NavigationRail` 压缩
- 原始判断使用 `ResponsiveHelper.isTablet(context)` 依赖 `MediaQuery` 宽度
- 当宽度被导航栏占用后，判断可能变成"非平板"，导致走了手机布局

**修复方式：**
改为基于 `NavigationContext.useRailNavigation` 判定（只要是侧边导航就走平板布局）

### 编码问题（TXT）
**症状：** TXT 文件显示乱码

**排查步骤：**
1. 检查 `EnhancedTxtImportService` 编码检测结果
2. 尝试手动切换编码（GBK/UTF-8/UTF-16）
3. 确认文件是否为 BOM 格式
4. 检查 `TextPreprocessor` 是否正确处理换行符

## 知识库

技术方案和问题解决记录存放在项目根目录：
- `knowledge_base/pagination_research_2025.md` - 分页技术调研
- `knowledge_base/LEGADO_PAGINATION_IMPLEMENTATION.md` - 分页实施计划
- `knowledge_base/text_pagination_solutions.md` - 文本分页方案

## 更新记录

### 2025-12-25
- 修复 Android 全屏问题（使用原生方法通道）
- 清理 16+ 个代码质量问题
- 删除冗余代码（重复方法、未使用文件）
- 更新弃用 API（activeColor → activeThumbColor, scale → scaleByVector3, RadioListTile → RadioGroup）
- 优化代码结构

### 2025-12-23
- 清理根目录临时文档（14个英文标题文档）
- 更新 CLAUDE.md 架构说明

### 2025-01-19
- 清理未使用的分页器文件
- 创建本文档

---

**记住：遇到不确定的决策时，先询问，再执行！**
