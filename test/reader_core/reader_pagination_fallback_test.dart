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
}
