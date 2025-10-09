import 'package:flutter/material.dart';
import 'ultra_precise_paginator.dart';
import 'image_size_service.dart';

// 导出PageImageInfo和ImageStyle供外部使用
export 'ultra_precise_paginator.dart' show PageImageInfo, ImageStyle;

/// 分页字符串结果
class PaginationStringsResult {
  final List<String> pages;
  final int maxLinesPerPage;

  PaginationStringsResult({
    required this.pages,
    required this.maxLinesPerPage,
  });
}

/// 精确分页器适配器 - 使用超精确分页器（基于legado实现）
///
/// 核心改进：
/// 1. 固定行数：根据屏幕参数精确计算每页固定行数
/// 2. 填满每行：使用TextPainter精确测量，每行尽量填满字符
/// 3. 无溢出无浪费：任何参数组合都不会溢出，也不会有大量空白
/// 4. 段落跨页：段落可以自然跨页显示
/// 5. 首行缩进：支持段落首行缩进
///
/// 用于向后兼容现有系统
class PrecisePaginatorAdapter {
  static bool _isInitialized = false;

  /// 执行分页并转换为String列表（向后兼容）
  ///
  /// 参数说明：
  /// - text: 要分页的文本内容
  /// - screenSize: 屏幕尺寸
  /// - textStyle: 文本样式（包含fontSize, height等）
  /// - padding: 页面边距
  /// - firstLineIndent: 首行缩进字符数
  /// - paragraphSpacing: 段落间距（目前未使用，由引擎内部控制）
  /// - imageUrls: 图片URL列表（可选，支持自动提取和手动指定）
  static Future<PaginationStringsResult> paginateToStrings({
    required String text,
    required Size screenSize,
    required TextStyle textStyle,
    required EdgeInsets padding,
    double firstLineIndent = 2.0,
    double paragraphSpacing = 0.0,
    List<String>? imageUrls,
  }) async {
    debugPrint('🔧 [适配器] 开始精确分页...');

    // 从textStyle中提取参数
    final fontSize = textStyle.fontSize ?? 18.0;
    final lineHeight = textStyle.height ?? 1.8;
    final letterSpacing = textStyle.letterSpacing ?? 0.2;
    final fontFamily = textStyle.fontFamily;

    // 计算状态栏高度（从padding.top推算）
    final statusBarHeight = padding.top;

    // 初始化分页器（如果尚未初始化）
    if (!_isInitialized) {
      await UltraPrecisePaginator.initialize(
        screenSize: screenSize,
        pixelRatio: 1.0, // 使用默认像素密度
        fontSize: fontSize,
        lineHeight: lineHeight,
        letterSpacing: letterSpacing,
        padding: padding,
        statusBarHeight: statusBarHeight,
        firstLineIndent: firstLineIndent.toInt(),
        fontFamily: fontFamily,
      );
      _isInitialized = true;
    }

    // 处理图片
    List<PageImageInfo>? images;
    if (imageUrls != null && imageUrls.isNotEmpty) {
      debugPrint('📸 [适配器] 开始获取图片尺寸...');
      images = await ImageSizeService.getImageSizes(imageUrls);
      debugPrint('✅ [适配器] 获取到 ${images.length}/${imageUrls.length} 张图片尺寸');
    } else {
      // 尝试从文本中自动提取图片URL
      final extractedUrls = ImageSizeService.extractImageUrls(text);
      if (extractedUrls.isNotEmpty) {
        debugPrint('📸 [适配器] 自动提取到 ${extractedUrls.length} 张图片');
        images = await ImageSizeService.getImageSizes(extractedUrls);
        debugPrint(
            '✅ [适配器] 获取到 ${images.length}/${extractedUrls.length} 张图片尺寸');
      }
    }

    // 执行分页
    final result = await UltraPrecisePaginator.paginate(
      content: text,
      images: images,
      imageStyle: ImageStyle.auto, // 默认使用自适应样式
    );

    // 转换为String列表
    final pages = result.pages.map((page) {
      return page.lines.join('\n');
    }).toList();

    debugPrint(
        '✅ [适配器] 分页完成: ${pages.length} 页, 每页最多${result.maxLinesPerPage}行');

    return PaginationStringsResult(
      pages: pages,
      maxLinesPerPage: result.maxLinesPerPage,
    );
  }

  /// 重置分页器状态（当设置改变时调用）
  static void reset() {
    _isInitialized = false;
    debugPrint('🔄 [适配器] 已重置分页器状态');
  }

  /// 获取布局参数（用于调试）
  static Map<String, dynamic> getLayoutParams() {
    return UltraPrecisePaginator.getLayoutParams();
  }
}
