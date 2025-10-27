import 'dart:async';
import 'package:flutter/material.dart';

/// 增强分页器 - 批量测量 + 精确填充 + 图片支持
class EnhancedPaginator {
  static void Function(int currentPage, String stage)? _onProgress;

  /// 渐进式分页
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

    debugPrint('\n📖 ===== 开始快速分页 =====');
    debugPrint('   文本长度: ${text.length} 字符');

    final startTime = DateTime.now();

    // 直接使用批量分页（快速）
    final result = await _batchPaginate(
      text: text,
      screenSize: screenSize,
      fontSize: fontSize,
      lineHeight: lineHeight,
      padding: padding,
      letterSpacing: letterSpacing,
      supportImages: supportImages,
      sampleSize: quickSamplePages,
    );

    final duration = DateTime.now().difference(startTime);
    debugPrint('✅ 分页完成: ${result.pages.length}页');
    debugPrint('   耗时: ${duration.inMilliseconds}ms');
    debugPrint(
        '   速度: ${(text.length / duration.inMilliseconds * 1000).toInt()} 字符/秒');

    // 快速估算：使用采样页
    final sampledPages = result.pages.take(quickSamplePages).toList();
    final avgCharsPerPage =
        sampledPages.fold<int>(0, (sum, page) => sum + page.length) /
            sampledPages.length;
    final estimatedTotal = (text.length / avgCharsPerPage).ceil();

    return ProgressivePaginationResult(
      sampledPages: sampledPages,
      estimatedTotal: estimatedTotal,
      preciseCalculationFuture: Future.value(result),
    );
  }

  /// 批量分页（高性能 + 图片支持）
  static Future<PreciseCalculationResult> _batchPaginate({
    required String text,
    required Size screenSize,
    required double fontSize,
    required double lineHeight,
    required EdgeInsets padding,
    required double letterSpacing,
    required bool supportImages,
    int sampleSize = 10,
  }) async {
    final availableWidth = screenSize.width - padding.horizontal;
    final availableHeight = screenSize.height - padding.vertical;

    final textStyle = TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      letterSpacing: letterSpacing,
    );

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left, // 关键：与渲染一致
    );

    final pages = <String>[];
    final pageContents = <PageContent>[];

    // 🖼️ 解析内容元素（文本和图片）
    final contentElements = supportImages
        ? _parseContentElements(text)
        : [ContentElement(isImage: false, content: text)];

    debugPrint('📋 解析内容: ${contentElements.length} 个元素');

    // 分页处理每个内容元素
    for (final element in contentElements) {
      if (pages.length % 10 == 0) {
        _reportProgress(pages.length, '分页中...');
      }

      if (element.isImage) {
        // 🖼️ 图片独占一页
        debugPrint('🖼️ 处理图片: ${element.content}');
        pages.add(''); // 空文本内容
        pageContents.add(PageContent(
          textContent: '',
          images: [
            ImageElement(
              path: element.content,
              width: availableWidth,
              height: availableHeight,
            )
          ],
        ));
        continue;
      }

      // 📝 处理纯文本分页
      final textContent = element.content;
      int startIndex = 0;
      int batchSize = 500; // 每次测量500字符

      while (startIndex < textContent.length) {
        // 批量测试：先测试一大块
        int endIndex = (startIndex + batchSize).clamp(0, textContent.length);
        String testText = textContent.substring(startIndex, endIndex);

        textPainter.text = TextSpan(text: testText, style: textStyle);
        textPainter.layout(maxWidth: availableWidth);

        if (textPainter.height <= availableHeight) {
          // 放得下，继续加字符
          while (endIndex < textContent.length) {
            final nextChar = textContent[endIndex];
            final newText = testText + nextChar;

            textPainter.text = TextSpan(text: newText, style: textStyle);
            textPainter.layout(maxWidth: availableWidth);

            if (textPainter.height > availableHeight) {
              // 超出了，停止
              break;
            }

            testText = newText;
            endIndex++;
          }

          // 保存这一页
          pages.add(testText);
          pageContents.add(PageContent(textContent: testText, images: []));
          startIndex = endIndex;
        } else {
          // 放不下，缩小范围（二分查找）
          int left = startIndex;
          int right = endIndex;

          while (left < right) {
            int mid = (left + right + 1) ~/ 2;
            testText = textContent.substring(startIndex, mid);

            textPainter.text = TextSpan(text: testText, style: textStyle);
            textPainter.layout(maxWidth: availableWidth);

            if (textPainter.height <= availableHeight) {
              left = mid;
            } else {
              right = mid - 1;
            }
          }

          if (left > startIndex) {
            testText = textContent.substring(startIndex, left);
            pages.add(testText);
            pageContents.add(PageContent(textContent: testText, images: []));
            startIndex = left;
          } else {
            // 至少放一个字符（极端情况）
            testText = textContent.substring(startIndex, startIndex + 1);
            pages.add(testText);
            pageContents.add(PageContent(textContent: testText, images: []));
            startIndex++;
          }
        }
      }
    }

    textPainter.dispose();

    return PreciseCalculationResult(
      pages: pages,
      pageContents: pageContents,
    );
  }

  static void _reportProgress(int currentPage, String stage) {
    if (_onProgress != null && currentPage % 10 == 0) {
      _onProgress!(currentPage, stage);
    }
  }

  /// 解析内容元素（提取文本和图片）
  ///
  /// 将文本中的图片标签解析为独立元素
  /// 图片标签格式：<img src="path"/>
  static List<ContentElement> _parseContentElements(String text) {
    final elements = <ContentElement>[];
    final imgPattern = RegExp(r'<img\s+src="([^"]+)"\s*/?>');

    int lastIndex = 0;
    for (final match in imgPattern.allMatches(text)) {
      // 添加图片前的文本
      if (match.start > lastIndex) {
        final textContent = text.substring(lastIndex, match.start);
        if (textContent.isNotEmpty) {
          elements.add(ContentElement(isImage: false, content: textContent));
        }
      }

      // 添加图片
      final imagePath = match.group(1);
      if (imagePath != null && imagePath.isNotEmpty) {
        elements.add(ContentElement(isImage: true, content: imagePath));
        debugPrint('   📸 发现图片: $imagePath');
      }

      lastIndex = match.end;
    }

    // 添加最后的文本
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
