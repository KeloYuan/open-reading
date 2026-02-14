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
  static const double _eps = 0.8;
  static const double _renderSafetyBottom = 8.0;
  static const double _estimatedImageVerticalPadding = 0.0;
  static const double _imageFragmentSafety = 1.2;
  static const double _textFragmentSafety = 0.25;
  static const String _cacheAlgoVersion = 'v17';
  static const TextScaler _textScaler = TextScaler.noScaling;
  static const TextHeightBehavior _textHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
  );
  static const bool _debugPaginationLogs = true;
  static const bool _debugPaginationVerbose = true;

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

    final pageWidth = layout.usableWidth;
    final pageHeight = _effectivePageHeight(
      usableHeight: layout.usableHeight,
      style: style,
    );

    final firstPageHeadingReserve = _estimatePromotedHeadingReserve(
      flowDoc: flowDoc,
      style: style,
      pageWidth: pageWidth,
      chapterTitle: chapterTitle,
    );
    _logDebug(
      'layout prepared chapter=$chapterId page=(${pageWidth.toStringAsFixed(1)}x${pageHeight.toStringAsFixed(1)}) '
      'firstPageTitleReserve=${firstPageHeadingReserve.toStringAsFixed(2)}',
    );
    double consumedHeight = firstPageHeadingReserve;
    int lastCommittedOffset = 0;
    int debugSuspiciousPages = 0;
    int debugImagePages = 0;
    int debugAdjustments = 0;

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

      if (pages.length == eagerPageCount ||
          (pages.length > eagerPageCount && pages.length % batchSize == 0)) {
        onProgress?.call(List<Page>.from(pages), false);
        await Future<void>.delayed(Duration.zero);
      }
    }

    final blocks = flowDoc.blocks;
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

        var cursor = 0;
        while (cursor < plainText.length) {
          if (currentFragments.isEmpty) {
            cursor = _skipLeadingBreaks(plainText, cursor);
            if (cursor >= plainText.length) {
              break;
            }
          }

          final remaining = pageHeight - consumedHeight;
          if (remaining <= layoutData.minLineHeight &&
              currentFragments.isNotEmpty) {
            _logDebug(
              'flush due to remaining<=lineHeight block=${block.id} '
              'remaining=${remaining.toStringAsFixed(2)} minLine=${layoutData.minLineHeight.toStringAsFixed(2)}',
            );
            await flushPage();
            continue;
          }

          var end = _findPageEnd(
            layoutData,
            start: cursor,
            remainingHeight: math.max(remaining, layoutData.minLineHeight),
            maxWidth: pageWidth,
          );
          final probeEnd = end;

          if (end <= cursor) {
            if (currentFragments.isNotEmpty) {
              await flushPage();
              continue;
            }
            end = (cursor + 1).clamp(0, plainText.length);
          }

          end = _shrinkTextEndToFit(
            layoutData,
            start: cursor,
            end: end,
            consumedHeight: consumedHeight,
            pageHeight: pageHeight,
          );
          final shrinkEnd = end;
          end = _expandTextEndToFill(
            layoutData,
            start: cursor,
            end: end,
            consumedHeight: consumedHeight,
            pageHeight: pageHeight,
          );
          final expandEnd = end;
          end = _trimTrailingBreaks(layoutData.text, cursor, end);
          final trimEnd = end;
          end = _avoidOrphanTailLine(
            layoutData,
            start: cursor,
            end: end,
            hasFollowingContent: end < plainText.length || hasLaterBlocks,
            consumedHeight: consumedHeight,
            pageHeight: pageHeight,
          );
          final orphanEnd = end;
          if (probeEnd != shrinkEnd ||
              shrinkEnd != expandEnd ||
              expandEnd != trimEnd ||
              trimEnd != orphanEnd) {
            debugAdjustments += 1;
            final localUsed =
                _measureSliceHeight(layoutData, start: cursor, end: end);
            _logDebug(
              'adjust block=${block.id} cursor=$cursor probe=$probeEnd shrink=$shrinkEnd '
              'expand=$expandEnd trim=$trimEnd orphan=$orphanEnd '
              'sliceH=${localUsed.toStringAsFixed(2)} remaining=${remaining.toStringAsFixed(2)}',
            );
          }
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
              _measureSliceHeight(layoutData, start: cursor, end: end);
          final beforeConsumed = consumedHeight;
          consumedHeight += usedHeight + _textFragmentSafety;
          currentDebugStats.add(
            _DebugFragmentStat(
              type: 'text',
              blockId: block.id,
              start: cursor,
              end: end,
              usedHeight: usedHeight,
              safetyHeight: _textFragmentSafety,
              beforeConsumed: beforeConsumed,
              afterConsumed: consumedHeight,
              note:
                  'probe=$probeEnd shrink=$shrinkEnd expand=$expandEnd trim=$trimEnd orphan=$orphanEnd',
            ),
          );
          cursor = end;

          if (cursor < plainText.length) {
            await flushPage();
          }
        }

        final spacing = hasLaterBlocks ? _paragraphSpacing(block.style) : 0.0;
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
        final imageHeight = _estimateImageHeight(
          block: block,
          pageWidth: pageWidth,
          pageHeight: pageHeight,
        );
        final spacing = hasLaterBlocks ? _imageSpacing(block.style) : 0.0;
        final requiredHeight =
            imageHeight +
                _estimatedImageVerticalPadding +
                _imageFragmentSafety +
                spacing;
        _logDebug(
          'image block=${block.id} required=${requiredHeight.toStringAsFixed(2)} '
          'img=${imageHeight.toStringAsFixed(2)} spacing=${spacing.toStringAsFixed(2)} '
          'consumed=${consumedHeight.toStringAsFixed(2)} pageH=${pageHeight.toStringAsFixed(2)}',
        );
        if (consumedHeight + requiredHeight > pageHeight &&
            currentFragments.isNotEmpty) {
          await flushPage();
        }
        currentFragments.add(ImageFragment(blockId: block.id));
        final beforeConsumed = consumedHeight;
        consumedHeight +=
            imageHeight + _estimatedImageVerticalPadding + _imageFragmentSafety;
        currentDebugStats.add(
          _DebugFragmentStat(
            type: 'image',
            blockId: block.id,
            usedHeight: imageHeight + _estimatedImageVerticalPadding,
            safetyHeight: _imageFragmentSafety,
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
          currentFragments
              .add(SpaceFragment(blockId: block.id, height: spacing));
          final beforeSpaceConsumed = consumedHeight;
          consumedHeight += spacing;
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
        if (consumedHeight + block.height > pageHeight &&
            currentFragments.isNotEmpty) {
          await flushPage();
        }
        currentFragments
            .add(SpaceFragment(blockId: block.id, height: block.height));
        final beforeConsumed = consumedHeight;
        consumedHeight += block.height;
        currentDebugStats.add(
          _DebugFragmentStat(
            type: 'space',
            blockId: block.id,
            usedHeight: block.height,
            safetyHeight: 0,
            beforeConsumed: beforeConsumed,
            afterConsumed: consumedHeight,
          ),
        );
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
    final resolvedLineHeight = _normalizeBlockLineHeight(
      blockStyle.lineHeight,
      readerStyle.lineHeight,
    );
    final textStyle = readerStyle.toTextStyle().copyWith(
          fontWeight: blockStyle.fontWeight ?? readerStyle.fontWeight,
          fontStyle: blockStyle.fontStyle ??
              (readerStyle.italic ? FontStyle.italic : FontStyle.normal),
          height: resolvedLineHeight,
        );
    final strutStyle = StrutStyle(
      fontFamily: textStyle.fontFamily,
      fontSize: textStyle.fontSize ?? readerStyle.fontSize,
      height: resolvedLineHeight,
      leading: 0,
      forceStrutHeight: true,
    );

    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: blockStyle.textAlign ?? readerStyle.textAlign,
      locale: readerStyle.locale,
      textScaler: _textScaler,
      strutStyle: strutStyle,
      textHeightBehavior: _textHeightBehavior,
      textWidthBasis: TextWidthBasis.parent,
    )..layout(maxWidth: maxWidth);

    final lineHeight =
        (textStyle.fontSize ?? readerStyle.fontSize) * resolvedLineHeight;
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
      textStyle: textStyle,
      strutStyle: strutStyle,
      textAlign: blockStyle.textAlign ?? readerStyle.textAlign,
      locale: readerStyle.locale,
      maxWidth: maxWidth,
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

    final startCaret =
        painter.getOffsetForCaret(TextPosition(offset: start), Rect.zero);
    final targetDy = (startCaret.dy + remainingHeight - _eps)
        .clamp(0, math.max(0.0, painter.height - _eps))
        .toDouble();
    var end = painter
        .getLineBoundary(
          painter.getPositionForOffset(Offset(maxWidth - _eps, targetDy)),
        )
        .end;

    if (end <= start) {
      final startLine = _lineIndexForStart(layout, start);
      final endLine = _lineIndexByRemainingHeight(
        layout,
        startLine: startLine,
        remainingHeight: remainingHeight,
      );
      end = layout.lineEnds[endLine.clamp(0, layout.lineEnds.length - 1)];
    }

    if (end <= start && start + 1 < textLength) {
      final word = painter.getWordBoundary(TextPosition(offset: start + 1));
      end = word.end;
    }

    return end.clamp(start + 1, textLength).toInt();
  }

  int _shrinkTextEndToFit(
    _ParagraphLayout layout, {
    required int start,
    required int end,
    required double consumedHeight,
    required double pageHeight,
  }) {
    var candidate = end.clamp(start + 1, layout.text.length).toInt();
    if (_canFitTextSlice(
      layout,
      start: start,
      end: candidate,
      consumedHeight: consumedHeight,
      pageHeight: pageHeight,
    )) {
      return candidate;
    }

    final startLine = _lineIndexForStart(layout, start);
    var endLine = _lineIndexForEnd(layout, candidate);
    while (endLine > startLine) {
      final previousLineEnd = layout.lineEnds[endLine - 1]
          .clamp(start + 1, candidate)
          .toInt();
      if (previousLineEnd <= start) {
        break;
      }
      candidate = previousLineEnd;
      if (_canFitTextSlice(
        layout,
        start: start,
        end: candidate,
        consumedHeight: consumedHeight,
        pageHeight: pageHeight,
      )) {
        return candidate;
      }
      endLine -= 1;
    }

    while (candidate > start + 1) {
      candidate -= 1;
      if (_canFitTextSlice(
        layout,
        start: start,
        end: candidate,
        consumedHeight: consumedHeight,
        pageHeight: pageHeight,
      )) {
        return candidate;
      }
    }

    return (start + 1).clamp(0, layout.text.length).toInt();
  }

  int _expandTextEndToFill(
    _ParagraphLayout layout, {
    required int start,
    required int end,
    required double consumedHeight,
    required double pageHeight,
  }) {
    var candidate = end.clamp(start + 1, layout.text.length).toInt();
    final painter = layout.painter;
    while (candidate < layout.text.length) {
      final probe = math.min(layout.text.length - 1, candidate + 1);
      final nextEnd = painter
          .getLineBoundary(TextPosition(offset: probe))
          .end
          .clamp(candidate + 1, layout.text.length)
          .toInt();
      if (nextEnd <= candidate) {
        break;
      }
      if (!_canFitTextSlice(
        layout,
        start: start,
        end: nextEnd,
        consumedHeight: consumedHeight,
        pageHeight: pageHeight,
      )) {
        break;
      }
      candidate = nextEnd;
    }
    return candidate;
  }

  bool _canFitTextSlice(
    _ParagraphLayout layout, {
    required int start,
    required int end,
    required double consumedHeight,
    required double pageHeight,
  }) {
    final used = _measureSliceHeight(layout, start: start, end: end);
    return consumedHeight + used + _textFragmentSafety <= pageHeight + _eps;
  }

  int _avoidOrphanTailLine(
    _ParagraphLayout layout, {
    required int start,
    required int end,
    required bool hasFollowingContent,
    required double consumedHeight,
    required double pageHeight,
  }) {
    if (end <= start || !hasFollowingContent) {
      return end;
    }

    final used = _measureSliceHeight(layout, start: start, end: end);
    final remainingAfter =
        pageHeight - (consumedHeight + used + _textFragmentSafety);
    // 仅在接近页底时做“尾行单字回退”，避免在页面很空时制造大片留白。
    if (remainingAfter > layout.minLineHeight * 0.75) {
      return end;
    }

    final startLine = _lineIndexForStart(layout, start);
    final endLine = _lineIndexForEnd(layout, end);
    if (endLine <= startLine) {
      return end;
    }

    final previousLineEnd = layout.lineEnds[endLine - 1];
    if (previousLineEnd <= start) {
      return end;
    }

    final tailStart = math.max(start, previousLineEnd);
    final tail = layout.text.substring(tailStart, end);
    final compact = tail.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) {
      return previousLineEnd;
    }
    if (compact.length <= 1) {
      return previousLineEnd;
    }
    if (compact.length == 2) {
      final noPunc = compact.replaceAll(RegExp(r'[，。！？；：,.!?;]'), '');
      if (noPunc.length <= 1) {
        return previousLineEnd;
      }
    }

    return end;
  }

  int _skipLeadingBreaks(String text, int start) {
    var i = start.clamp(0, text.length).toInt();
    while (i < text.length) {
      final code = text.codeUnitAt(i);
      if (code == 0x0A || code == 0x0D) {
        i += 1;
      } else {
        break;
      }
    }
    return i;
  }

  int _trimTrailingBreaks(String text, int start, int end) {
    var i = end.clamp(start, text.length).toInt();
    final min = start.clamp(0, text.length).toInt();
    while (i > min) {
      final code = text.codeUnitAt(i - 1);
      if (code == 0x0A || code == 0x0D) {
        i -= 1;
      } else {
        break;
      }
    }
    return i;
  }

  double _estimatePromotedHeadingReserve({
    required FlowDoc flowDoc,
    required ReaderStyle style,
    required double pageWidth,
    String? chapterTitle,
  }) {
    final titleText = chapterTitle?.trim() ?? '';
    final text = titleText.isNotEmpty
        ? titleText
        : _fallbackHeadingText(flowDoc.blocks);
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
      locale: style.locale,
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

  double _measureSliceHeight(
    _ParagraphLayout layout, {
    required int start,
    required int end,
  }) {
    if (end <= start) {
      return layout.minLineHeight;
    }
    final safeStart = start.clamp(0, layout.text.length).toInt();
    final safeEnd = end.clamp(safeStart, layout.text.length).toInt();
    if (safeEnd <= safeStart) {
      return layout.minLineHeight;
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
    final h = painter.height;
    painter.dispose();
    return h <= 0 ? layout.minLineHeight : h;
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

  double _paragraphSpacing(BlockStyle style) {
    final raw = style.margin?.bottom ?? 0.0;
    return raw.clamp(0.0, 6.0);
  }

  double _imageSpacing(BlockStyle style) {
    final raw = style.margin?.bottom ?? 0.0;
    return raw.clamp(0.0, 4.0);
  }

  double _estimateImageHeight({
    required ImageBlock block,
    required double pageWidth,
    required double pageHeight,
  }) {
    final maxImageHeight = math.max(84.0, pageHeight * 0.36);

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
      return targetHeight.clamp(38.0, maxImageHeight).toDouble();
    }
    return (pageHeight * 0.22).clamp(38.0, maxImageHeight).toDouble();
  }

  double _effectivePageHeight({
    required double usableHeight,
    required ReaderStyle style,
  }) {
    final lineGuard = math.max(2.0, style.fontSize * style.lineHeight * 0.10);
    return math.max(80.0, usableHeight - _renderSafetyBottom - lineGuard);
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
    return raw.clamp(1.0, 3.2).toDouble();
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

class _ParagraphLayout {
  final String text;
  final TextPainter painter;
  final TextStyle textStyle;
  final StrutStyle strutStyle;
  final TextAlign textAlign;
  final Locale? locale;
  final double maxWidth;
  final double minLineHeight;
  final List<int> lineEnds;
  final List<double> cumulativeHeights;

  const _ParagraphLayout({
    required this.text,
    required this.painter,
    required this.textStyle,
    required this.strutStyle,
    required this.textAlign,
    required this.locale,
    required this.maxWidth,
    required this.minLineHeight,
    required this.lineEnds,
    required this.cumulativeHeights,
  });
}
