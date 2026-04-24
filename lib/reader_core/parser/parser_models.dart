// 文件说明：阅读解析阶段的通用模型与解析器接口定义。
// 技术要点：ReaderCore。

import 'dart:typed_data';

import '../data/reader_models.dart';
import '../document/flow_doc.dart';

class ParsedChapter {
  final Chapter chapter;
  final FlowDoc flowDoc;
  final String? htmlContent;
  final Map<String, Uint8List> resources;

  const ParsedChapter({
    required this.chapter,
    required this.flowDoc,
    this.htmlContent,
    this.resources = const {},
  });
}

class ParsedBook {
  final Book book;
  final List<TocItem> toc;
  final List<ParsedChapter> chapters;

  const ParsedBook({
    required this.book,
    required this.toc,
    required this.chapters,
  });
}

abstract class BookParser {
  Future<ParsedBook> parse({
    required String bookId,
    required String title,
    required String author,
    required String filePath,
    String? encodingOverride,
  });
}
