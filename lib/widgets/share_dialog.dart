import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/share_service.dart';
import '../utils/theme_mixin.dart';

/// 分享对话框
/// 提供优雅的分享选项界面，保持应用的毛玻璃主题风格
class ShareDialog extends StatefulWidget {
  final String bookTitle;
  final String? author;
  final String? currentPageContent;
  final String? selectedText;
  final int? currentPage;
  final int? totalPages;
  final double? progressPercentage;
  final Duration? readingTime;

  const ShareDialog({
    super.key,
    required this.bookTitle,
    this.author,
    this.currentPageContent,
    this.selectedText,
    this.currentPage,
    this.totalPages,
    this.progressPercentage,
    this.readingTime,
  });

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog>
    with ThemeMixin, TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // 启动动画
    _scaleController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _scaleController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                margin: const EdgeInsets.all(24),
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withValues(alpha: 0.9),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(context),
                        _buildShareOptions(context),
                        _buildActions(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: getAccentColor(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.share_rounded,
              color: getAccentColor(context),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '分享内容',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: getTextColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '《${widget.bookTitle}》',
                  style: TextStyle(
                    fontSize: 14,
                    color: getTextColor(context).withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareOptions(BuildContext context) {
    return Consumer<ShareService>(
      builder: (context, shareService, child) {
        final options = shareService.getShareOptions();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: options
                .map(
                  (option) => _buildShareOption(
                    context: context,
                    option: option,
                    shareService: shareService,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildShareOption({
    required BuildContext context,
    required ShareOption option,
    required ShareService shareService,
  }) {
    final isEnabled = _isOptionEnabled(option.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled
              ? () => _handleShare(context, option.type, shareService)
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isEnabled
                  ? getTextColor(context).withValues(alpha: 0.05)
                  : getTextColor(context).withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEnabled
                    ? getTextColor(context).withValues(alpha: 0.1)
                    : getTextColor(context).withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? getAccentColor(context).withValues(alpha: 0.1)
                        : getTextColor(context).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      option.icon,
                      style: TextStyle(
                        fontSize: 20,
                        color: isEnabled
                            ? getAccentColor(context)
                            : getTextColor(context).withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isEnabled
                              ? getTextColor(context)
                              : getTextColor(context).withValues(alpha: 0.3),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: isEnabled
                              ? getTextColor(context).withValues(alpha: 0.7)
                              : getTextColor(context).withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isEnabled)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: getTextColor(context).withValues(alpha: 0.3),
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _close,
            style: TextButton.styleFrom(
              foregroundColor: getTextColor(context).withValues(alpha: 0.7),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  bool _isOptionEnabled(ShareType type) {
    switch (type) {
      case ShareType.currentPage:
        return widget.currentPageContent != null;
      case ShareType.selectedText:
        return widget.selectedText != null;
      case ShareType.progress:
        return widget.progressPercentage != null &&
            widget.currentPage != null &&
            widget.totalPages != null;
      case ShareType.recommendation:
        return true; // 书籍推荐总是可用
      case ShareType.note:
        return false; // TODO: 实现笔记功能后启用
      case ShareType.statistics:
        return false; // TODO: 实现统计功能后启用
    }
  }

  Future<void> _handleShare(
    BuildContext context,
    ShareType type,
    ShareService shareService,
  ) async {
    await _close();

    switch (type) {
      case ShareType.currentPage:
        if (widget.currentPageContent != null &&
            widget.currentPage != null &&
            widget.totalPages != null) {
          await shareService.shareCurrentPage(
            bookTitle: widget.bookTitle,
            content: widget.currentPageContent!,
            currentPage: widget.currentPage!,
            totalPages: widget.totalPages!,
          );
        }
        break;

      case ShareType.selectedText:
        if (widget.selectedText != null) {
          await shareService.shareSelectedText(
            bookTitle: widget.bookTitle,
            selectedText: widget.selectedText!,
            author: widget.author ?? '未知作者',
          );
        }
        break;

      case ShareType.progress:
        if (widget.progressPercentage != null &&
            widget.currentPage != null &&
            widget.totalPages != null) {
          await shareService.shareReadingProgress(
            bookTitle: widget.bookTitle,
            author: widget.author ?? '未知作者',
            progressPercentage: widget.progressPercentage!,
            currentPage: widget.currentPage!,
            totalPages: widget.totalPages!,
            readingTime: widget.readingTime ?? Duration.zero,
          );
        }
        break;

      case ShareType.recommendation:
        await shareService.shareBookRecommendation(
          bookTitle: widget.bookTitle,
          author: widget.author ?? '未知作者',
          description: '这是一本值得推荐的好书，内容精彩，值得一读！',
          rating: 5.0,
        );
        break;

      case ShareType.note:
      case ShareType.statistics:
        // TODO: 实现笔记和统计分享功能
        break;
    }
  }
}

/// 显示分享对话框的便捷函数
Future<void> showShareDialog({
  required BuildContext context,
  required String bookTitle,
  String? author,
  String? currentPageContent,
  String? selectedText,
  int? currentPage,
  int? totalPages,
  double? progressPercentage,
  Duration? readingTime,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (context) => ShareDialog(
      bookTitle: bookTitle,
      author: author,
      currentPageContent: currentPageContent,
      selectedText: selectedText,
      currentPage: currentPage,
      totalPages: totalPages,
      progressPercentage: progressPercentage,
      readingTime: readingTime,
    ),
  );
}
