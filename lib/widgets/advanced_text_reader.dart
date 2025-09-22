import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/text_page_data.dart';
import '../services/precise_text_measurer.dart';
import '../services/advanced_text_paginator.dart';

/// AdvancedTextReader - 主要阅读组件
/// 高精度文本阅读器
/// 支持字符级精确渲染、触摸交互和文字选择
class AdvancedTextReader extends StatefulWidget {
  /// 要显示的文本内容
  final String text;

  /// 文本样式
  final TextStyle textStyle;

  /// 背景颜色
  final Color backgroundColor;

  /// 内边距
  final EdgeInsets padding;

  /// 页面切换回调
  final Function(int currentPage, int totalPages)? onPageChanged;

  /// 文本选择回调
  final Function(String selectedText, int startIndex, int endIndex)?
  onTextSelected;

  /// 点击事件回调
  final VoidCallback? onTap;

  /// 长按事件回调
  final Function(Offset position)? onLongPress;

  /// 是否启用文字选择
  final bool enableTextSelection;

  /// 是否启用页面指示器
  final bool enablePageIndicator;

  /// 动画时长
  final Duration animationDuration;

  const AdvancedTextReader({
    Key? key,
    required this.text,
    required this.textStyle,
    this.backgroundColor = const Color(0xFFFFFBF0),
    this.padding = const EdgeInsets.all(20.0),
    this.onPageChanged,
    this.onTextSelected,
    this.onTap,
    this.onLongPress,
    this.enableTextSelection = true,
    this.enablePageIndicator = true,
    this.animationDuration = const Duration(milliseconds: 300),
  }) : super(key: key);

  @override
  State<AdvancedTextReader> createState() => _AdvancedTextReaderState();
}

class _AdvancedTextReaderState extends State<AdvancedTextReader>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  List<TextPageData> _pages = [];
  int _currentPageIndex = 0;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // 文字选择相关
  bool _isSelecting = false;
  int _selectionStart = -1;
  int _selectionEnd = -1;
  List<TextColumnData> _selectedChars = [];

  // 性能优化
  Timer? _debounceTimer;
  final Map<int, Widget> _pageWidgetCache = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializePagination();
  }

  @override
  void didUpdateWidget(AdvancedTextReader oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 如果文本或样式发生变化，重新分页
    if (oldWidget.text != widget.text ||
        oldWidget.textStyle != widget.textStyle ||
        oldWidget.padding != widget.padding) {
      _initializePagination();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _debounceTimer?.cancel();
    _pageWidgetCache.clear();
    super.dispose();
  }

  /// 初始化控制器
  void _initializeControllers() {
    _pageController = PageController();

    _fadeController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  /// 初始化分页
  Future<void> _initializePagination() async {
    if (widget.text.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = '文本内容为空';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      debugPrint('🔄 开始高级分页处理...');

      // 获取屏幕信息
      final size = MediaQuery.of(context).size;
      final statusBarHeight = MediaQuery.of(context).padding.top;
      final isLandscape = size.width > size.height;

      // 计算分页参数
      final params = AdvancedTextPaginator.calculatePreciseParams(
        screenSize: size,
        fontSize: widget.textStyle.fontSize ?? 18.0,
        lineHeight: widget.textStyle.height ?? 1.8,
        letterSpacing: widget.textStyle.letterSpacing ?? 0.2,
        padding: widget.padding,
        statusBarHeight: statusBarHeight,
        controlBarHeight: 140.0, // 控制栏高度
        isLandscape: isLandscape,
        fontFamily: widget.textStyle.fontFamily,
      );

      // 执行分页
      final pageContents = AdvancedTextPaginator.paginateText(
        widget.text,
        params,
      );

      // 转换为TextPageData列表
      final pages = <TextPageData>[];
      for (int i = 0; i < pageContents.length; i++) {
        final pageContent = pageContents[i];
        final pageData = await _createTextPageData(
          pageContent,
          i,
          pageContents.length,
          params,
        );
        pages.add(pageData);
      }

      if (mounted) {
        setState(() {
          _pages = pages;
          _isLoading = false;
          _currentPageIndex = 0;
        });

        _fadeController.forward();
        _notifyPageChanged();

        debugPrint('✅ 高级分页完成: ${pages.length}页');
      }
    } catch (e) {
      debugPrint('❌ 高级分页失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = '分页处理失败: $e';
        });
      }
    }
  }

  /// 创建TextPageData
  Future<TextPageData> _createTextPageData(
    String content,
    int pageIndex,
    int totalPages,
    PaginationParams params,
  ) async {
    final lines = <TextLineData>[];
    final contentLines = content.split('\n');

    double currentY = widget.padding.top;
    int globalCharIndex = 0;

    for (int lineIndex = 0; lineIndex < contentLines.length; lineIndex++) {
      final lineContent = contentLines[lineIndex];
      if (lineContent.isEmpty) {
        currentY += params.spacingMetrics.actualLineHeight;
        continue;
      }

      // 测量行内字符
      final charWidths = PreciseTextMeasurer.measureCharacterWidths(
        lineContent,
        widget.textStyle,
        context,
      );

      final columns = <TextColumnData>[];
      double currentX = widget.padding.left;

      for (int charIndex = 0; charIndex < lineContent.length; charIndex++) {
        final char = lineContent[charIndex];
        final charWidth = charWidths[charIndex];

        final fontMetrics = PreciseTextMeasurer.measureCharacter(
          char,
          widget.textStyle,
          context,
        );

        final charBounds = Rect.fromLTWH(
          currentX,
          currentY,
          charWidth,
          fontMetrics.height,
        );

        final column = TextColumnData.normal(
          char: char,
          charIndex: globalCharIndex,
          bounds: charBounds,
          baseline: currentY + fontMetrics.ascent,
          fontMetrics: fontMetrics,
        );

        columns.add(column);
        currentX += charWidth;
        globalCharIndex++;
      }

      // 创建行数据
      final lineBounds = Rect.fromLTWH(
        widget.padding.left,
        currentY,
        currentX - widget.padding.left,
        params.spacingMetrics.actualLineHeight,
      );

      final lineData = TextLineData(
        lineIndex: lineIndex,
        columns: columns,
        bounds: lineBounds,
        baseline: currentY + params.fontMetrics.ascent,
        isParagraphEnd: lineIndex == contentLines.length - 1,
        paragraphIndex: 0, // 简化处理
        lineSpacing: params.spacingMetrics.lineSpacingExtra,
      );

      lines.add(lineData);
      currentY += params.spacingMetrics.actualLineHeight;
    }

    // 计算页面边界
    final pageBounds = Rect.fromLTWH(
      0,
      0,
      params.viewMetrics.viewWidth.toDouble(),
      params.viewMetrics.viewHeight.toDouble(),
    );

    return TextPageData(
      index: pageIndex,
      lines: lines,
      startIndex: 0, // 简化处理
      endIndex: content.length,
      characterCount: content.length,
      isLastPage: pageIndex == totalPages - 1,
      readProgress: (pageIndex + 1) / totalPages,
      bounds: pageBounds,
      createTime: DateTime.now(),
    );
  }

  /// 通知页面变化
  void _notifyPageChanged() {
    widget.onPageChanged?.call(_currentPageIndex + 1, _pages.length);
  }

  /// 页面变化处理
  void _onPageChanged(int index) {
    setState(() {
      _currentPageIndex = index;
    });

    // 防抖处理
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      _notifyPageChanged();
    });
  }

  /// 处理点击事件
  void _handleTap(TapDownDetails details) {
    if (_isSelecting) {
      _clearSelection();
      return;
    }

    widget.onTap?.call();
  }

  /// 处理长按事件
  void _handleLongPress(LongPressStartDetails details) {
    if (!widget.enableTextSelection || _pages.isEmpty) return;

    final position = details.localPosition;
    final pageData = _pages[_currentPageIndex];
    final charData = pageData.getCharAtPosition(position);

    if (charData != null) {
      setState(() {
        _isSelecting = true;
        _selectionStart = charData.charIndex;
        _selectionEnd = charData.charIndex + 1;
        _selectedChars = [charData.withSelection(true)];
      });

      HapticFeedback.mediumImpact();
      widget.onLongPress?.call(position);
    }
  }

  /// 处理拖拽选择
  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isSelecting || _pages.isEmpty) return;

    final position = details.localPosition;
    final pageData = _pages[_currentPageIndex];
    final charData = pageData.getCharAtPosition(position);

    if (charData != null) {
      final newEnd = charData.charIndex + 1;
      if (newEnd != _selectionEnd) {
        setState(() {
          _selectionEnd = newEnd;
          _updateSelection();
        });
      }
    }
  }

  /// 更新选择状态
  void _updateSelection() {
    if (_pages.isEmpty || _selectionStart < 0) return;

    final pageData = _pages[_currentPageIndex];
    final start = _selectionStart.clamp(0, pageData.characterCount);
    final end = _selectionEnd.clamp(start, pageData.characterCount);

    _selectedChars = pageData.getSelectionChars(start, end);

    // 通知选择变化
    final selectedText = _selectedChars.map((char) => char.char).join();
    widget.onTextSelected?.call(selectedText, start, end);
  }

  /// 清除选择
  void _clearSelection() {
    setState(() {
      _isSelecting = false;
      _selectionStart = -1;
      _selectionEnd = -1;
      _selectedChars.clear();
    });
  }

  /// 下一页
  void nextPage() {
    if (_currentPageIndex < _pages.length - 1) {
      _pageController.nextPage(
        duration: widget.animationDuration,
        curve: Curves.easeInOut,
      );
    }
  }

  /// 上一页
  void prevPage() {
    if (_currentPageIndex > 0) {
      _pageController.previousPage(
        duration: widget.animationDuration,
        curve: Curves.easeInOut,
      );
    }
  }

  /// 跳转到指定页面
  void goToPage(int page) {
    final targetPage = (page - 1).clamp(0, _pages.length - 1);
    _pageController.animateToPage(
      targetPage,
      duration: widget.animationDuration,
      curve: Curves.easeInOut,
    );
  }

  /// 获取当前阅读信息
  Map<String, dynamic> getReadingInfo() {
    if (_pages.isEmpty) {
      return {
        'currentPage': 0,
        'totalPages': 0,
        'progress': 0.0,
        'hasSelection': false,
      };
    }

    final currentPage = _pages[_currentPageIndex];

    return {
      'currentPage': _currentPageIndex + 1,
      'totalPages': _pages.length,
      'progress': currentPage.readProgress,
      'hasSelection': _isSelecting && _selectedChars.isNotEmpty,
      'selectedText': _isSelecting
          ? _selectedChars.map((c) => c.char).join()
          : '',
      'chapterTitle': currentPage.chapterTitle,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(color: widget.backgroundColor, child: _buildContent());
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_hasError) {
      return _buildErrorWidget();
    }

    if (_pages.isEmpty) {
      return _buildEmptyWidget();
    }

    return _buildPageView();
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: widget.textStyle.color ?? Colors.black,
          ),
          const SizedBox(height: 16),
          Text(
            '高级分页处理中...',
            style: widget.textStyle.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            '分页失败',
            style: widget.textStyle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              style: widget.textStyle.copyWith(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _initializePagination,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Text(
        '没有内容可显示',
        style: widget.textStyle.copyWith(
          fontSize: 16,
          color: widget.textStyle.color?.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildPageView() {
    return Stack(
      children: [
        // 主内容区域
        GestureDetector(
          onTapDown: _handleTap,
          onLongPressStart: _handleLongPress,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: (_) => _updateSelection(),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _pages.length,
              itemBuilder: (context, index) => _buildPage(index),
            ),
          ),
        ),

        // 页面指示器
        if (widget.enablePageIndicator) _buildPageIndicator(),
      ],
    );
  }

  Widget _buildPage(int index) {
    // 使用缓存优化性能
    return _pageWidgetCache.putIfAbsent(index, () {
      final pageData = _pages[index];

      return CustomPaint(
        size: Size.infinite,
        painter: TextPagePainter(
          pageData: pageData,
          textStyle: widget.textStyle,
          selectedChars: _isSelecting && index == _currentPageIndex
              ? _selectedChars
              : [],
        ),
      );
    });
  }

  Widget _buildPageIndicator() {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${_currentPageIndex + 1} / ${_pages.length}',
            style: widget.textStyle.copyWith(
              fontSize: 12,
              color: widget.textStyle.color?.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

/// TextPagePainter - 自定义绘制器
/// 用于精确绘制文本页面
class TextPagePainter extends CustomPainter {
  final TextPageData pageData;
  final TextStyle textStyle;
  final List<TextColumnData> selectedChars;

  TextPagePainter({
    required this.pageData,
    required this.textStyle,
    required this.selectedChars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // 绘制选择背景
    if (selectedChars.isNotEmpty) {
      paint.color = Colors.blue.withValues(alpha: 0.3);
      for (final char in selectedChars) {
        canvas.drawRect(char.bounds, paint);
      }
    }

    // 绘制文本内容
    for (final line in pageData.lines) {
      line.draw(canvas, paint, textStyle);
    }
  }

  @override
  bool shouldRepaint(TextPagePainter oldDelegate) {
    return oldDelegate.pageData != pageData ||
        oldDelegate.selectedChars.length != selectedChars.length;
  }
}
