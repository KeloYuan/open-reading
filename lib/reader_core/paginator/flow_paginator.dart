import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Page;

import '../data/reader_models.dart';
import '../document/flow_doc.dart';
import 'page_plan.dart';

typedef PaginationProgress = void Function(List<Page> pages, bool done);

class FlowPaginator {
  static final Map<String, PagePlan> _memoryCache = <String, PagePlan>{};
  static const double _eps = 0.5;
  static const double _renderSafetyBottom = 24.0;
  static const double _estimatedImageVerticalPadding = 4.0;
  static const String _cacheAlgoVersion = 'v4';

  static String buildCacheKey({
    required String chapterId,
    required ReaderStyle style,
    required PageLayout layout,
  }) {
    return '$chapterId::$_cacheAlgoVersion::${layout.cacheSignature()}::${style.cacheSignature()}';
  }

  static PagePlan? getMemoryCache(String key) => _memoryCache[key];

  static void putMemoryCache(PagePlan plan) {
    _memoryCache[plan.cacheKey] = plan;
  }

  static int findPageIndexByAnchor(PagePlan pagePlan, int anchorOffset) {
    if (pagePlan.pages.isEmpty) return 0;

    int low = 0;
    int high = pagePlan.pages.length - 1;
    int result = 0;

    while (low <= high) {
      final mid = (low + high) >> 1;
      final page = pagePlan.pages[mid];
      if (page.startOffset <= anchorOffset) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return result.clamp(0, pagePlan.pages.length - 1);
  }

  Future<PagePlan> paginate({
    required String chapterId,
    required FlowDoc flowDoc,
    required ReaderStyle style,
    required PageLayout layout,
    int eagerPageCount = 4,
    int batchSize = 8,
    PaginationProgress? onProgress,
  }) async {
    final cacheKey =
        buildCacheKey(chapterId: chapterId, style: style, layout: layout);
    final cached = _memoryCache[cacheKey];
    if (cached != null) {
      onProgress?.call(cached.pages, true);
      return cached;
    }

    final blockOffsets = _computeBlockOffsets(flowDoc);
    final pages = <Page>[];
    final currentFragments = <Fragment>[];
    final paragraphCache = <String, _ParagraphLayout>{};

    final pageWidth = layout.usableWidth;
    final lineGuard = math.max(6.0, style.fontSize * style.lineHeight * 0.45);
    final pageHeight = math.max(
      80.0,
      layout.usableHeight - _renderSafetyBottom - lineGuard,
    );

    double consumedHeight = 0;
    int lastCommittedOffset = 0;

    Future<void> flushPage() async {
      if (currentFragments.isEmpty) {
        return;
      }

      int startOffset = lastCommittedOffset;
      int endOffset = lastCommittedOffset;

      for (final fragment in currentFragments) {
        if (fragment is TextFragment) {
          startOffset = math.min(startOffset, fragment.globalStart);
          endOffset = math.max(endOffset, fragment.globalEnd);
        }
      }

      final page = Page(
        index: pages.length,
        startOffset: startOffset,
        endOffset: endOffset,
        fragments: List<Fragment>.from(currentFragments),
      );
      pages.add(page);

      if (endOffset > 0) {
        lastCommittedOffset = endOffset;
      }

      currentFragments.clear();
      consumedHeight = 0;

      if (pages.length == eagerPageCount ||
          (pages.length > eagerPageCount && pages.length % batchSize == 0)) {
        onProgress?.call(List<Page>.from(pages), false);
        await Future<void>.delayed(Duration.zero);
      }
    }

    for (final block in flowDoc.blocks) {
      if (block is ParagraphBlock || block is HeadingBlock) {
        final plainText = block is ParagraphBlock
            ? block.plainText
            : (block as HeadingBlock).plainText;
        if (plainText.isEmpty) {
          continue;
        }

        final painterKey = '${block.id}|$pageWidth|${style.cacheSignature()}';
        final layoutData = paragraphCache.putIfAbsent(
          painterKey,
          () => _layoutParagraph(
            text: plainText,
            blockStyle: block.style,
            readerStyle: style,
            maxWidth: pageWidth,
          ),
        );

        var cursor = 0;
        while (cursor < plainText.length) {
          final remaining = pageHeight - consumedHeight;
          if (remaining <= layoutData.minLineHeight &&
              currentFragments.isNotEmpty) {
            await flushPage();
            continue;
          }

          var end = _findPageEnd(
            layoutData,
            start: cursor,
            remainingHeight: math.max(remaining, layoutData.minLineHeight),
            maxWidth: pageWidth,
          );

          if (end <= cursor) {
            if (currentFragments.isNotEmpty) {
              await flushPage();
              continue;
            }
            end = (cursor + 1).clamp(0, plainText.length);
          }

          final blockBase = blockOffsets[block.id] ?? 0;
          final globalStart = blockBase + cursor;
          final globalEnd = blockBase + end;

          currentFragments.add(
            TextFragment(
              blockId: block.id,
              start: cursor,
              end: end,
              globalStart: globalStart,
              globalEnd: globalEnd,
            ),
          );

          final usedHeight =
              _estimateHeight(layoutData, start: cursor, end: end);
          consumedHeight += usedHeight;
          cursor = end;

          if (cursor < plainText.length) {
            await flushPage();
          }
        }

        final spacing = _blockSpacing(block.style);
        if (spacing > 0) {
          if (consumedHeight + spacing > pageHeight &&
              currentFragments.isNotEmpty) {
            await flushPage();
          }
          currentFragments
              .add(SpaceFragment(blockId: block.id, height: spacing));
          consumedHeight += spacing;
        }
      } else if (block is ImageBlock) {
        final maxImageHeight = math.max(88.0, pageHeight * 0.44);
        final imageHeight =
            (block.height ?? (pageHeight * 0.28)).clamp(44.0, maxImageHeight);
        final spacing = _blockSpacing(block.style);
        final requiredHeight =
            imageHeight + _estimatedImageVerticalPadding + spacing;
        if (consumedHeight + requiredHeight > pageHeight &&
            currentFragments.isNotEmpty) {
          await flushPage();
        }
        currentFragments.add(ImageFragment(blockId: block.id));
        consumedHeight += imageHeight + _estimatedImageVerticalPadding;
        if (spacing > 0) {
          if (consumedHeight + spacing > pageHeight &&
              currentFragments.isNotEmpty) {
            await flushPage();
          }
          currentFragments
              .add(SpaceFragment(blockId: block.id, height: spacing));
          consumedHeight += spacing;
        }
      } else if (block is SpaceBlock) {
        if (consumedHeight + block.height > pageHeight &&
            currentFragments.isNotEmpty) {
          await flushPage();
        }
        currentFragments
            .add(SpaceFragment(blockId: block.id, height: block.height));
        consumedHeight += block.height;
      }
    }

    if (currentFragments.isNotEmpty || pages.isEmpty) {
      await flushPage();
    }

    for (final p in paragraphCache.values) {
      p.painter.dispose();
    }

    final pagePlan =
        PagePlan(chapterId: chapterId, pages: pages, cacheKey: cacheKey);
    _memoryCache[cacheKey] = pagePlan;
    onProgress?.call(pagePlan.pages, true);
    return pagePlan;
  }

  Map<String, int> _computeBlockOffsets(FlowDoc flowDoc) {
    final result = <String, int>{};
    int offset = 0;
    for (final block in flowDoc.blocks) {
      result[block.id] = offset;
      if (block is ParagraphBlock) {
        offset += block.plainText.length;
      } else if (block is HeadingBlock) {
        offset += block.plainText.length;
      }
      offset += 1;
    }
    return result;
  }

  _ParagraphLayout _layoutParagraph({
    required String text,
    required BlockStyle blockStyle,
    required ReaderStyle readerStyle,
    required double maxWidth,
  }) {
    final textStyle = readerStyle.toTextStyle().copyWith(
          fontWeight: blockStyle.fontWeight ?? readerStyle.fontWeight,
          fontStyle: blockStyle.fontStyle ??
              (readerStyle.italic ? FontStyle.italic : FontStyle.normal),
          height: blockStyle.lineHeight ?? readerStyle.lineHeight,
        );

    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: blockStyle.textAlign ?? readerStyle.textAlign,
      locale: readerStyle.locale,
    )..layout(maxWidth: maxWidth);

    final lineHeight = (textStyle.fontSize ?? readerStyle.fontSize) *
        (textStyle.height ?? readerStyle.lineHeight);
    final metrics = painter.computeLineMetrics();
    final lineEnds = <int>[];
    final cumulativeHeights = <double>[0];

    if (metrics.isEmpty) {
      lineEnds.add(text.length);
      cumulativeHeights.add(lineHeight);
    } else {
      for (final metric in metrics) {
        final lineTop = metric.baseline - metric.ascent;
        final probeDy =
            (lineTop + (metric.height <= 0 ? lineHeight : metric.height) / 2)
                .clamp(0, math.max(0, painter.height - _eps))
                .toDouble();
        final probe =
            painter.getPositionForOffset(Offset(maxWidth - _eps, probeDy));
        final boundary = painter.getLineBoundary(probe);
        var endIndex = boundary.end.clamp(0, text.length).toInt();
        if (lineEnds.isNotEmpty && endIndex <= lineEnds.last) {
          endIndex = math.min(text.length, lineEnds.last + 1);
        }
        lineEnds.add(endIndex);
        final lineMetricHeight =
            metric.height <= 0 ? lineHeight : metric.height;
        cumulativeHeights.add(cumulativeHeights.last + lineMetricHeight);
      }
      if (lineEnds.isNotEmpty) {
        lineEnds[lineEnds.length - 1] = text.length;
      }
    }

    return _ParagraphLayout(
      text: text,
      painter: painter,
      minLineHeight: lineHeight,
      lineEnds: lineEnds,
      cumulativeHeights: cumulativeHeights,
    );
  }

  int _findPageEnd(
    _ParagraphLayout layout, {
    required int start,
    required double remainingHeight,
    required double maxWidth,
  }) {
    final painter = layout.painter;
    final textLength = layout.text.length;

    if (start >= textLength) {
      return textLength;
    }

    final startLine = _lineIndexForStart(layout, start);
    final endLine = _lineIndexByRemainingHeight(
      layout,
      startLine: startLine,
      remainingHeight: remainingHeight,
    );
    var end = layout.lineEnds[endLine.clamp(0, layout.lineEnds.length - 1)];

    if (end <= start) {
      final startCaret =
          painter.getOffsetForCaret(TextPosition(offset: start), Rect.zero);
      final targetDy = (startCaret.dy + remainingHeight - _eps)
          .clamp(0, painter.height)
          .toDouble();
      final fallback =
          painter.getPositionForOffset(Offset(maxWidth - _eps, targetDy));
      end = painter.getLineBoundary(fallback).end;
    }

    if (end <= start && start + 1 < textLength) {
      final word = painter.getWordBoundary(TextPosition(offset: start + 1));
      end = word.end;
    }

    return end.clamp(start + 1, textLength).toInt();
  }

  double _estimateHeight(
    _ParagraphLayout layout, {
    required int start,
    required int end,
  }) {
    if (end <= start) {
      return layout.minLineHeight;
    }
    final startLine = _lineIndexForStart(layout, start);
    final endLine = _lineIndexForEnd(layout, end);
    if (endLine < startLine) {
      return layout.minLineHeight;
    }
    final startValue = layout.cumulativeHeights[startLine];
    final endValue = layout.cumulativeHeights[endLine + 1];
    final delta = endValue - startValue;
    if (delta <= 0) {
      return layout.minLineHeight;
    }
    return delta;
  }

  int _lineIndexForStart(_ParagraphLayout layout, int offset) {
    final lineEnds = layout.lineEnds;
    int low = 0;
    int high = lineEnds.length - 1;
    int result = lineEnds.length - 1;

    while (low <= high) {
      final mid = (low + high) >> 1;
      if (lineEnds[mid] > offset) {
        result = mid;
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    return result.clamp(0, lineEnds.length - 1);
  }

  int _lineIndexForEnd(_ParagraphLayout layout, int offset) {
    final lineEnds = layout.lineEnds;
    final safeOffset = offset.clamp(0, layout.text.length);
    int low = 0;
    int high = lineEnds.length - 1;
    int result = lineEnds.length - 1;

    while (low <= high) {
      final mid = (low + high) >> 1;
      if (lineEnds[mid] >= safeOffset) {
        result = mid;
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    return result.clamp(0, lineEnds.length - 1);
  }

  int _lineIndexByRemainingHeight(
    _ParagraphLayout layout, {
    required int startLine,
    required double remainingHeight,
  }) {
    final lineCount = layout.lineEnds.length;
    if (lineCount == 0) {
      return 0;
    }

    final normalizedHeight = math.max(layout.minLineHeight, remainingHeight);
    final baseHeight = layout.cumulativeHeights[startLine];

    int low = startLine + 1;
    int high = lineCount;
    int bestExclusive = startLine + 1;

    while (low <= high) {
      final mid = (low + high) >> 1;
      final consumed = layout.cumulativeHeights[mid] - baseHeight;
      if (consumed <= normalizedHeight + _eps) {
        bestExclusive = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return (bestExclusive - 1).clamp(startLine, lineCount - 1);
  }

  double _blockSpacing(BlockStyle style) {
    final raw = style.margin?.bottom ?? 8.0;
    return raw.clamp(2.0, 18.0);
  }
}

class _ParagraphLayout {
  final String text;
  final TextPainter painter;
  final double minLineHeight;
  final List<int> lineEnds;
  final List<double> cumulativeHeights;

  const _ParagraphLayout({
    required this.text,
    required this.painter,
    required this.minLineHeight,
    required this.lineEnds,
    required this.cumulativeHeights,
  });
}
