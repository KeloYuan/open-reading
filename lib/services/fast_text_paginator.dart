import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 分页进度回调
typedef FastPaginationProgressCallback = void Function(
    int currentPage, String stage);

/// 页面内容元素类型
enum PageElementType {
  text, // 文本内容
  image, // 图片内容
}

/// 页面内容元素
class PageElement {
  final PageElementType type;
  final String content; // 文本内容或图片URL
  final double? width; // 图片宽度（可选）
  final double? height; // 图片高度（可选）

  const PageElement.text(this.content)
      : type = PageElementType.text,
        width = null,
        height = null;

  const PageElement.image(this.content, {this.width, this.height})
      : type = PageElementType.image;
}

/// 分页结果
class FastPaginationResult {
  /// 分页后的文本页面列表
  final List<String> pages;

  /// 每页在原文中的字符起始位置
  final List<int> charOffsets;

  /// 每页的内容元素列表（包含文本和图片）
  final List<List<PageElement>>? pageElements;

  /// 每页的额外行间距（用于底部对齐）
  /// 如果启用底部对齐，这个值会被添加到每行的间距中
  final List<double>? pageExtraLineSpacing;

  const FastPaginationResult({
    required this.pages,
    required this.charOffsets,
    this.pageElements,
    this.pageExtraLineSpacing,
  });
}

/// 快速文本分页器
///
/// 使用精确的逐行填充算法，确保每页都正好填满指定的行数
class FastTextPaginator {
  /// 精确分页（动态测量版本 - 支持图片，准确处理所有字符）
  ///
  /// 核心逻辑：
  /// 1. 使用 TextPainter 动态测量每段文本的实际高度
  /// 2. 支持图片（保留图片标签）
  /// 3. 保守地填充每一页，保证不超出屏幕
  static Future<FastPaginationResult> paginateAccurate({
    required String text,
    required Size screenSize,
    required double fontSize,
    required double lineSpacing,
    required EdgeInsets padding,
    double letterSpacing = 0.0,
    double firstLineIndent = 0.0,
    double devicePixelRatio = 1.0,
    bool supportImages = true,
    FastPaginationProgressCallback? onProgress,
  }) async {
    if (text.isEmpty) {
      return const FastPaginationResult(pages: [], charOffsets: []);
    }

    // 预处理文本：规范化空行
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 计算可用空间
    final visibleWidth = screenSize.width - padding.left - padding.right;
    final visibleHeight = screenSize.height - padding.top - padding.bottom;

    // 创建 TextPainter 用于精确测量
    final textStyle = TextStyle(
      fontSize: fontSize,
      letterSpacing: letterSpacing,
      height: lineSpacing,
    );
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
    );

    // 测量基础行高
    textPainter.text = TextSpan(text: '测', style: textStyle);
    textPainter.layout();
    final baseLineHeight = textPainter.height;

    // 根据字体大小调整安全边距
    double safetyMargin = baseLineHeight * 1.5; // 默认1.5行
    if (fontSize >= 26) {
      safetyMargin = baseLineHeight * 2.5; // 大字体留2.5行
    } else if (fontSize >= 22) {
      safetyMargin = baseLineHeight * 2.0;
    }

    final effectiveHeight = visibleHeight - safetyMargin;

    debugPrint('📄 精确分页（动态测量）:');
    debugPrint(
        '   屏幕: ${screenSize.width.toInt()}×${screenSize.height.toInt()}px');
    debugPrint('   可用: ${visibleWidth.toInt()}×${visibleHeight.toInt()}px');
    debugPrint(
        '   字体: ${fontSize}px, 行距: ${lineSpacing}x, 字间距: ${letterSpacing}px');
    debugPrint(
        '   基础行高: ${baseLineHeight.toStringAsFixed(1)}px, 安全边距: ${safetyMargin.toStringAsFixed(1)}px');
    debugPrint('   有效高度: ${effectiveHeight.toStringAsFixed(1)}px');

    final List<String> pages = [];
    final List<int> charOffsets = [];
    final List<List<PageElement>> pageElements = [];

    int currentIndex = 0;
    double currentY = 0.0;
    final StringBuffer pageBuffer = StringBuffer();
    final List<PageElement> currentPageElements = [];

    // 图片正则 (匹配 <img src="..."> 或 <img src='...'>)
    final imgPattern = RegExp('<img\\s+src=["\']([^"\']+)["\'][^>]*>');

    onProgress?.call(0, '正在分页...');

    /// 完成当前页
    void finishPage() {
      if (pageBuffer.isNotEmpty || currentPageElements.isNotEmpty) {
        final content = pageBuffer.toString();
        if (content.trim().isNotEmpty ||
            currentPageElements.any((e) => e.type == PageElementType.image)) {
          pages.add(content);
          pageElements.add(List.from(currentPageElements));
        }
        pageBuffer.clear();
        currentPageElements.clear();
        currentY = 0.0;
      }
    }

    /// 尝试添加文本，返回是否成功
    bool tryAddText(String textToAdd) {
      if (textToAdd.isEmpty) return true;

      // 测量这段文本的高度
      textPainter.text = TextSpan(text: textToAdd, style: textStyle);
      textPainter.layout(maxWidth: visibleWidth);
      final textHeight = textPainter.height;

      // 检查是否放得下
      if (currentY + textHeight > effectiveHeight) {
        return false;
      }

      // 放得下，添加
      pageBuffer.write(textToAdd);
      currentPageElements.add(PageElement.text(textToAdd));
      currentY += textHeight;
      return true;
    }

    /// 添加图片
    void addImage(String src) {
      // 计算图片尺寸
      double imgWidth = visibleWidth;
      double imgHeight = visibleWidth * 0.6; // 默认宽高比

      if (imgHeight > visibleHeight * 0.7) {
        imgHeight = visibleHeight * 0.7;
        imgWidth = imgHeight / 0.6;
      }

      // 如果当前页放不下，开新页
      if (currentY + imgHeight > effectiveHeight) {
        finishPage();
        charOffsets.add(currentIndex);
      }

      currentPageElements
          .add(PageElement.image(src, width: imgWidth, height: imgHeight));
      currentY += imgHeight + fontSize * 0.5; // 图片后留间距
    }

    // 逐块处理文本
    while (currentIndex < text.length) {
      // 如果是新页，记录起始位置
      if (currentY == 0.0 && pageBuffer.isEmpty) {
        charOffsets.add(currentIndex);
      }

      // 查找下一个图片
      final remainingText = text.substring(currentIndex);
      final imgMatch =
          supportImages ? imgPattern.firstMatch(remainingText) : null;

      if (imgMatch != null && imgMatch.start < 100) {
        // 处理图片前的文本
        if (imgMatch.start > 0) {
          final beforeImg = remainingText.substring(0, imgMatch.start);
          if (!tryAddText(beforeImg)) {
            finishPage();
            charOffsets.add(currentIndex);
            tryAddText(beforeImg);
          }
          currentIndex += imgMatch.start;
        }

        // 添加图片
        addImage(imgMatch.group(1)!);
        currentIndex += imgMatch.group(0)!.length;
      } else {
        // 取一段文本（最多100字符）
        final chunkSize = math.min(100, text.length - currentIndex);
        final chunk = text.substring(currentIndex, currentIndex + chunkSize);

        if (!tryAddText(chunk)) {
          // 放不下，分页
          finishPage();
          // 重试
          if (!tryAddText(chunk)) {
            // 还是放不下，逐字符添加
            for (int i = 0; i < chunk.length; i++) {
              final char = chunk[i];
              if (!tryAddText(char)) {
                finishPage();
                tryAddText(char);
              }
            }
          }
        }
        currentIndex += chunkSize;
      }

      // 进度报告
      if (pages.length % 200 == 0 && pages.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 1));
        final progress = (currentIndex / text.length * 100).toStringAsFixed(1);
        onProgress?.call(pages.length, '正在分页... $progress%');
      }
    }

    // 完成最后一页
    finishPage();

    debugPrint('✅ 分页完成: ${pages.length}页');
    debugPrint('   平均每页: ${(text.length / pages.length).toInt()}字符');

    onProgress?.call(pages.length, '分页完成');

    return FastPaginationResult(
      pages: pages,
      charOffsets: charOffsets,
      pageElements: pageElements,
    );
  }

  /// 快速分页（异步版本，支持进度回调）
  ///
  /// 精确分页 + 首行缩进 + 底部对齐
  static Future<FastPaginationResult> paginateWithProgress({
    required String text,
    required Size screenSize,
    required double fontSize,
    required double lineSpacing,
    required EdgeInsets padding,
    double letterSpacing = 0.0,
    double firstLineIndent = 0.0,
    double devicePixelRatio = 1.0,
    FastPaginationProgressCallback? onProgress,
  }) async {
    if (text.isEmpty) {
      return const FastPaginationResult(pages: [], charOffsets: []);
    }

    // 预处理文本：规范化空行
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 计算可用空间
    final availableWidth = screenSize.width - padding.left - padding.right;
    final availableHeight = screenSize.height - padding.top - padding.bottom;

    // 计算缩进宽度（字符数转为像素）
    final indentWidth = firstLineIndent * fontSize;

    // 创建TextPainter用于测量
    final textStyle = TextStyle(
      fontSize: fontSize,
      height: lineSpacing,
      letterSpacing: letterSpacing,
    );
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
    );

    debugPrint('📄 精确分页（含首行缩进）:');
    debugPrint('   屏幕: ${screenSize.width.toInt()}×${screenSize.height.toInt()}');
    debugPrint('   可用: ${availableWidth.toInt()}×${availableHeight.toInt()}');
    debugPrint('   首行缩进: ${firstLineIndent}字符 (${indentWidth.toInt()}px)');

    final List<String> pages = [];
    final List<int> charOffsets = [];
    final StringBuffer pageBuffer = StringBuffer();
    int pageStartIndex = 0;

    onProgress?.call(0, '正在分页...');

    // 逐段处理
    int currentIndex = 0;
    while (currentIndex < text.length) {
      // 如果是新页，记录起始位置
      if (pageBuffer.isEmpty) {
        pageStartIndex = currentIndex;
      }

      // 找到下一个段落的结束位置（换行符或文本末尾）
      int nextNewline = text.indexOf('\n', currentIndex);
      if (nextNewline == -1) nextNewline = text.length;

      // 提取段落（包含换行符）
      final hasNewline = nextNewline < text.length;
      final paragraph = text.substring(currentIndex, hasNewline ? nextNewline + 1 : nextNewline);

      // 测量加上这段后的总高度
      final testContent = pageBuffer.toString() + paragraph;
      textPainter.text = TextSpan(text: testContent, style: textStyle);
      textPainter.layout(maxWidth: availableWidth);
      final totalHeight = textPainter.height;

      // 检查是否超出页面
      if (totalHeight > availableHeight && pageBuffer.isNotEmpty) {
        // 超出了，完成当前页
        pages.add(pageBuffer.toString());
        charOffsets.add(pageStartIndex);
        pageBuffer.clear();

        // 进度报告
        if (pages.length % 200 == 0) {
          await Future.delayed(const Duration(milliseconds: 1));
          final progress = (currentIndex / text.length * 100).toStringAsFixed(1);
          onProgress?.call(pages.length, '正在分页... $progress%');
        }

        // 不移动currentIndex，下一轮会重新处理这段内容
        continue;
      }

      // 没超出，添加到当前页
      pageBuffer.write(paragraph);
      currentIndex = hasNewline ? nextNewline + 1 : nextNewline;
    }

    // 完成最后一页
    if (pageBuffer.isNotEmpty) {
      pages.add(pageBuffer.toString());
      charOffsets.add(pageStartIndex);
    }

    // 计算底部对齐的额外行间距（参考legado的upLinesPosition算法）
    final List<double> extraLineSpacing = [];
    for (int i = 0; i < pages.length; i++) {
      final pageContent = pages[i];

      // 测量当前页面的实际高度
      textPainter.text = TextSpan(text: pageContent, style: textStyle);
      textPainter.layout(maxWidth: availableWidth);
      final actualHeight = textPainter.height;

      // 计算行数（通过computeLineMetrics）
      final lineCount = textPainter.computeLineMetrics().length;

      // 如果只有1行或者底部空白超过1行，不做调整
      if (lineCount <= 1) {
        extraLineSpacing.add(0.0);
        continue;
      }

      // 计算剩余空间
      final surplus = availableHeight - actualHeight;

      // 测量单行高度
      textPainter.text = TextSpan(text: '测', style: textStyle);
      textPainter.layout();
      final singleLineHeight = textPainter.height;

      // 如果剩余空间超过1行高度，不做调整（避免行间距过大）
      if (surplus >= singleLineHeight) {
        extraLineSpacing.add(0.0);
        continue;
      }

      // 将剩余空间均匀分配到每行之间
      final extraSpacing = surplus / (lineCount - 1);
      extraLineSpacing.add(extraSpacing);
    }

    debugPrint('✅ 分页完成: ${pages.length}页');
    debugPrint('   平均每页: ${(text.length / pages.length).toInt()}字符');
    debugPrint('   底部对齐已计算');

    onProgress?.call(pages.length, '分页完成');

    return FastPaginationResult(
      pages: pages,
      charOffsets: charOffsets,
      pageExtraLineSpacing: extraLineSpacing,
    );
  }

  /// 快速分页（同步版本，用于小文件或缓存加载）
  ///
  /// 精确分页 + 首行缩进（同步版本）
  static FastPaginationResult paginate({
    required String text,
    required Size screenSize,
    required double fontSize,
    required double lineSpacing,
    required EdgeInsets padding,
    double letterSpacing = 0.0,
    double firstLineIndent = 0.0,
    double devicePixelRatio = 1.0,
  }) {
    if (text.isEmpty) {
      return const FastPaginationResult(pages: [], charOffsets: []);
    }

    // 预处理文本：规范化空行
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 计算可用空间
    final availableWidth = screenSize.width - padding.left - padding.right;
    final availableHeight = screenSize.height - padding.top - padding.bottom;

    // 创建TextPainter用于测量
    final textStyle = TextStyle(
      fontSize: fontSize,
      height: lineSpacing,
      letterSpacing: letterSpacing,
    );
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
    );

    final List<String> pages = [];
    final List<int> charOffsets = [];
    final StringBuffer pageBuffer = StringBuffer();
    int pageStartIndex = 0;

    // 逐段处理
    int currentIndex = 0;
    while (currentIndex < text.length) {
      // 如果是新页，记录起始位置
      if (pageBuffer.isEmpty) {
        pageStartIndex = currentIndex;
      }

      // 找到下一个段落的结束位置（换行符或文本末尾）
      int nextNewline = text.indexOf('\n', currentIndex);
      if (nextNewline == -1) nextNewline = text.length;

      // 提取段落（包含换行符）
      final hasNewline = nextNewline < text.length;
      final paragraph = text.substring(currentIndex, hasNewline ? nextNewline + 1 : nextNewline);

      // 测量加上这段后的总高度
      final testContent = pageBuffer.toString() + paragraph;
      textPainter.text = TextSpan(text: testContent, style: textStyle);
      textPainter.layout(maxWidth: availableWidth);
      final totalHeight = textPainter.height;

      // 检查是否超出页面
      if (totalHeight > availableHeight && pageBuffer.isNotEmpty) {
        // 超出了，完成当前页
        pages.add(pageBuffer.toString());
        charOffsets.add(pageStartIndex);
        pageBuffer.clear();
        // 不移动currentIndex，下一轮会重新处理这段内容
        continue;
      }

      // 没超出，添加到当前页
      pageBuffer.write(paragraph);
      currentIndex = hasNewline ? nextNewline + 1 : nextNewline;
    }

    // 完成最后一页
    if (pageBuffer.isNotEmpty) {
      pages.add(pageBuffer.toString());
      charOffsets.add(pageStartIndex);
    }

    // 计算底部对齐的额外行间距
    final List<double> extraLineSpacing = [];
    for (int i = 0; i < pages.length; i++) {
      final pageContent = pages[i];

      // 测量当前页面的实际高度
      textPainter.text = TextSpan(text: pageContent, style: textStyle);
      textPainter.layout(maxWidth: availableWidth);
      final actualHeight = textPainter.height;

      // 计算行数
      final lineCount = textPainter.computeLineMetrics().length;

      // 如果只有1行，不做调整
      if (lineCount <= 1) {
        extraLineSpacing.add(0.0);
        continue;
      }

      // 计算剩余空间
      final surplus = availableHeight - actualHeight;

      // 测量单行高度
      textPainter.text = TextSpan(text: '测', style: textStyle);
      textPainter.layout();
      final singleLineHeight = textPainter.height;

      // 如果剩余空间超过1行高度，不做调整
      if (surplus >= singleLineHeight) {
        extraLineSpacing.add(0.0);
        continue;
      }

      // 将剩余空间均匀分配到每行之间
      final extraSpacing = surplus / (lineCount - 1);
      extraLineSpacing.add(extraSpacing);
    }

    return FastPaginationResult(
      pages: pages,
      charOffsets: charOffsets,
      pageExtraLineSpacing: extraLineSpacing,
    );
  }
}
