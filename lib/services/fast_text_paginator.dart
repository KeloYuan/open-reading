import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 分页进度回调
typedef FastPaginationProgressCallback = void Function(
    int currentPage, String stage);

/// 分页结果
class FastPaginationResult {
  /// 分页后的文本页面列表
  final List<String> pages;

  /// 每页在原文中的字符起始位置
  final List<int> charOffsets;

  const FastPaginationResult({
    required this.pages,
    required this.charOffsets,
  });
}

/// 快速文本分页器
///
/// 使用精确的逐行填充算法，确保每页都正好填满指定的行数
class FastTextPaginator {
  /// 快速分页（异步版本，支持进度回调）
  ///
  /// 精确的逐行分页算法：
  /// 1. 计算每页能显示多少行
  /// 2. 计算每行能显示多少字符
  /// 3. 逐行填充字符，空行也占1行
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

    // 预处理文本：规范化空行（3个以上换行符 -> 2个）
    final originalLength = text.length;
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    final emptyLinesRemoved = originalLength - text.length;

    // 计算可用宽度和高度
    final availableWidth = screenSize.width - padding.left - padding.right;

    // 计算实际的行高（像素）
    final lineHeightPx = fontSize * lineSpacing;

    // 根据屏幕实际情况动态计算安全边距
    // 策略：使用行高的倍数 + 最小像素值（仅对大字体≥25px生效）
    // 使用极小的倍数，最大化内容显示
    double topSafetyMultiplier = 0.2; // 顶部：0.2倍行高（极小）
    double bottomSafetyMultiplier = 0.05; // 底部：0.05倍行高（极小）

    // 最小安全边距（像素）- 仅在大字体时启用，防止边距太小
    // 临界值设为26px，25px及以下使用动态倍数以避免浪费空间
    double minTopMarginPx = fontSize >= 26 ? 22.0 : 0.0;
    double minBottomMarginPx = fontSize >= 26 ? 20.0 : 0.0;

    // 根据屏幕密度微调
    if (screenSize.height > 2500 || devicePixelRatio >= 3.5) {
      // 超高分辨率屏幕 (如 OPPO Find X8)
      topSafetyMultiplier = 0.25;
      bottomSafetyMultiplier = 0.03; // 极小化底部边距
      if (fontSize >= 26) {
        minTopMarginPx = 28.0;
        minBottomMarginPx = 25.0;
      }
    } else if (screenSize.height > 2000 || devicePixelRatio >= 3.0) {
      topSafetyMultiplier = 0.22;
      bottomSafetyMultiplier = 0.04;
      if (fontSize >= 26) {
        minTopMarginPx = 25.0;
        minBottomMarginPx = 22.0;
      }
    } else if (screenSize.height > 1500 || devicePixelRatio >= 2.5) {
      topSafetyMultiplier = 0.2;
      bottomSafetyMultiplier = 0.05;
      if (fontSize >= 26) {
        minTopMarginPx = 22.0;
        minBottomMarginPx = 20.0;
      }
    }

    // 计算动态安全边距（行高 × 倍数）
    final dynamicTopMargin = lineHeightPx * topSafetyMultiplier;
    final dynamicBottomMargin = lineHeightPx * bottomSafetyMultiplier;

    // 实际安全边距 = max(动态值, 最小值)
    // 小字体时最小值为0，完全使用动态值；大字体时有最小值保护
    final topSafetyMarginPx = math.max(minTopMarginPx, dynamicTopMargin);
    final bottomSafetyMarginPx =
        math.max(minBottomMarginPx, dynamicBottomMargin);

    // 计算可用高度（减去 padding 和安全边距）
    final availableHeight = screenSize.height -
        padding.top -
        padding.bottom -
        topSafetyMarginPx -
        bottomSafetyMarginPx;

    // 计算每行可以容纳的字符数
    // 字符宽度 = 字体大小 + 字间距
    // 中文字符约为 0.95 * fontSize（略小于完整字体大小）
    final charWidth = fontSize * 0.95 + letterSpacing;
    final charsPerLine = (availableWidth / charWidth).floor();

    // 计算首行缩进后的字符数（每段第一行）
    final firstLineAvailableWidth = availableWidth - firstLineIndent;
    final firstLineCharsPerLine = (firstLineAvailableWidth / charWidth).floor();

    debugPrint('📄 逐行分页开始:');
    debugPrint(
        '   屏幕: ${screenSize.width.toInt()}×${screenSize.height.toInt()} (DPR: ${devicePixelRatio.toStringAsFixed(2)})');
    debugPrint(
        '   Padding: L${padding.left.toInt()} R${padding.right.toInt()} T${padding.top.toInt()} B${padding.bottom.toInt()}');
    debugPrint(
        '   安全边距: 顶部${topSafetyMarginPx.toInt()}px (动态${dynamicTopMargin.toInt()}px vs 最小${minTopMarginPx.toInt()}px), 底部${bottomSafetyMarginPx.toInt()}px (动态${dynamicBottomMargin.toInt()}px vs 最小${minBottomMarginPx.toInt()}px)');
    debugPrint('   可用空间: ${availableWidth.toInt()}×${availableHeight.toInt()}');
    debugPrint(
        '   排版参数: 字体${fontSize}px, 行距${lineSpacing.toStringAsFixed(1)} (${lineHeightPx.toInt()}px), 字间距$letterSpacing');
    debugPrint('   首行缩进: ${firstLineIndent.toInt()}px');
    debugPrint('   计算结果: 每行${charsPerLine}字符 (首行${firstLineCharsPerLine}字符)');
    if (emptyLinesRemoved > 0) {
      debugPrint('   空行优化: 移除${emptyLinesRemoved}个多余换行符');
    }

    // 计算每页能显示的完整行数（向下取整，零点几行留空不显示）
    // 使用安全系数动态调整：根据行距预留安全高度，再计算行数
    // 安全高度 = 行高 × 安全系数，行距越大，安全系数越大
    // 1.0-1.5: 安全系数 0.8（预留0.8行高度）
    // 1.5-2.0: 安全系数 1.2（预留1.2行高度）
    // 2.0+:    安全系数 1.5（预留1.5行高度）
    double safetyFactor;
    if (lineSpacing < 1.5) {
      safetyFactor = 0.8;
    } else if (lineSpacing < 2.0) {
      safetyFactor = 1.2;
    } else {
      safetyFactor = 1.5;
    }

    final safetyHeight = lineHeightPx * safetyFactor;
    final adjustedHeight = availableHeight - safetyHeight;
    final maxLinesPerPage =
        math.max(1, (adjustedHeight / lineHeightPx).floor());

    debugPrint(
        '   ✅ 可用高度: ${availableHeight.toInt()}px, 安全高度: ${safetyHeight.toInt()}px (${safetyFactor}×行高), 实际使用: $maxLinesPerPage 行');

    // 动态高度分页
    final List<String> pages = [];
    final List<int> charOffsets = [];
    int currentIndex = 0;
    int pageNum = 0;
    int lastProgressReport = 0;

    onProgress?.call(0, '正在分页...');

    while (currentIndex < text.length) {
      pageNum++;

      // 跳过页面开头的所有换行符（空行）
      while (currentIndex < text.length && text[currentIndex] == '\n') {
        currentIndex++;
      }

      // 如果跳过空行后已经到达文本末尾，结束分页
      if (currentIndex >= text.length) {
        break;
      }

      // 记录页面开始位置（跳过空行后）
      charOffsets.add(currentIndex);
      final pageStartIndex = currentIndex;

      // 用行数计数器，确保只显示完整的行，零点几行留空
      int usedLines = 0; // 当前页已使用的行数
      bool isFirstLineOfParagraph = true; // 页面开始时，第一行是段落首行

      while (usedLines < maxLinesPerPage && currentIndex < text.length) {
        // 检查当前字符是否是换行符
        if (text[currentIndex] == '\n') {
          currentIndex++;
          usedLines++; // 换行符占1行
          isFirstLineOfParagraph = true; // 下一行是新段落的首行
          continue;
        }

        // 查找从当前位置到下一个换行符的位置
        int nextNewlinePos = text.indexOf('\n', currentIndex);
        if (nextNewlinePos == -1) {
          nextNewlinePos = text.length; // 没有换行符，就到文本末尾
        }

        // 根据是否是首行，选择每行字符数
        final currentLineCharsPerLine =
            isFirstLineOfParagraph ? firstLineCharsPerLine : charsPerLine;

        // 计算这一段的长度（不包含换行符）
        int segmentLength = nextNewlinePos - currentIndex;

        if (segmentLength <= currentLineCharsPerLine) {
          // 这一段可能可以放在一行，但需要检查是否应该填满这一行
          final segment = text.substring(currentIndex, nextNewlinePos);

          // 检查这一段是否以标点符号结尾
          final endsWithPunctuation = segment.isNotEmpty &&
              (segment.endsWith('。') ||
                  segment.endsWith('，') ||
                  segment.endsWith('、') ||
                  segment.endsWith('！') ||
                  segment.endsWith('？') ||
                  segment.endsWith('.') ||
                  segment.endsWith(',') ||
                  segment.endsWith('!') ||
                  segment.endsWith('?') ||
                  segment.endsWith(';') ||
                  segment.endsWith('；'));

          if (endsWithPunctuation ||
              segmentLength >= (currentLineCharsPerLine * 0.8).floor()) {
            // 如果以标点结尾，或者已经接近一行的长度（80%以上），就换行
            currentIndex = nextNewlinePos;
            usedLines++;
            isFirstLineOfParagraph = false; // 下一行不是首行
          } else {
            // 否则，尝试填满这一行
            currentIndex = nextNewlinePos;
            if (currentIndex < text.length && text[currentIndex] == '\n') {
              currentIndex++; // 跳过换行符

              // 如果跳过换行符后还有内容，尝试继续填充这一行
              if (currentIndex < text.length &&
                  segmentLength < currentLineCharsPerLine) {
                final nextNewline2 = text.indexOf('\n', currentIndex);
                final endPos2 = nextNewline2 == -1 ? text.length : nextNewline2;
                final additionalChars = math.min(
                    currentLineCharsPerLine - segmentLength,
                    endPos2 - currentIndex);

                // 只有在有足够内容时才继续填充
                if (additionalChars > 0) {
                  currentIndex += additionalChars;
                }
              }
            }
            usedLines++;
            isFirstLineOfParagraph = false; // 下一行不是首行
          }
        } else {
          // 这一段太长，需要分成多行
          // 首行可能更短（有缩进），后续行用正常长度
          final charsToTake =
              math.min(currentLineCharsPerLine, nextNewlinePos - currentIndex);
          currentIndex += charsToTake;
          usedLines++;
          isFirstLineOfParagraph = false; // 填充后，下一行不是首行了
        }
      }

      // 提取页面内容
      String pageContent = text.substring(pageStartIndex, currentIndex);

      // 去掉页面结尾的所有换行符（空行）
      pageContent = pageContent.replaceAll(RegExp(r'\n+$'), '');

      // 如果去掉结尾换行符后页面为空，跳过这一页
      if (pageContent.isEmpty) {
        continue;
      }

      pages.add(pageContent);

      // 每1000页报告一次进度
      if (pageNum - lastProgressReport >= 1000) {
        await Future.delayed(const Duration(milliseconds: 5));
        final progress = (currentIndex / text.length * 100).toStringAsFixed(1);
        onProgress?.call(pages.length, '正在分页... $progress%');
        lastProgressReport = pageNum;
        debugPrint('   已分页: ${pages.length} 页 ($progress%)');
      }
    }

    final avgCharsPerPage = text.length / pages.length;
    debugPrint('✅ 快速分页完成: ${pages.length}页');
    debugPrint('   平均每页: ${avgCharsPerPage.toInt()}字符');

    onProgress?.call(pages.length, '分页完成');

    return FastPaginationResult(
      pages: pages,
      charOffsets: charOffsets,
    );
  }

  /// 快速分页（同步版本，用于小文件或缓存加载）
  ///
  /// 精确的逐行分页算法
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

    // 预处理文本
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 计算可用空间
    final availableWidth = screenSize.width - padding.left - padding.right;

    // 计算实际的行高（像素）
    final lineHeightPx = fontSize * lineSpacing;

    // 根据屏幕实际情况动态计算安全边距
    // 策略：使用行高的倍数 + 最小像素值（仅对大字体≥25px生效）
    // 使用极小的倍数，最大化内容显示
    double topSafetyMultiplier = 0.2; // 顶部：0.2倍行高（极小）
    double bottomSafetyMultiplier = 0.05; // 底部：0.05倍行高（极小）

    // 最小安全边距（像素）- 仅在大字体时启用，防止边距太小
    // 临界值设为26px，25px及以下使用动态倍数以避免浪费空间
    double minTopMarginPx = fontSize >= 26 ? 22.0 : 0.0;
    double minBottomMarginPx = fontSize >= 26 ? 20.0 : 0.0;

    // 根据屏幕密度微调
    if (screenSize.height > 2500 || devicePixelRatio >= 3.5) {
      // 超高分辨率屏幕 (如 OPPO Find X8)
      topSafetyMultiplier = 0.25;
      bottomSafetyMultiplier = 0.03; // 极小化底部边距
      if (fontSize >= 26) {
        minTopMarginPx = 28.0;
        minBottomMarginPx = 25.0;
      }
    } else if (screenSize.height > 2000 || devicePixelRatio >= 3.0) {
      topSafetyMultiplier = 0.22;
      bottomSafetyMultiplier = 0.04;
      if (fontSize >= 26) {
        minTopMarginPx = 25.0;
        minBottomMarginPx = 22.0;
      }
    } else if (screenSize.height > 1500 || devicePixelRatio >= 2.5) {
      topSafetyMultiplier = 0.2;
      bottomSafetyMultiplier = 0.05;
      if (fontSize >= 26) {
        minTopMarginPx = 22.0;
        minBottomMarginPx = 20.0;
      }
    }

    // 计算动态安全边距（行高 × 倍数）
    final dynamicTopMargin = lineHeightPx * topSafetyMultiplier;
    final dynamicBottomMargin = lineHeightPx * bottomSafetyMultiplier;

    // 实际安全边距 = max(动态值, 最小值)
    // 小字体时最小值为0，完全使用动态值；大字体时有最小值保护
    final topSafetyMarginPx = math.max(minTopMarginPx, dynamicTopMargin);
    final bottomSafetyMarginPx =
        math.max(minBottomMarginPx, dynamicBottomMargin);

    // 计算可用高度
    final availableHeight = screenSize.height -
        padding.top -
        padding.bottom -
        topSafetyMarginPx -
        bottomSafetyMarginPx;

    // 计算每行可以容纳的字符数
    // 中文字符约为 0.95 * fontSize（略小于完整字体大小）
    final charWidth = fontSize * 0.95 + letterSpacing;
    final charsPerLine = (availableWidth / charWidth).floor();

    // 计算首行缩进后的字符数（每段第一行）
    final firstLineAvailableWidth = availableWidth - firstLineIndent;
    final firstLineCharsPerLine = (firstLineAvailableWidth / charWidth).floor();

    // 计算每页能显示的完整行数（向下取整，零点几行留空不显示）
    // 使用安全系数动态调整：根据行距预留安全高度，再计算行数
    double safetyFactor;
    if (lineSpacing < 1.5) {
      safetyFactor = 0.8;
    } else if (lineSpacing < 2.0) {
      safetyFactor = 1.2;
    } else {
      safetyFactor = 1.5;
    }

    final safetyHeight = lineHeightPx * safetyFactor;
    final adjustedHeight = availableHeight - safetyHeight;
    final maxLinesPerPage =
        math.max(1, (adjustedHeight / lineHeightPx).floor());

    // 精确的逐行分页
    final List<String> pages = [];
    final List<int> charOffsets = [];
    int currentIndex = 0;

    while (currentIndex < text.length) {
      // 跳过页面开头的所有换行符（空行）
      while (currentIndex < text.length && text[currentIndex] == '\n') {
        currentIndex++;
      }

      // 如果跳过空行后已经到达文本末尾，结束分页
      if (currentIndex >= text.length) {
        break;
      }

      // 记录页面开始位置（跳过空行后）
      charOffsets.add(currentIndex);
      final pageStartIndex = currentIndex;

      // 用行数计数器，确保只显示完整的行，零点几行留空
      int usedLines = 0; // 当前页已使用的行数
      bool isFirstLineOfParagraph = true; // 页面开始时，第一行是段落首行

      while (usedLines < maxLinesPerPage && currentIndex < text.length) {
        // 检查当前字符是否是换行符
        if (text[currentIndex] == '\n') {
          currentIndex++;
          usedLines++; // 换行符占1行
          isFirstLineOfParagraph = true; // 下一行是新段落的首行
          continue;
        }

        // 查找从当前位置到下一个换行符的位置
        int nextNewlinePos = text.indexOf('\n', currentIndex);
        if (nextNewlinePos == -1) {
          nextNewlinePos = text.length; // 没有换行符，就到文本末尾
        }

        // 根据是否是首行，选择每行字符数
        final currentLineCharsPerLine =
            isFirstLineOfParagraph ? firstLineCharsPerLine : charsPerLine;

        // 计算这一段的长度（不包含换行符）
        int segmentLength = nextNewlinePos - currentIndex;

        if (segmentLength <= currentLineCharsPerLine) {
          // 这一段可能可以放在一行，但需要检查是否应该填满这一行
          final segment = text.substring(currentIndex, nextNewlinePos);

          // 检查这一段是否以标点符号结尾
          final endsWithPunctuation = segment.isNotEmpty &&
              (segment.endsWith('。') ||
                  segment.endsWith('，') ||
                  segment.endsWith('、') ||
                  segment.endsWith('！') ||
                  segment.endsWith('？') ||
                  segment.endsWith('.') ||
                  segment.endsWith(',') ||
                  segment.endsWith('!') ||
                  segment.endsWith('?') ||
                  segment.endsWith(';') ||
                  segment.endsWith('；'));

          if (endsWithPunctuation ||
              segmentLength >= (currentLineCharsPerLine * 0.8).floor()) {
            // 如果以标点结尾，或者已经接近一行的长度（80%以上），就换行
            currentIndex = nextNewlinePos;
            usedLines++;
            isFirstLineOfParagraph = false; // 下一行不是首行
          } else {
            // 否则，尝试填满这一行
            currentIndex = nextNewlinePos;
            if (currentIndex < text.length && text[currentIndex] == '\n') {
              currentIndex++; // 跳过换行符

              // 如果跳过换行符后还有内容，尝试继续填充这一行
              if (currentIndex < text.length &&
                  segmentLength < currentLineCharsPerLine) {
                final nextNewline2 = text.indexOf('\n', currentIndex);
                final endPos2 = nextNewline2 == -1 ? text.length : nextNewline2;
                final additionalChars = math.min(
                    currentLineCharsPerLine - segmentLength,
                    endPos2 - currentIndex);

                // 只有在有足够内容时才继续填充
                if (additionalChars > 0) {
                  currentIndex += additionalChars;
                }
              }
            }
            usedLines++;
            isFirstLineOfParagraph = false; // 下一行不是首行
          }
        } else {
          // 这一段太长，需要分成多行
          // 首行可能更短（有缩进），后续行用正常长度
          final charsToTake =
              math.min(currentLineCharsPerLine, nextNewlinePos - currentIndex);
          currentIndex += charsToTake;
          usedLines++;
          isFirstLineOfParagraph = false; // 填充后，下一行不是首行了
        }
      }

      // 提取页面内容
      String pageContent = text.substring(pageStartIndex, currentIndex);

      // 去掉页面结尾的所有换行符（空行）
      pageContent = pageContent.replaceAll(RegExp(r'\n+$'), '');

      // 如果去掉结尾换行符后页面为空，跳过这一页
      if (pageContent.isEmpty) {
        continue;
      }

      pages.add(pageContent);
    }

    return FastPaginationResult(
      pages: pages,
      charOffsets: charOffsets,
    );
  }
}
