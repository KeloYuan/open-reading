part of 'reader_page.dart';

extension _ReaderToolbarActions on _ReaderToolbar {
  void _handleBookmark(BuildContext context, WidgetRef ref) {
    final readerPageState = context.findAncestorStateOfType<_ReaderPageState>();
    final bookId = readerPageState?.widget.bookId;
    if (bookId == null) {
      showSideToast(context, '当前书籍信息不可用');
      return;
    }

    final paginationState = ref.read(readerPaginationProvider);
    final pageNumber = paginationState.currentPageIndex + 1; // 书签页码使用 1-based
    final bookmarkDao = BookmarkDao();

    bookmarkDao.hasBookmarkOnPage(bookId, pageNumber).then((hasBookmark) async {
      if (hasBookmark) {
        await bookmarkDao.deleteBookmarkOnPage(bookId, pageNumber);
        if (context.mounted) {
          showSideToast(context, '已移除第 $pageNumber 页书签');
        }
      } else {
        await bookmarkDao.insertBookmark(
          Bookmark(
            bookId: bookId,
            pageNumber: pageNumber,
          ),
        );
        if (context.mounted) {
          showSideToast(context, '已添加第 $pageNumber 页书签');
        }
      }
    }).catchError((error) {
      if (context.mounted) {
        showSideToast(context, '书签操作失败: $error');
      }
    });
  }

  Future<void> _showTableOfContents(BuildContext context, WidgetRef ref) async {
    final paginationState = ref.read(readerPaginationProvider);
    final content = paginationState.cachedText ?? '';

    if (paginationState.pages.isEmpty || content.isEmpty) {
      showSideToast(context, '暂无可用目录');
      return;
    }

    final markers = _extractChapterMarkers(content);
    final chapters = _buildChapterHierarchy(
      markers: markers,
      pageCharOffsets: paginationState.pageCharOffsets ?? const [],
      pages: paginationState.pages,
    );

    if (chapters.isEmpty) {
      showSideToast(context, '未识别到目录');
      return;
    }

    final readerPageState = context.findAncestorStateOfType<_ReaderPageState>();
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

    showSideToast(context, '分享当前页面内容 (${currentPageContent.length}字)');
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
                  final l10n = context.l10n;
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
                            l10n.typographySettings,
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

                      // 字体选择
                      Text(
                        l10n.fontFamilyLabel,
                        style: settings.textStyle.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: FontCatalog.readerFonts.map((option) {
                          final isSelected =
                              settings.fontFamily == option.family;
                          final label = FontCatalog.labelFor(l10n, option);
                          return ChoiceChip(
                            label: Text(
                              label,
                              style: settings.textStyle.copyWith(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                fontFamily: option.family,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: settings.textStyle.color?.withValues(
                              alpha: 0.18,
                            ),
                            backgroundColor:
                                settings.textStyle.color?.withValues(
                              alpha: 0.08,
                            ),
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              ref
                                  .read(readerSettingsProvider.notifier)
                                  .updateFontFamily(option.family);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // 字体大小滑块
                      _buildSliderSetting(
                        label: l10n.fontSizeLabel,
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
                        label: l10n.lineSpacingLabel,
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
                        label: l10n.letterSpacingLabel,
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
                        label: l10n.firstLineIndentLabel,
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
                        label: l10n.pageMarginLabel,
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
                            ref
                                .read(readerSettingsProvider.notifier)
                                .updateFontFamily(null);
                          },
                          icon: Icon(
                            Icons.refresh,
                            color: settings.textStyle.color?.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          label: Text(
                            l10n.resetDefault,
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
              _buildMoreMenuItem(
                context,
                Icons.code_rounded,
                '编码',
                settings,
                onTap: () {
                  Navigator.pop(context);
                  _showEncodingSelector(context, ref);
                },
              ),
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

  Future<void> _showEncodingSelector(
      BuildContext context, WidgetRef ref) async {
    final readerPageState = context.findAncestorStateOfType<_ReaderPageState>();
    if (readerPageState == null) {
      showSideToast(context, '无法获取书籍信息');
      return;
    }

    final bookId = readerPageState.widget.bookId;
    if (bookId == null) {
      showSideToast(context, '无法获取书籍信息');
      return;
    }

    final book = await BookDao().getBookById(bookId);
    if (!context.mounted) return;
    if (book == null) {
      showSideToast(context, '未找到书籍信息');
      return;
    }

    if (book.format.toLowerCase() != 'txt') {
      showSideToast(context, '仅TXT支持手动编码');
      return;
    }

    final currentEncoding = EnhancedTxtImportService.normalizeEncoding(
      book.textEncoding,
    );

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        String? selectedEncoding = currentEncoding;
        const options = [
          {'label': '自动识别', 'value': 'auto'},
          {'label': 'GBK/GB2312/GB18030', 'value': 'gbk'},
          {'label': 'UTF-8', 'value': 'utf8'},
          {'label': 'UTF-16 LE', 'value': 'utf16le'},
          {'label': 'UTF-16 BE', 'value': 'utf16be'},
        ];
        return AlertDialog(
          title: const Text('选择TXT编码'),
          content: SizedBox(
            width: 320,
            child: RadioGroup<String>(
              groupValue: selectedEncoding,
              onChanged: (value) async {
                if (value == null) return;
                selectedEncoding = value;
                Navigator.of(dialogContext).pop();
                await readerPageState.reloadWithEncoding(value);
              },
              child: ListView(
                shrinkWrap: true,
                children: options
                    .map(
                      (option) => RadioListTile<String>(
                        value: option['value']!,
                        title: Text(option['label']!),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
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
            showSideToast(context, label);
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
}
