import 'package:flutter/material.dart';

/// 文本页面数据结构
/// 高级文本页面数据，用于精确文本分页和渲染
class TextPageData {
  /// 页面索引（从0开始）
  final int index;

  /// 页面内容的文本行数据列表
  final List<TextLineData> lines;

  /// 页面的字符起始位置（在整个文本中的位置）
  final int startIndex;

  /// 页面的字符结束位置（在整个文本中的位置）
  final int endIndex;

  /// 页面总字符数
  final int characterCount;

  /// 章节索引（如果页面开始新章节）
  final int? chapterIndex;

  /// 章节标题（如果页面开始新章节）
  final String? chapterTitle;

  /// 是否为最后一页
  final bool isLastPage;

  /// 阅读进度（0.0 - 1.0）
  final double readProgress;

  /// 页面边界信息
  final Rect bounds;

  /// 创建时间戳（用于缓存管理）
  final DateTime createTime;

  TextPageData({
    required this.index,
    required this.lines,
    required this.startIndex,
    required this.endIndex,
    required this.characterCount,
    this.chapterIndex,
    this.chapterTitle,
    required this.isLastPage,
    required this.readProgress,
    required this.bounds,
    DateTime? createTime,
  }) : createTime = createTime ?? DateTime.now();

  /// 工厂方法：创建空页面
  factory TextPageData.empty({int index = 0}) {
    return TextPageData(
      index: index,
      lines: [],
      startIndex: 0,
      endIndex: 0,
      characterCount: 0,
      isLastPage: true,
      readProgress: 0.0,
      bounds: Rect.zero,
      createTime: DateTime.now(),
    );
  }

  /// 获取页面总行数
  int get lineCount => lines.length;

  /// 获取页面的文本内容
  String get textContent {
    return lines.map((line) => line.textContent).join('\n');
  }

  /// 获取指定位置的字符（基于页面内偏移）
  String? getCharAt(int pageOffset) {
    if (pageOffset < 0 || pageOffset >= characterCount) return null;

    int currentOffset = 0;
    for (final line in lines) {
      if (pageOffset < currentOffset + line.characterCount) {
        return line.getCharAt(pageOffset - currentOffset);
      }
      currentOffset += line.characterCount;
    }
    return null;
  }

  /// 获取指定坐标位置的字符
  TextColumnData? getCharAtPosition(Offset position) {
    for (final line in lines) {
      if (line.bounds.contains(position)) {
        return line.getCharAtPosition(position);
      }
    }
    return null;
  }

  /// 获取文本选择范围内的所有字符数据
  List<TextColumnData> getSelectionChars(int startOffset, int endOffset) {
    final selectedChars = <TextColumnData>[];

    int currentOffset = 0;
    for (final line in lines) {
      final lineStart = currentOffset;
      final lineEnd = currentOffset + line.characterCount;

      // 检查这一行是否与选择范围有交集
      if (lineStart < endOffset && lineEnd > startOffset) {
        final selectionStart = (startOffset - lineStart).clamp(
          0,
          line.characterCount,
        );
        final selectionEnd = (endOffset - lineStart).clamp(
          0,
          line.characterCount,
        );

        selectedChars.addAll(
          line.getSelectionChars(selectionStart, selectionEnd),
        );
      }

      currentOffset += line.characterCount;
    }

    return selectedChars;
  }

  /// 创建副本
  TextPageData copyWith({
    int? index,
    List<TextLineData>? lines,
    int? startIndex,
    int? endIndex,
    int? characterCount,
    int? chapterIndex,
    String? chapterTitle,
    bool? isLastPage,
    double? readProgress,
    Rect? bounds,
    DateTime? createTime,
  }) {
    return TextPageData(
      index: index ?? this.index,
      lines: lines ?? this.lines,
      startIndex: startIndex ?? this.startIndex,
      endIndex: endIndex ?? this.endIndex,
      characterCount: characterCount ?? this.characterCount,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      isLastPage: isLastPage ?? this.isLastPage,
      readProgress: readProgress ?? this.readProgress,
      bounds: bounds ?? this.bounds,
      createTime: createTime ?? this.createTime,
    );
  }

  /// 转换为Map（用于调试和序列化）
  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'lines': lines.map((line) => line.toMap()).toList(),
      'startIndex': startIndex,
      'endIndex': endIndex,
      'characterCount': characterCount,
      'chapterIndex': chapterIndex,
      'chapterTitle': chapterTitle,
      'isLastPage': isLastPage,
      'readProgress': readProgress,
      'bounds': {
        'left': bounds.left,
        'top': bounds.top,
        'width': bounds.width,
        'height': bounds.height,
      },
      'createTime': createTime.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'TextPageData{index: $index, lines: ${lines.length}, chars: $characterCount, progress: ${(readProgress * 100).toStringAsFixed(1)}%}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextPageData &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          startIndex == other.startIndex &&
          endIndex == other.endIndex;

  @override
  int get hashCode => index.hashCode ^ startIndex.hashCode ^ endIndex.hashCode;
}

/// 文本行数据结构
/// 高级文本行数据，表示页面中的一行文本
class TextLineData {
  /// 行索引（在页面中的位置）
  final int lineIndex;

  /// 行内的字符数据列表
  final List<TextColumnData> columns;

  /// 行的边界区域
  final Rect bounds;

  /// 行的基线位置
  final double baseline;

  /// 是否为段落的最后一行
  final bool isParagraphEnd;

  /// 段落编号
  final int paragraphIndex;

  /// 行间距
  final double lineSpacing;

  const TextLineData({
    required this.lineIndex,
    required this.columns,
    required this.bounds,
    required this.baseline,
    required this.isParagraphEnd,
    required this.paragraphIndex,
    required this.lineSpacing,
  });

  /// 工厂方法：创建空行
  factory TextLineData.empty({int lineIndex = 0}) {
    return TextLineData(
      lineIndex: lineIndex,
      columns: [],
      bounds: Rect.zero,
      baseline: 0.0,
      isParagraphEnd: true,
      paragraphIndex: 0,
      lineSpacing: 0.0,
    );
  }

  /// 获取行的字符总数
  int get characterCount => columns.length;

  /// 获取行的文本内容
  String get textContent {
    return columns.map((col) => col.char).join();
  }

  /// 获取指定位置的字符
  String? getCharAt(int lineOffset) {
    if (lineOffset < 0 || lineOffset >= columns.length) return null;
    return columns[lineOffset].char;
  }

  /// 获取指定坐标位置的字符数据
  TextColumnData? getCharAtPosition(Offset position) {
    for (final column in columns) {
      if (column.bounds.contains(position)) {
        return column;
      }
    }
    return null;
  }

  /// 获取选择范围内的字符数据
  List<TextColumnData> getSelectionChars(int startOffset, int endOffset) {
    final start = startOffset.clamp(0, columns.length);
    final end = endOffset.clamp(0, columns.length);
    return columns.sublist(start, end);
  }

  /// 绘制行文本（用于CustomPainter）
  void draw(Canvas canvas, Paint paint, TextStyle style) {
    for (final column in columns) {
      column.draw(canvas, paint, style);
    }
  }

  /// 点击测试
  bool hitTest(Offset position) {
    return bounds.contains(position);
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'lineIndex': lineIndex,
      'columns': columns.map((col) => col.toMap()).toList(),
      'bounds': {
        'left': bounds.left,
        'top': bounds.top,
        'width': bounds.width,
        'height': bounds.height,
      },
      'baseline': baseline,
      'isParagraphEnd': isParagraphEnd,
      'paragraphIndex': paragraphIndex,
      'lineSpacing': lineSpacing,
    };
  }

  @override
  String toString() {
    return 'TextLineData{line: $lineIndex, chars: ${columns.length}, text: "${textContent.length > 20 ? '${textContent.substring(0, 20)}...' : textContent}"}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextLineData &&
          runtimeType == other.runtimeType &&
          lineIndex == other.lineIndex &&
          paragraphIndex == other.paragraphIndex;

  @override
  int get hashCode => lineIndex.hashCode ^ paragraphIndex.hashCode;
}

/// 文本字符数据结构
/// 高级文本字符数据，表示页面中的单个字符
class TextColumnData {
  /// 字符内容
  final String char;

  /// 字符在页面中的索引位置
  final int charIndex;

  /// 字符的精确边界区域
  final Rect bounds;

  /// 字符是否被选中
  final bool isSelected;

  /// 字符是否被高亮显示
  final bool isHighlighted;

  /// 高亮颜色
  final Color? highlightColor;

  /// 字符的基线位置
  final double baseline;

  /// 字符的字体度量信息
  final FontMetrics fontMetrics;

  const TextColumnData({
    required this.char,
    required this.charIndex,
    required this.bounds,
    required this.isSelected,
    required this.isHighlighted,
    this.highlightColor,
    required this.baseline,
    required this.fontMetrics,
  });

  /// 工厂方法：创建普通字符
  factory TextColumnData.normal({
    required String char,
    required int charIndex,
    required Rect bounds,
    required double baseline,
    required FontMetrics fontMetrics,
  }) {
    return TextColumnData(
      char: char,
      charIndex: charIndex,
      bounds: bounds,
      isSelected: false,
      isHighlighted: false,
      baseline: baseline,
      fontMetrics: fontMetrics,
    );
  }

  /// 是否为空白字符
  bool get isWhitespace => char.trim().isEmpty;

  /// 是否为标点符号
  bool get isPunctuation {
    const punctuations = '。！？，；：""'
        '（）《》【】[]{}…—';
    return punctuations.contains(char) ||
        char.contains(RegExp(r'[.!?,:;"(){}\[\]<>]'));
  }

  /// 创建选中状态的副本
  TextColumnData withSelection(bool selected) {
    return TextColumnData(
      char: char,
      charIndex: charIndex,
      bounds: bounds,
      isSelected: selected,
      isHighlighted: isHighlighted,
      highlightColor: highlightColor,
      baseline: baseline,
      fontMetrics: fontMetrics,
    );
  }

  /// 创建高亮状态的副本
  TextColumnData withHighlight(bool highlighted, [Color? color]) {
    return TextColumnData(
      char: char,
      charIndex: charIndex,
      bounds: bounds,
      isSelected: isSelected,
      isHighlighted: highlighted,
      highlightColor: highlighted ? (color ?? Colors.yellow) : null,
      baseline: baseline,
      fontMetrics: fontMetrics,
    );
  }

  /// 绘制字符（用于CustomPainter）
  void draw(Canvas canvas, Paint paint, TextStyle style) {
    // 绘制高亮背景
    if (isHighlighted && highlightColor != null) {
      paint.color = highlightColor!.withValues(alpha: 0.3);
      canvas.drawRect(bounds, paint);
    }

    // 绘制选择背景
    if (isSelected) {
      paint.color = Colors.blue.withValues(alpha: 0.3);
      canvas.drawRect(bounds, paint);
    }

    // 绘制字符
    final textSpan = TextSpan(text: char, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    textPainter.layout();
    textPainter.paint(canvas, bounds.topLeft);
    textPainter.dispose();
  }

  /// 点击测试
  bool hitTest(Offset position) {
    return bounds.contains(position);
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'char': char,
      'charIndex': charIndex,
      'bounds': {
        'left': bounds.left,
        'top': bounds.top,
        'width': bounds.width,
        'height': bounds.height,
      },
      'isSelected': isSelected,
      'isHighlighted': isHighlighted,
      'highlightColor': highlightColor?.toARGB32(),
      'baseline': baseline,
      'fontMetrics': fontMetrics.toMap(),
    };
  }

  @override
  String toString() {
    return 'TextColumnData{char: "$char", index: $charIndex, selected: $isSelected, highlighted: $isHighlighted}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextColumnData &&
          runtimeType == other.runtimeType &&
          charIndex == other.charIndex;

  @override
  int get hashCode => charIndex.hashCode;
}

/// 字体度量信息
/// 用于精确计算字符位置和间距
class FontMetrics {
  /// 字符宽度
  final double width;

  /// 字符高度
  final double height;

  /// 上升高度（基线到顶部的距离）
  final double ascent;

  /// 下降高度（基线到底部的距离）
  final double descent;

  /// 行间距
  final double leading;

  const FontMetrics({
    required this.width,
    required this.height,
    required this.ascent,
    required this.descent,
    required this.leading,
  });

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'width': width,
      'height': height,
      'ascent': ascent,
      'descent': descent,
      'leading': leading,
    };
  }

  @override
  String toString() {
    return 'FontMetrics{width: $width, height: $height, ascent: $ascent, descent: $descent}';
  }
}
