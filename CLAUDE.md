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
   - **阅读页面系统**:
     - `reading_page_enhanced.dart` - 增强版Flutter原生阅读器，高性能文本渲染
     - `webview_reading_page.dart` - WebView阅读器，EPUB/PDF支持
     - `webview_reading_page_enhanced_toc.dart` - 增强WebView阅读器，支持目录导航
     - `webview_reading_page_optimized.dart` - 优化版WebView阅读器
     - `advanced_reading_page.dart` - 高级阅读页面，多引擎支持
     - `reading_mode_selector.dart` - 阅读模式选择器
   - `settings_page.dart` - 设置页面，主题和强调色配置
   - `detailed_stats_page.dart` - 详细统计页面，毛玻璃效果
   - `import_book_page.dart` - 书籍导入功能
   - `user_agreement_page.dart` - 用户协议页面
   - `advanced_reader_demo_page.dart` - 高级阅读器演示页面

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

#### 设计语言和风格
- **Material 3设计语言** - 现代化界面设计，支持动态颜色和主题
- **毛玻璃效果** - 使用GlassConfig和ProgressiveBlur实现高级玻璃质感
- **渐变背景** - 主页、设置、书库页面的主题色渐变，营造深度感
- **圆角设计** - 统一使用20px圆角，现代化视觉语言
- **阴影层次** - 多层次阴影系统，增强空间感和层次
- **响应式设计** - 适配不同屏幕尺寸，移动端和桌面端优化

#### 导航和交互模式
- **药丸导航栏** - 浮动胶囊式底部导航，现代化交互
- **底部滑出面板** - 设置菜单等二级界面采用底部滑出模式
- **手势交互** - 支持拖拽、滑动等自然手势操作
- **沉浸式模式** - 边到边显示，透明状态栏，最大化内容区域
- **智能吸附** - 面板高度智能吸附到预设位置（40%、80%、95%）

#### 动画设计规范

##### 动画时长标准
- **快速反馈** - 150-200ms：按钮点击、状态切换
- **标准过渡** - 300ms：页面切换、面板滑出、控制栏显隐
- **复杂动画** - 500-800ms：页面路由、复杂状态变化
- **TTS播放进度** - 1000ms+：阅读进度、长时间状态动画

##### 缓动曲线（Easing）
- **Curves.easeInOut** - 标准选择，自然流畅的进出效果
- **Curves.easeOut** - 快速启动，平缓结束，适合出现动画
- **Curves.easeIn** - 平缓启动，快速结束，适合消失动画
- **Curves.elasticOut** - 弹性效果，用于特殊反馈场景

##### 动画类型和应用场景

###### 1. 页面过渡动画（PageAnimationType）
- **slide（滑动）** - 默认推荐，性能优秀
- **cover（覆盖）** - 页面覆盖效果，性能良好
- **simulation（仿真）** - 3D翻书效果，适合高端设备
- **scroll（滚动）** - 垂直滚动，适合长文本
- **none（无动画）** - 性能最佳，即时切换

###### 2. 控制界面动画
- **控制栏滑入滑出** - `AnimatedPositioned` + `AnimatedOpacity`
  - 位置：底部`bottom: _showControls ? 0 : -200`
  - 透明度：`opacity: _showControls ? 1.0 : 0.0`
  - 时长：300ms，`Curves.easeInOut`

- **底部设置面板** - `showModalBottomSheet` + `DraggableScrollableSheet`
  - 背景遮罩：`Colors.black.withValues(alpha: 0.5)`
  - 圆角：顶部20px圆角
  - 阴影：`blurRadius: 15`, `offset: Offset(0, -8)`
  - 拖拽手柄：36px宽，4px高，圆角2px

###### 3. 状态反馈动画
- **按钮按压效果** - `Transform.scale` 动画
  - 按下：缩放到0.95
  - 时长：150ms
  - 触觉反馈：`HapticFeedback.mediumImpact()`

- **加载状态** - `CircularProgressIndicator`
  - 主题色适配
  - 配合文字说明

##### 动画优化原则
1. **性能优先** - 避免复杂动画影响阅读体验
2. **渐进增强** - 低端设备自动降级到简单动画
3. **一致性** - 相同场景使用相同的动画参数
4. **可中断** - 用户操作可以中断正在进行的动画
5. **反馈及时** - 用户操作立即响应，避免延迟感

#### 主题和颜色系统
- **动态主题** - 支持Light/Dark模式自动切换
- **阅读主题** - 独立的阅读界面主题系统（日间、夜间、护眼等）
- **强调色系统** - 自定义强调色，影响整体UI色调
- **语义化颜色** - 统一的语义化颜色命名和使用规范

#### 视觉层次和布局
- **卡片系统** - 统一的卡片设计语言，区分内容层次
- **间距系统** - 8px基础网格，4px、8px、12px、16px、24px等标准间距
- **字体层次** - 统一的字体大小层次：12px、14px、16px、18px、20px、24px
- **图标系统** - Material Icons为主，统一的图标使用规范

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

### 原生Flutter阅读引擎
- **原生性能**: 基于Flutter原生渲染，无WebView开销，启动更快，内存占用更少
- **高效文本分页**: 智能文本分页算法，支持动态字体大小和行距调整
- **流畅阅读体验**: 原生手势支持，页面切换无延迟，响应更灵敏
- **多主题支持**: 内置5种阅读主题（白天、夜间、护眼、羊皮纸、棕褐色）
- **完整功能集成**:
  - 书签管理和快速添加/删除
  - 全文搜索和结果导航
  - TTS朗读支持
  - 文本选择和高亮
  - 章节目录导航
  - 阅读进度自动保存
- **性能优化**:
  - 页面缓存管理，减少重复计算
  - 防抖动页面切换，避免过度渲染
  - 定时自动保存，30秒间隔
  - 内存管理优化，及时清理资源
- **智能适配**: 根据屏幕尺寸自动调整默认字体大小和布局参数

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

### UI/UX开发指南

#### 动画实现规范
- **标准动画时长**：使用300ms作为默认过渡时间
- **缓动曲线**：优先使用`Curves.easeInOut`确保自然流畅
- **隐式动画优先**：使用`AnimatedPositioned`、`AnimatedOpacity`等，避免复杂的`AnimationController`
- **性能考虑**：避免同时运行多个复杂动画，优化渲染性能

#### 底部面板设计模式
- **使用场景**：设置菜单、选择器等二级界面必须采用底部滑出模式
- **实现方式**：`showModalBottomSheet` + `DraggableScrollableSheet`
- **视觉要求**：
  - 左右贴边：`width: double.infinity`
  - 顶部圆角：20px
  - 拖拽手柄：36px宽×4px高，透明度0.3
  - 背景遮罩：`Colors.black.withValues(alpha: 0.5)`
- **交互要求**：支持手势拖拽、智能吸附（40%、80%、95%高度）

#### 控制栏动画标准
- **滑入滑出**：`AnimatedPositioned`控制位置，`AnimatedOpacity`控制透明度
- **位置动画**：`bottom: _showControls ? 0 : -200`
- **透明度动画**：`opacity: _showControls ? 1.0 : 0.0`
- **时长配置**：300ms位置动画，250ms透明度动画

#### 按钮反馈标准
- **视觉反馈**：`Transform.scale`缩放到0.95
- **触觉反馈**：`HapticFeedback.mediumImpact()`
- **动画时长**：150ms快速响应
- **状态管理**：使用`GestureDetector`的`onTapDown`、`onTapUp`、`onTapCancel`

#### 圆角和阴影标准
- **卡片圆角**：12px标准，20px大卡片
- **按钮圆角**：8px小按钮，12px标准按钮，25px药丸形状
- **面板圆角**：顶部20px（底部面板），全局12px（对话框）
- **阴影规范**：
  - 轻度：`blurRadius: 4, offset: Offset(0, 2), alpha: 0.1`
  - 标准：`blurRadius: 8, offset: Offset(0, 4), alpha: 0.15`
  - 重度：`blurRadius: 15, offset: Offset(0, -8), alpha: 0.2`

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

#### 间距设计系统
- **基础网格**：8px为基础单位
- **标准间距**：4px、8px、12px、16px、24px、32px
- **内边距规范**：
  - 小组件：8px
  - 卡片内容：16px
  - 页面边距：16px（移动端）、24px（平板/桌面）
  - 对话框：16px内边距，24px底部间距
- **外边距规范**：
  - 组件间：8px最小，12px标准
  - 卡片间：12px（列表），16px（网格）
  - 章节间：24px大间距

#### 文字和图标规范
- **字体大小层次**：
  - 标题：24px（一级）、20px（二级）、18px（三级）
  - 正文：16px（标准）、14px（辅助）
  - 标签：12px（小标签）、10px（极小提示）
- **行高标准**：字体大小 × 1.4-1.6倍
- **图标尺寸**：16px（小图标）、24px（标准）、32px（大图标）、48px（特大）

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

### 阅读引擎架构设计

#### 多引擎阅读系统
应用支持多种阅读引擎，用户可根据需求选择最适合的阅读模式：

1. **原生Flutter阅读器** (`reading_page_enhanced.dart`)
   - **适用场景**: TXT文件，追求性能和电池续航
   - **优势**: 启动快、内存少、响应灵敏、电池友好
   - **特性**: 原生文本渲染、5种阅读主题、完整功能支持

2. **WebView阅读器** (`webview_reading_page.dart`)
   - **适用场景**: EPUB、PDF等复杂格式
   - **优势**: 完整的HTML/CSS渲染、复杂排版支持
   - **特性**: Foliate-js集成、JavaScript交互、渐进式加载

3. **增强WebView阅读器** (`webview_reading_page_enhanced_toc.dart`)
   - **适用场景**: 需要复杂目录导航的EPUB文件
   - **优势**: 智能目录解析、层级导航、章节跳转
   - **特性**: 增强TOC支持、书签同步、阅读进度追踪

4. **优化WebView阅读器** (`webview_reading_page_optimized.dart`)
   - **适用场景**: 大文件EPUB、性能敏感场景
   - **优势**: 内存优化、渲染优化、加载性能提升
   - **特性**: 分块加载、缓存管理、资源优化

#### 阅读模式选择器
- **智能推荐**: 根据文件格式自动推荐最优阅读引擎
- **性能对比**: 提供各引擎性能和功能对比
- **用户偏好**: 支持用户设置默认阅读引擎
- **无缝切换**: 支持同一书籍在不同引擎间切换

### 最近重大功能增强

#### 完善Flutter阅读器系统 (2025-09-21)
- **LegadoInspiredPaginator优化** - 完善基于legado算法的分页器，修复字体测量逻辑，确保文字完整性
- **智能响应式布局** - 实现屏幕尺寸自适应的字体、边距、控制栏高度动态调整
- **FlutterAdvancedReaderWidget完善** - 增强原生Flutter阅读器组件，添加完整的控制器API和错误处理
- **UI控制栏布局修复** - 解决控制栏动画和布局问题，实现流畅的显隐效果
- **分页算法保障** - 实现字符严格连续性分页，100%不丢失文字，添加完整性验证机制
- **设备类型自适应** - 根据屏幕对角线识别设备类型（手机/大屏手机/平板），智能调整显示参数

#### 技术改进要点
- **文字完整性保证**:
  - 智能断点检测（段落分隔 → 句子结束 → 逗号分号 → 空格）
  - 严格字符连续性，绝对不跳字不丢字
  - 保守的85%页面利用率，确保显示舒适
- **响应式设计优化**:
  - 平板设备：字体20px，边距32px，控制栏180px
  - 大屏手机：字体18px，边距24px，控制栏160px
  - 普通手机：字体17px，边距20px，控制栏140px
- **分页算法精确度**:
  - 基于legado TextPaint原理的字符测量
  - 二分查找最佳断点算法
  - 实时分页完整性验证（调试模式）

#### 原生阅读引擎开发 (2025-09-21)
- **NativeReadingPage** - 全新原生Flutter阅读器实现
- **高性能文本渲染** - 基于Flutter原生Canvas和TextPainter
- **智能分页算法** - 动态计算页面布局，支持响应式调整
- **完整UI控制系统** - 动画控制栏、顶部栏、工具栏集成
- **多主题阅读体验** - 5种内置主题，支持实时切换
- **性能优化机制** - 页面缓存、防抖动、定时保存、内存管理
- **阅读功能完整性** - 书签、搜索、TTS、高亮、目录导航全支持

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
- 修复color.value废弃API用法，统一使用withValues()
- 优化字符串插值，避免冗余
- 药丸导航栏背景与按钮对齐
- 移除所有页面背景小灰点
- 统一阅读页面分页算法和显示区域高度
- ✅ 修复legado分页器字体测量逻辑，确保准确性
- ✅ 解决控制栏布局问题，修复_controlBarHeight未定义错误
- ✅ 完善FlutterAdvancedReaderWidget组件，添加完整API
- ✅ 实现智能响应式布局，自适应不同设备屏幕尺寸
- ✅ 添加分页完整性验证，防止文字丢失问题
- ✅ 修复设置页面毛玻璃效果显示异常问题，统一UI效果配置

### 原生阅读器开发要点

#### 性能优化策略
- **页面缓存管理**: PageCacheManager管理最近访问的页面内容，减少重复计算
- **防抖动机制**: 使用Timer防抖动，避免快速翻页时的过度渲染
- **定时保存**: 30秒间隔自动保存阅读进度，平衡性能和数据安全
- **内存管理**: 及时清理Timer和StreamSubscription，避免内存泄漏

#### UI控制栏动画
- **AnimatedPositioned**: 使用隐式动画实现控制栏滑入滑出效果
- **动画时长**: 顶部栏200ms，底部控制栏200ms，保持一致性
- **状态管理**: _showControls统一控制所有UI元素显示状态
- **自动隐藏**: 5秒无操作自动隐藏控制栏，提供沉浸式阅读体验

#### 主题系统实现
- **ReadingTheme类**: 封装阅读主题的所有颜色配置
- **ReadingThemes**: 提供5种预设主题的静态定义
- **实时切换**: 支持阅读过程中动态切换主题，无需重启
- **智能适配**: 根据屏幕尺寸自动调整默认字体大小

#### 文本处理和分页
- **智能章节检测**: 对TXT文件进行简单章节识别（第X章模式）
- **响应式字体**: 根据屏幕高度动态计算合适的默认字体大小
- **文本渲染**: 支持字体大小、行距、字间距的实时调整
- **格式支持**: 目前专注TXT格式，EPUB显示提示引导用户使用WebView阅读器

#### 原生阅读器开发状态
**当前状态**: ✅ 已完善，基础架构和核心功能已实现
**已解决问题**:
- ✅ 完善FlutterAdvancedReaderWidget组件实现，添加完整控制器API
- ✅ 修复legado分页器的字体测量逻辑，确保文字完整性
- ✅ 统一UI变量命名，修复控制栏布局问题
- ✅ 清理未使用的字段和变量，提升代码质量
- ✅ 实现智能响应式布局，自适应不同设备尺寸
- ✅ 添加分页完整性验证机制，防止文字丢失

**技术特性**:
- **精确分页**: 基于legado算法的精确文本测量和智能断点检测
- **舒适布局**: 根据设备类型智能调整字体、边距、控制栏高度
- **流畅动画**: 正确的控制栏显隐动画，300ms标准过渡时间
- **稳定性能**: 优化的渲染和内存管理，防抖动机制
- **完整性保障**: 85%保守页面利用率，100%文字完整性验证

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

## UI/UX设计哲学和最佳实践

### 设计理念
- **简洁优雅**：界面设计追求简洁但不简单，每个元素都有其存在的理由
- **以内容为中心**：UI设计服务于阅读体验，避免过度装饰影响专注度
- **自然交互**：动画和手势符合用户的直觉期待，减少学习成本
- **性能优先**：美观不能以牺牲性能为代价，流畅的体验是第一要务

### 动画设计原则
1. **有意义的动画**：每个动画都应该有助于用户理解界面变化
2. **保持连续性**：相关元素的动画应该在时间和空间上保持连续
3. **适度的个性**：在保持专业性的同时，适当展现应用的个性特色
4. **设备适配**：根据设备性能自动调整动画复杂度

### 交互设计规范
- **反馈即时性**：用户操作后150ms内必须有视觉或触觉反馈
- **操作可预测**：相似的手势在不同场景下应产生一致的结果
- **错误包容性**：允许用户撤销操作，提供清晰的错误提示
- **渐进式透露**：复杂功能通过渐进式界面逐步引导用户

### 阅读体验优化
- **沉浸式设计**：最大化阅读区域，最小化UI干扰
- **主题一致性**：阅读主题应该影响所有相关UI元素，保持整体感
- **智能适配**：根据环境光线、时间等自动调整界面
- **个性化定制**：提供丰富的自定义选项，满足不同用户偏好

### 开发实施要点
- **组件复用**：统一的设计语言通过可复用组件实现
- **主题系统**：通过完善的主题系统确保设计一致性
- **测试驱动**：UI组件的开发应该伴随相应的视觉测试
- **持续优化**：定期收集用户反馈，持续优化体验细节

### 无障碍设计
- **对比度要求**：确保文字和背景有足够的对比度
- **触摸目标**：按钮和可交互元素不小于44×44pt
- **语义标签**：为屏幕阅读器提供适当的语义信息
- **键盘导航**：支持完整的键盘导航流程

---
**最后更新**: 2025-09-21
**更新内容**:
- ✅ **完善Flutter阅读器系统**: 修复legado分页器，实现智能响应式布局和文字完整性保障
- ✅ **FlutterAdvancedReaderWidget组件**: 添加完整控制器API，增强错误处理和参数验证
- ✅ **UI控制栏布局修复**: 解决动画和布局问题，实现流畅的显隐效果
- ✅ **分页算法精确度**: 基于legado原理的字符测量，智能断点检测，85%保守利用率
- ✅ **设备自适应优化**: 手机/大屏手机/平板智能识别，动态调整字体、边距、控制栏
- 添加完整的UI/UX设计规范和动画标准
- 补充底部滑出面板设计模式
- 更新控制栏动画实现指南
- 添加间距、圆角、阴影等视觉设计标准
- 完善开发实施的UI/UX最佳实践

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

#### Glass Effect (毛玻璃效果) Issues
When implementing glass effect (frosted glass) UI elements across different pages:
- **Problem**: Settings page glass effect inconsistent with home/library pages, causing visual anomalies with status bar
- **Root Cause**:
  - Inconsistent blur and opacity parameters (settings: blur=5.0, opacity=0.95 vs standard: blur=15.0, opacity=0.3)
  - Conflicting glass effect implementations (page-level vs wrapper-level)
  - Missing unified configuration system
- **Solution**:
  - Centralize glass effect parameters in `GlassEffectConfig`
  - Use unified wrapper architecture for consistent UI across pages
  - Remove duplicate glass effect implementations from individual pages
- **Implementation Pattern**:
  ```dart
  // Use unified configuration instead of hardcoded values
  BackdropFilter(
    filter: ImageFilter.blur(
      sigmaX: GlassEffectConfig.appBarBlur, // 15.0
      sigmaY: GlassEffectConfig.appBarBlur,
    ),
    child: Container(
      color: Theme.of(context).colorScheme.surface.withValues(
        alpha: GlassEffectConfig.appBarOpacity, // 0.3
      ),
    ),
  )
  ```
- **Architecture**: Settings page uses `_SettingsPageWrapper` to provide unified glass effect, maintaining consistency with `_HomeContentWrapper`
- **Fixed**: 2025-09-25 - Settings page glass effect now matches home/library pages perfectly

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