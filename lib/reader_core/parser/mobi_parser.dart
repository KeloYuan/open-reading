import 'dart:convert';
import 'dart:io';

import 'parser_models.dart';
import 'txt_parser.dart';

class MobiParser implements BookParser {
  final TxtParser _txtParser = TxtParser();

  @override
  Future<ParsedBook> parse({
    required String bookId,
    required String title,
    required String author,
    required String filePath,
    String? encodingOverride,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    if (_looksLikeDrmProtected(bytes)) {
      throw UnsupportedError('检测到 DRM 保护，当前仅支持无 DRM 的 MOBI/AZW3 文件。');
    }

    // Stage 3 note:
    // Replace this fallback extractor with package:dart_mobi parser when wired in.
    final extractedText = _extractReadableText(bytes);
    if (extractedText.trim().isEmpty) {
      throw FormatException('MOBI/AZW3 解析失败：未提取到可阅读文本。');
    }

    final tmpPath = '${Directory.systemTemp.path}/$bookId-mobi.txt';
    final tmpFile = File(tmpPath);
    await tmpFile.writeAsString(extractedText);

    final parsed = await _txtParser.parse(
      bookId: bookId,
      title: title,
      author: author,
      filePath: tmpPath,
    );

    if (await tmpFile.exists()) {
      await tmpFile.delete();
    }

    return ParsedBook(
      book: parsed.book,
      toc: parsed.toc,
      chapters: parsed.chapters,
    );
  }

  bool _looksLikeDrmProtected(List<int> bytes) {
    final probe = utf8
        .decode(bytes.take(4096).toList(), allowMalformed: true)
        .toLowerCase();
    if (probe.contains('drm')) return true;

    if (bytes.length > 80) {
      final header = ascii.decode(bytes.sublist(60, 68), allowInvalid: true);
      if (!header.contains('BOOKMOBI') && !header.contains('TEXtREAd')) {
        return false;
      }
      // PalmDOC encryption type often appears in this area in many files.
      final encryptionType = (bytes[12] << 8) + bytes[13];
      if (encryptionType != 0) {
        return true;
      }
    }
    return false;
  }

  String _extractReadableText(List<int> bytes) {
    var text = utf8.decode(bytes, allowMalformed: true);
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = text.replaceAll(RegExp(r'\x00+'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    final keep = StringBuffer();
    for (final rune in text.runes) {
      final isAscii = rune >= 32 && rune <= 126;
      final isCjk = rune >= 0x4e00 && rune <= 0x9fff;
      final isPunct = rune == 10 || rune == 13 || rune == 9;
      if (isAscii || isCjk || isPunct) {
        keep.writeCharCode(rune);
      }
    }

    return keep.toString();
  }
}
