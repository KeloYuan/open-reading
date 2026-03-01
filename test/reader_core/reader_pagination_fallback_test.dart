import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/reader_core/data/reader_models.dart';
import 'package:xxread/reader_core/document/flow_doc.dart';
import 'package:xxread/reader_core/document/html_to_flow_doc.dart';
import 'package:xxread/reader_core/paginator/flow_paginator.dart';
import 'package:xxread/reader_core/paginator/page_plan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FlowPaginator keeps at least one page for empty chapter', () async {
    final paginator = FlowPaginator();
    final plan = await paginator.paginate(
      chapterId: 'chapter-empty',
      flowDoc: const FlowDoc(blocks: []),
      style: const ReaderStyle(),
      layout: const PageLayout(
        usableWidth: 360,
        usableHeight: 640,
        padding: EdgeInsets.zero,
      ),
    );

    expect(plan.pages, isNotEmpty);
    expect(plan.pages.first.startOffset, 0);
    expect(plan.pages.first.endOffset, 0);
  });

  test('HtmlToFlowDocConverter supports SVG image href', () {
    final converter = HtmlToFlowDocConverter();
    final doc = converter.convert(
      '<html><body><svg><image xlink:href="images/cover.jpg" /></svg></body></html>',
    );

    final imageBlocks = doc.blocks.whereType<ImageBlock>().toList();
    expect(imageBlocks, hasLength(1));
    expect(imageBlocks.first.src, 'images/cover.jpg');
  });

  test('HtmlToFlowDocConverter applies simple stylesheet selectors', () {
    final converter = HtmlToFlowDocConverter();
    final doc = converter.convert(
      '<html><body>'
      '<h2 class="title">推荐序</h2>'
      '<p class="lead">这是一段正文。</p>'
      '</body></html>',
      stylesheetText: '.title { color: #3366ff; } .lead { line-height: 180%; }',
    );

    final heading = doc.blocks.whereType<HeadingBlock>().first;
    final paragraph = doc.blocks.whereType<ParagraphBlock>().first;

    expect(heading.level, 2);
    expect(heading.style.fontSizeScale, greaterThan(1.0));
    expect(heading.style.textColor, const Color(0xFF3366FF));
    expect(paragraph.style.lineHeight, closeTo(1.8, 0.01));
  });

  test('HtmlToFlowDocConverter ignores invalid css color values safely', () {
    final converter = HtmlToFlowDocConverter();
    final doc = converter.convert(
      '<html><body>'
      '<p style="color:#zzzzzz;line-height:170%">测试文本</p>'
      '<p style="color:#12x;line-height:1.7">第二段</p>'
      '</body></html>',
    );

    final paragraphs = doc.blocks.whereType<ParagraphBlock>().toList();
    expect(paragraphs.length, 2);
    expect(paragraphs.first.style.textColor, isNull);
    expect(paragraphs.first.style.lineHeight, closeTo(1.7, 0.01));
    expect(paragraphs.last.style.textColor, isNull);
  });

  test('HtmlToFlowDocConverter converts list and blockquote to readable blocks',
      () {
    final converter = HtmlToFlowDocConverter();
    final doc = converter.convert(
      '<html><body>'
      '<ul><li>第一条</li><li>第二条</li></ul>'
      '<blockquote>引用内容</blockquote>'
      '</body></html>',
    );

    final paragraphs = doc.blocks.whereType<ParagraphBlock>().toList();
    expect(paragraphs, isNotEmpty);
    expect(paragraphs.first.plainText.startsWith('• '), isTrue);
    expect(paragraphs.last.style.fontStyle, FontStyle.italic);
  });

  test('FlowPaginator keeps text fragments continuous without gaps', () async {
    final longText = List.filled(
      220,
      '这是用于分页连续性验证的一段中文文本，不应出现漏字或跳字。',
    ).join();
    final flowDoc = FlowDoc(
      blocks: [
        ParagraphBlock(
          id: 'p-1',
          inlines: [TextInline(longText)],
        ),
      ],
    );

    final paginator = FlowPaginator();
    final plan = await paginator.paginate(
      chapterId: 'chapter-continuity',
      flowDoc: flowDoc,
      style: const ReaderStyle(fontSize: 18, lineHeight: 1.7),
      layout: const PageLayout(
        usableWidth: 360,
        usableHeight: 420,
        padding: EdgeInsets.zero,
      ),
    );

    expect(plan.pages.length, greaterThan(1));

    final textFragments = <TextFragment>[];
    for (final page in plan.pages) {
      for (final fragment in page.fragments) {
        if (fragment is TextFragment && fragment.blockId == 'p-1') {
          textFragments.add(fragment);
        }
      }
    }

    expect(textFragments, isNotEmpty);
    expect(textFragments.first.start, 0);
    expect(textFragments.last.end, longText.length);

    for (var i = 1; i < textFragments.length; i++) {
      expect(textFragments[i].start, textFragments[i - 1].end);
      expect(textFragments[i].end, greaterThan(textFragments[i].start));
    }
  });

  test('FlowPaginator keeps mixed punctuation pages within width/height bounds',
      () async {
    const paragraphPiece =
        '“经济学”里常见的“引号”、EnglishWordsAndNumbers123、括号（测试）和——破折号；这一行应稳定换行，不应超出可见区域。';
    final mixedText = List.filled(220, paragraphPiece).join();
    final flowDoc = FlowDoc(
      blocks: [
        ParagraphBlock(
          id: 'p-mixed',
          inlines: [TextInline(mixedText)],
        ),
      ],
    );

    const style = ReaderStyle(
      fontSize: 19,
      lineHeight: 1.72,
      letterSpacing: 0.0,
      textAlign: TextAlign.start,
    );
    const layout = PageLayout(
      usableWidth: 360,
      usableHeight: 640,
      padding: EdgeInsets.zero,
    );

    final paginator = FlowPaginator();
    final plan = await paginator.paginate(
      chapterId: 'chapter-mixed-overflow-guard',
      flowDoc: flowDoc,
      style: style,
      layout: layout,
    );

    expect(plan.pages.length, greaterThan(1));

    final blockMap = <String, Block>{for (final b in flowDoc.blocks) b.id: b};
    final effectivePageHeight = math.max(80.0, layout.usableHeight - 2.0);
    const textHeightBehavior = TextHeightBehavior(
      applyHeightToFirstAscent: true,
      applyHeightToLastDescent: true,
    );

    for (final page in plan.pages) {
      var totalHeight = 0.0;
      for (final fragment in page.fragments) {
        if (fragment is TextFragment) {
          final block = blockMap[fragment.blockId];
          final plainText = switch (block) {
            ParagraphBlock p => p.plainText,
            HeadingBlock h => h.plainText,
            _ => '',
          };
          if (plainText.isEmpty) {
            continue;
          }
          final start = fragment.start.clamp(0, plainText.length);
          final end = fragment.end.clamp(start, plainText.length);
          if (end <= start) {
            continue;
          }
          final text = plainText.substring(start, end);
          final textStyle = style.toTextStyle();
          final strut = StrutStyle(
            fontFamily: textStyle.fontFamily,
            fontSize: textStyle.fontSize ?? style.fontSize,
            fontWeight: textStyle.fontWeight,
            fontStyle: textStyle.fontStyle,
            height: style.lineHeight,
            leading: 0,
            forceStrutHeight: true,
          );
          final painter = TextPainter(
            text: TextSpan(text: text, style: textStyle),
            textDirection: TextDirection.ltr,
            textAlign: style.textAlign,
            locale: style.locale,
            textScaler: TextScaler.noScaling,
            strutStyle: strut,
            textHeightBehavior: textHeightBehavior,
            textWidthBasis: TextWidthBasis.parent,
          )..layout(maxWidth: layout.usableWidth);

          final metrics = painter.computeLineMetrics();
          for (final line in metrics) {
            expect(line.width, lessThanOrEqualTo(layout.usableWidth + 0.001),
                reason: 'page=${page.index} width=${line.width}');
          }

          final measuredHeight = painter.height <= 0
              ? style.fontSize * style.lineHeight
              : painter.height;
          totalHeight += measuredHeight.ceilToDouble();
          painter.dispose();
          continue;
        }
        if (fragment is ImageFragment) {
          totalHeight +=
              (fragment.measuredHeight ?? (effectivePageHeight * 0.24))
                  .ceilToDouble();
          continue;
        }
        if (fragment is SpaceFragment) {
          totalHeight += fragment.height.ceilToDouble();
        }
      }

      expect(
        totalHeight,
        lessThanOrEqualTo(effectivePageHeight + 0.01),
        reason:
            'page=${page.index} totalHeight=$totalHeight pageHeight=$effectivePageHeight',
      );
    }
  });

  test(
      'FlowPaginator force-splits long unbreakable tokens to keep width/height bounds',
      () async {
    const longToken =
        '“ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789”';
    final text = List<String>.generate(
      260,
      (i) => '第${i + 1}行：$longToken 这是超长不可断词回归测试。',
    ).join('\n');
    final flowDoc = FlowDoc(
      blocks: [
        ParagraphBlock(
          id: 'p-unbreakable',
          inlines: [TextInline(text)],
        ),
      ],
    );

    const style = ReaderStyle(
      fontSize: 19,
      lineHeight: 1.72,
      letterSpacing: 0.0,
      textAlign: TextAlign.start,
    );
    const layout = PageLayout(
      usableWidth: 360,
      usableHeight: 640,
      padding: EdgeInsets.zero,
    );

    final paginator = FlowPaginator();
    final plan = await paginator.paginate(
      chapterId: 'chapter-unbreakable-token',
      flowDoc: flowDoc,
      style: style,
      layout: layout,
    );

    expect(plan.pages.length, greaterThan(1));
    final textFragments = <TextFragment>[];
    for (final page in plan.pages) {
      for (final fragment in page.fragments) {
        if (fragment is TextFragment && fragment.blockId == 'p-unbreakable') {
          textFragments.add(fragment);
        }
      }
    }
    expect(textFragments, isNotEmpty);
    expect(textFragments.first.start, 0);
    expect(textFragments.last.end, text.length);
    for (var i = 1; i < textFragments.length; i++) {
      expect(textFragments[i].start, textFragments[i - 1].end);
      expect(textFragments[i].end, greaterThan(textFragments[i].start));
    }

    final blockMap = <String, Block>{for (final b in flowDoc.blocks) b.id: b};
    final effectivePageHeight = math.max(80.0, layout.usableHeight - 2.0);
    const textHeightBehavior = TextHeightBehavior(
      applyHeightToFirstAscent: true,
      applyHeightToLastDescent: true,
    );

    for (final page in plan.pages) {
      var totalHeight = 0.0;
      for (final fragment in page.fragments) {
        if (fragment is TextFragment) {
          final block = blockMap[fragment.blockId];
          final plainText = switch (block) {
            ParagraphBlock p => p.plainText,
            HeadingBlock h => h.plainText,
            _ => '',
          };
          if (plainText.isEmpty) {
            continue;
          }
          final start = fragment.start.clamp(0, plainText.length);
          final end = fragment.end.clamp(start, plainText.length);
          if (end <= start) {
            continue;
          }
          final text = plainText.substring(start, end);
          final textStyle = style.toTextStyle();
          final strut = StrutStyle(
            fontFamily: textStyle.fontFamily,
            fontSize: textStyle.fontSize ?? style.fontSize,
            fontWeight: textStyle.fontWeight,
            fontStyle: textStyle.fontStyle,
            height: style.lineHeight,
            leading: 0,
            forceStrutHeight: true,
          );
          final painter = TextPainter(
            text: TextSpan(text: text, style: textStyle),
            textDirection: TextDirection.ltr,
            textAlign: style.textAlign,
            locale: style.locale,
            textScaler: TextScaler.noScaling,
            strutStyle: strut,
            textHeightBehavior: textHeightBehavior,
            textWidthBasis: TextWidthBasis.parent,
          )..layout(maxWidth: layout.usableWidth);

          final metrics = painter.computeLineMetrics();
          for (final line in metrics) {
            expect(
              line.width,
              lessThanOrEqualTo(layout.usableWidth + 0.001),
              reason: 'page=${page.index} width=${line.width}',
            );
          }

          final measuredHeight = painter.height <= 0
              ? style.fontSize * style.lineHeight
              : painter.height;
          totalHeight += measuredHeight.ceilToDouble();
          painter.dispose();
          continue;
        }
        if (fragment is ImageFragment) {
          totalHeight +=
              (fragment.measuredHeight ?? (effectivePageHeight * 0.24))
                  .ceilToDouble();
          continue;
        }
        if (fragment is SpaceFragment) {
          totalHeight += fragment.height.ceilToDouble();
        }
      }

      expect(
        totalHeight,
        lessThanOrEqualTo(effectivePageHeight + 0.01),
        reason:
            'page=${page.index} totalHeight=$totalHeight pageHeight=$effectivePageHeight',
      );
    }
  });

  test(
      'FlowPaginator keeps newline-heavy TXT pages within height bounds after render normalization',
      () async {
    final lines = List<String>.generate(
      900,
      (i) => '第${i + 1}行：这是用于验证TXT换行分页稳定性的文本，避免行尾换行导致页面溢出。',
    );
    final text = lines.join('\n');
    final flowDoc = FlowDoc(
      blocks: [
        ParagraphBlock(
          id: 'p-newline-heavy',
          inlines: [TextInline(text)],
        ),
      ],
    );

    const style = ReaderStyle(
      fontSize: 19,
      lineHeight: 1.72,
      letterSpacing: 0.0,
      textAlign: TextAlign.start,
    );
    const layout = PageLayout(
      usableWidth: 360,
      usableHeight: 640,
      padding: EdgeInsets.zero,
    );

    final paginator = FlowPaginator();
    final plan = await paginator.paginate(
      chapterId: 'chapter-newline-heavy',
      flowDoc: flowDoc,
      style: style,
      layout: layout,
    );

    expect(plan.pages.length, greaterThan(1));
    final blockMap = <String, Block>{for (final b in flowDoc.blocks) b.id: b};
    final effectivePageHeight = math.max(80.0, layout.usableHeight - 2.0);
    const textHeightBehavior = TextHeightBehavior(
      applyHeightToFirstAscent: true,
      applyHeightToLastDescent: true,
    );

    for (final page in plan.pages) {
      var totalHeight = 0.0;
      for (final fragment in page.fragments) {
        if (fragment is TextFragment) {
          final block = blockMap[fragment.blockId];
          final plainText = switch (block) {
            ParagraphBlock p => p.plainText,
            HeadingBlock h => h.plainText,
            _ => '',
          };
          if (plainText.isEmpty) {
            continue;
          }
          final start = fragment.start.clamp(0, plainText.length);
          final end = fragment.end.clamp(start, plainText.length);
          if (end <= start) {
            continue;
          }
          final raw = plainText.substring(start, end);
          final normalized = _normalizeFragmentTextForRenderTest(raw);
          if (normalized.isEmpty) {
            totalHeight +=
                (fragment.measuredHeight ?? (style.fontSize * style.lineHeight))
                    .ceilToDouble();
            continue;
          }
          final textStyle = style.toTextStyle();
          final strut = StrutStyle(
            fontFamily: textStyle.fontFamily,
            fontSize: textStyle.fontSize ?? style.fontSize,
            fontWeight: textStyle.fontWeight,
            fontStyle: textStyle.fontStyle,
            height: style.lineHeight,
            leading: 0,
            forceStrutHeight: true,
          );
          final painter = TextPainter(
            text: TextSpan(text: normalized, style: textStyle),
            textDirection: TextDirection.ltr,
            textAlign: style.textAlign,
            locale: style.locale,
            textScaler: TextScaler.noScaling,
            strutStyle: strut,
            textHeightBehavior: textHeightBehavior,
            textWidthBasis: TextWidthBasis.parent,
          )..layout(maxWidth: layout.usableWidth);

          final measuredHeight = painter.height <= 0
              ? style.fontSize * style.lineHeight
              : painter.height;
          totalHeight += measuredHeight.ceilToDouble();
          painter.dispose();
          continue;
        }
        if (fragment is ImageFragment) {
          totalHeight +=
              (fragment.measuredHeight ?? (effectivePageHeight * 0.24))
                  .ceilToDouble();
          continue;
        }
        if (fragment is SpaceFragment) {
          totalHeight += fragment.height.ceilToDouble();
        }
      }

      expect(
        totalHeight,
        lessThanOrEqualTo(effectivePageHeight + 0.01),
        reason:
            'page=${page.index} totalHeight=$totalHeight pageHeight=$effectivePageHeight',
      );
    }
  });

  test(
      'FlowPaginator keeps newline-rich TXT non-final pages reasonably filled across font sizes',
      () async {
    final text = List<String>.generate(
      1200,
      (i) => '第${i + 1}行：这是用于分页空间利用率回归的测试文本。',
    ).join('\n');
    final flowDoc = FlowDoc(
      blocks: [
        ParagraphBlock(
          id: 'p-fill-ratio',
          inlines: [TextInline(text)],
        ),
      ],
    );

    const layout = PageLayout(
      usableWidth: 360,
      usableHeight: 640,
      padding: EdgeInsets.zero,
    );
    const textHeightBehavior = TextHeightBehavior(
      applyHeightToFirstAscent: true,
      applyHeightToLastDescent: true,
    );
    final blockMap = <String, Block>{for (final b in flowDoc.blocks) b.id: b};
    final effectivePageHeight = math.max(80.0, layout.usableHeight - 2.0);
    final paginator = FlowPaginator();

    for (final fontSize in <double>[16, 22, 28]) {
      final style = ReaderStyle(
        fontSize: fontSize,
        lineHeight: 1.72,
        letterSpacing: 0.0,
        textAlign: TextAlign.start,
      );
      final plan = await paginator.paginate(
        chapterId: 'chapter-fill-ratio-$fontSize',
        flowDoc: flowDoc,
        style: style,
        layout: layout,
      );
      expect(plan.pages.length, greaterThan(1), reason: 'font=$fontSize');

      for (var i = 0; i < plan.pages.length - 1; i++) {
        final page = plan.pages[i];
        var totalHeight = 0.0;
        for (final fragment in page.fragments) {
          if (fragment is TextFragment) {
            final block = blockMap[fragment.blockId];
            final plainText = switch (block) {
              ParagraphBlock p => p.plainText,
              HeadingBlock h => h.plainText,
              _ => '',
            };
            if (plainText.isEmpty) {
              continue;
            }
            final start = fragment.start.clamp(0, plainText.length);
            final end = fragment.end.clamp(start, plainText.length);
            if (end <= start) {
              continue;
            }
            final raw = plainText.substring(start, end);
            final normalized = _normalizeFragmentTextForRenderTest(raw);
            if (normalized.isEmpty) {
              continue;
            }
            final textStyle = style.toTextStyle();
            final strut = StrutStyle(
              fontFamily: textStyle.fontFamily,
              fontSize: textStyle.fontSize ?? style.fontSize,
              fontWeight: textStyle.fontWeight,
              fontStyle: textStyle.fontStyle,
              height: style.lineHeight,
              leading: 0,
              forceStrutHeight: true,
            );
            final painter = TextPainter(
              text: TextSpan(text: normalized, style: textStyle),
              textDirection: TextDirection.ltr,
              textAlign: style.textAlign,
              locale: style.locale,
              textScaler: TextScaler.noScaling,
              strutStyle: strut,
              textHeightBehavior: textHeightBehavior,
              textWidthBasis: TextWidthBasis.parent,
            )..layout(maxWidth: layout.usableWidth);
            final measuredHeight = painter.height <= 0
                ? style.fontSize * style.lineHeight
                : painter.height;
            totalHeight += measuredHeight.ceilToDouble();
            painter.dispose();
            continue;
          }
          if (fragment is SpaceFragment) {
            totalHeight += fragment.height.ceilToDouble();
          }
        }

        final fillRatio = totalHeight / effectivePageHeight;
        expect(
          fillRatio,
          greaterThan(0.55),
          reason:
              'font=$fontSize page=${page.index} fillRatio=${fillRatio.toStringAsFixed(3)}',
        );
      }
    }
  });

  test('FlowPaginator avoids tiny trailing line on non-terminal fragments',
      () async {
    const token =
        '“ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789”';
    final text = List<String>.filled(480, token).join();
    final flowDoc = FlowDoc(
      blocks: [
        ParagraphBlock(
          id: 'p-tiny-tail-guard',
          inlines: [TextInline(text)],
        ),
      ],
    );

    const style = ReaderStyle(
      fontSize: 19,
      lineHeight: 1.72,
      letterSpacing: 0.0,
      textAlign: TextAlign.start,
    );
    const layout = PageLayout(
      usableWidth: 336,
      usableHeight: 640,
      padding: EdgeInsets.zero,
    );

    final paginator = FlowPaginator();
    final plan = await paginator.paginate(
      chapterId: 'chapter-tiny-tail-guard',
      flowDoc: flowDoc,
      style: style,
      layout: layout,
    );

    expect(plan.pages.length, greaterThan(1));

    final textStyle = style.toTextStyle();
    final strut = StrutStyle(
      fontFamily: textStyle.fontFamily,
      fontSize: textStyle.fontSize ?? style.fontSize,
      fontWeight: textStyle.fontWeight,
      fontStyle: textStyle.fontStyle,
      height: style.lineHeight,
      leading: 0,
      forceStrutHeight: true,
    );
    final textWidth = math.max(24.0, layout.usableWidth - 2.0);

    var checkedFragments = 0;
    for (final page in plan.pages) {
      for (final fragment in page.fragments) {
        if (fragment is! TextFragment ||
            fragment.blockId != 'p-tiny-tail-guard') {
          continue;
        }
        if (fragment.end >= text.length) {
          // 段末尾可自然收束，不做短尾行限制。
          continue;
        }
        final start = fragment.start.clamp(0, text.length);
        final end = fragment.end.clamp(start, text.length);
        if (end <= start) {
          continue;
        }
        final raw = text.substring(start, end);
        final normalized = _normalizeFragmentTextForRenderTest(raw);
        if (normalized.isEmpty) {
          continue;
        }

        final ranges = _measureLineRangesForTest(
          text: normalized,
          style: textStyle,
          strutStyle: strut,
          textAlign: style.textAlign,
          locale: style.locale,
          maxWidth: textWidth,
        );
        if (ranges.length <= 1) {
          continue;
        }
        checkedFragments += 1;
        final lastLine = ranges.last;
        final lastLineChars = lastLine.end - lastLine.start;
        expect(
          lastLineChars,
          greaterThan(2),
          reason:
              'page=${page.index} fragment=${fragment.start}-${fragment.end} '
              'lastLineChars=$lastLineChars',
        );
      }
    }

    expect(checkedFragments, greaterThan(0));
  });
}

String _normalizeFragmentTextForRenderTest(String raw) {
  if (raw.isEmpty) {
    return raw;
  }
  final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  int end = normalized.length;
  while (end > 0 && normalized.codeUnitAt(end - 1) == 0x0A) {
    end -= 1;
  }
  if (end <= 0) {
    return '';
  }
  if (end == normalized.length) {
    return normalized;
  }
  return normalized.substring(0, end);
}

List<_TestLineRange> _measureLineRangesForTest({
  required String text,
  required TextStyle style,
  required StrutStyle strutStyle,
  required TextAlign textAlign,
  required Locale? locale,
  required double maxWidth,
}) {
  if (text.isEmpty) {
    return const <_TestLineRange>[];
  }
  const eps = 0.05;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: textAlign,
    locale: locale,
    textScaler: TextScaler.noScaling,
    strutStyle: strutStyle,
    textHeightBehavior: const TextHeightBehavior(
      applyHeightToFirstAscent: true,
      applyHeightToLastDescent: true,
    ),
    textWidthBasis: TextWidthBasis.parent,
  )..layout(maxWidth: maxWidth);

  final ranges = <_TestLineRange>[];
  final metrics = painter.computeLineMetrics();
  if (metrics.isEmpty) {
    ranges.add(_TestLineRange(start: 0, end: text.length));
    painter.dispose();
    return ranges;
  }

  var cursor = 0;
  const startProbeX = 0.0;
  final endProbeX = math.max(0.0, maxWidth - eps);
  for (final metric in metrics) {
    if (cursor >= text.length) {
      break;
    }
    final metricHeight =
        metric.height <= 0 ? painter.preferredLineHeight : metric.height;
    final lineTop = metric.baseline - metric.ascent;
    final probeY = (lineTop + metricHeight / 2)
        .clamp(0.0, math.max(0.0, painter.height - eps))
        .toDouble();
    final startProbe =
        painter.getPositionForOffset(Offset(startProbeX, probeY));
    final startBoundary = painter.getLineBoundary(startProbe);
    var start = startBoundary.start.clamp(0, text.length).toInt();
    if (start != cursor) {
      start = cursor;
    }
    final endProbe = painter.getPositionForOffset(Offset(endProbeX, probeY));
    final endBoundary = painter.getLineBoundary(endProbe);
    var end = math
        .max(startBoundary.end, endBoundary.end)
        .clamp(start, text.length)
        .toInt();
    if (end <= start) {
      end = math.min(text.length, start + 1).toInt();
    }
    ranges.add(_TestLineRange(start: start, end: end));
    cursor = end;
  }
  if (cursor < text.length) {
    ranges.add(_TestLineRange(start: cursor, end: text.length));
  }
  painter.dispose();
  return ranges;
}

class _TestLineRange {
  final int start;
  final int end;

  const _TestLineRange({
    required this.start,
    required this.end,
  });
}
