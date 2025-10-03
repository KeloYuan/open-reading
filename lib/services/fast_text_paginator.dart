import 'package:flutter/material.dart';

/// 分页进度回调
typedef FastPaginationProgressCallback = void Function(
    int currentPage, String stage);

/// 页面内容元素类型
enum PageElementType {
  text, // 文本内容
  image, // 图片内容
}

/// 页面内容元素
class PageElement {
  final PageElementType type;
  final String content; // 文本内容或图片URL
  final double? width; // 图片宽度（可选）
  final double? height; // 图片高度（可选）

  const PageElement.text(this.content)
      : type = PageElementType.text,
        width = null,
        height = null;

  const PageElement.image(this.content, {this.width, this.height})
      : type = PageElementType.image;
}

/// 分页结果
class FastPaginationResult {
  /// 分页后的文本页面列表
  final List<String> pages;

  /// 每页在原文中的字符起始位置
  final List<int> charOffsets;

  /// 每页的内容元素列表（包含文本和图片）
  final List<List<PageElement>>? pageElements;

  /// 每页的额外行间距（用于底部对齐）
  /// 如果启用底部对齐，这个值会被添加到每行的间距中
  final List<double>? pageExtraLineSpacing;

  const FastPaginationResult({
    required this.pages,
    required this.charOffsets,
    this.pageElements,
    this.pageExtraLineSpacing,
  });
}

/// 快速文本分页器
///
/// 使用精确的逐行填充算法，确保每页都正好填满指定的行数
class FastTextPaginator {
  /// 字符宽度缓存（key: 样式参数哈希，value: 字符宽度数组）
  static final Map<String, Map<String, double>> _charWidthCache = {};

  /// 最大缓存条目数（避免内存泄漏）
  static const int _maxCacheEntries = 10;

  /// 生成样式缓存键
  static String _getStyleKey(
    double fontSize,
    double letterSpacing,
    double lineSpacing,
  ) {
    return '${fontSize}_${letterSpacing}_${lineSpacing}';
  }

  /// 清理缓存（当缓存过多时）
  static void _cleanCache() {
    if (_charWidthCache.length > _maxCacheEntries) {
      // 移除最旧的缓存（简单实现：清空全部）
      _charWidthCache.clear();
      debugPrint('🧹 字符宽度缓存已清理');
    }
  }

  /// 清除所有缓存（供外部调用，比如切换主题时）
  static void clearCache() {
    _charWidthCache.clear();
    debugPrint('🧹 字符宽度缓存已清空');
  }

  /// 精确分页（动态测量版本 - 支持图片，准确处理所有字符）
  ///
  /// 核心逻辑：
  /// 1. 使用 TextPainter 动态测量每段文本的实际高度
  /// 2. 支持图片（保留图片标签）
  /// 3. 保守地填充每一页，保证不超出屏幕
  static Future<FastPaginationResult> paginateAccurate({
    required String text,
    required Size screenSize,
    required double fontSize,
    required double lineSpacing,
    required EdgeInsets padding,
    double letterSpacing = 0.0,
    double firstLineIndent = 0.0,
    double devicePixelRatio = 1.0,
    bool supportImages = true,
    FastPaginationProgressCallback? onProgress,
  }) async {
    if (text.isEmpty) {
      return const FastPaginationResult(pages: [], charOffsets: []);
    }

    // 预处理文本：规范化空行
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 计算可用空间
    final visibleWidth = screenSize.width - padding.left - padding.right;
    final visibleHeight = screenSize.height - padding.top - padding.bottom;

    // 创建 TextPainter 用于精确测量
    final textStyle = TextStyle(
      fontSize: fontSize,
      letterSpacing: letterSpacing,
      height: lineSpacing,
    );
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
    );

    // 直接使用可见高度，不要额外的安全边距（padding已经包含了安全区）
    final effectiveHeight = visibleHeight;

    debugPrint('📄 精确分页（动态测量）:');
    debugPrint(
        '   屏幕: ${screenSize.width.toInt()}×${screenSize.height.toInt()}px');
    debugPrint('   可用: ${visibleWidth.toInt()}×${visibleHeight.toInt()}px');
    debugPrint(
        '   字体: ${fontSize}px, 行距: ${lineSpacing}x, 字间距: ${letterSpacing}px');

    final List<String> pages = [];
    final List<int> charOffsets = [];
    final List<List<PageElement>> pageElements = [];

    int currentIndex = 0;
    double currentY = 0.0;
    final StringBuffer pageBuffer = StringBuffer();
    final List<PageElement> currentPageElements = [];

    // 图片正则 (匹配 <img src="..."> 或 <img src='...'>)
    final imgPattern = RegExp('<img\\s+src=["\']([^"\']+)["\'][^>]*>');

    onProgress?.call(0, '正在分页...');

    /// 完成当前页
    void finishPage() {
      if (pageBuffer.isNotEmpty || currentPageElements.isNotEmpty) {
        final content = pageBuffer.toString();
        if (content.trim().isNotEmpty ||
            currentPageElements.any((e) => e.type == PageElementType.image)) {
          pages.add(content);
          // 如果有文本内容，创建一个文本元素
          final elementsForThisPage = <PageElement>[];
          if (content.trim().isNotEmpty) {
            elementsForThisPage.add(PageElement.text(content));
          }
          // 添加图片元素
          elementsForThisPage.addAll(currentPageElements
              .where((e) => e.type == PageElementType.image));
          pageElements.add(elementsForThisPage);
        }
        pageBuffer.clear();
        currentPageElements.clear();
        currentY = 0.0;
      }
    }

    /// 尝试添加文本，返回是否成功
    bool tryAddText(String textToAdd) {
      if (textToAdd.isEmpty) return true;

      // 测量添加后的总高度（当前页内容 + 新文本）
      final testContent = pageBuffer.toString() + textToAdd;
      textPainter.text = TextSpan(text: testContent, style: textStyle);
      textPainter.layout(maxWidth: visibleWidth);
      final totalHeight = textPainter.height;

      // 检查是否超出可用高度
      if (totalHeight > effectiveHeight) {
        return false;
      }

      // 放得下，添加
      pageBuffer.write(textToAdd);
      currentY = totalHeight; // 更新当前高度为实际测量的总高度
      return true;
    }

    /// 添加图片
    void addImage(String src) {
      // 计算图片尺寸
      double imgWidth = visibleWidth;
      double imgHeight = visibleWidth * 0.6; // 默认宽高比

      if (imgHeight > visibleHeight * 0.7) {
        imgHeight = visibleHeight * 0.7;
        imgWidth = imgHeight / 0.6;
      }

      // 如果当前页放不下，开新页
      if (currentY + imgHeight > effectiveHeight) {
        finishPage();
        charOffsets.add(currentIndex);
      }

      currentPageElements
          .add(PageElement.image(src, width: imgWidth, height: imgHeight));
      currentY += imgHeight + fontSize * 0.5; // 图片后留间距
    }

    // 逐块处理文本
    while (currentIndex < text.length) {
      // 如果是新页，记录起始位置
      if (currentY == 0.0 && pageBuffer.isEmpty) {
        charOffsets.add(currentIndex);
      }

      // 查找下一个图片
      final remainingText = text.substring(currentIndex);
      final imgMatch =
          supportImages ? imgPattern.firstMatch(remainingText) : null;

      if (imgMatch != null && imgMatch.start < 100) {
        // 处理图片前的文本
        if (imgMatch.start > 0) {
          final beforeImg = remainingText.substring(0, imgMatch.start);
          if (!tryAddText(beforeImg)) {
            finishPage();
            charOffsets.add(currentIndex);
            tryAddText(beforeImg);
          }
          currentIndex += imgMatch.start;
        }

        // 添加图片
        addImage(imgMatch.group(1)!);
        currentIndex += imgMatch.group(0)!.length;
      } else {
        // 逐字符添加，确保每页都填满
        final char = text[currentIndex];
        if (!tryAddText(char)) {
          // 当前页放不下这个字符，翻页后再添加
          finishPage();
          charOffsets.add(currentIndex);
          tryAddText(char);
        }
        currentIndex++;
      }

      // 进度报告（每处理5000个字符报告一次）
      if (currentIndex % 5000 == 0) {
        await Future.delayed(const Duration(milliseconds: 1));
        final progress = (currentIndex / text.length * 100).toStringAsFixed(1);
        onProgress?.call(pages.length, '正在分页... $progress%');
      }
    }

    // 完成最后一页
    finishPage();

    debugPrint('✅ 分页完成: ${pages.length}页');
    debugPrint('   平均每页: ${(text.length / pages.length).toInt()}字符');

    onProgress?.call(pages.length, '分页完成');

    return FastPaginationResult(
      pages: pages,
      charOffsets: charOffsets,
      pageElements: pageElements,
    );
  }

  /// 快速分页（异步版本，支持进度回调）
  ///
  /// 🚀 预测量法（参考 Legado 的 paint.getTextWidths）
  /// 核心思想：一次性测量所有字符宽度，然后通过累加快速分页
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

    // 预处理文本：规范化空行
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 计算可用空间
    final visibleWidth = screenSize.width - padding.left - padding.right;
    final visibleHeight = screenSize.height - padding.top - padding.bottom;

    // 创建 TextPainter 用于测量
    final textStyle = TextStyle(
      fontSize: fontSize,
      height: lineSpacing,
      letterSpacing: letterSpacing,
    );
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
    );

    // 1️⃣ 测量单行高度
    textPainter.text = TextSpan(text: '测', style: textStyle);
    textPainter.layout();
    final lineHeight = textPainter.height;

    // ⭐ 不要安全边距，字体22时完美，保持原样
    final safeVisibleHeight = visibleHeight;
    
    debugPrint('📖 分页: 字号${fontSize} 行距${lineSpacing} 理论${(safeVisibleHeight / lineHeight).floor()}行/页');

    onProgress?.call(0, '预测量字符宽度...');

    // 3️⃣ 预测量所有字符宽度（快速）
    final styleKey = _getStyleKey(fontSize, letterSpacing, lineSpacing);
    if (_charWidthCache[styleKey] == null) {
      _charWidthCache[styleKey] = {};
      _cleanCache();
    }

    final widthCache = _charWidthCache[styleKey]!;
    final charWidths = <double>[];
    
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (widthCache.containsKey(char)) {
        charWidths.add(widthCache[char]!);
      } else {
        textPainter.text = TextSpan(text: char, style: textStyle);
        textPainter.layout();
        final width = textPainter.width;
        charWidths.add(width);
        widthCache[char] = width;
      }
    }

    onProgress?.call(0, '正在分页...');

    // 4️⃣ 使用预测量宽度快速分页
    final List<String> pages = [];
    final List<int> charOffsets = [];

    int pageCount = 0;
    double durY = 0.0;
    final List<String> pageLines = [];

    // 按行处理文本
    int currentIndex = 0;
    bool isPageStart = true; // 是否是页面开始
    bool isParagraphStart = true; // 是否是段落开始

    while (currentIndex < text.length) {
      // 跳过页首空行
      if (isPageStart && text[currentIndex] == '\n') {
        currentIndex++;
        isParagraphStart = true;
        continue;
      }

      // 记录页面开始位置
      if (isPageStart) {
        charOffsets.add(currentIndex);
        isPageStart = false;
      }

      // 找到当前行的结束位置（遇到\n或文本结束）
      int lineEnd = currentIndex;
      while (lineEnd < text.length && text[lineEnd] != '\n') {
        lineEnd++;
      }

      final rawLine = text.substring(currentIndex, lineEnd);

      // 如果是空行
      if (rawLine.isEmpty) {
        // ⭐ 判断能否放下空行
        if (durY + lineHeight > safeVisibleHeight) {
          // 完成当前页
          if (pageLines.isNotEmpty) {
            pages.add(pageLines.join('\n'));
            pageCount++;
          }
          pageLines.clear();
          durY = 0.0;
          isPageStart = true;
          isParagraphStart = true;
          continue; // 不添加空行，重新开始
        }

        pageLines.add('');
        durY += lineHeight;
        currentIndex = lineEnd + 1;
        isParagraphStart = true;
        continue;
      }

      // 处理非空行：可能需要分成多个显示行
      int lineStartInRaw = 0;
      bool isFirstLineOfParagraph = isParagraphStart;

      while (lineStartInRaw < rawLine.length) {
        final effectiveWidth = isFirstLineOfParagraph 
            ? visibleWidth - firstLineIndent 
            : visibleWidth;

        // ⭐ 快速累加字符宽度
        double currentWidth = 0.0;
        int breakPos = 0;
        final lineStartIdx = currentIndex + lineStartInRaw;

        for (int i = 0; i < rawLine.length - lineStartInRaw; i++) {
          final charIdx = lineStartIdx + i;
          if (charIdx >= charWidths.length) break;
          
          final charWidth = charWidths[charIdx];
          if (currentWidth + charWidth > effectiveWidth) {
            if (i == 0) breakPos = 1; // 至少放一个字符
            else breakPos = i;
            break;
          }
          currentWidth += charWidth;
          breakPos = i + 1;
        }

        if (breakPos == 0) break;

        final lineText = rawLine.substring(lineStartInRaw, lineStartInRaw + breakPos);

        // 判断是否需要换页
        if (durY + lineHeight > safeVisibleHeight) {
          if (pageLines.isNotEmpty) {
            pages.add(pageLines.join('\n'));
            pageCount++;

            if (pageCount % 50 == 0) {
              await Future.delayed(const Duration(milliseconds: 1));
              final progress = (currentIndex / text.length * 100).toStringAsFixed(1);
              onProgress?.call(pageCount, '正在分页... $progress%');
            }
          }
          pageLines.clear();
          durY = 0.0;
          isPageStart = true;
          charOffsets.add(currentIndex + lineStartInRaw);
        }

        pageLines.add(lineText);
        durY += lineHeight;
        isFirstLineOfParagraph = false;

        lineStartInRaw += breakPos;
      }

      // 移到下一个原始行
      currentIndex = lineEnd + 1;
      isParagraphStart = true; // 下一个原始行是新段落
    }

    // 完成最后一页
    if (pageLines.isNotEmpty) {
      pages.add(pageLines.join('\n'));
    }

    // ⭐ 详细的分页统计信息
    debugPrint('✅ 分页完成: ${pages.length}页');
    debugPrint('   平均每页: ${(text.length / pages.length).toInt()} 字符');
    
    // 统计每页的行数
    if (pages.isNotEmpty) {
      final lineCountsPerPage = pages.map((p) => p.split('\n').length).toList();
      final minLines = lineCountsPerPage.reduce((a, b) => a < b ? a : b);
      final maxLines = lineCountsPerPage.reduce((a, b) => a > b ? a : b);
      final avgLines = (lineCountsPerPage.reduce((a, b) => a + b) / lineCountsPerPage.length).toStringAsFixed(1);
      
      debugPrint('   行数统计: 最少 $minLines 行, 最多 $maxLines 行, 平均 $avgLines 行');
      debugPrint('   理论最大: ${(safeVisibleHeight / lineHeight).floor()} 行/页');
      
      if (maxLines > (safeVisibleHeight / lineHeight).floor() + 1) {
        debugPrint('   ⚠️ 警告：某些页面超出理论行数！');
      }
    }
    
    onProgress?.call(pages.length, '分页完成');

    return FastPaginationResult(
      pages: pages,
      charOffsets: charOffsets,
    );
  }

  /// 快速分页（同步版本，用于小文件或缓存加载）
  ///
  /// 🚀 预测量法（同步版本）
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

    // 预处理文本：规范化空行
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 计算可用空间
    final visibleWidth = screenSize.width - padding.left - padding.right;
    final visibleHeight = screenSize.height - padding.top - padding.bottom;

    // 创建 TextPainter 用于测量
    final textStyle = TextStyle(
      fontSize: fontSize,
      height: lineSpacing,
      letterSpacing: letterSpacing,
    );
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
    );

    // 1️⃣ 测量单行高度
    textPainter.text = TextSpan(text: '测', style: textStyle);
    textPainter.layout();
    final lineHeight = textPainter.height;

    // 2️⃣ 计算每页最大行数
    final maxLinesPerPage = (visibleHeight / lineHeight).floor();

    // 3️⃣ 【核心优化】一次性预测量所有字符宽度（带缓存机制）
    final styleKey = _getStyleKey(fontSize, letterSpacing, lineSpacing);

    // 检查缓存
    if (_charWidthCache[styleKey] == null) {
      _charWidthCache[styleKey] = {};
      _cleanCache();
    }

    final widthCache = _charWidthCache[styleKey]!;
    final charWidths = <double>[];

    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      // 先查缓存
      if (widthCache.containsKey(char)) {
        charWidths.add(widthCache[char]!);
      } else {
        // 缓存未命中，测量并缓存
        textPainter.text = TextSpan(text: char, style: textStyle);
        textPainter.layout();
        final width = textPainter.width;
        charWidths.add(width);
        widthCache[char] = width;
      }
    }

    // 4️⃣ 通过累加宽度快速分页
    final List<String> pages = [];
    final List<int> charOffsets = [];

    int currentIndex = 0;

    while (currentIndex < text.length) {
      // 跳过页首空行
      while (currentIndex < text.length && text[currentIndex] == '\n') {
        currentIndex++;
      }

      if (currentIndex >= text.length) break;

      charOffsets.add(currentIndex);
      final pageStartIndex = currentIndex;
      int usedLines = 0;

      // 逐行填充当前页
      while (usedLines < maxLinesPerPage && currentIndex < text.length) {
        // 判断是否是段落首行
        final isFirstLine = currentIndex == pageStartIndex ||
            (currentIndex > 0 && text[currentIndex - 1] == '\n');

        final lineWidth =
            isFirstLine ? visibleWidth - firstLineIndent : visibleWidth;

        // 【核心】通过累加预测量的宽度来确定这一行能放多少字符
        double currentWidth = 0.0;
        int lineStartIndex = currentIndex;

        while (currentIndex < text.length) {
          final char = text[currentIndex];

          // 遇到换行符，这一行结束
          if (char == '\n') {
            currentIndex++;
            break;
          }

          final charWidth = charWidths[currentIndex];

          // 检查是否超出行宽
          if (currentWidth + charWidth > lineWidth) {
            // 如果这是行首第一个字符，必须放进去（避免死循环）
            if (currentIndex == lineStartIndex) {
              currentIndex++;
            }
            break;
          }

          currentWidth += charWidth;
          currentIndex++;
        }

        usedLines++;
      }

      // 提取页面内容
      final pageContent = text
          .substring(pageStartIndex, currentIndex)
          .replaceAll(RegExp(r'\n+$'), ''); // 去除尾部换行

      if (pageContent.isNotEmpty) {
        pages.add(pageContent);
      }
    }

    return FastPaginationResult(
      pages: pages,
      charOffsets: charOffsets,
    );
  }
}
