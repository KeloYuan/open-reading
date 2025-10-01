# 小元读书 (XiaoYuan Reader)

优雅的Flutter跨平台电子书阅读器，支持多种书籍格式，提供舒适的阅读体验。

![Flutter](https://img.shields.io/badge/Flutter-^3.8.1-blue)
![License](https://img.shields.io/badge/License-Private-red)
![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)

## ✨ 主要特性

### 📚 多格式支持
- **EPUB** - 完整的EPUB电子书支持
- **PDF** - 原生PDF阅读体验
- **更多格式** - 支持压缩包等其他电子书格式

### 🎨 精美界面
- **Material 3设计语言** - 现代化的UI设计
- **多主题切换** - 内置多种阅读主题
- **自定义强调色** - 个性化界面配色
- **毛玻璃效果** - 优雅的视觉层次
- **渐变背景** - 沉浸式阅读体验

### 📖 阅读功能
- **智能分页** - 自适应文本布局和分页
- **书签管理** - 便捷的书签添加和管理
- **笔记高亮** - 支持文本选择、高亮和笔记
- **阅读进度** - 实时保存阅读位置
- **目录导航** - 快速章节跳转
- **字体调节** - 自定义字体大小和样式

### 📊 数据统计
- **阅读时长统计** - 详细的阅读时间记录
- **阅读进度追踪** - 可视化阅读进度
- **图表展示** - 使用fl_chart展示阅读数据
- **历史记录** - 完整的阅读历史

### 🛠️ 系统功能
- **文件导入** - 支持从文件系统导入电子书
- **数据持久化** - SQLite数据库存储
- **跨平台兼容** - 支持移动端和桌面端
- **音量键翻页** - 便捷的硬件按键操作

## 🏗️ 技术架构

### 核心框架
- **Flutter** `^3.8.1` - 跨平台UI框架
- **Dart** `^3.8.1` - 编程语言

### 数据层
- **SQLite** (`sqflite ^2.3.0`) - 本地数据库
- **SharedPreferences** (`^2.2.2`) - 配置存储
- **Path Provider** (`^2.1.5`) - 文件路径管理

### UI组件
- **Material 3** - Google最新设计语言
- **Provider** (`^6.1.5`) - 状态管理
- **FL Chart** (`^1.0.0`) - 图表组件

### 文件处理
- **File Picker** (`^8.0.0+1`) - 文件选择
- **Archive** (`^3.4.10`) - 压缩文件处理
- **Crypto** (`^3.0.3`) - 加密和哈希

### 电子书引擎
- **EPUBX** (`^4.0.0`) - EPUB格式支持
- **PDFX** (`^2.6.0`) - PDF格式支持

### 增强功能
- **Page Flip** (`^0.2.0`) - 翻页动画
- **Volume Controller** (`^2.0.8`) - 音量键控制
- **Intl** (`^0.20.2`) - 国际化支持

## 📱 项目结构

```
lib/
├── main.dart                    # 应用入口和主题配置
├── models/                      # 数据模型
│   ├── book.dart               # 书籍模型
│   ├── bookmark.dart           # 书签模型
│   ├── note.dart               # 笔记模型
│   ├── highlight.dart          # 高亮模型
│   └── chapter.dart            # 章节模型
├── pages/                       # 页面组件
│   ├── home_page_responsive.dart     # 主页（响应式）
│   ├── home_content_enhanced.dart    # 主页内容
│   ├── reading_page_enhanced.dart    # 阅读页面
│   ├── library_page.dart            # 书库页面
│   ├── settings_page.dart           # 设置页面
│   ├── detailed_stats_page.dart     # 统计详情
│   └── import_book_page.dart        # 导入书籍
├── services/                    # 业务逻辑
│   ├── database_service.dart    # 数据库服务
│   ├── book_dao.dart           # 书籍数据访问
│   ├── bookmark_dao.dart       # 书签数据访问
│   ├── note_dao.dart           # 笔记数据访问
│   ├── highlight_dao.dart      # 高亮数据访问
│   ├── reading_stats_dao.dart  # 统计数据访问
│   ├── storage_service.dart    # 存储服务
│   ├── book_import_service.dart # 书籍导入
│   └── text_paginator.dart     # 文本分页
├── utils/                       # 工具类
│   ├── app_themes.dart         # 应用主题
│   ├── theme_mixin.dart        # 主题混入
│   ├── glass_config.dart       # 毛玻璃配置
│   ├── progressive_blur.dart   # 渐进模糊
│   ├── responsive_helper.dart  # 响应式辅助
│   ├── color_extensions.dart   # 颜色扩展
│   ├── text_selection_helper.dart # 文本选择辅助
│   ├── text_painter_pagination.dart # 文本绘制分页
│   └── pagination_cache.dart   # 分页缓存
└── widgets/                     # 自定义组件
    ├── liquid_glass_navigation.dart  # 液态玻璃导航
    ├── floating_capsule_navigation.dart # 浮动胶囊导航
    ├── custom_slider_components.dart # 自定义滑块
    ├── note_dialog.dart         # 笔记对话框
    ├── toc_widget.dart          # 目录组件
    └── text_selection_toolbar.dart # 文本选择工具栏
```

## 🚀 快速开始

### 环境要求
- Flutter SDK `^3.8.1`
- Dart SDK `^3.8.1`
- Android Studio / VS Code
- iOS开发需要Xcode（仅限macOS）

### 安装步骤

1. **克隆项目**
```bash
git clone <repository-url>
cd xxread
```

2. **安装依赖**
```bash
flutter pub get
```

3. **运行应用**
```bash
# 调试模式
flutter run

# 发布模式
flutter run --release
```

### 平台特定配置

#### 桌面平台 (Windows/macOS/Linux)
项目已配置`sqflite_common_ffi`，支持桌面平台数据库操作。

#### 移动平台 (iOS/Android)
- Android: 最低API Level 21 (Android 5.0)
- iOS: 最低版本 iOS 11.0

## 🔧 开发说明

### 主要类和接口

#### 主题系统
- `AppTheme` - 应用主题定义
- `AppThemes` - 预设主题集合
- `ThemeNotifier` - 主题状态管理
- `ReadingTheme` - 阅读主题配置

#### 数据访问层 (DAO)
- `BookDao` - 书籍数据操作
- `BookmarkDao` - 书签数据操作
- `NoteDao` - 笔记数据操作
- `HighlightDao` - 高亮数据操作
- `ReadingStatsDao` - 统计数据操作

#### 核心页面
- `HomePageResponsive` - 响应式主页
- `ReadingPageEnhanced` - 增强阅读页
- `LibraryPage` - 书库管理
- `SettingsPage` - 应用设置
- `DetailedStatsPage` - 数据统计

### 开发最佳实践

1. **状态管理**: 使用`Provider`进行状态管理
2. **数据持久化**: 所有数据通过DAO层操作
3. **主题适配**: 继承`ThemeMixin`获得主题能力
4. **响应式设计**: 使用`ResponsiveHelper`适配不同屏幕
5. **错误处理**: 妥善处理异步操作和数据库错误

### 常用命令

```bash
# 代码分析
flutter analyze

# 运行测试
flutter test

# 构建APK
flutter build apk

# 构建iOS
flutter build ios

# 桌面构建
flutter build windows
flutter build macos
flutter build linux

# 清理缓存
flutter clean
flutter pub get
```

## 📖 使用指南

### 导入电子书
1. 点击主页的"导入书籍"按钮
2. 选择支持的电子书文件（EPUB、PDF等）
3. 系统自动解析并添加到书库

### 阅读体验
1. 从书库选择要阅读的书籍
2. 使用手势或音量键翻页
3. 长按文本进行选择、高亮或添加笔记
4. 点击目录按钮快速跳转章节

### 个性化设置
1. 进入设置页面
2. 选择喜欢的阅读主题
3. 调整字体大小和样式
4. 设置全局强调色

## 🤝 贡献指南

欢迎提交Issue和Pull Request来改进项目。

### 开发规范
- 遵循Dart代码规范
- 使用有意义的提交信息
- 确保代码通过`flutter analyze`
- 添加必要的注释和文档

## 📄 许可证

此项目为私有项目，未公开发布。

## 🙏 致谢

感谢Flutter社区和所有开源库的贡献者们。

---

**小元读书** - 让阅读更加优雅 📚✨
