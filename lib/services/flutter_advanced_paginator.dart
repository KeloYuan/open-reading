import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Flutter原生高级文本分页器
/// 基于anx-reader原理，使用Flutter原生Widget实现精确分页
class FlutterAdvancedPaginator {
  /// 分页配置
  static PaginationResult paginateText({
    required String text,
    required Size screenSize,
    required TextStyle textStyle,
    required EdgeInsets padding,
    bool preserveWordBoundaries = true,
    int maxPages = 10000,
  }) {
    if (text.isEmpty) {
      return PaginationResult(pages: [''], metadata: PaginationMetadata());
    }

    final availableWidth = screenSize.width - padding.horizontal;
    final availableHeight = screenSize.height - padding.vertical;

    // 创建TextPainter来测量文本
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.justify,
      maxLines: null,
    );

    // 计算每页可容纳的最大字符数（估算）
    final estimatedCharsPerPage = _estimateCharsPerPage(
      availableWidth: availableWidth,
      availableHeight: availableHeight,
      textStyle: textStyle,
      sampleText: text.length > 100 ? text.substring(0, 100) : text,
    );

    debugPrint('🔥 Flutter高级分页器启动');
    debugPrint(
      '📏 可用区域: ${availableWidth.toInt()}x${availableHeight.toInt()}px',
    );
    debugPrint('📊 预估每页字符数: $estimatedCharsPerPage');

    final pages = <String>[];
    final pageBreakPositions = <int>[];
    final chapterBoundaries = <ChapterBoundary>[];

    // 分割章节
    final chapters = _splitIntoChapters(text);
    int globalTextPosition = 0;

    for (int chapterIndex = 0; chapterIndex < chapters.length; chapterIndex++) {
      final chapter = chapters[chapterIndex];
      final chapterStartPage = pages.length;

      chapterBoundaries.add(
        ChapterBoundary(
          chapterIndex: chapterIndex,
          title: chapter.title,
          startPage: chapterStartPage,
          startPosition: globalTextPosition,
        ),
      );

      // 分割章节内容为页面
      final chapterPages = _paginateChapter(
        content: chapter.content,
        availableWidth: availableWidth,
        availableHeight: availableHeight,
        textStyle: textStyle,
        textPainter: textPainter,
        estimatedCharsPerPage: estimatedCharsPerPage,
        preserveWordBoundaries: preserveWordBoundaries,
        startPosition: globalTextPosition,
      );

      pages.addAll(chapterPages.pages);
      pageBreakPositions.addAll(chapterPages.breakPositions);

      globalTextPosition += chapter.content.length;

      // 更新章节结束页
      if (chapterBoundaries.isNotEmpty) {
        chapterBoundaries.last = chapterBoundaries.last.copyWith(
          endPage: pages.length - 1,
          endPosition: globalTextPosition,
        );
      }

      if (pages.length >= maxPages) {
        debugPrint('⚠️ 达到最大页数限制: $maxPages');
        break;
      }
    }

    textPainter.dispose();

    final metadata = PaginationMetadata(
      totalPages: pages.length,
      totalCharacters: text.length,
      pageBreakPositions: pageBreakPositions,
      chapterBoundaries: chapterBoundaries,
      avgCharsPerPage: text.length / pages.length,
    );

    debugPrint('✅ 分页完成: ${pages.length}页');
    debugPrint('📈 平均每页字符数: ${metadata.avgCharsPerPage.toStringAsFixed(0)}');

    return PaginationResult(pages: pages, metadata: metadata);
  }

  /// 估算每页字符数
  static int _estimateCharsPerPage({
    required double availableWidth,
    required double availableHeight,
    required TextStyle textStyle,
    required String sampleText,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: sampleText, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.justify,
    );

    textPainter.layout(maxWidth: availableWidth);

    final singleLineHeight = textPainter.size.height;
    final linesPerPage = (availableHeight / singleLineHeight).floor();
    final charsPerLine =
        (sampleText.length * availableWidth / textPainter.size.width).floor();

    textPainter.dispose();

    // 保守估计，减少10%以确保不溢出
    final estimatedChars = (linesPerPage * charsPerLine * 0.9).floor();
    return math.max(estimatedChars, 100); // 最少100字符
  }

  /// 分割章节
  static List<TextChapter> _splitIntoChapters(String text) {
    final chapters = <TextChapter>[];
    final lines = text.split('\n');

    String? currentTitle;
    final currentContent = StringBuffer();

    for (final line in lines) {
      final trimmedLine = line.trim();

      // 检测章节标题
      if (_isChapterTitle(trimmedLine)) {
        // 保存之前的章节
        if (currentContent.isNotEmpty) {
          chapters.add(
            TextChapter(
              title: currentTitle ?? '章节 ${chapters.length + 1}',
              content: currentContent.toString().trim(),
            ),
          );
          currentContent.clear();
        }

        currentTitle = trimmedLine;
      } else if (trimmedLine.isNotEmpty) {
        if (currentContent.isNotEmpty) {
          currentContent.writeln();
        }
        currentContent.writeln(trimmedLine);
      }
    }

    // 添加最后一个章节
    if (currentContent.isNotEmpty) {
      chapters.add(
        TextChapter(
          title: currentTitle ?? '章节 ${chapters.length + 1}',
          content: currentContent.toString().trim(),
        ),
      );
    }

    // 如果没有检测到章节，整个文本作为一章
    if (chapters.isEmpty) {
      chapters.add(TextChapter(title: '正文', content: text.trim()));
    }

    return chapters;
  }

  /// 判断是否为章节标题
  static bool _isChapterTitle(String line) {
    if (line.isEmpty || line.length > 50) return false;

    // 常见的章节标题模式
    final chapterPatterns = [
      RegExp(r'^第.{1,10}[章节]'),
      RegExp(r'^Chapter\s+\d+', caseSensitive: false),
      RegExp(r'^\d+\.'),
      RegExp(r'^[一二三四五六七八九十]+、'),
    ];

    return chapterPatterns.any((pattern) => pattern.hasMatch(line));
  }

  /// 分页单个章节
  static ChapterPaginationResult _paginateChapter({
    required String content,
    required double availableWidth,
    required double availableHeight,
    required TextStyle textStyle,
    required TextPainter textPainter,
    required int estimatedCharsPerPage,
    required bool preserveWordBoundaries,
    required int startPosition,
  }) {
    final pages = <String>[];
    final breakPositions = <int>[];

    int currentPosition = 0;
    int pageCount = 0;
    const maxPagesPerChapter = 1000;

    while (currentPosition < content.length && pageCount < maxPagesPerChapter) {
      final pageResult = _createSinglePage(
        content: content,
        startIndex: currentPosition,
        availableWidth: availableWidth,
        availableHeight: availableHeight,
        textStyle: textStyle,
        textPainter: textPainter,
        estimatedCharsPerPage: estimatedCharsPerPage,
        preserveWordBoundaries: preserveWordBoundaries,
      );

      if (pageResult.content.isEmpty) {
        // 防止无限循环
        currentPosition++;
        continue;
      }

      pages.add(pageResult.content);
      breakPositions.add(startPosition + pageResult.endIndex);

      currentPosition = pageResult.endIndex;
      pageCount++;
    }

    return ChapterPaginationResult(
      pages: pages,
      breakPositions: breakPositions,
    );
  }

  /// 创建单个页面
  static PageCreationResult _createSinglePage({
    required String content,
    required int startIndex,
    required double availableWidth,
    required double availableHeight,
    required TextStyle textStyle,
    required TextPainter textPainter,
    required int estimatedCharsPerPage,
    required bool preserveWordBoundaries,
  }) {
    if (startIndex >= content.length) {
      return PageCreationResult(content: '', endIndex: content.length);
    }

    // 计算初始结束位置
    int endIndex = math.min(startIndex + estimatedCharsPerPage, content.length);

    // 二分查找最优断点
    int left = startIndex + (estimatedCharsPerPage * 0.5).floor();
    int right = math.min(
      startIndex + (estimatedCharsPerPage * 1.5).floor(),
      content.length,
    );

    left = math.max(left, startIndex + 1);
    right = math.max(right, left + 1);

    int bestEndIndex = endIndex;

    // 使用二分查找找到最佳断点
    while (left <= right) {
      final mid = (left + right) ~/ 2;
      final testContent = content.substring(startIndex, mid);

      if (_fitsInPage(
        testContent,
        availableWidth,
        availableHeight,
        textStyle,
        textPainter,
      )) {
        bestEndIndex = mid;
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    // 确保页面不为空
    if (bestEndIndex <= startIndex) {
      bestEndIndex = math.min(startIndex + 1, content.length);
    }

    // 寻找最佳文本断点
    if (preserveWordBoundaries && bestEndIndex < content.length) {
      bestEndIndex = _findOptimalBreakPoint(content, startIndex, bestEndIndex);
    }

    final pageContent = content.substring(startIndex, bestEndIndex);
    return PageCreationResult(content: pageContent, endIndex: bestEndIndex);
  }

  /// 检查文本是否适合页面
  static bool _fitsInPage(
    String text,
    double availableWidth,
    double availableHeight,
    TextStyle textStyle,
    TextPainter textPainter,
  ) {
    if (text.isEmpty) return true;

    textPainter.text = TextSpan(text: text, style: textStyle);
    textPainter.layout(maxWidth: availableWidth);

    return textPainter.size.height <= availableHeight;
  }

  /// 寻找最佳断点
  static int _findOptimalBreakPoint(
    String content,
    int startIndex,
    int suggestedEndIndex,
  ) {
    if (suggestedEndIndex >= content.length) {
      return content.length;
    }

    // 搜索范围
    const searchRange = 50;
    final searchStart = math.max(startIndex, suggestedEndIndex - searchRange);
    final searchEnd = math.min(
      content.length,
      suggestedEndIndex + searchRange ~/ 2,
    );

    // 断点优先级
    final breakPriorities = [
      // 段落分隔 - 最高优先级
      RegExp(r'\n\s*\n'),
      // 句子结束 - 高优先级
      RegExp(r'[。！？.!?]\s*'),
      // 逗号、分号 - 中等优先级
      RegExp(r'[，；,;]\s*'),
      // 空格 - 低优先级
      RegExp(r'\s+'),
    ];

    // 按优先级查找最佳断点
    for (final pattern in breakPriorities) {
      final matches = pattern.allMatches(content, searchStart);

      for (final match in matches) {
        final breakPoint = match.end;
        if (breakPoint > startIndex && breakPoint <= searchEnd) {
          // 确保断点不会造成页面过小
          if (breakPoint - startIndex >=
              (suggestedEndIndex - startIndex) * 0.6) {
            return breakPoint;
          }
        }
      }
    }

    // 如果没找到合适的断点，返回建议的结束位置
    return suggestedEndIndex;
  }
}

/// 文本章节
class TextChapter {
  final String title;
  final String content;

  const TextChapter({required this.title, required this.content});
}

/// 章节边界
class ChapterBoundary {
  final int chapterIndex;
  final String title;
  final int startPage;
  final int? endPage;
  final int startPosition;
  final int? endPosition;

  const ChapterBoundary({
    required this.chapterIndex,
    required this.title,
    required this.startPage,
    this.endPage,
    required this.startPosition,
    this.endPosition,
  });

  ChapterBoundary copyWith({
    int? chapterIndex,
    String? title,
    int? startPage,
    int? endPage,
    int? startPosition,
    int? endPosition,
  }) {
    return ChapterBoundary(
      chapterIndex: chapterIndex ?? this.chapterIndex,
      title: title ?? this.title,
      startPage: startPage ?? this.startPage,
      endPage: endPage ?? this.endPage,
      startPosition: startPosition ?? this.startPosition,
      endPosition: endPosition ?? this.endPosition,
    );
  }
}

/// 分页结果
class PaginationResult {
  final List<String> pages;
  final PaginationMetadata metadata;

  const PaginationResult({required this.pages, required this.metadata});
}

/// 分页元数据
class PaginationMetadata {
  final int totalPages;
  final int totalCharacters;
  final List<int> pageBreakPositions;
  final List<ChapterBoundary> chapterBoundaries;
  final double avgCharsPerPage;

  const PaginationMetadata({
    this.totalPages = 0,
    this.totalCharacters = 0,
    this.pageBreakPositions = const [],
    this.chapterBoundaries = const [],
    this.avgCharsPerPage = 0.0,
  });

  /// 获取指定页码的章节信息
  ChapterBoundary? getChapterForPage(int pageIndex) {
    for (final chapter in chapterBoundaries) {
      if (pageIndex >= chapter.startPage &&
          (chapter.endPage == null || pageIndex <= chapter.endPage!)) {
        return chapter;
      }
    }
    return null;
  }

  /// 计算阅读进度
  double getProgressForPage(int pageIndex) {
    if (totalPages <= 0) return 0.0;
    return (pageIndex + 1) / totalPages;
  }

  /// 根据进度获取页码
  int getPageForProgress(double progress) {
    if (totalPages <= 0) return 0;
    final page = (progress * totalPages).round() - 1;
    return math.max(0, math.min(page, totalPages - 1));
  }
}

/// 章节分页结果
class ChapterPaginationResult {
  final List<String> pages;
  final List<int> breakPositions;

  const ChapterPaginationResult({
    required this.pages,
    required this.breakPositions,
  });
}

/// 页面创建结果
class PageCreationResult {
  final String content;
  final int endIndex;

  const PageCreationResult({required this.content, required this.endIndex});
}

/// 搜索结果
class TextSearchResult {
  final int pageIndex;
  final int position;
  final String context;
  final String query;

  const TextSearchResult({
    required this.pageIndex,
    required this.position,
    required this.context,
    required this.query,
  });
}

/// 搜索工具
class TextSearchHelper {
  /// 在分页结果中搜索文本
  static List<TextSearchResult> searchInPages({
    required List<String> pages,
    required String query,
    int contextLength = 50,
  }) {
    if (query.isEmpty) return [];

    final results = <TextSearchResult>[];
    final queryLower = query.toLowerCase();

    for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final page = pages[pageIndex];
      final pageLower = page.toLowerCase();

      int searchStart = 0;
      while (true) {
        final foundIndex = pageLower.indexOf(queryLower, searchStart);
        if (foundIndex == -1) break;

        // 获取上下文
        final contextStart = math.max(0, foundIndex - contextLength);
        final contextEnd = math.min(
          page.length,
          foundIndex + query.length + contextLength,
        );
        final context = page.substring(contextStart, contextEnd);

        results.add(
          TextSearchResult(
            pageIndex: pageIndex,
            position: foundIndex,
            context: context,
            query: query,
          ),
        );

        searchStart = foundIndex + 1;
      }
    }

    return results;
  }
}
