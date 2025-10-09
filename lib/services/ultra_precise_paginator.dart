import 'package:flutter/material.dart';
import 'dart:async';
import 'text_layout_engine.dart';

// 导出PageImageInfo和ImageStyle供外部使用
export 'text_layout_engine.dart' show PageImageInfo, ImageStyle;

/// 分页结果
class PaginationResult {
  final List<PageData> pages;
  final int maxLinesPerPage; // 🔧 改名：不再是固定行数，而是最大行数
  final double lineHeight;
  final int totalCharacters;

  PaginationResult({
    required this.pages,
    required this.maxLinesPerPage,
    required this.lineHeight,
    required this.totalCharacters,
  });
}

/// 页面数据
class PageData {
  final int index;
  final List<String> lines;
  final String rawText;
  final bool hasImages;

  PageData({
    required this.index,
    required this.lines,
    required this.rawText,
    this.hasImages = false,
  });
}

/// 超精确文本分页器
///
/// 核心特性（完全基于legado实现）：
/// 1. **固定行数**：根据屏幕参数精确计算每页能容纳的固定行数（如34.4行取34行）
/// 2. **填满每行**：使用TextPainter精确测量，每行尽量填满字符
/// 3. **无溢出无浪费**：任何参数组合都不会溢出需要滑动，也不会有大量空白
/// 4. **段落跨页**：段落可以自然跨页显示
/// 5. **首行缩进**：支持段落首行缩进
/// 6. **图片支持**：支持图片排版（预留）
/// 7. **分页速度快**：优化算法，使用缓存机制
///
/// 算法核心（参照legado的ChapterProvider和TextChapterLayout）：
/// ```
/// 1. 初始化阶段：
///    - 计算visibleWidth = screenWidth - paddingLeft - paddingRight
///    - 计算visibleHeight = screenHeight - paddingTop - paddingBottom
///    - 测量字体，获取textHeight（单行高度）
///    - 计算actualLineHeight = textHeight * lineSpacingExtra
///    - 计算fixedLinesPerPage = floor(visibleHeight / actualLineHeight)
///
/// 2. 分页阶段：
///    - durY = 0 （当前Y坐标）
///    - 对每个段落：
///      a. 添加首行缩进
///      b. 使用TextPainter.layout(maxWidth: visibleWidth)自动换行
///      c. 对每一行：
///         - 检查：if (durY + actualLineHeight > visibleHeight) 翻页
///         - 添加行到当前页
///         - durY += actualLineHeight
///      d. 段落结束，durY += paragraphSpacing
///
/// 3. 关键点：
///    - 行高固定，确保每页行数一致
///    - TextPainter自动断行，确保每行填满
///    - 精确判断翻页时机，无溢出无浪费
/// ```
class UltraPrecisePaginator {
  static final _layoutEngine = TextLayoutEngine();
  static bool _isInitialized = false;

  /// 初始化分页器
  ///
  /// 必须在分页前调用一次，配置所有布局参数
  static Future<void> initialize({
    required Size screenSize,
    required double pixelRatio,
    required double fontSize,
    required double lineHeight,
    required double letterSpacing,
    required EdgeInsets padding,
    required double statusBarHeight,
    int firstLineIndent = 2,
    String? fontFamily,
  }) async {
    debugPrint('🚀 [超精确分页器] 初始化中...');

    _layoutEngine.initialize(
      screenSize: screenSize,
      pixelRatio: pixelRatio,
      fontSize: fontSize,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      padding: padding,
      statusBarHeight: statusBarHeight,
      firstLineIndent: firstLineIndent,
      fontFamily: fontFamily,
    );

    _isInitialized = true;

    debugPrint('✅ [超精确分页器] 初始化完成');
    debugPrint('   📊 每页最大行数: ${_layoutEngine.maxLinesPerPage}（动态填充）');
    debugPrint(
        '   📊 实际行高: ${(_layoutEngine.contentTextHeight * _layoutEngine.lineSpacingExtra).toStringAsFixed(2)}px');
  }

  /// 执行分页
  ///
  /// 参数：
  /// - content: 要分页的文本内容
  /// - title: 可选的标题
  /// - images: 可选的图片信息列表
  /// - imageStyle: 图片样式（默认auto）
  ///
  /// 返回：PaginationResult，包含所有页面数据
  static Future<PaginationResult> paginate({
    required String content,
    String? title,
    List<PageImageInfo>? images,
    ImageStyle imageStyle = ImageStyle.auto,
  }) async {
    if (!_isInitialized) {
      throw StateError('分页器未初始化，请先调用initialize()');
    }

    debugPrint('🔄 [超精确分页器] 开始分页...');
    debugPrint('   内容长度: ${content.length} 字符');
    if (title != null) {
      debugPrint('   标题: $title');
    }
    if (images != null && images.isNotEmpty) {
      debugPrint('   图片数量: ${images.length}');
      debugPrint('   图片样式: $imageStyle');
    }

    final startTime = DateTime.now();

    // 使用布局引擎进行分页
    final layoutPages = _layoutEngine.paginate(
      content,
      title: title,
      images: images,
      imageStyle: imageStyle,
    );

    // 转换为PageData格式
    final pages = <PageData>[];
    for (final layoutPage in layoutPages) {
      final lines = layoutPage.lines.map((line) => line.text).toList();
      pages.add(PageData(
        index: layoutPage.index,
        lines: lines,
        rawText: layoutPage.text,
      ));
    }

    final elapsed = DateTime.now().difference(startTime);

    final result = PaginationResult(
      pages: pages,
      maxLinesPerPage: _layoutEngine.maxLinesPerPage,
      lineHeight:
          _layoutEngine.contentTextHeight * _layoutEngine.lineSpacingExtra,
      totalCharacters: content.length,
    );

    debugPrint('✅ [超精确分页器] 分页完成:');
    debugPrint('   ⏱️ 耗时: ${elapsed.inMilliseconds}ms');
    debugPrint('   📄 总页数: ${pages.length}');
    debugPrint('   📊 每页最大: ${result.maxLinesPerPage} 行（动态填充）');
    debugPrint(
        '   📊 平均每页: ${(content.length / pages.length).toStringAsFixed(0)} 字符');
    debugPrint(
        '   🎯 性能: ${(content.length / elapsed.inMilliseconds).toStringAsFixed(0)} 字符/毫秒');

    return result;
  }

  /// 获取当前的布局参数（用于调试）
  static Map<String, dynamic> getLayoutParams() {
    if (!_isInitialized) {
      return {'error': '未初始化'};
    }

    return {
      'viewWidth': _layoutEngine.viewMetrics.viewWidth,
      'viewHeight': _layoutEngine.viewMetrics.viewHeight,
      'visibleWidth': _layoutEngine.viewMetrics.visibleWidth,
      'visibleHeight': _layoutEngine.viewMetrics.visibleHeight,
      'paddingLeft': _layoutEngine.viewMetrics.paddingLeft,
      'paddingTop': _layoutEngine.viewMetrics.paddingTop,
      'paddingRight': _layoutEngine.viewMetrics.paddingRight,
      'paddingBottom': _layoutEngine.viewMetrics.paddingBottom,
      'contentTextHeight': _layoutEngine.contentTextHeight,
      'lineSpacingExtra': _layoutEngine.lineSpacingExtra,
      'actualLineHeight':
          _layoutEngine.contentTextHeight * _layoutEngine.lineSpacingExtra,
      'maxLinesPerPage': _layoutEngine.maxLinesPerPage,
      'indentCharWidth': _layoutEngine.indentCharWidth,
    };
  }

  /// 估算总页数（快速估算，不进行实际分页）
  static int estimatePageCount(String content) {
    if (!_isInitialized) {
      return 0;
    }

    // 简单估算：平均每行字符数 * 每页行数
    final avgCharsPerLine = _layoutEngine.viewMetrics.visibleWidth /
        (_layoutEngine.contentTextHeight * 0.6); // 粗略估算
    final charsPerPage = avgCharsPerLine * _layoutEngine.maxLinesPerPage;
    return (content.length / charsPerPage).ceil();
  }
}
