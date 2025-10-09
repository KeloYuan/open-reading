import 'package:flutter/material.dart';
import '../models/text_page_data.dart';
import 'book_image_manager.dart';

/// 精确分页器（支持文本+图片混排）
///
/// 特点：
/// - 逐行测量，确保每页都填满
/// - 支持文本和图片混合排版
/// - 当内容超过页面高度时自动分页
/// - 支持各种排版参数动态调整
class PrecisePaginatorWithImages {
  final BookImageManager imageManager;

  PrecisePaginatorWithImages({BookImageManager? imageManager})
      : imageManager = imageManager ?? BookImageManager();

  /// 分页文本内容（支持图片）
  ///
  /// 参数：
  /// - [content] 文本内容
  /// - [images] 图片映射 {占位符: 文件路径}
  /// - [screenSize] 屏幕尺寸
  /// - [padding] 页面边距
  /// - [fontSize] 字体大小
  /// - [lineHeight] 行高倍数
  /// - [letterSpacing] 字符间距
  /// - [paragraphSpacing] 段落间距
  /// - [fontFamily] 字体
  /// - [imageStyle] 图片显示样式
  ///
  /// 返回：页面数据列表
  Future<List<TextPageData>> paginate({
    required String content,
    required Map<String, String> images,
    required Size screenSize,
    required EdgeInsets padding,
    required double fontSize,
    required double lineHeight,
    required double letterSpacing,
    required double paragraphSpacing,
    String? fontFamily,
    ImageDisplayStyle imageStyle = ImageDisplayStyle.auto,
  }) async {
    debugPrint('📖 开始精确分页...');
    debugPrint('   - 内容长度: ${content.length} 字符');
    debugPrint('   - 图片数量: ${images.length}');
    debugPrint('   - 屏幕尺寸: ${screenSize.width}x${screenSize.height}');

    // 计算可见区域
    final visibleWidth = screenSize.width - padding.left - padding.right;
    final visibleHeight = screenSize.height - padding.top - padding.bottom;

    debugPrint('   - 可见区域: ${visibleWidth}x$visibleHeight');

    // 创建文本样式
    final textStyle = TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      letterSpacing: letterSpacing,
      fontFamily: fontFamily == 'System' ? null : fontFamily,
    );

    // 测量文本高度
    final textPainter = TextPainter(
      text: TextSpan(text: '测', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final singleLineHeight = textPainter.height;
    textPainter.dispose();

    debugPrint('   - 行高: ${singleLineHeight.toStringAsFixed(2)}px');

    // 分页
    final pages = <TextPageData>[];
    final paragraphs = content.split('\n');

    var currentPageLines = <TextLineData>[];
    var currentY = 0.0;
    var pageIndex = 0;
    var globalCharIndex = 0;
    var pageStartIndex = 0;

    for (var paragraphIndex = 0;
        paragraphIndex < paragraphs.length;
        paragraphIndex++) {
      var paragraph = paragraphs[paragraphIndex];

      // 检查是否包含图片占位符 {{img:xxx}}
      final imgPattern = RegExp(r'\{\{img:([^}]+)\}\}');
      final imgMatches = imgPattern.allMatches(paragraph);

      if (imgMatches.isEmpty) {
        // 纯文本段落
        final result = await _processParagraph(
          paragraph: paragraph,
          currentPageLines: currentPageLines,
          currentY: currentY,
          paragraphIndex: paragraphIndex,
          globalCharIndex: globalCharIndex,
          visibleWidth: visibleWidth,
          visibleHeight: visibleHeight,
          singleLineHeight: singleLineHeight,
          paragraphSpacing: paragraphSpacing,
          textStyle: textStyle,
          padding: padding,
        );

        currentPageLines = result.lines;
        currentY = result.y;
        globalCharIndex = result.charIndex;

        // 检查是否需要创建新页
        if (result.shouldCreateNewPage) {
          pages.add(_createPage(
            index: pageIndex++,
            lines: currentPageLines,
            startIndex: pageStartIndex,
            globalCharIndex: globalCharIndex,
            screenSize: screenSize,
            padding: padding,
          ));

          currentPageLines = [];
          currentY = 0.0;
          pageStartIndex = globalCharIndex;
        }
      } else {
        // 包含图片的段落，需要特殊处理
        final result = await _processParagraphWithImages(
          paragraph: paragraph,
          images: images,
          currentPageLines: currentPageLines,
          currentY: currentY,
          paragraphIndex: paragraphIndex,
          globalCharIndex: globalCharIndex,
          visibleWidth: visibleWidth,
          visibleHeight: visibleHeight,
          singleLineHeight: singleLineHeight,
          paragraphSpacing: paragraphSpacing,
          textStyle: textStyle,
          padding: padding,
          imageStyle: imageStyle,
          pages: pages,
          pageIndex: pageIndex,
          pageStartIndex: pageStartIndex,
        );

        currentPageLines = result.lines;
        currentY = result.y;
        globalCharIndex = result.charIndex;
        pageIndex = result.pageIndex;
        pageStartIndex = result.pageStartIndex;
      }
    }

    // 创建最后一页
    if (currentPageLines.isNotEmpty) {
      pages.add(_createPage(
        index: pageIndex,
        lines: currentPageLines,
        startIndex: pageStartIndex,
        globalCharIndex: globalCharIndex,
        screenSize: screenSize,
        padding: padding,
        isLastPage: true,
      ));
    }

    debugPrint('✅ 分页完成: ${pages.length} 页');
    return pages;
  }

  /// 处理纯文本段落
  Future<
      ({
        List<TextLineData> lines,
        double y,
        int charIndex,
        bool shouldCreateNewPage,
      })> _processParagraph({
    required String paragraph,
    required List<TextLineData> currentPageLines,
    required double currentY,
    required int paragraphIndex,
    required int globalCharIndex,
    required double visibleWidth,
    required double visibleHeight,
    required double singleLineHeight,
    required double paragraphSpacing,
    required TextStyle textStyle,
    required EdgeInsets padding,
  }) async {
    if (paragraph.trim().isEmpty) {
      // 空段落，添加段落间距
      return (
        lines: currentPageLines,
        y: currentY + paragraphSpacing,
        charIndex: globalCharIndex,
        shouldCreateNewPage: false,
      );
    }

    var durY = currentY;
    var charIndex = globalCharIndex;
    var lines = List<TextLineData>.from(currentPageLines);
    var shouldCreateNewPage = false;

    // 简单实现：逐字符累加直到填满一行
    final chars = paragraph.split('');
    var currentLineText = '';
    var currentLineWidth = 0.0;

    for (var i = 0; i < chars.length; i++) {
      final char = chars[i];

      // 测量字符宽度
      final charPainter = TextPainter(
        text: TextSpan(text: char, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final charWidth = charPainter.width;
      charPainter.dispose();

      // 检查是否需要换行
      if (currentLineWidth + charWidth > visibleWidth &&
          currentLineText.isNotEmpty) {
        // 检查是否需要换页
        if (durY + singleLineHeight > visibleHeight && lines.isNotEmpty) {
          shouldCreateNewPage = true;
          break;
        }

        // 创建行
        final lineText = currentLineText;
        final columns = _createColumns(
          lineText: lineText,
          textStyle: textStyle,
          startX: padding.left,
          charStartIndex: charIndex - lineText.length,
          visibleWidth: visibleWidth,
        );

        final line = TextLineData(
          lineIndex: lines.length,
          columns: columns,
          bounds: Rect.fromLTWH(
            padding.left,
            padding.top + durY,
            visibleWidth,
            singleLineHeight,
          ),
          baseline: padding.top + durY + singleLineHeight * 0.8,
          isParagraphEnd: false,
          paragraphIndex: paragraphIndex,
          lineSpacing: singleLineHeight,
        );

        lines.add(line);
        durY += singleLineHeight;

        // 重置当前行
        currentLineText = char;
        currentLineWidth = charWidth;
      } else {
        currentLineText += char;
        currentLineWidth += charWidth;
      }

      charIndex++;
    }

    // 处理最后一行
    if (currentLineText.isNotEmpty && !shouldCreateNewPage) {
      if (durY + singleLineHeight <= visibleHeight || lines.isEmpty) {
        final columns = _createColumns(
          lineText: currentLineText,
          textStyle: textStyle,
          startX: padding.left,
          charStartIndex: charIndex - currentLineText.length,
          visibleWidth: visibleWidth,
        );

        final line = TextLineData(
          lineIndex: lines.length,
          columns: columns,
          bounds: Rect.fromLTWH(
            padding.left,
            padding.top + durY,
            visibleWidth,
            singleLineHeight,
          ),
          baseline: padding.top + durY + singleLineHeight * 0.8,
          isParagraphEnd: true,
          paragraphIndex: paragraphIndex,
          lineSpacing: singleLineHeight,
        );

        lines.add(line);
        durY += singleLineHeight;
      } else {
        shouldCreateNewPage = true;
      }
    }

    // 段落结束，添加段落间距
    if (!shouldCreateNewPage) {
      durY += paragraphSpacing;
    }

    return (
      lines: lines,
      y: durY,
      charIndex: charIndex,
      shouldCreateNewPage: shouldCreateNewPage,
    );
  }

  /// 处理包含图片的段落
  Future<
      ({
        List<TextLineData> lines,
        double y,
        int charIndex,
        int pageIndex,
        int pageStartIndex,
      })> _processParagraphWithImages({
    required String paragraph,
    required Map<String, String> images,
    required List<TextLineData> currentPageLines,
    required double currentY,
    required int paragraphIndex,
    required int globalCharIndex,
    required double visibleWidth,
    required double visibleHeight,
    required double singleLineHeight,
    required double paragraphSpacing,
    required TextStyle textStyle,
    required EdgeInsets padding,
    required ImageDisplayStyle imageStyle,
    required List<TextPageData> pages,
    required int pageIndex,
    required int pageStartIndex,
  }) async {
    var lines = List<TextLineData>.from(currentPageLines);
    var durY = currentY;
    var charIndex = globalCharIndex;
    var currentPageIndex = pageIndex;
    var currentPageStartIndex = pageStartIndex;

    // 图片占位符正则
    final imgPattern = RegExp(r'\{\{img:([^}]+)\}\}');
    var lastIndex = 0;

    for (var match in imgPattern.allMatches(paragraph)) {
      // 处理图片前的文本
      if (match.start > lastIndex) {
        final beforeText = paragraph.substring(lastIndex, match.start);
        final result = await _processParagraph(
          paragraph: beforeText,
          currentPageLines: lines,
          currentY: durY,
          paragraphIndex: paragraphIndex,
          globalCharIndex: charIndex,
          visibleWidth: visibleWidth,
          visibleHeight: visibleHeight,
          singleLineHeight: singleLineHeight,
          paragraphSpacing: 0, // 不添加段落间距
          textStyle: textStyle,
          padding: padding,
        );

        lines = result.lines;
        durY = result.y;
        charIndex = result.charIndex;

        if (result.shouldCreateNewPage) {
          pages.add(_createPage(
            index: currentPageIndex++,
            lines: lines,
            startIndex: currentPageStartIndex,
            globalCharIndex: charIndex,
            screenSize: Size(visibleWidth + padding.left + padding.right,
                visibleHeight + padding.top + padding.bottom),
            padding: padding,
          ));
          lines = [];
          durY = 0.0;
          currentPageStartIndex = charIndex;
        }
      }

      // 处理图片
      final imgKey = match.group(1)!;
      final imgPath = images[imgKey];

      if (imgPath != null) {
        final imgResult = await _processImage(
          imagePath: imgPath,
          currentPageLines: lines,
          currentY: durY,
          visibleWidth: visibleWidth,
          visibleHeight: visibleHeight,
          padding: padding,
          imageStyle: imageStyle,
          pages: pages,
          pageIndex: currentPageIndex,
          pageStartIndex: currentPageStartIndex,
          charIndex: charIndex,
        );

        lines = imgResult.lines;
        durY = imgResult.y;
        currentPageIndex = imgResult.pageIndex;
        currentPageStartIndex = imgResult.pageStartIndex;
        charIndex++; // 图片占一个字符位
      }

      lastIndex = match.end;
    }

    // 处理剩余文本
    if (lastIndex < paragraph.length) {
      final afterText = paragraph.substring(lastIndex);
      final result = await _processParagraph(
        paragraph: afterText,
        currentPageLines: lines,
        currentY: durY,
        paragraphIndex: paragraphIndex,
        globalCharIndex: charIndex,
        visibleWidth: visibleWidth,
        visibleHeight: visibleHeight,
        singleLineHeight: singleLineHeight,
        paragraphSpacing: paragraphSpacing,
        textStyle: textStyle,
        padding: padding,
      );

      lines = result.lines;
      durY = result.y;
      charIndex = result.charIndex;

      if (result.shouldCreateNewPage) {
        pages.add(_createPage(
          index: currentPageIndex++,
          lines: lines,
          startIndex: currentPageStartIndex,
          globalCharIndex: charIndex,
          screenSize: Size(visibleWidth + padding.left + padding.right,
              visibleHeight + padding.top + padding.bottom),
          padding: padding,
        ));
        lines = [];
        durY = 0.0;
        currentPageStartIndex = charIndex;
      }
    }

    return (
      lines: lines,
      y: durY,
      charIndex: charIndex,
      pageIndex: currentPageIndex,
      pageStartIndex: currentPageStartIndex,
    );
  }

  /// 处理图片
  Future<
      ({
        List<TextLineData> lines,
        double y,
        int pageIndex,
        int pageStartIndex,
      })> _processImage({
    required String imagePath,
    required List<TextLineData> currentPageLines,
    required double currentY,
    required double visibleWidth,
    required double visibleHeight,
    required EdgeInsets padding,
    required ImageDisplayStyle imageStyle,
    required List<TextPageData> pages,
    required int pageIndex,
    required int pageStartIndex,
    required int charIndex,
  }) async {
    // 获取图片尺寸
    final imageSize = await imageManager.getImageSize(imagePath);
    if (imageSize == null) {
      return (
        lines: currentPageLines,
        y: currentY,
        pageIndex: pageIndex,
        pageStartIndex: pageStartIndex,
      );
    }

    var imgWidth = imageSize.width;
    var imgHeight = imageSize.height;

    // 根据样式调整尺寸
    switch (imageStyle) {
      case ImageDisplayStyle.fullWidth:
        imgWidth = visibleWidth;
        imgHeight = imageSize.height * visibleWidth / imageSize.width;
        break;
      case ImageDisplayStyle.fullPage:
        // 独占一页，如果当前页有内容则先结束当前页
        if (currentPageLines.isNotEmpty) {
          final screenSize = Size(
            visibleWidth + padding.left + padding.right,
            visibleHeight + padding.top + padding.bottom,
          );
          pages.add(_createPage(
            index: pageIndex,
            lines: List<TextLineData>.from(currentPageLines),
            startIndex: pageStartIndex,
            globalCharIndex: charIndex,
            screenSize: screenSize,
            padding: padding,
          ));
          return (
            lines: <TextLineData>[],
            y: 0.0,
            pageIndex: pageIndex + 1,
            pageStartIndex: charIndex,
          );
        }
        imgWidth = visibleWidth;
        imgHeight = imageSize.height * visibleWidth / imageSize.width;
        if (imgHeight > visibleHeight) {
          imgWidth = imgWidth * visibleHeight / imgHeight;
          imgHeight = visibleHeight;
        }
        break;
      default:
        // auto: 保持比例，不超过可见区域
        if (imgWidth > visibleWidth) {
          imgHeight = imgHeight * visibleWidth / imgWidth;
          imgWidth = visibleWidth;
        }
        if (imgHeight > visibleHeight) {
          imgWidth = imgWidth * visibleHeight / imgHeight;
          imgHeight = visibleHeight;
        }
    }

    // 检查是否需要换页
    if (currentY + imgHeight > visibleHeight && currentPageLines.isNotEmpty) {
      final screenSize = Size(
        visibleWidth + padding.left + padding.right,
        visibleHeight + padding.top + padding.bottom,
      );
      pages.add(_createPage(
        index: pageIndex,
        lines: List<TextLineData>.from(currentPageLines),
        startIndex: pageStartIndex,
        globalCharIndex: charIndex,
        screenSize: screenSize,
        padding: padding,
      ));
      return (
        lines: <TextLineData>[],
        y: 0.0,
        pageIndex: pageIndex + 1,
        pageStartIndex: charIndex,
      );
    }

    // TODO: 创建图片行（需要扩展TextLineData支持图片）
    // 目前先跳过，返回原状态

    return (
      lines: List<TextLineData>.from(currentPageLines),
      y: currentY + imgHeight,
      pageIndex: pageIndex,
      pageStartIndex: pageStartIndex,
    );
  }

  /// 创建字符列
  List<TextColumnData> _createColumns({
    required String lineText,
    required TextStyle textStyle,
    required double startX,
    required int charStartIndex,
    required double visibleWidth,
  }) {
    final columns = <TextColumnData>[];
    var x = startX;

    for (var i = 0; i < lineText.length; i++) {
      final char = lineText[i];

      // 测量字符宽度
      final textPainter = TextPainter(
        text: TextSpan(text: char, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final charWidth = textPainter.width;
      final charHeight = textPainter.height;

      columns.add(TextColumnData.normal(
        char: char,
        charIndex: charStartIndex + i,
        bounds: Rect.fromLTWH(x, 0, charWidth, charHeight),
        baseline: charHeight * 0.8,
        fontMetrics: FontMetrics(
          width: charWidth,
          height: charHeight,
          ascent: -charHeight * 0.75,
          descent: charHeight * 0.25,
          leading: 0,
        ),
      ));

      x += charWidth;
      textPainter.dispose();
    }

    return columns;
  }

  /// 创建页面
  TextPageData _createPage({
    required int index,
    required List<TextLineData> lines,
    required int startIndex,
    required int globalCharIndex,
    required Size screenSize,
    required EdgeInsets padding,
    bool isLastPage = false,
  }) {
    final characterCount = globalCharIndex - startIndex;

    return TextPageData(
      index: index,
      lines: lines,
      startIndex: startIndex,
      endIndex: globalCharIndex,
      characterCount: characterCount,
      isLastPage: isLastPage,
      readProgress: 0.0, // 需要外部计算
      bounds: Rect.fromLTWH(
        padding.left,
        padding.top,
        screenSize.width - padding.left - padding.right,
        screenSize.height - padding.top - padding.bottom,
      ),
    );
  }
}
