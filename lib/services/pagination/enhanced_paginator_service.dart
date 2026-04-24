// 文件说明：旧分页服务实现，负责按样式把纯文本切分为页面内容。
// 技术要点：服务层、Flutter。

import 'dart:async';
import 'package:flutter/material.dart';

/// 🚀 增强分页器 v2.0 - 高性能版本
///
/// 优化策略：
/// 1. 按最大行数分页，避免每页多次二分测量
/// 2. 向下取整行数，确保不溢出
/// 3. 图片按比例占用页面高度，允许与文本共存
class EnhancedPaginator {
  /// 快速采样分页（仅采样，不启动精确计算）
  static Future<SamplePaginationResult> paginateSample({
    required String text,
    required Size screenSize,
    required double fontSize,
    required double lineHeight,
    required EdgeInsets padding,
    double letterSpacing = 0.0,
    List<String>? fontFamilyFallback,
    String? fontFamily,
    bool supportImages = true,
    int quickSamplePages = 10,
  }) async {
    final sampleResult = await _fastPaginate(
      text: text,
      screenSize: screenSize,
      fontSize: fontSize,
      lineHeight: lineHeight,
      padding: padding,
      letterSpacing: letterSpacing,
      fontFamilyFallback: fontFamilyFallback,
      fontFamily: fontFamily,
      supportImages: supportImages,
      pageLimit: quickSamplePages,
    );

    final sampledPages = sampleResult.pages;
    final avgCharsPerPage = sampledPages.isNotEmpty
        ? sampledPages.fold<int>(0, (sum, page) => sum + page.length) /
            sampledPages.length
        : 500;
    final estimatedTotal = (text.length / avgCharsPerPage).ceil();
    final isComplete = sampledPages.length < quickSamplePages;

    return SamplePaginationResult(
      pages: sampledPages,
      estimatedTotal: isComplete ? sampledPages.length : estimatedTotal,
      pageCharOffsets: sampleResult.pageCharOffsets,
      isComplete: isComplete,
    );
  }

  /// 精确分页（用于后台线程/Isolate）
  static Future<PreciseCalculationResult> paginatePrecise({
    required String text,
    required Size screenSize,
    required double fontSize,
    required double lineHeight,
    required EdgeInsets padding,
    double letterSpacing = 0.0,
    List<String>? fontFamilyFallback,
    String? fontFamily,
    bool supportImages = true,
  }) async {
    return _fastPaginate(
      text: text,
      screenSize: screenSize,
      fontSize: fontSize,
      lineHeight: lineHeight,
      padding: padding,
      letterSpacing: letterSpacing,
      fontFamilyFallback: fontFamilyFallback,
      fontFamily: fontFamily,
      supportImages: supportImages,
    );
  }

  /// 渐进式分页（快速）
  static Future<ProgressivePaginationResult> paginateProgressive({
    required String text,
    required Size screenSize,
    required double fontSize,
    required double lineHeight,
    required EdgeInsets padding,
    double letterSpacing = 0.0,
    List<String>? fontFamilyFallback,
    String? fontFamily,
    bool supportImages = true,
    int quickSamplePages = 10,
  }) async {
    final startTime = DateTime.now();
    debugPrint('\n📖 ===== 开始高性能分页 v2.0 =====');
    debugPrint('   文本长度: ${text.length} 字符');

    // 先快速采样分页，避免大文本卡住UI
    final sampleResult = await _fastPaginate(
      text: text,
      screenSize: screenSize,
      fontSize: fontSize,
      lineHeight: lineHeight,
      padding: padding,
      letterSpacing: letterSpacing,
      fontFamilyFallback: fontFamilyFallback,
      fontFamily: fontFamily,
      supportImages: supportImages,
      pageLimit: quickSamplePages,
    );

    final sampledPages = sampleResult.pages;
    final avgCharsPerPage = sampledPages.isNotEmpty
        ? sampledPages.fold<int>(0, (sum, page) => sum + page.length) /
            sampledPages.length
        : 500;
    final estimatedTotal = (text.length / avgCharsPerPage).ceil();

    // 精确分页放到后台异步执行
    final preciseCalculationFuture = Future<PreciseCalculationResult>(() async {
      await Future.delayed(Duration.zero);
      final result = await _fastPaginate(
        text: text,
        screenSize: screenSize,
        fontSize: fontSize,
        lineHeight: lineHeight,
        padding: padding,
        letterSpacing: letterSpacing,
        fontFamilyFallback: fontFamilyFallback,
        fontFamily: fontFamily,
        supportImages: supportImages,
      );
      final duration = DateTime.now().difference(startTime);
      final speed = duration.inMilliseconds > 0
          ? (text.length / duration.inMilliseconds * 1000).toInt()
          : text.length;

      debugPrint('✅ 分页完成: ${result.pages.length}页');
      debugPrint('   耗时: ${duration.inMilliseconds}ms');
      debugPrint('   速度: $speed 字符/秒');
      return result;
    });

    return ProgressivePaginationResult(
      sampledPages: sampledPages,
      estimatedTotal: estimatedTotal,
      pageCharOffsets: sampleResult.pageCharOffsets,
      preciseCalculationFuture: preciseCalculationFuture,
    );
  }

  /// 🚀 高性能分页（逐页布局）
  static Future<PreciseCalculationResult> _fastPaginate({
    required String text,
    required Size screenSize,
    required double fontSize,
    required double lineHeight,
    required EdgeInsets padding,
    required double letterSpacing,
    List<String>? fontFamilyFallback,
    String? fontFamily,
    required bool supportImages,
    int? pageLimit,
  }) async {
    final availableWidth = screenSize.width - padding.horizontal;
    final availableHeight = screenSize.height - padding.vertical;

    // 🔑 向下取整行数，并预留安全裕度确保不溢出
    final lineHeightPx = fontSize * lineHeight;
    // 🔧 修复：减去 2px 安全裕度，避免浮点精度问题导致最后一行只显示一个字
    final safeHeight = availableHeight - 2.0;
    final maxLines = (safeHeight / lineHeightPx).floor().clamp(1, 9999);
    final actualAvailableHeight = maxLines * lineHeightPx;

    debugPrint(
        '   可用空间: ${availableWidth.toInt()} × ${availableHeight.toInt()}');
    debugPrint('   行高: ${lineHeightPx.toStringAsFixed(1)}px, 最大行数: $maxLines');
    debugPrint('   实际可用高度: ${actualAvailableHeight.toStringAsFixed(1)}');

    final textStyle = TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      letterSpacing: letterSpacing,
      fontFamilyFallback: fontFamilyFallback,
      fontFamily: fontFamily,
    );

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    final pages = <String>[];
    final pageContents = <PageContent>[];
    final pageCharOffsets = <int>[];
    final charsPerLine = (availableWidth / fontSize).floor().clamp(1, 9999);
    final linesPerPage =
        (actualAvailableHeight / lineHeightPx).floor().clamp(1, 9999);
    final estimatedCharsPerPage = charsPerLine * linesPerPage;

    // 解析内容元素
    final contentElements = supportImages
        ? _parseContentElements(text)
        : [ContentElement(isImage: false, content: text, startIndex: 0)];

    final buffer = StringBuffer();
    final currentImages = <ImageElement>[];
    double remainingHeight = actualAvailableHeight;
    int? pageStartOffset;
    const imageHeightRatio = 0.45;
    var stop = false;

    bool reachedLimit() {
      return pageLimit != null && pages.length >= pageLimit;
    }

    void flushPage() {
      if (buffer.isEmpty && currentImages.isEmpty) return;
      pages.add(buffer.toString());
      pageContents.add(PageContent(
        textContent: buffer.toString(),
        images: List<ImageElement>.from(currentImages),
      ));
      pageCharOffsets.add(pageStartOffset ?? 0);
      buffer.clear();
      currentImages.clear();
      remainingHeight = actualAvailableHeight;
      pageStartOffset = null;
      if (reachedLimit()) {
        stop = true;
      }
    }

    for (final element in contentElements) {
      if (stop) break;
      if (element.isImage) {
        final imageHeight = (actualAvailableHeight * imageHeightRatio)
            .clamp(lineHeightPx * 3, actualAvailableHeight);
        if (remainingHeight < imageHeight &&
            (buffer.isNotEmpty || currentImages.isNotEmpty)) {
          flushPage();
          if (stop) break;
        }
        pageStartOffset ??= element.startIndex;
        buffer.write(
          '<img src="${element.content}" data-height="${imageHeight.toStringAsFixed(1)}"/>',
        );
        currentImages.add(ImageElement(
          path: element.content,
          width: availableWidth,
          height: imageHeight,
        ));
        remainingHeight -= imageHeight;
        if (remainingHeight < lineHeightPx) {
          flushPage();
          if (stop) break;
        }
        continue;
      }

      var cursor = 0;
      final textContent = element.content;
      while (cursor < textContent.length) {
        if (stop) break;
        pageStartOffset ??= element.startIndex + cursor;
        final maxLinesForRemaining =
            (remainingHeight / lineHeightPx).floor().clamp(1, maxLines);
        final endIndex = _findPageEnd(
          text: textContent,
          startIndex: cursor,
          estimatedCharsPerPage: estimatedCharsPerPage,
          availableWidth: availableWidth,
          availableHeight: remainingHeight,
          maxLines: maxLinesForRemaining,
          textStyle: textStyle,
          textPainter: textPainter,
        );

        final pageText = textContent.substring(cursor, endIndex);
        buffer.write(pageText);

        textPainter
          ..text = TextSpan(text: pageText, style: textStyle)
          ..maxLines = maxLinesForRemaining
          ..ellipsis = null;
        textPainter.layout(maxWidth: availableWidth);
        final usedHeight = textPainter.height;
        remainingHeight =
            (remainingHeight - usedHeight).clamp(0.0, actualAvailableHeight);

        cursor = endIndex;
        if (cursor < textContent.length) {
          flushPage();
          if (stop) break;
        } else if (remainingHeight < lineHeightPx) {
          flushPage();
          if (stop) break;
        }
      }
    }

    if (!stop) {
      flushPage();
    }

    textPainter.dispose();

    return PreciseCalculationResult(
      pages: pages,
      pageContents: pageContents,
      pageCharOffsets: pageCharOffsets,
    );
  }

  /// 🚀 单次布局找断点（减少重复测量）
  static int _findPageEnd({
    required String text,
    required int startIndex,
    required int estimatedCharsPerPage,
    required double availableWidth,
    required double availableHeight,
    required int maxLines,
    required TextStyle textStyle,
    required TextPainter textPainter,
  }) {
    final remaining = text.length - startIndex;
    if (remaining <= 0) return text.length;

    // 控制切片大小，避免每页都布局超长文本
    int windowChars = estimatedCharsPerPage * 3;
    if (windowChars < 512) {
      windowChars = 512;
    }
    int sliceEnd = startIndex + windowChars;
    if (sliceEnd < startIndex + 1) {
      sliceEnd = startIndex + 1;
    }
    if (sliceEnd > text.length) {
      sliceEnd = text.length;
    }

    String slice = text.substring(startIndex, sliceEnd);
    textPainter
      ..text = TextSpan(text: slice, style: textStyle)
      ..maxLines = maxLines
      ..ellipsis = null;
    textPainter.layout(maxWidth: availableWidth);

    // 切片过短，无法填满页面时，扩展到剩余文本再布局一次
    if (!textPainter.didExceedMaxLines && sliceEnd < text.length) {
      sliceEnd = text.length;
      slice = text.substring(startIndex, sliceEnd);
      textPainter.text = TextSpan(text: slice, style: textStyle);
      textPainter.layout(maxWidth: availableWidth);
    }

    if (!textPainter.didExceedMaxLines) {
      return text.length;
    }

    final double layoutHeight = textPainter.height;
    final double offsetHeight = (layoutHeight - 1).clamp(0.0, availableHeight);
    final position =
        textPainter.getPositionForOffset(Offset(availableWidth, offsetHeight));
    final lineBoundary = textPainter.getLineBoundary(position);
    int endIndex = lineBoundary.end;

    if (endIndex <= 0 || endIndex > slice.length) {
      endIndex = position.offset;
    }
    if (endIndex <= 0) {
      endIndex = 1;
    }

    final absoluteEnd = (startIndex + endIndex).clamp(
      startIndex + 1,
      text.length,
    );

    // 智能断行
    return _adjustBreakpoint(text, startIndex, absoluteEnd);
  }

  /// 智能断行（已禁用：直接返回断点，不寻找标点符号）
  static int _adjustBreakpoint(String text, int startIndex, int breakpoint) {
    if (breakpoint >= text.length) return text.length;
    if (breakpoint <= startIndex) return (startIndex + 1).clamp(0, text.length);

    // 🔧 直接返回断点，不再寻找标点符号
    return breakpoint;
  }

  /// 解析内容元素
  static List<ContentElement> _parseContentElements(String text) {
    final elements = <ContentElement>[];
    final imgPattern = RegExp(r'<img\s+[^>]*src="([^"]+)"[^>]*?>');

    int lastIndex = 0;
    for (final match in imgPattern.allMatches(text)) {
      if (match.start > lastIndex) {
        final textContent = text.substring(lastIndex, match.start);
        if (textContent.isNotEmpty) {
          elements.add(ContentElement(
            isImage: false,
            content: textContent,
            startIndex: lastIndex,
          ));
        }
      }

      final imagePath = match.group(1);
      if (imagePath != null && imagePath.isNotEmpty) {
        elements.add(ContentElement(
          isImage: true,
          content: imagePath,
          startIndex: match.start,
        ));
      }
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      final textContent = text.substring(lastIndex);
      if (textContent.isNotEmpty) {
        elements.add(ContentElement(
          isImage: false,
          content: textContent,
          startIndex: lastIndex,
        ));
      }
    }

    return elements.isEmpty
        ? [ContentElement(isImage: false, content: text, startIndex: 0)]
        : elements;
  }
}

class ContentElement {
  final bool isImage;
  final String content;
  final int startIndex;
  ContentElement({
    required this.isImage,
    required this.content,
    required this.startIndex,
  });
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
  final List<int> pageCharOffsets;
  PreciseCalculationResult({
    required this.pages,
    required this.pageContents,
    required this.pageCharOffsets,
  });
}

class ProgressivePaginationResult {
  final List<String> sampledPages;
  final int estimatedTotal;
  final List<int> pageCharOffsets;
  final Future<PreciseCalculationResult> preciseCalculationFuture;
  ProgressivePaginationResult({
    required this.sampledPages,
    required this.estimatedTotal,
    required this.pageCharOffsets,
    required this.preciseCalculationFuture,
  });
}

class SamplePaginationResult {
  final List<String> pages;
  final int estimatedTotal;
  final List<int> pageCharOffsets;
  final bool isComplete;

  SamplePaginationResult({
    required this.pages,
    required this.estimatedTotal,
    required this.pageCharOffsets,
    required this.isComplete,
  });
}
