import 'package:flutter/material.dart';

/// 文本列 - 对应legado的BaseColumn
/// 用于记录每个字符或图片的精确位置和宽度
abstract class TextColumn {
  final double start; // 起始X坐标
  final double end; // 结束X坐标

  TextColumn({required this.start, required this.end});

  double get width => end - start;
}

/// 字符列 - 对应legado的TextColumn
class CharColumn extends TextColumn {
  final String charData;

  CharColumn({
    required this.charData,
    required double start,
    required double end,
  }) : super(start: start, end: end);
}

/// 图片列 - 对应legado的ImageColumn
class ImageColumn extends TextColumn {
  final String src;

  ImageColumn({
    required this.src,
    required double start,
    required double end,
  }) : super(start: start, end: end);
}

/// 文本行 - 对应legado的TextLine
/// 记录一行的所有字符位置、行高等信息
class LayoutTextLine {
  final List<TextColumn> columns = [];
  String text = '';
  double lineTop = 0.0;
  double lineBase = 0.0;
  double lineBottom = 0.0;
  double indentWidth = 0.0;
  bool isParagraphEnd = false;
  bool isImage = false;
  final bool isTitle;

  LayoutTextLine({this.isTitle = false});

  void addColumn(TextColumn column) {
    columns.add(column);
  }

  double get height => lineBottom - lineTop;
  double get lineStart => columns.isEmpty ? 0.0 : columns.first.start;
  double get lineEnd => columns.isEmpty ? 0.0 : columns.last.end;
  int get charSize => text.length;
}

/// 文本页 - 对应legado的TextPage
/// 包含一页的所有行信息
class LayoutTextPage {
  final List<LayoutTextLine> lines = [];
  int index = 0;
  double height = 0.0;
  String text = '';

  void addLine(LayoutTextLine line) {
    lines.add(line);
  }

  int get lineSize => lines.length;
  LayoutTextLine getLine(int index) {
    return lines[index];
  }
}

/// 视图度量参数 - 对应legado的ChapterProvider视图相关变量
class ViewMetrics {
  final int viewWidth; // 屏幕总宽度
  final int viewHeight; // 屏幕总高度
  final int paddingLeft; // 左边距
  final int paddingTop; // 顶边距
  final int paddingRight; // 右边距
  final int paddingBottom; // 底边距
  final int visibleWidth; // 可见文本区域宽度
  final int visibleHeight; // 可见文本区域高度
  final int visibleRight; // 可见区域右边界
  final int visibleBottom; // 可见区域底边界

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

/// 图片样式枚举
enum ImageStyle {
  full, // 铺满宽度
  single, // 单独一页（图片居中）
  auto, // 自适应（默认）
}

/// 图片信息数据类
class PageImageInfo {
  final String src;
  final int width;
  final int height;

  PageImageInfo({
    required this.src,
    required this.width,
    required this.height,
  });
}

/// 文本布局引擎 - 核心分页计算类
/// 完全参照legado的ChapterProvider和TextChapterLayout实现
///
/// 核心算法：
/// 1. 根据屏幕参数精确计算visibleWidth和visibleHeight
/// 2. 使用TextPainter测量每个字符的实际宽度
/// 3. 逐字符排版，计算每行能容纳的字符数
/// 4. 逐行累加高度，当durY + lineHeight > visibleHeight时翻页
/// 5. 固定行高，确保每页都填满固定行数
/// 6. 支持图片排版，图片参与分页计算
class TextLayoutEngine {
  // 视图度量
  late ViewMetrics viewMetrics;

  // 文本样式
  late TextStyle contentTextStyle;
  late TextStyle titleTextStyle;

  // 计算出的行高和字体度量
  late double contentTextHeight;
  late double titleTextHeight;
  late double contentAscent;
  late double contentDescent;
  late double titleAscent;
  late double titleDescent;

  // 间距参数
  late double lineSpacingExtra; // 行间距倍数
  late double paragraphSpacing; // 段落间距
  late double indentCharWidth; // 缩进字符宽度
  late String indentString; // 缩进字符串

  // 每页最大行数（仅用于统计，不强制填充）
  int maxLinesPerPage = 0;

  /// 初始化布局引擎
  ///
  /// 参数说明：
  /// - screenSize: 屏幕尺寸
  /// - pixelRatio: 像素密度
  /// - fontSize: 字体大小
  /// - lineHeight: 行高倍数
  /// - letterSpacing: 字间距
  /// - padding: 页面边距
  /// - statusBarHeight: 状态栏高度
  /// - firstLineIndent: 首行缩进字符数
  /// - fontFamily: 字体族
  void initialize({
    required Size screenSize,
    required double pixelRatio,
    required double fontSize,
    required double lineHeight,
    required double letterSpacing,
    required EdgeInsets padding,
    required double statusBarHeight,
    int firstLineIndent = 2,
    String? fontFamily,
  }) {
    debugPrint('🔧 [布局引擎] 开始初始化...');
    debugPrint(
        '   屏幕: ${screenSize.width}x${screenSize.height}, 像素密度: $pixelRatio');
    debugPrint('   字体: ${fontSize}px, 行高: $lineHeight, 字间距: $letterSpacing');

    // 1. 计算视图度量 - 对应legado的upLayout()
    _calculateViewMetrics(
      screenSize: screenSize,
      padding: padding,
      statusBarHeight: statusBarHeight,
    );

    // 2. 创建文本样式 - 对应legado的getPaints()
    contentTextStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: fontFamily,
      letterSpacing: letterSpacing,
      height: 1.0, // 基础行高为1.0，实际行高通过lineSpacingExtra控制
      decoration: TextDecoration.none,
    );

    titleTextStyle = TextStyle(
      fontSize: fontSize + 2, // 标题字号稍大
      fontFamily: fontFamily,
      fontWeight: FontWeight.bold,
      letterSpacing: letterSpacing,
      height: 1.0,
      decoration: TextDecoration.none,
    );

    // 3. 测量字体度量 - 对应legado的titlePaintTextHeight等
    _measureFontMetrics(fontSize, lineHeight);

    // 4. 计算间距 - 对应legado的lineSpacingExtra等
    lineSpacingExtra = lineHeight;
    paragraphSpacing = 0.5; // 段落间距为0.5行高

    // 5. 计算缩进 - 对应legado的indentCharWidth
    indentString = '　' * firstLineIndent; // 使用全角空格
    final indentPainter = TextPainter(
      text: TextSpan(text: indentString, style: contentTextStyle),
      textDirection: TextDirection.ltr,
    );
    indentPainter.layout();
    indentCharWidth = indentPainter.width / firstLineIndent;
    indentPainter.dispose();

    // 6. 计算每页理论最大行数（仅用于统计）
    // 🔧 修复：不再强制填充固定行数，改用legado的动态翻页检查
    // legado方式：当 durY + lineHeight > visibleHeight 时自然翻页
    final theoreticalMaxLines =
        viewMetrics.visibleHeight / (contentTextHeight * lineSpacingExtra);
    maxLinesPerPage = theoreticalMaxLines.floor();

    debugPrint('✅ [布局引擎] 初始化完成:');
    debugPrint(
        '   可见区域: ${viewMetrics.visibleWidth}x${viewMetrics.visibleHeight}');
    debugPrint('   内容行高: ${contentTextHeight.toStringAsFixed(2)}px');
    debugPrint(
        '   实际行高: ${(contentTextHeight * lineSpacingExtra).toStringAsFixed(2)}px');
    debugPrint('   理论最大: $maxLinesPerPage 行（不强制填充）');
    debugPrint('   缩进宽度: ${indentCharWidth.toStringAsFixed(2)}px');
  }

  /// 计算视图度量 - 对应legado的upViewSize和upLayout
  void _calculateViewMetrics({
    required Size screenSize,
    required EdgeInsets padding,
    required double statusBarHeight,
  }) {
    final viewWidth = screenSize.width.toInt();
    final viewHeight = screenSize.height.toInt();

    // 计算边距（沉浸式阅读，保留必要空间）
    final paddingLeft = padding.left.toInt();
    final paddingRight = padding.right.toInt();
    final paddingTop = (statusBarHeight + padding.top).toInt();
    final paddingBottom = padding.bottom.toInt();

    // 计算可见区域
    final visibleWidth = viewWidth - paddingLeft - paddingRight;
    final visibleHeight = viewHeight - paddingTop - paddingBottom;
    final visibleRight = paddingLeft + visibleWidth;
    final visibleBottom = paddingTop + visibleHeight;

    viewMetrics = ViewMetrics(
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

  /// 测量字体度量 - 对应legado的titlePaint.textHeight等
  void _measureFontMetrics(double fontSize, double lineHeight) {
    // 测量内容文本
    final contentPainter = TextPainter(
      text: TextSpan(text: '测', style: contentTextStyle),
      textDirection: TextDirection.ltr,
    );
    contentPainter.layout();
    contentTextHeight = contentPainter.height;

    // 使用TextPainter的高度信息计算ascent和descent
    // Flutter中TextPainter不直接暴露FontMetrics，我们根据经验值计算
    contentAscent = contentPainter.height * 0.8;
    contentDescent = contentPainter.height * 0.2;
    contentPainter.dispose();

    // 测量标题文本
    final titlePainter = TextPainter(
      text: TextSpan(text: '测', style: titleTextStyle),
      textDirection: TextDirection.ltr,
    );
    titlePainter.layout();
    titleTextHeight = titlePainter.height;
    titleAscent = titlePainter.height * 0.8;
    titleDescent = titlePainter.height * 0.2;
    titlePainter.dispose();
  }

  /// 分页主方法 - 对应legado的getTextChapter
  ///
  /// 参数：
  /// - content: 文本内容
  /// - title: 标题（可选）
  /// - images: 图片信息列表（可选）
  /// - imageStyle: 图片样式（默认auto）
  ///
  /// 返回：分页后的页面列表
  List<LayoutTextPage> paginate(
    String content, {
    String? title,
    List<PageImageInfo>? images,
    ImageStyle imageStyle = ImageStyle.auto,
  }) {
    debugPrint('🔄 [布局引擎] 开始分页...');
    if (images != null && images.isNotEmpty) {
      debugPrint('   包含 ${images.length} 张图片');
    }

    final textPages = <LayoutTextPage>[];
    textPages.add(LayoutTextPage());

    int absStartX = viewMetrics.paddingLeft;
    double durY = 0.0;
    final stringBuilder = StringBuffer();

    // 处理标题（如果有）
    if (title != null && title.isNotEmpty) {
      final titleResult = _setTypeText(
        text: title,
        absStartX: absStartX,
        durY: durY,
        textPages: textPages,
        stringBuilder: stringBuilder,
        textStyle: titleTextStyle,
        textHeight: titleTextHeight,
        ascent: titleAscent,
        descent: titleDescent,
        isTitle: true,
      );
      absStartX = titleResult.$1;
      durY = titleResult.$2;

      textPages.last.lines.last.isParagraphEnd = true;
      stringBuilder.writeln();
      durY += contentTextHeight * paragraphSpacing;
    }

    // 创建图片索引（用于快速查找）
    final imageMap = <String, PageImageInfo>{};
    if (images != null) {
      for (final img in images) {
        imageMap[img.src] = img;
      }
    }

    // 图片标记正则表达式：<img src="..."/>
    final imgPattern = RegExp(r'''<img[^>]+src=["']([^"']+)["'][^>]*>''');

    // 处理内容（按段落分割）
    final paragraphs = content.split('\n');
    for (int i = 0; i < paragraphs.length; i++) {
      var paragraph = paragraphs[i].trim();
      if (paragraph.isEmpty) continue;

      // 检查段落中是否包含图片
      final imgMatches = imgPattern.allMatches(paragraph);

      if (imgMatches.isEmpty) {
        // 纯文本段落
        final paragraphText = indentString + paragraph;

        final result = _setTypeText(
          text: paragraphText,
          absStartX: absStartX,
          durY: durY,
          textPages: textPages,
          stringBuilder: stringBuilder,
          textStyle: contentTextStyle,
          textHeight: contentTextHeight,
          ascent: contentAscent,
          descent: contentDescent,
          isTitle: false,
          hasIndent: true,
        );
        absStartX = result.$1;
        durY = result.$2;

        textPages.last.lines.last.isParagraphEnd = true;
        stringBuilder.writeln();
      } else {
        // 包含图片的段落，需要分段处理
        int lastEnd = 0;

        for (final match in imgMatches) {
          // 处理图片前的文本
          if (match.start > lastEnd) {
            final beforeText = paragraph.substring(lastEnd, match.start).trim();
            if (beforeText.isNotEmpty) {
              final textToAdd = (lastEnd == 0 ? indentString : '') + beforeText;

              final textResult = _setTypeText(
                text: textToAdd,
                absStartX: absStartX,
                durY: durY,
                textPages: textPages,
                stringBuilder: stringBuilder,
                textStyle: contentTextStyle,
                textHeight: contentTextHeight,
                ascent: contentAscent,
                descent: contentDescent,
                isTitle: false,
                hasIndent: lastEnd == 0,
              );
              absStartX = textResult.$1;
              durY = textResult.$2;
            }
          }

          // 处理图片
          final imgSrc = match.group(1)!;
          final imgInfo = imageMap[imgSrc];

          if (imgInfo != null) {
            final imgResult = _setTypeImage(
              imageInfo: imgInfo,
              absStartX: absStartX,
              durY: durY,
              textPages: textPages,
              stringBuilder: stringBuilder,
              imageStyle: imageStyle,
            );
            absStartX = imgResult.$1;
            durY = imgResult.$2;
          } else {
            debugPrint('⚠️ 未找到图片信息: $imgSrc');
          }

          lastEnd = match.end;
        }

        // 处理图片后的文本
        if (lastEnd < paragraph.length) {
          final afterText = paragraph.substring(lastEnd).trim();
          if (afterText.isNotEmpty) {
            final textResult = _setTypeText(
              text: afterText,
              absStartX: absStartX,
              durY: durY,
              textPages: textPages,
              stringBuilder: stringBuilder,
              textStyle: contentTextStyle,
              textHeight: contentTextHeight,
              ascent: contentAscent,
              descent: contentDescent,
              isTitle: false,
              hasIndent: false,
            );
            absStartX = textResult.$1;
            durY = textResult.$2;
          }
        }

        textPages.last.lines.last.isParagraphEnd = true;
        stringBuilder.writeln();
      }

      // 段落间距
      if (i < paragraphs.length - 1) {
        durY += contentTextHeight * paragraphSpacing;
      }
    }

    // 设置最后一页的高度和文本
    final lastPage = textPages.last;
    if (lastPage.height < durY) {
      lastPage.height = durY;
    }
    lastPage.text = stringBuilder.toString();

    // 设置页面索引
    for (int i = 0; i < textPages.length; i++) {
      textPages[i].index = i;
    }

    debugPrint('✅ [布局引擎] 分页完成: ${textPages.length} 页');
    return textPages;
  }

  /// 排版图片 - 对应legado的setTypeImage
  ///
  /// 核心逻辑：
  /// 1. 根据图片样式计算显示尺寸
  /// 2. 检查当前页是否能容纳图片
  /// 3. 如果不能容纳则翻页
  /// 4. 添加图片行到当前页
  (int, double) _setTypeImage({
    required PageImageInfo imageInfo,
    required int absStartX,
    required double durY,
    required List<LayoutTextPage> textPages,
    required StringBuffer stringBuilder,
    required ImageStyle imageStyle,
  }) {
    int currentAbsStartX = absStartX;
    double currentDurY = durY;

    // 检查图片尺寸是否有效
    if (imageInfo.width <= 0 || imageInfo.height <= 0) {
      debugPrint('⚠️ 图片尺寸无效: ${imageInfo.src}');
      return (currentAbsStartX, currentDurY);
    }

    // 计算图片显示尺寸
    int displayWidth = imageInfo.width;
    int displayHeight = imageInfo.height;

    switch (imageStyle) {
      case ImageStyle.full:
        // 铺满宽度
        displayWidth = viewMetrics.visibleWidth;
        displayHeight =
            (imageInfo.height * viewMetrics.visibleWidth / imageInfo.width)
                .round();
        break;

      case ImageStyle.single:
        // 单独一页，图片居中
        displayWidth = viewMetrics.visibleWidth;
        displayHeight =
            (imageInfo.height * viewMetrics.visibleWidth / imageInfo.width)
                .round();

        // 如果高度超过可见高度，按高度缩放
        if (displayHeight > viewMetrics.visibleHeight) {
          displayWidth =
              (displayWidth * viewMetrics.visibleHeight / displayHeight)
                  .round();
          displayHeight = viewMetrics.visibleHeight;
        }

        // 如果当前页已有内容，翻页
        if (currentDurY > 0) {
          final currentPage = textPages.last;
          if (currentPage.height < currentDurY) {
            currentPage.height = currentDurY;
          }
          currentPage.text = stringBuilder.toString();

          textPages.add(LayoutTextPage());
          stringBuilder.clear();
          currentAbsStartX = viewMetrics.paddingLeft;
          currentDurY = 0;
        }

        // 图片垂直居中
        if (displayHeight < viewMetrics.visibleHeight) {
          final adjustHeight =
              (viewMetrics.visibleHeight - displayHeight) / 2.0;
          currentDurY = adjustHeight;
        }
        break;

      case ImageStyle.auto:
        // 自适应：如果宽度超过可见宽度，缩放
        if (imageInfo.width > viewMetrics.visibleWidth) {
          displayHeight =
              (imageInfo.height * viewMetrics.visibleWidth / imageInfo.width)
                  .round();
          displayWidth = viewMetrics.visibleWidth;
        }

        // 如果高度超过可见高度，按高度缩放
        if (displayHeight > viewMetrics.visibleHeight) {
          displayWidth =
              (displayWidth * viewMetrics.visibleHeight / displayHeight)
                  .round();
          displayHeight = viewMetrics.visibleHeight;
        }

        // 检查当前页是否能容纳图片
        if (currentDurY + displayHeight > viewMetrics.visibleHeight) {
          final currentPage = textPages.last;
          if (currentPage.height < currentDurY) {
            currentPage.height = currentDurY;
          }
          currentPage.text = stringBuilder.toString();

          textPages.add(LayoutTextPage());
          stringBuilder.clear();
          currentAbsStartX = viewMetrics.paddingLeft;
          currentDurY = 0;
        }
        break;
    }

    // 创建图片行
    final imageLine = LayoutTextLine(isTitle: false);
    imageLine.isImage = true;
    imageLine.text = ' '; // 占位符

    imageLine.lineTop = currentDurY + viewMetrics.paddingTop;
    currentDurY += displayHeight;
    imageLine.lineBottom = currentDurY + viewMetrics.paddingTop;
    imageLine.lineBase = imageLine.lineBottom;

    // 图片水平居中
    final startX = (viewMetrics.visibleWidth - displayWidth) / 2.0;
    final endX = startX + displayWidth;

    imageLine.addColumn(ImageColumn(
      src: imageInfo.src,
      start: currentAbsStartX + startX,
      end: currentAbsStartX + endX,
    ));

    // 添加到当前页
    textPages.last.addLine(imageLine);
    stringBuilder.write(' '); // 占位符

    // 更新页面高度
    if (textPages.last.height < currentDurY) {
      textPages.last.height = currentDurY;
    }

    // 图片后添加间距
    currentDurY += contentTextHeight * paragraphSpacing;

    return (currentAbsStartX, currentDurY);
  }

  /// 排版文字 - 对应legado的setTypeText
  ///
  /// 核心逻辑：
  /// 1. 使用TextPainter测量文本，获取每行
  /// 2. 对每行中的字符，逐个测量宽度并排版
  /// 3. 检查是否超出visibleHeight，如果超出则创建新页面
  /// 4. 支持首行缩进和两端对齐
  (int, double) _setTypeText({
    required String text,
    required int absStartX,
    required double durY,
    required List<LayoutTextPage> textPages,
    required StringBuffer stringBuilder,
    required TextStyle textStyle,
    required double textHeight,
    required double ascent,
    required double descent,
    required bool isTitle,
    bool hasIndent = false,
  }) {
    // 使用TextPainter进行文本布局，获取自动换行结果
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );
    textPainter.layout(maxWidth: viewMetrics.visibleWidth.toDouble());

    double currentDurY = durY;
    int currentAbsStartX = absStartX;

    // 获取所有行
    final lineCount = textPainter.computeLineMetrics().length;

    for (int lineIndex = 0; lineIndex < lineCount; lineIndex++) {
      // 检查是否需要翻页 - 对应legado的prepareNextPageIfNeed
      if (currentDurY + textHeight * lineSpacingExtra >
          viewMetrics.visibleHeight) {
        // 当前页满，创建新页
        final currentPage = textPages.last;
        if (currentPage.height < currentDurY) {
          currentPage.height = currentDurY;
        }
        currentPage.text = stringBuilder.toString();

        textPages.add(LayoutTextPage());
        stringBuilder.clear();
        currentAbsStartX = viewMetrics.paddingLeft;
        currentDurY = 0.0;
      }

      // 获取当前行的文本
      final lineMetrics = textPainter.computeLineMetrics()[lineIndex];
      final lineStart = textPainter
          .getPositionForOffset(
            Offset(0, lineMetrics.baseline - lineMetrics.ascent / 2),
          )
          .offset;
      final lineEnd = textPainter
          .getPositionForOffset(
            Offset(textPainter.width,
                lineMetrics.baseline - lineMetrics.ascent / 2),
          )
          .offset;

      if (lineStart >= text.length) break;

      final lineText = text.substring(
        lineStart,
        lineEnd.clamp(lineStart, text.length),
      );

      // 创建新行
      final textLine = LayoutTextLine(isTitle: isTitle);
      textLine.text = lineText;

      // 逐字符排版 - 对应legado的addCharsToLine系列方法
      _addCharsToLine(
        textLine: textLine,
        lineText: lineText,
        absStartX: currentAbsStartX,
        textStyle: textStyle,
        isFirstLine: lineIndex == 0 && hasIndent,
        isLastLine: lineIndex == lineCount - 1,
        isTitle: isTitle,
      );

      // 更新行的位置信息
      textLine.lineTop = currentDurY + viewMetrics.paddingTop;
      textLine.lineBottom = textLine.lineTop + textHeight;
      textLine.lineBase = textLine.lineBottom - descent;

      // 添加到当前页
      textPages.last.addLine(textLine);
      stringBuilder.write(lineText);

      // 更新Y坐标
      currentDurY += textHeight * lineSpacingExtra;

      // 更新页面高度
      if (textPages.last.height < currentDurY) {
        textPages.last.height = currentDurY;
      }
    }

    textPainter.dispose();
    return (currentAbsStartX, currentDurY);
  }

  /// 添加字符到行 - 对应legado的addCharsToLineFirst、addCharsToLineMiddle等
  ///
  /// 实现两端对齐和首行缩进
  void _addCharsToLine({
    required LayoutTextLine textLine,
    required String lineText,
    required int absStartX,
    required TextStyle textStyle,
    required bool isFirstLine,
    required bool isLastLine,
    required bool isTitle,
  }) {
    // 测量每个字符的宽度
    final charWidths = <double>[];
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < lineText.length; i++) {
      final char = lineText[i];
      textPainter.text = TextSpan(text: char, style: textStyle);
      textPainter.layout();
      charWidths.add(textPainter.width);
    }

    double currentX = 0.0;

    // 首行缩进处理
    if (isFirstLine) {
      textLine.indentWidth = indentCharWidth * indentString.length;
      // 缩进字符已经在lineText中，直接计算即可
    }

    // 逐字符添加
    for (int i = 0; i < lineText.length; i++) {
      final char = lineText[i];
      final charWidth = charWidths[i];

      textLine.addColumn(CharColumn(
        charData: char,
        start: absStartX + currentX,
        end: absStartX + currentX + charWidth,
      ));

      currentX += charWidth;
    }

    textPainter.dispose();
  }
}
