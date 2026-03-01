import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Page;

import '../data/reader_models.dart';
import '../document/flow_doc.dart';
import 'page_plan.dart';

typedef PaginationProgress = void Function(List<Page> pages, bool done);

class FlowPaginator {
  static final Map<String, PagePlan> _memoryCache = <String, PagePlan>{};
  static const double _eps = 0.05;
  static const bool _promoteChapterTitleOnFirstPage = false;
  static const double _renderSafetyBottom = 2.0;
  static const double _estimatedImageVerticalPadding = 0.0;
  static const double _imageFragmentSafety = 1.2;
  static const double _textFragmentSafety = 0.0;
  static const double _horizontalOverflowTolerance = -0.35;
  static const double _layoutWidthSafety = 0.0;
  static const double _textInkHorizontalGuard = 1.0;
  static const int _shortLineWidowChars = 2;
  static const String _cacheAlgoVersion = 'v50';
  static const TextScaler _textScaler = TextScaler.noScaling;
  static const TextHeightBehavior _textHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: true,
    applyHeightToLastDescent: true,
  );
  static const bool _debugPaginationLogs = false;
  static const bool _debugPaginationVerbose = false;

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
    String? chapterTitle,
    int eagerPageCount = 4,
    int batchSize = 8,
    PaginationProgress? onProgress,
  }) async {
    _logDebug(
      'start chapter=$chapterId title="${chapterTitle ?? ''}" '
      'layout=(${layout.usableWidth.toStringAsFixed(1)}x${layout.usableHeight.toStringAsFixed(1)}) '
      'style(font=${style.fontSize.toStringAsFixed(1)}, lh=${style.lineHeight.toStringAsFixed(2)}, '
      'ls=${style.letterSpacing.toStringAsFixed(2)}, align=${style.textAlign.name})',
    );
    final cacheKey =
        buildCacheKey(chapterId: chapterId, style: style, layout: layout);
    final cached = _memoryCache[cacheKey];
    if (cached != null) {
      _logDebug(
        'cache hit chapter=$chapterId pages=${cached.pages.length} key=$cacheKey',
      );
      onProgress?.call(cached.pages, true);
      return cached;
    }

    final blockOffsets = _computeBlockOffsets(flowDoc);
    final pages = <Page>[];
    final currentFragments = <Fragment>[];
    final currentDebugStats = <_DebugFragmentStat>[];
    final paragraphCache = <String, _ParagraphLayout>{};
    final blocks = flowDoc.blocks;

    final pageWidth = layout.usableWidth;
    final pageHeight = _effectivePageHeight(
      usableHeight: layout.usableHeight,
    );

    final firstPageHeadingReserve = _promoteChapterTitleOnFirstPage
        ? _estimatePromotedHeadingReserve(
            flowDoc: flowDoc,
            style: style,
            pageWidth: pageWidth,
            chapterTitle: chapterTitle,
          )
        : 0.0;
    _logDebug(
      'layout prepared chapter=$chapterId page=(${pageWidth.toStringAsFixed(1)}x${pageHeight.toStringAsFixed(1)}) '
      'firstPageTitleReserve=${firstPageHeadingReserve.toStringAsFixed(2)}',
    );
    double consumedHeight = firstPageHeadingReserve;
    int lastCommittedOffset = 0;
    int debugSuspiciousPages = 0;
    int debugImagePages = 0;
    int debugAdjustments = 0;

    Future<void> flushPage({bool forcePlaceholder = false}) async {
      if (currentFragments.isEmpty) {
        if (forcePlaceholder) {
          pages.add(
            Page(
              index: pages.length,
              startOffset: lastCommittedOffset,
              endOffset: lastCommittedOffset,
              fragments: const [],
            ),
          );
          onProgress?.call(List<Page>.from(pages), false);
          await Future<void>.delayed(Duration.zero);
        }
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
      final debugSummary = _summarizeFragments(currentFragments);
      final isFirstPage = pages.isEmpty;
      final reserve = isFirstPage ? firstPageHeadingReserve : 0.0;
      final fillRatio = pageHeight > 0 ? consumedHeight / pageHeight : 0.0;
      final suspicious = fillRatio < 0.72 || fillRatio > 1.001;
      if (suspicious) {
        debugSuspiciousPages += 1;
      }
      if (debugSummary.imageFragments > 0) {
        debugImagePages += 1;
      }
      final shouldLogPage =
          suspicious || debugSummary.imageFragments > 0 || pages.length < 6;
      if (shouldLogPage) {
        _logDebug(
          'page idx=${pages.length} fill=${fillRatio.toStringAsFixed(3)} '
          'used=${consumedHeight.toStringAsFixed(2)}/${pageHeight.toStringAsFixed(2)} '
          'reserve=${reserve.toStringAsFixed(2)} start=$startOffset end=$endOffset '
          'textFrags=${debugSummary.textFragments} textChars=${debugSummary.textChars} '
          'imgFrags=${debugSummary.imageFragments} spaceFrags=${debugSummary.spaceFragments}',
        );
        _logPageDetail(
          pageIndex: pages.length,
          pageHeight: pageHeight,
          consumedHeight: consumedHeight,
          fragments: currentDebugStats,
        );
      }
      pages.add(page);

      if (endOffset > 0) {
        lastCommittedOffset = endOffset;
      }

      currentFragments.clear();
      currentDebugStats.clear();
      consumedHeight = 0;

      if (pages.length == 1 ||
          pages.length == eagerPageCount ||
          (pages.length > eagerPageCount && pages.length % batchSize == 0)) {
        onProgress?.call(List<Page>.from(pages), false);
        await Future<void>.delayed(Duration.zero);
      }
    }

    for (var blockIndex = 0; blockIndex < blocks.length; blockIndex++) {
      final block = blocks[blockIndex];
      final hasLaterBlocks = blockIndex < blocks.length - 1;
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
        final blockBase = blockOffsets[block.id] ?? 0;
        final lineCount = layoutData.lineEnds.length;
        if (lineCount <= 0) {
          continue;
        }

        var lineCursor = 0;
        int? partialLineStart;
        while (lineCursor < lineCount) {
          final remaining = pageHeight - consumedHeight;
          if (remaining <= _eps && currentFragments.isNotEmpty) {
            await flushPage();
            continue;
          }

          final currentLineStart = layoutData.lineStarts[lineCursor];
          final currentLineEnd = layoutData.lineEnds[lineCursor];
          final start =
              (partialLineStart ?? currentLineStart).clamp(0, currentLineEnd);
          if (start >= currentLineEnd) {
            partialLineStart = null;
            lineCursor += 1;
            continue;
          }

          var endLineExclusive = partialLineStart == null
              ? _findLineEndExclusiveByHeight(
                  layoutData,
                  startLine: lineCursor,
                  consumedHeight: consumedHeight,
                  pageHeight: pageHeight,
                )
              : lineCursor + 1;
          if (endLineExclusive <= lineCursor) {
            if (currentFragments.isNotEmpty) {
              await flushPage();
              continue;
            }
            endLineExclusive = math.min(lineCount, lineCursor + 1);
          }

          while (endLineExclusive > lineCursor + 1 &&
              _lineRangeHasHorizontalOverflow(
                layoutData,
                startLine: lineCursor,
                endLineExclusive: endLineExclusive,
              )) {
            endLineExclusive -= 1;
          }
          final hasHorizontalOverflow = _lineRangeHasHorizontalOverflow(
            layoutData,
            startLine: lineCursor,
            endLineExclusive: endLineExclusive,
          );
          if (hasHorizontalOverflow && currentFragments.isNotEmpty) {
            await flushPage();
            continue;
          }

          if (partialLineStart == null) {
            endLineExclusive = _adjustEndLineExclusiveForWidow(
              layoutData,
              startLine: lineCursor,
              endLineExclusive: endLineExclusive,
            );
          }
          if (endLineExclusive <= lineCursor) {
            if (currentFragments.isNotEmpty) {
              await flushPage();
              continue;
            }
            endLineExclusive = math.min(lineCount, lineCursor + 1);
          }

          var end = layoutData.lineEnds[endLineExclusive - 1];
          final fittedEnd = _fitSliceEnd(
            layoutData,
            start: start,
            end: end,
            availableHeight: pageHeight - consumedHeight,
          );
          if (fittedEnd <= start) {
            if (currentFragments.isNotEmpty) {
              await flushPage();
              continue;
            }
            end = math.min(layoutData.text.length, start + 1);
          } else {
            end = fittedEnd;
          }
          var measuredSliceHeight = _measureSliceStandaloneHeight(
            layoutData,
            start: start,
            end: end,
          );
          var committedTextHeight =
              _snapToPixelCeil(measuredSliceHeight + _textFragmentSafety);
          var nextConsumedTextHeight =
              _snapToPixelCeil(consumedHeight + committedTextHeight);
          while (nextConsumedTextHeight > pageHeight + _eps &&
              endLineExclusive > lineCursor + 1) {
            endLineExclusive -= 1;
            end = layoutData.lineEnds[endLineExclusive - 1];
            measuredSliceHeight = _measureSliceStandaloneHeight(
              layoutData,
              start: start,
              end: end,
            );
            committedTextHeight =
                _snapToPixelCeil(measuredSliceHeight + _textFragmentSafety);
            nextConsumedTextHeight =
                _snapToPixelCeil(consumedHeight + committedTextHeight);
          }
          if (nextConsumedTextHeight > pageHeight + _eps &&
              currentFragments.isNotEmpty) {
            await flushPage();
            continue;
          }
          if (hasHorizontalOverflow ||
              end < layoutData.lineEnds[endLineExclusive - 1]) {
            debugAdjustments += 1;
            _logDebug(
              'line-overflow-guard block=${block.id} lines=$lineCursor-$endLineExclusive '
              'range=$start-$end width=${layoutData.maxWidth.toStringAsFixed(2)}',
            );
          }

          final globalStart = blockBase + start;
          final globalEnd = blockBase + end;
          currentFragments.add(
            TextFragment(
              blockId: block.id,
              start: start,
              end: end,
              globalStart: globalStart,
              globalEnd: globalEnd,
              measuredHeight: committedTextHeight,
            ),
          );

          final beforeConsumed = consumedHeight;
          consumedHeight = nextConsumedTextHeight;
          currentDebugStats.add(
            _DebugFragmentStat(
              type: 'text',
              blockId: block.id,
              start: start,
              end: end,
              usedHeight: committedTextHeight,
              safetyHeight: 0,
              beforeConsumed: beforeConsumed,
              afterConsumed: consumedHeight,
              note: 'lineBased widthGuard=${hasHorizontalOverflow ? 1 : 0}',
            ),
          );

          final nextState = _advanceLineStateAfterSlice(
            layoutData,
            endOffset: end,
          );
          lineCursor = nextState.lineCursor;
          partialLineStart = nextState.partialLineStart;
          if (lineCursor < lineCount) {
            await flushPage();
          }
        }

        final spacing = hasLaterBlocks
            ? _snapToPixelCeil(_paragraphSpacing(block.style))
            : 0.0;
        if (spacing > 0) {
          if (consumedHeight + spacing > pageHeight &&
              currentFragments.isNotEmpty) {
            await flushPage();
          }
          // 间距只作为段间距，不作为新页顶部留白。
          if (currentFragments.isEmpty) {
            continue;
          }
          currentFragments
              .add(SpaceFragment(blockId: block.id, height: spacing));
          consumedHeight = _snapToPixelCeil(consumedHeight + spacing);
        }
      } else if (block is ImageBlock) {
        final imageHeight = _estimateImageHeight(
          block: block,
          pageWidth: pageWidth,
          pageHeight: pageHeight,
        );
        final committedImageHeight = _snapToPixelCeil(
          imageHeight + _estimatedImageVerticalPadding + _imageFragmentSafety,
        );
        final spacing =
            hasLaterBlocks ? _snapToPixelCeil(_imageSpacing(block.style)) : 0.0;
        final requiredHeight = committedImageHeight + spacing;
        _logDebug(
          'image block=${block.id} required=${requiredHeight.toStringAsFixed(2)} '
          'img=${imageHeight.toStringAsFixed(2)} spacing=${spacing.toStringAsFixed(2)} '
          'consumed=${consumedHeight.toStringAsFixed(2)} pageH=${pageHeight.toStringAsFixed(2)}',
        );
        if (consumedHeight + requiredHeight > pageHeight &&
            currentFragments.isNotEmpty) {
          await flushPage();
        }
        currentFragments.add(
          ImageFragment(
            blockId: block.id,
            measuredHeight: committedImageHeight,
          ),
        );
        final beforeConsumed = consumedHeight;
        consumedHeight =
            _snapToPixelCeil(consumedHeight + committedImageHeight);
        currentDebugStats.add(
          _DebugFragmentStat(
            type: 'image',
            blockId: block.id,
            usedHeight: committedImageHeight,
            safetyHeight: 0,
            beforeConsumed: beforeConsumed,
            afterConsumed: consumedHeight,
            note:
                'required=${requiredHeight.toStringAsFixed(2)} spacing=${spacing.toStringAsFixed(2)}',
          ),
        );
        if (spacing > 0) {
          if (consumedHeight + spacing > pageHeight &&
              currentFragments.isNotEmpty) {
            await flushPage();
          }
          // 间距只作为图后段间距，不作为新页顶部留白。
          if (currentFragments.isEmpty) {
            continue;
          }
          currentFragments
              .add(SpaceFragment(blockId: block.id, height: spacing));
          final beforeSpaceConsumed = consumedHeight;
          consumedHeight = _snapToPixelCeil(consumedHeight + spacing);
          currentDebugStats.add(
            _DebugFragmentStat(
              type: 'space',
              blockId: block.id,
              usedHeight: spacing,
              safetyHeight: 0,
              beforeConsumed: beforeSpaceConsumed,
              afterConsumed: consumedHeight,
              note: 'image_spacing',
            ),
          );
        }
      } else if (block is SpaceBlock) {
        final spaceHeight = _snapToPixelCeil(block.height);
        if (consumedHeight + spaceHeight > pageHeight &&
            currentFragments.isNotEmpty) {
          await flushPage();
        }
        currentFragments
            .add(SpaceFragment(blockId: block.id, height: spaceHeight));
        final beforeConsumed = consumedHeight;
        consumedHeight = _snapToPixelCeil(consumedHeight + spaceHeight);
        currentDebugStats.add(
          _DebugFragmentStat(
            type: 'space',
            blockId: block.id,
            usedHeight: spaceHeight,
            safetyHeight: 0,
            beforeConsumed: beforeConsumed,
            afterConsumed: consumedHeight,
          ),
        );
      }
    }

    if (currentFragments.isNotEmpty || pages.isEmpty) {
      await flushPage(forcePlaceholder: pages.isEmpty);
    }

    for (final p in paragraphCache.values) {
      p.painter.dispose();
    }

    final pagePlan =
        PagePlan(chapterId: chapterId, pages: pages, cacheKey: cacheKey);
    _memoryCache[cacheKey] = pagePlan;
    _logDebug(
      'done chapter=$chapterId pages=${pages.length} suspiciousPages=$debugSuspiciousPages '
      'imagePages=$debugImagePages adjustments=$debugAdjustments cacheKey=$cacheKey',
    );
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
    final layoutWidth = math.max(
      40.0,
      maxWidth - _layoutWidthSafety - (_textInkHorizontalGuard * 2),
    );
    final fontScale =
        (blockStyle.fontSizeScale ?? 1.0).clamp(0.72, 2.4).toDouble();
    final resolvedFontSize = readerStyle.fontSize * fontScale;
    final resolvedLineHeight = _normalizeBlockLineHeight(
      blockStyle.lineHeight,
      readerStyle.lineHeight,
    );
    final textStyle = readerStyle.toTextStyle().copyWith(
          fontSize: resolvedFontSize,
          fontWeight: blockStyle.fontWeight ?? readerStyle.fontWeight,
          fontStyle: blockStyle.fontStyle ??
              (readerStyle.italic ? FontStyle.italic : FontStyle.normal),
          letterSpacing: blockStyle.letterSpacing ?? readerStyle.letterSpacing,
          height: resolvedLineHeight,
        );
    final strutStyle = StrutStyle(
      fontFamily: textStyle.fontFamily,
      fontSize: textStyle.fontSize ?? resolvedFontSize,
      fontWeight: textStyle.fontWeight,
      fontStyle: textStyle.fontStyle,
      height: resolvedLineHeight,
      leading: 0,
      forceStrutHeight: true,
    );
    final resolvedLocale = _effectiveLocale(readerStyle.locale);

    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: blockStyle.textAlign ?? readerStyle.textAlign,
      locale: resolvedLocale,
      textScaler: _textScaler,
      strutStyle: strutStyle,
      textHeightBehavior: _textHeightBehavior,
      textWidthBasis: TextWidthBasis.parent,
    )..layout(maxWidth: layoutWidth);

    final lineHeight =
        (textStyle.fontSize ?? resolvedFontSize) * resolvedLineHeight;
    final lineStarts = <int>[];
    final lineEnds = <int>[];
    final lineWidths = <double>[];
    final cumulativeLineHeights = <double>[0.0];
    final metrics = painter.computeLineMetrics();
    if (metrics.isEmpty) {
      if (text.isNotEmpty) {
        lineStarts.add(0);
        lineEnds.add(text.length);
        lineWidths.add(
          _measureLineVisualWidth(
            painter: painter,
            start: 0,
            end: text.length,
            fallbackWidth: painter.width,
          ),
        );
        cumulativeLineHeights.add(lineHeight);
      }
    } else {
      var cursor = 0;
      const startProbeX = 0.0;
      final endProbeX = math.max(0.0, layoutWidth - _eps);
      for (final metric in metrics) {
        if (cursor >= text.length) {
          break;
        }
        final metricHeight = metric.height <= 0 ? lineHeight : metric.height;
        final lineTop = metric.baseline - metric.ascent;
        final probeY = (lineTop + metricHeight / 2)
            .clamp(0.0, math.max(0.0, painter.height - _eps))
            .toDouble();
        final startProbe =
            painter.getPositionForOffset(Offset(startProbeX, probeY));
        final startBoundary = painter.getLineBoundary(startProbe);
        var start = startBoundary.start.clamp(0, text.length).toInt();
        if (start != cursor) {
          start = cursor;
        }
        final endProbe =
            painter.getPositionForOffset(Offset(endProbeX, probeY));
        final endBoundary = painter.getLineBoundary(endProbe);
        var end = math
            .max(startBoundary.end, endBoundary.end)
            .clamp(start, text.length)
            .toInt();
        if (end <= start) {
          end = math.min(text.length, start + 1).toInt();
        }
        lineStarts.add(start);
        lineEnds.add(end);
        lineWidths.add(
          _measureLineVisualWidth(
            painter: painter,
            start: start,
            end: end,
            fallbackWidth: metric.width,
          ),
        );
        cumulativeLineHeights.add(cumulativeLineHeights.last + metricHeight);
        cursor = end;
      }
      if (cursor < text.length) {
        lineStarts.add(cursor);
        lineEnds.add(text.length);
        lineWidths.add(
          _measureLineVisualWidth(
            painter: painter,
            start: cursor,
            end: text.length,
            fallbackWidth: layoutWidth,
          ),
        );
        cumulativeLineHeights.add(cumulativeLineHeights.last + lineHeight);
      }
    }
    if (lineStarts.isEmpty) {
      lineStarts.add(0);
      lineEnds.add(text.length);
      lineWidths.add(
        _measureLineVisualWidth(
          painter: painter,
          start: 0,
          end: text.length,
          fallbackWidth: painter.width,
        ),
      );
      cumulativeLineHeights.add(lineHeight);
    } else if (lineEnds.last != text.length) {
      lineEnds[lineEnds.length - 1] = text.length;
    }

    return _ParagraphLayout(
      text: text,
      painter: painter,
      textStyle: textStyle,
      strutStyle: strutStyle,
      textAlign: blockStyle.textAlign ?? readerStyle.textAlign,
      locale: resolvedLocale,
      maxWidth: layoutWidth,
      minLineHeight: lineHeight,
      lineStarts: lineStarts,
      lineEnds: lineEnds,
      lineWidths: lineWidths,
      cumulativeLineHeights: cumulativeLineHeights,
    );
  }

  int _adjustEndLineExclusiveForWidow(
    _ParagraphLayout layout, {
    required int startLine,
    required int endLineExclusive,
  }) {
    if (_shortLineWidowChars <= 0) {
      return endLineExclusive;
    }
    final lineCount = layout.lineEnds.length;
    final safeStart = startLine.clamp(0, math.max(0, lineCount - 1)).toInt();
    final safeEnd = endLineExclusive.clamp(safeStart + 1, lineCount).toInt();
    if (safeEnd - safeStart <= 1) {
      return safeEnd;
    }
    if (safeEnd >= lineCount) {
      return safeEnd;
    }
    final lastLine = safeEnd - 1;
    final chars = layout.lineEnds[lastLine] - layout.lineStarts[lastLine];
    if (chars > _shortLineWidowChars) {
      return safeEnd;
    }
    final candidate = safeEnd - 1;
    if (candidate <= safeStart) {
      return safeEnd;
    }
    return candidate;
  }

  int _findLineEndExclusiveByHeight(
    _ParagraphLayout layout, {
    required int startLine,
    required double consumedHeight,
    required double pageHeight,
  }) {
    final lineCount = layout.lineEnds.length;
    if (lineCount <= 0) {
      return startLine;
    }
    final safeStartLine = startLine.clamp(0, lineCount - 1);
    final available = pageHeight - consumedHeight - _textFragmentSafety;
    if (available <= _eps) {
      return safeStartLine;
    }
    final baseHeight = layout.cumulativeLineHeights[safeStartLine];
    var low = safeStartLine + 1;
    var high = lineCount;
    var best = safeStartLine;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final used = layout.cumulativeLineHeights[mid] - baseHeight;
      if (used <= available + _eps) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return best;
  }

  bool _lineRangeHasHorizontalOverflow(
    _ParagraphLayout layout, {
    required int startLine,
    required int endLineExclusive,
  }) {
    final safeStart = startLine.clamp(0, layout.lineWidths.length - 1);
    final safeEnd =
        endLineExclusive.clamp(safeStart + 1, layout.lineWidths.length);
    for (var i = safeStart; i < safeEnd; i++) {
      if (layout.lineWidths[i] >
          layout.maxWidth + _horizontalOverflowTolerance) {
        return true;
      }
    }
    return false;
  }

  double _measureSliceStandaloneHeight(
    _ParagraphLayout layout, {
    required int start,
    required int end,
  }) {
    final safeStart = start.clamp(0, layout.text.length).toInt();
    final safeEnd = end.clamp(safeStart, layout.text.length).toInt();
    if (safeEnd <= safeStart) {
      return layout.minLineHeight;
    }
    final key = '$safeStart:$safeEnd';
    final cached = layout.sliceHeightCache[key];
    if (cached != null) {
      return cached;
    }
    final slice = layout.text.substring(safeStart, safeEnd);
    final painter = TextPainter(
      text: TextSpan(text: slice, style: layout.textStyle),
      textDirection: TextDirection.ltr,
      textAlign: layout.textAlign,
      locale: layout.locale,
      textScaler: _textScaler,
      strutStyle: layout.strutStyle,
      textHeightBehavior: _textHeightBehavior,
      textWidthBasis: TextWidthBasis.parent,
    )..layout(maxWidth: layout.maxWidth);
    final measured =
        painter.height <= 0 ? layout.minLineHeight : painter.height;
    painter.dispose();
    layout.sliceHeightCache[key] = measured;
    return measured;
  }

  int _fitSliceEnd(
    _ParagraphLayout layout, {
    required int start,
    required int end,
    required double availableHeight,
  }) {
    final safeStart = start.clamp(0, layout.text.length).toInt();
    final safeEnd = end.clamp(safeStart, layout.text.length).toInt();
    if (safeEnd <= safeStart) {
      return safeStart;
    }
    if (availableHeight <= _eps) {
      return safeStart;
    }

    var low = safeStart + 1;
    var high = safeEnd;
    var best = safeStart;

    while (low <= high) {
      final mid = (low + high) >> 1;
      final measuredHeight = _snapToPixelCeil(
        _measureSliceStandaloneHeight(
              layout,
              start: safeStart,
              end: mid,
            ) +
            _textFragmentSafety,
      );
      final hasHorizontalOverflow = _sliceHasHorizontalOverflowStandalone(
        layout,
        start: safeStart,
        end: mid,
      );
      final fits =
          !hasHorizontalOverflow && measuredHeight <= availableHeight + _eps;
      if (fits) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return best;
  }

  bool _sliceHasHorizontalOverflowStandalone(
    _ParagraphLayout layout, {
    required int start,
    required int end,
  }) {
    final maxWidth = _measureSliceMaxLineWidthStandalone(
      layout,
      start: start,
      end: end,
    );
    return maxWidth > layout.maxWidth + _horizontalOverflowTolerance;
  }

  double _measureSliceMaxLineWidthStandalone(
    _ParagraphLayout layout, {
    required int start,
    required int end,
  }) {
    final safeStart = start.clamp(0, layout.text.length).toInt();
    final safeEnd = end.clamp(safeStart, layout.text.length).toInt();
    if (safeEnd <= safeStart) {
      return 0.0;
    }
    final key = '$safeStart:$safeEnd';
    final cached = layout.sliceMaxLineWidthCache[key];
    if (cached != null) {
      return cached;
    }
    final slice = layout.text.substring(safeStart, safeEnd);
    final painter = TextPainter(
      text: TextSpan(text: slice, style: layout.textStyle),
      textDirection: TextDirection.ltr,
      textAlign: layout.textAlign,
      locale: layout.locale,
      textScaler: _textScaler,
      strutStyle: layout.strutStyle,
      textHeightBehavior: _textHeightBehavior,
      textWidthBasis: TextWidthBasis.parent,
    )..layout(maxWidth: layout.maxWidth);

    var maxLineWidth = 0.0;
    final metrics = painter.computeLineMetrics();
    if (metrics.isNotEmpty) {
      for (final line in metrics) {
        maxLineWidth = math.max(maxLineWidth, line.width);
      }
    } else {
      maxLineWidth = painter.width;
    }
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: slice.length),
    );
    if (boxes.isNotEmpty) {
      var left = double.infinity;
      var right = double.negativeInfinity;
      for (final box in boxes) {
        if (box.left < left) {
          left = box.left;
        }
        if (box.right > right) {
          right = box.right;
        }
      }
      if (left.isFinite && right.isFinite && right > left) {
        maxLineWidth = math.max(maxLineWidth, right - left);
      }
    }
    painter.dispose();
    layout.sliceMaxLineWidthCache[key] = maxLineWidth;
    return maxLineWidth;
  }

  _LineCursorState _advanceLineStateAfterSlice(
    _ParagraphLayout layout, {
    required int endOffset,
  }) {
    final lineCount = layout.lineEnds.length;
    if (lineCount <= 0) {
      return const _LineCursorState(lineCursor: 0, partialLineStart: null);
    }
    if (endOffset >= layout.lineEnds.last) {
      return _LineCursorState(lineCursor: lineCount, partialLineStart: null);
    }

    int low = 0;
    int high = lineCount - 1;
    var lineIndex = lineCount - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (endOffset < layout.lineEnds[mid]) {
        lineIndex = mid;
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }

    final lineStart = layout.lineStarts[lineIndex];
    if (endOffset <= lineStart) {
      return _LineCursorState(lineCursor: lineIndex, partialLineStart: null);
    }
    return _LineCursorState(
      lineCursor: lineIndex,
      partialLineStart: endOffset,
    );
  }

  double _estimatePromotedHeadingReserve({
    required FlowDoc flowDoc,
    required ReaderStyle style,
    required double pageWidth,
    String? chapterTitle,
  }) {
    final titleText = chapterTitle?.trim() ?? '';
    final text =
        titleText.isNotEmpty ? titleText : _fallbackHeadingText(flowDoc.blocks);
    if (text.isEmpty) {
      return 0.0;
    }

    final promotedSize = (style.fontSize * 1.34).clamp(18.0, 40.0).toDouble();
    final promotedStyle = style.toTextStyle().copyWith(
          fontSize: promotedSize,
          fontWeight: FontWeight.w700,
          height: 1.25,
        );
    final strutStyle = StrutStyle(
      fontFamily: promotedStyle.fontFamily,
      fontSize: promotedSize,
      height: 1.25,
      leading: 0,
      forceStrutHeight: true,
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: promotedStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
      locale: _effectiveLocale(style.locale),
      textScaler: _textScaler,
      maxLines: 2,
      ellipsis: '…',
      strutStyle: strutStyle,
      textHeightBehavior: _textHeightBehavior,
      textWidthBasis: TextWidthBasis.parent,
    )..layout(maxWidth: pageWidth);
    final reserve = painter.height + 10.0;
    painter.dispose();
    return reserve.clamp(0.0, promotedSize * 2.6);
  }

  String _fallbackHeadingText(List<Block> blocks) {
    if (blocks.isEmpty) {
      return '';
    }
    final first = blocks.first;
    if (first is! HeadingBlock) {
      return '';
    }
    return first.plainText.trim();
  }

  double _paragraphSpacing(BlockStyle style) {
    final fontScale = (style.fontSizeScale ?? 1.0).clamp(0.8, 1.8).toDouble();
    final emphasisBoost = fontScale > 1.12 ? 0.9 : 0.4;
    return (1.8 + emphasisBoost).clamp(1.8, 3.0);
  }

  double _imageSpacing(BlockStyle style) {
    final fontScale = (style.fontSizeScale ?? 1.0).clamp(0.8, 1.8).toDouble();
    return (2.0 + (fontScale - 1.0) * 0.6).clamp(1.8, 2.8);
  }

  double _estimateImageHeight({
    required ImageBlock block,
    required double pageWidth,
    required double pageHeight,
  }) {
    final isCoverImage = _isCoverImageBlock(block);
    final maxImageHeight = isCoverImage
        ? math.max(180.0, pageHeight * 0.90)
        : math.max(84.0, pageHeight * 0.44);

    var targetWidth = pageWidth;
    var targetHeight = block.height;

    if (block.width != null && block.width! > 0) {
      targetWidth = math.min(pageWidth, block.width!);
    }
    if (block.width != null &&
        block.height != null &&
        block.width! > 0 &&
        block.height! > 0) {
      targetHeight = targetWidth * (block.height! / block.width!);
    }

    if (targetHeight != null) {
      final minHeight = isCoverImage ? 120.0 : 38.0;
      return targetHeight.clamp(minHeight, maxImageHeight).toDouble();
    }
    final fallbackHeight = isCoverImage ? pageHeight * 0.78 : pageHeight * 0.24;
    final minHeight = isCoverImage ? 120.0 : 38.0;
    return fallbackHeight.clamp(minHeight, maxImageHeight).toDouble();
  }

  double _effectivePageHeight({
    required double usableHeight,
  }) {
    return math.max(80.0, usableHeight - _renderSafetyBottom);
  }

  void _logDebug(String message) {
    if (!_debugPaginationLogs || !kDebugMode) {
      return;
    }
    debugPrint('[ReaderPaginator] $message');
  }

  void _logPageDetail({
    required int pageIndex,
    required double pageHeight,
    required double consumedHeight,
    required List<_DebugFragmentStat> fragments,
  }) {
    if (!_debugPaginationVerbose || !kDebugMode) {
      return;
    }
    if (fragments.isEmpty) {
      _logDebug('page-detail idx=$pageIndex fragments=0');
      return;
    }
    _logDebug(
      'page-detail idx=$pageIndex fragments=${fragments.length} '
      'consumed=${consumedHeight.toStringAsFixed(2)}/${pageHeight.toStringAsFixed(2)}',
    );
    for (var i = 0; i < fragments.length; i++) {
      final f = fragments[i];
      _logDebug(
        '  #$i ${f.type} block=${f.blockId} '
        'range=${f.start ?? -1}-${f.end ?? -1} '
        'h=${f.usedHeight.toStringAsFixed(2)} '
        'safety=${f.safetyHeight.toStringAsFixed(2)} '
        'consumed=${f.beforeConsumed.toStringAsFixed(2)}->${f.afterConsumed.toStringAsFixed(2)} '
        '${f.note ?? ''}',
      );
    }
  }

  _FragmentDebugSummary _summarizeFragments(List<Fragment> fragments) {
    int textFragments = 0;
    int imageFragments = 0;
    int spaceFragments = 0;
    int textChars = 0;
    for (final fragment in fragments) {
      if (fragment is TextFragment) {
        textFragments += 1;
        textChars += math.max(0, fragment.end - fragment.start);
      } else if (fragment is ImageFragment) {
        imageFragments += 1;
      } else if (fragment is SpaceFragment) {
        spaceFragments += 1;
      }
    }
    return _FragmentDebugSummary(
      textFragments: textFragments,
      imageFragments: imageFragments,
      spaceFragments: spaceFragments,
      textChars: textChars,
    );
  }

  double _normalizeBlockLineHeight(double? rawValue, double fallback) {
    final fallbackValue = fallback.clamp(1.0, 3.2).toDouble();
    final raw = rawValue;
    if (raw == null || !raw.isFinite || raw <= 0) {
      return fallbackValue;
    }
    if (raw < 0.7) {
      return fallbackValue;
    }
    // EPUB 中常见 px/异常值误入 height 倍数，这里回退避免分页异常。
    if (raw > 4.0) {
      return fallbackValue;
    }
    final minPreferred = (fallbackValue - 0.22).clamp(1.0, 2.4).toDouble();
    final maxPreferred = (fallbackValue + 0.32).clamp(1.2, 2.6).toDouble();
    return raw.clamp(minPreferred, maxPreferred).toDouble();
  }

  Locale? _effectiveLocale(Locale? locale) {
    if (locale != null) {
      return locale;
    }
    try {
      return WidgetsBinding.instance.platformDispatcher.locale;
    } catch (_) {
      return locale;
    }
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

  double _snapToPixelCeil(double value) {
    if (!value.isFinite || value <= 0) {
      return value;
    }
    final dpr = _devicePixelRatio();
    return (value * dpr).ceil() / dpr;
  }

  double _devicePixelRatio() {
    try {
      final views = WidgetsBinding.instance.platformDispatcher.views;
      if (views.isNotEmpty) {
        return views.first.devicePixelRatio.clamp(1.0, 4.0);
      }
    } catch (_) {
      // Fall through to default.
    }
    return 1.0;
  }

  double _measureLineVisualWidth({
    required TextPainter painter,
    required int start,
    required int end,
    required double fallbackWidth,
  }) {
    if (end <= start) {
      return 0.0;
    }
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );
    if (boxes.isEmpty) {
      return fallbackWidth;
    }
    var left = double.infinity;
    var right = double.negativeInfinity;
    for (final box in boxes) {
      if (box.left < left) {
        left = box.left;
      }
      if (box.right > right) {
        right = box.right;
      }
    }
    if (!left.isFinite || !right.isFinite || right <= left) {
      return fallbackWidth;
    }
    return right - left;
  }
}

class _FragmentDebugSummary {
  final int textFragments;
  final int imageFragments;
  final int spaceFragments;
  final int textChars;

  const _FragmentDebugSummary({
    required this.textFragments,
    required this.imageFragments,
    required this.spaceFragments,
    required this.textChars,
  });
}

class _DebugFragmentStat {
  final String type;
  final String blockId;
  final int? start;
  final int? end;
  final double usedHeight;
  final double safetyHeight;
  final double beforeConsumed;
  final double afterConsumed;
  final String? note;

  const _DebugFragmentStat({
    required this.type,
    required this.blockId,
    this.start,
    this.end,
    required this.usedHeight,
    required this.safetyHeight,
    required this.beforeConsumed,
    required this.afterConsumed,
    this.note,
  });
}

class _LineCursorState {
  final int lineCursor;
  final int? partialLineStart;

  const _LineCursorState({
    required this.lineCursor,
    required this.partialLineStart,
  });
}

class _ParagraphLayout {
  final String text;
  final TextPainter painter;
  final TextStyle textStyle;
  final StrutStyle strutStyle;
  final TextAlign textAlign;
  final Locale? locale;
  final double maxWidth;
  final double minLineHeight;
  final List<int> lineStarts;
  final List<int> lineEnds;
  final List<double> lineWidths;
  final List<double> cumulativeLineHeights;
  final Map<String, double> sliceHeightCache;
  final Map<String, double> sliceMaxLineWidthCache;

  _ParagraphLayout({
    required this.text,
    required this.painter,
    required this.textStyle,
    required this.strutStyle,
    required this.textAlign,
    required this.locale,
    required this.maxWidth,
    required this.minLineHeight,
    required this.lineStarts,
    required this.lineEnds,
    required this.lineWidths,
    required this.cumulativeLineHeights,
    Map<String, double>? sliceHeightCache,
    Map<String, double>? sliceMaxLineWidthCache,
  })  : sliceHeightCache = sliceHeightCache ?? <String, double>{},
        sliceMaxLineWidthCache = sliceMaxLineWidthCache ?? <String, double>{};
}
