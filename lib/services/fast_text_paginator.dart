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
    required double lineHeight,
    required EdgeInsets padding,
    double letterSpacing = 0.0,
    double paragraphSpacing = 0.0,
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
    final lineHeightPx = fontSize * lineHeight;

    // 根据屏幕实际情况动态计算安全边距
    // 策略：使用行高的倍数，随字体大小和行间距自适应
    double topSafetyMultiplier = 0.5; // 顶部：0.5倍行高
    double bottomSafetyMultiplier = 0.3; // 底部：0.3倍行高（更小，最大化内容）

    // 根据屏幕密度微调（高分辨率屏幕稍微增加一点）
    if (screenSize.height > 2500 || devicePixelRatio >= 3.5) {
      // 超高分辨率屏幕 (如 OPPO Find X8)
      topSafetyMultiplier = 0.6;
      bottomSafetyMultiplier = 0.2; // 底部更少，最大化内容
    } else if (screenSize.height > 2000 || devicePixelRatio >= 3.0) {
      topSafetyMultiplier = 0.55;
      bottomSafetyMultiplier = 0.25;
    } else if (screenSize.height > 1500 || devicePixelRatio >= 2.5) {
      topSafetyMultiplier = 0.5;
      bottomSafetyMultiplier = 0.3;
    }

    // 计算实际的安全边距（像素）= 行高 × 倍数
    final topSafetyMarginPx = lineHeightPx * topSafetyMultiplier;
    final bottomSafetyMarginPx = lineHeightPx * bottomSafetyMultiplier;

    // 计算可用高度（减去 padding 和安全边距）
    final availableHeight = screenSize.height -
        padding.top -
        padding.bottom -
        topSafetyMarginPx -
        bottomSafetyMarginPx;

    // 计算每行可以容纳的字符数
    // 字符宽度 = 字体大小 + 字间距
    final charWidth = fontSize + letterSpacing;
    final charsPerLine = (availableWidth / charWidth).floor();

    // 计算每页可以容纳的行数（向下取整）
    final linesPerPage = (availableHeight / lineHeightPx).floor();

    // 使用计算出的行数，不再额外减少
    final safeLinesPerPage = math.max(1, linesPerPage);

    debugPrint('📄 精确的逐行分页开始:');
    debugPrint(
        '   屏幕: ${screenSize.width.toInt()}×${screenSize.height.toInt()} (DPR: ${devicePixelRatio.toStringAsFixed(2)})');
    debugPrint(
        '   Padding: L${padding.left.toInt()} R${padding.right.toInt()} T${padding.top.toInt()} B${padding.bottom.toInt()}');
    debugPrint(
        '   安全边距: 顶部${topSafetyMultiplier}×行高(${topSafetyMarginPx.toInt()}px), 底部${bottomSafetyMultiplier}×行高(${bottomSafetyMarginPx.toInt()}px)');
    debugPrint('   可用空间: ${availableWidth.toInt()}×${availableHeight.toInt()}');
    debugPrint(
        '   排版参数: 字体${fontSize}px, 行高$lineHeight (${lineHeightPx.toInt()}px), 字间距$letterSpacing');
    debugPrint('   计算结果: 每行${charsPerLine}字符, 每页${safeLinesPerPage}行');
    debugPrint(
        '   空间利用率: ${(safeLinesPerPage * lineHeightPx / screenSize.height * 100).toStringAsFixed(1)}%');
    if (emptyLinesRemoved > 0) {
      debugPrint('   空行优化: 移除${emptyLinesRemoved}个多余换行符');
    }

    // 精确的逐行分页
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
      int usedLines = 0;

      // 逐行填充，直到达到最大行数
      while (usedLines < safeLinesPerPage && currentIndex < text.length) {
        // 检查当前字符是否是换行符
        if (text[currentIndex] == '\n') {
          // 空行，占1行
          currentIndex++;
          usedLines++;
          continue;
        }

        // 查找从当前位置到下一个换行符的位置
        int nextNewlinePos = text.indexOf('\n', currentIndex);
        if (nextNewlinePos == -1) {
          nextNewlinePos = text.length; // 没有换行符，就到文本末尾
        }

        // 计算这一段的长度（不包含换行符）
        int segmentLength = nextNewlinePos - currentIndex;

        if (segmentLength <= charsPerLine) {
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
              segmentLength >= (charsPerLine * 0.8).floor()) {
            // 如果以标点结尾，或者已经接近一行的长度（80%以上），就换行
            currentIndex = nextNewlinePos;
            usedLines++;
          } else {
            // 否则，尝试填满这一行（跳过换行符继续添加内容）
            currentIndex = nextNewlinePos;
            if (currentIndex < text.length && text[currentIndex] == '\n') {
              currentIndex++; // 跳过换行符
            }
            usedLines++;
          }
        } else {
          // 这一段太长，需要分成多行
          // 每次取 charsPerLine 个字符，填满每一行
          final charsToTake =
              math.min(charsPerLine, nextNewlinePos - currentIndex);
          currentIndex += charsToTake;
          usedLines++;
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
    required double lineHeight,
    required EdgeInsets padding,
    double letterSpacing = 0.0,
    double paragraphSpacing = 0.0,
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
    final lineHeightPx = fontSize * lineHeight;

    // 根据屏幕实际情况动态计算安全边距
    // 策略：使用行高的倍数，随字体大小和行间距自适应
    double topSafetyMultiplier = 0.5; // 顶部：0.5倍行高
    double bottomSafetyMultiplier = 0.3; // 底部：0.3倍行高

    // 根据屏幕密度微调
    if (screenSize.height > 2500 || devicePixelRatio >= 3.5) {
      topSafetyMultiplier = 0.6;
      bottomSafetyMultiplier = 0.2;
    } else if (screenSize.height > 2000 || devicePixelRatio >= 3.0) {
      topSafetyMultiplier = 0.55;
      bottomSafetyMultiplier = 0.25;
    } else if (screenSize.height > 1500 || devicePixelRatio >= 2.5) {
      topSafetyMultiplier = 0.5;
      bottomSafetyMultiplier = 0.3;
    }

    // 计算实际的安全边距（像素）= 行高 × 倍数
    final topSafetyMarginPx = lineHeightPx * topSafetyMultiplier;
    final bottomSafetyMarginPx = lineHeightPx * bottomSafetyMultiplier;

    // 计算可用高度
    final availableHeight = screenSize.height -
        padding.top -
        padding.bottom -
        topSafetyMarginPx -
        bottomSafetyMarginPx;

    // 计算每行可以容纳的字符数
    final charWidth = fontSize + letterSpacing;
    final charsPerLine = (availableWidth / charWidth).floor();
    final linesPerPage = (availableHeight / lineHeightPx).floor();

    // 使用计算出的行数，不再额外减少
    final safeLinesPerPage = math.max(1, linesPerPage);

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
      int usedLines = 0;

      // 逐行填充，直到达到最大行数
      while (usedLines < safeLinesPerPage && currentIndex < text.length) {
        // 检查当前字符是否是换行符
        if (text[currentIndex] == '\n') {
          // 空行，占1行
          currentIndex++;
          usedLines++;
          continue;
        }

        // 查找从当前位置到下一个换行符的位置
        int nextNewlinePos = text.indexOf('\n', currentIndex);
        if (nextNewlinePos == -1) {
          nextNewlinePos = text.length; // 没有换行符，就到文本末尾
        }

        // 计算这一段的长度（不包含换行符）
        int segmentLength = nextNewlinePos - currentIndex;

        if (segmentLength <= charsPerLine) {
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
              segmentLength >= (charsPerLine * 0.8).floor()) {
            // 如果以标点结尾，或者已经接近一行的长度（80%以上），就换行
            currentIndex = nextNewlinePos;
            usedLines++;
          } else {
            // 否则，尝试填满这一行（跳过换行符继续添加内容）
            currentIndex = nextNewlinePos;
            if (currentIndex < text.length && text[currentIndex] == '\n') {
              currentIndex++; // 跳过换行符
            }
            usedLines++;
          }
        } else {
          // 这一段太长，需要分成多行
          // 每次取 charsPerLine 个字符，填满每一行
          final charsToTake =
              math.min(charsPerLine, nextNewlinePos - currentIndex);
          currentIndex += charsToTake;
          usedLines++;
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
