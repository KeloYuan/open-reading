import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/reader_core/data/reader_models.dart';
import 'package:xxread/reader_core/document/flow_doc.dart';
import 'package:xxread/reader_core/document/html_to_flow_doc.dart';
import 'package:xxread/reader_core/paginator/flow_paginator.dart';

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
}
