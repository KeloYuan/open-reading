import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
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
    // 设置为沉浸式模式，完全隐藏系统UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );

    // 同时设置系统UI样式为透明
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
    );

    debugPrint('📱 进入沉浸式模式 - 隐藏状态栏和导航栏');
  }

  /// 退出沉浸式模式（恢复状态栏和导航栏）
  void _exitImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );

    // 恢复系统UI样式
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    debugPrint('📱 退出沉浸式模式 - 恢复系统UI');
  }

  /// 显示系统 UI（状态栏和导航栏）- 工具栏显示时使用
  void _showSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    // 设置半透明的系统UI
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black26,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    debugPrint('📱 显示系统UI - 工具栏可见');
  }

  /// 隐藏系统 UI（状态栏和导航栏）- 工具栏隐藏时使用
  void _hideSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );

    // 确保系统UI完全透明
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
    );

    debugPrint('📱 隐藏系统UI - 完全沉浸');
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
      top: 20, // 增加到20px距离顶部，避免圆角屏幕遮挡
      left: 0,
      right: 0,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
      bottom: 20,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                final readerPageState =
                    context.findAncestorStateOfType<_ReaderPageState>();
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
                backgroundColor:
                    settings.textStyle.color?.withValues(alpha: 0.1),
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
                foregroundColor:
                    settings.textStyle.color?.withValues(alpha: 0.7),
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

/// 左右滑动翻页视图 - PageView实现
/// 支持流畅的左右滑动翻页，带有预加载和缓存优化
class _SlidePaginationView extends StatefulWidget {
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
  State<_SlidePaginationView> createState() => _SlidePaginationViewState();
}

class _SlidePaginationViewState extends State<_SlidePaginationView> {
  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: widget.controller,
      onPageChanged: widget.onPageChanged,
      itemCount: widget.pages.length,
      // 优化滚动物理效果
      physics: const PageScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      itemBuilder: (context, index) {
        return _buildPageContent(context, widget.pages[index]);
      },
    );
  }

  Widget _buildPageContent(BuildContext context, String pageContent) {
    return RepaintBoundary(
      child: ClipRect(
        child: Container(
          padding: widget.settings.padding,
          alignment: Alignment.topLeft,
          child: Consumer(
            builder: (context, ref, child) {
              final ttsState = ref.watch(readerTtsProvider);
              return _HighlightedText(
                text: pageContent,
                style: widget.settings.textStyle,
                highlightedSentenceIndex: ttsState.highlightedSentenceIndex,
                enableSelection: widget.settings.enableTextSelection,
                onTextSelection: widget.onTextSelection,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 上下滚动视图 - 分页式垂直滚动
/// 实现类似真实阅读器的分页滚动效果，而非连续滚动
class _ScrollPaginationView extends StatefulWidget {
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
  State<_ScrollPaginationView> createState() => _ScrollPaginationViewState();
}

class _ScrollPaginationViewState extends State<_ScrollPaginationView> {
  int _currentPageIndex = 0;
  double _dragStartOffset = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (_isDragging) return;

    final screenHeight = MediaQuery.of(context).size.height;
    final currentPage = (widget.controller.offset / screenHeight).round();
    final clampedPage = currentPage.clamp(0, widget.pages.length - 1);

    if (clampedPage != _currentPageIndex) {
      setState(() {
        _currentPageIndex = clampedPage;
      });
      widget.onPageChanged?.call(clampedPage);
    }
  }

  void _handleDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragStartOffset = widget.controller.offset;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    // 反向拖拽（向下拖动时减少偏移，向上拖动时增加偏移）
    final newOffset = _dragStartOffset - details.primaryDelta!;
    widget.controller.jumpTo(newOffset.clamp(
      0.0,
      widget.controller.position.maxScrollExtent,
    ));
  }

  void _handleDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    final screenHeight = MediaQuery.of(context).size.height;
    final velocity = details.primaryVelocity ?? 0;
    final currentOffset = widget.controller.offset;

    // 根据拖拽方向和速度决定翻页
    int targetPage = _currentPageIndex;

    if (velocity.abs() > 500) {
      // 快速滑动：根据速度方向翻页
      if (velocity < 0 && _currentPageIndex < widget.pages.length - 1) {
        targetPage = _currentPageIndex + 1; // 向上滑动，下一页
      } else if (velocity > 0 && _currentPageIndex > 0) {
        targetPage = _currentPageIndex - 1; // 向下滑动，上一页
      }
    } else {
      // 慢速滑动：根据偏移量决定
      final currentPageOffset = _currentPageIndex * screenHeight;
      final delta = currentOffset - currentPageOffset;

      if (delta > screenHeight * 0.3 &&
          _currentPageIndex < widget.pages.length - 1) {
        targetPage = _currentPageIndex + 1;
      } else if (delta < -screenHeight * 0.3 && _currentPageIndex > 0) {
        targetPage = _currentPageIndex - 1;
      }
    }

    // 平滑滚动到目标页面
    widget.controller.animateTo(
      targetPage * screenHeight,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );

    if (targetPage != _currentPageIndex) {
      setState(() {
        _currentPageIndex = targetPage;
      });
      widget.onPageChanged?.call(targetPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onVerticalDragStart: _handleDragStart,
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
      child: ListView.builder(
        controller: widget.controller,
        physics: const NeverScrollableScrollPhysics(), // 禁用默认滚动
        itemCount: widget.pages.length,
        itemBuilder: (context, index) {
          return SizedBox(
            height: screenHeight,
            child: Container(
              padding: widget.settings.padding,
              child: Consumer(
                builder: (context, ref, child) {
                  final ttsState = ref.watch(readerTtsProvider);
                  return _HighlightedText(
                    text: widget.pages[index],
                    style: widget.settings.textStyle,
                    highlightedSentenceIndex: ttsState.highlightedSentenceIndex,
                    enableSelection: widget.settings.enableTextSelection,
                    onTextSelection: widget.onTextSelection,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 仿真翻页视图 - 增强版 3D 纸张翻转效果
/// 支持平滑的 3D 翻页动画，模拟真实纸张书的翻页体验
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
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;

  int _currentPage = 0;
  int _nextPage = 0;
  bool _isAnimating = false;
  bool _isForwardFlip = true;
  double _dragStartX = 0.0;
  double _currentDragX = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  /// 初始化动画控制器
  void _initializeAnimations() {
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));

    _shadowAnimation = Tween<double>(
      begin: 0.1,
      end: 0.3,
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));

    _flipController.addStatusListener(_onFlipStatusChanged);
  }

  void _onFlipStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        _currentPage = _nextPage;
        _isAnimating = false;
      });
      _flipController.reset();
      widget.onPageChanged?.call(_currentPage);
    }
  }

  /// 处理水平拖动开始
  void _handleDragStart(DragStartDetails details) {
    if (_isAnimating) return;
    _dragStartX = details.globalPosition.dx;
    _currentDragX = _dragStartX;
  }

  /// 处理水平拖动更新
  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;

    setState(() {
      _currentDragX = details.globalPosition.dx;
    });

    final delta = _currentDragX - _dragStartX;
    final screenWidth = MediaQuery.of(context).size.width;
    final progress = (delta.abs() / screenWidth).clamp(0.0, 1.0);

    // 实时更新动画进度
    if (delta < 0 && _currentPage < widget.pages.length - 1) {
      // 向左拖拽
      _isForwardFlip = true;
      _flipController.value = progress;
    } else if (delta > 0 && _currentPage > 0) {
      // 向右拖拽
      _isForwardFlip = false;
      _flipController.value = progress;
    }
  }

  /// 处理水平拖动结束
  void _handleDragEnd(DragEndDetails details) {
    if (_isAnimating) return;

    final delta = _currentDragX - _dragStartX;
    final velocity = details.primaryVelocity ?? 0;
    final screenWidth = MediaQuery.of(context).size.width;
    final progress = delta.abs() / screenWidth;

    // 决定是否翻页
    bool shouldFlip = false;
    int targetPage = _currentPage;

    if (velocity.abs() > 500) {
      // 快速滑动
      if (velocity < 0 && _currentPage < widget.pages.length - 1) {
        shouldFlip = true;
        targetPage = _currentPage + 1;
        _isForwardFlip = true;
      } else if (velocity > 0 && _currentPage > 0) {
        shouldFlip = true;
        targetPage = _currentPage - 1;
        _isForwardFlip = false;
      }
    } else if (progress > 0.3) {
      // 拖动超过 30%
      if (delta < 0 && _currentPage < widget.pages.length - 1) {
        shouldFlip = true;
        targetPage = _currentPage + 1;
        _isForwardFlip = true;
      } else if (delta > 0 && _currentPage > 0) {
        shouldFlip = true;
        targetPage = _currentPage - 1;
        _isForwardFlip = false;
      }
    }

    if (shouldFlip) {
      // 执行翻页动画
      setState(() {
        _isAnimating = true;
        _nextPage = targetPage;
      });
      _flipController.forward();
    } else {
      // 回弹到当前页
      _flipController.reverse();
    }

    _dragStartX = 0.0;
    _currentDragX = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Stack(
        children: [
          // 背景页（下一页）
          if (_isAnimating || _flipController.value > 0)
            _buildPageContent(_nextPage, isBackground: true),

          // 前景页（当前页）带翻页动画
          AnimatedBuilder(
            animation: _flipController,
            builder: (context, child) {
              final rotationY = _isForwardFlip
                  ? -_flipAnimation.value * 3.14159 * 0.5
                  : _flipAnimation.value * 3.14159 * 0.5;

              return Transform(
                alignment: _isForwardFlip
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002) // 透视效果
                  ..rotateY(rotationY)
                  ..scaleByVector3(vm.Vector3.all(_scaleAnimation.value)),
                child: _buildPageContent(_currentPage),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 构建页面内容
  Widget _buildPageContent(int pageIndex, {bool isBackground = false}) {
    if (pageIndex < 0 || pageIndex >= widget.pages.length) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: widget.settings.backgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isBackground ? 0.05 : _shadowAnimation.value,
              ),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Container(
          padding: widget.settings.padding,
          alignment: Alignment.topLeft,
          child: Consumer(
            builder: (context, ref, child) {
              final ttsState = ref.watch(readerTtsProvider);
              return _HighlightedText(
                text: widget.pages[pageIndex],
                style: widget.settings.textStyle,
                highlightedSentenceIndex: pageIndex == _currentPage
                    ? ttsState.highlightedSentenceIndex
                    : null,
                enableSelection:
                    !isBackground && widget.settings.enableTextSelection,
                onTextSelection: !isBackground ? widget.onTextSelection : null,
              );
            },
          ),
        ),
      ),
    );
  }

  /// 跳转到指定页面
  void goToPage(int pageIndex) {
    if (pageIndex >= 0 &&
        pageIndex < widget.pages.length &&
        !_isAnimating &&
        pageIndex != _currentPage) {
      setState(() {
        _isAnimating = true;
        _nextPage = pageIndex;
        _isForwardFlip = pageIndex > _currentPage;
      });
      _flipController.forward();
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
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
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
          const SizedBox(width: 12),
          _buildIconButton(
            icon: Icons.bookmark_border_rounded,
            onPressed: () {
              HapticFeedback.mediumImpact();
              _handleBookmark(context, ref);
            },
            settings: settings,
          ),
          const SizedBox(width: 8),
          _buildIconButton(
            icon: Icons.list_rounded,
            onPressed: () {
              HapticFeedback.lightImpact();
              _showTableOfContents(context, ref);
            },
            settings: settings,
          ),
          const SizedBox(width: 8),
          _buildIconButton(
            icon: Icons.more_vert_rounded,
            onPressed: () {
              HapticFeedback.lightImpact();
              _showMoreMenu(context, ref, settings);
            },
            settings: settings,
          ),
        ],
      ),
    );
  }

  void _handleBookmark(BuildContext context, WidgetRef ref) {
    // TODO: Implement bookmark functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('书签功能')),
    );
  }

  void _showTableOfContents(BuildContext context, WidgetRef ref) {
    // TODO: Implement TOC navigation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('目录导航')),
    );
  }

  void _showMoreMenu(
      BuildContext context, WidgetRef ref, ReaderSettings settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _getToolbarBackgroundColor(settings),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: settings.textStyle.color?.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              _buildMoreMenuItem(context, Icons.search_rounded, '搜索', settings),
              _buildMoreMenuItem(context, Icons.share_rounded, '分享', settings),
              _buildMoreMenuItem(
                  context, Icons.brightness_6_rounded, '亮度', settings),
              _buildMoreMenuItem(
                  context, Icons.settings_rounded, '设置', settings),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreMenuItem(BuildContext context, IconData icon, String label,
      ReaderSettings settings) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(label)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: settings.textStyle.color?.withValues(alpha: 0.8)),
            const SizedBox(width: 16),
            Text(
              label,
              style: settings.textStyle.copyWith(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomToolbar(
      BuildContext context, WidgetRef ref, ReaderSettings settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一行：进度滑块
          Row(
            children: [
              Text(
                '1',
                style: settings.textStyle.copyWith(fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: 0.5,
                  onChanged: (value) {
                    onInteraction?.call();
                    HapticFeedback.selectionClick();
                  },
                  activeColor: settings.textStyle.color?.withValues(alpha: 0.8),
                  inactiveColor:
                      settings.textStyle.color?.withValues(alpha: 0.2),
                ),
              ),
              Text(
                '100',
                style: settings.textStyle.copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 第二行：控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildThemeToggle(ref, settings),
              _buildFontSizeControls(ref, settings),
              _buildBrightnessControl(ref, settings),
              _buildTtsControls(ref, settings),
              _buildPageFlipMode(ref, settings),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrightnessControl(WidgetRef ref, ReaderSettings settings) {
    return GestureDetector(
      onTap: () {
        onInteraction?.call();
        HapticFeedback.lightImpact();
        _showBrightnessSlider(ref, settings);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: settings.textStyle.color?.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.brightness_6_rounded,
          size: 20,
          color: settings.textStyle.color?.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildPageFlipMode(WidgetRef ref, ReaderSettings settings) {
    return GestureDetector(
      onTap: () {
        onInteraction?.call();
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(ref.context).showSnackBar(
          const SnackBar(content: Text('翻页模式切换')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: settings.textStyle.color?.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.auto_stories_rounded,
          size: 20,
          color: settings.textStyle.color?.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  void _showBrightnessSlider(WidgetRef ref, ReaderSettings settings) {
    // TODO: Implement brightness slider
    ScaffoldMessenger.of(ref.context).showSnackBar(
      const SnackBar(content: Text('亮度调节')),
    );
  }

  Widget _buildThemeToggle(WidgetRef ref, ReaderSettings settings) {
    return GestureDetector(
      onTap: () {
        onInteraction?.call();
        HapticFeedback.lightImpact();
        _cycleTheme(ref);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: settings.textStyle.color?.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _getThemeIcon(settings.theme),
          size: 20,
          color: settings.textStyle.color?.withValues(alpha: 0.8),
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
        HapticFeedback.lightImpact();
        _toggleTts(ref);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ttsState.isPlaying
              ? settings.textStyle.color?.withValues(alpha: 0.2)
              : settings.textStyle.color?.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          ttsState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
}
