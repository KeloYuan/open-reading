import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/reader_providers.dart';
import '../widgets/enhanced_text_selection_toolbar.dart';
import '../models/book_note.dart';

/// 支持句子高亮的文本渲染组件
class _HighlightedText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int? highlightedSentenceIndex;
  final Color highlightColor;
  final Function(String, Offset)? onTextSelection;
  final bool enableSelection;

  const _HighlightedText({
    required this.text,
    required this.style,
    this.highlightedSentenceIndex,
    Color? highlightColor,
    this.onTextSelection,
    this.enableSelection = true,
  }) : highlightColor = highlightColor ?? const Color(0xFFFFEB3B);

  @override
  Widget build(BuildContext context) {
    if (highlightedSentenceIndex == null || highlightedSentenceIndex! <= -1) {
      // 没有高亮句子，直接返回普通文本
      return enableSelection
          ? SelectableText(
              text,
              style: style,
              textAlign: TextAlign.justify,
              onSelectionChanged: onTextSelection != null
                  ? (selection, cause) {
                      if (!selection.isCollapsed) {
                        final selectedText =
                            text.substring(selection.start, selection.end);
                        _calculateSelectionPosition(
                            context, selection, selectedText);
                      }
                    }
                  : null,
            )
          : Text(
              text,
              style: style,
              textAlign: TextAlign.justify,
            );
    }

    // 分割文本为句子并高亮指定句子
    final sentences = _splitIntoSentences(text);
    if (sentences.isEmpty || highlightedSentenceIndex! >= sentences.length) {
      return enableSelection
          ? SelectableText(
              text,
              style: style,
              textAlign: TextAlign.justify,
              onSelectionChanged: onTextSelection != null
                  ? (selection, cause) {
                      if (!selection.isCollapsed) {
                        final selectedText =
                            text.substring(selection.start, selection.end);
                        _calculateSelectionPosition(
                            context, selection, selectedText);
                      }
                    }
                  : null,
            )
          : Text(
              text,
              style: style,
              textAlign: TextAlign.justify,
            );
    }

    // 构建带有高亮的文本段落
    final spans = <TextSpan>[];

    for (var i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];
      final isHighlighted = i == highlightedSentenceIndex;

      spans.add(TextSpan(
        text: sentence,
        style: style.copyWith(
          backgroundColor:
              isHighlighted ? highlightColor.withValues(alpha: 0.3) : null,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.justify,
    );
  }

  List<String> _splitIntoSentences(String text) {
    // 简单的句子分割逻辑（可以根据需要改进）
    final sentences = <String>[];
    final regex = RegExp(r'[^。！？.!?]+[。！？.!?\s]*');
    final matches = regex.allMatches(text);

    for (final match in matches) {
      sentences.add(match.group(0)!);
    }

    return sentences.isEmpty ? [text] : sentences;
  }

  void _calculateSelectionPosition(
      BuildContext context, TextSelection selection, String selectedText) {
    // 计算选中文本的位置（简化实现）
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && onTextSelection != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      onTextSelection!(selectedText, position);
    }
  }
}

/// 阅读页面 - 核心组件
///
/// 实现沉浸式阅读体验，集成分页引擎、工具栏、TTS等功能
/// 使用Riverpod进行状态管理，采用分层UI架构
class ReaderPage extends ConsumerStatefulWidget {
  /// 书籍文本内容
  final String bookContent;

  /// 书籍标题
  final String? bookTitle;

  /// 初始页面索引
  final int initialPageIndex;

  const ReaderPage({
    Key? key,
    required this.bookContent,
    this.bookTitle,
    this.initialPageIndex = 0,
  }) : super(key: key);

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage>
    with TickerProviderStateMixin {
  // 动画控制器用于工具栏显示隐藏
  late AnimationController _toolbarAnimationController;
  late Animation<double> _toolbarOpacityAnimation;
  late Animation<Offset> _topToolbarSlideAnimation;
  late Animation<Offset> _bottomToolbarSlideAnimation;

  // 自动隐藏工具栏的计时器
  Timer? _autoHideTimer;

  // 文本选择相关状态
  String _selectedText = '';
  bool _showTextSelectionToolbar = false;
  Offset? _selectionToolbarPosition;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializePage();
    _enterImmersiveMode();
  }

  @override
  void dispose() {
    _toolbarAnimationController.dispose();
    _autoHideTimer?.cancel();
    _exitImmersiveMode();
    super.dispose();
  }

  /// 初始化动画控制器
  void _initializeAnimations() {
    _toolbarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 280), // 优化时长，提升响应性
      reverseDuration: const Duration(milliseconds: 220),
      vsync: this,
    );

    _toolbarOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _toolbarAnimationController,
      curve: Curves.fastOutSlowIn, // 使用更流畅的曲线
    ));

    _topToolbarSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _toolbarAnimationController,
      curve: Curves.fastOutSlowIn, // 统一使用流畅曲线
    ));

    _bottomToolbarSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _toolbarAnimationController,
      curve: Curves.fastOutSlowIn, // 统一使用流畅曲线
    ));
  }

  /// 初始化页面
  void _initializePage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePagination();
      _initializeTts();

      // 跳转到初始页面
      if (widget.initialPageIndex > 0) {
        ref
            .read(readerPaginationProvider.notifier)
            .goToPage(widget.initialPageIndex);
      }
    });
  }

  /// 初始化分页
  void _initializePagination() {
    final size = MediaQuery.of(context).size;
    final settings = ref.read(readerSettingsProvider);
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    debugPrint('🎯 初始化沉浸式阅读器分页');
    debugPrint('   - 书籍内容长度: ${widget.bookContent.length} 字符');
    debugPrint('   - 屏幕尺寸: ${size.width.toInt()}x${size.height.toInt()}');

    ref.read(readerPaginationProvider.notifier).initializePagination(
          text: widget.bookContent,
          screenSize: size,
          settings: settings,
          statusBarHeight: statusBarHeight,
          bottomSafeArea: bottomSafeArea,
        );
  }

  /// 初始化TTS
  void _initializeTts() {
    ref.read(readerTtsProvider.notifier).initialize(
          getCurrentText: _getCurrentPageText,
          getNextText: _getNextPageText,
          getPrevText: _getPreviousPageText,
        );
  }

  /// 获取当前页面文本（用于TTS）
  String _getCurrentPageText() {
    final paginationState = ref.read(readerPaginationProvider);
    return paginationState.currentPageContent ?? '';
  }

  /// 获取下一页文本（用于TTS）
  String _getNextPageText() {
    final paginationNotifier = ref.read(readerPaginationProvider.notifier);
    final paginationState = ref.read(readerPaginationProvider);
    final nextIndex = paginationState.currentPageIndex + 1;

    if (nextIndex < paginationState.pages.length) {
      // 切换到下一页
      paginationNotifier.nextPage();
      return paginationState.pages[nextIndex];
    }

    return '';
  }

  /// 获取上一页文本（用于TTS）
  String _getPreviousPageText() {
    final paginationNotifier = ref.read(readerPaginationProvider.notifier);
    final paginationState = ref.read(readerPaginationProvider);
    final prevIndex = paginationState.currentPageIndex - 1;

    if (prevIndex >= 0) {
      // 切换到上一页
      paginationNotifier.previousPage();
      return paginationState.pages[prevIndex];
    }

    return '';
  }

  /// 处理屏幕中央点击 - 显示/隐藏工具栏
  void _handleCenterTap() {
    final toolbarState = ref.read(toolbarProvider);

    if (toolbarState.isVisible) {
      _hideToolbar();
    } else {
      _showToolbar();
    }
  }

  /// 显示工具栏
  void _showToolbar() {
    ref.read(toolbarProvider.notifier).show();
    _toolbarAnimationController.forward();

    // 显示系统 UI（状态栏和导航栏）
    _showSystemUI();

    // 启动自动隐藏计时器
    _startAutoHideTimer();

    // 触觉反馈
    HapticFeedback.lightImpact();
  }

  /// 隐藏工具栏
  void _hideToolbar() {
    ref.read(toolbarProvider.notifier).hide();
    _toolbarAnimationController.reverse();

    // 隐藏系统 UI（状态栏和导航栏）
    _hideSystemUI();

    // 取消自动隐藏计时器
    _cancelAutoHideTimer();
  }

  /// 启动自动隐藏计时器
  void _startAutoHideTimer() {
    _cancelAutoHideTimer();
    _autoHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _hideToolbar();
      }
    });
  }

  /// 取消自动隐藏计时器
  void _cancelAutoHideTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
  }

  /// 进入沉浸式模式（隐藏状态栏和导航栏）
  void _enterImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  /// 退出沉浸式模式（恢复状态栏和导航栏）
  void _exitImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
  }

  /// 显示系统 UI（状态栏和导航栏）
  void _showSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  /// 隐藏系统 UI（状态栏和导航栏）
  void _hideSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  /// 处理文本选择
  void _handleTextSelection(String selectedText, Offset position) {
    setState(() {
      _selectedText = selectedText;
      _selectionToolbarPosition = position;
      _showTextSelectionToolbar = true;
    });
  }

  /// 关闭文本选择工具栏
  void _closeTextSelectionToolbar() {
    setState(() {
      _showTextSelectionToolbar = false;
      _selectedText = '';
      _selectionToolbarPosition = null;
    });
  }

  /// 处理笔记创建
  void _handleNoteCreated(BookNote note) {
    // 可以在这里添加笔记创建后的逻辑，比如显示提示
    debugPrint('笔记已创建: ${note.content}');
  }

  /// 处理笔记更新
  void _handleNoteUpdated(BookNote note) {
    // 可以在这里添加笔记更新后的逻辑，比如显示提示
    debugPrint('笔记已更新: ${note.content}');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final toolbarState = ref.watch(toolbarProvider);

    return Scaffold(
      backgroundColor: settings.backgroundColor,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _getSystemUiOverlayStyle(settings.theme),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              // 主要阅读内容区域 - 沉浸式布局
              _buildReaderContentArea(settings),

              // 页面信息浮层（状态栏和进度）
              _ReaderOverlay(
                showStatusBar: true,
                showProgress: settings.showPageIndicator,
              ),

              // 工具栏（顶部和底部）
              RepaintBoundary(
                child: _buildToolbarArea(toolbarState, settings),
              ),

              // 文本选择工具栏
              if (_showTextSelectionToolbar &&
                  _selectionToolbarPosition != null)
                RepaintBoundary(
                  child: Positioned(
                    left: _selectionToolbarPosition!.dx,
                    top: _selectionToolbarPosition!.dy,
                    child: EnhancedTextSelectionToolbar(
                      selectedText: _selectedText,
                      bookId: 1, // TODO: 从书籍信息获取
                      pageNumber:
                          ref.read(readerPaginationProvider).currentPageIndex +
                              1,
                      chapterTitle: widget.bookTitle ?? '未知章节',
                      cfi:
                          'page-${ref.read(readerPaginationProvider).currentPageIndex + 1}',
                      onNoteCreated: _handleNoteCreated,
                      onNoteUpdated: _handleNoteUpdated,
                      onClose: _closeTextSelectionToolbar,
                      backgroundColor: settings.backgroundColor,
                      iconColor: settings.textStyle.color,
                      textColor: settings.textStyle.color,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建阅读内容区域
  Widget _buildReaderContentArea(ReaderSettings settings) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _handleCenterTap,
        child: _ReaderTextView(
          paginationMode: settings.paginationMode,
          onPageChanged: (pageIndex) {
            // 页面变化时取消自动隐藏计时器
            _cancelAutoHideTimer();
            if (ref.read(toolbarProvider).isVisible) {
              _startAutoHideTimer();
            }
          },
          onTextSelection: _handleTextSelection,
        ),
      ),
    );
  }

  /// 构建工具栏区域
  Widget _buildToolbarArea(ToolbarState toolbarState, ReaderSettings settings) {
    if (!toolbarState.isVisible) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // 半透明背景遮罩
        Positioned.fill(
          child: FadeTransition(
            opacity: _toolbarOpacityAnimation,
            child: Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: GestureDetector(
                onTap: _hideToolbar,
                behavior: HitTestBehavior.translucent,
              ),
            ),
          ),
        ),

        // 顶部工具栏
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: _topToolbarSlideAnimation,
            child: FadeTransition(
              opacity: _toolbarOpacityAnimation,
              child: _ReaderToolbar(
                position: _ToolbarPosition.top,
                onInteraction: _startAutoHideTimer,
              ),
            ),
          ),
        ),

        // 底部工具栏
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: _bottomToolbarSlideAnimation,
            child: FadeTransition(
              opacity: _toolbarOpacityAnimation,
              child: _ReaderToolbar(
                position: _ToolbarPosition.bottom,
                onInteraction: _startAutoHideTimer,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 获取系统UI覆盖样式
  SystemUiOverlayStyle _getSystemUiOverlayStyle(ReadingTheme theme) {
    switch (theme) {
      case ReadingTheme.day:
        return SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        );
      case ReadingTheme.night:
        return SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        );
      case ReadingTheme.eyeCare:
        return SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        );
    }
  }
}

/// ============================================================================
/// 私有组件类 - 符合Riverpod规范，每个build方法控制在80行内
/// ============================================================================

/// 工具栏位置枚举
enum _ToolbarPosition {
  top, // 顶部工具栏
  bottom, // 底部工具栏
}

/// 阅读器浮层信息组件 - Riverpod版本
class _ReaderOverlay extends ConsumerStatefulWidget {
  final bool showStatusBar;
  final bool showProgress;

  const _ReaderOverlay({
    required this.showStatusBar,
    required this.showProgress,
  });

  @override
  ConsumerState<_ReaderOverlay> createState() => _ReaderOverlayState();
}

class _ReaderOverlayState extends ConsumerState<_ReaderOverlay> {
  Timer? _timeUpdateTimer;
  String _currentTime = '';
  int _batteryLevel = 100;

  @override
  void initState() {
    super.initState();
    _initializeOverlay();
  }

  @override
  void dispose() {
    _timeUpdateTimer?.cancel();
    super.dispose();
  }

  void _initializeOverlay() {
    _updateTime();
    _updateBatteryLevel();
    _timeUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateTime();
      _updateBatteryLevel();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    final timeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    if (mounted && timeString != _currentTime) {
      setState(() {
        _currentTime = timeString;
      });
    }
  }

  Future<void> _updateBatteryLevel() async {
    try {
      // 模拟电池电量获取
      if (mounted) {
        setState(() {
          _batteryLevel = 85; // 示例值
        });
      }
    } catch (e) {
      debugPrint('获取电池电量失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);

    return Stack(
      children: [
        if (widget.showStatusBar) _buildTopStatusBar(settings),
        if (widget.showProgress) _buildBottomProgressBar(settings),
      ],
    );
  }

  Widget _buildTopStatusBar(ReaderSettings settings) {
    return Positioned(
      top: MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildTimeDisplay(settings),
            _buildBatteryDisplay(settings),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeDisplay(ReaderSettings settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: settings.textStyle.color?.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _currentTime,
        style: settings.textStyle.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: settings.textStyle.color?.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildBatteryDisplay(ReaderSettings settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: settings.textStyle.color?.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getBatteryIcon(),
            size: 16,
            color: _getBatteryColor(settings),
          ),
          const SizedBox(width: 4),
          Text(
            '$_batteryLevel%',
            style: settings.textStyle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: settings.textStyle.color?.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomProgressBar(ReaderSettings settings) {
    final paginationState = ref.watch(readerPaginationProvider);
    final pageInfo = paginationState.pages.isEmpty
        ? '0/0'
        : '${paginationState.currentPageIndex + 1}/${paginationState.totalPages}';
    final progress = paginationState.progress;

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 20,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildPageInfo(pageInfo, settings),
            _buildProgressInfo(progress, settings),
          ],
        ),
      ),
    );
  }

  Widget _buildPageInfo(String pageInfo, ReaderSettings settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: settings.textStyle.color?.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        pageInfo,
        style: settings.textStyle.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: settings.textStyle.color?.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildProgressInfo(double progress, ReaderSettings settings) {
    final progressPercent = (progress * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: settings.textStyle.color?.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1.5),
              color: settings.textStyle.color?.withValues(alpha: 0.2),
            ),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                settings.textStyle.color?.withValues(alpha: 0.6) ?? Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$progressPercent%',
            style: settings.textStyle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: settings.textStyle.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getBatteryIcon() {
    if (_batteryLevel >= 90) return Icons.battery_full;
    if (_batteryLevel >= 60) return Icons.battery_5_bar;
    if (_batteryLevel >= 40) return Icons.battery_3_bar;
    if (_batteryLevel >= 20) return Icons.battery_2_bar;
    if (_batteryLevel >= 10) return Icons.battery_1_bar;
    return Icons.battery_0_bar;
  }

  Color _getBatteryColor(ReaderSettings settings) {
    final baseColor = settings.textStyle.color ?? Colors.black;
    if (_batteryLevel <= 20) {
      return Colors.red;
    } else if (_batteryLevel <= 40) {
      return Colors.orange;
    } else {
      return baseColor.withValues(alpha: 0.8);
    }
  }
}

/// 阅读文本视图组件 - Riverpod版本
class _ReaderTextView extends ConsumerStatefulWidget {
  final PaginationMode paginationMode;
  final Function(int pageIndex)? onPageChanged;
  final Function(String, Offset)? onTextSelection;

  const _ReaderTextView({
    required this.paginationMode,
    this.onPageChanged,
    this.onTextSelection,
  });

  @override
  ConsumerState<_ReaderTextView> createState() => _ReaderTextViewState();
}

class _ReaderTextViewState extends ConsumerState<_ReaderTextView> {
  PageController? _pageController;
  ScrollController? _scrollController;
  GlobalKey<_SimulationPaginationViewState>? _simulationKey;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void didUpdateWidget(_ReaderTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paginationMode != widget.paginationMode) {
      _initializeControllers();
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _scrollController?.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    _pageController?.dispose();
    _scrollController?.dispose();

    switch (widget.paginationMode) {
      case PaginationMode.slide:
        _pageController = PageController();
        break;
      case PaginationMode.scroll:
        _scrollController = ScrollController();
        break;
      case PaginationMode.simulation:
        _simulationKey = GlobalKey<_SimulationPaginationViewState>();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final paginationState = ref.watch(readerPaginationProvider);
    final settings = ref.watch(readerSettingsProvider);

    if (paginationState.isLoading) {
      return _buildLoadingView(settings);
    }

    if (paginationState.error != null) {
      return _buildErrorView(paginationState.error!, settings);
    }

    if (paginationState.pages.isEmpty) {
      return _buildEmptyView(settings);
    }

    return _buildContentView(paginationState, settings);
  }

  Widget _buildContentView(
      ReaderPaginationState paginationState, ReaderSettings settings) {
    switch (widget.paginationMode) {
      case PaginationMode.slide:
        return _SlidePaginationView(
          pages: paginationState.pages,
          controller: _pageController!,
          settings: settings,
          onPageChanged: _onPageChanged,
          onTextSelection: _onTextSelection,
        );
      case PaginationMode.scroll:
        return _ScrollPaginationView(
          pages: paginationState.pages,
          controller: _scrollController!,
          settings: settings,
          onPageChanged: _onPageChanged,
          onTextSelection: _onTextSelection,
        );
      case PaginationMode.simulation:
        return _SimulationPaginationView(
          key: _simulationKey,
          pages: paginationState.pages,
          settings: settings,
          onPageChanged: _onPageChanged,
          onTextSelection: _onTextSelection,
        );
    }
  }

  void _onPageChanged(int pageIndex) {
    ref.read(readerPaginationProvider.notifier).goToPage(pageIndex);
    widget.onPageChanged?.call(pageIndex);
  }

  void _onTextSelection(String text, Offset position) {
    widget.onTextSelection?.call(text, position);
  }

  Widget _buildLoadingView(ReaderSettings settings) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: settings.textStyle.color),
          const SizedBox(height: 16),
          Text(
            '正在分页处理...',
            style: settings.textStyle.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error, ReaderSettings settings) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 24),
            Text(
              '分页失败',
              style: settings.textStyle.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: settings.textStyle.copyWith(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // 重试按钮
            ElevatedButton.icon(
              onPressed: () {
                // 通过祖先 widget 重新初始化分页
                // 获取 ReaderPage 的 context 并触发重新初始化
                final readerPageState = context.findAncestorStateOfType<_ReaderPageState>();
                if (readerPageState != null) {
                  readerPageState._initializePagination();
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                backgroundColor: settings.textStyle.color?.withValues(alpha: 0.1),
                foregroundColor: settings.textStyle.color,
              ),
            ),
            const SizedBox(height: 16),
            // 返回按钮
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('返回'),
              style: TextButton.styleFrom(
                foregroundColor: settings.textStyle.color?.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(ReaderSettings settings) {
    return Center(
      child: Text(
        '没有内容可显示',
        style: settings.textStyle.copyWith(
          fontSize: 16,
          color: settings.textStyle.color?.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

/// 左右滑动翻页视图
class _SlidePaginationView extends StatelessWidget {
  final List<String> pages;
  final PageController controller;
  final ReaderSettings settings;
  final Function(int)? onPageChanged;
  final Function(String, Offset)? onTextSelection;

  const _SlidePaginationView({
    required this.pages,
    required this.controller,
    required this.settings,
    this.onPageChanged,
    this.onTextSelection,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      onPageChanged: onPageChanged,
      itemCount: pages.length,
      itemBuilder: (context, index) {
        return _buildPageContent(context, pages[index]);
      },
    );
  }

  Widget _buildPageContent(BuildContext context, String pageContent) {
    return Container(
      padding: settings.padding,
      child: Consumer(
        builder: (context, ref, child) {
          final ttsState = ref.watch(readerTtsProvider);
          return _HighlightedText(
            text: pageContent,
            style: settings.textStyle,
            highlightedSentenceIndex: ttsState.highlightedSentenceIndex,
            enableSelection: settings.enableTextSelection,
            onTextSelection: onTextSelection,
          );
        },
      ),
    );
  }
}

/// 上下滚动视图
class _ScrollPaginationView extends StatelessWidget {
  final List<String> pages;
  final ScrollController controller;
  final ReaderSettings settings;
  final Function(int)? onPageChanged;
  final Function(String, Offset)? onTextSelection;

  const _ScrollPaginationView({
    required this.pages,
    required this.controller,
    required this.settings,
    this.onPageChanged,
    this.onTextSelection,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification && onPageChanged != null) {
          final screenHeight = MediaQuery.of(context).size.height * 0.9;
          final currentPage = (controller.offset / screenHeight).round();
          final clampedPage = currentPage.clamp(0, pages.length - 1);
          onPageChanged!(clampedPage);
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: controller,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: pages.asMap().entries.map((entry) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              padding: settings.padding,
              child: Consumer(
                builder: (context, ref, child) {
                  final ttsState = ref.watch(readerTtsProvider);
                  return _HighlightedText(
                    text: entry.value,
                    style: settings.textStyle,
                    highlightedSentenceIndex: ttsState.highlightedSentenceIndex,
                    enableSelection: settings.enableTextSelection,
                    onTextSelection: onTextSelection,
                  );
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// 真实的仿真翻页视图 - 支持3D纸张翻转效果
class _SimulationPaginationView extends StatefulWidget {
  final List<String> pages;
  final ReaderSettings settings;
  final Function(int)? onPageChanged;
  final Function(String, Offset)? onTextSelection;

  const _SimulationPaginationView({
    Key? key,
    required this.pages,
    required this.settings,
    this.onPageChanged,
    this.onTextSelection,
  }) : super(key: key);

  @override
  State<_SimulationPaginationView> createState() =>
      _SimulationPaginationViewState();
}

class _SimulationPaginationViewState extends State<_SimulationPaginationView>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late Animation<double> _scaleAnimation;

  bool _isAnimating = false;
  int _currentPage = 0;
  bool _isForwardFlip = true; // true为向前翻页，false为向后翻页

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600), // 缩短动画时长，提升响应性
      vsync: this,
    );

    // 使用更流畅的动画曲线
    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.fastOutSlowIn, // 使用更流畅的曲线
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.985, // 减小缩放幅度，减少视觉跳跃
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeOutQuart, // 使用更平滑的曲线
    ));

    _flipController.addStatusListener(_onAnimationStatusChanged);
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        _isAnimating = false;
        _currentPage = _pageController.page?.round() ?? _currentPage;
      });
    }
  }

  void _handlePageChange(int pageIndex) {
    if (_isAnimating || pageIndex == _currentPage) return;

    final direction = pageIndex > _currentPage ? 1 : -1;
    _isForwardFlip = direction > 0;

    setState(() {
      _isAnimating = true;
    });

    _flipController.forward(from: 0.0).then((_) {
      _pageController.jumpToPage(pageIndex);
      widget.onPageChanged?.call(pageIndex);
      setState(() {
        _currentPage = pageIndex;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onHorizontalDragEnd: _handleDragEnd,
        child: AnimatedBuilder(
          animation: _flipController,
          builder: (context, child) {
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // 轻微透视效果
                ..rotateY(_isForwardFlip
                    ? _flipAnimation.value * 3.14159
                    : -_flipAnimation.value * 3.14159)
                ..scale(_scaleAnimation.value),
              child: _buildPageContent(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPageContent() {
    return Container(
      padding: widget.settings.padding,
      decoration: BoxDecoration(
        color: widget.settings.backgroundColor,
        boxShadow: _isAnimating
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Consumer(
        builder: (context, ref, child) {
          final ttsState = ref.watch(readerTtsProvider);
          return _HighlightedText(
            text: widget.pages[_currentPage],
            style: widget.settings.textStyle,
            highlightedSentenceIndex: ttsState.highlightedSentenceIndex,
            enableSelection: widget.settings.enableTextSelection,
            onTextSelection: widget.onTextSelection,
          );
        },
      ),
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_isAnimating) return;

    // 根据拖拽速度和方向决定是否翻页
    final velocity = details.primaryVelocity ?? 0;
    const minVelocity = 300.0;

    if (velocity.abs() > minVelocity) {
      if (velocity < 0 && _currentPage < widget.pages.length - 1) {
        // 向左拖拽，前翻页
        _handlePageChange(_currentPage + 1);
      } else if (velocity > 0 && _currentPage > 0) {
        // 向右拖拽，后翻页
        _handlePageChange(_currentPage - 1);
      }
    }
  }

  void goToPage(int pageIndex) {
    if (pageIndex >= 0 && pageIndex < widget.pages.length && !_isAnimating) {
      _handlePageChange(pageIndex);
    }
  }
}

/// 阅读器工具栏 - Riverpod版本（简化实现）
class _ReaderToolbar extends ConsumerWidget {
  final _ToolbarPosition position;
  final VoidCallback? onInteraction;

  const _ReaderToolbar({
    required this.position,
    this.onInteraction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);

    return Container(
      decoration: _buildToolbarDecoration(settings),
      child: SafeArea(
        top: position == _ToolbarPosition.top,
        bottom: position == _ToolbarPosition.bottom,
        child: position == _ToolbarPosition.top
            ? _buildTopToolbar(context, ref, settings)
            : _buildBottomToolbar(context, ref, settings),
      ),
    );
  }

  BoxDecoration _buildToolbarDecoration(ReaderSettings settings) {
    return BoxDecoration(
      color: _getToolbarBackgroundColor(settings),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: position == _ToolbarPosition.top
              ? const Offset(0, 2)
              : const Offset(0, -2),
        ),
      ],
    );
  }

  Color _getToolbarBackgroundColor(ReaderSettings settings) {
    switch (settings.theme) {
      case ReadingTheme.day:
        return const Color(0xFFF8F8F8);
      case ReadingTheme.night:
        return const Color(0xFF2A2A2A);
      case ReadingTheme.eyeCare:
        return const Color(0xFFF0F2E8);
    }
  }

  Widget _buildTopToolbar(
      BuildContext context, WidgetRef ref, ReaderSettings settings) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildIconButton(
            icon: Icons.arrow_back,
            onPressed: () => Navigator.of(context).pop(),
            settings: settings,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '阅读中...',
              style: settings.textStyle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          _buildIconButton(
            icon: Icons.list,
            onPressed: () {},
            settings: settings,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar(
      BuildContext context, WidgetRef ref, ReaderSettings settings) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildThemeToggle(ref, settings),
          _buildFontSizeControls(ref, settings),
          _buildTtsControls(ref, settings),
        ],
      ),
    );
  }

  Widget _buildThemeToggle(WidgetRef ref, ReaderSettings settings) {
    return GestureDetector(
      onTap: () {
        onInteraction?.call();
        _cycleTheme(ref);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: settings.textStyle.color?.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getThemeIcon(settings.theme),
              size: 20,
              color: settings.textStyle.color?.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 4),
            Text(
              _getThemeName(settings.theme),
              style: settings.textStyle.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontSizeControls(WidgetRef ref, ReaderSettings settings) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconButton(
          icon: Icons.text_decrease,
          onPressed: () {
            onInteraction?.call();
            _decreaseFontSize(ref);
          },
          settings: settings,
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: settings.textStyle.color?.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${settings.fontSize.toInt()}',
            style: settings.textStyle.copyWith(fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        _buildIconButton(
          icon: Icons.text_increase,
          onPressed: () {
            onInteraction?.call();
            _increaseFontSize(ref);
          },
          settings: settings,
        ),
      ],
    );
  }

  Widget _buildTtsControls(WidgetRef ref, ReaderSettings settings) {
    final ttsState = ref.watch(readerTtsProvider);

    return GestureDetector(
      onTap: () {
        onInteraction?.call();
        _toggleTts(ref);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ttsState.isPlaying
              ? settings.textStyle.color?.withValues(alpha: 0.2)
              : settings.textStyle.color?.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          ttsState.isPlaying ? Icons.pause : Icons.play_arrow,
          size: 20,
          color: settings.textStyle.color?.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required ReaderSettings settings,
  }) {
    return GestureDetector(
      onTap: () {
        onInteraction?.call();
        onPressed();
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: settings.textStyle.color?.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 20,
          color: settings.textStyle.color?.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  void _cycleTheme(WidgetRef ref) {
    final settings = ref.read(readerSettingsProvider);
    ReadingTheme nextTheme;

    switch (settings.theme) {
      case ReadingTheme.day:
        nextTheme = ReadingTheme.night;
        break;
      case ReadingTheme.night:
        nextTheme = ReadingTheme.eyeCare;
        break;
      case ReadingTheme.eyeCare:
        nextTheme = ReadingTheme.day;
        break;
    }

    ref.read(readerSettingsProvider.notifier).switchTheme(nextTheme);
  }

  void _increaseFontSize(WidgetRef ref) {
    final currentSize = ref.read(readerSettingsProvider).fontSize;
    ref.read(readerSettingsProvider.notifier).updateFontSize(currentSize + 1);
  }

  void _decreaseFontSize(WidgetRef ref) {
    final currentSize = ref.read(readerSettingsProvider).fontSize;
    ref.read(readerSettingsProvider.notifier).updateFontSize(currentSize - 1);
  }

  void _toggleTts(WidgetRef ref) {
    final ttsState = ref.read(readerTtsProvider);
    final ttsNotifier = ref.read(readerTtsProvider.notifier);

    if (ttsState.isPlaying) {
      ttsNotifier.pause();
    } else {
      final currentPageContent =
          ref.read(readerPaginationProvider).currentPageContent;
      ttsNotifier.play(text: currentPageContent);
    }
  }

  IconData _getThemeIcon(ReadingTheme theme) {
    switch (theme) {
      case ReadingTheme.day:
        return Icons.wb_sunny;
      case ReadingTheme.night:
        return Icons.nights_stay;
      case ReadingTheme.eyeCare:
        return Icons.eco;
    }
  }

  String _getThemeName(ReadingTheme theme) {
    switch (theme) {
      case ReadingTheme.day:
        return '白天';
      case ReadingTheme.night:
        return '夜间';
      case ReadingTheme.eyeCare:
        return '护眼';
    }
  }
}
