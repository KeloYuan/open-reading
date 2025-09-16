import 'package:flutter/material.dart';

/// TextPainter基础的精确分页工具类
class TextPainterPagination {
  /// 使用TextPainter进行精确的基于布局的分页
  static List<String> performTextPainterBasedPagination({
    required String content,
    required Size screenSize,
    required EdgeInsets systemPadding,
    required double fontSize,
    required double lineSpacing,
    required double letterSpacing,
    required String fontFamily,
    required double horizontalPadding,
  }) {
    List<String> pages = [];

    if (content.isEmpty) {
      return ['内容为空'];
    }

    // 计算可用区域 - 与实际显示保持完全一致
    // 精确匹配_buildPageWidget中的计算逻辑
    final statusBarHeight = systemPadding.top;
    final topPadding = 40.0;
    final baseBottomPadding = 40.0;
    final toolbarSpace = 100.0; // 控制栏预留空间
    final totalBottomPadding = baseBottomPadding + toolbarSpace;

    // 精确的可用尺寸 - 最大化利用屏幕空间
    final availableWidth = screenSize.width - (horizontalPadding * 2);
    // 顶部留白 = topPadding + statusBarHeight
    // 底部留白 = totalBottomPadding + systemPadding.bottom（SafeArea自动处理）
    final availableHeight =
        screenSize.height -
        (topPadding + statusBarHeight) -
        (totalBottomPadding + systemPadding.bottom);

    // 文本样式
    final textStyle = TextStyle(
      fontSize: fontSize,
      height: lineSpacing,
      letterSpacing: letterSpacing,
      fontFamily: fontFamily == 'System' ? null : fontFamily,
    );

    debugPrint(
      '📏 可用区域: ${availableWidth.toInt()}x${availableHeight.toInt()}px',
    );
    debugPrint(
      '📝 字体设置: ${fontSize.toInt()}px, 行距$lineSpacing, 字间距$letterSpacing',
    );

    int currentIndex = 0;
    int pageCount = 0;
    const maxPages = 50000; // 防止无限循环

    // 预先计算单行字符数，优化分页性能
    final singleLineText = '测试中文字符English123';
    final singleLinePainter = TextPainter(
      text: TextSpan(text: singleLineText, style: textStyle),
      textDirection: TextDirection.ltr,
    );
    singleLinePainter.layout(maxWidth: availableWidth);
    final avgCharWidth = singleLinePainter.size.width / singleLineText.length;
    final charsPerLine = (availableWidth / avgCharWidth).floor();
    singleLinePainter.dispose();

    debugPrint(
      '📊 字体分析: 平均字符宽度${avgCharWidth.toStringAsFixed(1)}px, 每行约$charsPerLine字符',
    );

    while (currentIndex < content.length && pageCount < maxPages) {
      // 使用改进的二分搜索找到能够容纳在可用高度内的最大文本量
      int bestEndIndex = _findBestPageEndIndex(
        content,
        currentIndex,
        availableWidth,
        availableHeight,
        textStyle,
        fontSize,
      );

      // 如果没有找到合适的结束位置，使用保守估算
      if (bestEndIndex <= currentIndex) {
        bestEndIndex = (currentIndex + charsPerLine).clamp(
          currentIndex + 1,
          content.length,
        );
      }

      // 提取页面内容并清理
      String pageContent = content.substring(currentIndex, bestEndIndex);
      pageContent = pageContent.trimLeft(); // 去除开头空白

      if (pageContent.isNotEmpty) {
        pages.add(pageContent);
        pageCount++;
        debugPrint(
          '📄 第$pageCount页: 位置$currentIndex-$bestEndIndex, ${bestEndIndex - currentIndex}字符',
        );
      }

      currentIndex = bestEndIndex;
    }

    // 验证页面连接的完整性
    if (pages.length > 1) {
      _validatePageConnections(pages, content);
    }

    return pages;
  }

  /// 验证页面连接的完整性，确保没有遗漏或重复字符
  static void _validatePageConnections(
    List<String> pages,
    String originalContent,
  ) {
    String reconstructedContent = pages.join('');

    // 移除清理过程中可能产生的空白差异进行比较
    String normalizedOriginal = originalContent
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    String normalizedReconstructed = reconstructedContent
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (normalizedOriginal.length != normalizedReconstructed.length) {
      debugPrint(
        '⚠️ 分页验证警告: 原文${normalizedOriginal.length}字符, 重建${normalizedReconstructed.length}字符',
      );
      debugPrint(
        '📝 长度差异: ${normalizedOriginal.length - normalizedReconstructed.length}字符',
      );
    } else {
      debugPrint('✅ 分页验证通过: 字符连接完整');
    }

    // 检查相邻页面边界
    for (int i = 0; i < pages.length - 1; i++) {
      String currentPageEnd = pages[i].trimRight();
      String nextPageStart = pages[i + 1].trimLeft();

      if (currentPageEnd.isNotEmpty && nextPageStart.isNotEmpty) {
        debugPrint(
          '🔗 第${i + 1}-${i + 2}页边界: "${currentPageEnd.substring(currentPageEnd.length - 1)}" -> "${nextPageStart.substring(0, 1)}"',
        );
      }
    }
  }

  /// 使用二分搜索找到最佳的页面结束位置
  static int _findBestPageEndIndex(
    String content,
    int startIndex,
    double maxWidth,
    double maxHeight,
    TextStyle textStyle,
    double fontSize,
  ) {
    if (startIndex >= content.length) return content.length;

    // 更精确的初始估算
    final testPainter = TextPainter(
      text: TextSpan(text: '测试字符串中文内容\n第二行测试', style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.justify,
    );
    testPainter.layout(maxWidth: maxWidth);
    final avgLineHeight = testPainter.size.height / 2;
    final estimatedLines = (maxHeight / avgLineHeight).floor();

    // 更准确的字符宽度估算：中文字符约为字号的0.9倍，英文字符约为字号的0.6倍
    final estimatedCharsPerLine = (maxWidth / (fontSize * 0.85)).floor();
    final estimatedTotalChars = estimatedLines * estimatedCharsPerLine;
    testPainter.dispose();

    // 设置更保守的搜索范围，避免过度估算
    int left = startIndex;
    int right = (startIndex + (estimatedTotalChars * 1.2))
        .clamp(startIndex + 1, content.length)
        .toInt();
    int bestFit = startIndex;

    debugPrint('🔍 二分搜索范围: $left-$right (预估$estimatedTotalChars字符)');

    // 改进的二分搜索：更精确的边界处理
    while (left < right) {
      int mid = left + ((right - left) ~/ 2);

      // 在自然分割点进行调整
      int adjustedMid = _findNaturalBreak(content, mid, startIndex);

      // 测量这段文本的实际高度
      String testText = content.substring(startIndex, adjustedMid);
      final painter = TextPainter(
        text: TextSpan(text: testText, style: textStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.justify,
      );
      painter.layout(maxWidth: maxWidth);

      final actualHeight = painter.size.height;
      painter.dispose();

      // 精确判断：留出小量缓冲空间避免文字被截断
      final heightMargin = fontSize * 0.2; // 留出0.2倍字号的缓冲
      if (actualHeight <= maxHeight - heightMargin) {
        bestFit = adjustedMid;
        left = mid + 1;
      } else {
        right = mid;
      }
    }

    // 确保至少前进一些字符，避免无限循环
    if (bestFit <= startIndex) {
      bestFit = (startIndex + (estimatedCharsPerLine / 2))
          .clamp(startIndex + 1, content.length)
          .toInt();
    }

    return bestFit;
  }

  /// 寻找自然的分割点（句子或段落结尾）
  static int _findNaturalBreak(String content, int targetIndex, int minIndex) {
    if (targetIndex >= content.length) return content.length;
    if (targetIndex <= minIndex) return minIndex + 1;

    // 扩大搜索范围，优化分割点选择
    const searchRange = 80; // 增加搜索范围
    int bestBreak = targetIndex;
    int priority = 0; // 分割点优先级

    for (int i = 0; i < searchRange && targetIndex - i > minIndex; i++) {
      int checkIndex = targetIndex - i;
      if (checkIndex >= content.length) continue;

      String char = content[checkIndex];
      int currentPriority = 0;

      // 优先级分层：段落 > 句子 > 其他标点 > 空格
      if (char == '\n') {
        currentPriority = 10; // 最高优先级：段落分割
      } else if (char == '。' || char == '！' || char == '？' || char == '.') {
        currentPriority = 8; // 高优先级：句子结尾
      } else if (char == '；' || char == '：' || char == '，') {
        currentPriority = 6; // 中等优先级：句内标点
      } else if (char == ' ' || char == '\t') {
        currentPriority = 4; // 低优先级：空格
      } else if (_isChinesePunctuation(char)) {
        currentPriority = 5; // 中文标点符号
      }

      // 选择更高优先级的分割点，如果优先级相同则选择距离更近的
      if (currentPriority > priority ||
          (currentPriority == priority && i < 20)) {
        bestBreak = checkIndex + 1;
        priority = currentPriority;

        // 如果找到段落分割且距离很近，直接使用
        if (currentPriority >= 10 && i < 30) {
          return bestBreak;
        }
      }
    }

    // 如果没有找到合适的分割点，使用原目标位置
    return bestBreak == targetIndex ? targetIndex : bestBreak;
  }

  /// 判断是否为中文标点符号
  static bool _isChinesePunctuation(String char) {
    const chinesePunc = [
      '「',
      '」',
      '『',
      '』',
      '《',
      '》',
      '〈',
      '〉',
      '【',
      '】',
      '〔',
      '〕',
      '（',
      '）',
      '—',
      '…',
      '·',
    ];
    return chinesePunc.contains(char);
  }
}
