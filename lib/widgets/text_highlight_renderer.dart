import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/highlight.dart';

/// 文本高亮渲染器
/// 用于在SelectableText中渲染高亮效果
class TextHighlightRenderer {
  final List<Highlight> highlights;
  final String fullText;
  final TextStyle baseStyle;

  TextHighlightRenderer({
    required this.highlights,
    required this.fullText,
    required this.baseStyle,
  });

  /// 构建包含高亮的RichText
  Widget buildHighlightedText({
    TextAlign textAlign = TextAlign.justify,
    int? maxLines,
    TextOverflow overflow = TextOverflow.clip,
    Function(Highlight)? onHighlightTap,
  }) {
    if (highlights.isEmpty) {
      return SelectableText(
        fullText,
        style: baseStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        showCursor: false,
        enableInteractiveSelection: true,
      );
    }

    // 按开始位置排序高亮
    final sortedHighlights = [...highlights]
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

    final textSpans = <TextSpan>[];
    int currentOffset = 0;

    for (final highlight in sortedHighlights) {
      // 添加高亮前的普通文本
      if (currentOffset < highlight.startOffset) {
        final normalText = fullText.substring(
          currentOffset,
          highlight.startOffset,
        );
        if (normalText.isNotEmpty) {
          textSpans.add(TextSpan(text: normalText, style: baseStyle));
        }
      }

      // 添加高亮文本
      final highlightText = fullText.substring(
        highlight.startOffset,
        highlight.endOffset,
      );

      textSpans.add(
        TextSpan(
          text: highlightText,
          style: baseStyle.copyWith(
            backgroundColor: highlight.color.withOpacity(0.4),
            // 可选：添加下划线以增强视觉效果
            decoration: null, // 简化处理，不显示下划线
            decorationColor: highlight.color,
            decorationThickness: 2,
          ),
          recognizer: onHighlightTap != null
              ? (TapGestureRecognizer()
                  ..onTap = () => onHighlightTap(highlight))
              : null,
        ),
      );

      currentOffset = highlight.endOffset;
    }

    // 添加最后的普通文本
    if (currentOffset < fullText.length) {
      final remainingText = fullText.substring(currentOffset);
      if (remainingText.isNotEmpty) {
        textSpans.add(TextSpan(text: remainingText, style: baseStyle));
      }
    }

    return SelectableText.rich(
      TextSpan(style: baseStyle, children: textSpans),
      textAlign: textAlign,
      maxLines: maxLines,
      showCursor: false,
      enableInteractiveSelection: true,
    );
  }

  /// 检查指定范围是否与现有高亮重叠
  bool hasOverlappingHighlight(int startOffset, int endOffset) {
    return highlights.any(
      (highlight) =>
          (startOffset < highlight.endOffset &&
          endOffset > highlight.startOffset),
    );
  }

  /// 获取指定位置的高亮
  Highlight? getHighlightAtPosition(int offset) {
    try {
      return highlights.firstWhere(
        (highlight) =>
            offset >= highlight.startOffset && offset < highlight.endOffset,
      );
    } catch (e) {
      return null;
    }
  }
}
