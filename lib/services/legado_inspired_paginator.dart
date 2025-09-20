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

  /// 测量字体度量 (基于legado FontMetrics)
  static FontMetricsData _measureFontMetrics({
    required TextPainter textPaint,
    required String sampleText,
    required int maxWidth,
  }) {
    // 测量单个字符的平均宽度
    double totalWidth = 0;
    int charCount = 0;

    for (int i = 0; i < sampleText.length; i++) {
      final char = sampleText[i];
      textPaint.text = TextSpan(
        text: char,
        style: textPaint.text?.style,
      );
      textPaint.layout();
      totalWidth += textPaint.width;
      charCount++;
    }

    final averageCharWidth = charCount > 0 ? totalWidth / charCount : 14.0;

    // 测量文本高度
    textPaint.text = TextSpan(
      text: '中国Ag',
      style: textPaint.text?.style,
    );
    textPaint.layout();
    final textHeight = textPaint.height;

    // 获取字体度量 (使用估算值)
    final ascent = -textHeight * 0.8;
    final descent = textHeight * 0.2;
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

  /// 计算页面度量 (基于legado页面计算)
  static PageMetrics _calculatePageMetrics({
    required ViewMetrics viewMetrics,
    required FontMetricsData fontMetrics,
    required SpacingMetrics spacingMetrics,
  }) {
    // 计算每行字符数 (保留一些余量以避免换行问题)
    final charsPerLine = (viewMetrics.visibleWidth / fontMetrics.averageCharWidth).floor() - 1;

    // 计算每页行数 (保留底部间距)
    final linesPerPage = (viewMetrics.visibleHeight / spacingMetrics.actualLineHeight).floor() - 1;

    // 计算每页字符数
    final charsPerPage = charsPerLine * linesPerPage;

    return PageMetrics(
      charsPerLine: math.max(1, charsPerLine),
      linesPerPage: math.max(1, linesPerPage),
      charsPerPage: math.max(1, charsPerPage),
    );
  }

  /// 分页文本内容
  static List<String> paginateText(String text, LegadoPaginationParams params) {
    if (text.isEmpty) return [''];

    final pages = <String>[];
    final lines = text.split('\n');
    final processedLines = <String>[];

    // 处理每一行，如果过长则自动换行
    for (final line in lines) {
      if (line.length <= params.pageMetrics.charsPerLine) {
        processedLines.add(line);
      } else {
        // 长行分割
        int start = 0;
        while (start < line.length) {
          int end = math.min(start + params.pageMetrics.charsPerLine, line.length);
          processedLines.add(line.substring(start, end));
          start = end;
        }
      }
    }

    // 按页组织行
    int currentLineIndex = 0;
    while (currentLineIndex < processedLines.length) {
      final pageLines = <String>[];
      int linesInPage = 0;

      while (linesInPage < params.pageMetrics.linesPerPage && currentLineIndex < processedLines.length) {
        pageLines.add(processedLines[currentLineIndex]);
        currentLineIndex++;
        linesInPage++;
      }

      pages.add(pageLines.join('\n'));
    }

    return pages.isEmpty ? [''] : pages;
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