import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/highlight.dart';

/// 荧光笔颜色选择器
class HighlightColorPicker extends StatefulWidget {
  final Function(Color) onColorSelected;
  final Color? initialColor;
  final VoidCallback? onCancel;

  const HighlightColorPicker({
    super.key,
    required this.onColorSelected,
    this.initialColor,
    this.onCancel,
  });

  @override
  State<HighlightColorPicker> createState() => _HighlightColorPickerState();
}

class _HighlightColorPickerState extends State<HighlightColorPicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  Color? _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor ?? Highlight.highlightColors.first;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleColorSelection(Color color) {
    setState(() {
      _selectedColor = color;
    });

    // 添加触觉反馈
    HapticFeedback.lightImpact();

    // 延迟一点时间让用户看到选择效果
    Future.delayed(const Duration(milliseconds: 200), () {
      widget.onColorSelected(color);
      _close();
    });
  }

  void _close() {
    _animationController.reverse().then((_) {
      widget.onCancel?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(20),
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 25,
                      offset: const Offset(0, 12),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标题
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(
                              0.1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.palette_rounded,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '选择荧光笔颜色',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _close,
                          icon: Icon(
                            Icons.close_rounded,
                            color: theme.colorScheme.onSurface.withOpacity(
                              0.6,
                            ),
                          ),
                          iconSize: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 颜色选择网格
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: Highlight.highlightColors.length,
                      itemBuilder: (context, index) {
                        final color = Highlight.highlightColors[index];
                        final isSelected = _selectedColor == color;
                        final colorName = Highlight.getColorNameStatic(color);

                        return InkWell(
                          onTap: () => _handleColorSelection(color),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isSelected ? color : color.withOpacity(0.3),
                                width: isSelected ? 3 : 1.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 颜色圆圈
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withOpacity(0.4),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 8),
                                // 颜色名称
                                Text(
                                  colorName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? color.computeLuminance() > 0.5
                                            ? Colors.black87
                                            : theme.colorScheme.onSurface
                                        : theme.colorScheme.onSurface
                                            .withOpacity(0.8),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // 示例文本
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(
                            0.2,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '预览效果',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                                height: 1.5,
                              ),
                              children: [
                                const TextSpan(text: '这是一段示例文本，'),
                                TextSpan(
                                  text: '这部分将被高亮显示',
                                  style: TextStyle(
                                    backgroundColor:
                                        _selectedColor?.withOpacity(
                                      0.4,
                                    ),
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const TextSpan(text: '，展示荧光笔效果。'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 显示荧光笔颜色选择器的辅助函数
Future<Color?> showHighlightColorPicker({
  required BuildContext context,
  Color? initialColor,
}) async {
  Color? selectedColor;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (BuildContext context) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: HighlightColorPicker(
            initialColor: initialColor,
            onColorSelected: (color) {
              selectedColor = color;
              Navigator.of(context).pop();
            },
            onCancel: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      );
    },
  );

  return selectedColor;
}
