import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 增强的文字选择工具栏
class EnhancedTextSelectionToolbar extends StatefulWidget {
  final String selectedText;
  final int bookId;
  final int pageNumber;
  final String chapterTitle;
  final VoidCallback? onCopy;
  final VoidCallback? onHighlight;
  final VoidCallback? onNote;
  final VoidCallback? onShare;
  final VoidCallback? onClose;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? textColor;

  const EnhancedTextSelectionToolbar({
    super.key,
    required this.selectedText,
    required this.bookId,
    required this.pageNumber,
    required this.chapterTitle,
    this.onCopy,
    this.onHighlight,
    this.onNote,
    this.onShare,
    this.onClose,
    this.backgroundColor,
    this.iconColor,
    this.textColor,
  });

  @override
  State<EnhancedTextSelectionToolbar> createState() =>
      _EnhancedTextSelectionToolbarState();
}

class _EnhancedTextSelectionToolbarState
    extends State<EnhancedTextSelectionToolbar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
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

  void _handleCopy() {
    Clipboard.setData(ClipboardData(text: widget.selectedText));
    _showFeedback('已复制到剪贴板');
    widget.onCopy?.call();
    _close();
  }

  void _handleHighlight() {
    widget.onHighlight?.call();
    _showFeedback('已添加高亮');
    _close();
  }

  void _handleNote() {
    widget.onNote?.call();
    // 不关闭工具栏，让用户输入笔记
  }

  void _handleShare() {
    final shareText =
        '''📖 阅读摘录

"${widget.selectedText}"

——${widget.chapterTitle}
📍 第${widget.pageNumber}页

#读书笔记 #文字摘录''';

    Clipboard.setData(ClipboardData(text: shareText));
    _showFeedback('摘录已复制，可分享到其他平台');
    widget.onShare?.call();
    _close();
  }

  void _showFeedback(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              widget.backgroundColor?.withValues(alpha: 0.9) ??
              Theme.of(context).primaryColor.withValues(alpha: 0.9),
        ),
      );
    }
  }

  void _close() {
    _animationController.reverse().then((_) {
      widget.onClose?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor =
        widget.backgroundColor ??
        theme.colorScheme.surface.withValues(alpha: 0.95);
    final iconColor = widget.iconColor ?? theme.colorScheme.primary;
    final textColor = widget.textColor ?? theme.colorScheme.onSurface;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToolbarButton(
                      icon: Icons.content_copy_rounded,
                      label: '复制',
                      onTap: _handleCopy,
                      iconColor: iconColor,
                      textColor: textColor,
                    ),
                    _buildDivider(iconColor),
                    _buildToolbarButton(
                      icon: Icons.highlight_alt_rounded,
                      label: '高亮',
                      onTap: _handleHighlight,
                      iconColor: iconColor,
                      textColor: textColor,
                    ),
                    _buildDivider(iconColor),
                    _buildToolbarButton(
                      icon: Icons.note_add_rounded,
                      label: '笔记',
                      onTap: _handleNote,
                      iconColor: iconColor,
                      textColor: textColor,
                    ),
                    _buildDivider(iconColor),
                    _buildToolbarButton(
                      icon: Icons.share_rounded,
                      label: '分享',
                      onTap: _handleShare,
                      iconColor: iconColor,
                      textColor: textColor,
                    ),
                    _buildDivider(iconColor),
                    _buildToolbarButton(
                      icon: Icons.close_rounded,
                      label: '关闭',
                      onTap: _close,
                      iconColor: iconColor.withValues(alpha: 0.7),
                      textColor: textColor.withValues(alpha: 0.7),
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

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color iconColor,
    required Color textColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: color.withValues(alpha: 0.2),
    );
  }
}

