import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/flutter_advanced_paginator.dart';

/// Flutter原生高级阅读器Widget
/// 基于anx-reader原理，使用Flutter原生组件实现精确分页
class FlutterAdvancedReaderWidget extends StatefulWidget {
  final String text;
  final TextStyle textStyle;
  final EdgeInsets padding;
  final Color backgroundColor;
  final bool preserveWordBoundaries;
  final Function(int currentPage, int totalPages)? onPageChanged;
  final Function(String query)? onTextSelected;
  final VoidCallback? onReachStart;
  final VoidCallback? onReachEnd;
  final VoidCallback? onMiddleClick;
  final bool enablePageIndicator;
  final bool enableTextSelection;

  const FlutterAdvancedReaderWidget({
    Key? key,
    required this.text,
    required this.textStyle,
    this.padding = const EdgeInsets.all(20.0),
    this.backgroundColor = const Color(0xFFFFFBF0),
    this.preserveWordBoundaries = true,
    this.onPageChanged,
    this.onTextSelected,
    this.onReachStart,
    this.onReachEnd,
    this.onMiddleClick,
    this.enablePageIndicator = true,
    this.enableTextSelection = true,
  }) : super(key: key);

  @override
  State<FlutterAdvancedReaderWidget> createState() =>
      _FlutterAdvancedReaderWidgetState();
}

class _FlutterAdvancedReaderWidgetState
    extends State<FlutterAdvancedReaderWidget> {
  late PageController _pageController;
  PaginationResult? _paginationResult;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPageIndex = 0;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializePagination();
  }

  @override
  void didUpdateWidget(FlutterAdvancedReaderWidget oldWidget) {
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
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// 初始化分页
  Future<void> _initializePagination() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // 获取屏幕尺寸
      final size = MediaQuery.of(context).size;

      // 执行分页
      final result = FlutterAdvancedPaginator.paginateText(
        text: widget.text,
        screenSize: size,
        textStyle: widget.textStyle,
        padding: widget.padding,
        preserveWordBoundaries: widget.preserveWordBoundaries,
      );

      if (mounted) {
        setState(() {
          _paginationResult = result;
          _isLoading = false;
          _currentPageIndex = 0;
        });

        _notifyPageChanged();
      }
    } catch (e) {
      debugPrint('分页失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// 通知页面变化
  void _notifyPageChanged() {
    if (_paginationResult != null) {
      widget.onPageChanged?.call(
        _currentPageIndex + 1,
        _paginationResult!.pages.length,
      );
    }
  }

  /// 翻页处理
  void _onPageChanged(int index) {
    setState(() {
      _currentPageIndex = index;
    });

    // 防抖处理
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      _notifyPageChanged();

      // 检查是否到达边界
      if (index == 0) {
        widget.onReachStart?.call();
      } else if (_paginationResult != null &&
          index == _paginationResult!.pages.length - 1) {
        widget.onReachEnd?.call();
      }
    });
  }

  /// 下一页
  void nextPage() {
    if (_paginationResult == null) return;

    final nextIndex = _currentPageIndex + 1;
    if (nextIndex < _paginationResult!.pages.length) {
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onReachEnd?.call();
      // 触觉反馈
      HapticFeedback.lightImpact();
    }
  }

  /// 上一页
  void prevPage() {
    if (_currentPageIndex > 0) {
      _pageController.animateToPage(
        _currentPageIndex - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onReachStart?.call();
      // 触觉反馈
      HapticFeedback.lightImpact();
    }
  }

  /// 跳转到指定页面
  void goToPage(int page) {
    if (_paginationResult == null) return;

    final targetPage = (page - 1).clamp(0, _paginationResult!.pages.length - 1);
    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// 跳转到进度位置
  void goToProgress(double progress) {
    if (_paginationResult == null) return;

    final targetPage = _paginationResult!.metadata.getPageForProgress(progress);
    goToPage(targetPage + 1);
  }

  /// 搜索文本
  List<TextSearchResult> searchText(String query) {
    if (_paginationResult == null) return [];

    return TextSearchHelper.searchInPages(
      pages: _paginationResult!.pages,
      query: query,
    );
  }

  /// 获取当前阅读信息
  ReadingInfo? getCurrentReadingInfo() {
    if (_paginationResult == null) return null;

    final metadata = _paginationResult!.metadata;
    final chapter = metadata.getChapterForPage(_currentPageIndex);

    return ReadingInfo(
      currentPage: _currentPageIndex + 1,
      totalPages: _paginationResult!.pages.length,
      progress: metadata.getProgressForPage(_currentPageIndex),
      chapterTitle: chapter?.title,
      chapterIndex: chapter?.chapterIndex,
    );
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

    if (_paginationResult == null || _paginationResult!.pages.isEmpty) {
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
            '正在分页处理...',
            style: widget.textStyle.copyWith(
              fontSize: 16,
              color: widget.textStyle.color?.withOpacity(0.7),
            ),
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
          color: widget.textStyle.color?.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildPageView() {
    return Stack(
      children: [
        // 主要内容区域
        GestureDetector(
          onTap: _handleTap,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _paginationResult!.pages.length,
            itemBuilder: (context, index) => _buildPage(index),
          ),
        ),

        // 页面指示器
        if (widget.enablePageIndicator) _buildPageIndicator(),
      ],
    );
  }

  Widget _buildPage(int index) {
    final pageContent = _paginationResult!.pages[index];
    final chapter = _paginationResult!.metadata.getChapterForPage(index);

    return Container(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 章节标题（如果是章节开始页面）
          if (chapter != null && chapter.startPage == index)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                chapter.title,
                style: widget.textStyle.copyWith(
                  fontSize: widget.textStyle.fontSize! * 1.2,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // 页面内容
          Expanded(
            child: widget.enableTextSelection
                ? SelectableText(
                    pageContent,
                    style: widget.textStyle,
                    textAlign: TextAlign.justify,
                    onSelectionChanged: (selection, cause) {
                      if (selection.baseOffset != selection.extentOffset) {
                        final selectedText = pageContent.substring(
                          selection.baseOffset,
                          selection.extentOffset,
                        );
                        widget.onTextSelected?.call(selectedText);
                      }
                    },
                  )
                : Text(
                    pageContent,
                    style: widget.textStyle,
                    textAlign: TextAlign.justify,
                  ),
          ),
        ],
      ),
    );
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
            color: widget.textStyle.color?.withOpacity(0.1) ?? Colors.black12,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${_currentPageIndex + 1} / ${_paginationResult!.pages.length}',
            style: widget.textStyle.copyWith(
              fontSize: 12,
              color: widget.textStyle.color?.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }

  /// 处理点击事件
  void _handleTap() {
    // 获取点击位置，实现区域翻页
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // 这里简化处理，直接调用中间点击
    widget.onMiddleClick?.call();
  }
}

/// 阅读信息
class ReadingInfo {
  final int currentPage;
  final int totalPages;
  final double progress;
  final String? chapterTitle;
  final int? chapterIndex;

  const ReadingInfo({
    required this.currentPage,
    required this.totalPages,
    required this.progress,
    this.chapterTitle,
    this.chapterIndex,
  });

  @override
  String toString() {
    return 'ReadingInfo(page: $currentPage/$totalPages, progress: ${(progress * 100).toStringAsFixed(1)}%, chapter: $chapterTitle)';
  }
}

/// 带控制器的高级阅读器Widget
class ControlledFlutterAdvancedReaderWidget extends StatefulWidget {
  final String text;
  final TextStyle textStyle;
  final EdgeInsets padding;
  final Color backgroundColor;
  final bool preserveWordBoundaries;
  final FlutterAdvancedReaderController? controller;
  final Function(int currentPage, int totalPages)? onPageChanged;
  final Function(String query)? onTextSelected;
  final VoidCallback? onReachStart;
  final VoidCallback? onReachEnd;
  final VoidCallback? onMiddleClick;
  final bool enablePageIndicator;
  final bool enableTextSelection;

  const ControlledFlutterAdvancedReaderWidget({
    Key? key,
    required this.text,
    required this.textStyle,
    this.padding = const EdgeInsets.all(20.0),
    this.backgroundColor = const Color(0xFFFFFBF0),
    this.preserveWordBoundaries = true,
    this.controller,
    this.onPageChanged,
    this.onTextSelected,
    this.onReachStart,
    this.onReachEnd,
    this.onMiddleClick,
    this.enablePageIndicator = true,
    this.enableTextSelection = true,
  }) : super(key: key);

  @override
  State<ControlledFlutterAdvancedReaderWidget> createState() =>
      _ControlledFlutterAdvancedReaderWidgetState();
}

class _ControlledFlutterAdvancedReaderWidgetState
    extends State<ControlledFlutterAdvancedReaderWidget> {
  final GlobalKey<_FlutterAdvancedReaderWidgetState> _readerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller?._attach(_readerKey.currentState!);
    });
  }

  @override
  void didUpdateWidget(ControlledFlutterAdvancedReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(_readerKey.currentState!);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterAdvancedReaderWidget(
      key: _readerKey,
      text: widget.text,
      textStyle: widget.textStyle,
      padding: widget.padding,
      backgroundColor: widget.backgroundColor,
      preserveWordBoundaries: widget.preserveWordBoundaries,
      onPageChanged: widget.onPageChanged,
      onTextSelected: widget.onTextSelected,
      onReachStart: widget.onReachStart,
      onReachEnd: widget.onReachEnd,
      onMiddleClick: widget.onMiddleClick,
      enablePageIndicator: widget.enablePageIndicator,
      enableTextSelection: widget.enableTextSelection,
    );
  }
}

/// 阅读器控制器
class FlutterAdvancedReaderController {
  _FlutterAdvancedReaderWidgetState? _state;

  void _attach(_FlutterAdvancedReaderWidgetState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
  }

  /// 下一页
  void nextPage() {
    _state?.nextPage();
  }

  /// 上一页
  void prevPage() {
    _state?.prevPage();
  }

  /// 跳转到指定页面
  void goToPage(int page) {
    _state?.goToPage(page);
  }

  /// 跳转到进度位置
  void goToProgress(double progress) {
    _state?.goToProgress(progress);
  }

  /// 搜索文本
  List<TextSearchResult> searchText(String query) {
    return _state?.searchText(query) ?? [];
  }

  /// 获取当前阅读信息
  ReadingInfo? getCurrentReadingInfo() {
    return _state?.getCurrentReadingInfo();
  }
}
