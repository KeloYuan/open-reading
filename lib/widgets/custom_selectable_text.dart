import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/highlight.dart';
import 'highlight_color_picker.dart';

/// 自定义可选择文本组件，支持高亮和笔记功能
class CustomSelectableText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final List<Highlight> highlights;
  final Function(String selectedText, int startOffset, int endOffset)?
  onTextSelected;
  final Function(Highlight)? onHighlightTap;
  final TextAlign textAlign;

  const CustomSelectableText({
    super.key,
    required this.text,
    required this.style,
    this.highlights = const [],
    this.onTextSelected,
    this.onHighlightTap,
    this.textAlign = TextAlign.justify,
  });

  @override
  State<CustomSelectableText> createState() => _CustomSelectableTextState();
}

class _CustomSelectableTextState extends State<CustomSelectableText> {
  final FocusNode _focusNode = FocusNode();
  // TextSelection? _currentSelection; // TODO: 待实现
  OverlayEntry? _selectionToolbarOverlay;

  @override
  void dispose() {
    _focusNode.dispose();
    _hideSelectionToolbar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      child: SelectableText.rich(
        _buildTextSpan(),
        textAlign: widget.textAlign,
        showCursor: false,
        enableInteractiveSelection: true,
        contextMenuBuilder: _buildCustomContextMenu,
        onSelectionChanged: _onSelectionChanged,
        style: widget.style,
      ),
    );
  }

  /// 构建带高亮的文本片段
  TextSpan _buildTextSpan() {
    if (widget.highlights.isEmpty) {
      return TextSpan(text: widget.text, style: widget.style);
    }

    // 按开始位置排序高亮
    final sortedHighlights = [...widget.highlights]
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

    final textSpans = <InlineSpan>[];
    int currentOffset = 0;

    for (final highlight in sortedHighlights) {
      // 添加高亮前的普通文本
      if (currentOffset < highlight.startOffset) {
        final normalText = widget.text.substring(
          currentOffset,
          highlight.startOffset,
        );
        if (normalText.isNotEmpty) {
          textSpans.add(TextSpan(text: normalText, style: widget.style));
        }
      }

      // 添加高亮文本
      final highlightText = widget.text.substring(
        highlight.startOffset,
        highlight.endOffset,
      );

      textSpans.add(
        WidgetSpan(
          child: GestureDetector(
            onTap: () => widget.onHighlightTap?.call(highlight),
            child: Container(
              decoration: BoxDecoration(
                color: highlight.color.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                highlightText,
                style: widget.style.copyWith(
                  backgroundColor: Colors.transparent,
                  decoration: null, // 简化处理，不显示下划线
                  decorationColor: highlight.color,
                  decorationThickness: 2,
                ),
              ),
            ),
          ),
        ),
      );

      currentOffset = highlight.endOffset;
    }

    // 添加最后的普通文本
    if (currentOffset < widget.text.length) {
      final remainingText = widget.text.substring(currentOffset);
      if (remainingText.isNotEmpty) {
        textSpans.add(TextSpan(text: remainingText, style: widget.style));
      }
    }

    return TextSpan(style: widget.style, children: textSpans);
  }

  /// 处理选择变化
  void _onSelectionChanged(
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    // setState(() {
    //   _currentSelection = selection;
    // });

    if (selection.isCollapsed) {
      _hideSelectionToolbar();
    } else {
      _showSelectionToolbar(selection);
    }
  }

  /// 构建自定义上下文菜单
  Widget _buildCustomContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final selection = editableTextState.textEditingValue.selection;
    if (selection.isCollapsed) {
      return const SizedBox.shrink();
    }

    final selectedText = widget.text.substring(selection.start, selection.end);

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMenuButton(
              icon: Icons.content_copy,
              label: '复制',
              onTap: () => _copyText(selectedText),
            ),
            const SizedBox(width: 8),
            _buildMenuButton(
              icon: Icons.highlight_alt,
              label: '高亮',
              onTap: () => _highlightText(selectedText, selection),
            ),
            const SizedBox(width: 8),
            _buildMenuButton(
              icon: Icons.note_add,
              label: '笔记',
              onTap: () => _addNote(selectedText, selection),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建菜单按钮
  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  /// 显示选择工具栏
  void _showSelectionToolbar(TextSelection selection) {
    _hideSelectionToolbar();

    final selectedText = widget.text.substring(selection.start, selection.end);
    final overlay = Overlay.of(context);

    _selectionToolbarOverlay = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100,
        left: 20,
        right: 20,
        child: Center(
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildToolbarButton(
                    icon: Icons.content_copy,
                    label: '复制',
                    onTap: () => _copyText(selectedText),
                  ),
                  const SizedBox(width: 16),
                  _buildToolbarButton(
                    icon: Icons.highlight_alt,
                    label: '高亮',
                    onTap: () => _highlightText(selectedText, selection),
                  ),
                  const SizedBox(width: 16),
                  _buildToolbarButton(
                    icon: Icons.note_add,
                    label: '笔记',
                    onTap: () => _addNote(selectedText, selection),
                  ),
                  const SizedBox(width: 16),
                  _buildToolbarButton(
                    icon: Icons.close,
                    label: '关闭',
                    onTap: _hideSelectionToolbar,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_selectionToolbarOverlay!);
  }

  /// 构建工具栏按钮
  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  /// 隐藏选择工具栏
  void _hideSelectionToolbar() {
    _selectionToolbarOverlay?.remove();
    _selectionToolbarOverlay = null;
  }

  /// 复制文本
  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)),
    );
    _hideSelectionToolbar();
  }

  /// 高亮文本
  void _highlightText(String selectedText, TextSelection selection) async {
    final color = await showHighlightColorPicker(context: context);
    if (color != null) {
      widget.onTextSelected?.call(selectedText, selection.start, selection.end);
      _hideSelectionToolbar();
    }
  }

  /// 添加笔记
  void _addNote(String selectedText, TextSelection selection) {
    showDialog(
      context: context,
      builder: (context) {
        final noteController = TextEditingController();
        return AlertDialog(
          title: const Text('添加笔记'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选中文字：'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(selectedText),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: '笔记内容',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final noteText = noteController.text.trim();
                if (noteText.isNotEmpty) {
                  final color = await showHighlightColorPicker(
                    context: context,
                  );
                  if (color != null) {
                    // TODO: 传递笔记文本到回调
                    widget.onTextSelected?.call(
                      selectedText,
                      selection.start,
                      selection.end,
                    );
                  }
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    _hideSelectionToolbar();
  }
}
