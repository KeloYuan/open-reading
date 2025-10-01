import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reader_providers.dart';

/// 阅读文本视图组件
///
/// 根据翻页模式显示不同的文本视图：
/// - 左右滑动：PageView翻页
/// - 上下滚动：ScrollView滚动
/// - 仿真翻页：PageFlip动画翻页
class ReaderTextView extends StatefulWidget {
  /// 翻页模式
  final PaginationMode paginationMode;

  /// 页面变化回调
  final Function(int pageIndex)? onPageChanged;

  const ReaderTextView({
    Key? key,
    required this.paginationMode,
    this.onPageChanged,
  }) : super(key: key);

  @override
  State<ReaderTextView> createState() => _ReaderTextViewState();
}

class _ReaderTextViewState extends State<ReaderTextView> {
  PageController? _pageController;
  ScrollController? _scrollController;
  GlobalKey<_SimulationPaginationViewState>? _simulationKey;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void didUpdateWidget(ReaderTextView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 翻页模式变化时重新初始化控制器
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

  /// 初始化控制器
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
    return Consumer2<ReaderPaginationNotifier, ReaderSettingsNotifier>(
      builder: (context, paginationNotifier, settingsNotifier, child) {
        final paginationState = paginationNotifier.state;
        final settings = settingsNotifier.state;

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
      },
    );
  }

  /// 构建内容视图
  Widget _buildContentView(
      ReaderPaginationState paginationState, ReaderSettings settings) {
    switch (widget.paginationMode) {
      case PaginationMode.slide:
        return _SlidePaginationView(
          pages: paginationState.pages,
          controller: _pageController!,
          settings: settings,
          onPageChanged: _onPageChanged,
        );
      case PaginationMode.scroll:
        return _ScrollPaginationView(
          pages: paginationState.pages,
          controller: _scrollController!,
          settings: settings,
          onPageChanged: _onPageChanged,
        );
      case PaginationMode.simulation:
        return _SimulationPaginationView(
          key: _simulationKey,
          pages: paginationState.pages,
          settings: settings,
          onPageChanged: _onPageChanged,
        );
    }
  }

  /// 页面变化处理
  void _onPageChanged(int pageIndex) {
    final paginationNotifier = context.read<ReaderPaginationNotifier>();
    final currentIndex = paginationNotifier.state.currentPageIndex;

    if (pageIndex != currentIndex) {
      paginationNotifier.goToPage(pageIndex);
    }

    widget.onPageChanged?.call(pageIndex);
  }

  /// 构建加载视图
  Widget _buildLoadingView(ReaderSettings settings) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: settings.textStyle.color,
          ),
          const SizedBox(height: 16),
          Text(
            '正在分页处理...',
            style: settings.textStyle.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// 构建错误视图
  Widget _buildErrorView(String error, ReaderSettings settings) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              '分页失败',
              style: settings.textStyle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: settings.textStyle.copyWith(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // 重新分页
                final size = MediaQuery.of(context).size;
                final settings = context.read<ReaderSettingsNotifier>().state;
                final paginationNotifier =
                    context.read<ReaderPaginationNotifier>();

                // 这里需要获取原始文本，暂时使用空字符串
                paginationNotifier.initializePagination(
                  text: '',
                  screenSize: size,
                  settings: settings,
                );
              },
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建空内容视图
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

  const _SlidePaginationView({
    required this.pages,
    required this.controller,
    required this.settings,
    this.onPageChanged,
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

  /// 构建页面内容
  Widget _buildPageContent(BuildContext context, String pageContent) {
    return Container(
      padding: settings.padding,
      child: settings.enableTextSelection
          ? SelectableText(
              pageContent,
              style: settings.textStyle,
              textAlign: TextAlign.justify,
            )
          : Text(
              pageContent,
              style: settings.textStyle,
              textAlign: TextAlign.justify,
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

  const _ScrollPaginationView({
    required this.pages,
    required this.controller,
    required this.settings,
    this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification && onPageChanged != null) {
          // 计算当前显示的页面
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
              child: settings.enableTextSelection
                  ? SelectableText(
                      entry.value,
                      style: settings.textStyle,
                      textAlign: TextAlign.justify,
                    )
                  : Text(
                      entry.value,
                      style: settings.textStyle,
                      textAlign: TextAlign.justify,
                    ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// 仿真翻页视图（暂时使用PageView代替）
class _SimulationPaginationView extends StatefulWidget {
  final List<String> pages;
  final ReaderSettings settings;
  final Function(int)? onPageChanged;

  const _SimulationPaginationView({
    Key? key,
    required this.pages,
    required this.settings,
    this.onPageChanged,
  }) : super(key: key);

  @override
  State<_SimulationPaginationView> createState() =>
      _SimulationPaginationViewState();
}

class _SimulationPaginationViewState extends State<_SimulationPaginationView> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.pages.length,
      onPageChanged: (index) {
        widget.onPageChanged?.call(index);
      },
      itemBuilder: (context, index) {
        return Container(
          padding: widget.settings.padding,
          decoration: BoxDecoration(
            color: widget.settings.backgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: widget.settings.enableTextSelection
              ? SelectableText(
                  widget.pages[index],
                  style: widget.settings.textStyle,
                  textAlign: TextAlign.justify,
                )
              : Text(
                  widget.pages[index],
                  style: widget.settings.textStyle,
                  textAlign: TextAlign.justify,
                ),
        );
      },
    );
  }

  /// 跳转到指定页面
  void goToPage(int pageIndex) {
    if (pageIndex >= 0 && pageIndex < widget.pages.length) {
      _pageController.animateToPage(
        pageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
}
