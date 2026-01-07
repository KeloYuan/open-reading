# 小元读书 - 代码库索引

> 更新：2025-01-07
> 目的：快速理解项目结构、核心流程与关键文件入口

## 快速入口（从这里开始读）

- `lib/main.dart`：应用入口、主题与 Provider/Riverpod 初始化
- `lib/pages/reader_page.dart`：阅读器核心 UI（最大文件）
- `lib/providers/reader_providers.dart`：阅读器核心状态管理
- `lib/services/enhanced_paginator.dart`：文本分页核心算法
- `lib/services/pagination_cache_service.dart`：分页缓存
- `lib/services/reading_router_service.dart`：阅读器入口路由
- `lib/services/book_import_service.dart`：书籍导入入口

## 架构分层（简化视角）

- UI 层：`lib/pages/` + `lib/widgets/`
- 状态层：`lib/providers/`（Riverpod）+ `main.dart` 内 Provider 初始化
- 业务服务层：`lib/services/`
- 数据模型层：`lib/models/`
- 平台层：`android/`、`ios/`、`macos/`、`windows/`、`linux/`、`web/`
- 资源层：`assets/`、`assets/foliate-js/`

## 核心流程

### 启动流程

`main.dart`
→ `DataManager.initialize()`
→ `ReadingEngineCoordinator.ensureInitialized()`
→ `BookImageManager.initialize()`
→ `runApp()`（Riverpod + Provider）

### 阅读流程（文本分页）

`ReadingRouterService.openBook()`
→ `ReaderPage`
→ `ReaderProviders`（分页、主题、阅读设置）
→ `EnhancedPaginator.paginateProgressive()`
→ `PaginationCacheService`（磁盘缓存）

### 导入流程

`BookImportService.importBook()`
→ TXT：`EnhancedTxtImportService` + `TextPreprocessor`
→ EPUB：`EpubImageExtractor` + `BookImageMapService`
→ PDF：`pdfx` 直接渲染

### 同步流程（WebDAV）

`WebDavSyncService`
→ 同步书籍元数据、书签、进度、笔记（依赖 `BookNoteDao` 等 DAO）

## 文件索引

### lib/

- `main.dart`：应用入口
- `l10n/`：多语言资源与生成代码

#### lib/models/
- `book.dart`：书籍模型
- `book_note.dart`：统一笔记/高亮模型
- `bookmark.dart`：书签模型
- `chapter.dart`：章节模型
- `book_source.dart`：书源模型
- `page_turning_config.dart`：翻页配置
- `text_page_data.dart`：分页数据结构
- `highlight.dart`：兼容层（BookNote 包装）
- `note.dart`：兼容层（BookNote 包装）

#### lib/providers/
- `reader_providers.dart`：阅读器核心 Provider

#### lib/pages/
- `reader_page.dart`：阅读页（核心）
- `home_page_responsive.dart`：响应式首页
- `home_content_enhanced.dart`：首页内容
- `library_page.dart`：书库管理
- `import_book_page.dart`：导入页面
- `settings_page.dart`：设置页面
- `book_source_page.dart`：书源管理
- `detailed_stats_page.dart`：阅读统计详情
- `user_agreement_page.dart`：用户协议
- `cover_pagination_view.dart`：覆盖翻页视图

#### lib/services/
- `app_state_service.dart`：应用状态
- `data_manager.dart`：数据初始化与管理
- `database_service.dart`：数据库服务
- `enhanced_database_service.dart`：增强数据库服务（事务/健康检查）
- `book_dao.dart`：书籍 DAO
- `bookmark_dao.dart`：书签 DAO
- `book_note_dao.dart`：笔记/高亮 DAO
- `reading_stats_dao.dart`：统计 DAO
- `book_source_dao.dart`：书源 DAO
- `book_source_service.dart`：书源服务
- `book_import_service.dart`：书籍导入入口
- `book_import_isolate.dart`：导入 isolate
- `enhanced_txt_import_service.dart`：TXT 导入增强
- `text_preprocessor.dart`：文本预处理
- `enhanced_paginator.dart`：分页器
- `pagination_cache_service.dart`：分页缓存
- `reading_router_service.dart`：阅读路由
- `reader_settings_service.dart`：阅读设置持久化
- `reading_progress_service.dart`：阅读进度
- `reading_engine_coordinator.dart`：阅读引擎协调器
- `reading_theme_manager.dart`：阅读主题管理
- `page_animation_manager.dart`：翻页动画管理
- `book_image_manager.dart`：图片缓存
- `book_image_map_service.dart`：图片路径映射
- `epub_image_extractor.dart`：EPUB 图片提取
- `cover_generator.dart`：封面生成
- `book_cover_fetcher.dart`：封面获取
- `share_service.dart`：分享
- `data_backup_service.dart`：数据备份
- `data_cache_service.dart`：缓存服务
- `offline_data_service.dart`：离线数据服务
- `library_event_bus.dart`：书库事件
- `tts_service.dart`：TTS 服务入口
- `tts/`：TTS 子模块
  - `base_tts.dart`
  - `system_tts.dart`
  - `tts_preferences.dart`
- `sync/`：同步模块
  - `webdav_sync_service.dart`
  - `sync_utils.dart`

#### lib/utils/
- `app_themes.dart`：应用主题
- `glass_config.dart`：毛玻璃配置
- `progressive_blur.dart`：渐进式模糊
- `responsive_helper.dart`：响应式工具
- `page_transitions.dart`：页面转场
- `theme_mixin.dart`：主题 mixin
- `encoding_detector_helper.dart`：编码检测

#### lib/widgets/
- `enhanced_text_selection_toolbar.dart`：文本选择工具栏
- `highlight_color_picker.dart`：高亮颜色选择
- `page_turning_settings_sheet.dart`：翻页设置面板
- `tts_settings_sheet.dart`：TTS 设置面板
- `toc_widget.dart`：目录组件
- `webdav_config_dialog.dart`：WebDAV 配置
- `side_toast.dart`：侧边提示
- `tap_zone_diagram.dart`：点击区域示意
- `scrolling_text.dart`：滚动文本

### 其他目录

- `assets/foliate-js/`：EPUB/Web 渲染引擎
- `knowledge_base/`：分页与阅读器技术研究文档
- `android/ ios/ macos/ windows/ linux/ web/`：各平台工程

## 清理记录（2025-01-07）

- 删除未引用的旧组件、工具与服务文件
- 移除已废弃的 TTS/分页实验代码
- 更新 README/CLAUDE 文档索引
