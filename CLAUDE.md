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
   - `fast_text_paginator.dart` - **快速文本分页器**（核心，2025-10-04重构）
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

**fast_text_paginator.dart** - 快速逐行分页器（2025-10-04重构）

#### 设计原则
- ✅ **逐行填充算法**：计算每行字符数，逐行填充页面
- ✅ **动态安全系数**：根据行距自动调整安全边距（0.8-1.5倍行高）
- ✅ **字符100%连续**：`currentIndex = endIndex` 确保无缝衔接
- ✅ **零溢出保证**：内容永不超出可见区域
- ✅ **空白最小化**：底部空白通常不超过1行

#### 分页流程
```
1. 计算可用空间（屏幕尺寸 - padding - 安全边距）
2. 根据行距选择安全系数：
   - 行距 < 1.5：安全系数 0.8
   - 行距 < 2.0：安全系数 1.2  
   - 行距 ≥ 2.0：安全系数 1.5
3. 计算每页最大行数：
   - 安全高度 = 行高 × 安全系数
   - 调整后高度 = 可用高度 - 安全高度
   - 最大行数 = floor(调整后高度 / 行高)
4. 逐行填充内容直到达到最大行数
```

#### 关键配置
- `lineSpacing: 1.0-3.0` - 行距（替代原来的lineHeight和paragraphSpacing）
- `letterSpacing: 0.0` - 字间距
- `firstLineIndent: 0.0-4.0` - 首行缩进（字符数）
- `charWidth: fontSize * 0.95 + letterSpacing` - 字符宽度估算

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
   padding: EdgeInsets.only(left: 20.0, right: 20.0, top: 60.0, bottom: 60.0)

   // fast_text_paginator.dart
   final availableWidth = screenSize.width - padding.left - padding.right
   final availableHeight = screenSize.height - padding.top - padding.bottom - safetyHeight
   ```

2. **TextStyle必须一致**
   ```dart
   // 分页器
   TextStyle(fontSize: fontSize, height: lineSpacing, letterSpacing: letterSpacing)

   // 渲染组件
   Text(content, style: widget.settings.textStyle)
   ```

3. **使用动态安全系数**
   - ❌ 固定减去整数行 - 错误，不够精确
   - ✅ 根据行距选择安全系数 - 正确，自适应调整

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

### 2025-10-04: 分页算法全面重构 - 参考legado实现精确分页

**背景**：
- 旧算法基于字符宽度估算，不够精确
- 有的页面内容溢出，有的页面底部大量空白
- 用户反馈希望实现像legado一样的精确分页效果

**解决方案**：

1. ✅ **参考legado分页算法** - `F:\xxread\legado\app\src\main\java\io\legado\app\ui\book\read\page\provider\TextChapterLayout.kt`
   - 逐段累加内容，TextPainter实时测量高度
   - 超出可用高度时开新页
   - 不再依赖字符宽度估算

2. ✅ **首行缩进实现** - `lib/services/fast_text_paginator.dart:329-339`
   ```dart
   // 判断是否是段落首行
   final isFirstLineOfParagraph = pageBuffer.isEmpty || pageBuffer.toString().endsWith('\n');

   // 添加全角空格作为缩进（2个全角空格 = 2个中文字符宽度）
   if (isFirstLineOfParagraph && paragraph.trim().isNotEmpty && firstLineIndent > 0) {
     final indentSpaces = '　' * firstLineIndent.toInt();
     paragraphToAdd = indentSpaces + paragraph;
   }
   ```

3. ✅ **底部对齐算法** - `lib/services/fast_text_paginator.dart:381-417`
   ```dart
   // 计算剩余空间
   final surplus = availableHeight - actualHeight;

   // 如果剩余空间超过1行高度，不做调整（避免行间距过大）
   if (surplus >= singleLineHeight) {
     extraLineSpacing.add(0.0);
     continue;
   }

   // 将剩余空间均匀分配到每行之间
   final extraSpacing = surplus / (lineCount - 1);
   ```

4. ✅ **动态排版参数支持**
   - 字体大小 `fontSize` - 任意调整，TextPainter自动适配
   - 行距 `lineSpacing` - 1.0-3.0倍，实时重新测量
   - 首行缩进 `firstLineIndent` - 0-4字符，全角空格实现
   - 字间距 `letterSpacing` - TextStyle直接支持

**核心改进**：

| 特性 | 旧算法 | 新算法 |
|------|--------|--------|
| 测量方式 | 字符宽度估算 `fontSize * 0.95` | TextPainter实际测量 |
| 分页策略 | 固定行数 × 固定字符数 | 逐段累加，超出分页 |
| 首行缩进 | 无 | 全角空格实现 |
| 底部对齐 | 固定安全系数 | 均匀分配剩余空间 |
| 参数适配 | 需要手动调整安全系数 | 完全动态，TextPainter自适应 |

**效果**：
- ✅ 每页内容精确填满，不溢出不留空白
- ✅ 首行自动缩进2字符（可配置）
- ✅ 底部对齐，行间距自动微调
- ✅ 所有排版参数（字体、行距、缩进）可随时调整，无需修改算法

**代码位置**：
- `lib/services/fast_text_paginator.dart:265-429` - 异步分页（含首行缩进 + 底部对齐）
- `lib/services/fast_text_paginator.dart:435-569` - 同步分页
- `lib/providers/reader_providers.dart:668` - 保存底部对齐数据

**最后更新**: 2025-10-04

---

### 2025-10-04: 分页算法优化 - 动态安全系数与参数简化（已废弃）

**问题**：
1. 部分页面有1-2行内容超出可见区域，需要下滑才能看到
2. 部分页面底部有多余空行（占20%-70%屏幕）
3. 不同行距下表现不一致：行距1.8多1-2行，行距1.7多半行
4. 行高和段间距参数冗余，用户理解困难

**根本原因**：
1. 固定减去整数行数的策略不够精确
2. 未考虑行距对误差累积的影响
3. 行高和段间距概念重叠，增加了用户理解成本

**解决方案**：

1. ✅ **参数简化：合并行高和段间距**
   - 删除 `lineHeight` 和 `paragraphSpacing` 参数
   - 统一为 `lineSpacing`（行距）参数
   - 换行符简单占1行，不再有复杂的段落间距计算
   
   ```dart
   // 简化前
   double lineHeight = 1.8;
   double paragraphSpacing = 8.0;  // 像素
   
   // 简化后
   double lineSpacing = 1.8;  // 统一为行高倍数
   ```

2. ✅ **动态安全系数替代固定减行数** - `lib/services/fast_text_paginator.dart:137-157`
   - 根据行距选择安全系数（0.8-1.5）
   - 先减去安全高度，再计算行数
   - 更精确地适配不同行距
   
   ```dart
   // 旧方案：固定减整数行
   final maxLinesPerPage = theoreticalLines - 2;  // 不够精确
   
   // 新方案：动态安全系数
   double safetyFactor;
   if (lineSpacing < 1.5) {
     safetyFactor = 0.8;  // 行距小，预留0.8倍行高
   } else if (lineSpacing < 2.0) {
     safetyFactor = 1.2;  // 行距中等，预留1.2倍行高
   } else {
     safetyFactor = 1.5;  // 行距大，预留1.5倍行高
   }
   
   final safetyHeight = lineHeightPx * safetyFactor;
   final adjustedHeight = availableHeight - safetyHeight;
   final maxLinesPerPage = (adjustedHeight / lineHeightPx).floor();
   ```

3. ✅ **安全系数策略表**

   | 行距范围 | 安全系数 | 预留高度（fontSize=18px） | 说明 |
   |---------|---------|--------------------------|------|
   | 1.0-1.4 | 0.8 | ~14px-20px | 行距小，误差小 |
   | 1.5-1.9 | 1.2 | ~32px-41px | 行距中等，预留中等 |
   | 2.0+ | 1.5 | ~54px+ | 行距大，误差累积大 |

4. ✅ **修改的文件**
   - `lib/providers/reader_providers.dart` - 状态管理
   - `lib/pages/reader_page.dart` - UI（删除段间距滑块）
   - `lib/services/reader_settings_service.dart` - 设置持久化
   - `lib/services/fast_text_paginator.dart` - 分页算法
   - `lib/services/pagination_cache_service.dart` - 缓存键生成
   - `lib/widgets/reader_toolbar.dart` - 工具栏

**效果**：
- ✅ 内容永不溢出可见区域
- ✅ 底部空白最小化（通常不超过1行）
- ✅ 行距1.7：预留1.2倍行高，解决"多半行"问题
- ✅ 行距1.8：预留1.2倍行高，解决"多1-2行"问题
- ✅ 参数简化，用户更易理解

**核心代码位置**：
- `lib/services/fast_text_paginator.dart:137-157` - 动态安全系数计算
- `lib/services/fast_text_paginator.dart:386-406` - 同步版本实现

**最后更新**: 2025-10-04

### 2025-10-03: TTS朗读功能修复 + 电量显示 + 控制栏动画优化

**问题1: TTS朗读无声音**
- 症状：点击朗读按钮后没有任何声音
- 错误日志：
  ```
  W/TextToSpeech: speak failed: not bound to TTS engine
  E/TTS: Failed to initialize TextToSpeech with status: -1
  ```

**根本原因**：
1. FlutterTts实例在类初始化时创建（第19行），此时Android应用上下文未就绪
2. Android TTS引擎初始化是异步的，但FlutterTts构造函数是同步的
3. speak()在引擎绑定前被调用导致"not bound to TTS engine"错误

**解决方案**：
1. ✅ **延迟创建FlutterTts实例** - `lib/services/tts/system_tts.dart:19`
   ```dart
   late FlutterTts flutterTts;  // 改为late变量
   ```

2. ✅ **在init()中创建FlutterTts** - `lib/services/tts/system_tts.dart:180`
   ```dart
   flutterTts = FlutterTts();  // 在有应用上下文时创建
   await Future.delayed(const Duration(seconds: 2));  // 等待引擎初始化
   ```

3. ✅ **引擎就绪检查** - `lib/services/tts/system_tts.dart:322-327`
   ```dart
   if (!_isTtsEngineReady) {
     _pendingSpeakTasks.add(() => speak(content: content));
     return;
   }
   ```

4. ✅ **移除初始化跳过逻辑** - `lib/providers/reader_providers.dart:827`
   ```dart
   // 每次都执行init()确保引擎正确绑定
   await _systemTts.init(getCurrentText, getNextText, getPrevText);
   ```

**问题2: 电量显示固定85%**
- 症状：阅读页面右上角电量始终显示85%

**解决方案**：
- ✅ **使用battery_plus获取真实电量** - `lib/pages/reader_page.dart:1066`
  ```dart
  final level = await _battery.batteryLevel;
  setState(() { _batteryLevel = level; });
  ```

**问题3: 控制栏关闭无动画**
- 症状：点击屏幕关闭控制栏时，直接消失，没有滑动+淡出动画

**根本原因**：
1. `_hideToolbar()`先调用`hide()`更新状态，然后执行动画
2. `_buildToolbarArea()`检测到`isVisible=false`直接返回空组件
3. 工具栏立即消失，动画还没执行就被移除了

**解决方案**：
1. ✅ **先执行动画再更新状态** - `lib/pages/reader_page.dart:593-608`
   ```dart
   _toolbarAnimationController.reverse().then((_) {
     if (mounted) {
       ref.read(toolbarProvider.notifier).hide();
     }
   });
   ```

2. ✅ **移除isVisible检查** - `lib/pages/reader_page.dart:967-970`
   ```dart
   // 始终渲染工具栏，让动画控制显示/隐藏
   return Stack(children: [...]);
   ```

3. ✅ **优化动画曲线** - `lib/pages/reader_page.dart:352-388`
   - 关闭时长：350ms
   - 透明度：`Cubic(0.0, 0.0, 0.2, 1.0)` - 丝滑淡出
   - 滑动：`Cubic(0.4, 0.0, 1.0, 1.0)` - 流畅加速离开

**代码位置**：
- `lib/services/tts/system_tts.dart`: TTS引擎初始化
- `lib/providers/reader_providers.dart`: TTS初始化逻辑
- `lib/pages/reader_page.dart`: 电量显示、控制栏动画

**最后更新**: 2025-10-03

### 2025-10-02: 全屏模式修复（原生 Android API）

**问题**：
1. 打开书籍后状态栏和导航栏无法完全隐藏
2. 关闭控制栏后全屏不生效
3. InsetsController 日志显示 requestedVisibleTypes 不断切换 (-16 ↔ -9)
4. 状态栏闪烁几次后停止，但仍然可见

**根本原因**：
1. **MainActivity 强制设置废弃的系统 UI 标志** - 与 Flutter 的 SystemChrome 冲突
2. **main.dart 全局更新系统 UI** - 不断覆盖阅读页面的全屏设置
3. **多次延迟调用 _hideSystemUI()** - 导致系统 UI 在显示/隐藏之间反复切换
4. **SystemUiMode.manual/immersive 不够稳定** - 在不同 Android 版本表现不一致

**解决方案**：

1. ✅ **使用原生 Android API（MethodChannel）**
   - Android 11+ (API 30+)：使用 `WindowInsetsController.hide()`
   - Android 10 及以下：使用 `SYSTEM_UI_FLAG_IMMERSIVE_STICKY`
   - 完全绕过 Flutter 的 SystemChrome，直接控制原生窗口

2. ✅ **简化 MainActivity**
   - 移除所有强制的系统 UI 标志
   - 只启用 `edge-to-edge` 模式和透明颜色
   - 通过 MethodChannel 提供 `hideSystemUI()` 和 `showSystemUI()` 方法

3. ✅ **移除所有延迟调用**
   - initState: 只调用一次 `_enterImmersiveMode()`
   - _hideToolbar: 只调用一次 `_hideSystemUI()`
   - didChangeAppLifecycleState: 只调用一次 `_hideSystemUI()`
   - 避免多次设置导致的冲突

4. ✅ **移除 main.dart 的系统 UI 干扰**
   - 删除所有 `_updateSystemUIOverlay()` 调用
   - 让各页面完全自主控制系统 UI

**关键代码**：

MainActivity.kt:
```kotlin
private fun hideSystemUI() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        // Android 11+: WindowInsetsController
        window.insetsController?.let {
            it.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
            it.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
    } else {
        // Android 10-: 废弃标志（但仍有效）
        window.decorView.systemUiVisibility = (
            SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            or SYSTEM_UI_FLAG_HIDE_NAVIGATION
            or SYSTEM_UI_FLAG_FULLSCREEN
        )
    }
}
```

reader_page.dart:
```dart
Future<void> _hideSystemUI() async {
    const platform = MethodChannel('com.niki.xread/fullscreen');
    await platform.invokeMethod('hideSystemUI');
}
```

**为什么原生 API 更可靠**：
- ✅ 直接控制 Android 窗口，无中间层干扰
- ✅ 避免 Flutter 框架的版本兼容问题
- ✅ 支持 Android 11+ 的新 API 和旧版本的降级方案
- ✅ 不会被其他 Flutter 代码覆盖

**代码位置**：
- `android/app/src/main/kotlin/com/example/xxread/MainActivity.kt`
- `lib/pages/reader_page.dart`: `_hideSystemUI()`, `_showSystemUI()`
- `lib/main.dart`: 移除所有系统 UI 更新

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