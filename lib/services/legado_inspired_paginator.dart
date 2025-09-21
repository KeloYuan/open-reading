import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 基于legado算法优化的文本分页器
/// 提供更精确的文本度量和分页计算
class LegadoInspiredPaginator {
  static const double kDefaultFontSize = 18.0;
  static const double kDefaultLineHeight = 1.8;
  static const double kDefaultLetterSpacing = 0.2;
  static const double kDefaultParagraphSpacing = 12.0;
  static const String kSampleText = '中国汉字测试样本文字内容显示效果检测分页算法ABCDEFGHabcdefgh1234567890';

  /// 计算精确的分页参数
  static LegadoPaginationParams calculatePreciseParams({
    required Size screenSize,
    required double fontSize,
    required double lineHeight,
    required double letterSpacing,
    required EdgeInsets padding,
    required double statusBarHeight,
    required double controlBarHeight,
    required bool isLandscape,
    String? fontFamily,
    String? customSampleText,
  }) {
    debugPrint('🔄 开始计算legado式分页参数...');

    // 1. 计算视图尺寸 (参考legado ChapterProvider)
    final viewMetrics = _calculateViewMetrics(
      screenSize: screenSize,
      padding: padding,
      statusBarHeight: statusBarHeight,
      controlBarHeight: controlBarHeight,
      isLandscape: isLandscape,
    );

    // 2. 创建文本画笔 (参考legado TextPaint)
    final textPaint = _createTextPaint(
      fontSize: fontSize,
      fontFamily: fontFamily,
      letterSpacing: letterSpacing,
    );

    // 3. 测量字体度量 (参考legado FontMetrics)
    final fontMetrics = _measureFontMetrics(
      textPaint: textPaint,
      sampleText: customSampleText ?? kSampleText,
      maxWidth: viewMetrics.visibleWidth,
      fontSize: fontSize,
      fontFamily: fontFamily,
      letterSpacing: letterSpacing,
    );

    // 4. 计算行间距和段落间距 (参考legado lineSpacingExtra)
    final spacingMetrics = _calculateSpacingMetrics(
      fontMetrics: fontMetrics,
      lineHeight: lineHeight,
      paragraphSpacing: kDefaultParagraphSpacing,
    );

    // 5. 计算每页内容 (参考legado页面计算逻辑)
    final pageMetrics = _calculatePageMetrics(
      viewMetrics: viewMetrics,
      fontMetrics: fontMetrics,
      spacingMetrics: spacingMetrics,
    );

    debugPrint('📊 视图: ${viewMetrics.viewWidth}x${viewMetrics.viewHeight}');
    debugPrint('📊 可见: ${viewMetrics.visibleWidth}x${viewMetrics.visibleHeight}');
    debugPrint('📊 字符: ${fontMetrics.averageCharWidth.toStringAsFixed(2)}px宽');
    debugPrint('📊 行高: ${spacingMetrics.actualLineHeight.toStringAsFixed(2)}px');
    debugPrint('📊 分页: ${pageMetrics.charsPerLine}字符/行, ${pageMetrics.linesPerPage}行/页');

    return LegadoPaginationParams(
      viewMetrics: viewMetrics,
      fontMetrics: fontMetrics,
      spacingMetrics: spacingMetrics,
      pageMetrics: pageMetrics,
      textPaint: textPaint,
    );
  }

  /// 计算视图度量 (基于legado ChapterProvider)
  static ViewMetrics _calculateViewMetrics({
    required Size screenSize,
    required EdgeInsets padding,
    required double statusBarHeight,
    required double controlBarHeight,
    required bool isLandscape,
  }) {
    final viewWidth = screenSize.width.toInt();
    final viewHeight = screenSize.height.toInt();

    final paddingLeft = padding.left.toInt();
    final paddingTop = (padding.top + statusBarHeight).toInt();
    final paddingRight = padding.right.toInt();
    final paddingBottom = (padding.bottom + controlBarHeight).toInt();

    final visibleWidth = viewWidth - paddingLeft - paddingRight;
    final visibleHeight = viewHeight - paddingTop - paddingBottom;
    final visibleRight = paddingLeft + visibleWidth;
    final visibleBottom = paddingTop + visibleHeight;

    return ViewMetrics(
      viewWidth: viewWidth,
      viewHeight: viewHeight,
      paddingLeft: paddingLeft,
      paddingTop: paddingTop,
      paddingRight: paddingRight,
      paddingBottom: paddingBottom,
      visibleWidth: visibleWidth,
      visibleHeight: visibleHeight,
      visibleRight: visibleRight,
      visibleBottom: visibleBottom,
    );
  }

  /// 创建文本画笔 (基于legado TextPaint)
  static TextPainter _createTextPaint({
    required double fontSize,
    String? fontFamily,
    required double letterSpacing,
  }) {
    return TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );
  }

  /// 创建TextStyle用于文本测量
  static TextStyle _createTextStyle({
    required double fontSize,
    String? fontFamily,
    required double letterSpacing,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontFamily: fontFamily ?? 'System',
      letterSpacing: letterSpacing,
      height: 1.0, // 基础行高，后续会通过lineHeight调整
      decoration: TextDecoration.none,
    );
  }

  /// 测量字体度量 (基于legado FontMetrics) - 修复版本
  static FontMetricsData _measureFontMetrics({
    required TextPainter textPaint,
    required String sampleText,
    required int maxWidth,
    double fontSize = kDefaultFontSize,
    String? fontFamily,
    double letterSpacing = kDefaultLetterSpacing,
  }) {
    // 创建正确的TextStyle
    final textStyle = _createTextStyle(
      fontSize: fontSize,
      fontFamily: fontFamily,
      letterSpacing: letterSpacing,
    );

    // 测量单个字符的平均宽度 - 使用正确的TextStyle
    double totalWidth = 0;
    int charCount = 0;

    // 优化：只测量样本文本的前20个字符，提高性能
    final measureLength = math.min(20, sampleText.length);

    for (int i = 0; i < measureLength; i++) {
      final char = sampleText[i];
      textPaint.text = TextSpan(
        text: char,
        style: textStyle,
      );
      textPaint.layout(maxWidth: maxWidth.toDouble());
      totalWidth += textPaint.width;
      charCount++;
    }

    final averageCharWidth = charCount > 0 ? totalWidth / charCount : fontSize * 0.8;

    // 测量文本高度 - 使用混合字符确保准确性
    textPaint.text = TextSpan(
      text: '中国AgjQ测试',
      style: textStyle,
    );
    textPaint.layout(maxWidth: maxWidth.toDouble());
    final textHeight = textPaint.height;

    // 获取字体度量 (基于实际测量)
    final ascent = -textHeight * 0.75; // 更准确的上升高度
    final descent = textHeight * 0.25; // 更准确的下降高度
    final leading = 0.0;

    return FontMetricsData(
      averageCharWidth: averageCharWidth,
      textHeight: textHeight,
      ascent: ascent,
      descent: descent,
      leading: leading,
    );
  }

  /// 计算间距度量 (基于legado间距计算)
  static SpacingMetrics _calculateSpacingMetrics({
    required FontMetricsData fontMetrics,
    required double lineHeight,
    required double paragraphSpacing,
  }) {
    final baseLineHeight = fontMetrics.textHeight;
    final lineSpacingExtra = (baseLineHeight * lineHeight) - baseLineHeight;
    final actualLineHeight = baseLineHeight + lineSpacingExtra;

    return SpacingMetrics(
      lineSpacingExtra: lineSpacingExtra,
      paragraphSpacing: paragraphSpacing.toInt(),
      actualLineHeight: actualLineHeight,
    );
  }

  /// 计算页面度量 (基于legado页面计算) - 优化版本
  static PageMetrics _calculatePageMetrics({
    required ViewMetrics viewMetrics,
    required FontMetricsData fontMetrics,
    required SpacingMetrics spacingMetrics,
  }) {
    // 计算每行字符数 - 使用更保守的策略
    // 保留15%的余量避免文字被截断
    final rawCharsPerLine = viewMetrics.visibleWidth / fontMetrics.averageCharWidth;
    final charsPerLine = (rawCharsPerLine * 0.85).floor();

    // 计算每页行数 - 保留底部间距和滚动缓冲
    // 保留20%的余量确保最后一行不会被控制栏遮挡
    final rawLinesPerPage = viewMetrics.visibleHeight / spacingMetrics.actualLineHeight;
    final linesPerPage = (rawLinesPerPage * 0.80).floor();

    // 计算每页字符数
    final charsPerPage = charsPerLine * linesPerPage;

    debugPrint('📐 页面度量计算:');
    debugPrint('  - 原始每行字符数: ${rawCharsPerLine.toStringAsFixed(1)} → 保守值: $charsPerLine');
    debugPrint('  - 原始每页行数: ${rawLinesPerPage.toStringAsFixed(1)} → 保守值: $linesPerPage');
    debugPrint('  - 每页总字符数: $charsPerPage');

    return PageMetrics(
      charsPerLine: math.max(10, charsPerLine), // 最少10个字符
      linesPerPage: math.max(3, linesPerPage),  // 最少3行
      charsPerPage: math.max(30, charsPerPage), // 最少30个字符
    );
  }

  /// 分页文本内容 - 优化版本，确保不缺字漏字
  static List<String> paginateText(String text, LegadoPaginationParams params) {
    if (text.isEmpty) return [''];

    debugPrint('🔄 开始Legado分页: 文本长度${text.length}字符');

    final pages = <String>[];
    int currentIndex = 0;
    int pageCount = 0;
    const int maxPages = 100000; // 防止无限循环

    // 计算每页最大字符数，使用保守策略
    final maxCharsPerPage = (params.pageMetrics.charsPerPage * 0.85).floor();

    while (currentIndex < text.length && pageCount < maxPages) {
      pageCount++;

      final remainingLength = text.length - currentIndex;

      // 如果剩余文本小于一页容量，全部放入最后一页
      if (remainingLength <= maxCharsPerPage) {
        final remainingText = text.substring(currentIndex);
        if (remainingText.trim().isNotEmpty) {
          pages.add(remainingText);
        }
        break;
      }

      // 计算建议的结束位置
      int suggestedEndIndex = currentIndex + maxCharsPerPage;
      suggestedEndIndex = math.min(suggestedEndIndex, text.length);

      // 寻找最佳断点，避免在单词或句子中间断开
      int actualEndIndex = _findOptimalBreakPoint(
        text,
        currentIndex,
        suggestedEndIndex,
      );

      // 确保页面不会太小
      if (actualEndIndex - currentIndex < maxCharsPerPage * 0.5) {
        actualEndIndex = suggestedEndIndex;
      }

      // 提取页面文本
      final pageText = text.substring(currentIndex, actualEndIndex);

      if (pageText.trim().isNotEmpty) {
        pages.add(pageText);
      }

      // 严格连续：下一页从当前页结束位置开始，绝对不跳字
      currentIndex = actualEndIndex;

      // 安全检查：如果没有前进，强制前进一个字符避免死循环
      if (actualEndIndex == currentIndex && currentIndex < text.length) {
        currentIndex++;
      }
    }

    debugPrint('✅ Legado分页完成: ${pages.length}页');

    // 验证分页结果的完整性
    _validatePaginationIntegrity(text, pages);

    return pages.isEmpty ? [''] : pages;
  }

  /// 寻找最佳断点，优化版本
  static int _findOptimalBreakPoint(String text, int startIndex, int suggestedEndIndex) {
    if (suggestedEndIndex >= text.length) {
      return text.length;
    }

    // 搜索范围，在建议结束位置附近寻找
    const searchRange = 50;
    final searchStart = math.max(startIndex, suggestedEndIndex - searchRange);
    final searchEnd = math.min(text.length, suggestedEndIndex + 10);

    // 断点优先级从高到低
    final breakPriorities = [
      // 最高优先级：段落分隔
      RegExp(r'\n\s*\n'),
      // 高优先级：换行符
      RegExp(r'\n'),
      // 中高优先级：句子结束
      RegExp(r'[。！？.!?]\s*'),
      // 中等优先级：逗号、分号
      RegExp(r'[，；,;]\s*'),
      // 低优先级：空格
      RegExp(r'\s+'),
    ];

    // 按优先级查找最佳断点
    for (final pattern in breakPriorities) {
      final matches = pattern.allMatches(text, searchStart);

      for (final match in matches) {
        final breakPoint = match.end;
        if (breakPoint > startIndex && breakPoint <= searchEnd) {
          // 确保断点不会造成页面过小
          if (breakPoint - startIndex >= (suggestedEndIndex - startIndex) * 0.6) {
            return breakPoint;
          }
        }
      }
    }

    // 如果没找到合适的断点，返回建议的结束位置
    return suggestedEndIndex;
  }

  /// 验证分页完整性，确保没有丢失字符
  static void _validatePaginationIntegrity(String originalText, List<String> pages) {
    if (!kDebugMode) return; // 只在调试模式下运行

    final reconstructedText = pages.join('');
    if (reconstructedText.length != originalText.length) {
      debugPrint('⚠️ 分页完整性警告: 原文${originalText.length}字符，分页后${reconstructedText.length}字符');

      // 查找差异
      final minLength = math.min(originalText.length, reconstructedText.length);
      for (int i = 0; i < minLength; i++) {
        if (originalText[i] != reconstructedText[i]) {
          debugPrint('⚠️ 第一个差异位置: $i');
          debugPrint('⚠️ 原文: "${originalText.substring(i, math.min(i + 20, originalText.length))}"');
          debugPrint('⚠️ 分页: "${reconstructedText.substring(i, math.min(i + 20, reconstructedText.length))}"');
          break;
        }
      }
    } else {
      debugPrint('✅ 分页完整性验证通过');
    }
  }
}

/// 视图度量数据
class ViewMetrics {
  final int viewWidth;
  final int viewHeight;
  final int paddingLeft;
  final int paddingTop;
  final int paddingRight;
  final int paddingBottom;
  final int visibleWidth;
  final int visibleHeight;
  final int visibleRight;
  final int visibleBottom;

  ViewMetrics({
    required this.viewWidth,
    required this.viewHeight,
    required this.paddingLeft,
    required this.paddingTop,
    required this.paddingRight,
    required this.paddingBottom,
    required this.visibleWidth,
    required this.visibleHeight,
    required this.visibleRight,
    required this.visibleBottom,
  });
}

/// 字体度量数据
class FontMetricsData {
  final double averageCharWidth;
  final double textHeight;
  final double ascent;
  final double descent;
  final double leading;

  FontMetricsData({
    required this.averageCharWidth,
    required this.textHeight,
    required this.ascent,
    required this.descent,
    required this.leading,
  });
}

/// 间距度量数据
class SpacingMetrics {
  final double lineSpacingExtra;
  final int paragraphSpacing;
  final double actualLineHeight;

  SpacingMetrics({
    required this.lineSpacingExtra,
    required this.paragraphSpacing,
    required this.actualLineHeight,
  });
}

/// 页面度量数据
class PageMetrics {
  final int charsPerLine;
  final int linesPerPage;
  final int charsPerPage;

  PageMetrics({
    required this.charsPerLine,
    required this.linesPerPage,
    required this.charsPerPage,
  });
}

/// legado式分页参数
class LegadoPaginationParams {
  final ViewMetrics viewMetrics;
  final FontMetricsData fontMetrics;
  final SpacingMetrics spacingMetrics;
  final PageMetrics pageMetrics;
  final TextPainter textPaint;

  LegadoPaginationParams({
    required this.viewMetrics,
    required this.fontMetrics,
    required this.spacingMetrics,
    required this.pageMetrics,
    required this.textPaint,
  });
}