import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/reader_models.dart';
import '../document/flow_doc.dart';
import '../../services/books/enhanced_txt_import_service.dart';
import 'parser_models.dart';

Map<String, dynamic> _decodeAndDetectTxtInBackground(
    Map<String, dynamic> args) {
  final bytes = args['bytes'] as Uint8List;
  final encodingOverride = args['encodingOverride'] as String?;
  final content = TxtParser._decodeSmart(
    bytes,
    encodingOverride: encodingOverride,
  ).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final markers = TxtParser._detectChapters(content)
      .map(
        (e) => <String, dynamic>{
          'title': e.title,
          'startOffset': e.startOffset,
        },
      )
      .toList();
  return <String, dynamic>{
    'content': content,
    'markers': markers,
  };
}

class TxtParser implements BookParser {
  static const _fallbackChapterChars = 12000;
  static const _fallbackParagraphCount = 25;
  static const _decodeSampleBytes = 512 * 1024;
  static const _largeTxtBytes = 2 * 1024 * 1024;
  static const _fastFlowDocCharsThreshold = 3 * 1024 * 1024;
  static const _fastParagraphChunkChars = 3600;
  static const _normalParagraphChunkChars = 12000;
  static const _blankParagraphSpaceHeight = 8.0;
  static final RegExp _listLinePattern = RegExp(
    r'^\s*(?:[-*•●○◆■□※]|[0-9]{1,3}[\.、．\)]|[一二三四五六七八九十百千]+[、\.．\)]|第[一二三四五六七八九十百千\d]+[章节回])',
  );
  static final RegExp _latinDigitTailPattern = RegExp(r'[A-Za-z0-9\)\]]$');
  static final RegExp _latinDigitHeadPattern = RegExp(r'^[A-Za-z0-9\(\[]');

  static final List<RegExp> _chapterPatterns = [
    RegExp(r'^第[一二三四五六七八九十百千\d]+章\s*.*$'),
    RegExp(r'^第[一二三四五六七八九十百千\d]+节\s*.*$'),
    RegExp(r'^chapter\s+\d+\b.*$', caseSensitive: false),
    RegExp(r'^part\s+\d+\b.*$', caseSensitive: false),
    RegExp(r'^[\d]+[\.、]\s+.*$'),
  ];

  @override
  Future<ParsedBook> parse({
    required String bookId,
    required String title,
    required String author,
    required String filePath,
    String? encodingOverride,
  }) async {
    final startAt = DateTime.now();
    if (kDebugMode) {
      debugPrint(
        '[TxtParser] parse start book=$bookId file=$filePath encoding=${encodingOverride ?? 'auto'}',
      );
    }
    final bytes = await File(filePath).readAsBytes();
    final payload = await compute<Map<String, dynamic>, Map<String, dynamic>>(
      _decodeAndDetectTxtInBackground,
      <String, dynamic>{
        'bytes': bytes,
        'encodingOverride': encodingOverride,
      },
    );
    final content = payload['content'] as String;
    final markerMaps =
        (payload['markers'] as List).cast<Map<String, dynamic>>();
    final markers = markerMaps
        .map(
          (e) => _ChapterMarker(
            title: e['title'] as String,
            startOffset: e['startOffset'] as int,
          ),
        )
        .toList();
    if (kDebugMode) {
      final elapsedMs = DateTime.now().difference(startAt).inMilliseconds;
      debugPrint(
        '[TxtParser] decode+toc done book=$bookId bytes=${bytes.length} chars=${content.length} '
        'markers=${markers.length} elapsed=${elapsedMs}ms',
      );
    }
    final chapters =
        _buildChapters(bookId: bookId, content: content, markers: markers);
    if (kDebugMode) {
      final elapsedMs = DateTime.now().difference(startAt).inMilliseconds;
      debugPrint(
        '[TxtParser] build chapters done book=$bookId chapters=${chapters.length} elapsed=${elapsedMs}ms',
      );
    }

    final book = Book(
      id: bookId,
      title: title,
      author: author,
      filePath: filePath,
      format: 'txt',
    );

    final toc = <TocItem>[];
    final parsed = <ParsedChapter>[];

    for (int i = 0; i < chapters.length; i++) {
      final chapterWithOffset = chapters[i];
      final parsedChapter = chapterWithOffset.chapter;
      toc.add(TocItem(
        chapterId: parsedChapter.chapter.id,
        title: parsedChapter.chapter.title,
        level: 0,
        anchorOffset: chapterWithOffset.anchorOffset,
      ));
      parsed.add(parsedChapter);
    }

    return ParsedBook(book: book, toc: toc, chapters: parsed);
  }

  static String _decodeSmart(
    Uint8List bytes, {
    String? encodingOverride,
  }) {
    if (bytes.isEmpty) {
      return '';
    }

    final txtService = EnhancedTxtImportService();
    final normalized = EnhancedTxtImportService.normalizeEncoding(
      encodingOverride,
    );

    if (normalized != 'auto') {
      final forced = txtService.decodeWithOverride(
        _trimBytesForEncoding(bytes, normalized),
        encodingOverride: normalized,
      );
      if (kDebugMode) {
        debugPrint(
          '[TxtParser] decode forced encoding=$normalized bytes=${bytes.length} chars=${forced.length}',
        );
      }
      return forced;
    }

    final preferred = txtService.detectEncoding(
      bytes,
      encodingOverride: null,
    );
    final normalizedPreferred =
        EnhancedTxtImportService.normalizeEncoding(preferred);
    final candidates = <String>[
      normalizedPreferred,
      'gbk',
      'utf8',
      'utf16le',
      'utf16be',
    ];

    // 大文件优先走快速路径，避免整本多轮全量解码导致卡住。
    if (bytes.length >= _largeTxtBytes) {
      final primary = _decodeCandidate(
        txtService,
        bytes,
        normalizedPreferred,
      );
      if (primary != null && !_looksGarbled(primary)) {
        if (kDebugMode) {
          debugPrint(
            '[TxtParser] decode fast-path encoding=$normalizedPreferred bytes=${bytes.length}',
          );
        }
        return primary;
      }

      final fallbackEncoding = normalizedPreferred == 'gbk' ? 'utf8' : 'gbk';
      final fallback = _decodeCandidate(txtService, bytes, fallbackEncoding);
      if (primary == null || primary.isEmpty) {
        if (fallback != null && fallback.isNotEmpty) {
          return fallback;
        }
      } else if (fallback != null &&
          fallback.isNotEmpty &&
          _contentQualityScore(fallback) > _contentQualityScore(primary)) {
        if (kDebugMode) {
          debugPrint(
            '[TxtParser] decode fast-fallback encoding=$fallbackEncoding bytes=${bytes.length}',
          );
        }
        return fallback;
      } else {
        if (kDebugMode) {
          debugPrint(
            '[TxtParser] decode fast-primary encoding=$normalizedPreferred bytes=${bytes.length}',
          );
        }
        return primary;
      }
    }

    final sampleBytes = bytes.length > _decodeSampleBytes
        ? bytes.sublist(0, _decodeSampleBytes)
        : bytes;
    final tried = <String>{};
    String? bestCandidate;
    String? best;
    double bestScore = -1e9;

    for (final candidate in candidates) {
      if (candidate.isEmpty || tried.contains(candidate)) {
        continue;
      }
      tried.add(candidate);

      final sampleDecoded =
          _decodeCandidate(txtService, sampleBytes, candidate);
      if (sampleDecoded == null || sampleDecoded.isEmpty) {
        continue;
      }
      final score = _contentQualityScore(sampleDecoded);
      if (score > bestScore) {
        bestScore = score;
        bestCandidate = candidate;
      }
    }

    final finalCandidate = bestCandidate ?? normalizedPreferred;
    best = _decodeCandidate(txtService, bytes, finalCandidate);
    if (kDebugMode) {
      debugPrint(
        '[TxtParser] decode sampled encoding=$finalCandidate '
        'preferred=$normalizedPreferred bytes=${bytes.length}',
      );
    }

    final bestText = best;
    if (bestText != null && bestText.isNotEmpty) {
      return bestText;
    }

    for (final candidate in candidates) {
      final fallback = _decodeCandidate(txtService, bytes, candidate);
      if (fallback != null && fallback.isNotEmpty) {
        return fallback;
      }
    }

    return txtService.decodeWithOverride(bytes, encodingOverride: 'utf8');
  }

  static String? _decodeCandidate(
    EnhancedTxtImportService txtService,
    Uint8List bytes,
    String candidate,
  ) {
    final normalizedCandidate =
        EnhancedTxtImportService.normalizeEncoding(candidate);
    if (normalizedCandidate == 'auto') {
      return null;
    }
    try {
      return txtService.decodeWithOverride(
        _trimBytesForEncoding(bytes, normalizedCandidate),
        encodingOverride: normalizedCandidate,
      );
    } catch (_) {
      return null;
    }
  }

  static Uint8List _trimBytesForEncoding(
    Uint8List bytes,
    String? encoding,
  ) {
    final normalized = EnhancedTxtImportService.normalizeEncoding(encoding);
    if ((normalized == 'utf16le' || normalized == 'utf16be') &&
        bytes.length.isOdd) {
      return bytes.sublist(0, bytes.length - 1);
    }
    return bytes;
  }

  static bool _looksGarbled(String text) {
    final value = text.trim();
    if (value.isEmpty) {
      return true;
    }

    int total = 0;
    int cjk = 0;
    int replacement = 0;
    int control = 0;
    for (final rune in value.runes) {
      if (rune <= 0x20) continue;
      total += 1;
      if (rune == 0xfffd) {
        replacement += 1;
      }
      if ((rune >= 0x4e00 && rune <= 0x9fff) ||
          (rune >= 0x3400 && rune <= 0x4dbf)) {
        cjk += 1;
      }
      if (rune < 32 && rune != 9 && rune != 10 && rune != 13) {
        control += 1;
      }
    }
    if (total == 0) return true;

    final replacementRatio = replacement / total;
    final cjkRatio = cjk / total;
    final controlRatio = control / total;

    if (replacementRatio > 0.03 || controlRatio > 0.03) {
      return true;
    }
    // 对中文小说更宽松：只要有一定中文比例就接受。
    if (cjkRatio > 0.02) {
      return false;
    }
    return false;
  }

  static double _contentQualityScore(String text) {
    if (text.isEmpty) return -1e9;
    final sample = text.length > 8000 ? text.substring(0, 8000) : text;
    int total = 0;
    int cjk = 0;
    int replacement = 0;
    int printable = 0;
    int control = 0;

    for (final rune in sample.runes) {
      total += 1;
      if (rune == 0xfffd) replacement += 1;
      final isCjk = (rune >= 0x4e00 && rune <= 0x9fff) ||
          (rune >= 0x3400 && rune <= 0x4dbf);
      if (isCjk) cjk += 1;

      final isPrintableAscii = rune >= 32 && rune <= 126;
      final isWhitespace = rune == 9 || rune == 10 || rune == 13 || rune == 32;
      if (isPrintableAscii || isWhitespace || isCjk) {
        printable += 1;
      }
      if (rune < 32 && rune != 9 && rune != 10 && rune != 13) {
        control += 1;
      }
    }

    if (total == 0) return -1e9;
    final replacementRatio = replacement / total;
    final cjkRatio = cjk / total;
    final printableRatio = printable / total;
    final controlRatio = control / total;

    return printableRatio * 0.55 +
        cjkRatio * 0.45 -
        replacementRatio * 4.0 -
        controlRatio * 2.0 +
        math.min(0.1, cjkRatio);
  }

  static List<_ChapterMarker> _detectChapters(String content) {
    final markers = <_ChapterMarker>[];
    _forEachLine(content, (line, startOffset) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty &&
          _chapterPatterns.any((p) => p.hasMatch(trimmed))) {
        markers.add(_ChapterMarker(title: trimmed, startOffset: startOffset));
      }
    });

    if (markers.length >= 2) {
      return markers;
    }

    final paragraphMarkers = _fallbackByParagraph(content);
    if (paragraphMarkers.length >= 2) {
      return paragraphMarkers;
    }

    return _fallbackByCharCount(content);
  }

  static List<_ChapterMarker> _fallbackByParagraph(String content) {
    final markers = <_ChapterMarker>[];
    int paragraphCount = 0;
    int chapterIndex = 1;

    _forEachLine(content, (line, startOffset) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        if (paragraphCount % _fallbackParagraphCount == 0) {
          markers.add(
            _ChapterMarker(
              title: '第$chapterIndex章',
              startOffset: startOffset,
            ),
          );
          chapterIndex += 1;
        }
        paragraphCount += 1;
      }
    });

    return markers;
  }

  static List<_ChapterMarker> _fallbackByCharCount(String content) {
    final markers = <_ChapterMarker>[];
    int chapterIndex = 1;
    int cursor = 0;

    while (cursor < content.length) {
      markers
          .add(_ChapterMarker(title: '第$chapterIndex章', startOffset: cursor));
      chapterIndex += 1;

      if (cursor + _fallbackChapterChars >= content.length) {
        break;
      }

      final breakPos = content.indexOf('\n', cursor + _fallbackChapterChars);
      if (breakPos < 0) {
        break;
      }
      cursor = breakPos + 1;
    }

    if (markers.isEmpty) {
      markers.add(const _ChapterMarker(title: '正文', startOffset: 0));
    }

    return markers;
  }

  static void _forEachLine(
    String content,
    void Function(String line, int startOffset) onLine,
  ) {
    int lineStart = 0;
    for (int i = 0; i <= content.length; i++) {
      if (i == content.length || content.codeUnitAt(i) == 0x0A) {
        onLine(content.substring(lineStart, i), lineStart);
        lineStart = i + 1;
      }
    }
  }

  List<_ParsedChapterWithOffset> _buildChapters({
    required String bookId,
    required String content,
    required List<_ChapterMarker> markers,
  }) {
    final results = <_ParsedChapterWithOffset>[];
    final fastFlowDocMode = content.length >= _fastFlowDocCharsThreshold;

    for (int i = 0; i < markers.length; i++) {
      final marker = markers[i];
      final nextOffset =
          i + 1 < markers.length ? markers[i + 1].startOffset : content.length;
      final start = marker.startOffset.clamp(0, content.length);
      final end = nextOffset.clamp(start, content.length);
      final chapterContent = content.substring(start, end).trim();
      if (chapterContent.isEmpty) {
        continue;
      }

      final chapterId = '$bookId-ch-$i';
      final chapter = Chapter(
        id: chapterId,
        bookId: bookId,
        title: marker.title,
        order: i,
        content: chapterContent,
      );

      results.add(
        _ParsedChapterWithOffset(
          anchorOffset: start,
          chapter: ParsedChapter(
            chapter: chapter,
            flowDoc: _toFlowDoc(
              chapter.title,
              chapterContent,
              fastMode: fastFlowDocMode,
            ),
          ),
        ),
      );
    }

    if (results.isEmpty) {
      final chapter = Chapter(
        id: '$bookId-ch-0',
        bookId: bookId,
        title: '正文',
        order: 0,
        content: content,
      );
      results.add(
        _ParsedChapterWithOffset(
          anchorOffset: 0,
          chapter: ParsedChapter(
            chapter: chapter,
            flowDoc: _toFlowDoc(
              chapter.title,
              chapter.content,
              fastMode: fastFlowDocMode,
            ),
          ),
        ),
      );
    }

    return results;
  }

  FlowDoc _toFlowDoc(
    String title,
    String content, {
    bool fastMode = false,
  }) {
    final blocks = <Block>[];
    int blockIndex = 0;

    blocks.add(
      HeadingBlock(
        id: 'h-${blockIndex++}',
        level: 1,
        inlines: [TextInline(title)],
      ),
    );

    final normalizedTitle = _normalizeHeading(title);
    final cleanedLines = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .toList();

    while (cleanedLines.isNotEmpty) {
      final first = cleanedLines.first.trim();
      if (first.isEmpty) {
        cleanedLines.removeAt(0);
        continue;
      }
      if (_normalizeHeading(first) == normalizedTitle) {
        cleanedLines.removeAt(0);
      }
      break;
    }

    final bodyText = cleanedLines.join('\n').trim();
    if (bodyText.isEmpty) {
      return FlowDoc(blocks: blocks);
    }

    blockIndex = _appendTxtBodyBlocks(
      blocks: blocks,
      bodyText: bodyText,
      startBlockIndex: blockIndex,
      fastMode: fastMode,
    );

    return FlowDoc(blocks: blocks);
  }

  int _appendTxtBodyBlocks({
    required List<Block> blocks,
    required String bodyText,
    required int startBlockIndex,
    required bool fastMode,
  }) {
    var blockIndex = startBlockIndex;
    final maxParagraphChars =
        fastMode ? _fastParagraphChunkChars : _normalParagraphChunkChars;
    final lines = bodyText.split('\n');
    final paragraph = StringBuffer();
    int blankRun = 0;
    String? previousLine;

    void flushParagraph() {
      if (paragraph.isEmpty) {
        return;
      }
      final text = paragraph.toString().trim();
      paragraph.clear();
      if (text.isEmpty) {
        return;
      }
      blocks.add(
        ParagraphBlock(
          id: 'p-${blockIndex++}',
          inlines: [TextInline(text)],
        ),
      );
      previousLine = null;
    }

    void flushBlankRun() {
      if (blankRun >= 2) {
        blocks.add(
          SpaceBlock(
            id: 'space-${blockIndex++}',
            height: _blankParagraphSpaceHeight,
          ),
        );
      }
      blankRun = 0;
      previousLine = null;
    }

    for (final line in lines) {
      final normalizedLine = line.trimRight();
      if (normalizedLine.trim().isEmpty) {
        flushParagraph();
        blankRun += 1;
        continue;
      }

      flushBlankRun();
      if (paragraph.isEmpty) {
        paragraph.write(normalizedLine);
        previousLine = normalizedLine;
      } else {
        final prev = previousLine ?? '';
        final keepHardBreak = _shouldKeepTxtHardBreak(
          previousLine: prev,
          currentLine: normalizedLine,
        );
        if (keepHardBreak) {
          paragraph.write('\n');
          paragraph.write(normalizedLine);
        } else {
          if (_shouldInsertAsciiJoinSpace(
            previousLine: prev,
            currentLine: normalizedLine,
          )) {
            paragraph.write(' ');
          }
          paragraph.write(normalizedLine.trimLeft());
        }
        previousLine = normalizedLine;
      }
      if (paragraph.length >= maxParagraphChars) {
        flushParagraph();
      }
    }

    flushParagraph();
    flushBlankRun();
    return blockIndex;
  }

  String _normalizeHeading(String text) {
    return text.replaceAll(RegExp(r'\s+'), '').trim();
  }

  bool _shouldKeepTxtHardBreak({
    required String previousLine,
    required String currentLine,
  }) {
    final prev = previousLine.trimRight();
    final curr = currentLine.trimRight();
    if (prev.isEmpty || curr.isEmpty) {
      return true;
    }

    final prevTrim = prev.trimLeft();
    final currTrim = curr.trimLeft();

    if (_listLinePattern.hasMatch(prevTrim) ||
        _listLinePattern.hasMatch(currTrim)) {
      return true;
    }

    if (_isLikelyPoetryLine(prevTrim) && _isLikelyPoetryLine(currTrim)) {
      return true;
    }

    if (_startsWithExplicitIndent(curr)) {
      return true;
    }

    if (prevTrim.endsWith('：') || prevTrim.endsWith(':')) {
      return true;
    }

    if (_looksLikeDialogue(prevTrim) && _looksLikeDialogue(currTrim)) {
      return true;
    }

    return false;
  }

  bool _shouldInsertAsciiJoinSpace({
    required String previousLine,
    required String currentLine,
  }) {
    final prev = previousLine.trimRight();
    final curr = currentLine.trimLeft();
    if (prev.isEmpty || curr.isEmpty) {
      return false;
    }
    return _latinDigitTailPattern.hasMatch(prev) &&
        _latinDigitHeadPattern.hasMatch(curr);
  }

  bool _isLikelyPoetryLine(String line) {
    final text = line.trim();
    if (text.isEmpty) {
      return false;
    }
    if (text.length > 18) {
      return false;
    }
    return true;
  }

  bool _startsWithExplicitIndent(String line) {
    if (line.startsWith('  ')) {
      return true;
    }
    if (line.startsWith('\t')) {
      return true;
    }
    return line.startsWith('　');
  }

  bool _looksLikeDialogue(String line) {
    if (line.isEmpty) {
      return false;
    }
    const quoteStarts = <String>['“', '"', '「', '『', '《', '—', '–'];
    for (final q in quoteStarts) {
      if (line.startsWith(q)) {
        return true;
      }
    }
    return false;
  }
}

class _ChapterMarker {
  final String title;
  final int startOffset;

  const _ChapterMarker({required this.title, required this.startOffset});
}

class _ParsedChapterWithOffset {
  final int anchorOffset;
  final ParsedChapter chapter;

  const _ParsedChapterWithOffset(
      {required this.anchorOffset, required this.chapter});
}
