// 文件说明：纯文本解析桥接层，为 TXT/RTF/FB2 等文本格式提供统一入口。
// 技术要点：ReaderCore、文件系统。

import 'dart:io';

import '../data/reader_models.dart';
import 'parser_models.dart';
import 'txt_parser.dart';

class TextParserBridge {
  static final TxtParser _txtParser = TxtParser();

  static Future<ParsedBook> parsePlainText({
    required String bookId,
    required String title,
    required String author,
    required String filePath,
    required String format,
    required String text,
  }) async {
    if (text.trim().isEmpty) {
      throw const FormatException('未提取到可阅读文本内容。');
    }

    final tempPath =
        '${Directory.systemTemp.path}/$bookId-${DateTime.now().microsecondsSinceEpoch}-$format.txt';
    final tempFile = File(tempPath);

    try {
      await tempFile.writeAsString(text);
      final parsed = await _txtParser.parse(
        bookId: bookId,
        title: title,
        author: author,
        filePath: tempPath,
        encodingOverride: 'utf8',
      );

      return ParsedBook(
        book: Book(
          id: parsed.book.id,
          title: parsed.book.title,
          author: parsed.book.author,
          filePath: filePath,
          format: format,
        ),
        toc: parsed.toc,
        chapters: parsed.chapters,
      );
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }
}
