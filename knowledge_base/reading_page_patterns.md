# 阅读页面设计模式

本文档总结电子书阅读器的阅读页面设计模式、UI架构和交互设计最佳实践。

---

## 目录
1. [页面架构模式](#页面架构模式)
2. [手势交互设计](#手势交互设计)
3. [工具栏设计](#工具栏设计)
4. [文本渲染层](#文本渲染层)
5. [状态管理](#状态管理)
6. [完整实现示例](#完整实现示例)

---

## 页面架构模式

### 1. 分层架构（推荐） ⭐⭐⭐⭐⭐

#### 架构图
```
┌─────────────────────────────────────────┐
│         ReaderPage (根容器)              │
├─────────────────────────────────────────┤
│  ┌───────────────────────────────────┐  │
│  │   ContentLayer (内容层)           │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │  PaginationView (分页视图)  │  │  │
│  │  │   - TextContent (文本)      │  │  │
│  │  │   - ImageContent (图片)     │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
├─────────────────────────────────────────┤
│  ┌───────────────────────────────────┐  │
│  │  GestureLayer (手势层)            │  │
│  │   - Tap / LongPress / Swipe      │  │
│  └───────────────────────────────────┘  │
├─────────────────────────────────────────┤
│  ┌───────────────────────────────────┐  │
│  │  OverlayLayer (覆盖层)            │  │
│  │   - Toolbar (工具栏)              │  │
│  │   - StatusBar (状态栏)            │  │
│  │   - Menu (菜单)                   │  │
│  └───────────────────────────────────┘  │
├─────────────────────────────────────────┤
│  ┌───────────────────────────────────┐  │
│  │  SelectionLayer (选择层)          │  │
│  │   - TextSelection (文本选择)     │  │
│  │   - SelectionToolbar (工具栏)    │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

#### Flutter实现
```dart
class ReaderPage extends ConsumerStatefulWidget {
  final String bookId;
  
  const ReaderPage({Key? key, required this.bookId}) : super(key: key);
  
  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> 
    with TickerProviderStateMixin {
  
  late AnimationController _toolbarAnimController;
  late AnimationController _menuAnimController;
  
  @override
  void initState() {
    super.initState();
    
    // 初始化动画控制器
    _toolbarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    _menuAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // 加载书籍
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(readerStateProvider.notifier).loadBook(widget.bookId);
    });
  }
  
  @override
  void dispose() {
    _toolbarAnimController.dispose();
    _menuAnimController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final readerState = ref.watch(readerStateProvider);
    
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 1️⃣ 内容层
            _ContentLayer(state: readerState),
            
            // 2️⃣ 手势层
            _GestureLayer(
              onTap: _handleTap,
              onLongPress: _handleLongPress,
              onSwipe: _handleSwipe,
            ),
            
            // 3️⃣ 覆盖层
            _OverlayLayer(
              toolbarController: _toolbarAnimController,
              menuController: _menuAnimController,
              state: readerState,
            ),
            
            // 4️⃣ 选择层
            if (readerState.isSelecting)
              _SelectionLayer(state: readerState),
          ],
        ),
      ),
    );
  }
  
  void _handleTap(TapDetails details) {
    final width = MediaQuery.of(context).size.width;
    final x = details.localPosition.dx;
    
    if (x < width * 0.3) {
      // 左侧 - 上一页
      ref.read(readerStateProvider.notifier).previousPage();
    } else if (x > width * 0.7) {
      // 右侧 - 下一页
      ref.read(readerStateProvider.notifier).nextPage();
    } else {
      // 中间 - 切换工具栏
      _toggleToolbar();
    }
  }
  
  void _toggleToolbar() {
    if (_toolbarAnimController.isCompleted) {
      _toolbarAnimController.reverse();
    } else {
      _toolbarAnimController.forward();
    }
  }
  
  void _handleLongPress(LongPressDetails details) {
    // 触发文本选择
    ref.read(readerStateProvider.notifier).startTextSelection(details.localPosition);
  }
  
  void _handleSwipe(SwipeDirection direction) {
    switch (direction) {
      case SwipeDirection.left:
        ref.read(readerStateProvider.notifier).nextPage();
        break;
      case SwipeDirection.right:
        ref.read(readerStateProvider.notifier).previousPage();
        break;
      default:
        break;
    }
  }
}
```

### 2. 内容层设计

#### 多种分页模式
```dart
/// 内容层 - 根据模式切换不同的分页视图
class _ContentLayer extends StatelessWidget {
  final ReaderState state;
  
  const _ContentLayer({required this.state});
  
  @override
  Widget build(BuildContext context) {
    switch (state.paginationMode) {
      case PaginationMode.slide:
        return _SlidePaginationView(state: state);
      case PaginationMode.scroll:
        return _ScrollPaginationView(state: state);
      case PaginationMode.simulation:
        return _SimulationPaginationView(state: state);
      case PaginationMode.cover:
        return _CoverPaginationView(state: state);
    }
  }
}
```

#### 滑动翻页视图
```dart
/// 滑动翻页 - 使用PageView
class _SlidePaginationView extends StatefulWidget {
  final ReaderState state;
  
  const _SlidePaginationView({required this.state});
  
  @override
  State<_SlidePaginationView> createState() => _SlidePaginationViewState();
}

class _SlidePaginationViewState extends State<_SlidePaginationView> {
  late PageController _pageController;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.state.currentPage);
  }
  
  @override
  void didUpdateWidget(_SlidePaginationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.currentPage != widget.state.currentPage) {
      _pageController.jumpToPage(widget.state.currentPage);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.state.pages.length,
      onPageChanged: (index) {
        context.read(readerStateProvider.notifier).setCurrentPage(index);
      },
      itemBuilder: (context, index) {
        return _buildPageContent(widget.state.pages[index]);
      },
    );
  }
  
  Widget _buildPageContent(String content) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SelectableText(
        content,
        style: TextStyle(
          fontSize: widget.state.fontSize,
          height: widget.state.lineSpacing,
          color: widget.state.theme.textColor,
        ),
      ),
    );
  }
}
```

#### 滚动翻页视图
```dart
/// 滚动翻页 - 使用ScrollView
class _ScrollPaginationView extends StatefulWidget {
  final ReaderState state;
  
  const _ScrollPaginationView({required this.state});
  
  @override
  State<_ScrollPaginationView> createState() => _ScrollPaginationViewState();
}

class _ScrollPaginationViewState extends State<_ScrollPaginationView> {
  late ScrollController _scrollController;
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    // 监听滚动，更新当前页码
    _scrollController.addListener(_onScroll);
  }
  
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final offset = _scrollController.offset;
    final screenHeight = MediaQuery.of(context).size.height;
    final currentPage = (offset / screenHeight).round();
    
    if (currentPage != widget.state.currentPage) {
      context.read(readerStateProvider.notifier).setCurrentPage(currentPage);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.state.pages.length,
      itemBuilder: (context, index) {
        return SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SelectableText(
              widget.state.pages[index],
              style: TextStyle(
                fontSize: widget.state.fontSize,
                height: widget.state.lineSpacing,
                color: widget.state.theme.textColor,
              ),
            ),
          ),
        );
      },
    );
  }
}
```

#### 仿真翻页视图
```dart
/// 仿真翻页 - 使用page_flip插件
import 'package:page_flip/page_flip.dart';

class _SimulationPaginationView extends StatefulWidget {
  final ReaderState state;
  
  const _SimulationPaginationView({required this.state});
  
  @override
  State<_SimulationPaginationView> createState() => _SimulationPaginationViewState();
}

class _SimulationPaginationViewState extends State<_SimulationPaginationView> {
  final _controller = GlobalKey<PageFlipWidgetState>();
  
  @override
  Widget build(BuildContext context) {
    return PageFlipWidget(
      key: _controller,
      backgroundColor: widget.state.theme.backgroundColor,
      lastPage: Container(
        color: widget.state.theme.backgroundColor,
        child: const Center(child: Text('已到最后一页')),
      ),
      children: widget.state.pages.map((page) {
        return Container(
          color: widget.state.theme.backgroundColor,
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            page,
            style: TextStyle(
              fontSize: widget.state.fontSize,
              height: widget.state.lineSpacing,
              color: widget.state.theme.textColor,
            ),
          ),
        );
      }).toList(),
    );
  }
}
```

---

## 手势交互设计

### 区域划分策略

```
┌─────────────────────────────────┐
│  ┌─────┐   ┌─────────┐  ┌─────┐ │
│  │     │   │         │  │     │ │
│  │ 上  │   │   工    │  │ 下  │ │
│  │ 一  │   │   具    │  │ 一  │ │
│  │ 页  │   │   栏    │  │ 页  │ │
│  │     │   │   切    │  │     │ │
│  │     │   │   换    │  │     │ │
│  │ 30% │   │   40%   │  │ 30% │ │
│  └─────┘   └─────────┘  └─────┘ │
└─────────────────────────────────┘
```

### 手势识别器实现
```dart
class _GestureLayer extends StatelessWidget {
  final Function(TapDetails) onTap;
  final Function(LongPressDetails) onLongPress;
  final Function(SwipeDirection) onSwipe;
  
  const _GestureLayer({
    required this.onTap,
    required this.onLongPress,
    required this.onSwipe,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      
      // 点击
      onTapUp: (details) => onTap(TapDetails(details.localPosition)),
      
      // 长按
      onLongPressStart: (details) => onLongPress(LongPressDetails(details.localPosition)),
      
      // 滑动
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! < -500) {
          onSwipe(SwipeDirection.left);
        } else if (details.primaryVelocity! > 500) {
          onSwipe(SwipeDirection.right);
        }
      },
      
      // 垂直滑动（滚动模式）
      onVerticalDragUpdate: (details) {
        // 滚动模式下由ScrollView处理
      },
    );
  }
}

class TapDetails {
  final Offset localPosition;
  TapDetails(this.localPosition);
}

class LongPressDetails {
  final Offset localPosition;
  LongPressDetails(this.localPosition);
}

enum SwipeDirection { left, right, up, down }
```

### 音量键翻页
```dart
import 'package:volume_controller/volume_controller.dart';

class VolumeKeyHandler {
  final VolumeController _volumeController = VolumeController();
  double _lastVolume = 0;
  
  void initialize(Function() onVolumeUp, Function() onVolumeDown) {
    _volumeController.getVolume().then((volume) {
      _lastVolume = volume;
    });
    
    _volumeController.listener((volume) {
      if (volume > _lastVolume) {
        onVolumeUp();
      } else if (volume < _lastVolume) {
        onVolumeDown();
      }
      _lastVolume = volume;
    });
  }
  
  void dispose() {
    _volumeController.removeListener();
  }
}

// 在ReaderPage中使用
class _ReaderPageState extends ConsumerState<ReaderPage> {
  late VolumeKeyHandler _volumeKeyHandler;
  
  @override
  void initState() {
    super.initState();
    _volumeKeyHandler = VolumeKeyHandler();
    _volumeKeyHandler.initialize(
      () => ref.read(readerStateProvider.notifier).nextPage(),
      () => ref.read(readerStateProvider.notifier).previousPage(),
    );
  }
  
  @override
  void dispose() {
    _volumeKeyHandler.dispose();
    super.dispose();
  }
}
```

---

## 工具栏设计

### 工具栏布局

#### 顶部工具栏
```dart
class _TopToolbar extends StatelessWidget {
  final Animation<double> animation;
  final ReaderState state;
  
  const _TopToolbar({
    required this.animation,
    required this.state,
  });
  
  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      )),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            // 返回按钮
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            
            // 书名
            Expanded(
              child: Text(
                state.bookTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // 目录按钮
            IconButton(
              icon: const Icon(Icons.menu_book, color: Colors.white),
              onPressed: () => _showTableOfContents(context),
            ),
            
            // 更多按钮
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () => _showMoreMenu(context),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showTableOfContents(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => TableOfContentsSheet(
        chapters: state.chapters,
        currentChapter: state.currentChapter,
      ),
    );
  }
  
  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ReaderMenuSheet(state: state),
    );
  }
}
```

#### 底部工具栏
```dart
class _BottomToolbar extends StatelessWidget {
  final Animation<double> animation;
  final ReaderState state;
  
  const _BottomToolbar({
    required this.animation,
    required this.state,
  });
  
  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      )),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            Row(
              children: [
                Text(
                  '${state.currentPage + 1}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Expanded(
                  child: Slider(
                    value: state.currentPage.toDouble(),
                    min: 0,
                    max: (state.totalPages - 1).toDouble(),
                    onChanged: (value) {
                      context.read(readerStateProvider.notifier).setCurrentPage(value.toInt());
                    },
                  ),
                ),
                Text(
                  '${state.totalPages}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // 功能按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildToolButton(
                  icon: Icons.font_download,
                  label: '字体',
                  onTap: () => _showFontSettings(context),
                ),
                _buildToolButton(
                  icon: Icons.brightness_6,
                  label: '亮度',
                  onTap: () => _showBrightnessSettings(context),
                ),
                _buildToolButton(
                  icon: Icons.palette,
                  label: '主题',
                  onTap: () => _showThemeSettings(context),
                ),
                _buildToolButton(
                  icon: Icons.settings,
                  label: '设置',
                  onTap: () => _showReaderSettings(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 文本渲染层

### 富文本渲染
```dart
class _RichTextRenderer extends StatelessWidget {
  final String content;
  final TextStyle baseStyle;
  final List<HighlightRange> highlights;
  
  const _RichTextRenderer({
    required this.content,
    required this.baseStyle,
    required this.highlights,
  });
  
  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      TextSpan(
        children: _buildTextSpans(),
        style: baseStyle,
      ),
      textAlign: TextAlign.justify,
    );
  }
  
  List<TextSpan> _buildTextSpans() {
    if (highlights.isEmpty) {
      return [TextSpan(text: content)];
    }
    
    final spans = <TextSpan>[];
    int lastEnd = 0;
    
    for (final highlight in highlights) {
      // 高亮前的普通文本
      if (highlight.start > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, highlight.start),
        ));
      }
      
      // 高亮文本
      spans.add(TextSpan(
        text: content.substring(highlight.start, highlight.end),
        style: TextStyle(
          backgroundColor: highlight.color.withOpacity(0.3),
          color: baseStyle.color,
        ),
      ));
      
      lastEnd = highlight.end;
    }
    
    // 最后的普通文本
    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
      ));
    }
    
    return spans;
  }
}

class HighlightRange {
  final int start;
  final int end;
  final Color color;
  
  const HighlightRange({
    required this.start,
    required this.end,
    required this.color,
  });
}
```

### 图文混排
```dart
class _MixedContentRenderer extends StatelessWidget {
  final List<ContentElement> elements;
  final TextStyle textStyle;
  
  const _MixedContentRenderer({
    required this.elements,
    required this.textStyle,
  });
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: elements.map((element) {
          if (element.isText) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(element.content, style: textStyle),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Image.file(
                File(element.content),
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            );
          }
        }).toList(),
      ),
    );
  }
}

class ContentElement {
  final bool isText;
  final String content;
  
  const ContentElement({required this.isText, required this.content});
}
```

---

## 状态管理

### Riverpod状态管理（推荐）
```dart
// 阅读器状态
class ReaderState {
  final String bookId;
  final String bookTitle;
  final List<String> pages;
  final int currentPage;
  final int totalPages;
  final PaginationMode paginationMode;
  final double fontSize;
  final double lineSpacing;
  final ReadingTheme theme;
  final bool isToolbarVisible;
  final bool isSelecting;
  final List<HighlightRange> highlights;
  
  const ReaderState({
    required this.bookId,
    required this.bookTitle,
    this.pages = const [],
    this.currentPage = 0,
    this.totalPages = 0,
    this.paginationMode = PaginationMode.slide,
    this.fontSize = 18,
    this.lineSpacing = 1.8,
    required this.theme,
    this.isToolbarVisible = false,
    this.isSelecting = false,
    this.highlights = const [],
  });
  
  ReaderState copyWith({
    String? bookId,
    String? bookTitle,
    List<String>? pages,
    int? currentPage,
    int? totalPages,
    PaginationMode? paginationMode,
    double? fontSize,
    double? lineSpacing,
    ReadingTheme? theme,
    bool? isToolbarVisible,
    bool? isSelecting,
    List<HighlightRange>? highlights,
  }) {
    return ReaderState(
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      pages: pages ?? this.pages,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      paginationMode: paginationMode ?? this.paginationMode,
      fontSize: fontSize ?? this.fontSize,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      theme: theme ?? this.theme,
      isToolbarVisible: isToolbarVisible ?? this.isToolbarVisible,
      isSelecting: isSelecting ?? this.isSelecting,
      highlights: highlights ?? this.highlights,
    );
  }
}

// 状态管理器
class ReaderStateNotifier extends StateNotifier<ReaderState> {
  ReaderStateNotifier() : super(ReaderState(
    bookId: '',
    bookTitle: '',
    theme: ReadingTheme.light(),
  ));
  
  /// 加载书籍
  Future<void> loadBook(String bookId) async {
    // 1. 从数据库加载书籍信息
    final book = await BookDao.getBook(bookId);
    final content = await BookDao.getContent(bookId);
    
    // 2. 执行分页
    final pages = await _paginate(content);
    
    // 3. 加载阅读进度
    final progress = await ReadingProgressDao.getProgress(bookId);
    
    // 4. 加载高亮
    final highlights = await HighlightDao.getHighlights(bookId);
    
    // 5. 更新状态
    state = state.copyWith(
      bookId: bookId,
      bookTitle: book.title,
      pages: pages,
      totalPages: pages.length,
      currentPage: progress.currentPage,
      highlights: highlights,
    );
  }
  
  /// 下一页
  void nextPage() {
    if (state.currentPage < state.totalPages - 1) {
      setCurrentPage(state.currentPage + 1);
    }
  }
  
  /// 上一页
  void previousPage() {
    if (state.currentPage > 0) {
      setCurrentPage(state.currentPage - 1);
    }
  }
  
  /// 设置当前页
  void setCurrentPage(int page) {
    state = state.copyWith(currentPage: page);
    _saveProgress();
  }
  
  /// 保存阅读进度
  Future<void> _saveProgress() async {
    await ReadingProgressDao.saveProgress(
      bookId: state.bookId,
      currentPage: state.currentPage,
      progress: state.currentPage / state.totalPages,
    );
  }
  
  /// 分页
  Future<List<String>> _paginate(String content) async {
    return await compute(_paginateWorker, PaginationParams(
      text: content,
      pageSize: /* ... */,
      fontSize: state.fontSize,
      lineSpacing: state.lineSpacing,
    ));
  }
}

// Provider定义
final readerStateProvider = StateNotifierProvider<ReaderStateNotifier, ReaderState>(
  (ref) => ReaderStateNotifier(),
);
```

---

## 完整实现示例

完整的阅读页面实现可以参考项目中的 `lib/pages/reader_page.dart` 文件。

### 关键要点总结

1. **分层架构** - 清晰的层次划分
2. **状态管理** - 使用Riverpod集中管理状态
3. **手势识别** - 合理的手势区域划分
4. **动画流畅** - 使用AnimationController
5. **性能优化** - 虚拟列表、缓存等
6. **用户体验** - 工具栏、进度条、快捷操作

---

*更新于: 2025-10-19*

