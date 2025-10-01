import 'dart:ui';

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                margin: const EdgeInsets.all(24),
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDarkMode ? 0.4 : 0.15),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.grey[900]!.withValues(alpha: 0.85)
                            : Colors.white.withValues(alpha: 0.9),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(28),
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
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
      child: Column(
        children: [
          // 拖拽指示器
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: getTextColor(context).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          // 标题和图标
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      getAccentColor(context).withValues(alpha: 0.8),
                      getAccentColor(context),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: getAccentColor(context).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.share_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '分享内容',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: getTextColor(context),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '《${widget.bookTitle}》',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: getTextColor(context).withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.author != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.author!,
                        style: TextStyle(
                          fontSize: 13,
                          color: getTextColor(context).withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
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
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // 分割线
                Container(
                  height: 0.5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        getTextColor(context).withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                // 分享选项
                ...options.map(
                  (option) => _buildShareOption(
                    context: context,
                    option: option,
                    shareService: shareService,
                  ),
                ),
              ],
            ),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled
              ? () => _handleShare(context, option.type, shareService)
              : null,
          borderRadius: BorderRadius.circular(20),
          splashColor: getAccentColor(context).withValues(alpha: 0.1),
          highlightColor: getAccentColor(context).withValues(alpha: 0.05),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isEnabled
                  ? (isDarkMode
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.04))
                  : getTextColor(context).withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isEnabled
                    ? (isDarkMode
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08))
                    : getTextColor(context).withValues(alpha: 0.05),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: isEnabled
                        ? LinearGradient(
                            colors: [
                              getAccentColor(context).withValues(alpha: 0.1),
                              getAccentColor(context).withValues(alpha: 0.15),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: !isEnabled
                        ? getTextColor(context).withValues(alpha: 0.05)
                        : null,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isEnabled
                          ? getAccentColor(context).withValues(alpha: 0.2)
                          : getTextColor(context).withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      option.icon,
                      style: TextStyle(
                        fontSize: 22,
                        color: isEnabled
                            ? getAccentColor(context)
                            : getTextColor(context).withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: isEnabled
                              ? getTextColor(context)
                              : getTextColor(context).withValues(alpha: 0.3),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        option.description,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: isEnabled
                              ? getTextColor(context).withValues(alpha: 0.65)
                              : getTextColor(context).withValues(alpha: 0.3),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isEnabled) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: getAccentColor(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: getAccentColor(context),
                      size: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: getTextColor(context).withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _close,
                borderRadius: BorderRadius.circular(16),
                splashColor: getTextColor(context).withValues(alpha: 0.1),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: getTextColor(context).withValues(alpha: 0.7),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
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
