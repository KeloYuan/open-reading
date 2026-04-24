// 文件说明：RTF 解析器，用于提取富文本内容并桥接到阅读模型。
// 技术要点：ReaderCore、JSON、文件系统。

import 'dart:convert';
import 'dart:io';

import 'parser_models.dart';
import 'text_parser_bridge.dart';

class RtfParser implements BookParser {
  @override
  Future<ParsedBook> parse({
    required String bookId,
    required String title,
    required String author,
    required String filePath,
    String? encodingOverride,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    final raw = latin1.decode(bytes, allowInvalid: true);
    final plainText = _extractPlainText(raw);
    if (plainText.trim().isEmpty) {
      throw const FormatException('RTF 解析失败：未提取到可阅读文本。');
    }

    return TextParserBridge.parsePlainText(
      bookId: bookId,
      title: title,
      author: author,
      filePath: filePath,
      format: 'rtf',
      text: plainText,
    );
  }

  String _extractPlainText(String raw) {
    var text = raw;

    // RTF unicode escape: \uN? where N can be negative.
    text = text.replaceAllMapped(RegExp(r'\\u(-?\d+)\??'), (match) {
      final value = int.tryParse(match.group(1) ?? '');
      if (value == null) {
        return '';
      }
      final codePoint = value < 0 ? value + 65536 : value;
      return String.fromCharCode(codePoint);
    });

    // RTF hex escape: \'hh
    text = text.replaceAllMapped(RegExp(r"\\'([0-9a-fA-F]{2})"), (match) {
      final value = int.tryParse(match.group(1) ?? '', radix: 16);
      if (value == null) {
        return '';
      }
      return String.fromCharCode(value);
    });

    text = text.replaceAll(RegExp(r'\\par[d]?'), '\n');
    text = text.replaceAll(RegExp(r'\\line'), '\n');
    text = text.replaceAll(RegExp(r'\\tab'), '\t');

    // Remove remaining control words and group markers.
    text = text.replaceAll(RegExp(r'\\[a-zA-Z]+-?\d* ?'), ' ');
    text = text.replaceAll(RegExp(r'[{}]'), ' ');
    text = text.replaceAll(RegExp(r'\\[^a-zA-Z]'), ' ');

    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    return text.trim();
  }
}
