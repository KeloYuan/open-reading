# CLAUDE.md

此文件为Claude AI助手提供在该仓库中工作时的指导信息。

## 项目概述

小元读书 (XiaoYuan Reader) 是一个功能丰富的Flutter跨平台电子书阅读器，支持EPUB、PDF、TXT等多种格式。应用具备本地存储、阅读进度追踪、书签管理、阅读统计、TTS朗读、高亮笔记和响应式设计等功能，支持移动端和桌面端。

## 开发命令

### 核心Flutter命令
- `flutter pub get` - 安装依赖
- `flutter run` - 调试模式运行应用
- `flutter run -d macos` - macOS平台运行
- `flutter run -d windows` - Windows平台运行
- `flutter analyze` - 代码分析和Lint检查
- `flutter clean` - 清理缓存和构建文件

## 技术架构

### 核心分层

1. **表现层** (`lib/pages/`): UI组件和页面
   - `home_page_responsive.dart` - 响应式主页，药丸导航栏
   - `library_page.dart` - 书库管理页面
   - `reader_page.dart` - 主阅读页面，支持左右滑动翻页
   - `settings_page.dart` - 设置页面
   - `import_book_page.dart` - 书籍导入功能

2. **业务逻辑层** (`lib/services/`):
   - `database_service.dart` - SQLite数据库管理
   - `book_dao.dart` - 书籍数据访问
   - `bookmark_dao.dart` - 书签数据访问
   - `reading_stats_dao.dart` - 阅读统计数据访问
   - `simple_text_paginator.dart` - **简单文本分页器**（核心）
   - `book_import_service.dart` - 书籍导入处理

3. **数据层** (`lib/models/`):
   - `book.dart` - 书籍实体
   - `bookmark.dart` - 书签实体

4. **状态管理** (`lib/providers/`):
   - `reader_providers.dart` - 阅读器状态管理（Riverpod）

### 数据库设计

使用SQLite，主要表：
- `books` - 书籍元数据和阅读进度
- `bookmarks` - 用户书签
- `reading_stats` - 阅读统计

跨平台支持：
- 移动端：sqflite
- 桌面端：sqflite_common_ffi

### 文本分页系统（核心）

**simple_text_paginator.dart** - 简单精确的分页实现

#### 设计原则
- ❌ **不使用保守值**：完全根据实际测量分页
- ✅ **TextPainter精确测量**：测量文本实际渲染高度
- ✅ **二分查找算法**：找到能放入页面的最大字符数
- ✅ **字符100%连续**：`currentIndex = endIndex` 确保无缝衔接
- ✅ **动态适配屏幕**：根据实际容器尺寸自动调整

#### 分页流程
```
1. 计算可用空间（屏幕尺寸 - padding）
2. 创建TextPainter（配置与实际渲染完全一致）
3. 二分查找最佳字符数：
   - 测量候选文本的实际渲染高度
   - 如果高度 <= 可用高度：增加字符数
   - 如果高度 > 可用高度：减少字符数
4. 添加页面内容并验证连续性
```

#### 关键配置
- `textAlign: TextAlign.justify` - 必须与Text组件一致
- `maxWidth: availableWidth` - 约束文本宽度
- `height: lineHeight` - 行高系数
- `letterSpacing: 0.0` - 无额外字符间距

### UI渲染系统

**reader_page.dart** - 阅读页面实现

#### PageView配置
- `physics: PageScrollPhysics` - 只允许左右滑动
- `ClipRect` - 裁剪超出内容，防止上下滚动

#### 关键要点
- ❌ 不使用 `SingleChildScrollView` - 会导致上下滑动
- ✅ 使用 `ClipRect` 直接裁剪超出内容
- ✅ PageView自动处理左右翻页
- ✅ Container padding必须与分页器padding一致

### 主题系统
- Material 3设计语言
- 毛玻璃效果（GlassConfig）
- 支持Light/Dark模式
- 响应式布局适配

## 开发注意事项

### 分页系统规则（重要！）

1. **padding必须一致**
   ```dart
   // reader_providers.dart
   padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0)

   // simple_text_paginator.dart
   finalavailableWidth = screenSize.width - padding.left - padding.right
   final availableHeight = screenSize.height - padding.top - padding.bottom
   ```

2. **TextStyle必须一致**
   ```dart
   // 分页器
   TextStyle(fontSize: fontSize, height: lineHeight, letterSpacing: 0.0)

   // 渲染组件
   Text(content, style: widget.settings.textStyle)
   ```

3. **不要使用保守值！**
   - ❌ `charsPerPage * 0.85` - 错误，浪费空间
   - ✅ 用TextPainter实际测量 - 正确，精确分页

4. **PageView只允许左右滑动**
   ```dart
   PageView(
     physics: PageScrollPhysics(), // 只左右滑动
     children: pages.map((page) =>
       ClipRect(  // 裁剪超出内容
         child: Container(
           padding: settings.padding,
           child: Text(page),
         ),
       ),
     ),
   )
   ```

### 代码质量
- 使用 `flutter analyze` 检查代码
- 使用 Material 3 API
- 避免 `color.value`，使用 `withValues(alpha:)`
- 清理未使用的变量和方法

### UI规范
- 动画时长：300ms标准
- 触觉反馈：`HapticFeedback.lightImpact()`
- 圆角：12px标准，20px大卡片
- 间距：8px基础网格

## 关键依赖

### 核心框架
- Flutter ^3.8.1
- Riverpod - 状态管理

### 数据存储
- sqflite - 移动端数据库
- sqflite_common_ffi - 桌面端数据库
- shared_preferences - 设置存储

### 电子书支持
- epubx - EPUB格式
- pdfx - PDF格式（仅支持渲染，不支持文本提取）

### UI增强
- fl_chart - 图表
- page_flip - 翻页动画

## 历史修复问题

### 2025-10-01: 阅读页面控制栏交互修复

**问题**：
1. 点击屏幕中间无法呼出控制栏，只有在翻页的瞬间点击才有效
2. 控制栏显示时背景变暗（有半透明黑色遮罩）

**根本原因**：
- `GestureDetector` 的点击事件被子组件（PageView、SelectableText等）的手势识别器拦截
- 手势识别在竞技场（Gesture Arena）中竞争，子组件优先级更高
- 使用了半透明背景遮罩层 `Colors.black.withValues(alpha: 0.3)`

**解决方案**：
1. ✅ 移除背景遮罩层 - 控制栏显示时背景保持原样
2. ✅ 使用 `Listener` 替代 `GestureDetector` 监听原始指针事件
3. ✅ 实现智能点击检测：
   ```dart
   // 判断是否为点击（而非滑动）
   if (duration < 300ms && distance < 10px) {
     _handleCenterTap();  // 呼出/隐藏控制栏
   }
   ```

**关键技术点**：
- `Listener` 监听底层指针事件，在手势竞技场之前触发，不会被拦截
- `HitTestBehavior.translucent` 允许事件穿透，不影响子组件交互
- 通过时间和距离判断区分点击和滑动手势
- 完全不影响翻页、文本选择等其他功能

**代码位置**：
- `lib/pages/reader_page.dart`: `_handlePointerDown()`, `_handlePointerUp()`

### 2025-09-30: 分页系统重构

**问题**：
1. 使用保守值（75%、85%）导致空间浪费
2. 字符不连续，页面之间丢字
3. 文字超出屏幕可以上下滑动

**解决方案**：
1. ✅ 创建 `simple_text_paginator.dart`
2. ✅ 使用 TextPainter 精确测量文本高度
3. ✅ 二分查找最佳字符数
4. ✅ 使用 ClipRect 裁剪超出内容
5. ✅ 移除 SingleChildScrollView，禁止上下滑动
6. ✅ 保证字符100%连续（currentIndex = endIndex）

### UI优化
1. ✅ 恢复页码、电量、进度的美观UI设计
2. ✅ PageView只允许左右滑动
3. ✅ 顶部工具栏添加书签、目录、更多按钮
4. ✅ 底部控制栏双行布局（进度条 + 控制按钮）

## 总结

**核心原则**：
1. 分页用TextPainter实际测量，不用估算
2. 字符100%连续，currentIndex = endIndex
3. padding和TextStyle必须一致
4. PageView只左右滑动，ClipRect裁剪超出内容
5. 不要使用保守值，根据实际测量结果分页

**最后更新**: 2025-10-01