# CLAUDE.md

此文件为Claude AI助手提供在该仓库中工作时的指导信息。

## 项目概述

小元读书 (XiaoYuan Reader) 是一个功能丰富的Flutter跨平台电子书阅读器，支持EPUB、PDF等多种格式。应用具备本地存储、阅读进度追踪、书签管理、阅读统计、TTS朗读、云端同步、高亮笔记、智能分页和响应式设计等高级功能，支持移动端和桌面端。

## 开发命令

### 核心Flutter命令
- `flutter pub get` - 安装依赖
- `flutter run` - 调试模式运行应用
- `flutter build` - 生产环境构建
- `flutter test` - 运行单元测试
- `flutter analyze` - 代码分析和Lint检查
- `flutter doctor` - 检查开发环境

### 平台特定命令
- `flutter run -d windows` - Windows平台运行
- `flutter run -d macos` - macOS平台运行
- `flutter run -d linux` - Linux平台运行
- `flutter run -d chrome` - Web平台运行
- `flutter build windows` - Windows平台构建
- `flutter build macos` - macOS平台构建
- `flutter build linux` - Linux平台构建
- `flutter build apk` - Android APK构建
- `flutter build ios` - iOS平台构建

### 测试和调试
- `flutter test` - 运行所有测试
- `flutter test test/widget_test.dart` - 运行特定测试
- `flutter test --coverage` - 生成覆盖率报告
- `flutter clean` - 清理缓存和构建文件

## 技术架构

### 分层结构
应用遵循分层架构设计：

1. **表现层** (`lib/pages/`): UI组件和页面
   - `home_page_responsive.dart` - 响应式主页，包含药丸导航栏
   - `home_content_enhanced.dart` - 主页内容，阅读统计仪表板
   - `library_page.dart` - 书库管理页面
   - `reading_page_enhanced.dart` - 增强阅读界面，支持主题切换
   - `settings_page.dart` - 设置页面，主题和强调色配置
   - `detailed_stats_page.dart` - 详细统计页面，毛玻璃效果
   - `import_book_page.dart` - 书籍导入功能

2. **业务逻辑层** (`lib/services/`): 核心业务逻辑和数据访问
   - **数据访问层**:
     - `database_service.dart` - SQLite数据库管理单例
     - `book_dao.dart` - 书籍数据访问，包含完整CRUD操作
     - `bookmark_dao.dart` - 书签数据访问，支持updateBookmark方法
     - `book_note_dao.dart` - 统一笔记数据访问，参考anx-reader设计
       - 整合高亮和笔记的CRUD操作
       - 智能CFI位置合并
       - 按类型、章节、页码查询
       - 搜索和筛选功能
       - 统计信息获取
     - `reading_stats_dao.dart` - 阅读统计数据访问
   - **文件和内容处理**:
     - `book_import_service.dart` - 书籍文件导入和处理
     - `storage_service.dart` - 文件存储操作
     - `enhanced_book_service.dart` - 增强书籍处理，目录分析、封面提取、元数据处理
   - **高级文本分页系统**:
     - `text_paginator.dart` - 基础文本分页服务
     - `enhanced_text_paginator.dart` - 智能文本分页器，根据设备特性优化
     - `advanced_text_paginator.dart` - WebView精确分页算法，支持JavaScript渲染
     - `flutter_advanced_paginator.dart` - Flutter原生高级分页器
   - **WebView阅读引擎**:
     - `simple_webview_reader.dart` - 简单WebView阅读器
     - `enhanced_webview_reader.dart` - 增强WebView阅读器，集成Foliate-js
     - `book_player_server.dart` - 本地HTTP服务器，支持EPUB渲染
   - **TTS朗读系统** (`tts/`):
     - `base_tts.dart` - TTS抽象基类
     - `system_tts.dart` - 系统TTS实现
     - `tts_factory.dart` - TTS工厂模式管理
     - `tts_handler.dart` - TTS控制器，处理播放状态和音频会话
     - `tts_service.dart` - 统一TTS服务管理
   - **分享和导出服务**:
     - `share_service.dart` - 增强分享服务，支持多种格式和平台
     - `note_export_service.dart` - 笔记导出服务，支持Markdown/JSON/CSV格式
   - **云端同步** (`webdav/`):
     - `webdav_sync_service.dart` - WebDAV云端同步服务

3. **数据层** (`lib/models/`): 数据模型和实体
   - `book.dart` - 书籍实体，包含文件路径和进度追踪
   - `bookmark.dart` - 书签实体，记录阅读位置
   - `chapter.dart` - 增强章节实体，支持层级结构、EPUB映射、智能章节检测
   - `book_note.dart` - 统一笔记实体，参考anx-reader设计
     - 整合高亮和笔记功能
     - 支持CFI定位和章节信息
     - 多种类型（高亮、下划线、笔记）
     - 8种预设颜色系统
     - 导出和分享功能

4. **工具类** (`lib/utils/`): 辅助功能和扩展
   - `app_themes.dart` - 应用主题定义（AppTheme, AppThemes）
   - `theme_mixin.dart` - 主题混入，为组件提供主题能力
   - `glass_config.dart` - 毛玻璃效果配置
   - `progressive_blur.dart` - 渐进模糊效果
   - `responsive_helper.dart` - 响应式设计工具
   - `color_extensions.dart` - 颜色操作扩展
   - `text_selection_helper.dart` - 文本选择辅助
   - `text_painter_pagination.dart` - 文本绘制分页
   - `pagination_cache.dart` - 分页缓存管理

5. **自定义组件** (`lib/widgets/`): 可复用UI组件
   - **导航组件**:
     - `liquid_glass_navigation.dart` - 液态玻璃导航组件
     - `floating_capsule_navigation.dart` - 浮动胶囊导航
   - **高级阅读组件**:
     - `advanced_text_reader_widget.dart` - 高级文本阅读器组件
     - `flutter_advanced_reader_widget.dart` - Flutter原生高级阅读器
     - `custom_selectable_text.dart` - 自定义可选择文本组件
     - `text_highlight_renderer.dart` - 文本高亮渲染器
   - **阅读相关组件**:
     - `chapter_panel.dart` - 智能章节面板，支持层级分析和导航
     - `enhanced_text_selection_toolbar.dart` - 统一文字选择工具栏，参考anx-reader设计
       - 多层级界面：主操作菜单、颜色选择器、笔记编辑器、翻译面板
       - 支持高亮、下划线、笔记三种类型
       - 8种预设颜色选择
       - 快速操作：复制、搜索、翻译、分享、删除
     - `highlight_note_panel.dart` - 统一笔记管理面板
       - 按类型分组显示（全部/高亮/下划线/笔记）
       - 实时搜索和筛选功能
       - 多格式导出支持
       - 统计信息显示
     - `highlight_color_picker.dart` - 高亮颜色选择器
     - `toc_widget.dart` - 目录导航组件
   - **TTS和分享组件**:
     - `tts_control_panel.dart` - TTS控制面板
     - `tts_panel_enhanced.dart` - 增强TTS面板
     - `share_dialog.dart` - 分享对话框
   - **布局和适配组件**:
     - `ios_adaptive_layout.dart` - iOS自适应布局组件
   - **设置和配置**:
     - `webdav_config_dialog.dart` - WebDAV云端同步配置对话框
   - **其他组件**:
     - `custom_slider_components.dart` - 自定义滑块组件
     - `note_dialog.dart` - 笔记编辑对话框

### 主题系统架构
- **ThemeNotifier** (`main.dart`) - 全局主题状态管理，使用Provider
- **AppTheme/AppThemes** (`utils/app_themes.dart`) - 主题定义和预设集合
- **ReadingTheme/ReadingThemes** (`pages/reading_page_enhanced.dart`) - 阅读专用主题
- **ThemeMixin** - 为组件提供主题访问能力

### 数据库设计
应用使用SQLite，包含四个主要表：
- `books` - 存储书籍元数据和阅读进度（包含totalPages、封面路径等字段）
- `bookmarks` - 存储用户书签，支持笔记和页面引用
- `reading_stats` - 追踪每日阅读统计和阅读时长
- `book_notes` - 统一的笔记高亮表，参考anx-reader设计
  - 支持高亮、下划线、纯笔记三种类型
  - CFI定位和章节信息
  - 颜色和附加笔记
  - 创建和更新时间追踪

#### 数据库版本更新
- **版本7**: 统一笔记高亮系统，创建book_notes表
  - 自动迁移旧的highlights和notes表数据
  - 支持CFI定位和章节信息
  - 颜色系统和类型分类
- **版本6**: 添加封面图片路径字段
- **版本5**: 添加内容缓存字段
- **外键关系**: books、bookmarks、book_notes之间的正确外键关系

跨平台数据库支持：
- 移动端: 通过sqflite使用标准SQLite
- 桌面端: 通过sqflite_common_ffi使用SQLite FFI

### 状态管理
- **Provider模式** 用于主题管理（main.dart中的ThemeNotifier）
- **SharedPreferences** 用于持久化用户设置
- **本地数据库状态** 通过DAO服务管理

### 文件处理
书籍以文件路径存储在数据库中，而非内容本身，支持：
- 通过`epubx`包处理EPUB
- 通过`pdfx`包支持PDF
- 通过`archive`包处理压缩文件
- 通过`file_picker`集成文件选择

### UI/UX特性
- **Material 3设计语言** - 现代化界面设计
- **毛玻璃效果** - 使用GlassConfig和ProgressiveBlur
- **渐变背景** - 主页、设置、书库页面的主题色渐变
- **药丸导航栏** - 浮动胶囊式底部导航
- **响应式设计** - 适配不同屏幕尺寸
- **沉浸式模式** - 边到边显示，透明状态栏

## 关键依赖和技术栈

### 核心框架
- **Flutter** `^3.8.1` - 跨平台UI框架
- **Dart** `^3.8.1` - 编程语言

### 数据持久化
- **sqflite** `^2.3.0` - 移动端SQLite
- **sqflite_common_ffi** `^2.3.6` - 桌面端SQLite
- **shared_preferences** `^2.2.2` - 用户偏好存储
- **path_provider** `^2.1.5` - 文件路径管理

### 电子书引擎
- **epubx** `^4.0.0` - EPUB格式支持
- **pdfx** `^2.6.0` - PDF格式支持
- **archive** `^3.4.10` - 压缩文件处理

### UI增强
- **provider** `^6.1.5` - 状态管理
- **fl_chart** `^0.68.0` - 图表展示
- **page_flip** `^0.2.0` - 翻页动画
- **volume_controller** `^2.0.8` - 音量键控制
- **google_fonts** `^6.1.0` - 中文字体支持

### 高级功能
- **flutter_tts** `^4.2.2` - TTS文本朗读功能
- **share_plus** `^11.1.0` - 增强分享功能
- **webdav_client** `^1.2.2` - WebDAV云端同步
- **dio** `^5.4.3+1` - HTTP客户端，支持WebDAV
- **audio_service** `^0.18.16` - 后台音频播放服务
- **audio_session** `^0.1.23` - 音频会话管理
- **connectivity_plus** `^6.1.3` - 网络连接检测

### WebView和高级UI
- **webview_flutter** `^4.4.2` - WebView支持
- **flutter_inappwebview** `^6.0.0` - 高级WebView功能
- **shelf** `^1.4.1` - 本地HTTP服务器
- **shelf_static** `^1.1.2` - 静态文件服务

### anx-reader 集成依赖
- **wakelock_plus** `^1.2.8` - 屏幕常亮管理
- **icons_plus** `^5.0.0` - 图标库增强
- **battery_plus** `^6.2.1` - 电池状态监控
- **device_info_plus** `^11.3.2` - 设备信息获取
- **url_launcher** `^6.2.6` - URL启动器
- **permission_handler** `^11.3.1` - 权限管理

### 增强UI体验
- **photo_view** `^0.15.0` - 图片查看器
- **sticky_headers** `^0.3.0+2` - 粘性头部
- **flutter_smart_dialog** `^4.9.8+1` - 智能对话框
- **saver_gallery** `^4.0.1` - 图片保存库

### 数据处理增强
- **logging** `^1.2.0` - 日志记录
- **html** `^0.15.4` - HTML解析
- **flutter_html** `^3.0.0-beta.2` - HTML渲染

### 工具库
- **file_picker** `^8.0.0+1` - 文件选择
- **crypto** `^3.0.3` - 加密和哈希
- **intl** `^0.20.2` - 国际化支持
- **path** `^1.9.1` - 路径操作
- **uuid** `^4.5.1` - 唯一标识符生成

## 高级功能特性

### Foliate-js 阅读引擎集成
- **Foliate-js核心**: 集成开源的Foliate-js阅读引擎，基于MIT许可证
- **WebView渲染**: 通过flutter_inappwebview实现高性能WebView渲染
- **JavaScript交互**: 完整的JavaScript API支持，与Flutter双向通信
- **多格式支持**: 原生支持EPUB、PDF等多种电子书格式
- **渐进式渲染**: 支持大文件的分块加载和渐进式渲染

### TTS朗读系统
- **架构设计**: 采用工厂模式和抽象基类设计，支持多TTS引擎
- **核心功能**: 语音朗读、语速调节、音调控制、连续翻页朗读
- **平台适配**: Android/iOS系统TTS优化适配
- **音频管理**: 集成audio_service支持后台播放和音频会话管理
- **智能控制**: 支持播放/暂停/上一页/下一页语音控制
- **服务集成**: 统一的TtsService管理多种TTS实现

### 多层级智能分页系统
- **Enhanced Text Paginator**: 根据设备类型智能调整分页参数
  - 自动检测设备类型（手机/大屏手机/平板）
  - 智能字符测量和行高计算
  - 设备特性适配的保conservative系数调整
- **Advanced Text Paginator**: WebView+JavaScript精确分页
  - HTML5+CSS3精确文本渲染
  - JavaScript分页算法，支持响应式布局
  - 触摸手势、键盘导航支持
  - 多列布局和滚动模式切换
- **Flutter Advanced Paginator**: 原生Flutter分页实现
  - 纯Dart实现的高性能分页算法
  - 自定义渲染管道优化
  - 内存使用优化和缓存管理

### 统一笔记高亮系统（参考anx-reader设计）
- **统一BookNote模型**: 整合高亮和笔记为单一数据模型，支持CFI定位
- **多种注释类型**: 支持高亮、下划线、纯笔记三种类型
- **丰富颜色系统**: 8种预设颜色（浅蓝、红、绿、紫、金、橙、黄、深绿）
- **增强文字选择工具栏**: 
  - 多层级界面设计（主操作、颜色选择、笔记编辑、翻译面板）
  - 快速操作：复制、搜索、翻译、分享
  - 颜色和类型选择器
  - 实时笔记编辑功能
- **智能笔记管理面板**:
  - 按类型分组显示（全部/高亮/下划线/笔记）
  - 实时搜索和筛选功能
  - 统计信息显示
  - 多格式导出（Markdown、CSV、JSON）
- **数据库架构升级**: 
  - 版本7数据库，支持统一book_notes表
  - 自动迁移旧数据
  - CFI定位和章节信息支持

### WebDAV云端同步
- **配置管理**: 直观的WebDAV服务器配置界面
- **数据同步**: 书籍、进度、书签、笔记、高亮全面同步
- **网络检测**: 智能网络状态检测和错误处理
- **安全存储**: 加密存储同步配置信息
- **状态管理**: 实时同步状态显示和错误反馈

### 增强章节导航
- **智能解析**: 自动识别章节结构和层级关系
- **类型检测**: 智能识别主章节、子章节、前言、后记等
- **可视化**: 层级结构可视化显示，支持折叠展开
- **快速跳转**: 点击章节快速定位到对应页面

### 增强书籍处理
- **元数据提取**: 自动提取EPUB/PDF书籍元信息
- **封面提取**: 智能提取书籍封面图片
- **目录分析**: 深度分析书籍目录结构
- **格式支持**: 完善的EPUB、PDF格式支持

### 增强分享和导出系统
- **ShareService**: 统一分享服务，支持多平台和多格式
- **多格式导出**: 笔记支持Markdown、JSON、CSV格式
- **阅读统计**: 自动生成阅读报告和统计信息
- **社交分享**: 格式化的文字摘录分享功能
- **批量操作**: 支持批量导出和管理
- **智能分享对话框**: 动态适应不同内容类型的分享界面

### iOS平台优化
- **自适应布局**: ios_adaptive_layout组件确保iOS平台的最佳显示效果
- **平台特性**: 充分利用iOS平台的UI特性和交互模式
- **性能优化**: 针对iOS设备的性能特点进行专门优化

### anx-reader 功能集成
- **屏幕管理**: wakelock_plus确保阅读时屏幕常亮
- **设备信息**: device_info_plus获取设备特性用于优化
- **电池监控**: battery_plus监控电池状态，智能调整性能
- **权限管理**: permission_handler统一管理各种系统权限
- **图片处理**: photo_view和saver_gallery增强图片查看和保存功能

## 开发注意事项

### 代码质量
- 所有代码通过`flutter analyze`检查，无编译错误和警告
- 使用Material 3 API，避免废弃的color.value，改用toARGB32()
- 清理未使用的变量和方法，保持代码整洁

### 主题和样式
- 继承`ThemeMixin`获得主题访问能力
- 使用`AppThemes`中的预设主题
- 支持自定义强调色设置
- 毛玻璃效果通过`GlassConfig`配置

### 数据访问
- 所有数据库操作通过DAO层进行
- 使用异步方法处理数据库操作
- 书签DAO支持updateBookmark方法
- 统计数据使用真实DAO而非硬编码

### 布局和间距
- 主页卡片间距已优化，使用合适的SizedBox和padding
- 药丸导航栏背景与按钮对齐
- 首页卡片整体位置通过ListView padding调整
- 毛玻璃效果避免割裂和过暗问题

### 性能优化
- 使用分页缓存减少重复计算
- 文本分页算法与显示区域统一
- 适当的Widget缓存和生命周期管理

### 平台兼容性
- 桌面平台需要sqflite_common_ffi初始化
- 移动平台使用标准sqflite
- 沉浸式状态栏在main.dart中配置
- 音量键翻页仅在移动端有效

### 调试和测试
- 使用`flutter hot reload`进行快速迭代
- 通过`flutter analyze`检查代码质量
- 所有DAO方法需要适当的错误处理
- 界面变更后进行多设备测试

### 最近重大功能增强

#### 完整数据持久化和缓存机制 (2025-09-20)
- **DataManager** - 统一数据管理器，协调所有数据服务生命周期
- **DataCacheService** - 统一缓存管理，30秒自动保存，支持缓存验证和清理
- **ReadingProgressService** - 阅读进度实时保存，支持历史记录和批量更新
- **AppStateService** - 完整应用状态管理，包括阅读状态、用户设置、UI状态
- **DataBackupService** - 自动数据备份(6小时间隔)，数据完整性验证，损坏修复
- **EnhancedDatabaseService** - 增强数据库管理，事务支持，错误恢复，性能监控
- **OfflineDataService** - 离线数据支持，网络状态监控，自动同步机制

#### 解决的关键问题
- ✅ 彻底解决"退出重进后数据丢失"问题
- ✅ 实现多层次数据持久化保障（内存缓存+SharedPreferences+SQLite）
- ✅ 离线数据支持，网络问题不影响数据保存
- ✅ 自动数据备份和验证，防止数据损坏
- ✅ 完整的状态恢复机制，包括阅读位置、设置、书签等
- ✅ 智能错误恢复和数据修复功能

#### 技术特性
- 实时数据保存（重要操作立即持久化）
- 定时自动保存（30秒间隔）
- 数据完整性验证（SHA-256校验和）
- 多重备份策略（保留7个历史备份）
- 离线操作队列（最多1000个操作）
- 事务管理和批量操作优化
- 全面的性能监控和统计

### 历史修复问题
- BookmarkDao添加updateBookmark方法支持
- 清理所有未使用变量和方法
- 修复color.value废弃API用法
- 优化字符串插值，避免冗余
- 药丸导航栏背景与按钮对齐
- 移除所有页面背景小灰点
- 统一阅读页面分页算法和显示区域高度

### 架构设计特殊注意事项

#### 响应式设置页面架构
**重要发现**: `home_page_responsive.dart` 中使用了双设置页面架构：
- **桌面端**: 使用完整的 `SettingsPage` 组件
- **手机端**: 使用简化版的 `_SettingsPageWrapper` 内嵌组件

**潜在问题**: 当在 `SettingsPage` 中添加新功能时，手机端的 `_SettingsPageWrapper` 不会自动包含这些新功能，导致功能不一致。

**解决方案**: 
1. 任何新增设置功能都需要同时在两处添加
2. 或者考虑重构为单一设置组件架构
3. 在修改设置功能时，必须检查并更新 `_SettingsPageWrapper`

**已修复案例**: 阅读引擎选择功能最初只在 `SettingsPage` 中实现，导致手机端无法使用此功能。已同步添加到 `_SettingsPageWrapper` 中。

## 项目文件结构说明

### 主要配置文件
- `pubspec.yaml` - 项目依赖和配置
- `analysis_options.yaml` - 代码分析配置
- `flutter_launcher_icons.yaml` - 应用图标配置
- `devtools_options.yaml` - 开发工具配置

### 平台特定配置
- `android/` - Android平台配置
- `ios/` - iOS平台配置
- `windows/` - Windows平台配置
- `macos/` - macOS平台配置
- `linux/` - Linux平台配置
- `web/` - Web平台配置

### 资源文件
- `assets/images/` - 应用图片资源
- `assets/foliate-js/` - Foliate-js阅读引擎资源
  - `dist/` - 编译后的JavaScript文件
  - `src/` - 源代码文件
  - `index.html` - WebView加载入口
- `shot/` - 应用截图文件

### 新增架构目录（Clean Architecture）
- `lib/core/` - 核心层
  - `constants/` - 常量定义
  - `di/` - 依赖注入
- `lib/data/` - 数据层
  - `datasources/` - 数据源
- `lib/domain/` - 领域层
  - `entities/` - 实体
  - `repositories/` - 仓库接口
  - `usecases/` - 用例
- `lib/presentation/` - 表现层
  - `providers/` - 状态提供者
  - `themes/` - 主题定义

### 示例和演示代码
- `lib/demo_main.dart` - 演示主程序
- `lib/examples/` - 使用示例
- `lib/pages/advanced_reader_demo_page.dart` - 高级阅读器演示页面
- `lib/pages/reading_mode_selector.dart` - 阅读模式选择器

这个项目是一个功能完整、架构清晰的Flutter电子书阅读器，具备优秀的用户体验和技术实现。

### Responsive Design
Navigation adapts based on screen size:
- **Mobile**: Bottom navigation bar
- **Desktop/Tablet**: Navigation rail sidebar
- Breakpoints managed in `ResponsiveHelper`

## Key Dependencies

### Core Flutter Packages
- `provider` - State management for themes
- `shared_preferences` - Persistent settings storage
- `sqflite` / `sqflite_common_ffi` - Database (mobile/desktop)
- `path_provider` - Cross-platform file paths

### E-book Functionality
- `epubx` - EPUB file processing and reading
- `file_picker` - File selection for book imports

### UI Enhancement
- `fl_chart` - Charts for reading statistics
- `page_flip` - Page turning animations
- `volume_controller` - Hardware volume button support
- `intl` - Internationalization support

## Development Notes

### Main Entry Point
- Desktop platform initialization occurs in `main.dart` with `sqfliteFfiInit()` for Windows/Linux/macOS
- `ThemeNotifier` provider manages app-wide theme state
- Debug logging utility available as `debugLog()` function

### Cross-Platform Considerations
- Database initialization differs between mobile and desktop platforms
- Desktop platforms require FFI initialization in main.dart
- Path handling varies between platforms using path_provider

### Database Versioning
- Current version: 4 (with notes and highlights tables addition)
- Migration system handles upgrades in DatabaseService._onUpgrade()
- Always increment _dbVersion when making schema changes

### Common UI Patterns and Solutions

#### Control Bar Animation Issues
When working with animated control bars in reading interfaces:
- **Problem**: Control bars appearing in wrong position or lacking animation
- **Solution**: Use AnimatedPositioned with bottom positioning and AnimatedOpacity for fade effects
- **Code Pattern**:
  ```dart
  AnimatedPositioned(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    bottom: _showControls ? 0 : -200,
    left: 0,
    right: 0,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: _showControls ? 1.0 : 0.0,
      child: Container(...)
    )
  )
  ```

#### Text Pagination with UI Overlays
When implementing text pagination that needs to account for UI elements:
- **Problem**: Text being covered by control bars or other UI elements
- **Solution**: Reserve space in pagination calculations
- **Implementation**: Subtract UI element height from available space before calculating characters per page
- **Key**: Always reserve space even when UI elements are hidden to maintain consistent pagination

#### Animation Conflicts
- **Problem**: Multiple animation systems conflicting (AnimationController vs implicit animations)
- **Solution**: Choose one approach consistently - prefer implicit animations (AnimatedPositioned, AnimatedOpacity) for simpler implementations
- **Avoid**: Mixing SingleTickerProviderStateMixin with implicit animations unless absolutely necessary

### Theme System
- Supports light/dark mode with Material 3 design
- Custom color schemes with seed colors
- Theme persistence via SharedPreferences
- Responsive to system theme changes

### Import Functionality
- Supports multiple book formats (EPUB, PDF, TXT)
- File validation and metadata extraction
- Error handling for unsupported formats

### Text Selection and Annotation Features
- Text highlighting with color support
- Note-taking functionality with text references
- Custom text selection toolbar
- Position-based highlight storage for accurate rendering

### Reading Interface Enhancements
- **Enhanced Control Bar System**: Slide-in/slide-out animated control bar at bottom of screen
  - Smooth AnimatedPositioned transitions (300ms duration)
  - AnimatedOpacity for fade effects (250ms duration)
  - Proper Stack layout with title bar at top, control bar at bottom
- **Smart Text Pagination**: Intelligent text flow management
  - Control bar space reservation (140px) to prevent text overlap
  - Dynamic character-per-page calculation based on available display area
  - Responsive layout adaptation for different screen sizes
- **Bookmark Management**: Full bookmark functionality with database persistence
  - Quick bookmark addition/removal from control bar
  - Bookmark navigation and management
  - Note support for bookmarks
- **Search and Navigation**: Enhanced text search with multi-result navigation
  - Search across entire book content
  - Result highlighting and navigation
  - Case-insensitive search support
- **Sharing Capabilities**: Multiple content sharing formats
  - Current page content sharing
  - Selected text sharing
  - Reading progress sharing

### Animation System
- **Implicit Animations**: Uses Flutter's AnimatedPositioned and AnimatedOpacity
  - Avoids complex AnimationController management
  - Smooth, consistent animations across UI elements
  - Proper curve animations (Curves.easeInOut) for natural motion
- **Performance Optimized**: Minimal animation overhead
  - State-based animation triggers
  - Efficient widget rebuilding strategies