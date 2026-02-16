import 'dart:convert';
import 'dart:io';

import 'parser_models.dart';
import 'text_parser_bridge.dart';

class Fb2Parser implements BookParser {
  @override
  Future<ParsedBook> parse({
    required String bookId,
    required String title,
    required String author,
    required String filePath,
    String? encodingOverride,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    final xml = _decodeXml(bytes);
    final plainText = _extractReadableText(xml);
    if (plainText.trim().isEmpty) {
      throw const FormatException('FB2 解析失败：未提取到可阅读文本。');
    }

    return TextParserBridge.parsePlainText(
      bookId: bookId,
      title: title,
      author: author,
      filePath: filePath,
      format: 'fb2',
      text: plainText,
    );
  }

  String _decodeXml(List<int> bytes) {
    final utf8Text = utf8.decode(bytes, allowMalformed: true);
    if (utf8Text.contains('<FictionBook') || utf8Text.contains('<?xml')) {
      return utf8Text;
    }
    return latin1.decode(bytes, allowInvalid: true);
  }

  String _extractReadableText(String xml) {
    final bodies = RegExp(
      r'<body[^>]*>([\s\S]*?)</body>',
      caseSensitive: false,
    ).allMatches(xml).map((m) => m.group(1) ?? '').join('\n\n');
    var text = bodies.isEmpty ? xml : bodies;

    text = text.replaceAll(
        RegExp(r'<empty-line\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'</section>', caseSensitive: false), '\n\n');
    text =
        text.replaceAll(RegExp(r'<section[^>]*>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</title>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<title[^>]*>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</subtitle>', caseSensitive: false), '\n');
    text =
        text.replaceAll(RegExp(r'<subtitle[^>]*>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');

    text = _decodeXmlEntities(text);
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    return text.trim();
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
