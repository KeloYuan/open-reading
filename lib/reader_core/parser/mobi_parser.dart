// 文件说明：MOBI 解析器，负责读取元数据和文本内容并输出统一结构。
// 技术要点：ReaderCore、JSON、文件系统。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'parser_models.dart';
import 'text_parser_bridge.dart';

class MobiParser implements BookParser {
  @override
  Future<ParsedBook> parse({
    required String bookId,
    required String title,
    required String author,
    required String filePath,
    String? encodingOverride,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    final records = _parsePalmDatabaseRecords(bytes);
    if (_looksLikeDrmProtected(records, bytes)) {
      throw UnsupportedError('检测到 DRM 保护，当前仅支持无 DRM 的 MOBI/AZW3 文件。');
    }

    final header = _parseHeaderInfo(
      records?.isNotEmpty == true ? records!.first : null,
      fallbackTitle: title,
      fallbackAuthor: author,
    );
    final extractedText = _extractReadableText(records, bytes, header);
    if (extractedText.trim().isEmpty) {
      throw const FormatException('MOBI/AZW3 解析失败：未提取到可阅读文本。');
    }

    final parsedFormat = _detectFormat(filePath);
    final parsed = await TextParserBridge.parsePlainText(
      bookId: bookId,
      title: header.title,
      author: header.author,
      filePath: filePath,
      format: parsedFormat,
      text: extractedText,
    );
    return parsed;
  }

  String _detectFormat(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.azw3')) {
      return 'azw3';
    }
    if (lower.endsWith('.azw')) {
      return 'azw';
    }
    return 'mobi';
  }

  bool _looksLikeDrmProtected(List<Uint8List>? records, Uint8List rawBytes) {
    if (records != null && records.isNotEmpty) {
      if (records.first.length < 14) {
        return false;
      }
      // PalmDOC encryption field lives at record-0 offset 12/13.
      // For valid MOBI/AZW3 this is the authoritative DRM signal.
      final encryptionType = _readUInt16(records.first, 12);
      return encryptionType != 0;
    }

    // Fallback path for malformed files where records cannot be parsed.
    if (rawBytes.length > 80) {
      final header = ascii.decode(rawBytes.sublist(60, 68), allowInvalid: true);
      if (!header.contains('BOOKMOBI') && !header.contains('TEXtREAd')) {
        return false;
      }
      final encryptionType = (rawBytes[12] << 8) + rawBytes[13];
      if (encryptionType != 0) {
        return true;
      }
    }
    return false;
  }

  String _extractReadableText(
    List<Uint8List>? records,
    Uint8List rawBytes,
    _MobiHeaderInfo header,
  ) {
    if (records == null || records.length < 2) {
      return _extractReadableTextFallback(rawBytes);
    }

    final headerRecord = records.first;
    if (headerRecord.length < 32) {
      return _extractReadableTextFallback(rawBytes);
    }

    final compression = _readUInt16(headerRecord, 0);
    final numTextRecords = _readUInt16(headerRecord, 8);
    final mobiMagic = _safeAscii(headerRecord, 16, 4);
    final hasMobiHeader = mobiMagic == 'MOBI';

    int textEncoding = header.textEncoding;
    int trailingFlags = header.trailingFlags;
    if (!hasMobiHeader) {
      textEncoding = 65001;
      trailingFlags = 0;
    }

    final textRecordCount = numTextRecords.clamp(1, records.length - 1);
    final bytesBuffer = BytesBuilder(copy: false);
    for (int i = 1; i <= textRecordCount; i++) {
      if (i >= records.length) {
        break;
      }
      final raw = records[i];
      if (raw.isEmpty) {
        continue;
      }
      final trimmed = _trimTrailingDataEntries(raw, trailingFlags);
      if (trimmed.isEmpty) {
        continue;
      }
      final decodedRecord = _decodeRecordBytes(trimmed, compression);
      if (decodedRecord.isNotEmpty) {
        bytesBuffer.add(decodedRecord);
      }
    }

    final merged = bytesBuffer.takeBytes();
    if (merged.isEmpty) {
      return _extractReadableTextFallback(rawBytes);
    }

    final decoded = _decodeTextByEncoding(merged, textEncoding);
    final normalized = _normalizeExtractedText(decoded);
    if (normalized.length >= 80) {
      return normalized;
    }
    return _extractReadableTextFallback(rawBytes);
  }

  Uint8List _decodeRecordBytes(Uint8List record, int compression) {
    if (compression == 1) {
      return record;
    }
    if (compression == 2) {
      return _decompressPalmDoc(record);
    }
    return record;
  }

  Uint8List _decompressPalmDoc(Uint8List input) {
    final out = <int>[];
    int i = 0;
    while (i < input.length) {
      final byte = input[i];
      i += 1;

      if (byte == 0) {
        out.add(0);
        continue;
      }
      if (byte <= 8) {
        final nextEnd = (i + byte).clamp(0, input.length);
        if (nextEnd > i) {
          out.addAll(input.sublist(i, nextEnd));
        }
        i = nextEnd;
        continue;
      }
      if (byte <= 0x7f) {
        out.add(byte);
        continue;
      }
      if (byte <= 0xbf) {
        if (i >= input.length) {
          break;
        }
        final bytes = (byte << 8) | input[i];
        i += 1;

        final distance = (bytes & 0x3fff) >> 3;
        final length = (bytes & 0x7) + 3;
        if (distance <= 0) {
          continue;
        }
        for (int j = 0; j < length; j++) {
          final index = out.length - distance;
          if (index < 0 || index >= out.length) {
            break;
          }
          out.add(out[index]);
        }
        continue;
      }
      out.add(32);
      out.add(byte ^ 0x80);
    }
    return Uint8List.fromList(out);
  }

  String _decodeTextByEncoding(Uint8List bytes, int encoding) {
    if (encoding == 65001) {
      return utf8.decode(bytes, allowMalformed: true);
    }
    if (encoding == 1252) {
      return latin1.decode(bytes, allowInvalid: true);
    }
    final utf = utf8.decode(bytes, allowMalformed: true);
    if (_looksLikeReadableText(utf)) {
      return utf;
    }
    return latin1.decode(bytes, allowInvalid: true);
  }

  Uint8List _trimTrailingDataEntries(Uint8List record, int trailingFlags) {
    if (trailingFlags == 0 || record.isEmpty) {
      return record;
    }
    int trim = 0;

    final multiByte = trailingFlags & 0x1;
    final flags = trailingFlags >> 1;
    for (int bit = 0; bit < 15; bit++) {
      if ((flags & (1 << bit)) != 0) {
        final value = _varLenFromEnd(record, trim);
        if (value <= 0) {
          continue;
        }
        trim += value;
      }
    }

    if (multiByte != 0 && trim < record.length) {
      final index = record.length - 1 - trim;
      if (index >= 0) {
        trim += (record[index] & 0x3) + 1;
      }
    }

    final end = (record.length - trim).clamp(0, record.length);
    return Uint8List.sublistView(record, 0, end);
  }

  int _varLenFromEnd(Uint8List data, int fromEndOffset) {
    final usableEnd = data.length - fromEndOffset;
    if (usableEnd <= 0) {
      return 0;
    }
    final start = (usableEnd - 4).clamp(0, usableEnd);
    int value = 0;
    for (int i = start; i < usableEnd; i++) {
      final byte = data[i];
      if ((byte & 0x80) != 0) {
        value = 0;
      }
      value = (value << 7) | (byte & 0x7f);
    }
    return value;
  }

  String _normalizeExtractedText(String text) {
    var content = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (RegExp(r'<\s*(html|body|p|div|h\d|br)', caseSensitive: false)
        .hasMatch(content)) {
      content = content.replaceAll(
        RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false),
        '\n',
      );
      content = content.replaceAll(
        RegExp(
          r'</\s*(p|div|h[1-6]|li|tr|section|article)\s*>',
          caseSensitive: false,
        ),
        '\n',
      );
      content = content.replaceAll(RegExp(r'<[^>]+>'), ' ');
    }

    content = _decodeHtmlEntities(content);
    final cleaned = StringBuffer();
    for (final rune in content.runes) {
      final isControl = rune < 32 && rune != 9 && rune != 10 && rune != 13;
      if (isControl) {
        continue;
      }
      if (rune == 0xfffd) {
        continue;
      }
      cleaned.writeCharCode(rune);
    }
    content = cleaned.toString();
    content = content.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    content = content.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    content = content.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    return content.trim();
  }

  String _decodeHtmlEntities(String input) {
    var text = input;
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&apos;', '\'');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
      final value = int.tryParse(match.group(1)!, radix: 16);
      if (value == null) {
        return '';
      }
      return String.fromCharCode(value);
    });
    text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final value = int.tryParse(match.group(1)!);
      if (value == null) {
        return '';
      }
      return String.fromCharCode(value);
    });
    return text;
  }

  bool _looksLikeReadableText(String text) {
    if (text.isEmpty) {
      return false;
    }
    final sample = text.length > 8000 ? text.substring(0, 8000) : text;
    int total = 0;
    int control = 0;
    for (final rune in sample.runes) {
      total += 1;
      if (rune < 32 && rune != 9 && rune != 10 && rune != 13) {
        control += 1;
      }
    }
    if (total == 0) {
      return false;
    }
    return (control / total) < 0.03;
  }

  String _extractReadableTextFallback(Uint8List bytes) {
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

  _MobiHeaderInfo _parseHeaderInfo(
    Uint8List? headerRecord, {
    required String fallbackTitle,
    required String fallbackAuthor,
  }) {
    var title = fallbackTitle;
    var author = fallbackAuthor;
    var textEncoding = 65001;
    var trailingFlags = 0;

    if (headerRecord == null || headerRecord.length < 32) {
      return _MobiHeaderInfo(
        title: title,
        author: author,
        textEncoding: textEncoding,
        trailingFlags: trailingFlags,
      );
    }

    if (_safeAscii(headerRecord, 16, 4) != 'MOBI') {
      return _MobiHeaderInfo(
        title: title,
        author: author,
        textEncoding: textEncoding,
        trailingFlags: trailingFlags,
      );
    }

    textEncoding = _readUInt32(headerRecord, 28);
    if (textEncoding == 0 || textEncoding == 0xffffffff) {
      textEncoding = 65001;
    }

    trailingFlags = _readUInt32(headerRecord, 240);
    if (trailingFlags == 0xffffffff) {
      trailingFlags = 0;
    }

    final titleOffset = _readUInt32(headerRecord, 84);
    final titleLength = _readUInt32(headerRecord, 88);
    final titleEnd = titleOffset + titleLength;
    if (titleOffset > 0 &&
        titleLength > 0 &&
        titleEnd > titleOffset &&
        titleEnd <= headerRecord.length) {
      final titleBytes =
          Uint8List.sublistView(headerRecord, titleOffset, titleEnd);
      final decoded = _normalizeMetadataText(
        _decodeTextByEncoding(titleBytes, textEncoding),
      );
      if (decoded.isNotEmpty) {
        title = decoded;
      }
    }

    final mobiHeaderLength = _readUInt32(headerRecord, 20);
    final exthStart = 16 + mobiHeaderLength;
    if (exthStart + 12 <= headerRecord.length &&
        _safeAscii(headerRecord, exthStart, 4) == 'EXTH') {
      final exthLength = _readUInt32(headerRecord, exthStart + 4);
      final exthCount = _readUInt32(headerRecord, exthStart + 8);
      final exthEnd = exthStart + exthLength;
      if (exthLength >= 12 && exthEnd <= headerRecord.length) {
        var pos = exthStart + 12;
        for (int i = 0; i < exthCount; i++) {
          if (pos + 8 > exthEnd) {
            break;
          }
          final type = _readUInt32(headerRecord, pos);
          final length = _readUInt32(headerRecord, pos + 4);
          if (length < 8 || pos + length > exthEnd) {
            break;
          }
          final value =
              Uint8List.sublistView(headerRecord, pos + 8, pos + length);
          if (type == 503) {
            final decoded = _normalizeMetadataText(
                _decodeTextByEncoding(value, textEncoding));
            if (decoded.isNotEmpty) {
              title = decoded;
            }
          } else if (type == 100) {
            final decoded = _normalizeMetadataText(
                _decodeTextByEncoding(value, textEncoding));
            if (decoded.isNotEmpty) {
              author = decoded;
            }
          }
          pos += length;
        }
      }
    }

    return _MobiHeaderInfo(
      title: title,
      author: author,
      textEncoding: textEncoding,
      trailingFlags: trailingFlags,
    );
  }

  String _normalizeMetadataText(String input) {
    return input
        .replaceAll('\x00', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<Uint8List>? _parsePalmDatabaseRecords(Uint8List bytes) {
    if (bytes.length < 86) {
      return null;
    }
    final numRecords = _readUInt16(bytes, 76);
    if (numRecords <= 0 || numRecords > 65535) {
      return null;
    }
    const recordsTableStart = 78;
    final recordsTableEnd = recordsTableStart + numRecords * 8;
    if (recordsTableEnd > bytes.length) {
      return null;
    }

    final offsets = <int>[];
    for (int i = 0; i < numRecords; i++) {
      final offset = _readUInt32(bytes, recordsTableStart + i * 8);
      if (offset < 0 || offset >= bytes.length) {
        return null;
      }
      offsets.add(offset);
    }

    final records = <Uint8List>[];
    for (int i = 0; i < offsets.length; i++) {
      final start = offsets[i];
      final end = i + 1 < offsets.length ? offsets[i + 1] : bytes.length;
      if (end <= start) {
        records.add(Uint8List(0));
        continue;
      }
      records.add(Uint8List.sublistView(bytes, start, end));
    }
    return records;
  }

  int _readUInt16(Uint8List bytes, int offset) {
    if (offset + 1 >= bytes.length) {
      return 0;
    }
    return (bytes[offset] << 8) | bytes[offset + 1];
  }

  int _readUInt32(Uint8List bytes, int offset) {
    if (offset + 3 >= bytes.length) {
      return 0;
    }
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  String _safeAscii(Uint8List bytes, int offset, int length) {
    if (offset < 0 || length <= 0 || offset + length > bytes.length) {
      return '';
    }
    return ascii.decode(bytes.sublist(offset, offset + length),
        allowInvalid: true);
  }
}

class _MobiHeaderInfo {
  final String title;
  final String author;
  final int textEncoding;
  final int trailingFlags;

  const _MobiHeaderInfo({
    required this.title,
    required this.author,
    required this.textEncoding,
    required this.trailingFlags,
  });
}
