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
    final chapterChanged = oldWidget.pagePlan.chapterId != widget.pagePlan.chapterId ||
        oldWidget.pagePlan.cacheKey != widget.pagePlan.cacheKey;

    if (columnsChanged) {
      _singleController?.dispose();
      _spreadController?.dispose();
      _singleController = null;
      _spreadController = null;
      if (widget.layout.columns <= 1) {
        _singleController =
            PageController(initialPage: _clampPageIndex(widget.initialPageIndex));
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
    if (pages.isEmpty) {
      return const Center(child: Text('No pages'));
    }

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

    if (widget.layout.columns <= 1) {
      _singleController ??=
          PageController(initialPage: _clampPageIndex(widget.initialPageIndex));
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) =>
            _handleBoundaryOverscroll(notification, widget.onReachChapterBoundary),
        child: PageView.builder(
          controller: _singleController,
          itemCount: pages.length,
          onPageChanged: (index) {
            widget.onPageChanged?.call(index);
          },
          itemBuilder: (context, index) {
            final page = pages[index];
            return _PagePane(
              key: ValueKey('page-${page.index}'),
              page: page,
              style: widget.style,
              flowDoc: widget.flowDoc,
              chapterPlainText: widget.chapterPlainText,
              chapterResources: widget.chapterResources,
              chapterTitle: widget.currentChapterTitle,
              showChapterTitle: page.index == 0,
              pagePadding: pagePadding,
              maxVisibleLines: maxVisibleLines,
              pageUsableHeight: widget.layout.usableHeight,
              pageBackgroundColor: widget.pageBackgroundColor,
              textColor: widget.textColor,
              annotations: widget.annotations,
              onSelectionAction: widget.onSelectionAction,
            );
          },
        ),
      );
    }

    final spreadCount = (pages.length / 2).ceil();
    _spreadController ??= PageController(
      initialPage: _clampSpreadIndexFromPage(widget.initialPageIndex),
    );

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) =>
          _handleBoundaryOverscroll(notification, widget.onReachChapterBoundary),
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
                  child: _PagePane(
                    key: ValueKey('page-${left.index}'),
                    page: left,
                    style: widget.style,
                    flowDoc: widget.flowDoc,
                    chapterPlainText: widget.chapterPlainText,
                    chapterResources: widget.chapterResources,
                    chapterTitle: widget.currentChapterTitle,
                    showChapterTitle: left.index == 0,
                    pagePadding: pagePadding,
                    maxVisibleLines: maxVisibleLines,
                    pageUsableHeight: widget.layout.usableHeight,
                    pageBackgroundColor: widget.pageBackgroundColor,
                    textColor: widget.textColor,
                    annotations: widget.annotations,
                    onSelectionAction: widget.onSelectionAction,
                  ),
                ),
                SizedBox(width: widget.layout.gutter),
                Expanded(
                  child: right == null
                      ? const SizedBox.shrink()
                      : _PagePane(
                          key: ValueKey('page-${right.index}'),
                          page: right,
                          style: widget.style,
                          flowDoc: widget.flowDoc,
                          chapterPlainText: widget.chapterPlainText,
                          chapterResources: widget.chapterResources,
                          chapterTitle: widget.currentChapterTitle,
                          showChapterTitle: right.index == 0,
                          pagePadding: pagePadding,
                          maxVisibleLines: maxVisibleLines,
                          pageUsableHeight: widget.layout.usableHeight,
                          pageBackgroundColor: widget.pageBackgroundColor,
                          textColor: widget.textColor,
                          annotations: widget.annotations,
                          onSelectionAction: widget.onSelectionAction,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _handleBoundaryOverscroll(
    ScrollNotification notification,
    ChapterBoundaryCallback? callback,
  ) {
    if (callback == null || notification is! OverscrollNotification) {
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
  static const TextHeightBehavior _textHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
  );
  static const bool _debugRenderLogs = true;
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
    final shouldPromoteTitle = widget.showChapterTitle &&
        (widget.chapterTitle?.trim().isNotEmpty ?? false);
    final blockMap = <String, Block>{for (final b in widget.flowDoc.blocks) b.id: b};
    final textColor = widget.textColor ?? Theme.of(context).colorScheme.onSurface;
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
    final hasImageItem = renderItems.any((e) => e.type == _RenderItemType.image);
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
        child: ClipRect(
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
                    final maxWidth =
                        constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
                    final children = <Widget>[
                      if (promotedTitle != null && promotedTitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            promotedTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textScaler: TextScaler.noScaling,
                            textHeightBehavior: _textHeightBehavior,
                            style: baseStyle.copyWith(
                              fontSize: (widget.style.fontSize *
                                      (hasImageItem ? 1.24 : 1.34))
                                  .clamp(18, 40),
                              fontWeight: FontWeight.w700,
                              height: 1.25,
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
                          final blockTextAlign =
                              item.blockStyle?.textAlign ?? widget.style.textAlign;
                          final blockLineHeight = _normalizedLineHeight(
                            item.blockStyle?.lineHeight,
                          );
                          final spans = _buildHighlightedSpans(
                            text: text,
                            pageStartOffset: item.globalStart ?? widget.page.startOffset,
                            annotations: widget.annotations,
                            baseStyle: blockTextStyle,
                          );
                          children.add(
                            Text.rich(
                              TextSpan(children: spans),
                              textAlign: blockTextAlign,
                              textScaler: TextScaler.noScaling,
                              strutStyle: StrutStyle(
                                fontFamily: blockTextStyle.fontFamily,
                                fontSize:
                                    blockTextStyle.fontSize ?? widget.style.fontSize,
                                fontWeight: blockTextStyle.fontWeight,
                                fontStyle: blockTextStyle.fontStyle,
                                height: blockLineHeight,
                                leading: 0,
                                forceStrutHeight: true,
                              ),
                              textHeightBehavior: _textHeightBehavior,
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
                              maxWidth: maxWidth,
                              textColor: textColor,
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

                    _scheduleRenderOverflowDebug(constraints.maxHeight);
                    return SizedBox(
                      height: constraints.maxHeight,
                      child: ListView(
                        controller: _pageScrollController,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        children: children,
                      ),
                    );
                  },
                ),
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
    if (!_debugRenderLogs || !kDebugMode) {
      return;
    }
    final key =
        '${widget.page.index}-${widget.page.startOffset}-${widget.page.endOffset}-${widget.style.cacheSignature()}';
    if (_lastRenderLogKey == key) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageScrollController.hasClients) {
        return;
      }
      final position = _pageScrollController.position;
      final overflow = position.maxScrollExtent;
      final viewport = position.viewportDimension;
      _lastRenderLogKey = key;
      debugPrint(
        '[ReaderRender] page=${widget.page.index} '
        'range=${widget.page.startOffset}-${widget.page.endOffset} '
        'viewportH=${viewport.toStringAsFixed(2)} '
        'expectedH=${(expectedViewportHeight ?? viewport).toStringAsFixed(2)} '
        'overflow=${overflow.toStringAsFixed(2)}',
      );
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
        items.add(
          _RenderItem.text(
            text: blockText.substring(start, end),
            globalStart: fragment.globalStart,
            isHeading: block is HeadingBlock,
            blockStyle: blockStyle,
          ),
        );
        continue;
      }

      if (fragment is ImageFragment) {
        final block = blockMap[fragment.blockId];
        if (block is! ImageBlock) {
          continue;
        }
        items.add(_RenderItem.image(block));
        continue;
      }

      if (fragment is SpaceFragment) {
        items.add(_RenderItem.space(fragment.height));
      }
    }
    return items;
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
      final isLikelyTitle = firstLine.length <= 34 &&
          !RegExp(r'[。！？!?；;，,]').hasMatch(firstLine);
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
    return value
        .trim()
        .replaceAll(RegExp(r'[\s:：\-—·•]+'), '')
        .toLowerCase();
  }

  Widget _buildImageWidget({
    required ImageBlock imageBlock,
    required double maxWidth,
    required Color textColor,
  }) {
    final src = imageBlock.src.trim();
    final imageBytes = _resolveImageBytes(src);
    final uri = Uri.tryParse(src);
    final isRemote = uri != null &&
        (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https');
    final effectivePageHeight = _effectivePageHeight();
    final maxImageHeight = math.max(84.0, effectivePageHeight * 0.36);

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
      targetHeight = targetHeight.clamp(38.0, maxImageHeight).toDouble();
    } else {
      targetHeight =
          (effectivePageHeight * 0.22).clamp(38.0, maxImageHeight).toDouble();
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

    final resolvedHeight = targetHeight.clamp(38.0, maxImageHeight).toDouble();
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

    final decodedPath = Uri.decodeFull(normalized);
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

  TextStyle _resolveTextStyle(TextStyle baseStyle, BlockStyle? blockStyle) {
    final lineHeight = _normalizedLineHeight(blockStyle?.lineHeight);
    return baseStyle.copyWith(
      fontWeight: blockStyle?.fontWeight ?? baseStyle.fontWeight,
      fontStyle: blockStyle?.fontStyle ?? baseStyle.fontStyle,
      height: lineHeight,
    );
  }

  double _effectivePageHeight() {
    final lineGuard =
        math.max(2.0, widget.style.fontSize * widget.style.lineHeight * 0.10);
    return math.max(80.0, widget.pageUsableHeight - 8.0 - lineGuard);
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
    return raw.clamp(1.0, 3.2).toDouble();
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

  const _RenderItem._({
    required this.type,
    this.text,
    this.globalStart,
    this.isHeading,
    this.blockStyle,
    this.imageBlock,
    this.spaceHeight,
  });

  factory _RenderItem.text({
    required String text,
    required int globalStart,
    bool isHeading = false,
    BlockStyle? blockStyle,
  }) {
    return _RenderItem._(
      type: _RenderItemType.text,
      text: text,
      globalStart: globalStart,
      isHeading: isHeading,
      blockStyle: blockStyle,
    );
  }

  factory _RenderItem.image(ImageBlock block) {
    return _RenderItem._(
      type: _RenderItemType.image,
      imageBlock: block,
    );
  }

  factory _RenderItem.space(double height) {
    return _RenderItem._(
      type: _RenderItemType.space,
      spaceHeight: height,
    );
  }
}
