import 'dart:async';
import 'package:flutter/material.dart';

/// 🚀 增强分页器 v2.0 - 高性能版本
///
/// 优化策略：
/// 1. 纯二分法分页（不逐字符测量）
/// 2. 向下取整行数，确保不溢出
/// 3. 图片独占一页
class EnhancedPaginator {
  static void Function(int currentPage, String stage)? _onProgress;

  /// 渐进式分页（快速）
  static Future<ProgressivePaginationResult> paginateProgressive({
    required String text,
    required Size screenSize,
    required double fontSize,
    required double lineHeight,
    required EdgeInsets padding,
    double letterSpacing = 0.0,
    bool supportImages = true,
    int quickSamplePages = 10,
    Function(int currentPage, String stage)? onProgress,
  }) async {
    _onProgress = onProgress;

    final startTime = DateTime.now();
    debugPrint('\n📖 ===== 开始高性能分页 v2.0 =====');
    debugPrint('   文本长度: ${text.length} 字符');

    // 直接使用高性能分页
    final result = await _fastPaginate(
      text: text,
      screenSize: screenSize,
      fontSize: fontSize,
      lineHeight: lineHeight,
      padding: padding,
      letterSpacing: letterSpacing,
      supportImages: supportImages,
    );

    final duration = DateTime.now().difference(startTime);
    final speed = duration.inMilliseconds > 0
        ? (text.length / duration.inMilliseconds * 1000).toInt()
        : text.length;

    debugPrint('✅ 分页完成: ${result.pages.length}页');
    debugPrint('   耗时: ${duration.inMilliseconds}ms');
    debugPrint('   速度: $speed 字符/秒');

    // 返回结果
    final sampledPages = result.pages.take(quickSamplePages).toList();
    final avgCharsPerPage = sampledPages.isNotEmpty
        ? sampledPages.fold<int>(0, (sum, page) => sum + page.length) /
            sampledPages.length
        : 500;
    final estimatedTotal = (text.length / avgCharsPerPage).ceil();

    return ProgressivePaginationResult(
      sampledPages: result.pages, // 返回所有页（已经很快了）
      estimatedTotal: estimatedTotal,
      preciseCalculationFuture: Future.value(result),
    );
  }

  /// 🚀 高性能分页（纯二分法）
  static Future<PreciseCalculationResult> _fastPaginate({
    required String text,
    required Size screenSize,
    required double fontSize,
    required double lineHeight,
    required EdgeInsets padding,
    required double letterSpacing,
    required bool supportImages,
  }) async {
    final availableWidth = screenSize.width - padding.horizontal;
    final availableHeight = screenSize.height - padding.vertical;

    // 🔑 向下取整行数，确保不溢出
    final lineHeightPx = fontSize * lineHeight;
    final maxLines = (availableHeight / lineHeightPx).floor();
    final actualAvailableHeight = maxLines * lineHeightPx;

    debugPrint(
        '   可用空间: ${availableWidth.toInt()} × ${availableHeight.toInt()}');
    debugPrint('   行高: ${lineHeightPx.toStringAsFixed(1)}px, 最大行数: $maxLines');
    debugPrint('   实际可用高度: ${actualAvailableHeight.toStringAsFixed(1)}');

    final textStyle = TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      letterSpacing: letterSpacing,
    );

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
      strutStyle: StrutStyle(
        fontSize: fontSize,
        height: lineHeight,
        forceStrutHeight: true,
      ),
    );

    final pages = <String>[];
    final pageContents = <PageContent>[];

    // 解析内容元素
    final contentElements = supportImages
        ? _parseContentElements(text)
        : [ContentElement(isImage: false, content: text)];

    for (final element in contentElements) {
      if (element.isImage) {
        // 图片独占一页
        pages.add('<img src="${element.content}"/>');
        pageContents.add(PageContent(
          textContent: '',
          images: [
            ImageElement(
                path: element.content,
                width: availableWidth,
                height: actualAvailableHeight)
          ],
        ));
        continue;
      }

      // 🚀 纯二分法分页
      await _paginateTextFast(
        text: element.content,
        availableWidth: availableWidth,
        availableHeight: actualAvailableHeight,
        textStyle: textStyle,
        textPainter: textPainter,
        pages: pages,
        pageContents: pageContents,
      );
    }

    textPainter.dispose();

    return PreciseCalculationResult(
      pages: pages,
      pageContents: pageContents,
    );
  }

  /// 🚀 纯二分法文本分页（不逐字符）
  static Future<void> _paginateTextFast({
    required String text,
    required double availableWidth,
    required double availableHeight,
    required TextStyle textStyle,
    required TextPainter textPainter,
    required List<String> pages,
    required List<PageContent> pageContents,
  }) async {
    if (text.isEmpty) return;

    int startIndex = 0;
    int pageCount = 0;

    // 估算每页字符数（用于初始猜测）
    final charsPerLine = (availableWidth / textStyle.fontSize!).floor();
    final linesPerPage =
        (availableHeight / (textStyle.fontSize! * (textStyle.height ?? 1.5)))
            .floor();
    final estimatedCharsPerPage = charsPerLine * linesPerPage;

    while (startIndex < text.length) {
      // 二分法找断点
      final endIndex = _binarySearchBreakpoint(
        text: text,
        startIndex: startIndex,
        estimatedCharsPerPage: estimatedCharsPerPage,
        availableWidth: availableWidth,
        availableHeight: availableHeight,
        textStyle: textStyle,
        textPainter: textPainter,
      );

      final pageText = text.substring(startIndex, endIndex);
      pages.add(pageText);
      pageContents.add(PageContent(textContent: pageText, images: []));

      startIndex = endIndex;
      pageCount++;

      // 每50页让出CPU
      if (pageCount % 50 == 0) {
        _reportProgress(pages.length, '分页中...');
        await Future.delayed(Duration.zero);
      }
    }
  }

  /// 🚀 二分查找断点
  static int _binarySearchBreakpoint({
    required String text,
    required int startIndex,
    required int estimatedCharsPerPage,
    required double availableWidth,
    required double availableHeight,
    required TextStyle textStyle,
    required TextPainter textPainter,
  }) {
    final remaining = text.length - startIndex;
    if (remaining <= 0) return text.length;

    // 初始范围
    int low = startIndex;
    int high =
        (startIndex + estimatedCharsPerPage * 2).clamp(startIndex, text.length);
    if (high <= low) high = (low + 1).clamp(low, text.length);

    int bestBreakpoint = low + 1;

    // 二分查找
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      final testText = text.substring(startIndex, mid);

      textPainter.text = TextSpan(text: testText, style: textStyle);
      textPainter.layout(maxWidth: availableWidth);

      if (textPainter.height <= availableHeight) {
        bestBreakpoint = mid;
        low = mid;
      } else {
        high = mid - 1;
      }
    }

    // 智能断行
    return _adjustBreakpoint(text, startIndex, bestBreakpoint);
  }

  /// 智能断行
  static int _adjustBreakpoint(String text, int startIndex, int breakpoint) {
    if (breakpoint >= text.length) return text.length;
    if (breakpoint <= startIndex) return (startIndex + 1).clamp(0, text.length);

    final searchStart = (breakpoint - 15).clamp(startIndex, breakpoint);
    for (int i = breakpoint - 1; i >= searchStart; i--) {
      final char = text[i];
      if ('。！？.!?；;，,、：:）)】」』"\'"\n\r '.contains(char)) {
        return i + 1;
      }
    }
    return breakpoint;
  }

  static void _reportProgress(int currentPage, String stage) {
    if (_onProgress != null) {
      _onProgress!(currentPage, stage);
    }
  }

  /// 解析内容元素
  static List<ContentElement> _parseContentElements(String text) {
    final elements = <ContentElement>[];
    final imgPattern = RegExp(r'<img\s+src="([^"]+)"\s*/?>');

    int lastIndex = 0;
    for (final match in imgPattern.allMatches(text)) {
      if (match.start > lastIndex) {
        final textContent = text.substring(lastIndex, match.start);
        if (textContent.isNotEmpty) {
          elements.add(ContentElement(isImage: false, content: textContent));
        }
      }

      final imagePath = match.group(1);
      if (imagePath != null && imagePath.isNotEmpty) {
        elements.add(ContentElement(isImage: true, content: imagePath));
      }
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      final textContent = text.substring(lastIndex);
      if (textContent.isNotEmpty) {
        elements.add(ContentElement(isImage: false, content: textContent));
      }
    }

    return elements.isEmpty
        ? [ContentElement(isImage: false, content: text)]
        : elements;
  }
}

class ContentElement {
  final bool isImage;
  final String content;
  ContentElement({required this.isImage, required this.content});
}

class ImageElement {
  final String path;
  final double width;
  final double height;
  ImageElement({required this.path, required this.width, required this.height});
}

class PageContent {
  final String textContent;
  final List<ImageElement> images;
  PageContent({required this.textContent, required this.images});
}

class QuickEstimateResult {
  final List<String> sampledPages;
  final List<PageContent> pageContents;
  final double avgCharsPerPage;
  final int estimatedTotal;
  QuickEstimateResult({
    required this.sampledPages,
    required this.pageContents,
    required this.avgCharsPerPage,
    required this.estimatedTotal,
  });
}

class PreciseCalculationResult {
  final List<String> pages;
  final List<PageContent> pageContents;
  PreciseCalculationResult({required this.pages, required this.pageContents});
}

class ProgressivePaginationResult {
  final List<String> sampledPages;
  final int estimatedTotal;
  final Future<PreciseCalculationResult> preciseCalculationFuture;
  ProgressivePaginationResult({
    required this.sampledPages,
    required this.estimatedTotal,
    required this.preciseCalculationFuture,
  });
}
