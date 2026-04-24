// 文件说明：DOCX 解析器，把 Word 文档转换成阅读内核可消费的章节数据。
// 技术要点：ReaderCore、Archive ZIP、JSON、文件系统。

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import 'parser_models.dart';
import 'text_parser_bridge.dart';

class DocxParser implements BookParser {
  @override
  Future<ParsedBook> parse({
    required String bookId,
    required String title,
    required String author,
    required String filePath,
    String? encodingOverride,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    final plainText = _extractPlainText(bytes);
    if (plainText.trim().isEmpty) {
      throw const FormatException('DOCX 解析失败：未提取到可阅读文本。');
    }

    return TextParserBridge.parsePlainText(
      bookId: bookId,
      title: title,
      author: author,
      filePath: filePath,
      format: 'docx',
      text: plainText,
    );
  }

  String _extractPlainText(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    ArchiveFile? documentFile;

    for (final file in archive.files) {
      if (file.name == 'word/document.xml') {
        documentFile = file;
        break;
      }
    }

    if (documentFile == null || !documentFile.isFile) {
      throw const FormatException('DOCX 内容缺失：word/document.xml 不存在。');
    }

    final xml = utf8.decode(
      (documentFile.content as List<int>),
      allowMalformed: true,
    );

    final paragraphs = RegExp(
      r'<w:p\b[^>]*>([\s\S]*?)</w:p>',
      caseSensitive: false,
    ).allMatches(xml);

    final buffer = StringBuffer();
    if (paragraphs.isNotEmpty) {
      for (final paragraph in paragraphs) {
        final segment = paragraph.group(1) ?? '';
        final texts = RegExp(
          r'<w:t\b[^>]*>([\s\S]*?)</w:t>',
          caseSensitive: false,
        ).allMatches(segment);
        for (final item in texts) {
          buffer.write(_decodeXmlEntities(item.group(1) ?? ''));
        }
        buffer.writeln();
      }
    } else {
      final texts = RegExp(
        r'<w:t\b[^>]*>([\s\S]*?)</w:t>',
        caseSensitive: false,
      ).allMatches(xml);
      for (final item in texts) {
        buffer.writeln(_decodeXmlEntities(item.group(1) ?? ''));
      }
    }

    final plain = buffer
        .toString()
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return plain;
  }

  String _decodeXmlEntities(String input) {
    var text = input;
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&apos;', '\'');
    text = text.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
      final value = int.tryParse(match.group(1)!, radix: 16);
      if (value == null) return '';
      return String.fromCharCode(value);
    });
    text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final value = int.tryParse(match.group(1)!);
      if (value == null) return '';
      return String.fromCharCode(value);
    });
    return text;
  }
}
