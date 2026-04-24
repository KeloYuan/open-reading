// 文件说明：全局 AI 阅读服务，为首页和阅读场景生成建议、摘要和知识片段。
// 技术要点：服务层、Crypto 哈希、Path、Path Provider、JSON、文件系统。

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:xxread/models/book.dart' as legacy;
import 'package:xxread/reader_core/data/reader_models.dart' as core;
import 'package:xxread/reader_core/parser/docx_parser.dart';
import 'package:xxread/reader_core/parser/epub_parser.dart';
import 'package:xxread/reader_core/parser/fb2_parser.dart';
import 'package:xxread/reader_core/parser/mobi_parser.dart';
import 'package:xxread/reader_core/parser/parser_models.dart';
import 'package:xxread/reader_core/parser/rtf_parser.dart';
import 'package:xxread/reader_core/parser/txt_parser.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/books/book_note_dao.dart';
import 'package:xxread/services/reading/reading_stats_dao.dart';

class KnowledgeSnippet {
  final String id;
  final String chapterId;
  final int startOffset;
  final int endOffset;
  final String preview;
  final List<String> keywords;
  final double score;

  const KnowledgeSnippet({
    required this.id,
    required this.chapterId,
    required this.startOffset,
    required this.endOffset,
    required this.preview,
    required this.keywords,
    this.score = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chapterId': chapterId,
      'startOffset': startOffset,
      'endOffset': endOffset,
      'preview': preview,
      'keywords': keywords,
    };
  }

  factory KnowledgeSnippet.fromMap(Map<String, dynamic> map) {
    return KnowledgeSnippet(
      id: map['id'] as String,
      chapterId: map['chapterId'] as String,
      startOffset: map['startOffset'] as int,
      endOffset: map['endOffset'] as int,
      preview: map['preview'] as String,
      keywords: (map['keywords'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }

  KnowledgeSnippet withScore(double nextScore) {
    return KnowledgeSnippet(
      id: id,
      chapterId: chapterId,
      startOffset: startOffset,
      endOffset: endOffset,
      preview: preview,
      keywords: keywords,
      score: nextScore,
    );
  }
}

class GlobalAIReadingService {
  factory GlobalAIReadingService() => _instance;

  GlobalAIReadingService._();

  static final GlobalAIReadingService _instance = GlobalAIReadingService._();

  static const String _rootFolder = 'ai_knowledge';
  static const String _globalMemoryFile = 'memory.json';
  static const int _schemaVersion = 1;
  static const int _chunkSize = 420;
  static const int _chunkOverlap = 120;

  static const Set<String> _supportedFormats = <String>{
    'txt',
    'epub',
    'mobi',
    'azw',
    'azw3',
    'fb2',
    'rtf',
    'docx',
  };

  final ReadingStatsDao _statsDao = ReadingStatsDao();
  final BookNoteDao _bookNoteDao = BookNoteDao();
  final BookDao _bookDao = BookDao();

  Future<void> scheduleImportedBookAnalysis({required legacy.Book book}) async {
    if (!_supportedFormats.contains(book.format.toLowerCase())) {
      return;
    }
    unawaited(_analyzeImportedBook(book));
  }

  Future<void> _analyzeImportedBook(legacy.Book book) async {
    try {
      final fallbackId = book.filePath.hashCode.abs().toString();
      final parser = _pickParser(book.format);
      final parsed = await parser.parse(
        bookId: (book.id ?? fallbackId).toString(),
        title: book.title,
        author: book.author,
        filePath: book.filePath,
        encodingOverride: book.textEncoding,
      );
      await ensureKnowledgeForParsedBook(
        parsedBook: parsed,
        legacyBookId: book.id,
      );
    } catch (e) {
      debugPrint('[GlobalAI] imported analysis skipped: $e');
    }
  }

  Future<void> ensureKnowledgeForParsedBook({
    required ParsedBook parsedBook,
    int? legacyBookId,
  }) async {
    try {
      final bookId = parsedBook.book.id;
      final memoryFile = await _bookMemoryFile(bookId);
      final indexFile = await _bookIndexFile(bookId);
      final fingerprint = _fingerprintParsedBook(parsedBook);
      final readingProfile = await _buildReadingProfile(legacyBookId);

      final memoryDoc = await _readJson(memoryFile);
      final indexDoc = await _readJson(indexFile);
      final hasSameFingerprint = memoryDoc?['fingerprint'] == fingerprint &&
          indexDoc?['fingerprint'] == fingerprint;

      if (!hasSameFingerprint) {
        final termAnnotations = _extractTermAnnotations(parsedBook);
        final chunks = _buildKnowledgeChunks(parsedBook, termAnnotations);
        final chapterSummaries = _buildChapterSummaries(parsedBook);
        final summary = _buildBookSummary(parsedBook, chapterSummaries);

        final nextMemory = <String, dynamic>{
          'schemaVersion': _schemaVersion,
          'bookId': bookId,
          'title': parsedBook.book.title,
          'author': parsedBook.book.author,
          'fingerprint': fingerprint,
          'generatedAt': DateTime.now().toIso8601String(),
          'summary': summary,
          'chapterSummaries': chapterSummaries,
          'readingAdvice': _buildReadingAdvice(readingProfile),
          'readingProfile': readingProfile,
          'qaMemory': _normalizeQaMemory(memoryDoc?['qaMemory']),
        };

        final nextIndex = <String, dynamic>{
          'schemaVersion': _schemaVersion,
          'bookId': bookId,
          'fingerprint': fingerprint,
          'generatedAt': DateTime.now().toIso8601String(),
          'chunks': chunks.map((e) => e.toMap()).toList(),
          'terms': termAnnotations.map((e) => e.toMap()).toList(),
        };

        await _writeJson(memoryFile, nextMemory);
        await _writeJson(indexFile, nextIndex);
      } else {
        final patched = <String, dynamic>{
          ...memoryDoc!,
          'readingProfile': readingProfile,
          'readingAdvice': _buildReadingAdvice(readingProfile),
          'updatedAt': DateTime.now().toIso8601String(),
        };
        await _writeJson(memoryFile, patched);
      }

      await _updateGlobalMemory(readingProfile: readingProfile);
    } catch (e) {
      debugPrint('[GlobalAI] ensure knowledge failed: $e');
    }
  }

  Future<List<core.TermAnnotation>> loadTermAnnotations({
    required String bookId,
    required String chapterId,
  }) async {
    final indexFile = await _bookIndexFile(bookId);
    final doc = await _readJson(indexFile);
    if (doc == null) {
      return const <core.TermAnnotation>[];
    }
    final terms = (doc['terms'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .map(core.TermAnnotation.fromMap)
        .where((e) => e.chapterId == chapterId)
        .toList();
    terms.sort((a, b) => a.startOffset.compareTo(b.startOffset));
    return terms;
  }

  Future<Map<String, dynamic>?> loadBookMemory(String bookId) async {
    return _readJson(await _bookMemoryFile(bookId));
  }

  Future<List<KnowledgeSnippet>> findRelevantSnippets({
    required String bookId,
    required String query,
    String? chapterId,
    int limit = 3,
  }) async {
    final indexFile = await _bookIndexFile(bookId);
    final doc = await _readJson(indexFile);
    if (doc == null) {
      return const <KnowledgeSnippet>[];
    }
    final chunks = (doc['chunks'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => KnowledgeSnippet.fromMap(e.cast<String, dynamic>()))
        .toList();
    if (chunks.isEmpty) {
      return const <KnowledgeSnippet>[];
    }

    final tokens = _tokenizeQuery(query);
    final scored = <KnowledgeSnippet>[];
    for (final chunk in chunks) {
      final normalizedPreview = chunk.preview.toLowerCase();
      double score = 0;
      if (chapterId != null && chapterId == chunk.chapterId) {
        score += 2.0;
      }
      for (final token in tokens) {
        if (token.isEmpty) continue;
        if (normalizedPreview.contains(token.toLowerCase())) {
          score += 2.2;
        }
        if (chunk.keywords.any(
          (k) => k.toLowerCase().contains(token.toLowerCase()),
        )) {
          score += 1.4;
        }
      }
      if (score > 0) {
        scored.add(chunk.withScore(score));
      }
    }

    if (scored.isEmpty && chapterId != null) {
      final chapterFallback =
          chunks.where((e) => e.chapterId == chapterId).take(limit).toList();
      if (chapterFallback.isNotEmpty) {
        return chapterFallback;
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).toList();
  }

  Future<String> buildInjectedContext({
    required String bookId,
    required String userQuestion,
    String? chapterId,
  }) async {
    final memory = await loadBookMemory(bookId);
    final snippets = await findRelevantSnippets(
      bookId: bookId,
      query: userQuestion,
      chapterId: chapterId,
      limit: 3,
    );

    final buffer = StringBuffer();
    if (memory != null) {
      final summary = (memory['summary'] as String?)?.trim() ?? '';
      final advice = (memory['readingAdvice'] as String?)?.trim() ?? '';
      if (summary.isNotEmpty) {
        buffer
          ..writeln('【本书记忆摘要】')
          ..writeln(summary);
      }
      if (advice.isNotEmpty) {
        buffer
          ..writeln('【针对用户的阅读建议】')
          ..writeln(advice);
      }
    }

    if (snippets.isNotEmpty) {
      buffer.writeln('【索引命中片段】');
      for (var i = 0; i < snippets.length; i++) {
        final s = snippets[i];
        buffer
          ..writeln(
            '${i + 1}. chapter=${s.chapterId}, offset=${s.startOffset}-${s.endOffset}',
          )
          ..writeln(s.preview);
      }
    }

    return buffer.toString().trim();
  }

  Future<String> buildLocalFallbackAnswer({
    required String bookId,
    required String userQuestion,
    String? chapterId,
  }) async {
    final memory = await loadBookMemory(bookId);
    final snippets = await findRelevantSnippets(
      bookId: bookId,
      query: userQuestion,
      chapterId: chapterId,
      limit: 3,
    );

    final summary = (memory?['summary'] as String?)?.trim() ?? '';
    final advice = (memory?['readingAdvice'] as String?)?.trim() ?? '';

    final buffer = StringBuffer();
    buffer.writeln('当前未配置在线 AI Key，先基于本地记忆和索引给你一个答案：');

    if (snippets.isEmpty) {
      if (summary.isNotEmpty) {
        buffer
          ..writeln('\n【相关内容】')
          ..writeln(summary);
      } else {
        buffer.writeln('\n【相关内容】暂未命中可用片段。');
      }
    } else {
      buffer.writeln('\n【相关内容定位】');
      for (final s in snippets) {
        buffer
          ..writeln('- 位置：${s.chapterId} (${s.startOffset}-${s.endOffset})')
          ..writeln('  ${s.preview}');
      }
    }

    if (advice.isNotEmpty) {
      buffer
        ..writeln('\n【建议怎么读】')
        ..writeln(advice);
    }

    buffer
      ..writeln('\n【下一步】')
      ..writeln('1) 先读上面命中的片段。')
      ..writeln('2) 用“为什么/如何/例子”再追问一次，我会继续按索引定位。');

    return buffer.toString().trim();
  }

  Future<void> appendConversationMemory({
    required String bookId,
    required String question,
    required String answer,
  }) async {
    final memoryFile = await _bookMemoryFile(bookId);
    final memory = await _readJson(memoryFile) ?? <String, dynamic>{};
    final qa = _normalizeQaMemory(memory['qaMemory'])
      ..add(<String, dynamic>{
        'question': question,
        'answer': answer,
        'createdAt': DateTime.now().toIso8601String(),
      });

    final trimmed = qa.length <= 20 ? qa : qa.sublist(qa.length - 20);
    final next = <String, dynamic>{
      ...memory,
      'qaMemory': trimmed,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await _writeJson(memoryFile, next);
  }

  BookParser _pickParser(String format) {
    final normalized = format.toLowerCase();
    if (normalized == 'epub') {
      return EpubParser();
    }
    if (normalized == 'mobi' || normalized == 'azw' || normalized == 'azw3') {
      return MobiParser();
    }
    if (normalized == 'fb2') {
      return Fb2Parser();
    }
    if (normalized == 'rtf') {
      return RtfParser();
    }
    if (normalized == 'docx') {
      return DocxParser();
    }
    return TxtParser();
  }

  String _fingerprintParsedBook(ParsedBook parsedBook) {
    final buffer = StringBuffer()
      ..write(parsedBook.book.id)
      ..write('|')
      ..write(parsedBook.book.title)
      ..write('|')
      ..write(parsedBook.chapters.length);

    for (final chapter in parsedBook.chapters) {
      final text = chapter.chapter.content;
      final head = text.substring(0, math.min(120, text.length));
      buffer
        ..write('|')
        ..write(chapter.chapter.id)
        ..write(':')
        ..write(text.length)
        ..write(':')
        ..write(head);
    }

    return sha1.convert(utf8.encode(buffer.toString())).toString();
  }

  List<Map<String, dynamic>> _buildChapterSummaries(ParsedBook parsedBook) {
    final summaries = <Map<String, dynamic>>[];
    for (final chapter in parsedBook.chapters) {
      final content = _normalizeText(chapter.chapter.content);
      if (content.isEmpty) {
        continue;
      }
      final summary = _summarizeText(content);
      summaries.add({
        'chapterId': chapter.chapter.id,
        'title': chapter.chapter.title,
        'summary': summary,
      });
    }
    return summaries;
  }

  String _buildBookSummary(
    ParsedBook parsedBook,
    List<Map<String, dynamic>> chapterSummaries,
  ) {
    final buffer = StringBuffer();
    buffer
      ..writeln('《${parsedBook.book.title}》共 ${parsedBook.chapters.length} 章。')
      ..writeln('核心内容提要：');

    for (var i = 0; i < chapterSummaries.length && i < 6; i++) {
      final item = chapterSummaries[i];
      final title = item['title'] as String? ?? '章节 ${i + 1}';
      final summary = item['summary'] as String? ?? '';
      if (summary.trim().isEmpty) {
        continue;
      }
      buffer.writeln('${i + 1}. $title：$summary');
    }

    return buffer.toString().trim();
  }

  List<core.TermAnnotation> _extractTermAnnotations(ParsedBook parsedBook) {
    final frequency = <String, int>{};
    final sourceByChapter = <String, String>{
      for (final chapter in parsedBook.chapters)
        chapter.chapter.id: _normalizeText(chapter.chapter.content),
    };

    final chineseRegex = RegExp(r'[\u4e00-\u9fa5]{2,8}');
    final englishRegex = RegExp(r'\b[A-Za-z][A-Za-z0-9\-]{2,}\b');

    for (final entry in sourceByChapter.entries) {
      final text = entry.value;

      for (final match in chineseRegex.allMatches(text)) {
        final token = match.group(0)?.trim() ?? '';
        if (_skipChineseToken(token)) continue;
        frequency[token] = (frequency[token] ?? 0) + 1;
      }

      for (final match in englishRegex.allMatches(text)) {
        final token = match.group(0)?.trim() ?? '';
        if (_skipEnglishToken(token)) continue;
        frequency[token] = (frequency[token] ?? 0) + 1;
      }
    }

    final candidates = frequency.entries.where((entry) {
      final token = entry.key;
      final count = entry.value;
      if (_isTechnicalToken(token)) {
        return count >= 2;
      }
      return count >= 4;
    }).toList();

    candidates.sort((a, b) => b.value.compareTo(a.value));
    final selected = candidates.take(48).toList();

    final terms = <core.TermAnnotation>[];
    final topCount = math.max(4, (selected.length * 0.25).round());
    var totalMarkers = 0;

    for (var i = 0; i < selected.length; i++) {
      final term = selected[i].key;
      final style = i < topCount
          ? core.TermMarkStyle.highlight
          : core.TermMarkStyle.underline;
      final color = style == core.TermMarkStyle.highlight
          ? const Color(0xFFEAB308)
          : const Color(0xFF14B8A6);
      var perTermCount = 0;

      for (final chapter in parsedBook.chapters) {
        if (perTermCount >= 3 || totalMarkers >= 180) {
          break;
        }
        final chapterId = chapter.chapter.id;
        final content = sourceByChapter[chapterId] ?? '';
        if (content.isEmpty) {
          continue;
        }
        var from = 0;
        while (from < content.length) {
          final start = content.indexOf(term, from);
          if (start < 0) {
            break;
          }
          final end = start + term.length;
          final explanation = _buildTermExplanation(
            term: term,
            chapterText: content,
            start: start,
          );

          terms.add(
            core.TermAnnotation(
              id: 'term-$chapterId-$start-${term.hashCode}',
              bookId: parsedBook.book.id,
              chapterId: chapterId,
              term: term,
              explanation: explanation,
              startOffset: start,
              endOffset: end,
              color: color,
              style: style,
              createdAt: DateTime.now(),
            ),
          );
          perTermCount += 1;
          totalMarkers += 1;
          if (perTermCount >= 3 || totalMarkers >= 180) {
            break;
          }
          from = end;
        }
      }
    }

    return terms;
  }

  List<KnowledgeSnippet> _buildKnowledgeChunks(
    ParsedBook parsedBook,
    List<core.TermAnnotation> terms,
  ) {
    final termLookup = <String, List<String>>{};
    for (final term in terms) {
      termLookup.putIfAbsent(term.chapterId, () => <String>[]).add(term.term);
    }

    final chunks = <KnowledgeSnippet>[];
    for (final chapter in parsedBook.chapters) {
      final chapterId = chapter.chapter.id;
      final text = _normalizeText(chapter.chapter.content);
      if (text.isEmpty) {
        continue;
      }
      final chapterTerms = termLookup[chapterId] ?? const <String>[];

      var start = 0;
      var index = 0;
      while (start < text.length) {
        var end = math.min(text.length, start + _chunkSize);
        if (end < text.length) {
          final nearbyNewline = text.lastIndexOf('\n', end);
          if (nearbyNewline > start + 120) {
            end = nearbyNewline;
          }
        }

        final raw = text.substring(start, end).trim();
        if (raw.isNotEmpty) {
          final preview =
              raw.length <= 260 ? raw : '${raw.substring(0, 260)}...';
          final keywords = _extractChunkKeywords(raw, chapterTerms);
          chunks.add(
            KnowledgeSnippet(
              id: '${chapterId}_$index',
              chapterId: chapterId,
              startOffset: start,
              endOffset: end,
              preview: preview,
              keywords: keywords,
            ),
          );
        }

        if (end >= text.length) {
          break;
        }
        start = math.max(start + 1, end - _chunkOverlap);
        index += 1;
      }
    }

    return chunks;
  }

  Future<Map<String, dynamic>> _buildReadingProfile(int? legacyBookId) async {
    final profile = <String, dynamic>{
      'bookId': legacyBookId,
      'durationMinutes': 0,
      'pagesRead': 0,
      'sessionCount': 0,
      'lastReadMs': 0,
      'noteCount': 0,
      'highlightCount': 0,
      'progress': 0.0,
    };

    if (legacyBookId == null) {
      return profile;
    }

    try {
      final stats = await _statsDao.getBookReadingStats();
      final byBook = stats[legacyBookId];
      if (byBook != null) {
        profile['durationMinutes'] = byBook['durationMinutes'] ?? 0;
        profile['pagesRead'] = byBook['pagesRead'] ?? 0;
        profile['sessionCount'] = byBook['sessionCount'] ?? 0;
        profile['lastReadMs'] = byBook['lastReadMs'] ?? 0;
      }
    } catch (e) {
      debugPrint('[GlobalAI] load reading stats failed: $e');
    }

    try {
      final notes = await _bookNoteDao.selectBookNotesByBookId(legacyBookId);
      profile['noteCount'] = notes.where((n) => n.hasNote).length;
      profile['highlightCount'] = notes
          .where((n) => n.type == 'highlight' || n.type == 'underline')
          .length;
    } catch (e) {
      debugPrint('[GlobalAI] load notes failed: $e');
    }

    try {
      final book = await _bookDao.getBookById(legacyBookId);
      if (book != null && book.totalPages > 0) {
        profile['progress'] =
            (book.currentPage / book.totalPages).clamp(0.0, 1.0).toDouble();
      }
    } catch (e) {
      debugPrint('[GlobalAI] load book progress failed: $e');
    }

    return profile;
  }

  String _buildReadingAdvice(Map<String, dynamic> profile) {
    final progress = (profile['progress'] as num?)?.toDouble() ?? 0;
    final sessions = (profile['sessionCount'] as num?)?.toInt() ?? 0;
    final durationMin = (profile['durationMinutes'] as num?)?.toInt() ?? 0;
    final noteCount = (profile['noteCount'] as num?)?.toInt() ?? 0;
    final highlightCount = (profile['highlightCount'] as num?)?.toInt() ?? 0;

    final avgSession = sessions > 0 ? durationMin / sessions : 0;
    final lines = <String>[];

    if (progress < 0.2) {
      lines.add('先做“通读式预习”：每次 15-25 分钟，先把章节结构读完整。');
    } else if (progress < 0.7) {
      lines.add('进入“理解深化阶段”：每章至少留下 1 条问题和 1 条总结。');
    } else {
      lines.add('进入“复盘阶段”：重点回看高亮与专业术语，形成自己的提纲。');
    }

    if (avgSession < 12 && sessions > 0) {
      lines.add('当前单次阅读偏短，建议提升到 18-30 分钟，减少频繁中断。');
    }

    if (noteCount == 0 && highlightCount < 3) {
      lines.add('建议每章至少标注 2-3 个关键概念，并写一句自己的解释。');
    } else if (noteCount > 0 && highlightCount > 10) {
      lines.add('你已经有较多标注，下一步建议按“问题-证据-结论”整理笔记。');
    }

    if (durationMin == 0) {
      lines.add('这本书还没有有效阅读记录，先完成前两章再让 AI 做针对性计划。');
    }

    if (lines.isEmpty) {
      lines.add('建议保持当前节奏，每次阅读后用 2 分钟回顾本页核心观点。');
    }

    return lines.map((line) => '- $line').join('\n');
  }

  Future<void> _updateGlobalMemory({
    required Map<String, dynamic> readingProfile,
  }) async {
    try {
      final file = await _globalMemoryPath();
      final summaryStats = await _statsDao.getSummaryStats();
      final achievement = await _statsDao.getAchievementStats();

      final todayMinutes = (summaryStats['today'] ?? 0) ~/ 60;
      final weekMinutes = (summaryStats['week'] ?? 0) ~/ 60;
      final streak = achievement['consecutiveDays'] ?? 0;

      final recommendation = <String>[];
      if (todayMinutes < 20) {
        recommendation.add('今天阅读不足 20 分钟，建议补一段 15-25 分钟的专注阅读。');
      } else {
        recommendation.add('今天阅读节奏良好，建议在结束前做一次 3 分钟复盘。');
      }
      if (streak < 3) {
        recommendation.add('连续阅读天数较低，优先建立“每天固定时段阅读”的稳定习惯。');
      } else {
        recommendation.add('连续阅读习惯正在形成，下一步提升每次阅读深度。');
      }

      final global = <String, dynamic>{
        'schemaVersion': _schemaVersion,
        'updatedAt': DateTime.now().toIso8601String(),
        'summary': {
          'todayMinutes': todayMinutes,
          'weekMinutes': weekMinutes,
          'streakDays': streak,
          'activeBookProfile': readingProfile,
        },
        'recommendation': recommendation,
      };
      await _writeJson(file, global);
    } catch (e) {
      debugPrint('[GlobalAI] update global memory failed: $e');
    }
  }

  String _normalizeText(String input) {
    return input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _summarizeText(String content) {
    if (content.isEmpty) {
      return '';
    }
    final paragraphs = content
        .split(RegExp(r'\n+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (paragraphs.isEmpty) {
      return content.length <= 140
          ? content
          : '${content.substring(0, 140)}...';
    }

    final pieces = <String>[];
    for (final p in paragraphs.take(2)) {
      pieces.add(p.length <= 80 ? p : '${p.substring(0, 80)}...');
    }
    return pieces.join(' ');
  }

  bool _skipChineseToken(String token) {
    if (token.length < 2 || token.length > 8) {
      return true;
    }
    const stop = <String>{
      '我们',
      '你们',
      '他们',
      '这个',
      '那个',
      '可以',
      '因为',
      '所以',
      '然后',
      '但是',
      '如果',
      '就是',
      '一个',
      '一些',
      '已经',
      '正在',
      '其中',
      '以及',
      '进行',
      '通过',
      '对于',
      '没有',
      '不是',
      '非常',
      '这里',
      '那里',
      '内容',
      '章节',
      '本章',
      '本书',
    };
    return stop.contains(token);
  }

  bool _skipEnglishToken(String token) {
    if (token.length < 3) {
      return true;
    }
    final lower = token.toLowerCase();
    const stop = <String>{
      'the',
      'and',
      'for',
      'with',
      'that',
      'this',
      'from',
      'into',
      'have',
      'will',
      'your',
      'book',
      'chapter',
    };
    return stop.contains(lower);
  }

  bool _isTechnicalToken(String token) {
    final upper = token.toUpperCase();
    const englishHints = <String>{
      'API',
      'HTTP',
      'HTTPS',
      'TCP',
      'UDP',
      'SQL',
      'JSON',
      'XML',
      'GPU',
      'CPU',
      'AI',
      'ML',
      'LLM',
      'SDK',
      'UI',
      'UX',
    };
    if (englishHints.contains(upper)) {
      return true;
    }
    const chineseHints = <String>{
      '算法',
      '模型',
      '协议',
      '架构',
      '网络',
      '数据库',
      '引擎',
      '框架',
      '函数',
      '向量',
      '神经',
      '索引',
      '缓存',
      '推理',
      '语义',
      '训练',
      '参数',
      '系统',
      '编译',
      '服务',
    };
    for (final hint in chineseHints) {
      if (token.contains(hint)) {
        return true;
      }
    }
    return false;
  }

  String _buildTermExplanation({
    required String term,
    required String chapterText,
    required int start,
  }) {
    final left = math.max(0, start - 36);
    final right = math.min(chapterText.length, start + term.length + 54);
    final context = chapterText
        .substring(left, right)
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    final base = _isTechnicalToken(term)
        ? '“$term”是本书中的关键专业概念，建议结合上下文理解其定义、作用和使用条件。'
        : '“$term”在当前内容中是重要术语，建议重点关注它与前后概念的关系。';

    if (context.isEmpty) {
      return base;
    }

    return '$base\n\n上下文：$context';
  }

  List<String> _extractChunkKeywords(String raw, List<String> chapterTerms) {
    final keys = <String>[];

    for (final term in chapterTerms) {
      if (raw.contains(term)) {
        keys.add(term);
      }
      if (keys.length >= 6) {
        break;
      }
    }

    if (keys.length < 6) {
      final englishMatches = RegExp(r'\b[A-Za-z][A-Za-z0-9\-]{2,}\b')
          .allMatches(raw)
          .map((e) => e.group(0) ?? '')
          .where((e) => !_skipEnglishToken(e))
          .toSet();
      for (final word in englishMatches) {
        keys.add(word);
        if (keys.length >= 6) {
          break;
        }
      }
    }

    return keys.toSet().toList();
  }

  List<String> _tokenizeQuery(String query) {
    final tokens = <String>[];
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return tokens;
    }

    for (final match
        in RegExp(r'[\u4e00-\u9fa5]{2,8}').allMatches(normalized)) {
      final token = match.group(0) ?? '';
      if (!_skipChineseToken(token)) {
        tokens.add(token);
      }
    }

    for (final match
        in RegExp(r'\b[A-Za-z][A-Za-z0-9\-]{2,}\b').allMatches(normalized)) {
      final token = match.group(0) ?? '';
      if (!_skipEnglishToken(token)) {
        tokens.add(token);
      }
    }

    if (tokens.isEmpty && normalized.length >= 2) {
      tokens.add(normalized);
    }

    return tokens.toSet().toList();
  }

  List<Map<String, dynamic>> _normalizeQaMemory(dynamic raw) {
    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }
    return raw
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .where((e) => (e['question'] as String?)?.trim().isNotEmpty ?? false)
        .toList();
  }

  Future<File> _globalMemoryPath() async {
    final root = await _ensureRoot();
    return File(p.join(root.path, _globalMemoryFile));
  }

  Future<File> _bookMemoryFile(String bookId) async {
    final dir = await _bookFolder(bookId);
    return File(p.join(dir.path, 'memory.json'));
  }

  Future<File> _bookIndexFile(String bookId) async {
    final dir = await _bookFolder(bookId);
    return File(p.join(dir.path, 'index.json'));
  }

  Future<Directory> _ensureRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(docs.path, _rootFolder));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  Future<Directory> _bookFolder(String bookId) async {
    final root = await _ensureRoot();
    final safeId = _safeFileName(bookId);
    final folder = Directory(p.join(root.path, 'books', safeId));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  String _safeFileName(String input) {
    final sanitized = input.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return sanitized.isEmpty ? 'unknown_book' : sanitized;
  }

  Future<Map<String, dynamic>?> _readJson(File file) async {
    try {
      if (!await file.exists()) {
        return null;
      }
      final text = await file.readAsString();
      if (text.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
      return null;
    } catch (e) {
      debugPrint('[GlobalAI] read json failed: ${file.path}, $e');
      return null;
    }
  }

  Future<void> _writeJson(File file, Map<String, dynamic> json) async {
    try {
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(json), flush: true);
    } catch (e) {
      debugPrint('[GlobalAI] write json failed: ${file.path}, $e');
    }
  }
}
