import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

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

class ReaderView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final pages = pagePlan.pages;
    if (pages.isEmpty) {
      return const Center(child: Text('No pages'));
    }

    final pagePadding = EdgeInsets.fromLTRB(
      layout.padding.left,
      layout.padding.top,
      layout.padding.right,
      layout.padding.bottom,
    );
    final maxVisibleLines = math.max(
        1, (layout.usableHeight / (style.fontSize * style.lineHeight)).floor());

    if (layout.columns <= 1) {
      final initial =
          initialPageIndex.clamp(0, math.max(0, pages.length - 1)).toInt();
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) =>
            _handleBoundaryOverscroll(notification, onReachChapterBoundary),
        child: PageView.builder(
          controller: PageController(initialPage: initial),
          itemCount: pages.length,
          onPageChanged: (index) => onPageChanged?.call(index),
          itemBuilder: (context, index) {
            final page = pages[index];
            return _PagePane(
              key: ValueKey('page-${page.index}'),
              page: page,
              style: style,
              flowDoc: flowDoc,
              chapterPlainText: chapterPlainText,
              chapterResources: chapterResources,
              chapterTitle: currentChapterTitle,
              showChapterTitle: page.index == 0,
              pagePadding: pagePadding,
              maxVisibleLines: maxVisibleLines,
              pageUsableHeight: layout.usableHeight,
              pageBackgroundColor: pageBackgroundColor,
              textColor: textColor,
              annotations: annotations,
              onSelectionAction: onSelectionAction,
            );
          },
        ),
      );
    }

    final spreadCount = (pages.length / 2).ceil();
    final initialSpread =
        (initialPageIndex ~/ 2).clamp(0, math.max(0, spreadCount - 1)).toInt();

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) =>
          _handleBoundaryOverscroll(notification, onReachChapterBoundary),
      child: PageView.builder(
        controller: PageController(initialPage: initialSpread),
        itemCount: spreadCount,
        onPageChanged: (spread) => onPageChanged
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
                    style: style,
                    flowDoc: flowDoc,
                    chapterPlainText: chapterPlainText,
                    chapterResources: chapterResources,
                    chapterTitle: currentChapterTitle,
                    showChapterTitle: left.index == 0,
                    pagePadding: pagePadding,
                    maxVisibleLines: maxVisibleLines,
                    pageUsableHeight: layout.usableHeight,
                    pageBackgroundColor: pageBackgroundColor,
                    textColor: textColor,
                    annotations: annotations,
                    onSelectionAction: onSelectionAction,
                  ),
                ),
                SizedBox(width: layout.gutter),
                Expanded(
                  child: right == null
                      ? const SizedBox.shrink()
                      : _PagePane(
                          key: ValueKey('page-${right.index}'),
                          page: right,
                          style: style,
                          flowDoc: flowDoc,
                          chapterPlainText: chapterPlainText,
                          chapterResources: chapterResources,
                          chapterTitle: currentChapterTitle,
                          showChapterTitle: right.index == 0,
                          pagePadding: pagePadding,
                          maxVisibleLines: maxVisibleLines,
                          pageUsableHeight: layout.usableHeight,
                          pageBackgroundColor: pageBackgroundColor,
                          textColor: textColor,
                          annotations: annotations,
                          onSelectionAction: onSelectionAction,
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
  final SelectionListenerNotifier _selectionNotifier =
      SelectionListenerNotifier();

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasTitle = widget.showChapterTitle &&
        (widget.chapterTitle?.trim().isNotEmpty ?? false);
    final blockMap = <String, Block>{for (final b in widget.flowDoc.blocks) b.id: b};
    final textColor = widget.textColor ?? Theme.of(context).colorScheme.onSurface;
    final baseStyle = widget.style.toTextStyle(color: textColor);
    final renderItems = _buildRenderItems(blockMap);
    if (hasTitle) {
      _trimLeadingTitleFromItems(renderItems, widget.chapterTitle!);
    }
    final hasContent = renderItems.any((e) => e.type != _RenderItemType.space);

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
                      if (hasTitle)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            widget.chapterTitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: baseStyle.copyWith(
                              fontSize: (widget.style.fontSize * 1.38).clamp(20, 42),
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
                          final spans = _buildHighlightedSpans(
                            text: text,
                            pageStartOffset: item.globalStart ?? widget.page.startOffset,
                            annotations: widget.annotations,
                            baseStyle: baseStyle,
                          );
                          children.add(
                            Text.rich(
                              TextSpan(children: spans),
                              textAlign: widget.style.textAlign,
                              strutStyle: StrutStyle(
                                fontFamily: widget.style.fontFamily,
                                fontSize: widget.style.fontSize,
                                height: widget.style.lineHeight,
                                leading: 0,
                                forceStrutHeight: true,
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
                          style: baseStyle,
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
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
        if (blockText == null || blockText.isEmpty) {
          continue;
        }
        final start = fragment.start.clamp(0, blockText.length);
        final end = fragment.end.clamp(start, blockText.length);
        if (end <= start) {
          continue;
        }
        final margin = (block is Block) ? block.style.margin : null;
        if (margin != null && margin.top > 0) {
          items.add(_RenderItem.space(margin.top));
        }
        items.add(
          _RenderItem.text(
            text: blockText.substring(start, end),
            globalStart: fragment.globalStart,
          ),
        );
        if (margin != null && margin.bottom > 0) {
          items.add(_RenderItem.space(margin.bottom));
        }
        continue;
      }

      if (fragment is ImageFragment) {
        final block = blockMap[fragment.blockId];
        if (block is! ImageBlock) {
          continue;
        }
        final margin = block.style.margin;
        if (margin != null && margin.top > 0) {
          items.add(_RenderItem.space(margin.top));
        }
        items.add(_RenderItem.image(block));
        if (margin != null && margin.bottom > 0) {
          items.add(_RenderItem.space(margin.bottom));
        }
        continue;
      }

      if (fragment is SpaceFragment) {
        items.add(_RenderItem.space(fragment.height));
      }
    }
    return items;
  }

  void _trimLeadingTitleFromItems(List<_RenderItem> items, String chapterTitle) {
    final title = chapterTitle.trim();
    if (title.isEmpty) {
      return;
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
        return;
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
        return;
      }

      var trimmed = raw.substring(remove);
      trimmed = trimmed.replaceFirst(RegExp(r'^[\s:：\-—·•]+'), '');
      if (trimmed.isEmpty) {
        items.removeAt(i);
      } else {
        final shift = raw.length - trimmed.length;
        items[i] = _RenderItem.text(
          text: trimmed,
          globalStart: (item.globalStart ?? widget.page.startOffset) + shift,
        );
      }
      return;
    }
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
    final maxImageHeight = math.max(96.0, widget.pageUsableHeight * 0.58);

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
      targetHeight = targetHeight.clamp(48.0, maxImageHeight).toDouble();
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
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxImageHeight,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Align(
            alignment: Alignment.centerLeft,
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
  }) {
    return Container(
      width: maxWidth,
      constraints: BoxConstraints(
        minHeight: 72,
        maxHeight: maxHeight,
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
  final ImageBlock? imageBlock;
  final double? spaceHeight;

  const _RenderItem._({
    required this.type,
    this.text,
    this.globalStart,
    this.imageBlock,
    this.spaceHeight,
  });

  factory _RenderItem.text({
    required String text,
    required int globalStart,
  }) {
    return _RenderItem._(
      type: _RenderItemType.text,
      text: text,
      globalStart: globalStart,
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
