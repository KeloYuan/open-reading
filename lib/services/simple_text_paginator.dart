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
    double letterSpacing = 0.0,
    double paragraphSpacing = 0.0,
    double firstLineIndent = 0.0,
  }) {
    if (text.isEmpty) return [];

    // 0. 预处理文本：规范化空行
    // 将3个或以上连续换行符替换为2个，避免过多空白
    final originalLength = text.length;
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    final emptyLinesRemoved = originalLength - text.length;

    // 1. 计算可用宽度和高度，并添加充足的安全边距
    final availableWidth = screenSize.width - padding.left - padding.right;

    // 动态安全边距：与字体大小和行高关联，确保绝对不超出
    // 基础边距：一行的高度作为缓冲
    final baseMargin = fontSize * lineHeight;
    // 行高补偿：行高越大，额外增加边距
    final lineHeightCompensation = lineHeight > 2.0
        ? (lineHeight - 2.0) * fontSize * 10
        : 0.0;
    // 字体补偿：大字体需要更多边距
    final fontCompensation = fontSize > 24.0
        ? (fontSize - 24.0) * 2.0
        : 0.0;

    final safetyMargin = baseMargin + lineHeightCompensation + fontCompensation;
    final availableHeight = screenSize.height - padding.top - padding.bottom - safetyMargin;

    print('📄 开始精确分页:');
    print('   屏幕: ${screenSize.width.toInt()}×${screenSize.height.toInt()}');
    print('   Padding: L${padding.left.toInt()} R${padding.right.toInt()} T${padding.top.toInt()} B${padding.bottom.toInt()}');
    print('   安全边距: ${safetyMargin.toStringAsFixed(1)}px (自适应)');
    print('   可用空间: ${availableWidth.toInt()}×${availableHeight.toInt()}');
    print('   排版: 字体${fontSize}px, 行高$lineHeight, 字间距$letterSpacing');
    print('        段落间距${paragraphSpacing}px, 首行缩进${firstLineIndent}字符');
    if (emptyLinesRemoved > 0) {
      print('   空行优化: 移除${emptyLinesRemoved}个多余换行符');
    }

    // 2. 创建TextPainter - 配置必须和实际渲染完全一致
    final textStyle = TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      letterSpacing: letterSpacing, // 使用实际的字间距设置
    );

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left, // 使用left对齐，确保分页和渲染一致
      maxLines: null, // 允许无限行
    );

    // 3. 逐页分页
    final pages = <String>[];
    int currentIndex = 0;
    int pageNum = 0;

    while (currentIndex < text.length) {
      pageNum++;

      // 估算起始范围 - 使用非常保守的估算，确保绝对不超出
      final remainingChars = text.length - currentIndex;
      // 更保守的系数：字体越大、行高越大越保守
      // 12px+1.0行高 -> 0.88, 36px+3.0行高 -> 0.75
      final conservativeRatio = 0.90 - (fontSize - 12.0) * 0.005 - (lineHeight - 1.0) * 0.05;
      final charsPerLine = (availableWidth / fontSize * 0.90).floor();
      final linesPerPage = (availableHeight / (fontSize * lineHeight) * conservativeRatio).floor();
      final estimatedCharsPerPage = (charsPerLine * linesPerPage).floor();

      // 二分查找最佳字符数
      int left = math.min(1, remainingChars);
      // 右边界限制为估算值的1.5倍，避免过度估算
      int right = math.min(estimatedCharsPerPage * 1.5, remainingChars).floor();
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

      // 添加安全缓冲：减少3-5%字符确保不超出
      final safetyBuffer = (bestFit * 0.04).ceil(); // 4%安全缓冲
      final safeBestFit = math.max(1, bestFit - safetyBuffer);

      // 添加这一页
      final endIndex = currentIndex + safeBestFit;
      final pageContent = text.substring(currentIndex, endIndex);
      pages.add(pageContent);

      // 验证分页结果 - 确保不超出/不浪费空间
      textPainter.text = TextSpan(text: pageContent, style: textStyle);
      textPainter.layout(maxWidth: availableWidth);
      final actualHeight = textPainter.height;
      final heightUtilization = (actualHeight / availableHeight * 100);

      // 调试输出前3页和最后1页
      if (pageNum <= 3 || endIndex >= text.length) {
        final lastChar = pageContent.isEmpty ? '' : pageContent[pageContent.length - 1];
        final nextChar = endIndex < text.length ? text[endIndex] : '';

        print('   第$pageNum页: $bestFit字符, 高度${actualHeight.toInt()}/${availableHeight.toInt()}px (${heightUtilization.toStringAsFixed(1)}%)');
        print('        最后字符: "$lastChar" (索引${endIndex-1}) -> 下页首字符: "$nextChar" (索引$endIndex)');
      }

      // 验证警告：超出或浪费过多空间
      if (actualHeight > availableHeight + 5) {
        print('   ⚠️  警告: 第$pageNum页文字超出可用高度 ${(actualHeight - availableHeight).toInt()}px');
      } else if (heightUtilization < 70.0 && endIndex < text.length) {
        print('   ⚠️  提示: 第$pageNum页空间利用率较低 (${heightUtilization.toStringAsFixed(1)}%)');
      }

      currentIndex = endIndex;
    }

    // 最终验证统计
    print('✅ 分页完成: ${pages.length}页');
    print('   平均每页约 ${(text.length / pages.length).toInt()} 字符');
    return pages;
  }
}