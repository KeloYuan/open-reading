import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 简单文本分页器
/// 使用TextPainter精确测量，确保100%准确分页
class SimpleTextPaginator {
  /// 简单分页
  static List<String> paginate({
    required String text,
    required Size screenSize,
    required double fontSize,
    required double lineHeight,
    required EdgeInsets padding,
  }) {
    if (text.isEmpty) return [];

    // 0. 预处理文本：规范化空行
    // 将3个或以上连续换行符替换为2个，避免过多空白
    final originalLength = text.length;
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    final emptyLinesRemoved = originalLength - text.length;

    // 1. 计算可用宽度和高度
    final availableWidth = screenSize.width - padding.left - padding.right;
    final availableHeight = screenSize.height - padding.top - padding.bottom;

    print('📄 开始分页:');
    print('   屏幕: ${screenSize.width.toInt()}×${screenSize.height.toInt()}');
    print('   Padding: L${padding.left} R${padding.right} T${padding.top} B${padding.bottom}');
    print('   可用: ${availableWidth.toInt()}×${availableHeight.toInt()}');
    print('   字体: ${fontSize}px, 行高: $lineHeight');
    if (emptyLinesRemoved > 0) {
      print('   空行处理: 移除${emptyLinesRemoved}个多余换行符');
    }

    // 2. 创建TextPainter - 配置必须和实际渲染完全一致
    final textStyle = TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      letterSpacing: 0.0, // 确保没有额外间距
    );

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.justify, // 必须和Text组件一致
      maxLines: null, // 允许无限行
    );

    // 3. 逐页分页
    final pages = <String>[];
    int currentIndex = 0;
    int pageNum = 0;

    while (currentIndex < text.length) {
      pageNum++;

      // 估算起始范围
      final remainingChars = text.length - currentIndex;
      final estimatedCharsPerPage = ((availableWidth / fontSize) * (availableHeight / (fontSize * lineHeight)) * 0.9).floor();

      // 二分查找最佳字符数
      int left = math.min(1, remainingChars);
      int right = math.min(estimatedCharsPerPage * 2, remainingChars);
      int bestFit = left;

      while (left <= right) {
        final mid = (left + right) ~/ 2;
        final endIndex = currentIndex + mid;
        final testText = text.substring(currentIndex, endIndex);

        // 测量这段文本
        textPainter.text = TextSpan(text: testText, style: textStyle);
        textPainter.layout(maxWidth: availableWidth);

        final textHeight = textPainter.height;

        if (textHeight <= availableHeight) {
          // 能放下，尝试放更多
          bestFit = mid;
          left = mid + 1;
        } else {
          // 放不下，减少字符
          right = mid - 1;
        }
      }

      // 添加这一页
      final endIndex = currentIndex + bestFit;
      final pageContent = text.substring(currentIndex, endIndex);
      pages.add(pageContent);

      // 调试输出前3页
      if (pageNum <= 3) {
        // 测量最终高度
        textPainter.text = TextSpan(text: pageContent, style: textStyle);
        textPainter.layout(maxWidth: availableWidth);

        final lastChar = pageContent.isEmpty ? '' : pageContent[pageContent.length - 1];
        final nextChar = endIndex < text.length ? text[endIndex] : '';

        print('   第$pageNum页: $bestFit字符, 高度${textPainter.height.toInt()}/${availableHeight.toInt()}px');
        print('        最后字符: "$lastChar" (索引${endIndex-1}) -> 下页首字符: "$nextChar" (索引$endIndex)');
      }

      currentIndex = endIndex;
    }

    print('✅ 分页完成: ${pages.length}页');
    return pages;
  }
}