import 'package:flutter/material.dart';

/// 文本行 - 记录每一行的精确信息
class TextLine {
  final String text;
  final bool hasIndent;

  TextLine({
    required this.text,
    this.hasIndent = false,
  });
}

/// 文本页 - 包含完整的页面布局信息
class TextPage {
  final List<TextLine> lines;
  final int index;

  TextPage({
    required this.lines,
    required this.index,
  });

  bool get isImagePage => false;
}

/// 分页结果 - 包含页面和元数据
class PaginationResult {
  final List<TextPage> pages;
  final int maxLinesPerPage;

  PaginationResult({
    required this.pages,
    required this.maxLinesPerPage,
  });
}

/// 精确文本分页器 - 完全参照legado实现
///
/// 核心思路（参照legado的TextChapterLayout.kt）：
/// 1. 逐段处理文本（按\n分段）
/// 2. 每段使用TextPainter测量，自动断行
/// 3. 逐行累加高度，每行前检查是否超出visibleHeight
/// 4. 超出则开新页，当前行放入新页
/// 5. 段落首行添加缩进（全角空格）
class PreciseTextPaginator {
  static PaginationResult paginate({
    required String text,
    required Size screenSize,
    required TextStyle textStyle,
    required EdgeInsets padding,
    double firstLineIndent = 2.0,
    double paragraphSpacing = 0.0,
    List<String>? imageUrls,
  }) {
    debugPrint('🔧 [精确分页器] Legado算法 - 逐段累加');

    final pages = <TextPage>[];

    // 计算参数
    final visibleWidth = screenSize.width - padding.left - padding.right;
    final visibleHeight = screenSize.height - padding.top - padding.bottom;
    final fontSize = textStyle.fontSize ?? 16.0;
    final lineHeight = (textStyle.height ?? 1.5) * fontSize;
    final indentString = '　' * firstLineIndent.toInt();

    debugPrint('   可见尺寸: ${visibleWidth.toStringAsFixed(1)} x ${visibleHeight.toStringAsFixed(1)}');
    debugPrint('   行高: ${lineHeight.toStringAsFixed(1)}');
    debugPrint('   缩进: ${firstLineIndent.toInt()} 字');

    if (visibleHeight <= 0 || visibleWidth <= 0) {
      return PaginationResult(pages: pages, maxLinesPerPage: 0);
    }

    // 估算每页最大行数
    final maxLinesPerPage = (visibleHeight / lineHeight).floor();
    debugPrint('   估算每页最大: $maxLinesPerPage 行');

    // TextPainter - 用于测量每段文本
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // 状态变量
    List<TextLine> currentPageLines = [];
    double durY = 0.0; // 当前Y坐标
    int pageIndex = 0;

    void prepareNextPageIfNeed(double requestHeight) {
      if (requestHeight > visibleHeight) {
        // 当前页满，开新页
        if (currentPageLines.isNotEmpty) {
          pages.add(TextPage(
            lines: List.from(currentPageLines),
            index: pageIndex,
          ));
          debugPrint('   ✅ 第${pages.length}页: ${currentPageLines.length}行, durY=${durY.toStringAsFixed(1)}');
          pageIndex++;
          currentPageLines.clear();
          durY = 0.0;
        }
      }
    }

    // 按段落分割文本
    final paragraphs = text.split('\n');
    debugPrint('   总段落数: ${paragraphs.length}');

    for (int pIndex = 0; pIndex < paragraphs.length; pIndex++) {
      final paragraph = paragraphs[pIndex];

      // 跳过空段落（但仍然需要段间距）
      if (paragraph.trim().isEmpty) {
        if (paragraphSpacing > 0 && currentPageLines.isNotEmpty) {
          durY += paragraphSpacing;
        }
        continue;
      }

      // 判断是否是段落首行（需要缩进）
      final isFirstLineOfParagraph = true;
      final paragraphText = isFirstLineOfParagraph && firstLineIndent > 0
          ? indentString + paragraph
          : paragraph;

      // 使用TextPainter测量段落，自动断行
      textPainter.text = TextSpan(
        text: paragraphText,
        style: textStyle,
      );
      textPainter.layout(maxWidth: visibleWidth);

      // 获取所有行的文本
      final lines = _extractLinesFromPainter(textPainter, paragraphText);

      for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
        // 检查是否需要新页（legado的prepareNextPageIfNeed）
        prepareNextPageIfNeed(durY + lineHeight);

        final lineText = lines[lineIndex];

        // 添加到当前页
        currentPageLines.add(TextLine(
          text: lineText,
          hasIndent: lineIndex == 0 && isFirstLineOfParagraph && firstLineIndent > 0,
        ));

        // 更新Y坐标
        durY += lineHeight;
      }

      // 段落间距
      if (paragraphSpacing > 0 && pIndex < paragraphs.length - 1) {
        durY += paragraphSpacing;
      }
    }

    // 最后一页
    if (currentPageLines.isNotEmpty) {
      pages.add(TextPage(
        lines: List.from(currentPageLines),
        index: pageIndex,
      ));
      debugPrint('   ✅ 第${pages.length}页（最后）: ${currentPageLines.length}行');
    }

    debugPrint('   ✅ 分页完成: ${pages.length} 页');

    return PaginationResult(
      pages: pages,
      maxLinesPerPage: maxLinesPerPage,
    );
  }

  /// 从TextPainter中提取每一行的文本
  static List<String> _extractLinesFromPainter(TextPainter textPainter, String text) {
    final lines = <String>[];
    final lineMetrics = textPainter.computeLineMetrics();

    if (lineMetrics.isEmpty) {
      return [text];
    }

    for (int i = 0; i < lineMetrics.length; i++) {
      // 使用getPositionForOffset来找到每行的起始和结束位置
      // 通过行的垂直位置来确定行边界
      final lineTop = lineMetrics[i].baseline - lineMetrics[i].ascent;
      final lineBottom = lineMetrics[i].baseline + lineMetrics[i].descent;
      final lineMid = (lineTop + lineBottom) / 2;

      // 找到这一行的起始位置（从左边缘开始）
      final startPos = textPainter.getPositionForOffset(Offset(0, lineMid));

      // 找到这一行的结束位置（从右边缘开始）
      final endPos = textPainter.getPositionForOffset(Offset(textPainter.width, lineMid));

      final lineStart = startPos.offset;
      final lineEnd = endPos.offset;

      if (lineStart >= text.length) break;

      final actualEnd = lineEnd > text.length ? text.length : lineEnd;
      final lineText = text.substring(lineStart, actualEnd);

      lines.add(lineText);
    }

    return lines;
  }
}
