import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/reader_providers.dart';

/// 覆盖翻页视图
/// 实现新页面从侧面覆盖当前页的效果
class CoverPaginationView extends ConsumerStatefulWidget {
  final List<String> pages;
  final PageController controller;
  final ReaderSettings settings;
  final Function(int)? onPageChanged;
  final Function(String, Offset)? onTextSelection;
  final VoidCallback? onTap;

  const CoverPaginationView({
    super.key,
    required this.pages,
    required this.controller,
    required this.settings,
    this.onPageChanged,
    this.onTextSelection,
    this.onTap,
  });

  @override
  ConsumerState<CoverPaginationView> createState() =>
      _CoverPaginationViewState();
}

class _CoverPaginationViewState extends ConsumerState<CoverPaginationView> {
  int _currentPage = 0;
  double _pageProgress = 0.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPageScroll);
    super.dispose();
  }

  void _onPageScroll() {
    if (!mounted) return;
    setState(() {
      _currentPage = widget.controller.page?.floor() ?? 0;
      _pageProgress = (widget.controller.page ?? 0.0) - _currentPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return PageView.builder(
      controller: widget.controller,
      onPageChanged: widget.onPageChanged,
      itemCount: widget.pages.length,
      itemBuilder: (context, index) {
        final pageContent = widget.pages[index];

        return GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // 当前页内容
              Container(
                color: widget.settings.backgroundColor,
                child: _buildPageContent(
                  pageContent,
                  widget.settings,
                ),
              ),

              // 覆盖层效果
              if (index == _currentPage && _pageProgress > 0)
                _buildCoverOverlay(screenSize, _pageProgress, isNext: true),

              if (index == _currentPage + 1 && _pageProgress > 0)
                _buildCoverPage(
                  screenSize,
                  _pageProgress,
                  widget.pages[index],
                  widget.settings,
                ),
            ],
          ),
        );
      },
    );
  }

  /// 构建页面内容
  Widget _buildPageContent(
    String text,
    ReaderSettings settings,
  ) {
    return Container(
      color: settings.backgroundColor,
      child: ClipRect(
        clipBehavior: Clip.hardEdge,
        child: Consumer(
          builder: (context, ref, _) {
            final paginationState = ref.watch(readerPaginationProvider);
            return _PageText(
              text: text,
              style: settings.textStyle,
              enableSelection: settings.enableTextSelection,
              onTextSelection: widget.onTextSelection,
              maxLines: paginationState.maxLinesPerPage,
            );
          },
        ),
      ),
    );
  }

  /// 构建覆盖层遮罩
  Widget _buildCoverOverlay(Size screenSize, double progress,
      {required bool isNext}) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black.withValues(alpha: 0.1 * progress),
        ),
      ),
    );
  }

  /// 构建覆盖的新页面
  Widget _buildCoverPage(
    Size screenSize,
    double progress,
    String text,
    ReaderSettings settings,
  ) {
    final offset = screenSize.width * (1 - progress);

    return Positioned.fill(
      child: Transform.translate(
        offset: Offset(offset, 0),
        child: Stack(
          children: [
            // 新页面内容
            Container(
              color: settings.backgroundColor,
              child: _buildPageContent(text, settings),
            ),

            // 左侧阴影
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 页面文本渲染组件
class _PageText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Function(String, Offset)? onTextSelection;
  final bool enableSelection;
  final int? maxLines;

  const _PageText({
    required this.text,
    required this.style,
    this.onTextSelection,
    this.enableSelection = true,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return enableSelection
        ? SelectableText(
            text,
            style: style,
            textAlign: TextAlign.left,
            maxLines: maxLines,
          )
        : Text(
            text,
            style: style,
            textAlign: TextAlign.left,
            maxLines: maxLines,
          );
  }
}
