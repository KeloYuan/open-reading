import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:path/path.dart' as path;
import '../providers/reader_providers.dart';
import '../widgets/enhanced_text_selection_toolbar.dart';
import '../widgets/tts_settings_sheet.dart';
import '../widgets/page_turning_settings_sheet.dart';
import '../models/book_note.dart';
import '../models/bookmark.dart';
import '../models/chapter.dart';
import '../services/book_dao.dart';
import '../services/data_manager.dart';
import '../services/bookmark_dao.dart';
import '../services/reading_stats_dao.dart';
import 'cover_pagination_view.dart';
import '../widgets/toc_widget.dart';

/// 混合内容元素（文本或图片）
class _ContentElement {
  final bool isImage;
  final String content; // 如果是文本就是文本内容，如果是图片就是文件路径
  final double? imageHeight;

  const _ContentElement({
    required this.isImage,
    required this.content,
    this.imageHeight,
  });
}

/// 解析混合内容（文本+图片）
List<_ContentElement> _parseMixedContent(String content) {
  final elements = <_ContentElement>[];
  final imgPattern = RegExp(r'<img\s+[^>]*src="([^"]+)"[^>]*?>');

  int lastIndex = 0;
  for (var match in imgPattern.allMatches(content)) {
    // 添加图片前的文本
    if (match.start > lastIndex) {
      final textContent = content.substring(lastIndex, match.start);
      if (textContent.isNotEmpty) {
        elements.add(_ContentElement(isImage: false, content: textContent));
      }
    }

    // 添加图片
    final imagePath = match.group(1);
    if (imagePath != null && imagePath.isNotEmpty) {
      final tagText = match.group(0) ?? '';
      final heightMatch =
          RegExp(r'data-height="([^"]+)"').firstMatch(tagText);
      final imageHeight = heightMatch != null
          ? double.tryParse(heightMatch.group(1) ?? '')
          : null;
      elements.add(_ContentElement(
        isImage: true,
        content: imagePath,
        imageHeight: imageHeight,
      ));
    }

    lastIndex = match.end;
  }

  // 添加最后剩余的文本
  if (lastIndex < content.length) {
    final textContent = content.substring(lastIndex);
    if (textContent.isNotEmpty) {
      elements.add(_ContentElement(isImage: false, content: textContent));
    }
  }

  return elements;
}

class _ChapterMarker {
  final String title;
  final int level;
  final int startIndex;

  const _ChapterMarker({
    required this.title,
    required this.level,
    required this.startIndex,
  });
}

final List<RegExp> _chapterTitlePatterns = [
  // 中文章节
  RegExp(r'^第[一二三四五六七八九十百千\d]+章\s*(.*)$'),
  RegExp(r'^第[一二三四五六七八九十百千\d]+节\s*(.*)$'),
  RegExp(r'^[一二三四五六七八九十]+、\s*(.*)$'),
  RegExp(r'^\d+\.\s*(.*)$'),
  RegExp(r'^\d+\.\d+\s*(.*)$'),
  RegExp(r'^\d+\.\d+\.\d+\s*(.*)$'),
  RegExp(r'^[\d]+[\.、]\s*(.*)$'),
  // 英文章节
  RegExp(r'^Chapter\s+\d+\s*(.*)$', caseSensitive: false),
  RegExp(r'^Part\s+\d+\s*(.*)$', caseSensitive: false),
  RegExp(r'^Section\s+\d+\s*(.*)$', caseSensitive: false),
  // 特殊章节
  RegExp(r'^(序言|前言|引言|目录|后记|跋|结语)(.*)$'),
  RegExp(
    r'^(Preface|Introduction|Prologue|Epilogue)(.*)$',
    caseSensitive: false,
  ),
  // 分割线章节
  RegExp(r'^[=\-]{3,}\s*(.+)\s*[=\-]{3,}$'),
  RegExp(r'^\*{3,}\s*(.+)\s*\*{3,}$'),
];

String _cleanChapterTitle(String title) {
  return title
      .replaceAll(RegExp(r'[^\w\s\u4e00-\u9fff]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _normalizeTitleKey(String title) {
  return title
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\u4e00-\u9fff]'), '');
}

int _determineChapterLevel(String title) {
  if (RegExp(r'第[一二三四五六七八九十百千\d]+章').hasMatch(title) ||
      RegExp(r'Chapter\s+\d+', caseSensitive: false).hasMatch(title) ||
      RegExp(r'Part\s+\d+', caseSensitive: false).hasMatch(title)) {
    return 0;
  }

  if (RegExp(r'第[一二三四五六七八九十\d]+节').hasMatch(title) ||
      RegExp(r'Section\s+\d+', caseSensitive: false).hasMatch(title) ||
      RegExp(r'^\d+\.\d+').hasMatch(title)) {
    return 1;
  }

  if (RegExp(r'^\d+\.\d+\.\d+').hasMatch(title) ||
      RegExp(r'[一二三四五六七八九十]+、').hasMatch(title)) {
    return 2;
  }

  return 0;
}

List<_ChapterMarker> _splitContentFallback(String content) {
  const targetChapterLength = 5000;
  final markers = <_ChapterMarker>[];
  int index = 0;
  int chapterIndex = 1;

  while (index < content.length) {
    markers.add(_ChapterMarker(
      title: '第$chapterIndex章',
      level: 0,
      startIndex: index,
    ));
    chapterIndex++;

    if (index + targetChapterLength >= content.length) break;
    final nextBreak = content.indexOf('\n', index + targetChapterLength);
    if (nextBreak == -1) break;
    index = nextBreak + 1;
  }

  return markers;
}

String _sanitizeTocTitle(String title) {
  return title.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _stripTocPageNumber(String line) {
  var result = line;
  result = result.replaceAll(RegExp(r'[·\.]{2,}\s*\d+\s*$'), '');
  result = result.replaceAll(RegExp(r'\s+\d+\s*$'), '');
  return result.trim();
}

String? _extractTocTitleFromLine(String line) {
  final cleaned = _stripTocPageNumber(line);
  if (cleaned.isEmpty) return null;

  for (final pattern in _chapterTitlePatterns) {
    if (pattern.hasMatch(cleaned)) {
      return _sanitizeTocTitle(cleaned);
    }
  }
  return null;
}

bool _looksLikeTocEntryLine(String line) {
  final cleaned = _stripTocPageNumber(line);
  if (cleaned.length < 2 || cleaned.length > 80) return false;
  if (RegExp(r'^\d+$').hasMatch(cleaned)) return false;
  if (!RegExp(r'[A-Za-z\u4e00-\u9fff]').hasMatch(cleaned)) return false;
  return true;
}

bool _looksLikeHeadingLine(String line) {
  if (line.length > 80) return false;
  for (final pattern in _chapterTitlePatterns) {
    if (pattern.hasMatch(line)) return true;
  }
  return false;
}

List<_ChapterMarker> _extractChapterMarkers(String content) {
  final lines = content.split('\n');
  final tocLinePattern = RegExp(
    r'^\s*[\[【(（]?\s*(目录|目\s*录|contents)\s*[】\]）)]?\s*[:：]?\s*$',
    caseSensitive: false,
  );

  int offset = 0;
  int tocStartLine = -1;
  int tocEndLine = -1;

  // Step 1: locate the TOC section near the start
  for (int i = 0; i < lines.length; i++) {
    final trimmed = lines[i].trim();
    if (tocLinePattern.hasMatch(trimmed)) {
      tocStartLine = i;
      break;
    }
    offset += lines[i].length + 1;
  }

  if (tocStartLine != -1) {
    int emptyStreak = 0;
    for (int i = tocStartLine + 1; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.isEmpty) {
        emptyStreak++;
      } else {
        emptyStreak = 0;
      }

      if (emptyStreak >= 3) {
        tocEndLine = i;
        break;
      }
      if (i - tocStartLine > 200) {
        tocEndLine = i;
        break;
      }
      if (RegExp(r'^第[一二三四五六七八九十百千\d]+章').hasMatch(trimmed) &&
          i - tocStartLine > 10) {
        tocEndLine = i;
        break;
      }
    }
    if (tocEndLine == -1) {
      tocEndLine = lines.length;
    }
  }

  // Step 2: collect TOC titles in that section
  final tocTitles = <String>[];
  if (tocStartLine != -1) {
    for (int i = tocStartLine + 1; i < tocEndLine; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.isEmpty) continue;
      final title = _extractTocTitleFromLine(trimmed);
      if (title != null && title.isNotEmpty) {
        tocTitles.add(title);
      } else if (_looksLikeTocEntryLine(trimmed)) {
        tocTitles.add(_sanitizeTocTitle(_stripTocPageNumber(trimmed)));
      }
    }
  }

  // Step 3: if TOC titles found, map to first occurrence after TOC
  if (tocTitles.isNotEmpty) {
    final markers = <_ChapterMarker>[];
    final seenTitles = <String>{};
    for (final tocTitle in tocTitles) {
      final normalizedToc = _normalizeTitleKey(tocTitle);
      if (normalizedToc.isEmpty) continue;
      if (seenTitles.contains(normalizedToc)) continue;

      int offsetCursor = 0;
      bool matched = false;
      for (int i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trim();
        final normalizedLine = _normalizeTitleKey(trimmed);
        if (i <= tocStartLine) {
          offsetCursor += lines[i].length + 1;
          continue;
        }

        if (normalizedLine.isNotEmpty &&
            normalizedLine.startsWith(normalizedToc) &&
            _looksLikeHeadingLine(trimmed)) {
          markers.add(_ChapterMarker(
            title: tocTitle,
            level: _determineChapterLevel(tocTitle),
            startIndex: offsetCursor,
          ));
          seenTitles.add(normalizedToc);
          matched = true;
          break;
        }

        offsetCursor += lines[i].length + 1;
      }
      if (!matched) {
        markers.add(_ChapterMarker(
          title: tocTitle,
          level: _determineChapterLevel(tocTitle),
          startIndex: -1,
        ));
        seenTitles.add(normalizedToc);
      }
    }

    return markers;
  }

  // Step 4: fallback to loose detection only if no TOC section found
  if (tocStartLine != -1) {
    return [];
  }

  // Step 5: no TOC section, use loose detection
  final markers = <_ChapterMarker>[];
  final seenTitles = <String>{};
  offset = 0;

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) {
      for (final pattern in _chapterTitlePatterns) {
        if (pattern.hasMatch(trimmed)) {
          final title = _cleanChapterTitle(trimmed);
          if (title.isNotEmpty) {
            final key = _normalizeTitleKey(title);
            if (!seenTitles.contains(key)) {
              markers.add(_ChapterMarker(
                title: title,
                level: _determineChapterLevel(trimmed),
                startIndex: offset,
              ));
              seenTitles.add(key);
            }
          }
          break;
        }
      }
    }

    offset += line.length + 1;
  }

  return markers.isEmpty ? _splitContentFallback(content) : markers;
}

int _findPageForCharIndex(List<int> offsets, int charIndex) {
  if (offsets.isEmpty) return 0;

  int low = 0;
  int high = offsets.length - 1;
  int result = 0;

  while (low <= high) {
    final mid = (low + high) >> 1;
    final value = offsets[mid];
    if (value <= charIndex) {
      result = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }

  return result;
}

int _findPageByTitle(List<String> pages, String title) {
  final normalizedTitle = _normalizeTitleKey(title);
  if (normalizedTitle.isEmpty) return 0;

  for (int i = 0; i < pages.length; i++) {
    final normalizedPage = _normalizeTitleKey(pages[i]);
    if (normalizedPage.contains(normalizedTitle)) {
      return i;
    }
  }

  return 0;
}

List<Chapter> _buildChapterHierarchy({
  required List<_ChapterMarker> markers,
  required List<int> pageCharOffsets,
  required List<String> pages,
}) {
  final root = <Chapter>[];
  final stack = <Chapter>[];

  for (int i = 0; i < markers.length; i++) {
    final marker = markers[i];
    int startPage = marker.startIndex >= 0 && pageCharOffsets.isNotEmpty
        ? _findPageForCharIndex(pageCharOffsets, marker.startIndex)
        : _findPageByTitle(pages, marker.title);
    if (pages.isNotEmpty) {
      startPage = startPage.clamp(0, pages.length - 1);
    }

    final chapter = Chapter(
      title: marker.title,
      startPage: startPage,
      level: marker.level,
      order: i,
      subChapters: <Chapter>[],
    );

    while (stack.isNotEmpty && marker.level <= stack.last.level) {
      stack.removeLast();
    }

    if (stack.isEmpty) {
      root.add(chapter);
    } else {
      stack.last.subChapters.add(chapter);
    }

    stack.add(chapter);
  }

  return root;
}

void _showSideToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  if (overlay == null) return;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _SideToast(
      message: message,
      onDismissed: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _SideToast extends StatefulWidget {
  final String message;
  final VoidCallback onDismissed;

  const _SideToast({
    required this.message,
    required this.onDismissed,
  });

  @override
  State<_SideToast> createState() => _SideToastState();
}

class _SideToastState extends State<_SideToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.6, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _controller.forward();
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topInset + 16,
      right: 12,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: scheme.surfaceContainerHigh,
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  widget.message,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 支持句子高亮的文本渲染组件
class _HighlightedText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int? highlightedSentenceIndex;
  final Color highlightColor;
  final Function(String, Offset)? onTextSelection;
  final bool enableSelection;
  final int? maxLines; // 最大行数限制

  const _HighlightedText({
    required this.text,
    required this.style,
    this.highlightedSentenceIndex,
    Color? highlightColor,
    this.onTextSelection,
    this.enableSelection = true,
    this.maxLines,
  }) : highlightColor = highlightColor ?? const Color(0xFFFFEB3B);

  @override
  Widget build(BuildContext context) {
    // 🖼️ 检查是否包含图片标签
    final hasImages = text.contains(RegExp(r'<img\s+[^>]*src="[^"]+\"[^>]*?>'));

    if (hasImages) {
      // 包含图片，使用混合内容渲染
      return _buildMixedContent(context);
    }

    if (highlightedSentenceIndex == null || highlightedSentenceIndex! <= -1) {
      // 没有高亮句子，直接返回普通文本
      return enableSelection
          ? SelectableText(
              text,
              style: style,
              textAlign: TextAlign.left, // 改为left对齐，与分页器TextPainter一致
              // 隐藏系统默认的选择工具栏，使用自定义工具栏
              contextMenuBuilder: (context, editableTextState) {
                // 从 EditableTextState 获取准确的选中位置
                final selection = editableTextState.textEditingValue.selection;
                if (!selection.isCollapsed && onTextSelection != null) {
                  final selectedText =
                      text.substring(selection.start, selection.end);
                  // 延迟调用，确保在正确的时机
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _calculateSelectionPositionFromEditableText(
                      context,
                      editableTextState,
                      selection,
                      selectedText,
                    );
                  });
                }
                return const SizedBox.shrink(); // 返回空组件，隐藏系统工具栏
              },
              onSelectionChanged: onTextSelection != null
                  ? (selection, cause) {
                      if (!selection.isCollapsed) {
                        final selectedText = text.substring(
                          selection.start,
                          selection.end,
                        );
                        _calculateSelectionPosition(
                          context,
                          selection,
                          selectedText,
                        );
                      }
                    }
                  : null,
            )
          : Text(
              text,
              style: style,
              textAlign: TextAlign.left,
              softWrap: true, // 启用自动换行
              maxLines: maxLines, // 限制最大行数
              overflow: TextOverflow.clip, // 超出裁剪
            );
    }

    // 分割文本为句子并高亮指定句子
    final sentences = _splitIntoSentences(text);
    if (sentences.isEmpty || highlightedSentenceIndex! >= sentences.length) {
      return enableSelection
          ? SelectableText(
              text,
              style: style,
              textAlign: TextAlign.left, // 改为left对齐，与分页器TextPainter一致
              // 隐藏系统默认的选择工具栏，使用自定义工具栏
              contextMenuBuilder: (context, editableTextState) {
                // 从 EditableTextState 获取准确的选中位置
                final selection = editableTextState.textEditingValue.selection;
                if (!selection.isCollapsed && onTextSelection != null) {
                  final selectedText =
                      text.substring(selection.start, selection.end);
                  // 延迟调用，确保在正确的时机
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _calculateSelectionPositionFromEditableText(
                      context,
                      editableTextState,
                      selection,
                      selectedText,
                    );
                  });
                }
                return const SizedBox.shrink(); // 返回空组件，隐藏系统工具栏
              },
              onSelectionChanged: onTextSelection != null
                  ? (selection, cause) {
                      if (!selection.isCollapsed) {
                        final selectedText = text.substring(
                          selection.start,
                          selection.end,
                        );
                        _calculateSelectionPosition(
                          context,
                          selection,
                          selectedText,
                        );
                      }
                    }
                  : null,
            )
          : Text(
              text,
              style: style,
              textAlign: TextAlign.left,
              softWrap: true, // 启用自动换行
              maxLines: maxLines, // 限制最大行数
              overflow: TextOverflow.clip, // 超出裁剪
            );
    }

    // 构建带有高亮的文本段落
    final spans = <TextSpan>[];

    for (var i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];
      final isHighlighted = i == highlightedSentenceIndex;

      spans.add(
        TextSpan(
          text: sentence,
          style: style.copyWith(
            backgroundColor:
                isHighlighted ? highlightColor.withValues(alpha: 0.3) : null,
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.left, // 改为left对齐，与分页器TextPainter一致
    );
  }

  /// 构建混合内容（文本+图片）
  Widget _buildMixedContent(BuildContext context) {
    final elements = _parseMixedContent(text);

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(), // 禁止滚动，由外层分页控制
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: elements.map((element) {
          if (element.isImage) {
            // 渲染图片
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: _buildImage(
                element.content,
                maxHeight: element.imageHeight,
              ),
            );
          } else {
            // 渲染文本
            return Text(
              element.content,
              style: style,
              textAlign: TextAlign.left,
            );
          }
        }).toList(),
      ),
    );
  }

  /// 构建图片组件
  Widget _buildImage(String imagePath, {double? maxHeight}) {
    final file = File(imagePath);

    final imageWidget = Image.file(
      file,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        final exists = file.existsSync();
        debugPrint('❌ 图片加载失败: ${path.basename(imagePath)}, 存在:$exists');

        return Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            border: Border.all(color: Colors.red, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '❌ 图片加载失败',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '路径: $imagePath',
                style: TextStyle(color: Colors.grey[700], fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                '文件存在: ${exists ? "是" : "否"}',
                style: TextStyle(color: Colors.grey[700], fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                '错误: $error',
                style: TextStyle(color: Colors.grey[700], fontSize: 11),
              ),
            ],
          ),
        );
      },
    );

    if (maxHeight == null) {
      return imageWidget;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: imageWidget,
    );
  }

  List<String> _splitIntoSentences(String text) {
    // 简单的句子分割逻辑（可以根据需要改进）
    final sentences = <String>[];
    final regex = RegExp(r'[^。！？.!?]+[。！？.!?\s]*');
    final matches = regex.allMatches(text);

    for (final match in matches) {
      sentences.add(match.group(0)!);
    }

    return sentences.isEmpty ? [text] : sentences;
  }

  void _calculateSelectionPosition(
    BuildContext context,
    TextSelection selection,
    String selectedText,
  ) {
    if (onTextSelection == null) return;

    try {
      // 计算选中文本的实际位置
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.attached) {
        debugPrint('⚠️ RenderBox为空或未attached，使用默认位置');
        _useDefaultToolbarPosition(context, selectedText);
        return;
      }

      // 获取屏幕尺寸
      final screenSize = MediaQuery.of(context).size;
      const toolbarWidth = 420.0; // 更新为新的宽度
      const toolbarHeight = 70.0; // 从 60 增加到 70

      // 尝试获取精确的文本选择位置
      Offset? startPosition;
      Offset? endPosition;

      // 尝试从 RenderParagraph 获取精确位置
      if (renderBox is RenderParagraph) {
        try {
          debugPrint('✓ RenderBox 类型: RenderParagraph');
          // 获取选中文本的起始位置
          final startOffset = renderBox.getOffsetForCaret(
            TextPosition(offset: selection.start),
            Rect.zero,
          );

          // 获取选中文本的结束位置
          final endOffset = renderBox.getOffsetForCaret(
            TextPosition(offset: selection.end),
            Rect.zero,
          );

          // 转换为全局坐标
          startPosition = renderBox.localToGlobal(startOffset);
          endPosition = renderBox.localToGlobal(endOffset);

          debugPrint('✓ 获取到文本位置: start=$startPosition, end=$endPosition');
        } catch (e) {
          debugPrint('⚠️ 获取文本位置失败: $e');
        }
      } else {
        debugPrint(
            '⚠️ RenderBox 类型不是 RenderParagraph: ${renderBox.runtimeType}');
        // 尝试其他方式获取位置
        try {
          final boxPosition = renderBox.localToGlobal(Offset.zero);
          final boxSize = renderBox.size;

          // 估算选中文本的位置（在组件中间偏上）
          startPosition = Offset(
            boxPosition.dx + boxSize.width * 0.5,
            boxPosition.dy + boxSize.height * 0.3,
          );
          endPosition = startPosition;

          debugPrint('✓ 使用估算位置: $startPosition');
        } catch (e) {
          debugPrint('⚠️ 估算位置也失败: $e');
        }
      }

      // 计算工具栏位置
      double toolbarX;
      double toolbarY;

      if (startPosition != null && endPosition != null) {
        // 使用精确位置或估算位置
        final selectionCenterX = (startPosition.dx + endPosition.dx) / 2;

        // 计算工具栏 X 坐标，确保不超出屏幕
        final maxX = screenSize.width - toolbarWidth - 10.0;
        toolbarX = (selectionCenterX - toolbarWidth / 2);
        if (toolbarX < 10.0) {
          toolbarX = 10.0; // 左边界
        } else if (toolbarX > maxX) {
          toolbarX = maxX; // 右边界
        }

        // 工具栏显示在选中文本上方，如果上方空间不足则显示在下方
        // 减少间距，让工具栏更接近选中文字
        if (startPosition.dy > toolbarHeight + 15) {
          toolbarY = startPosition.dy - toolbarHeight - 5;
        } else {
          // 上方空间不足，显示在下方
          toolbarY = endPosition.dy + 5;
        }

        debugPrint('✓ 使用选中文字位置: X=$toolbarX, Y=$toolbarY');
      } else {
        // 最终降级处理：使用屏幕中心位置
        debugPrint('⚠️ 无法获取任何位置信息，使用屏幕中心');
        toolbarX = (screenSize.width - toolbarWidth) / 2;
        toolbarY = screenSize.height / 3;
      }

      // 确保工具栏 Y 坐标不超出屏幕
      final maxY = screenSize.height - toolbarHeight - 10.0;
      if (toolbarY < 10.0) {
        toolbarY = 10.0; // 顶部边界
      } else if (toolbarY > maxY) {
        toolbarY = maxY; // 底部边界
      }

      debugPrint('📍 工具栏位置: ($toolbarX, $toolbarY)');
      onTextSelection!(selectedText, Offset(toolbarX, toolbarY));
    } catch (e) {
      debugPrint('❌ 计算选择位置失败: $e');
      _useDefaultToolbarPosition(context, selectedText);
    }
  }

  /// 使用默认工具栏位置（屏幕中上部）
  void _useDefaultToolbarPosition(BuildContext context, String selectedText) {
    if (onTextSelection == null) return;

    final screenSize = MediaQuery.of(context).size;
    const toolbarWidth = 420.0; // 更新为新的宽度
    final toolbarX = (screenSize.width - toolbarWidth) / 2;
    final toolbarY = screenSize.height / 3;

    debugPrint('📍 使用默认工具栏位置: ($toolbarX, $toolbarY)');
    onTextSelection!(selectedText, Offset(toolbarX, toolbarY));
  }

  /// 从 EditableTextState 计算选择位置（更准确）
  void _calculateSelectionPositionFromEditableText(
    BuildContext context,
    EditableTextState editableTextState,
    TextSelection selection,
    String selectedText,
  ) {
    if (onTextSelection == null) return;

    try {
      final screenSize = MediaQuery.of(context).size;
      const toolbarWidth = 420.0;
      const toolbarHeight = 70.0;

      // 从 EditableTextState 获取选中区域的端点
      final startPoint = editableTextState.renderEditable.getLocalRectForCaret(
        TextPosition(offset: selection.start),
      );
      final endPoint = editableTextState.renderEditable.getLocalRectForCaret(
        TextPosition(offset: selection.end),
      );

      // 转换为全局坐标
      final renderObject = editableTextState.renderEditable;
      final startGlobal = renderObject.localToGlobal(startPoint.topLeft);
      final endGlobal = renderObject.localToGlobal(endPoint.topLeft);

      debugPrint('📌 EditableText 选中位置: start=$startGlobal, end=$endGlobal');

      // 计算工具栏位置
      final selectionCenterX = (startGlobal.dx + endGlobal.dx) / 2;
      final maxX = screenSize.width - toolbarWidth - 10.0;
      double toolbarX = (selectionCenterX - toolbarWidth / 2);
      if (toolbarX < 10.0) {
        toolbarX = 10.0;
      } else if (toolbarX > maxX) {
        toolbarX = maxX;
      }

      double toolbarY;
      if (startGlobal.dy > toolbarHeight + 15) {
        toolbarY = startGlobal.dy - toolbarHeight - 5;
      } else {
        toolbarY = endGlobal.dy + 5;
      }

      // 确保不超出屏幕
      final maxY = screenSize.height - toolbarHeight - 10.0;
      if (toolbarY < 10.0) {
        toolbarY = 10.0;
      } else if (toolbarY > maxY) {
        toolbarY = maxY;
      }

      debugPrint('✅ 最终工具栏位置: ($toolbarX, $toolbarY)');
      onTextSelection!(selectedText, Offset(toolbarX, toolbarY));
    } catch (e) {
      debugPrint('❌ EditableText 位置计算失败: $e');
      _useDefaultToolbarPosition(context, selectedText);
    }
  }
}

/// 阅读页面 - 核心组件
///
/// 实现沉浸式阅读体验，集成分页引擎、工具栏、TTS等功能
/// 使用Riverpod进行状态管理，采用分层UI架构
class ReaderPage extends ConsumerStatefulWidget {
  /// 书籍文本内容
  final String bookContent;

  /// 书籍标题
  final String? bookTitle;

  /// 初始页面索引
  final int initialPageIndex;

  /// 书籍ID（用于保存阅读进度）
  final int? bookId;

  const ReaderPage({
    Key? key,
    required this.bookContent,
    this.bookTitle,
    this.initialPageIndex = 0,
    this.bookId,
  }) : super(key: key);

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // 动画控制器用于工具栏显示隐藏
  late AnimationController _toolbarAnimationController;
  late Animation<double> _toolbarOpacityAnimation;
  late Animation<Offset> _topToolbarSlideAnimation;
  late Animation<Offset> _bottomToolbarSlideAnimation;

  // 自动隐藏工具栏的计时器
  Timer? _autoHideTimer;

  // 文本选择相关状态
  String _selectedText = '';
  bool _showTextSelectionToolbar = false;
  Offset? _selectionToolbarPosition;
  Timer? _selectionToolbarDelayTimer; // 延迟显示工具栏的计时器

  // 指针事件跟踪（用于检测点击）
  Offset? _pointerDownPosition;
  int? _pointerDownTime;

  // 重新分页防抖和状态
  Timer? _repaginationDebounceTimer;
  bool _isRepaginating = false;

  // 阅读时间追踪
  final _statsDao = ReadingStatsDao();
  DateTime? _readingStartTime;
  int _totalReadingSeconds = 0;
  Timer? _readingTimeTimer;

  @override
  void initState() {
    super.initState();
    // 注册应用生命周期监听
    WidgetsBinding.instance.addObserver(this);

    // 记录阅读开始时间
    _readingStartTime = DateTime.now();
    debugPrint('📊 开始记录阅读时间: $_readingStartTime');

    _initializeAnimations();
    _initializePage();

    // 延迟进入沉浸式全屏模式，确保窗口已完全初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enterImmersiveMode();
      // 启用屏幕常亮，防止长按选择文字时黑屏
      _enableWakeLock();
      debugPrint('📱 ReaderPage 初始化完成，已进入全屏模式并启用屏幕常亮');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // 应用进入后台或暂停，立即保存阅读进度和阅读时间
      if (widget.bookId != null) {
        final currentPageIndex =
            ref.read(readerPaginationProvider).currentPageIndex;
        debugPrint('📱 应用生命周期变化: $state，立即保存进度');
        _saveReadingProgress(currentPageIndex);
      }
      // 保存阅读时间并停止定时器
      _saveReadingTime();
      _readingTimeTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      // 应用从后台返回前台，重新开始计时
      _readingStartTime = DateTime.now();
      debugPrint('📊 应用恢复前台，重新开始计时: $_readingStartTime');

      // 重新启动定时器
      _readingTimeTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        _saveReadingTime();
      });

      // 重新确保沉浸式模式
      // 延迟一帧执行，确保窗口状态已更新
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !ref.read(toolbarProvider).isVisible) {
          debugPrint('📱 应用恢复前台，重新进入沉浸式模式');
          _hideSystemUI();
        }
      });
    }
  }

  @override
  void dispose() {
    // 保存最后一次阅读时间
    _saveReadingTime();

    // 移除应用生命周期监听
    WidgetsBinding.instance.removeObserver(this);

    // 停止所有定时器
    _toolbarAnimationController.dispose();
    _autoHideTimer?.cancel();
    _repaginationDebounceTimer?.cancel();
    _readingTimeTimer?.cancel();
    _selectionToolbarDelayTimer?.cancel();

    // 禁用屏幕常亮
    _disableWakeLock();

    // 退出沉浸式模式
    _exitImmersiveMode();

    debugPrint('📱 ReaderPage已销毁');
    super.dispose();
  }

  /// 保存阅读时间到数据库
  ///
  /// 计算从上次开始时间到现在的阅读时长，并保存到数据库
  void _saveReadingTime() {
    if (_readingStartTime == null) return;

    try {
      final now = DateTime.now();
      final duration = now.difference(_readingStartTime!);
      final seconds = duration.inSeconds;

      // 只保存超过5秒的阅读时间，避免记录无效数据
      if (seconds >= 5) {
        _totalReadingSeconds += seconds;
        _statsDao.insertReadingTime(now, seconds);
        debugPrint('📊 保存阅读时间: ${seconds}秒 (累计: ${_totalReadingSeconds}秒)');
      }

      // 重置开始时间
      _readingStartTime = now;
    } catch (e) {
      debugPrint('❌ 保存阅读时间失败: $e');
    }
  }

  /// 初始化动画控制器
  void _initializeAnimations() {
    _toolbarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400), // 🎨 呼出时间，优雅舒适
      reverseDuration: const Duration(milliseconds: 350), // 🎨 关闭动画更流畅
      vsync: this,
    );

    // 🎨 透明度动画：使用高级曲线，丝滑优雅
    _toolbarOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _toolbarAnimationController,
        curve: const Cubic(0.4, 0.0, 0.2, 1.0), // Material Design 标准 easing
        reverseCurve: const Cubic(0.0, 0.0, 0.2, 1.0), // 关闭时更丝滑的淡出
      ),
    );

    // 🎨 顶部工具栏：优雅的弹性滑动
    _topToolbarSlideAnimation =
        Tween<Offset>(begin: const Offset(0.0, -1.0), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _toolbarAnimationController,
        curve: Curves.easeOutCubic, // 呼出：快速开始，缓慢停止
        reverseCurve: const Cubic(0.4, 0.0, 1.0, 1.0), // 关闭：流畅加速离开
      ),
    );

    // 🎨 底部工具栏：与顶部对称的优雅滑动
    _bottomToolbarSlideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _toolbarAnimationController,
        curve: Curves.easeOutCubic, // 呼出：快速开始，缓慢停止
        reverseCurve: const Cubic(0.4, 0.0, 1.0, 1.0), // 关闭：流畅加速离开
      ),
    );
  }

  /// 初始化页面
  void _initializePage() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 初始化分页，会自动恢复到 initialPageIndex
      await initializePagination();
      await _initializeTts(); // 等待TTS初始化完成
    });
  }

  /// 初始化分页（公共方法，供子组件调用）
  ///
  /// 返回 Future 以便调用者可以等待分页完成
  Future<void> initializePagination() async {
    final size = MediaQuery.of(context).size;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    // 读取当前settings
    final settings = ref.read(readerSettingsProvider);

    // ✅ 计算真实可用高度（考虑所有UI元素）
    // 沉浸式模式下：全屏高度 - 状态栏
    // 注意：reader_page是全屏的，没有AppBar和BottomBar
    final realAvailableHeight = size.height - statusBarHeight;
    final adjustedSize = Size(size.width, realAvailableHeight);

    // 计算响应式padding（基于实际可用尺寸）
    final responsivePadding = settings.getResponsivePadding(adjustedSize);

    // 创建临时settings，带有响应式padding
    final settingsWithPadding = settings.copyWith(padding: responsivePadding);

    debugPrint('🎯 初始化沉浸式阅读器分页');
    debugPrint('   - 书籍内容长度: ${widget.bookContent.length} 字符');
    debugPrint('   - 初始页码: ${widget.initialPageIndex}');
    debugPrint(
      '   - 屏幕尺寸: ${size.width.toInt()}x${size.height.toInt()} (DPR: ${devicePixelRatio.toStringAsFixed(2)})',
    );
    debugPrint(
      '   - 实际可用高度: ${realAvailableHeight.toInt()} (已减去状态栏 ${statusBarHeight.toInt()})',
    );
    debugPrint(
      '   - 响应式Padding: T${responsivePadding.top.toInt()} B${responsivePadding.bottom.toInt()} L${responsivePadding.left.toInt()} R${responsivePadding.right.toInt()}',
    );

    await ref.read(readerPaginationProvider.notifier).initializePagination(
          text: widget.bookContent,
          screenSize: adjustedSize, // ✅ 使用调整后的尺寸
          settings: settingsWithPadding,
          statusBarHeight: statusBarHeight,
          bottomSafeArea: bottomSafeArea,
          devicePixelRatio: devicePixelRatio,
          initialPageIndex: widget.initialPageIndex,
        );
  }

  /// 初始化TTS
  Future<void> _initializeTts() async {
    try {
      debugPrint('📢 开始初始化TTS...');
      await ref.read(readerTtsProvider.notifier).initialize(
            getCurrentText: _getCurrentPageText,
            getNextText: _getNextPageText,
            getPrevText: _getPreviousPageText,
          );
      debugPrint('✅ TTS初始化成功');
    } catch (e, stack) {
      debugPrint('❌ TTS初始化失败: $e');
      debugPrint('Stack: $stack');
    }
  }

  /// 获取当前页面文本（用于TTS）
  String _getCurrentPageText() {
    final paginationState = ref.read(readerPaginationProvider);
    return paginationState.currentPageContent ?? '';
  }

  /// 获取下一页文本（用于TTS）
  String _getNextPageText() {
    final paginationNotifier = ref.read(readerPaginationProvider.notifier);
    final paginationState = ref.read(readerPaginationProvider);
    final nextIndex = paginationState.currentPageIndex + 1;

    if (nextIndex < paginationState.pages.length) {
      // 切换到下一页
      paginationNotifier.nextPage();
      return paginationState.pages[nextIndex];
    }

    return '';
  }

  /// 获取上一页文本（用于TTS）
  String _getPreviousPageText() {
    final paginationNotifier = ref.read(readerPaginationProvider.notifier);
    final paginationState = ref.read(readerPaginationProvider);
    final prevIndex = paginationState.currentPageIndex - 1;

    if (prevIndex >= 0) {
      // 切换到上一页
      paginationNotifier.previousPage();
      return paginationState.pages[prevIndex];
    }

    return '';
  }

  /// 处理指针按下事件
  void _handlePointerDown(PointerDownEvent event) {
    _pointerDownPosition = event.position;
    _pointerDownTime = DateTime.now().millisecondsSinceEpoch;
  }

  /// 处理指针抬起事件 - 检测是否为点击
  void _handlePointerUp(PointerUpEvent event) {
    if (_pointerDownPosition == null || _pointerDownTime == null) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final duration = now - _pointerDownTime!;
    final distance = (event.position - _pointerDownPosition!).distance;

    // 如果持续时间短（<300ms）且移动距离小（<10px），则认为是点击
    if (duration < 300 && distance < 10) {
      _handleScreenTap(event.position);
    }

    _pointerDownPosition = null;
    _pointerDownTime = null;
  }

  /// 处理屏幕点击 - 左中右三分区点击逻辑
  ///
  /// 所有翻页模式统一使用三分区：
  /// - 左边1/3：上一页
  /// - 中间1/3：显示/隐藏工具栏
  /// - 右边1/3：下一页
  void _handleScreenTap(Offset position) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final tapX = position.dx;
    final tapY = position.dy;

    // 检查是否点击在控制栏区域
    final toolbarState = ref.read(toolbarProvider);
    if (toolbarState.isVisible) {
      // 控制栏显示时，检测点击是否在控制栏区域内
      const topToolbarHeight = 120.0; // 顶部工具栏高度（约）
      const bottomToolbarHeight = 180.0; // 底部工具栏高度（约）

      if (tapY < topToolbarHeight ||
          tapY > screenHeight - bottomToolbarHeight) {
        // 点击在控制栏区域，忽略翻页，只处理关闭控制栏
        _hideToolbar();
        return;
      }
    }

    // 计算点击位置所在的区域
    if (tapX < screenWidth / 3) {
      // 左侧区域 - 上一页
      _handlePreviousPage();
    } else if (tapX > screenWidth * 2 / 3) {
      // 右侧区域 - 下一页
      _handleNextPage();
    } else {
      // 中间区域 - 显示/隐藏工具栏
      _handleCenterTap();
    }
  }

  /// 处理屏幕中央点击 - 显示/隐藏工具栏
  void _handleCenterTap() {
    // 如果文本选择工具栏正在显示，先关闭它
    if (_showTextSelectionToolbar) {
      debugPrint('📍 点击中央区域，关闭文本选择工具栏');
      _closeTextSelectionToolbar();
      return;
    }

    final toolbarState = ref.read(toolbarProvider);

    if (toolbarState.isVisible) {
      _hideToolbar();
    } else {
      _showToolbar();
    }
  }

  /// 处理上一页点击
  void _handlePreviousPage() {
    if (!mounted) return;

    final paginationNotifier = ref.read(readerPaginationProvider.notifier);
    final paginationState = ref.read(readerPaginationProvider);

    if (paginationState.currentPageIndex > 0) {
      paginationNotifier.previousPage();
      HapticFeedback.lightImpact();
      debugPrint('📖 点击左侧区域 - 上一页');
    }
  }

  /// 处理下一页点击
  void _handleNextPage() {
    if (!mounted) return;

    final paginationNotifier = ref.read(readerPaginationProvider.notifier);
    final paginationState = ref.read(readerPaginationProvider);

    if (paginationState.currentPageIndex < paginationState.pages.length - 1) {
      paginationNotifier.nextPage();
      HapticFeedback.lightImpact();
      debugPrint('📖 点击右侧区域 - 下一页');
    }
  }

  /// 显示工具栏
  void _showToolbar() {
    ref.read(toolbarProvider.notifier).show();
    _toolbarAnimationController.forward();

    // 显示系统 UI（状态栏和导航栏）
    _showSystemUI();

    // 启动自动隐藏计时器
    _startAutoHideTimer();

    // 触觉反馈
    HapticFeedback.lightImpact();
  }

  /// 隐藏工具栏
  void _hideToolbar() {
    // 先执行动画
    _toolbarAnimationController.reverse().then((_) {
      // 动画完成后再更新状态
      if (mounted) {
        ref.read(toolbarProvider.notifier).hide();
      }
    });

    // 取消自动隐藏计时器
    _cancelAutoHideTimer();

    // 立即进入全屏模式（只调用一次）
    _hideSystemUI();
    debugPrint('🎯 工具栏关闭动画开始，进入全屏');
  }

  /// 启动自动隐藏计时器
  void _startAutoHideTimer() {
    _cancelAutoHideTimer();
    _autoHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _hideToolbar();
      }
    });
  }

  /// 取消自动隐藏计时器
  void _cancelAutoHideTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
  }

  /// 进入沉浸式模式（隐藏状态栏和导航栏）
  void _enterImmersiveMode() {
    debugPrint('📱 进入沉浸式全屏模式');
    _hideSystemUI();
  }

  /// 退出沉浸式模式（恢复状态栏和导航栏）
  void _exitImmersiveMode() {
    _showSystemUI();
    debugPrint('📱 退出沉浸式模式 - 恢复系统UI');
  }

  /// 启用屏幕常亮（防止长按选择文字时黑屏）
  Future<void> _enableWakeLock() async {
    try {
      await WakelockPlus.enable();
      debugPrint('🔆 屏幕常亮已启用');
    } catch (e) {
      debugPrint('❌ 启用屏幕常亮失败: $e');
    }
  }

  /// 禁用屏幕常亮
  Future<void> _disableWakeLock() async {
    try {
      await WakelockPlus.disable();
      debugPrint('🌙 屏幕常亮已禁用');
    } catch (e) {
      debugPrint('❌ 禁用屏幕常亮失败: $e');
    }
  }

  /// 显示系统 UI（状态栏和导航栏）- 工具栏显示时使用
  Future<void> _showSystemUI() async {
    try {
      const platform = MethodChannel('com.niki.xread/fullscreen');
      await platform.invokeMethod('showSystemUI');
      debugPrint('📱 显示系统UI - 工具栏可见');
    } catch (e) {
      debugPrint('❌ 显示系统UI失败: $e');
      // 降级使用 Flutter API
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  /// 隐藏系统 UI（状态栏和导航栏）- 工具栏隐藏时使用
  Future<void> _hideSystemUI() async {
    debugPrint('📱 隐藏系统UI，进入全屏');

    try {
      const platform = MethodChannel('com.niki.xread/fullscreen');
      await platform.invokeMethod('hideSystemUI');
      debugPrint('✅ 原生全屏已设置');
    } catch (e) {
      debugPrint('❌ 原生全屏失败: $e，使用降级方案');
      // 降级使用 Flutter API
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    }
  }

  /// 处理文本选择
  void _handleTextSelection(String selectedText, Offset position) {
    if (!mounted) return;

    debugPrint('📝 文本选择: "$selectedText" (前20字符)');
    debugPrint('📍 工具栏位置: (${position.dx}, ${position.dy})');

    // 取消之前的延迟计时器
    _selectionToolbarDelayTimer?.cancel();

    // 先保存选中的文本和位置，但不立即显示工具栏
    _selectedText = selectedText;
    _selectionToolbarPosition = position;

    // 延迟 500ms 显示工具栏，确保用户选择稳定
    _selectionToolbarDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      // 检查选中的文本是否还是同一个（用户可能已经改变选择）
      if (_selectedText == selectedText &&
          _selectionToolbarPosition == position) {
        debugPrint('⏰ 延迟后显示工具栏');

        // 添加触觉反馈
        HapticFeedback.selectionClick();

        setState(() {
          _showTextSelectionToolbar = true;
        });

        debugPrint('✅ 工具栏显示状态: $_showTextSelectionToolbar');
      } else {
        debugPrint('⚠️ 选择已改变，取消显示工具栏');
      }
    });
  }

  /// 关闭文本选择工具栏
  void _closeTextSelectionToolbar() {
    if (!mounted) return;

    // 取消延迟计时器
    _selectionToolbarDelayTimer?.cancel();

    debugPrint('❌ 关闭文本选择工具栏');
    setState(() {
      _showTextSelectionToolbar = false;
      _selectedText = '';
      _selectionToolbarPosition = null;
    });
  }

  /// 处理笔记创建
  void _handleNoteCreated(BookNote note) {
    // 可以在这里添加笔记创建后的逻辑，比如显示提示
    debugPrint('笔记已创建: ${note.content}');
  }

  /// 处理笔记更新
  void _handleNoteUpdated(BookNote note) {
    // 可以在这里添加笔记更新后的逻辑，比如显示提示
    debugPrint('笔记已更新: ${note.content}');
  }

  /// 保存阅读进度到数据库
  ///
  /// 使用 ReadingProgressService 进行防抖保存
  /// [immediate] 为 true 时立即保存，用于页面关闭等关键场景
  Future<void> _saveReadingProgress(
    int pageIndex, {
    bool immediate = false,
  }) async {
    debugPrint(
      '🔄 正在保存阅读进度: bookId=${widget.bookId}, pageIndex=$pageIndex, immediate=$immediate',
    );

    if (widget.bookId == null) {
      debugPrint('⚠️ 书籍ID为空，无法保存阅读进度');
      return;
    }

    try {
      // 获取总页数
      final book = await BookDao().getBookById(widget.bookId!);
      if (book == null) {
        debugPrint('⚠️ 书籍不存在: bookId=${widget.bookId}');
        return;
      }

      // 使用 ReadingProgressService 保存进度
      final progressService = DataManager().progressService;
      await progressService.updateProgress(
        bookId: 'book_${widget.bookId}',
        bookDatabaseId: widget.bookId!,
        currentPage: pageIndex,
        totalPages: book.totalPages,
        progress: book.totalPages > 0 ? pageIndex / book.totalPages : 0.0,
        immediate: immediate,
        critical: immediate, // 关键保存标记
      );

      debugPrint(
        '✅ 阅读进度已保存: bookId=${widget.bookId}, 第 ${pageIndex + 1} 页/${book.totalPages}',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ 保存阅读进度失败: $e');
      debugPrint('堆栈: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final toolbarState = ref.watch(toolbarProvider);

    // 在build方法中设置监听器（必须在build方法中）
    ref.listen<ReaderSettings>(readerSettingsProvider, (previous, next) {
      if (previous == null) return;

      // 检测主题变化
      if (previous.theme != next.theme) {
        debugPrint('🎨 主题已切换: ${previous.themeName} → ${next.themeName}');
        // 强制重建以更新背景色
        if (mounted) {
          setState(() {});
          // 主题切换后重新应用全屏模式（如果工具栏未显示）
          if (!toolbarState.isVisible) {
            // 使用 addPostFrameCallback 确保在UI重建完成后再应用全屏
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _hideSystemUI();
                debugPrint('🎨 主题切换完成，重新进入全屏模式');
              }
            });
          }
        }
      }

      // 检测影响分页的设置是否变化
      final needRepagination = previous.fontSize != next.fontSize ||
          previous.lineSpacing != next.lineSpacing ||
          previous.letterSpacing != next.letterSpacing ||
          previous.horizontalMargin != next.horizontalMargin ||
          previous.firstLineIndent != next.firstLineIndent;

      if (needRepagination) {
        debugPrint('📝 排版设置变化，触发重新分页...');
        debugPrint('   字体: ${previous.fontSize} → ${next.fontSize}');

        // 取消之前的防抖计时器
        _repaginationDebounceTimer?.cancel();

        // 使用防抖延迟重新分页（200ms），避免频繁调整时卡顿
        _repaginationDebounceTimer =
            Timer(const Duration(milliseconds: 200), () {
          if (!mounted) return;

          setState(() {
            _isRepaginating = true;
          });

          // 保存当前页面的字符位置（而不是进度百分比）
          final paginationState = ref.read(readerPaginationProvider);
          final currentCharOffset = paginationState.currentCharOffset;
          final currentProgress = paginationState.progress; // 作为备用方案

          debugPrint(
              '💾 保存当前阅读位置: 字符索引 $currentCharOffset (进度 ${(currentProgress * 100).toStringAsFixed(1)}%)');

          // 使用延迟确保loading状态能被显示
          Future.delayed(const Duration(milliseconds: 50), () async {
            if (!mounted) return;

            // 重新分页（会等待完成）
            await initializePagination();

            // 重新分页完成后，恢复到相应的阅读位置
            if (mounted) {
              final notifier = ref.read(readerPaginationProvider.notifier);

              // 优先使用字符索引定位，更精确
              if (currentCharOffset != null) {
                notifier.goToCharIndex(currentCharOffset);
                debugPrint(
                  '✅ 重新分页完成，已通过字符索引 $currentCharOffset 精确定位',
                );
              } else {
                // 回退到进度百分比方法
                notifier.goToProgress(currentProgress);
                debugPrint(
                  '✅ 重新分页完成，已恢复到 ${(currentProgress * 100).toStringAsFixed(1)}% 位置',
                );
              }

              // 隐藏loading
              setState(() {
                _isRepaginating = false;
              });
            }
          });
        });
      }
    });

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: settings.backgroundColor,
        child: SafeArea(
          top: false,
          bottom: false,
          child: Listener(
            onPointerDown: _handlePointerDown,
            onPointerUp: _handlePointerUp,
            behavior: HitTestBehavior.translucent,
            child: Stack(
              children: [
                // 主要阅读内容区域 - 沉浸式布局
                _buildReaderContentArea(settings),

                // 页面信息浮层（状态栏和进度）
                _ReaderOverlay(
                  showStatusBar: true,
                  showProgress: settings.showPageIndicator,
                ),

                // 工具栏（顶部和底部）
                RepaintBoundary(
                  child: _buildToolbarArea(toolbarState, settings),
                ),

                // 重新分页加载指示器
                if (_isRepaginating)
                  RepaintBoundary(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 24,
                          ),
                          decoration: BoxDecoration(
                            color: settings.backgroundColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 16,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  settings.textStyle.color ?? Colors.black,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '重新排版中...',
                                style: settings.textStyle.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // 文本选择工具栏 - 使用Material确保正确的层级和主题
                if (_showTextSelectionToolbar &&
                    _selectionToolbarPosition != null &&
                    _selectedText.isNotEmpty)
                  Positioned(
                    left: _selectionToolbarPosition!.dx,
                    top: _selectionToolbarPosition!.dy,
                    child: Material(
                      type: MaterialType.transparency,
                      child: EnhancedTextSelectionToolbar(
                        key: ValueKey('toolbar_${_selectedText.hashCode}'),
                        selectedText: _selectedText,
                        bookId: widget.bookId ?? 0,
                        pageNumber: ref
                                .read(readerPaginationProvider)
                                .currentPageIndex +
                            1,
                        chapterTitle: widget.bookTitle ?? '未知章节',
                        cfi:
                            'page-${ref.read(readerPaginationProvider).currentPageIndex + 1}',
                        onNoteCreated: _handleNoteCreated,
                        onNoteUpdated: _handleNoteUpdated,
                        onClose: _closeTextSelectionToolbar,
                        backgroundColor: settings.backgroundColor,
                        iconColor: settings.textStyle.color,
                        textColor: settings.textStyle.color,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建阅读内容区域
  Widget _buildReaderContentArea(ReaderSettings settings) {
    return Positioned.fill(
      child: _ReaderTextView(
        paginationMode: settings.paginationMode,
        onPageChanged: (pageIndex) {
          // 页面变化时关闭文本选择工具栏
          if (_showTextSelectionToolbar) {
            _closeTextSelectionToolbar();
          }

          // 页面变化时取消自动隐藏计时器
          _cancelAutoHideTimer();
          if (ref.read(toolbarProvider).isVisible) {
            _startAutoHideTimer();
          }

          // 保存阅读进度
          _saveReadingProgress(pageIndex);
        },
        onTextSelection: _handleTextSelection,
        onTap: _handleCenterTap,
      ),
    );
  }

  /// 构建工具栏区域
  Widget _buildToolbarArea(ToolbarState toolbarState, ReaderSettings settings) {
    // 不要根据isVisible直接返回空组件，而是始终渲染，让动画控制显示/隐藏
    // 这样关闭动画才能正常播放
    return Stack(
      children: [
        // 顶部工具栏
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: _topToolbarSlideAnimation,
            child: FadeTransition(
              opacity: _toolbarOpacityAnimation,
              child: _ReaderToolbar(
                position: _ToolbarPosition.top,
                onInteraction: _startAutoHideTimer,
              ),
            ),
          ),
        ),

        // 底部工具栏
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: _bottomToolbarSlideAnimation,
            child: FadeTransition(
              opacity: _toolbarOpacityAnimation,
              child: _ReaderToolbar(
                position: _ToolbarPosition.bottom,
                onInteraction: _startAutoHideTimer,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ============================================================================
/// 私有组件类 - 符合Riverpod规范，每个build方法控制在80行内
/// ============================================================================

/// 工具栏位置枚举
enum _ToolbarPosition {
  top, // 顶部工具栏
  bottom, // 底部工具栏
}

/// 阅读器浮层信息组件 - Riverpod版本
class _ReaderOverlay extends ConsumerStatefulWidget {
  final bool showStatusBar;
  final bool showProgress;

  const _ReaderOverlay({
    required this.showStatusBar,
    required this.showProgress,
  });

  @override
  ConsumerState<_ReaderOverlay> createState() => _ReaderOverlayState();
}

class _ReaderOverlayState extends ConsumerState<_ReaderOverlay> {
  Timer? _timeUpdateTimer;
  String _currentTime = '';
  int _batteryLevel = 100;
  final Battery _battery = Battery();

  @override
  void initState() {
    super.initState();
    _initializeOverlay();
  }

  @override
  void dispose() {
    _timeUpdateTimer?.cancel();
    super.dispose();
  }

  void _initializeOverlay() {
    _updateTime();
    _updateBatteryLevel();
    _timeUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateTime();
      _updateBatteryLevel();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    final timeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    if (mounted && timeString != _currentTime) {
      setState(() {
        _currentTime = timeString;
      });
    }
  }

  Future<void> _updateBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      if (mounted) {
        setState(() {
          _batteryLevel = level;
        });
      }
    } catch (e) {
      debugPrint('获取电池电量失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);

    return Stack(
      children: [
        if (widget.showStatusBar) _buildTopStatusBar(settings),
        if (widget.showProgress) _buildBottomProgressBar(settings),
      ],
    );
  }

  Widget _buildTopStatusBar(ReaderSettings settings) {
    final screenSize = MediaQuery.of(context).size;
    // 响应式计算：top使用屏幕高度的1%，水平边距使用屏幕宽度的8%
    final topMargin = screenSize.height * 0.01;
    final horizontalMargin = screenSize.width * 0.08;

    return Positioned(
      top: topMargin,
      left: horizontalMargin,
      right: horizontalMargin,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // 阻止点击事件穿透
        onTap: () {}, // 吸收点击事件
        onTapUp: (_) {}, // 🔧 阻止TapUp事件穿透导致翻页
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTimeDisplay(settings),
              _buildBatteryDisplay(settings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeDisplay(ReaderSettings settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: settings.textStyle.color?.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _currentTime,
        style: settings.textStyle.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: settings.textStyle.color?.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildBatteryDisplay(ReaderSettings settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: settings.textStyle.color?.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getBatteryIcon(), size: 16, color: _getBatteryColor(settings)),
          const SizedBox(width: 4),
          Text(
            '$_batteryLevel%',
            style: settings.textStyle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: settings.textStyle.color?.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomProgressBar(ReaderSettings settings) {
    final paginationState = ref.watch(readerPaginationProvider);

    // 📊 支持估算页码显示："1/约850页" 或 "1/856页"
    final pageInfo = paginationState.pages.isEmpty
        ? '0/0'
        : paginationState.isEstimated == true
            ? '${paginationState.currentPageIndex + 1}/约${paginationState.totalPages}'
            : '${paginationState.currentPageIndex + 1}/${paginationState.totalPages}';
    final progress = paginationState.progress;

    final screenSize = MediaQuery.of(context).size;

    // 响应式计算：底部边距为1%屏高，水平边距为10%屏宽
    final bottomMargin = screenSize.height * 0.01;
    final horizontalMargin = screenSize.width * 0.10;

    return Positioned(
      bottom: bottomMargin,
      left: horizontalMargin,
      right: horizontalMargin,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // 阻止点击事件穿透
        onTap: () {}, // 吸收点击事件
        onTapUp: (_) {}, // 🔧 阻止TapUp事件穿透导致翻页
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPageInfo(pageInfo, settings),
              _buildProgressInfo(progress, settings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageInfo(String pageInfo, ReaderSettings settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: settings.textStyle.color?.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        pageInfo,
        style: settings.textStyle.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: settings.textStyle.color?.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildProgressInfo(double progress, ReaderSettings settings) {
    final progressPercent = (progress * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: settings.textStyle.color?.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1.5),
              color: settings.textStyle.color?.withValues(alpha: 0.2),
            ),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                settings.textStyle.color?.withValues(alpha: 0.6) ?? Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$progressPercent%',
            style: settings.textStyle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: settings.textStyle.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getBatteryIcon() {
    if (_batteryLevel >= 90) return Icons.battery_full;
    if (_batteryLevel >= 60) return Icons.battery_5_bar;
    if (_batteryLevel >= 40) return Icons.battery_3_bar;
    if (_batteryLevel >= 20) return Icons.battery_2_bar;
    if (_batteryLevel >= 10) return Icons.battery_1_bar;
    return Icons.battery_0_bar;
  }

  Color _getBatteryColor(ReaderSettings settings) {
    final baseColor = settings.textStyle.color ?? Colors.black;
    if (_batteryLevel <= 20) {
      return Colors.red;
    } else if (_batteryLevel <= 40) {
      return Colors.orange;
    } else {
      return baseColor.withValues(alpha: 0.8);
    }
  }
}

/// 阅读文本视图组件 - Riverpod版本
class _ReaderTextView extends ConsumerStatefulWidget {
  final PaginationMode paginationMode;
  final Function(int pageIndex)? onPageChanged;
  final Function(String, Offset)? onTextSelection;
  final VoidCallback? onTap;

  const _ReaderTextView({
    required this.paginationMode,
    this.onPageChanged,
    this.onTextSelection,
    this.onTap,
  });

  @override
  ConsumerState<_ReaderTextView> createState() => _ReaderTextViewState();
}

class _ReaderTextViewState extends ConsumerState<_ReaderTextView> {
  PageController? _pageController;
  ScrollController? _scrollController;
  GlobalKey<_SimulationPaginationViewState>? _simulationKey;
  int _lastPageIndex = 0;
  bool _isDisposed = false;
  bool _hasInitializedAfterPagination = false; // 标记是否已在分页后初始化

  @override
  void initState() {
    super.initState();
    _initializeControllers();

    // 监听分页状态变化，当分页完成时重新初始化 controller
    ref.listenManual(readerPaginationProvider, (previous, next) {
      // 当从 loading 变为 loaded，且页码大于0，且还没有初始化过
      if (!_hasInitializedAfterPagination &&
          previous?.isLoading == true &&
          !next.isLoading &&
          next.pages.isNotEmpty &&
          next.currentPageIndex > 0) {
        debugPrint('📖 分页完成，重新初始化 controller 到第 ${next.currentPageIndex} 页');
        _hasInitializedAfterPagination = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isDisposed && mounted) {
            _initializeControllers();
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(_ReaderTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paginationMode != widget.paginationMode) {
      _initializeControllers();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pageController?.dispose();
    _pageController = null;
    _scrollController?.dispose();
    _scrollController = null;
    _simulationKey = null;
    super.dispose();
  }

  void _initializeControllers() {
    // 如果已经 disposed，不执行任何操作
    if (_isDisposed) {
      debugPrint('⚠️ Widget已disposed，跳过初始化');
      return;
    }

    // 先清理旧的 controllers
    _pageController?.dispose();
    _scrollController?.dispose();

    // 重置所有引用
    _pageController = null;
    _scrollController = null;
    _simulationKey = null;

    // 获取当前页码（用于初始化 controller）
    final currentPageIndex =
        ref.read(readerPaginationProvider).currentPageIndex;

    // 根据模式创建对应的 controller
    switch (widget.paginationMode) {
      case PaginationMode.cover:
        // 覆盖翻页使用与slide相同的PageController
        _pageController = PageController(initialPage: currentPageIndex);
        debugPrint('📖 [覆盖翻页] PageController 初始化到第 $currentPageIndex 页');
        break;
      case PaginationMode.slide:
        // 使用当前页码作为初始页
        _pageController = PageController(initialPage: currentPageIndex);
        debugPrint('📖 PageController 初始化到第 $currentPageIndex 页');
        break;
      case PaginationMode.scroll:
        _scrollController = ScrollController();
        // ScrollController 需要在有数据后手动跳转
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController != null && _scrollController!.hasClients) {
            final paginationState = ref.read(readerPaginationProvider);
            if (paginationState.pages.isNotEmpty && currentPageIndex > 0) {
              final screenHeight = MediaQuery.of(context).size.height;
              final targetOffset = currentPageIndex * screenHeight;
              _scrollController!.jumpTo(targetOffset);
              debugPrint('📖 ScrollController 跳转到第 $currentPageIndex 页');
            }
          }
        });
        break;
      case PaginationMode.simulation:
        _simulationKey = GlobalKey<_SimulationPaginationViewState>();
        // 仿真翻页需要在创建后手动跳转
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_simulationKey?.currentState != null && currentPageIndex > 0) {
            _simulationKey!.currentState!.goToPage(currentPageIndex);
            debugPrint('📖 SimulationView 跳转到第 $currentPageIndex 页');
          }
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final paginationState = ref.watch(readerPaginationProvider);
    final settings = ref.watch(readerSettingsProvider);

    // 监听页码变化，同步更新 PageController
    _syncPageController(paginationState.currentPageIndex);

    // 关键：使用分页时保存的settings（包含响应式padding），如果没有则使用当前settings
    final renderSettings = paginationState.paginationSettings ?? settings;

    if (paginationState.isLoading) {
      return _buildLoadingView(settings);
    }

    if (paginationState.error != null) {
      return _buildErrorView(paginationState.error!, settings);
    }

    if (paginationState.pages.isEmpty) {
      return _buildEmptyView(settings);
    }

    return _buildContentView(paginationState, renderSettings);
  }

  /// 同步 PageController 到当前页码
  ///
  /// 当通过点击翻页时，需要让 PageController 跳转到对应页面
  void _syncPageController(int currentPageIndex) {
    // 如果已经 disposed，不执行任何操作
    if (_isDisposed) return;

    if (_lastPageIndex == currentPageIndex) return;

    // 只在左右滑动模式和覆盖翻页模式下同步 PageController
    if ((widget.paginationMode == PaginationMode.slide ||
            widget.paginationMode == PaginationMode.cover) &&
        _pageController != null &&
        _pageController!.hasClients) {
      // 检查是否需要跳转
      final currentPage = _pageController!.page?.round() ?? 0;
      if (currentPage != currentPageIndex) {
        // 使用 animateToPage 实现平滑过渡
        _pageController!.animateToPage(
          currentPageIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }

    _lastPageIndex = currentPageIndex;
  }

  Widget _buildContentView(
    ReaderPaginationState paginationState,
    ReaderSettings settings,
  ) {
    switch (widget.paginationMode) {
      case PaginationMode.cover:
        // 覆盖翻页 - 新页面从侧面覆盖当前页
        if (_pageController == null) {
          debugPrint('⚠️ PageController is null, reinitializing...');
          _initializeControllers();
        }
        return CoverPaginationView(
          pages: paginationState.pages,
          controller: _pageController!,
          settings: settings,
          onPageChanged: _onPageChanged,
          onTextSelection: _onTextSelection,
          onTap: widget.onTap,
        );
      case PaginationMode.slide:
        // 如果 controller 为 null，先初始化（防御性检查）
        if (_pageController == null) {
          debugPrint('⚠️ PageController is null, reinitializing...');
          _initializeControllers();
        }
        return _SlidePaginationView(
          pages: paginationState.pages,
          controller: _pageController!,
          settings: settings,
          onPageChanged: _onPageChanged,
          onTextSelection: _onTextSelection,
          onTap: widget.onTap,
        );
      case PaginationMode.scroll:
        // 如果 controller 为 null，先初始化（防御性检查）
        if (_scrollController == null) {
          debugPrint('⚠️ ScrollController is null, reinitializing...');
          _initializeControllers();
        }
        return _ScrollPaginationView(
          pages: paginationState.pages,
          controller: _scrollController!,
          settings: settings,
          onPageChanged: _onPageChanged,
          onTextSelection: _onTextSelection,
          onTap: widget.onTap,
        );
      case PaginationMode.simulation:
        // 如果 key 为 null，先初始化（防御性检查）
        if (_simulationKey == null) {
          debugPrint('⚠️ Simulation key is null, reinitializing...');
          _initializeControllers();
        }
        return _SimulationPaginationView(
          key: _simulationKey,
          pages: paginationState.pages,
          settings: settings,
          onPageChanged: _onPageChanged,
          onTextSelection: _onTextSelection,
          onTap: widget.onTap,
        );
    }
  }

  void _onPageChanged(int pageIndex) {
    // 如果已经 disposed，不执行任何操作
    if (_isDisposed) return;

    ref.read(readerPaginationProvider.notifier).goToPage(pageIndex);
    widget.onPageChanged?.call(pageIndex);
  }

  void _onTextSelection(String text, Offset position) {
    widget.onTextSelection?.call(text, position);
  }

  Widget _buildLoadingView(ReaderSettings settings) {
    return Container(
      color: settings.backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 流畅的加载动画
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  settings.textStyle.color?.withValues(alpha: 0.8) ??
                      Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 加载文本 - 带淡入动画
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, child) {
                return Opacity(opacity: value, child: child);
              },
              child: Column(
                children: [
                  Text(
                    '正在分页处理',
                    style: settings.textStyle.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '马上就好...',
                    style: settings.textStyle.copyWith(
                      fontSize: 14,
                      color: settings.textStyle.color?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // 进度提示（可选）
            _LoadingDots(color: settings.textStyle.color),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String error, ReaderSettings settings) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 24),
            Text(
              '分页失败',
              style: settings.textStyle.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: settings.textStyle.copyWith(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // 重试按钮
            ElevatedButton.icon(
              onPressed: () {
                // 通过祖先 widget 重新初始化分页
                final readerPageState =
                    context.findAncestorStateOfType<_ReaderPageState>();
                if (readerPageState != null) {
                  readerPageState.initializePagination();
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                backgroundColor: settings.textStyle.color?.withValues(
                  alpha: 0.1,
                ),
                foregroundColor: settings.textStyle.color,
              ),
            ),
            const SizedBox(height: 16),
            // 返回按钮
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('返回'),
              style: TextButton.styleFrom(
                foregroundColor: settings.textStyle.color?.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(ReaderSettings settings) {
    return Center(
      child: Text(
        '没有内容可显示',
        style: settings.textStyle.copyWith(
          fontSize: 16,
          color: settings.textStyle.color?.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

/// 左右滑动翻页视图 - PageView实现
/// 支持流畅的左右滑动翻页，带有预加载和缓存优化
class _SlidePaginationView extends StatefulWidget {
  final List<String> pages;
  final PageController controller;
  final ReaderSettings settings;
  final Function(int)? onPageChanged;
  final Function(String, Offset)? onTextSelection;
  final VoidCallback? onTap;

  const _SlidePaginationView({
    required this.pages,
    required this.controller,
    required this.settings,
    this.onPageChanged,
    this.onTextSelection,
    this.onTap,
  });

  @override
  State<_SlidePaginationView> createState() => _SlidePaginationViewState();
}

class _SlidePaginationViewState extends State<_SlidePaginationView> {
  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: widget.controller,
      onPageChanged: widget.onPageChanged,
      itemCount: widget.pages.length,
      // 优化滚动物理效果
      physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
      itemBuilder: (context, index) {
        return _buildPageContent(context, widget.pages[index]);
      },
    );
  }

  Widget _buildPageContent(BuildContext context, String pageContent) {
    // 分页器已经精确计算了每页应该有多少文字
    // 渲染时需要确保尺寸和分页一致
    return RepaintBoundary(
      child: Consumer(
        builder: (context, ref, child) {
          final currentSettings = ref.watch(readerSettingsProvider);
          final ttsState = ref.watch(readerTtsProvider);
          final paginationState = ref.watch(readerPaginationProvider);

          // 获取屏幕尺寸
          final screenSize = MediaQuery.of(context).size;
          final statusBarHeight = MediaQuery.of(context).padding.top;

          // 分页时保存的 padding 和 maxLines
          final basePadding = paginationState.paginationSettings?.padding ??
              currentSettings.padding;
          final maxLines = paginationState.maxLinesPerPage ?? 20;

          // 🔧 渲染时的 padding：
          // - 顶部需要加上状态栏高度（分页时的屏幕尺寸已减去状态栏）
          // - 左右底部保持和分页一致
          final renderPadding = EdgeInsets.only(
            left: basePadding.left,
            right: basePadding.right,
            top: basePadding.top + statusBarHeight, // 加上状态栏高度
            bottom: basePadding.bottom,
          );

          return Container(
            width: screenSize.width,
            height: screenSize.height, // 使用完整屏幕高度
            padding: renderPadding,
            color: currentSettings.backgroundColor,
            // ClipRect确保超出部分被裁剪
            child: ClipRect(
              clipBehavior: Clip.hardEdge,
              child: _HighlightedText(
                text: pageContent,
                style: currentSettings.textStyle,
                highlightedSentenceIndex: ttsState.highlightedSentenceIndex,
                enableSelection: currentSettings.enableTextSelection,
                onTextSelection: widget.onTextSelection,
                maxLines: maxLines,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 上下滚动视图 - 分页式垂直滚动
/// 实现类似真实阅读器的分页滚动效果，而非连续滚动
class _ScrollPaginationView extends StatefulWidget {
  final List<String> pages;
  final ScrollController controller;
  final ReaderSettings settings;
  final Function(int)? onPageChanged;
  final Function(String, Offset)? onTextSelection;
  final VoidCallback? onTap;

  const _ScrollPaginationView({
    required this.pages,
    required this.controller,
    required this.settings,
    this.onPageChanged,
    this.onTextSelection,
    this.onTap,
  });

  @override
  State<_ScrollPaginationView> createState() => _ScrollPaginationViewState();
}

class _ScrollPaginationViewState extends State<_ScrollPaginationView> {
  int _currentPageIndex = 0;
  double _dragStartOffset = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (_isDragging) return;

    final screenHeight = MediaQuery.of(context).size.height;
    final currentPage = (widget.controller.offset / screenHeight).round();
    final clampedPage = currentPage.clamp(0, widget.pages.length - 1);

    if (clampedPage != _currentPageIndex) {
      setState(() {
        _currentPageIndex = clampedPage;
      });
      widget.onPageChanged?.call(clampedPage);
    }
  }

  void _handleDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragStartOffset = widget.controller.offset;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    // 反向拖拽（向下拖动时减少偏移，向上拖动时增加偏移）
    final newOffset = _dragStartOffset - details.primaryDelta!;
    widget.controller.jumpTo(
      newOffset.clamp(0.0, widget.controller.position.maxScrollExtent),
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    final screenHeight = MediaQuery.of(context).size.height;
    final velocity = details.primaryVelocity ?? 0;
    final currentOffset = widget.controller.offset;

    // 根据拖拽方向和速度决定翻页
    int targetPage = _currentPageIndex;

    if (velocity.abs() > 500) {
      // 快速滑动：根据速度方向翻页
      if (velocity < 0 && _currentPageIndex < widget.pages.length - 1) {
        targetPage = _currentPageIndex + 1; // 向上滑动，下一页
      } else if (velocity > 0 && _currentPageIndex > 0) {
        targetPage = _currentPageIndex - 1; // 向下滑动，上一页
      }
    } else {
      // 慢速滑动：根据偏移量决定
      final currentPageOffset = _currentPageIndex * screenHeight;
      final delta = currentOffset - currentPageOffset;

      if (delta > screenHeight * 0.3 &&
          _currentPageIndex < widget.pages.length - 1) {
        targetPage = _currentPageIndex + 1;
      } else if (delta < -screenHeight * 0.3 && _currentPageIndex > 0) {
        targetPage = _currentPageIndex - 1;
      }
    }

    // 平滑滚动到目标页面
    widget.controller.animateTo(
      targetPage * screenHeight,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );

    if (targetPage != _currentPageIndex) {
      setState(() {
        _currentPageIndex = targetPage;
      });
      widget.onPageChanged?.call(targetPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onVerticalDragStart: _handleDragStart,
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
      child: ListView.builder(
        controller: widget.controller,
        physics: const NeverScrollableScrollPhysics(), // 禁用默认滚动
        itemCount: widget.pages.length,
        itemBuilder: (context, index) {
          return SizedBox(
            height: screenHeight,
            child: Consumer(
              builder: (context, ref, child) {
                // 实时监听设置变化，确保背景色和文字颜色立即更新
                final currentSettings = ref.watch(readerSettingsProvider);
                final ttsState = ref.watch(readerTtsProvider);
                final paginationState = ref.watch(readerPaginationProvider);

                return Container(
                  padding: currentSettings.padding,
                  color: currentSettings.backgroundColor,
                  child: _HighlightedText(
                    text: widget.pages[index],
                    style: currentSettings.textStyle,
                    highlightedSentenceIndex: ttsState.highlightedSentenceIndex,
                    enableSelection: currentSettings.enableTextSelection,
                    onTextSelection: widget.onTextSelection,
                    maxLines: paginationState.maxLinesPerPage,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// 仿真翻页视图 - 增强版 3D 纸张翻转效果
/// 支持平滑的 3D 翻页动画，模拟真实纸张书的翻页体验
class _SimulationPaginationView extends StatefulWidget {
  final List<String> pages;
  final ReaderSettings settings;
  final Function(int)? onPageChanged;
  final Function(String, Offset)? onTextSelection;
  final VoidCallback? onTap;

  const _SimulationPaginationView({
    Key? key,
    required this.pages,
    required this.settings,
    this.onPageChanged,
    this.onTextSelection,
    this.onTap,
  }) : super(key: key);

  @override
  State<_SimulationPaginationView> createState() =>
      _SimulationPaginationViewState();
}

class _SimulationPaginationViewState extends State<_SimulationPaginationView>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;

  int _currentPage = 0;
  int _nextPage = 0;
  bool _isAnimating = false;
  bool _isForwardFlip = true;
  double _dragStartX = 0.0;
  double _currentDragX = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  /// 初始化动画控制器
  void _initializeAnimations() {
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _shadowAnimation = Tween<double>(begin: 0.1, end: 0.3).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _flipController.addStatusListener(_onFlipStatusChanged);
  }

  void _onFlipStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        _currentPage = _nextPage;
        _isAnimating = false;
      });
      _flipController.reset();
      widget.onPageChanged?.call(_currentPage);
    }
  }

  /// 处理水平拖动开始
  void _handleDragStart(DragStartDetails details) {
    if (_isAnimating) return;
    _dragStartX = details.globalPosition.dx;
    _currentDragX = _dragStartX;
  }

  /// 处理水平拖动更新
  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;

    setState(() {
      _currentDragX = details.globalPosition.dx;
    });

    final delta = _currentDragX - _dragStartX;
    final screenWidth = MediaQuery.of(context).size.width;
    final progress = (delta.abs() / screenWidth).clamp(0.0, 1.0);

    // 实时更新动画进度
    if (delta < 0 && _currentPage < widget.pages.length - 1) {
      // 向左拖拽
      _isForwardFlip = true;
      _flipController.value = progress;
    } else if (delta > 0 && _currentPage > 0) {
      // 向右拖拽
      _isForwardFlip = false;
      _flipController.value = progress;
    }
  }

  /// 处理水平拖动结束
  void _handleDragEnd(DragEndDetails details) {
    if (_isAnimating) return;

    final delta = _currentDragX - _dragStartX;
    final velocity = details.primaryVelocity ?? 0;
    final screenWidth = MediaQuery.of(context).size.width;
    final progress = delta.abs() / screenWidth;

    // 决定是否翻页
    bool shouldFlip = false;
    int targetPage = _currentPage;

    if (velocity.abs() > 500) {
      // 快速滑动
      if (velocity < 0 && _currentPage < widget.pages.length - 1) {
        shouldFlip = true;
        targetPage = _currentPage + 1;
        _isForwardFlip = true;
      } else if (velocity > 0 && _currentPage > 0) {
        shouldFlip = true;
        targetPage = _currentPage - 1;
        _isForwardFlip = false;
      }
    } else if (progress > 0.3) {
      // 拖动超过 30%
      if (delta < 0 && _currentPage < widget.pages.length - 1) {
        shouldFlip = true;
        targetPage = _currentPage + 1;
        _isForwardFlip = true;
      } else if (delta > 0 && _currentPage > 0) {
        shouldFlip = true;
        targetPage = _currentPage - 1;
        _isForwardFlip = false;
      }
    }

    if (shouldFlip) {
      // 执行翻页动画
      setState(() {
        _isAnimating = true;
        _nextPage = targetPage;
      });
      _flipController.forward();
    } else {
      // 回弹到当前页
      _flipController.reverse();
    }

    _dragStartX = 0.0;
    _currentDragX = 0.0;
  }

  /// 处理点击翻页 - 左中右三分区
  void _handleTapUp(TapUpDetails details) {
    if (_isAnimating) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final tapX = details.globalPosition.dx;
    final tapY = details.globalPosition.dy;

    // 检测是否点击在控制栏区域（粗略估计）
    const topToolbarHeight = 120.0;
    const bottomToolbarHeight = 180.0;

    if (tapY < topToolbarHeight || tapY > screenHeight - bottomToolbarHeight) {
      // 点击在控制栏区域，只触发菜单（关闭控制栏）
      widget.onTap?.call();
      return;
    }

    if (tapX < screenWidth / 3) {
      // 左侧区域 - 上一页
      _flipToPreviousPage();
    } else if (tapX > screenWidth * 2 / 3) {
      // 右侧区域 - 下一页
      _flipToNextPage();
    } else {
      // 中间区域 - 触发菜单（通过回调）
      widget.onTap?.call();
    }
  }

  /// 翻到上一页
  void _flipToPreviousPage() {
    if (_currentPage > 0) {
      setState(() {
        _isAnimating = true;
        _nextPage = _currentPage - 1;
        _isForwardFlip = false;
      });
      _flipController.forward();
    }
  }

  /// 翻到下一页
  void _flipToNextPage() {
    if (_currentPage < widget.pages.length - 1) {
      setState(() {
        _isAnimating = true;
        _nextPage = _currentPage + 1;
        _isForwardFlip = true;
      });
      _flipController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: _handleTapUp, // 添加点击处理
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Stack(
        children: [
          // 背景页（下一页）
          if (_isAnimating || _flipController.value > 0)
            _buildPageContent(_nextPage, isBackground: true),

          // 前景页（当前页）带翻页动画
          AnimatedBuilder(
            animation: _flipController,
            builder: (context, child) {
              // 修正方向：向左滑（下一页）时从右边翻过来，向右滑（上一页）时从左边翻过来
              final rotationY = _isForwardFlip
                  ? _flipAnimation.value * 3.14159 * 0.5 // 向左滑：正向旋转
                  : -_flipAnimation.value * 3.14159 * 0.5; // 向右滑：反向旋转

              return Transform(
                alignment: _isForwardFlip
                    ? Alignment.centerLeft // 向左滑：从左边旋转
                    : Alignment.centerRight, // 向右滑：从右边旋转
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002) // 透视效果
                  ..rotateY(rotationY)
                  ..scale(_scaleAnimation.value),
                child: _buildPageContent(_currentPage),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 构建页面内容
  Widget _buildPageContent(int pageIndex, {bool isBackground = false}) {
    if (pageIndex < 0 || pageIndex >= widget.pages.length) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Consumer(
        builder: (context, ref, child) {
          // 实时监听设置变化，确保背景色和文字颜色立即更新
          final currentSettings = ref.watch(readerSettingsProvider);
          final ttsState = ref.watch(readerTtsProvider);
          final paginationState = ref.watch(readerPaginationProvider);

          return Container(
            decoration: BoxDecoration(
              color: currentSettings.backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isBackground ? 0.05 : _shadowAnimation.value,
                  ),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              padding: currentSettings.padding,
              alignment: Alignment.topLeft,
              child: _HighlightedText(
                text: widget.pages[pageIndex],
                style: currentSettings.textStyle,
                highlightedSentenceIndex: pageIndex == _currentPage
                    ? ttsState.highlightedSentenceIndex
                    : null,
                enableSelection:
                    !isBackground && currentSettings.enableTextSelection,
                onTextSelection: !isBackground ? widget.onTextSelection : null,
                maxLines: paginationState.maxLinesPerPage,
              ),
            ),
          );
        },
      ),
    );
  }

  /// 跳转到指定页面
  void goToPage(int pageIndex) {
    if (pageIndex >= 0 &&
        pageIndex < widget.pages.length &&
        !_isAnimating &&
        pageIndex != _currentPage) {
      setState(() {
        _isAnimating = true;
        _nextPage = pageIndex;
        _isForwardFlip = pageIndex > _currentPage;
      });
      _flipController.forward();
    }
  }
}

/// 阅读器工具栏 - Riverpod版本（简化实现）
class _ReaderToolbar extends ConsumerWidget {
  final _ToolbarPosition position;
  final VoidCallback? onInteraction;

  const _ReaderToolbar({required this.position, this.onInteraction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);

    // 使用 GestureDetector 阻止点击事件穿透到下层
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // 阻止事件穿透
      onTap: () {
        // 吸收点击事件，不做任何操作
      },
      onTapDown: (_) {
        // 吸收按下事件
      },
      onTapUp: (_) {
        // 🔧 修复：吸收TapUp事件，防止穿透到下层触发翻页
        // 因为翻页手势使用的是onTapUp，必须在这里阻止
      },
      child: Container(
        decoration: _buildToolbarDecoration(settings),
        child: SafeArea(
          top: position == _ToolbarPosition.top,
          bottom: position == _ToolbarPosition.bottom,
          child: position == _ToolbarPosition.top
              ? _buildTopToolbar(context, ref, settings)
              : _buildBottomToolbar(context, ref, settings),
        ),
      ),
    );
  }

  BoxDecoration _buildToolbarDecoration(ReaderSettings settings) {
    return BoxDecoration(
      color: _getToolbarBackgroundColor(settings),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: position == _ToolbarPosition.top
              ? const Offset(0, 2)
              : const Offset(0, -2),
        ),
      ],
    );
  }

  Color _getToolbarBackgroundColor(ReaderSettings settings) {
    switch (settings.theme) {
      case ReadingTheme.day:
        return const Color(0xFFF8F8F8);
      case ReadingTheme.night:
        return const Color(0xFF2A2A2A);
      case ReadingTheme.eyeCare:
        return const Color(0xFFB8E5BE); // 护眼绿色，与阅读背景协调
      case ReadingTheme.warmPaper:
        return const Color(0xFFFFF8DC);
      case ReadingTheme.coolGray:
        return const Color(0xFFE8E8E8);
      case ReadingTheme.sepia:
        return const Color(0xFFF5E6D3);
      case ReadingTheme.pureBlack:
        return const Color(0xFF000000);
      case ReadingTheme.blueLight:
        return const Color(0xFFE8F4F8);
    }
  }

  Widget _buildTopToolbar(
    BuildContext context,
    WidgetRef ref,
    ReaderSettings settings,
  ) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            settings: settings,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                // 从祖先 widget 获取书名
                final readerPageState =
                    context.findAncestorStateOfType<_ReaderPageState>();
                final bookTitle = readerPageState?.widget.bookTitle;

                // 只有当书名不为空时才显示
                if (bookTitle == null || bookTitle.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Text(
                  bookTitle,
                  style: settings.textStyle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          _buildIconButton(
            icon: Icons.bookmark_border_rounded,
            onPressed: () {
              HapticFeedback.mediumImpact();
              _handleBookmark(context, ref);
            },
            settings: settings,
          ),
          const SizedBox(width: 8),
          _buildIconButton(
            icon: Icons.list_rounded,
            onPressed: () {
              HapticFeedback.lightImpact();
              _showTableOfContents(context, ref);
            },
            settings: settings,
          ),
          const SizedBox(width: 8),
          _buildIconButton(
            icon: Icons.more_vert_rounded,
            onPressed: () {
              HapticFeedback.lightImpact();
              _showMoreMenu(context, ref, settings);
            },
            settings: settings,
          ),
        ],
      ),
    );
  }

  void _handleBookmark(BuildContext context, WidgetRef ref) {
    // TODO: Implement bookmark functionality
    _showSideToast(context, '书签功能');
  }

  Future<void> _showTableOfContents(BuildContext context, WidgetRef ref) async {
    final paginationState = ref.read(readerPaginationProvider);
    final content = paginationState.cachedText ?? '';

    if (paginationState.pages.isEmpty || content.isEmpty) {
      _showSideToast(context, '暂无可用目录');
      return;
    }

    final markers = _extractChapterMarkers(content);
    final chapters = _buildChapterHierarchy(
      markers: markers,
      pageCharOffsets: paginationState.pageCharOffsets ?? const [],
      pages: paginationState.pages,
    );

    if (chapters.isEmpty) {
      _showSideToast(context, '未识别到目录');
      return;
    }

    final readerPageState =
        context.findAncestorStateOfType<_ReaderPageState>();
    final bookId = readerPageState?.widget.bookId;
    List<Bookmark> bookmarks = [];

    if (bookId != null) {
      try {
        bookmarks = await BookmarkDao().getBookmarksForBook(bookId);
      } catch (e) {
        debugPrint('❌ 加载书签失败: $e');
      }
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (dialogContext) {
        return TocWidget(
          chapters: chapters,
          bookmarks: bookmarks,
          currentPageIndex: paginationState.currentPageIndex,
          onPageTap: (pageIndex) {
            Navigator.of(dialogContext).pop();
            ref.read(readerPaginationProvider.notifier).goToPage(pageIndex);
          },
          onBookmarkTap: (bookmark) {
            Navigator.of(dialogContext).pop();
            ref
                .read(readerPaginationProvider.notifier)
                .goToPage(bookmark.pageNumber - 1);
          },
        );
      },
    );
  }

  /// 处理分享功能
  void _handleShare(BuildContext context, WidgetRef ref) {
    final paginationState = ref.read(readerPaginationProvider);
    final currentPageContent = paginationState.currentPageContent ?? '';

    _showSideToast(context, '分享当前页面内容 (${currentPageContent.length}字)');
  }

  /// 显示主题选择器
  void _showThemeSelector(
    BuildContext context,
    WidgetRef ref,
    ReaderSettings settings,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, child) {
          // 在弹窗内部监听最新的设置
          final currentSettings = ref.watch(readerSettingsProvider);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: _getToolbarBackgroundColor(currentSettings),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 拖动指示器
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: currentSettings.textStyle.color?.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 标题
                    Text(
                      '阅读主题',
                      style: currentSettings.textStyle.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 主题网格 - 使用SizedBox固定高度，避免主题切换时高度变化导致晃动
                    SizedBox(
                      height: 320, // 固定高度：增加高度让网格更舒适
                      child: GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.2,
                        physics: const NeverScrollableScrollPhysics(),
                        children: ReadingTheme.values.map((theme) {
                          final isSelected = currentSettings.theme == theme;
                          return _buildThemeCard(
                            theme,
                            isSelected,
                            dialogContext,
                            ref,
                            currentSettings,
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建主题卡片
  Widget _buildThemeCard(
    ReadingTheme theme,
    bool isSelected,
    BuildContext context,
    WidgetRef ref,
    ReaderSettings currentSettings,
  ) {
    // 创建临时设置以获取主题颜色
    final themeSettings = currentSettings.copyWith(theme: theme);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        // 切换主题，但不关闭弹窗，让用户实时看到效果
        ref.read(readerSettingsProvider.notifier).switchTheme(theme);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: themeSettings.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? currentSettings.textStyle.color?.withValues(alpha: 0.5) ??
                    Colors.grey
                : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 主题预览
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getThemeIcon(theme),
                    size: 28,
                    color: themeSettings.textStyle.color,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    themeSettings.themeName,
                    style: themeSettings.textStyle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // 选中标识
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: currentSettings.textStyle.color?.withValues(
                      alpha: 0.15,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 16,
                    color: currentSettings.textStyle.color,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 显示排版设置面板
  void _showTypographyPanel(
    BuildContext context,
    WidgetRef ref,
    ReaderSettings settings,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: _getToolbarBackgroundColor(settings),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Consumer(
                builder: (context, ref, child) {
                  final settings = ref.watch(readerSettingsProvider);
                  return ListView(
                    controller: scrollController,
                    children: [
                      // 拖动指示器
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: settings.textStyle.color?.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 标题
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '排版设置',
                            style: settings.textStyle.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: settings.textStyle.color?.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 字体大小滑块
                      _buildSliderSetting(
                        label: '字体大小',
                        value: settings.fontSize,
                        min: 12.0,
                        max: 36.0,
                        divisions: 24,
                        displayValue: '${settings.fontSize.toInt()}',
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          ref
                              .read(readerSettingsProvider.notifier)
                              .updateFontSize(value);
                        },
                        settings: settings,
                      ),
                      const SizedBox(height: 24),

                      // 行距滑块
                      _buildSliderSetting(
                        label: '行距',
                        value: settings.lineSpacing,
                        min: 1.0,
                        max: 3.0,
                        divisions: 20,
                        displayValue: settings.lineSpacing.toStringAsFixed(1),
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          ref
                              .read(readerSettingsProvider.notifier)
                              .updateLineSpacing(value);
                        },
                        settings: settings,
                      ),
                      const SizedBox(height: 24),

                      // 字间距滑块
                      _buildSliderSetting(
                        label: '字间距',
                        value: settings.letterSpacing,
                        min: -0.5,
                        max: 2.0,
                        divisions: 25,
                        displayValue: settings.letterSpacing.toStringAsFixed(1),
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          ref
                              .read(readerSettingsProvider.notifier)
                              .updateLetterSpacing(value);
                        },
                        settings: settings,
                      ),
                      const SizedBox(height: 24),

                      // 首行缩进滑块
                      _buildSliderSetting(
                        label: '首行缩进',
                        value: settings.firstLineIndent,
                        min: 0.0,
                        max: 4.0,
                        divisions: 8,
                        displayValue:
                            '${settings.firstLineIndent.toStringAsFixed(1)}字符',
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          ref
                              .read(readerSettingsProvider.notifier)
                              .updateFirstLineIndent(value);
                        },
                        settings: settings,
                      ),
                      const SizedBox(height: 24),

                      // 页边距滑块
                      _buildSliderSetting(
                        label: '页边距',
                        value: settings.horizontalMargin,
                        min: 10.0,
                        max: 40.0,
                        divisions: 30,
                        displayValue: '${settings.horizontalMargin.toInt()}px',
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          ref
                              .read(readerSettingsProvider.notifier)
                              .updateHorizontalMargin(value);
                        },
                        settings: settings,
                      ),
                      const SizedBox(height: 24),

                      // 重置按钮
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(readerSettingsProvider.notifier)
                                .updateFontSize(18.0);
                            ref
                                .read(readerSettingsProvider.notifier)
                                .updateLineSpacing(1.8);
                            ref
                                .read(readerSettingsProvider.notifier)
                                .updateLetterSpacing(0.2);
                            ref
                                .read(readerSettingsProvider.notifier)
                                .updateFirstLineIndent(2.0);
                            ref
                                .read(readerSettingsProvider.notifier)
                                .updateHorizontalMargin(20.0);
                          },
                          icon: Icon(
                            Icons.refresh,
                            color: settings.textStyle.color?.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          label: Text(
                            '恢复默认',
                            style: settings.textStyle.copyWith(fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建滑块设置项
  Widget _buildSliderSetting({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
    required ReaderSettings settings,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: settings.textStyle.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: settings.textStyle.color?.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                displayValue,
                style: settings.textStyle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: settings.textStyle.color?.withValues(alpha: 0.7),
            inactiveTrackColor: settings.textStyle.color?.withValues(
              alpha: 0.15,
            ),
            thumbColor: settings.textStyle.color,
            overlayColor: settings.textStyle.color?.withValues(alpha: 0.2),
            trackHeight: 4.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _showMoreMenu(
    BuildContext context,
    WidgetRef ref,
    ReaderSettings settings,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _getToolbarBackgroundColor(settings),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: settings.textStyle.color?.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              _buildMoreMenuItem(context, Icons.search_rounded, '搜索', settings),
              _buildMoreMenuItem(context, Icons.share_rounded, '分享', settings),
              _buildMoreMenuItem(
                context,
                Icons.touch_app_rounded,
                '翻页方式',
                settings,
                onTap: () {
                  Navigator.pop(context);
                  _showPageTurningSettings(context, ref, settings);
                },
              ),
              _buildMoreMenuItem(
                context,
                Icons.settings_rounded,
                '设置',
                settings,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreMenuItem(
    BuildContext context,
    IconData icon,
    String label,
    ReaderSettings settings, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ??
          () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
            _showSideToast(context, label);
          },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: settings.textStyle.color?.withValues(alpha: 0.8)),
            const SizedBox(width: 16),
            Text(label, style: settings.textStyle.copyWith(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomToolbar(
    BuildContext context,
    WidgetRef ref,
    ReaderSettings settings,
  ) {
    final paginationState = ref.watch(readerPaginationProvider);
    final currentPage = paginationState.currentPageIndex + 1;
    final totalPages = paginationState.totalPages;

    // 📊 支持估算页码显示："约850" 或 "856"
    final totalPagesText =
        paginationState.isEstimated == true ? '约$totalPages' : '$totalPages';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一行：进度滑块
          Row(
            children: [
              Text(
                '$currentPage',
                style: settings.textStyle.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Expanded(
                child: Slider(
                  value: totalPages > 0 ? currentPage / totalPages : 0,
                  onChanged: (value) {
                    onInteraction?.call();
                    HapticFeedback.selectionClick();
                    final targetPage = (value * totalPages).round().clamp(
                          1,
                          totalPages,
                        );
                    ref
                        .read(readerPaginationProvider.notifier)
                        .goToPage(targetPage - 1);
                  },
                  activeColor: settings.textStyle.color?.withValues(alpha: 0.8),
                  inactiveColor: settings.textStyle.color?.withValues(
                    alpha: 0.2,
                  ),
                ),
              ),
              Text(
                totalPagesText,
                style: settings.textStyle.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 第二行：新的控制按钮组（使用Flexible防止溢出）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Flexible(
                child: _buildToolbarButton(
                  icon: Icons.list_rounded,
                  label: '目录',
                  onTap: () {
                    onInteraction?.call();
                    HapticFeedback.lightImpact();
                    _showTableOfContents(context, ref);
                  },
                  settings: settings,
                ),
              ),
              Flexible(
                child: _buildToolbarButton(
                  icon: Icons.palette_rounded,
                  label: '主题',
                  onTap: () {
                    onInteraction?.call();
                    HapticFeedback.lightImpact();
                    _showThemeSelector(context, ref, settings);
                  },
                  settings: settings,
                ),
              ),
              Flexible(child: _buildTtsButton(context, ref, settings)),
              Flexible(
                child: _buildToolbarButton(
                  icon: Icons.format_size_rounded,
                  label: '排版',
                  onTap: () {
                    onInteraction?.call();
                    HapticFeedback.lightImpact();
                    _showTypographyPanel(context, ref, settings);
                  },
                  settings: settings,
                ),
              ),
              Flexible(
                child: _buildToolbarButton(
                  icon: Icons.share_rounded,
                  label: '分享',
                  onTap: () {
                    onInteraction?.call();
                    HapticFeedback.lightImpact();
                    _handleShare(context, ref);
                  },
                  settings: settings,
                ),
              ),
              Flexible(
                child: _buildToolbarButton(
                  icon: Icons.settings_rounded,
                  label: '设置',
                  onTap: () {
                    onInteraction?.call();
                    HapticFeedback.lightImpact();
                    _showMoreMenu(context, ref, settings);
                  },
                  settings: settings,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建工具栏按钮
  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ReaderSettings settings,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // 阻止事件穿透
      onTap: onTap,
      onTapUp: (_) {
        // 🔧 修复：阻止TapUp事件穿透到下层触发翻页
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: settings.textStyle.color?.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
                color: settings.textStyle.color?.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: settings.textStyle.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: settings.textStyle.color?.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建TTS按钮（带状态）
  Widget _buildTtsButton(
    BuildContext context,
    WidgetRef ref,
    ReaderSettings settings,
  ) {
    final ttsState = ref.watch(readerTtsProvider);
    final isPlaying = ttsState.isPlaying;

    return GestureDetector(
      behavior: HitTestBehavior.opaque, // 阻止事件穿透
      onTap: () {
        onInteraction?.call();
        HapticFeedback.lightImpact();
        _toggleTts(context, ref);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPlaying
                    ? settings.textStyle.color?.withValues(alpha: 0.15)
                    : settings.textStyle.color?.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 22,
                color: settings.textStyle.color?.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '朗读',
              style: settings.textStyle.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: settings.textStyle.color?.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required ReaderSettings settings,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // 阻止事件穿透
      onTap: () {
        onInteraction?.call();
        onPressed();
      },
      onTapUp: (_) {
        // 🔧 修复：阻止TapUp事件穿透到下层触发翻页
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: settings.textStyle.color?.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 20,
          color: settings.textStyle.color?.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  void _toggleTts(BuildContext context, WidgetRef ref) {
    // 显示 TTS 设置面板
    showTtsSettingsSheet(context);
  }

  /// 显示翻页方式设置
  void _showPageTurningSettings(
    BuildContext context,
    WidgetRef ref,
    ReaderSettings settings,
  ) {
    showPageTurningSettingsSheet(context);
  }

  IconData _getThemeIcon(ReadingTheme theme) {
    switch (theme) {
      case ReadingTheme.day:
        return Icons.wb_sunny;
      case ReadingTheme.night:
        return Icons.nights_stay;
      case ReadingTheme.eyeCare:
        return Icons.eco;
      case ReadingTheme.warmPaper:
        return Icons.article_outlined;
      case ReadingTheme.coolGray:
        return Icons.ac_unit_outlined;
      case ReadingTheme.sepia:
        return Icons.auto_stories_outlined;
      case ReadingTheme.pureBlack:
        return Icons.brightness_1;
      case ReadingTheme.blueLight:
        return Icons.wb_twilight;
    }
  }
}

/// 加载点动画组件
///
/// 显示三个跳动的点，营造流畅的加载感
class _LoadingDots extends StatefulWidget {
  final Color? color;

  const _LoadingDots({this.color});

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final value = (_controller.value + delay) % 1.0;
            final scale = 0.5 + (0.5 * (1 - (2 * value - 1).abs()));
            final opacity = 0.3 + (0.7 * scale);

            return Transform.scale(
              scale: scale,
              child: Opacity(opacity: opacity, child: child),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.color?.withValues(alpha: 0.6) ?? Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}
