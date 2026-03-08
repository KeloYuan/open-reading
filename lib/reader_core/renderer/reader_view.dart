import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/rendering.dart' show SelectedContentRange;

import '../data/reader_models.dart';
import '../document/flow_doc.dart';
import '../paginator/page_plan.dart';
import '../selection/reader_selection.dart';

typedef SelectionActionCallback = void Function(ReaderSelectionPayload payload);
typedef ChapterBoundaryCallback = void Function(
    ChapterBoundaryDirection direction);

enum ChapterBoundaryDirection {
  previous,
  next,
}

enum ReaderPageTurnAnimation {
  slide,
  cover,
  scroll,
  chapterScroll,
  simulation,
}

extension ReaderPageTurnAnimationPrefs on ReaderPageTurnAnimation {
  String get prefValue {
    switch (this) {
      case ReaderPageTurnAnimation.slide:
        return 'slide';
      case ReaderPageTurnAnimation.cover:
        return 'cover';
      case ReaderPageTurnAnimation.scroll:
        return 'scroll';
      case ReaderPageTurnAnimation.chapterScroll:
        return 'chapter_scroll';
      case ReaderPageTurnAnimation.simulation:
        return 'simulation';
    }
  }

  static ReaderPageTurnAnimation? fromPrefValue(String? value) {
    switch (value) {
      case 'slide':
        return ReaderPageTurnAnimation.slide;
      case 'cover':
        return ReaderPageTurnAnimation.cover;
      case 'scroll':
        return ReaderPageTurnAnimation.scroll;
      case 'chapter_scroll':
        return ReaderPageTurnAnimation.chapterScroll;
      case 'simulation':
        // Temporarily disable simulation mode and migrate to cover.
        return ReaderPageTurnAnimation.cover;
    }
    return null;
  }
}

class ReaderView extends StatefulWidget {
  final FlowDoc flowDoc;
  final PagePlan pagePlan;
  final String? chapterPlainText;
  final Map<String, Uint8List> chapterResources;
  final String? currentChapterTitle;
  final Color? pageBackgroundColor;
  final Color? textColor;
  final ReaderStyle style;
  final PageLayout layout;
  final List<Annotation> annotations;
  final int initialPageIndex;
  final bool enablePageAnimation;
  final ReaderPageTurnAnimation pageTurnAnimation;
  final ValueChanged<int>? onPageChanged;
  final SelectionActionCallback? onSelectionAction;
  final ChapterBoundaryCallback? onReachChapterBoundary;

  const ReaderView({
    super.key,
    required this.flowDoc,
    required this.pagePlan,
    this.chapterPlainText,
    this.chapterResources = const {},
    this.currentChapterTitle,
    this.pageBackgroundColor,
    this.textColor,
    required this.style,
    required this.layout,
    required this.annotations,
    this.initialPageIndex = 0,
    this.enablePageAnimation = true,
    this.pageTurnAnimation = ReaderPageTurnAnimation.slide,
    this.onPageChanged,
    this.onSelectionAction,
    this.onReachChapterBoundary,
  });

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  PageController? _singleController;
  PageController? _spreadController;
  bool _programmaticPaging = false;
  double _singleScrollDirection = 1.0;

  int _clampPageIndex(int index) {
    final pages = widget.pagePlan.pages;
    if (pages.isEmpty) {
      return 0;
    }
    return index.clamp(0, pages.length - 1).toInt();
  }

  int _clampSpreadIndexFromPage(int pageIndex) {
    final spreadCount = (widget.pagePlan.pages.length / 2).ceil();
    if (spreadCount <= 0) {
      return 0;
    }
    return (pageIndex ~/ 2).clamp(0, spreadCount - 1).toInt();
  }

  @override
  void initState() {
    super.initState();
    if (widget.layout.columns <= 1) {
      _singleController =
          PageController(initialPage: _clampPageIndex(widget.initialPageIndex));
    } else {
      _spreadController = PageController(
        initialPage: _clampSpreadIndexFromPage(widget.initialPageIndex),
      );
    }
  }

  @override
  void didUpdateWidget(covariant ReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final columnsChanged = oldWidget.layout.columns != widget.layout.columns;
    final chapterChanged =
        oldWidget.pagePlan.chapterId != widget.pagePlan.chapterId ||
            oldWidget.pagePlan.cacheKey != widget.pagePlan.cacheKey;

    if (columnsChanged) {
      _singleController?.dispose();
      _spreadController?.dispose();
      _singleController = null;
      _spreadController = null;
      if (widget.layout.columns <= 1) {
        _singleController = PageController(
            initialPage: _clampPageIndex(widget.initialPageIndex));
      } else {
        _spreadController = PageController(
          initialPage: _clampSpreadIndexFromPage(widget.initialPageIndex),
        );
      }
      return;
    }

    if (widget.layout.columns <= 1) {
      _singleController ??=
          PageController(initialPage: _clampPageIndex(widget.initialPageIndex));
      if (chapterChanged) {
        _jumpSingleTo(_clampPageIndex(widget.initialPageIndex));
      } else {
        _syncSingleFromExternalState();
      }
      return;
    }

    _spreadController ??= PageController(
      initialPage: _clampSpreadIndexFromPage(widget.initialPageIndex),
    );
    if (chapterChanged) {
      _jumpSpreadTo(_clampSpreadIndexFromPage(widget.initialPageIndex));
    } else {
      _syncSpreadFromExternalState();
    }
  }

  void _jumpSingleTo(int targetPage) {
    final controller = _singleController;
    if (controller == null || !controller.hasClients) {
      return;
    }
    _updateSingleDirectionForTarget(controller, targetPage);
    _programmaticPaging = true;
    controller.jumpToPage(targetPage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _programmaticPaging = false;
    });
  }

  void _jumpSpreadTo(int targetSpread) {
    final controller = _spreadController;
    if (controller == null || !controller.hasClients) {
      return;
    }
    _programmaticPaging = true;
    controller.jumpToPage(targetSpread);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _programmaticPaging = false;
    });
  }

  void _syncSingleFromExternalState() {
    if (_programmaticPaging) {
      return;
    }
    final controller = _singleController;
    if (controller == null || !controller.hasClients) {
      return;
    }
    final target = _clampPageIndex(widget.initialPageIndex);
    final current = (controller.page ?? target.toDouble()).round();
    if (current == target) {
      return;
    }
    _updateSingleDirectionForTarget(controller, target);
    _programmaticPaging = true;
    controller
        .animateToPage(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    )
        .whenComplete(() {
      _programmaticPaging = false;
    });
  }

  void _syncSpreadFromExternalState() {
    if (_programmaticPaging) {
      return;
    }
    final controller = _spreadController;
    if (controller == null || !controller.hasClients) {
      return;
    }
    final target = _clampSpreadIndexFromPage(widget.initialPageIndex);
    final current = (controller.page ?? target.toDouble()).round();
    if (current == target) {
      return;
    }
    _programmaticPaging = true;
    controller
        .animateToPage(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    )
        .whenComplete(() {
      _programmaticPaging = false;
    });
  }

  @override
  void dispose() {
    _singleController?.dispose();
    _spreadController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.pagePlan.pages;
    final pagePadding = EdgeInsets.fromLTRB(
      widget.layout.padding.left,
      widget.layout.padding.top,
      widget.layout.padding.right,
      widget.layout.padding.bottom,
    );
    final maxVisibleLines = math.max(
      1,
      (widget.layout.usableHeight /
              (widget.style.fontSize * widget.style.lineHeight))
          .floor(),
    );
    final isChapterScrollMode =
        widget.pageTurnAnimation == ReaderPageTurnAnimation.chapterScroll;
    if (isChapterScrollMode) {
      final pageCount = math.max(1, pages.length);
      final initialPage = _clampPageIndex(widget.initialPageIndex);
      return _ChapterScrollPane(
        style: widget.style,
        flowDoc: widget.flowDoc,
        chapterPlainText: widget.chapterPlainText,
        chapterTitle: widget.currentChapterTitle,
        pagePadding: pagePadding,
        pageUsableWidth: widget.layout.usableWidth,
        pageUsableHeight: widget.layout.usableHeight,
        pageBackgroundColor: widget.pageBackgroundColor,
        textColor: widget.textColor,
        virtualPageCount: pageCount,
        initialPageIndex: initialPage,
        onPageChanged: widget.onPageChanged,
        onReachChapterBoundary: widget.onReachChapterBoundary,
      );
    }
    if (pages.isEmpty) {
      return _PagePane(
        key: const ValueKey('page-fallback'),
        page: _buildFallbackPageFromFlowDoc(),
        style: widget.style,
        flowDoc: widget.flowDoc,
        chapterPlainText: widget.chapterPlainText,
        chapterResources: widget.chapterResources,
        chapterTitle: widget.currentChapterTitle,
        showChapterTitle: false,
        pagePadding: pagePadding,
        maxVisibleLines: maxVisibleLines,
        pageUsableWidth: widget.layout.usableWidth,
        pageUsableHeight: widget.layout.usableHeight,
        pageBackgroundColor: widget.pageBackgroundColor,
        textColor: widget.textColor,
        annotations: widget.annotations,
        onSelectionAction: widget.onSelectionAction,
      );
    }

    if (widget.layout.columns <= 1) {
      _singleController ??=
          PageController(initialPage: _clampPageIndex(widget.initialPageIndex));
      final scrollAxis =
          widget.pageTurnAnimation == ReaderPageTurnAnimation.scroll
              ? Axis.vertical
              : Axis.horizontal;
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) => _handleBoundaryOverscroll(
            notification, widget.onReachChapterBoundary),
        child: PageView.builder(
          controller: _singleController,
          scrollDirection: scrollAxis,
          itemCount: pages.length,
          onPageChanged: (index) {
            widget.onPageChanged?.call(index);
          },
          itemBuilder: (context, index) {
            final page = pages[index];
            final pane = _buildPagePane(
              page: page,
              showChapterTitle: page.index == 0,
              pagePadding: pagePadding,
              maxVisibleLines: maxVisibleLines,
            );
            return _wrapSinglePageTurnAnimation(index: index, child: pane);
          },
        ),
      );
    }

    final spreadCount = (pages.length / 2).ceil();
    _spreadController ??= PageController(
      initialPage: _clampSpreadIndexFromPage(widget.initialPageIndex),
    );

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) => _handleBoundaryOverscroll(
          notification, widget.onReachChapterBoundary),
      child: PageView.builder(
        controller: _spreadController,
        itemCount: spreadCount,
        onPageChanged: (spread) => widget.onPageChanged
            ?.call((spread * 2).clamp(0, pages.length - 1).toInt()),
        itemBuilder: (context, spreadIndex) {
          final leftIndex = spreadIndex * 2;
          final rightIndex = leftIndex + 1;

          final left = pages[leftIndex];
          final right = rightIndex < pages.length ? pages[rightIndex] : null;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            child: Row(
              children: [
                Expanded(
                  child: _buildPagePane(
                    page: left,
                    showChapterTitle: left.index == 0,
                    pagePadding: pagePadding,
                    maxVisibleLines: maxVisibleLines,
                  ),
                ),
                SizedBox(width: widget.layout.gutter),
                Expanded(
                  child: right == null
                      ? const SizedBox.shrink()
                      : _buildPagePane(
                          page: right,
                          showChapterTitle: right.index == 0,
                          pagePadding: pagePadding,
                          maxVisibleLines: maxVisibleLines,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _updateSingleDirectionForTarget(PageController controller, int target) {
    final current = controller.page ?? target.toDouble();
    final delta = target - current;
    if (delta.abs() < 0.001) {
      return;
    }
    _singleScrollDirection = delta.sign;
  }

  Widget _buildPagePane({
    required Page page,
    required bool showChapterTitle,
    required EdgeInsets pagePadding,
    required int maxVisibleLines,
  }) {
    return _PagePane(
      key: ValueKey('page-${page.index}'),
      page: page,
      style: widget.style,
      flowDoc: widget.flowDoc,
      chapterPlainText: widget.chapterPlainText,
      chapterResources: widget.chapterResources,
      chapterTitle: widget.currentChapterTitle,
      showChapterTitle: showChapterTitle,
      pagePadding: pagePadding,
      maxVisibleLines: maxVisibleLines,
      pageUsableWidth: widget.layout.usableWidth,
      pageUsableHeight: widget.layout.usableHeight,
      pageBackgroundColor: widget.pageBackgroundColor,
      textColor: widget.textColor,
      annotations: widget.annotations,
      onSelectionAction: widget.onSelectionAction,
    );
  }

  Widget _wrapSinglePageTurnAnimation({
    required int index,
    required Widget child,
  }) {
    final controller = _singleController;
    if (!widget.enablePageAnimation || controller == null) {
      return child;
    }

    if (widget.pageTurnAnimation == ReaderPageTurnAnimation.simulation) {
      // Temporarily disable simulation animation to avoid unstable behavior.
      return child;
    }

    if (widget.pageTurnAnimation != ReaderPageTurnAnimation.cover) {
      return child;
    }

    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, animatedChild) {
        if (!controller.hasClients || !controller.position.haveDimensions) {
          return animatedChild!;
        }
        final currentPage =
            controller.page ?? controller.initialPage.toDouble();
        final delta = index - currentPage;
        if (delta.abs() >= 1.0) {
          return animatedChild!;
        }

        final viewportWidth = controller.position.viewportDimension;
        if (viewportWidth <= 0) {
          return animatedChild!;
        }

        final direction = _singleScrollDirection;
        final isForwardOutgoing = direction >= 0 && delta < 0;
        final isBackwardOutgoing = direction < 0 && delta > 0;
        final isBackwardIncoming = direction < 0 && delta < 0;
        if (!isForwardOutgoing && !isBackwardOutgoing && !isBackwardIncoming) {
          return animatedChild!;
        }

        if (isForwardOutgoing) {
          // Next-page cover: keep current page anchored, let next page slide
          // above it.
          return Transform.translate(
            offset: Offset(-delta * viewportWidth, 0),
            child: animatedChild,
          );
        }

        if (isBackwardIncoming) {
          // Previous-page reveal: keep previous page anchored under the top
          // page, so the current page can slide out to the right above it.
          return Transform.translate(
            offset: Offset(-delta * viewportWidth, 0),
            child: animatedChild,
          );
        }

        // Previous-page reveal: keep current(top) page on the natural PageView
        // trajectory so it slides to the right and reveals the previous page
        // beneath it.
        return animatedChild!;
      },
    );
  }

  bool _handleBoundaryOverscroll(
    ScrollNotification notification,
    ChapterBoundaryCallback? callback,
  ) {
    final singleScrollAxis =
        widget.pageTurnAnimation == ReaderPageTurnAnimation.scroll
            ? Axis.vertical
            : Axis.horizontal;
    if (notification is ScrollUpdateNotification &&
        notification.metrics.axis == singleScrollAxis) {
      final delta = notification.scrollDelta;
      if (delta != null && delta.abs() > 0.001) {
        _singleScrollDirection = delta.sign;
      }
    }

    if (callback == null || notification is! OverscrollNotification) {
      return false;
    }
    if (notification.metrics.axis != singleScrollAxis) {
      return false;
    }
    final metrics = notification.metrics;
    final atStart = metrics.pixels <= metrics.minScrollExtent + 0.5;
    final atEnd = metrics.pixels >= metrics.maxScrollExtent - 0.5;
    if (notification.overscroll < 0 && atStart) {
      callback(ChapterBoundaryDirection.previous);
      return true;
    }
    if (notification.overscroll > 0 && atEnd) {
      callback(ChapterBoundaryDirection.next);
      return true;
    }
    return false;
  }

  Page _buildFallbackPageFromFlowDoc() {
    for (final block in widget.flowDoc.blocks) {
      if (block is ImageBlock) {
        return Page(
          index: 0,
          startOffset: 0,
          endOffset: 0,
          fragments: <Fragment>[
            ImageFragment(blockId: block.id),
          ],
        );
      }
    }
    return const Page(
      index: 0,
      startOffset: 0,
      endOffset: 0,
      fragments: [],
    );
  }
}

class _ChapterScrollPane extends StatefulWidget {
  final ReaderStyle style;
  final FlowDoc flowDoc;
  final String? chapterPlainText;
  final String? chapterTitle;
  final EdgeInsets pagePadding;
  final double pageUsableWidth;
  final double pageUsableHeight;
  final Color? pageBackgroundColor;
  final Color? textColor;
  final int virtualPageCount;
  final int initialPageIndex;
  final ValueChanged<int>? onPageChanged;
  final ChapterBoundaryCallback? onReachChapterBoundary;

  const _ChapterScrollPane({
    required this.style,
    required this.flowDoc,
    required this.chapterPlainText,
    required this.chapterTitle,
    required this.pagePadding,
    required this.pageUsableWidth,
    required this.pageUsableHeight,
    required this.pageBackgroundColor,
    required this.textColor,
    required this.virtualPageCount,
    required this.initialPageIndex,
    required this.onPageChanged,
    required this.onReachChapterBoundary,
  });

  @override
  State<_ChapterScrollPane> createState() => _ChapterScrollPaneState();
}

class _ChapterScrollPaneState extends State<_ChapterScrollPane> {
  static const TextHeightBehavior _textHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: true,
    applyHeightToLastDescent: true,
  );

  final ScrollController _scrollController = ScrollController();
  int _lastVirtualPageIndex = -1;
  DateTime? _lastBoundaryTriggerAt;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_emitVirtualPageIfNeeded);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        _emitVirtualPageIfNeeded();
        return;
      }
      final maxExtent = _scrollController.position.maxScrollExtent;
      final pageCount = math.max(1, widget.virtualPageCount);
      if (maxExtent <= 0 || pageCount <= 1) {
        _emitVirtualPageIfNeeded();
        return;
      }
      final ratio = (widget.initialPageIndex / (pageCount - 1)).clamp(0.0, 1.0);
      final targetOffset = (maxExtent * ratio).clamp(0.0, maxExtent);
      if (targetOffset > 0.0) {
        _scrollController.jumpTo(targetOffset);
      }
      _emitVirtualPageIfNeeded();
    });
  }

  @override
  void didUpdateWidget(covariant _ChapterScrollPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.virtualPageCount != widget.virtualPageCount) {
      _lastVirtualPageIndex = -1;
      _emitVirtualPageIfNeeded();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_emitVirtualPageIfNeeded);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg =
        widget.pageBackgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
    final fg = widget.textColor ?? Theme.of(context).colorScheme.onSurface;
    final chapterTitle = widget.chapterTitle?.trim() ?? '';
    final chapterText = _chapterTextForScroll();
    final baseStyle = widget.style.toTextStyle(color: fg);
    final minContentHeight = math.max(
      80.0,
      widget.pageUsableHeight - widget.pagePadding.vertical,
    );

    return Container(
      color: bg,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleBoundaryOverscroll,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: widget.pagePadding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: minContentHeight,
              minWidth: widget.pageUsableWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (chapterTitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      chapterTitle,
                      style: baseStyle.copyWith(
                        fontSize: (widget.style.fontSize * 1.2).clamp(16, 34),
                        fontWeight: FontWeight.w700,
                        height: 1.22,
                      ),
                      textScaler: TextScaler.noScaling,
                      textHeightBehavior: _textHeightBehavior,
                    ),
                  ),
                if (chapterText.isNotEmpty)
                  SelectableText(
                    chapterText,
                    style: baseStyle.copyWith(height: widget.style.lineHeight),
                    textAlign: widget.style.textAlign,
                    textScaler: TextScaler.noScaling,
                    textHeightBehavior: _textHeightBehavior,
                  )
                else
                  Text(
                    '本章暂无可显示内容',
                    style: baseStyle,
                    textScaler: TextScaler.noScaling,
                    textHeightBehavior: _textHeightBehavior,
                  ),
                const SizedBox(height: 20),
                _buildBoundaryButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoundaryButtons(BuildContext context) {
    final callback = widget.onReachChapterBoundary;
    final enabled = callback != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: enabled
                  ? () => callback(ChapterBoundaryDirection.previous)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('上一章'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: enabled
                  ? () => callback(ChapterBoundaryDirection.next)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('下一章'),
            ),
          ),
        ],
      ),
    );
  }

  bool _handleBoundaryOverscroll(ScrollNotification notification) {
    final callback = widget.onReachChapterBoundary;
    if (callback == null || notification is! OverscrollNotification) {
      return false;
    }
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final now = DateTime.now();
    if (_lastBoundaryTriggerAt != null &&
        now.difference(_lastBoundaryTriggerAt!) <
            const Duration(milliseconds: 420)) {
      return false;
    }
    final metrics = notification.metrics;
    final atStart = metrics.pixels <= metrics.minScrollExtent + 0.5;
    final atEnd = metrics.pixels >= metrics.maxScrollExtent - 0.5;
    if (notification.overscroll < 0 && atStart) {
      _lastBoundaryTriggerAt = now;
      callback(ChapterBoundaryDirection.previous);
      return true;
    }
    if (notification.overscroll > 0 && atEnd) {
      _lastBoundaryTriggerAt = now;
      callback(ChapterBoundaryDirection.next);
      return true;
    }
    return false;
  }

  void _emitVirtualPageIfNeeded() {
    final callback = widget.onPageChanged;
    if (callback == null) {
      return;
    }
    if (!_scrollController.hasClients) {
      final initial = widget.initialPageIndex
          .clamp(
            0,
            math.max(0, widget.virtualPageCount - 1),
          )
          .toInt();
      if (initial != _lastVirtualPageIndex) {
        _lastVirtualPageIndex = initial;
        callback(initial);
      }
      return;
    }

    final pageCount = math.max(1, widget.virtualPageCount);
    final position = _scrollController.position;
    final maxExtent = position.maxScrollExtent;
    final ratio =
        maxExtent <= 0 ? 0.0 : (position.pixels / maxExtent).clamp(0.0, 1.0);
    final index = (ratio * (pageCount - 1))
        .round()
        .clamp(0, math.max(0, pageCount - 1))
        .toInt();
    if (index == _lastVirtualPageIndex) {
      return;
    }
    _lastVirtualPageIndex = index;
    callback(index);
  }

  String _chapterTextForScroll() {
    final raw = (widget.chapterPlainText?.isNotEmpty ?? false)
        ? widget.chapterPlainText!
        : widget.flowDoc.toPlainText();
    if (raw.isEmpty) {
      return raw;
    }
    var value = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    int end = value.length;
    while (end > 0 && value.codeUnitAt(end - 1) == 0x0A) {
      end -= 1;
    }
    if (end <= 0) {
      return '';
    }
    if (end != value.length) {
      value = value.substring(0, end);
    }
    return value;
  }
}

class _PagePane extends StatefulWidget {
  final Page page;
  final ReaderStyle style;
  final FlowDoc flowDoc;
  final String? chapterPlainText;
  final Map<String, Uint8List> chapterResources;
  final String? chapterTitle;
  final bool showChapterTitle;
  final EdgeInsets pagePadding;
  final int maxVisibleLines;
  final double pageUsableWidth;
  final double pageUsableHeight;
  final Color? pageBackgroundColor;
  final Color? textColor;
  final List<Annotation> annotations;
  final SelectionActionCallback? onSelectionAction;

  const _PagePane({
    super.key,
    required this.page,
    required this.style,
    required this.flowDoc,
    required this.chapterPlainText,
    required this.chapterResources,
    required this.chapterTitle,
    required this.showChapterTitle,
    required this.pagePadding,
    required this.maxVisibleLines,
    required this.pageUsableWidth,
    required this.pageUsableHeight,
    required this.pageBackgroundColor,
    required this.textColor,
    required this.annotations,
    required this.onSelectionAction,
  });

  @override
  State<_PagePane> createState() => _PagePaneState();
}

class _PagePaneState extends State<_PagePane> {
  static const bool _promoteChapterTitleOnFirstPage = false;
  static const double _textInkHorizontalGuard = 1.0;
  static const TextHeightBehavior _textHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: true,
    applyHeightToLastDescent: true,
  );
  static const bool _debugRenderLogs = false;
  static const double _overflowWarnThreshold = 0.01;
  final SelectionListenerNotifier _selectionNotifier =
      SelectionListenerNotifier();
  final ScrollController _pageScrollController = ScrollController();
  String? _lastRenderLogKey;

  String _selectedText = '';
  SelectedContentRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    _selectionNotifier.addListener(_handleSelectionDetails);
  }

  @override
  void dispose() {
    _selectionNotifier.removeListener(_handleSelectionDetails);
    _selectionNotifier.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCoverOnlyChapter = _isCoverOnlyChapter();
    final shouldPromoteTitle = _promoteChapterTitleOnFirstPage &&
        widget.showChapterTitle &&
        !isCoverOnlyChapter &&
        (widget.chapterTitle?.trim().isNotEmpty ?? false);
    final blockMap = <String, Block>{
      for (final b in widget.flowDoc.blocks) b.id: b
    };
    final textColor =
        widget.textColor ?? Theme.of(context).colorScheme.onSurface;
    final baseStyle = widget.style.toTextStyle(color: textColor);
    final renderItems = _buildRenderItems(blockMap);
    final chapterTitleText = widget.chapterTitle?.trim();
    final promotedCandidate = shouldPromoteTitle
        ? (_extractLeadingTitleFromItems(renderItems, widget.chapterTitle!) ??
            _extractLeadingHeadingFromItems(renderItems) ??
            _extractFallbackLeadingTextFromItems(renderItems))
        : null;
    final promotedTitle = shouldPromoteTitle
        ? (promotedCandidate ?? chapterTitleText)?.trim()
        : null;
    final hasImageItem =
        renderItems.any((e) => e.type == _RenderItemType.image);
    if (promotedTitle != null && promotedTitle.isNotEmpty) {
      _removeImmediateDuplicateTitle(renderItems, promotedTitle);
      _removeLeadingHeadingAfterPromotion(renderItems, promotedTitle);
    }
    final hasContent = (promotedTitle != null && promotedTitle.isNotEmpty) ||
        renderItems.any((e) => e.type != _RenderItemType.space);

    return Container(
      color: widget.pageBackgroundColor ??
          Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: widget.pagePadding,
        child: SelectionListener(
          selectionNotifier: _selectionNotifier,
          child: SelectionArea(
            onSelectionChanged: (content) {
              _selectedText = content?.plainText ?? '';
            },
            contextMenuBuilder: (context, selectableRegionState) {
              final buttons = <ContextMenuButtonItem>[
                ...selectableRegionState.contextMenuButtonItems,
                ContextMenuButtonItem(
                  label: 'Highlight',
                  onPressed: () => _emitAction(
                    ReaderSelectionAction.highlight,
                    selectableRegionState,
                  ),
                ),
                ContextMenuButtonItem(
                  label: 'Note',
                  onPressed: () => _emitAction(
                    ReaderSelectionAction.note,
                    selectableRegionState,
                  ),
                ),
                ContextMenuButtonItem(
                  label: 'Ask AI',
                  onPressed: () => _emitAction(
                    ReaderSelectionAction.askAi,
                    selectableRegionState,
                  ),
                ),
              ];

              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: selectableRegionState.contextMenuAnchors,
                buttonItems: buttons,
              );
            },
            child: Align(
              alignment: Alignment.topLeft,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final constraintWidth = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : widget.pageUsableWidth;
                  final constraintHeight = constraints.maxHeight.isFinite
                      ? constraints.maxHeight
                      : widget.pageUsableHeight;
                  final paneWidth = math.max(
                    40.0,
                    math.min(constraintWidth, widget.pageUsableWidth),
                  );
                  final paneHeight = math.max(
                    80.0,
                    math.min(constraintHeight, widget.pageUsableHeight),
                  );
                  final textWidth = math.max(
                    24.0,
                    paneWidth - (_textInkHorizontalGuard * 2),
                  );
                  final children = <Widget>[
                    if (promotedTitle != null && promotedTitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          promotedTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textScaler: TextScaler.noScaling,
                          textHeightBehavior: _textHeightBehavior,
                          style: baseStyle.copyWith(
                            fontSize: (widget.style.fontSize *
                                    (hasImageItem ? 1.12 : 1.18))
                                .clamp(16, 32),
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                  ];

                  for (final item in renderItems) {
                    switch (item.type) {
                      case _RenderItemType.text:
                        final text = item.text;
                        if (text == null || text.isEmpty) {
                          continue;
                        }
                        final blockTextStyle = _resolveTextStyle(
                          baseStyle,
                          item.blockStyle,
                        );
                        final blockTextAlign = item.blockStyle?.textAlign ??
                            widget.style.textAlign;
                        final blockLineHeight = _normalizedLineHeight(
                          item.blockStyle?.lineHeight,
                        );
                        children.add(
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _textInkHorizontalGuard,
                            ),
                            child: _buildNativeTextBlock(
                              text: text,
                              pageStartOffset:
                                  item.globalStart ?? widget.page.startOffset,
                              textStyle: blockTextStyle,
                              textAlign: blockTextAlign,
                              lineHeight: blockLineHeight,
                              maxWidth: textWidth,
                            ),
                          ),
                        );
                        break;
                      case _RenderItemType.image:
                        final imageBlock = item.imageBlock;
                        if (imageBlock == null) {
                          continue;
                        }
                        children.add(
                          _buildImageWidget(
                            imageBlock: imageBlock,
                            maxWidth: paneWidth,
                            textColor: textColor,
                            fixedHeight: item.measuredHeight,
                          ),
                        );
                        break;
                      case _RenderItemType.space:
                        children.add(
                          SizedBox(height: item.spaceHeight ?? 8),
                        );
                        break;
                    }
                  }

                  if (!hasContent) {
                    children.add(
                      Text(
                        '本页暂无可显示内容',
                        textScaler: TextScaler.noScaling,
                        textHeightBehavior: _textHeightBehavior,
                        style: baseStyle,
                      ),
                    );
                  }

                  _scheduleRenderOverflowDebug(paneHeight);
                  return SizedBox(
                    width: paneWidth,
                    height: paneHeight,
                    child: ListView(
                      controller: _pageScrollController,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      clipBehavior: Clip.none,
                      children: children,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _PagePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page.index != widget.page.index ||
        oldWidget.page.startOffset != widget.page.startOffset ||
        oldWidget.page.endOffset != widget.page.endOffset ||
        oldWidget.style.cacheSignature() != widget.style.cacheSignature()) {
      _lastRenderLogKey = null;
    }
    _scheduleRenderOverflowDebug(null);
  }

  void _scheduleRenderOverflowDebug(double? expectedViewportHeight) {
    final key =
        '${widget.page.index}-${widget.page.startOffset}-${widget.page.endOffset}-${widget.style.cacheSignature()}';
    if (_debugRenderLogs && kDebugMode && _lastRenderLogKey == key) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageScrollController.hasClients) {
        return;
      }
      final position = _pageScrollController.position;
      final overflow = position.maxScrollExtent;
      final viewport = position.viewportDimension;
      if (_debugRenderLogs && kDebugMode) {
        _lastRenderLogKey = key;
        final baseLog = '[ReaderRender] page=${widget.page.index} '
            'range=${widget.page.startOffset}-${widget.page.endOffset} '
            'viewportH=${viewport.toStringAsFixed(2)} '
            'expectedH=${(expectedViewportHeight ?? viewport).toStringAsFixed(2)} '
            'overflow=${overflow.toStringAsFixed(2)} '
            'fixedPage=1';
        debugPrint(baseLog);
        if (overflow > _overflowWarnThreshold) {
          debugPrint(
            '[ReaderRender][OVERFLOW] page=${widget.page.index} '
            'range=${widget.page.startOffset}-${widget.page.endOffset} '
            'overflow=${overflow.toStringAsFixed(2)}',
          );
        }
      }
    });
  }

  List<_RenderItem> _buildRenderItems(Map<String, Block> blockMap) {
    final items = <_RenderItem>[];
    for (final fragment in widget.page.fragments) {
      if (fragment is TextFragment) {
        final block = blockMap[fragment.blockId];
        final blockText = switch (block) {
          ParagraphBlock p => p.plainText,
          HeadingBlock h => h.plainText,
          _ => null,
        };
        final blockStyle = switch (block) {
          ParagraphBlock p => p.style,
          HeadingBlock h => h.style,
          _ => null,
        };
        if (blockText == null || blockText.isEmpty) {
          continue;
        }
        final start = fragment.start.clamp(0, blockText.length);
        final end = fragment.end.clamp(start, blockText.length);
        if (end <= start) {
          continue;
        }
        final rawText = blockText.substring(start, end);
        final normalized = _normalizeFragmentTextForPage(rawText);
        if (normalized.isEmpty) {
          // 尾部换行在分段边界不应再额外占据版面高度。
          continue;
        }
        items.add(
          _RenderItem.text(
            text: normalized,
            globalStart: fragment.globalStart,
            isHeading: block is HeadingBlock,
            blockStyle: blockStyle,
            measuredHeight: fragment.measuredHeight,
          ),
        );
        continue;
      }

      if (fragment is ImageFragment) {
        final block = blockMap[fragment.blockId];
        if (block is! ImageBlock) {
          continue;
        }
        items.add(
          _RenderItem.image(
            block,
            measuredHeight: fragment.measuredHeight,
          ),
        );
        continue;
      }

      if (fragment is SpaceFragment) {
        items.add(_RenderItem.space(fragment.height));
      }
    }
    return items;
  }

  String _normalizeFragmentTextForPage(String raw) {
    if (raw.isEmpty) {
      return raw;
    }
    var value = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    int end = value.length;
    while (end > 0) {
      final code = value.codeUnitAt(end - 1);
      if (code == 0x0A) {
        end -= 1;
        continue;
      }
      break;
    }
    if (end <= 0) {
      return '';
    }
    if (end == value.length) {
      return value;
    }
    return value.substring(0, end);
  }

  String? _extractLeadingTitleFromItems(
      List<_RenderItem> items, String chapterTitle) {
    final title = chapterTitle.trim();
    if (title.isEmpty) {
      return null;
    }
    final compactTitle = title.replaceAll(RegExp(r'\s+'), '');
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.type != _RenderItemType.text) {
        continue;
      }
      final raw = item.text ?? '';
      final stripped = raw.trimLeft();
      if (stripped.isEmpty) {
        continue;
      }
      final compactStripped = stripped.replaceAll(RegExp(r'\s+'), '');
      final isLikelyTitle = stripped.startsWith(title) ||
          compactStripped.startsWith(compactTitle);
      if (!isLikelyTitle) {
        return null;
      }

      final leading = raw.length - stripped.length;
      var remove = 0;
      if (stripped.startsWith(title)) {
        remove = leading + title.length;
      } else {
        var titleIndex = 0;
        var sourceIndex = leading;
        while (titleIndex < title.length && sourceIndex < raw.length) {
          final sourceChar = raw[sourceIndex];
          if (RegExp(r'\s').hasMatch(sourceChar)) {
            sourceIndex += 1;
            continue;
          }
          if (sourceChar != title[titleIndex]) {
            break;
          }
          titleIndex += 1;
          sourceIndex += 1;
        }
        if (titleIndex == title.length) {
          remove = sourceIndex;
        }
      }
      if (remove <= 0 || remove > raw.length) {
        return null;
      }
      final promoted = raw.substring(leading, remove).trim();

      var trimmed = raw.substring(remove);
      trimmed = trimmed.replaceFirst(RegExp(r'^[\s:：\-—·•]+'), '');
      if (trimmed.isEmpty) {
        items.removeAt(i);
      } else {
        final shift = raw.length - trimmed.length;
        items[i] = _RenderItem.text(
          text: trimmed,
          globalStart: (item.globalStart ?? widget.page.startOffset) + shift,
          isHeading: item.isHeading ?? false,
          blockStyle: item.blockStyle,
        );
      }
      return promoted.isNotEmpty ? promoted : title;
    }
    return null;
  }

  String? _extractLeadingHeadingFromItems(List<_RenderItem> items) {
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.type == _RenderItemType.space) {
        continue;
      }
      if (item.type != _RenderItemType.text || !(item.isHeading ?? false)) {
        break;
      }
      final raw = item.text ?? '';
      final stripped = raw.trimLeft();
      if (stripped.isEmpty) {
        continue;
      }
      final firstLine = stripped.split('\n').first.trim();
      if (firstLine.isEmpty) {
        continue;
      }

      final leading = raw.length - stripped.length;
      final remove = leading + firstLine.length;
      if (remove <= 0 || remove > raw.length) {
        break;
      }
      var trimmed = raw.substring(remove);
      trimmed = trimmed.replaceFirst(RegExp(r'^[\s:：\-—·•]+'), '');
      if (trimmed.trim().isEmpty) {
        items.removeAt(i);
      } else {
        final shift = raw.length - trimmed.length;
        items[i] = _RenderItem.text(
          text: trimmed,
          globalStart: (item.globalStart ?? widget.page.startOffset) + shift,
          isHeading: item.isHeading ?? false,
          blockStyle: item.blockStyle,
        );
      }
      return firstLine;
    }
    return null;
  }

  String? _extractFallbackLeadingTextFromItems(List<_RenderItem> items) {
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.type == _RenderItemType.space) {
        continue;
      }
      if (item.type != _RenderItemType.text) {
        break;
      }
      final raw = item.text ?? '';
      final stripped = raw.trimLeft();
      if (stripped.isEmpty) {
        continue;
      }
      final firstLine = stripped.split('\n').first.trim();
      if (firstLine.isEmpty) {
        continue;
      }
      final isLikelyTitle =
          firstLine.length <= 34 && !RegExp(r'[。！？!?；;，,]').hasMatch(firstLine);
      if (!isLikelyTitle) {
        return null;
      }

      final leading = raw.length - stripped.length;
      final remove = leading + firstLine.length;
      if (remove <= 0 || remove > raw.length) {
        return null;
      }
      var trimmed = raw.substring(remove);
      trimmed = trimmed.replaceFirst(RegExp(r'^[\s:：\-—·•]+'), '');
      if (trimmed.trim().isEmpty) {
        items.removeAt(i);
      } else {
        final shift = raw.length - trimmed.length;
        items[i] = _RenderItem.text(
          text: trimmed,
          globalStart: (item.globalStart ?? widget.page.startOffset) + shift,
          isHeading: item.isHeading ?? false,
          blockStyle: item.blockStyle,
        );
      }
      return firstLine;
    }
    return null;
  }

  void _removeImmediateDuplicateTitle(
      List<_RenderItem> items, String promotedTitle) {
    final target = _normalizeTitleToken(promotedTitle);
    if (target.isEmpty) {
      return;
    }

    var textChecks = 0;
    for (var i = 0; i < items.length && textChecks < 4; i++) {
      final item = items[i];
      if (item.type == _RenderItemType.space) {
        continue;
      }
      if (item.type != _RenderItemType.text) {
        break;
      }
      textChecks += 1;

      final raw = item.text ?? '';
      final stripped = raw.trimLeft();
      if (stripped.isEmpty) {
        continue;
      }

      final normalized = _normalizeTitleToken(stripped);
      if (normalized.isEmpty) {
        continue;
      }
      final diff = (normalized.length - target.length).abs();
      final duplicate = normalized == target ||
          (normalized.startsWith(target) && diff <= 12) ||
          (target.startsWith(normalized) && diff <= 12) ||
          (normalized.contains(target) && diff <= 12) ||
          (target.contains(normalized) && diff <= 12);
      if (!duplicate) {
        break;
      }

      if (normalized == target) {
        items.removeAt(i);
        return;
      }

      final prefixPattern = RegExp(
        '^\\s*${RegExp.escape(promotedTitle)}[\\s:：\\-—·•]*',
      );
      final trimmed = raw.replaceFirst(prefixPattern, '');
      if (trimmed.trim().isEmpty) {
        items.removeAt(i);
      } else {
        final shift = raw.length - trimmed.length;
        items[i] = _RenderItem.text(
          text: trimmed,
          globalStart: (item.globalStart ?? widget.page.startOffset) + shift,
          isHeading: item.isHeading ?? false,
          blockStyle: item.blockStyle,
        );
      }
      return;
    }
  }

  void _removeLeadingHeadingAfterPromotion(
    List<_RenderItem> items,
    String promotedTitle,
  ) {
    final normalizedTarget = _normalizeTitleToken(promotedTitle);
    if (normalizedTarget.isEmpty) {
      return;
    }
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.type == _RenderItemType.space) {
        continue;
      }
      if (item.type != _RenderItemType.text) {
        return;
      }
      final raw = item.text ?? '';
      final stripped = raw.trimLeft();
      if (stripped.isEmpty) {
        continue;
      }
      final firstLine = stripped.split('\n').first.trim();
      if (firstLine.isEmpty) {
        return;
      }
      final normalizedFirst = _normalizeTitleToken(firstLine);
      final looksHeading = (item.isHeading ?? false) ||
          (firstLine.length <= 34 &&
              !RegExp(r'[。！？!?；;，,]').hasMatch(firstLine));
      final maybeDuplicate = normalizedFirst.isNotEmpty &&
          (normalizedFirst == normalizedTarget ||
              normalizedFirst.startsWith(normalizedTarget) ||
              normalizedTarget.startsWith(normalizedFirst));
      if (!looksHeading || !maybeDuplicate) {
        return;
      }

      final leading = raw.length - stripped.length;
      final remove = leading + firstLine.length;
      if (remove <= 0 || remove > raw.length) {
        return;
      }
      var trimmed = raw.substring(remove);
      trimmed = trimmed.replaceFirst(RegExp(r'^[\s:：\-—·•]+'), '');
      if (trimmed.trim().isEmpty) {
        items.removeAt(i);
      } else {
        final shift = raw.length - trimmed.length;
        items[i] = _RenderItem.text(
          text: trimmed,
          globalStart: (item.globalStart ?? widget.page.startOffset) + shift,
          isHeading: item.isHeading ?? false,
          blockStyle: item.blockStyle,
        );
      }
      return;
    }
  }

  String _normalizeTitleToken(String value) {
    return value.trim().replaceAll(RegExp(r'[\s:：\-—·•]+'), '').toLowerCase();
  }

  Widget _buildNativeTextBlock({
    required String text,
    required int pageStartOffset,
    required TextStyle textStyle,
    required TextAlign textAlign,
    required double lineHeight,
    required double maxWidth,
    double? fixedHeight,
  }) {
    final spans = _buildHighlightedSpans(
      text: text,
      pageStartOffset: pageStartOffset,
      annotations: widget.annotations,
      baseStyle: textStyle,
    );
    final resolvedLocale = textStyle.locale ??
        widget.style.locale ??
        Localizations.maybeLocaleOf(context);
    final strut = StrutStyle(
      fontFamily: textStyle.fontFamily,
      fontSize: textStyle.fontSize ?? widget.style.fontSize,
      fontWeight: textStyle.fontWeight,
      fontStyle: textStyle.fontStyle,
      height: lineHeight,
      leading: 0,
      forceStrutHeight: true,
    );

    return SizedBox(
      width: maxWidth,
      height: fixedHeight,
      child: Align(
        alignment: Alignment.topLeft,
        child: Text.rich(
          TextSpan(children: spans),
          softWrap: true,
          textAlign: textAlign,
          locale: resolvedLocale,
          textScaler: TextScaler.noScaling,
          textWidthBasis: TextWidthBasis.parent,
          strutStyle: strut,
          textHeightBehavior: _textHeightBehavior,
        ),
      ),
    );
  }

  Widget _buildImageWidget({
    required ImageBlock imageBlock,
    required double maxWidth,
    required Color textColor,
    double? fixedHeight,
  }) {
    final src = imageBlock.src.trim();
    final imageBytes = _resolveImageBytes(src);
    final uri = Uri.tryParse(src);
    final isRemote = uri != null &&
        (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https');
    final effectivePageHeight = _effectivePageHeight();
    final isCoverImage = _isCoverImageBlock(imageBlock);
    final maxImageHeight = isCoverImage
        ? math.max(180.0, effectivePageHeight * 0.90)
        : math.max(84.0, effectivePageHeight * 0.44);

    var targetWidth = maxWidth;
    var targetHeight = imageBlock.height;

    if (imageBlock.width != null && imageBlock.width! > 0) {
      targetWidth = math.min(maxWidth, imageBlock.width!);
    }
    if (imageBlock.width != null &&
        imageBlock.height != null &&
        imageBlock.width! > 0 &&
        imageBlock.height! > 0) {
      targetHeight = targetWidth * (imageBlock.height! / imageBlock.width!);
    }
    if (targetHeight != null) {
      final minHeight = isCoverImage ? 120.0 : 38.0;
      targetHeight = targetHeight.clamp(minHeight, maxImageHeight).toDouble();
    } else {
      final fallbackHeight = isCoverImage
          ? effectivePageHeight * 0.78
          : effectivePageHeight * 0.24;
      final minHeight = isCoverImage ? 120.0 : 38.0;
      targetHeight = fallbackHeight.clamp(minHeight, maxImageHeight).toDouble();
    }

    Widget imageChild;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      imageChild = Image.memory(
        imageBytes,
        width: targetWidth,
        height: targetHeight,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, _, __) => _buildImagePlaceholder(
          text: imageBlock.alt?.trim().isNotEmpty == true
              ? imageBlock.alt!.trim()
              : '图片加载失败',
          textColor: textColor,
          maxWidth: maxWidth,
          maxHeight: maxImageHeight,
          targetHeight: targetHeight,
        ),
      );
    } else if (isRemote) {
      imageChild = Image.network(
        src,
        width: targetWidth,
        height: targetHeight,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, _, __) => _buildImagePlaceholder(
          text: imageBlock.alt?.trim().isNotEmpty == true
              ? imageBlock.alt!.trim()
              : '图片未找到',
          textColor: textColor,
          maxWidth: maxWidth,
          maxHeight: maxImageHeight,
          targetHeight: targetHeight,
        ),
      );
    } else {
      imageChild = _buildImagePlaceholder(
        text: imageBlock.alt?.trim().isNotEmpty == true
            ? imageBlock.alt!.trim()
            : (src.isNotEmpty ? '图片资源缺失: $src' : '图片资源缺失'),
        textColor: textColor,
        maxWidth: maxWidth,
        maxHeight: maxImageHeight,
        targetHeight: targetHeight,
      );
    }

    final resolvedHeight = fixedHeight == null
        ? targetHeight.clamp(38.0, maxImageHeight).toDouble()
        : fixedHeight.clamp(38.0, maxImageHeight).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: SizedBox(
        width: maxWidth,
        height: resolvedHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Center(
            child: imageChild,
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder({
    required String text,
    required Color textColor,
    required double maxWidth,
    required double maxHeight,
    required double? targetHeight,
  }) {
    return Container(
      width: maxWidth,
      height: targetHeight,
      constraints: BoxConstraints(
        minHeight: targetHeight ?? 38,
        maxHeight: targetHeight ?? maxHeight,
      ),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.image_not_supported_outlined,
              size: 18, color: textColor.withValues(alpha: 0.75)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textScaler: TextScaler.noScaling,
              textHeightBehavior: _textHeightBehavior,
              style: widget.style.toTextStyle(
                color: textColor.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Uint8List? _resolveImageBytes(String src) {
    if (src.isEmpty) {
      return null;
    }
    final dataUriBytes = _decodeDataUri(src);
    if (dataUriBytes != null) {
      return dataUriBytes;
    }

    final resources = widget.chapterResources;
    if (resources.isEmpty) {
      return null;
    }
    if (resources.containsKey(src)) {
      return resources[src];
    }

    final normalized = _normalizeResourcePath(src);
    if (normalized.isNotEmpty && resources.containsKey(normalized)) {
      return resources[normalized];
    }

    final decodedPath = _safeUriDecodeFull(normalized);
    if (decodedPath.isNotEmpty && resources.containsKey(decodedPath)) {
      return resources[decodedPath];
    }

    final baseName = normalized.split('/').last;
    if (baseName.isNotEmpty && resources.containsKey(baseName)) {
      return resources[baseName];
    }

    final normalizedLower = normalized.toLowerCase();
    if (normalizedLower.isEmpty) {
      return null;
    }
    for (final entry in resources.entries) {
      final key = _normalizeResourcePath(entry.key);
      final keyLower = key.toLowerCase();
      if (keyLower == normalizedLower ||
          keyLower.endsWith('/$normalizedLower') ||
          normalizedLower.endsWith('/$keyLower')) {
        return entry.value;
      }
    }

    if (baseName.isNotEmpty) {
      final baseNameLower = baseName.toLowerCase();
      for (final entry in resources.entries) {
        final key = _normalizeResourcePath(entry.key);
        if (key.split('/').last.toLowerCase() == baseNameLower) {
          return entry.value;
        }
      }
    }

    return null;
  }

  Uint8List? _decodeDataUri(String raw) {
    final src = raw.trim();
    if (!src.startsWith('data:')) {
      return null;
    }
    final comma = src.indexOf(',');
    if (comma <= 0 || comma >= src.length - 1) {
      return null;
    }
    final header = src.substring(5, comma).toLowerCase();
    final payload = src.substring(comma + 1);
    try {
      if (header.contains(';base64')) {
        return Uint8List.fromList(base64Decode(payload));
      }
      return Uint8List.fromList(Uri.decodeComponent(payload).codeUnits);
    } catch (_) {
      return null;
    }
  }

  String _normalizeResourcePath(String raw) {
    var value = raw.trim();
    final hashIndex = value.indexOf('#');
    if (hashIndex >= 0) {
      value = value.substring(0, hashIndex);
    }
    final queryIndex = value.indexOf('?');
    if (queryIndex >= 0) {
      value = value.substring(0, queryIndex);
    }
    value = value.replaceAll('\\', '/');
    if (value.startsWith('file://')) {
      value = value.substring(7);
    }

    final uri = Uri.tryParse(value);
    if (uri != null && uri.scheme.isNotEmpty) {
      final scheme = uri.scheme.toLowerCase();
      if (scheme == 'http' || scheme == 'https') {
        value = uri.path;
      }
    }

    while (value.startsWith('./')) {
      value = value.substring(2);
    }
    while (value.startsWith('/')) {
      value = value.substring(1);
    }

    final parts = <String>[];
    for (final part in value.split('/')) {
      if (part.isEmpty || part == '.') {
        continue;
      }
      if (part == '..') {
        if (parts.isNotEmpty) {
          parts.removeLast();
        }
        continue;
      }
      parts.add(part);
    }
    return parts.join('/');
  }

  String _safeUriDecodeFull(String value) {
    try {
      return Uri.decodeFull(value);
    } catch (_) {
      return value;
    }
  }

  TextStyle _resolveTextStyle(TextStyle baseStyle, BlockStyle? blockStyle) {
    final lineHeight = _normalizedLineHeight(blockStyle?.lineHeight);
    final baseFontSize = baseStyle.fontSize ?? widget.style.fontSize;
    final resolvedFontSizeScale =
        (blockStyle?.fontSizeScale ?? 1.0).clamp(0.72, 2.4).toDouble();
    final resolvedLetterSpacing =
        (blockStyle?.letterSpacing ?? baseStyle.letterSpacing);
    final baseColor =
        baseStyle.color ?? Theme.of(context).colorScheme.onSurface;
    final backgroundColor =
        widget.pageBackgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
    final resolvedColor = _resolveThemeAwareTextColor(
      baseColor: baseColor,
      backgroundColor: backgroundColor,
      blockColor: blockStyle?.textColor,
    );
    return baseStyle.copyWith(
      fontWeight: blockStyle?.fontWeight ?? baseStyle.fontWeight,
      fontStyle: blockStyle?.fontStyle ?? baseStyle.fontStyle,
      color: resolvedColor,
      fontSize: baseFontSize * resolvedFontSizeScale,
      letterSpacing: resolvedLetterSpacing,
      height: lineHeight,
    );
  }

  Color _resolveThemeAwareTextColor({
    required Color baseColor,
    required Color backgroundColor,
    required Color? blockColor,
  }) {
    final raw = blockColor;
    if (raw == null) {
      return baseColor;
    }

    final base = baseColor.withAlpha(0xFF);
    final bg = backgroundColor.withAlpha(0xFF);
    final source = raw.withAlpha(0xFF);
    final sourceHsl = HSLColor.fromColor(source);
    final baseHsl = HSLColor.fromColor(base);
    final isDarkBg =
        ThemeData.estimateBrightnessForColor(bg) == Brightness.dark;

    final targetLightness = isDarkBg
        ? sourceHsl.lightness.clamp(0.62, 0.90).toDouble()
        : sourceHsl.lightness.clamp(0.16, 0.46).toDouble();
    final targetSaturation =
        (sourceHsl.saturation * 0.78 + baseHsl.saturation * 0.22)
            .clamp(0.18, 0.82)
            .toDouble();

    var harmonized = sourceHsl
        .withLightness(targetLightness)
        .withSaturation(targetSaturation)
        .toColor();
    harmonized = Color.lerp(base, harmonized, 0.78) ?? harmonized;

    var contrast = _contrastRatio(harmonized, bg);
    if (contrast < 3.2) {
      final fallback = isDarkBg ? Colors.white : Colors.black;
      final t = ((3.2 - contrast) / 3.2).clamp(0.0, 0.7).toDouble();
      harmonized = Color.lerp(harmonized, fallback, t) ?? harmonized;
      contrast = _contrastRatio(harmonized, bg);
      if (contrast < 2.8) {
        return base;
      }
    }
    return harmonized;
  }

  double _contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final l1 = math.max(la, lb);
    final l2 = math.min(la, lb);
    return (l1 + 0.05) / (l2 + 0.05);
  }

  double _effectivePageHeight() {
    return math.max(80.0, widget.pageUsableHeight - 2.0);
  }

  double _normalizedLineHeight(double? rawLineHeight) {
    final fallback = widget.style.lineHeight.clamp(1.0, 3.2).toDouble();
    final raw = rawLineHeight;
    if (raw == null || !raw.isFinite || raw <= 0) {
      return fallback;
    }
    if (raw < 0.7 || raw > 4.0) {
      return fallback;
    }
    final minPreferred = (fallback - 0.22).clamp(1.0, 2.4).toDouble();
    final maxPreferred = (fallback + 0.32).clamp(1.2, 2.6).toDouble();
    return raw.clamp(minPreferred, maxPreferred).toDouble();
  }

  bool _isCoverOnlyChapter() {
    var textBlocks = 0;
    ImageBlock? imageBlock;
    for (final block in widget.flowDoc.blocks) {
      if (block is ParagraphBlock || block is HeadingBlock) {
        final text = block is ParagraphBlock
            ? block.plainText
            : (block as HeadingBlock).plainText;
        if (text.trim().isNotEmpty) {
          textBlocks += 1;
        }
      } else if (block is ImageBlock) {
        imageBlock ??= block;
      }
    }
    return textBlocks == 0 &&
        imageBlock != null &&
        _isCoverImageBlock(imageBlock);
  }

  bool _isCoverImageBlock(ImageBlock block) {
    final id = block.id.toLowerCase();
    final alt = (block.alt ?? '').toLowerCase();
    final src = block.src.toLowerCase();
    return id.startsWith('cover-') ||
        alt.contains('封面') ||
        alt.contains('cover') ||
        src.contains('/cover') ||
        src.contains('cover.');
  }

  void _handleSelectionDetails() {
    if (!_selectionNotifier.registered) {
      return;
    }
    _selectedRange = _selectionNotifier.selection.range;
  }

  void _emitAction(
    ReaderSelectionAction action,
    SelectableRegionState regionState,
  ) {
    final pageText =
        _pageText(widget.page, widget.flowDoc, widget.chapterPlainText);
    final range = _selectedRange;
    final text = _selectedText.trim();
    if (range == null || text.isEmpty) {
      regionState.hideToolbar();
      return;
    }

    final localStart =
        math.min(range.startOffset, range.endOffset).clamp(0, pageText.length);
    final localEnd =
        math.max(range.startOffset, range.endOffset).clamp(0, pageText.length);

    final payload = ReaderSelectionPayload(
      action: action,
      text: text,
      localStart: localStart,
      localEnd: localEnd,
      globalStart: widget.page.startOffset + localStart,
      globalEnd: widget.page.startOffset + localEnd,
    );

    widget.onSelectionAction?.call(payload);
    regionState.hideToolbar();
  }

  String _pageText(Page page, FlowDoc flowDoc, String? chapterPlainText) {
    final blockMap = <String, Block>{for (final b in flowDoc.blocks) b.id: b};
    final buffer = StringBuffer();

    for (final fragment in page.fragments) {
      if (fragment is TextFragment) {
        final block = blockMap[fragment.blockId];
        if (block is ParagraphBlock) {
          final text = block.plainText;
          if (fragment.start >= 0 &&
              fragment.end <= text.length &&
              fragment.start < fragment.end) {
            buffer.write(text.substring(fragment.start, fragment.end));
          }
        } else if (block is HeadingBlock) {
          final text = block.plainText;
          if (fragment.start >= 0 &&
              fragment.end <= text.length &&
              fragment.start < fragment.end) {
            buffer.write(text.substring(fragment.start, fragment.end));
          }
        }
      }
      if (fragment is SpaceFragment) {
        buffer.write('\n');
      }
    }

    final text = buffer.toString();
    if (text.trim().isNotEmpty) {
      return text;
    }

    if (chapterPlainText != null && chapterPlainText.isNotEmpty) {
      int start = page.startOffset.clamp(0, chapterPlainText.length).toInt();
      int end = page.endOffset.clamp(start, chapterPlainText.length).toInt();

      if (end > start) {
        return chapterPlainText.substring(start, end);
      }
    }

    return text;
  }

  List<InlineSpan> _buildHighlightedSpans({
    required String text,
    required int pageStartOffset,
    required List<Annotation> annotations,
    required TextStyle baseStyle,
  }) {
    if (text.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final ranges = <({int start, int end, Color color})>[];
    for (final ann in annotations) {
      final localStart = ann.startOffset - pageStartOffset;
      final localEnd = ann.endOffset - pageStartOffset;
      final start = localStart.clamp(0, text.length);
      final end = localEnd.clamp(0, text.length);
      if (end > start) {
        ranges.add((start: start, end: end, color: ann.color));
      }
    }

    if (ranges.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    ranges.sort((a, b) => a.start.compareTo(b.start));

    final spans = <InlineSpan>[];
    int cursor = 0;

    for (final r in ranges) {
      if (r.start > cursor) {
        spans.add(
            TextSpan(text: text.substring(cursor, r.start), style: baseStyle));
      }

      final start = math.max(cursor, r.start);
      final end = math.max(start, r.end);
      if (end > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, end),
            style: baseStyle.copyWith(
              backgroundColor: r.color.withValues(alpha: 0.35),
            ),
          ),
        );
        cursor = end;
      }
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }

    return spans;
  }
}

enum _RenderItemType { text, image, space }

class _RenderItem {
  final _RenderItemType type;
  final String? text;
  final int? globalStart;
  final bool? isHeading;
  final BlockStyle? blockStyle;
  final ImageBlock? imageBlock;
  final double? spaceHeight;
  final double? measuredHeight;

  const _RenderItem._({
    required this.type,
    this.text,
    this.globalStart,
    this.isHeading,
    this.blockStyle,
    this.imageBlock,
    this.spaceHeight,
    this.measuredHeight,
  });

  factory _RenderItem.text({
    required String text,
    required int globalStart,
    bool isHeading = false,
    BlockStyle? blockStyle,
    double? measuredHeight,
  }) {
    return _RenderItem._(
      type: _RenderItemType.text,
      text: text,
      globalStart: globalStart,
      isHeading: isHeading,
      blockStyle: blockStyle,
      measuredHeight: measuredHeight,
    );
  }

  factory _RenderItem.image(ImageBlock block, {double? measuredHeight}) {
    return _RenderItem._(
      type: _RenderItemType.image,
      imageBlock: block,
      measuredHeight: measuredHeight,
    );
  }

  factory _RenderItem.space(double height) {
    return _RenderItem._(
      type: _RenderItemType.space,
      spaceHeight: height,
    );
  }
}
