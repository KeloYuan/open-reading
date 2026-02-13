import 'dart:async';
import 'dart:math' as math;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:xxread/models/book.dart' as legacy;
import 'package:xxread/reader_core/data/reader_models.dart' as core;
import 'package:xxread/reader_core/paginator/page_plan.dart' hide Page;
import 'package:xxread/reader_core/parser/parser_models.dart';
import 'package:xxread/reader_core/reader_kernel_controller.dart';
import 'package:xxread/reader_core/renderer/reader_view.dart';
import 'package:xxread/reader_core/selection/reader_selection.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/utils/system_ui_helper.dart';

class ReaderKernelPage extends StatefulWidget {
  final legacy.Book book;

  const ReaderKernelPage({
    super.key,
    required this.book,
  });

  @override
  State<ReaderKernelPage> createState() => _ReaderKernelPageState();
}

class _ReaderKernelPageState extends State<ReaderKernelPage> {
  late final ReaderKernelController _controller;
  final _bookDao = BookDao();
  bool _chapterSwitching = false;
  bool _chromeVisible = true;
  Timer? _immersiveTimer;
  final List<_ReaderThemePreset> _themes = const [
    _ReaderThemePreset(
      name: '纸张',
      background: Color(0xFFF7F2E7),
      foreground: Color(0xFF2A241C),
    ),
    _ReaderThemePreset(
      name: '浅色',
      background: Color(0xFFF5F7FA),
      foreground: Color(0xFF1F2630),
    ),
    _ReaderThemePreset(
      name: '夜间',
      background: Color(0xFF171A1F),
      foreground: Color(0xFFE5E7EC),
    ),
  ];
  final Set<_BookmarkPoint> _bookmarks = <_BookmarkPoint>{};
  int _themeIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = ReaderKernelController();
    _applyReaderSystemUI(immersive: false);
    _scheduleAutoImmersive();
    _open();
  }

  Future<void> _open() async {
    final fallbackId = widget.book.filePath.hashCode.abs().toString();
    await _controller.openBook(
      bookId: (widget.book.id ?? fallbackId).toString(),
      title: widget.book.title,
      author: widget.book.author,
      filePath: widget.book.filePath,
      format: widget.book.format,
      textEncoding: widget.book.textEncoding,
    );
  }

  @override
  void dispose() {
    _immersiveTimer?.cancel();
    _applyHostSystemUI();
    _controller.dispose();
    super.dispose();
  }

  void _applyHostSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiHelper.overlayStyleForBrightness(brightness),
    );
  }

  void _applyReaderSystemUI({required bool immersive}) {
    final isDark =
        ThemeData.estimateBrightnessForColor(_activeTheme.background) ==
            Brightness.dark;
    final baseStyle =
        isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    SystemChrome.setSystemUIOverlayStyle(
      baseStyle.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
    SystemChrome.setEnabledSystemUIMode(
      immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  void _scheduleAutoImmersive() {
    _immersiveTimer?.cancel();
    if (!_chromeVisible) {
      return;
    }
    _immersiveTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) {
        return;
      }
      _setChromeVisible(false);
    });
  }

  void _setChromeVisible(bool visible) {
    if (_chromeVisible == visible) {
      if (visible) {
        _scheduleAutoImmersive();
      }
      return;
    }
    setState(() {
      _chromeVisible = visible;
    });
    _applyReaderSystemUI(immersive: !visible);
    if (visible) {
      _scheduleAutoImmersive();
    } else {
      _immersiveTimer?.cancel();
    }
  }

  void _handleReaderTapUp(TapUpDetails details, BoxConstraints constraints) {
    final x = details.localPosition.dx;
    final leftBoundary = constraints.maxWidth / 3;
    final rightBoundary = constraints.maxWidth * 2 / 3;
    if (x >= leftBoundary && x <= rightBoundary) {
      _setChromeVisible(!_chromeVisible);
      return;
    }
    if (x < leftBoundary) {
      _stepPageBackward();
    } else {
      _stepPageForward();
    }
    if (_chromeVisible) {
      _scheduleAutoImmersive();
    }
  }

  _ReaderThemePreset get _activeTheme => _themes[_themeIndex % _themes.length];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _activeTheme.background,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.loading && _controller.pagePlan == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_controller.error != null && _controller.pagePlan == null) {
            return Center(child: Text(_controller.error!));
          }

          final chapter = _controller.currentParsedChapter;
          final plan = _controller.pagePlan;
          if (chapter == null || plan == null) {
            return const Center(child: Text('暂无内容'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final media = MediaQuery.of(context);
              final isLandscape = constraints.maxWidth > constraints.maxHeight;
              final enableSpread = constraints.maxWidth >= 900 && isLandscape;
              final padding = EdgeInsets.fromLTRB(
                16,
                12 + media.padding.top,
                16,
                12 + media.padding.bottom,
              );

              WidgetsBinding.instance.addPostFrameCallback((_) {
                _controller.updateViewport(
                  viewport: Size(constraints.maxWidth, constraints.maxHeight),
                  padding: padding,
                  enableSpread: enableSpread,
                );
              });

              final reader = ReaderView(
                flowDoc: chapter.flowDoc,
                pagePlan: plan,
                chapterPlainText: chapter.chapter.content,
                chapterResources: chapter.resources,
                currentChapterTitle: chapter.chapter.title,
                pageBackgroundColor: _activeTheme.background,
                textColor: _activeTheme.foreground,
                style: _controller.style,
                layout: _controller.layout,
                annotations: _controller.annotations,
                initialPageIndex: _controller.pageIndex,
                onPageChanged: (index) {
                  _controller.setPageIndex(index);
                  if (_chromeVisible) {
                    _scheduleAutoImmersive();
                  }
                },
                onSelectionAction: (payload) =>
                    _onSelectionAction(context, payload),
                onReachChapterBoundary: _onBoundaryReached,
              );

              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) => _handleReaderTapUp(details, constraints),
                child: Stack(
                  children: [
                    Positioned.fill(child: reader),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _ReaderTopStatusOverlay(
                          foreground: _activeTheme.foreground,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _buildBottomReadingInfoOverlay(
                          chapter: chapter,
                          plan: plan,
                        ),
                      ),
                    ),
                    if (_chromeVisible) ...[
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _buildTopControlBar(),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 34,
                        child: _buildBottomToolbar(),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final parsedBook = _controller.parsedBook;
        if (parsedBook == null) {
          return const SizedBox.shrink();
        }
        final isBookmarked = _isCurrentPageBookmarked();
        final foreground = _activeTheme.foreground;

        return SafeArea(
          top: false,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              decoration: BoxDecoration(
                color: _activeTheme.background.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: foreground.withValues(alpha: 0.18),
                ),
              ),
              child: IconTheme(
                data: IconThemeData(color: foreground),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    IconButton(
                      tooltip: '目录',
                      icon: const Icon(Icons.toc),
                      onPressed: () => _showTocSheet(context),
                    ),
                    IconButton(
                      tooltip: '上一章',
                      icon: const Icon(Icons.keyboard_double_arrow_left),
                      onPressed: _controller.chapterIndex > 0
                          ? () => _jumpByDirection(
                                ChapterBoundaryDirection.previous,
                              )
                          : null,
                    ),
                    IconButton(
                      tooltip: isBookmarked ? '移除书签' : '添加书签',
                      icon: Icon(
                        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      ),
                      onPressed: _toggleBookmark,
                    ),
                    IconButton(
                      tooltip: '下一章',
                      icon: const Icon(Icons.keyboard_double_arrow_right),
                      onPressed: _controller.chapterIndex <
                              parsedBook.chapters.length - 1
                          ? () => _jumpByDirection(
                                ChapterBoundaryDirection.next,
                              )
                          : null,
                    ),
                    IconButton(
                      tooltip: '排版',
                      icon: const Icon(Icons.tune),
                      onPressed: () => _showTypographySheet(context),
                    ),
                    IconButton(
                      tooltip: '主题',
                      icon: const Icon(Icons.palette_outlined),
                      onPressed: _cycleTheme,
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

  Widget _buildTopControlBar() {
    return SafeArea(
      bottom: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 34, 10, 0),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _activeTheme.background.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _activeTheme.foreground.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: '返回',
              icon: Icon(
                Icons.arrow_back,
                color: _activeTheme.foreground,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Text(
                    _controller.parsedBook?.book.title ?? widget.book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _activeTheme.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
            IconButton(
              tooltip: '问AI（当前页）',
              icon: Icon(
                Icons.auto_awesome,
                color: _activeTheme.foreground,
              ),
              onPressed: () async {
                await _controller.analyzeCurrentPage();
                if (!mounted) return;
                _showAiSheetFromState(_controller.lastAiAnswer ?? 'AI 暂无回答');
                _scheduleAutoImmersive();
              },
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz, color: _activeTheme.foreground),
              onSelected: (value) {
                if (value.startsWith('enc:')) {
                  _switchEncoding(value.substring(4));
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'enc:auto', child: Text('编码：自动')),
                PopupMenuItem(value: 'enc:utf8', child: Text('编码：UTF-8')),
                PopupMenuItem(value: 'enc:gbk', child: Text('编码：GBK/GB2312')),
                PopupMenuItem(
                    value: 'enc:utf16le', child: Text('编码：UTF-16 LE')),
                PopupMenuItem(
                    value: 'enc:utf16be', child: Text('编码：UTF-16 BE')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomReadingInfoOverlay({
    required ParsedChapter chapter,
    required PagePlan plan,
  }) {
    final parsedBook = _controller.parsedBook;
    if (parsedBook == null) {
      return const SizedBox.shrink();
    }
    final toc = parsedBook.toc;
    final tocIndex =
        toc.indexWhere((item) => item.chapterId == chapter.chapter.id);
    final chapterNo =
        (tocIndex >= 0 ? tocIndex + 1 : _controller.chapterIndex + 1).clamp(1,
            math.max(1, toc.isEmpty ? parsedBook.chapters.length : toc.length));
    final chapterTotal =
        toc.isNotEmpty ? toc.length : parsedBook.chapters.length;
    final pageNo =
        (_controller.pageIndex + 1).clamp(1, math.max(1, plan.pages.length));
    final pageTotal = math.max(1, plan.pages.length);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _activeTheme.background.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '第 $chapterNo/$chapterTotal 章 · 第 $pageNo/$pageTotal 页',
              style: TextStyle(
                color: _activeTheme.foreground.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onBoundaryReached(ChapterBoundaryDirection direction) async {
    await _jumpByDirection(direction, triggeredByBoundary: true);
  }

  Future<void> _stepPageForward() async {
    final plan = _controller.pagePlan;
    if (plan == null || plan.pages.isEmpty) {
      return;
    }
    final next = _controller.pageIndex + 1;
    if (next < plan.pages.length) {
      await _controller.setPageIndex(next);
      return;
    }
    await _jumpByDirection(
      ChapterBoundaryDirection.next,
      triggeredByBoundary: true,
    );
  }

  Future<void> _stepPageBackward() async {
    final plan = _controller.pagePlan;
    if (plan == null || plan.pages.isEmpty) {
      return;
    }
    final previous = _controller.pageIndex - 1;
    if (previous >= 0) {
      await _controller.setPageIndex(previous);
      return;
    }
    await _jumpByDirection(
      ChapterBoundaryDirection.previous,
      triggeredByBoundary: true,
    );
  }

  Future<void> _jumpByDirection(
    ChapterBoundaryDirection direction, {
    bool triggeredByBoundary = false,
  }) async {
    if (_chapterSwitching) {
      return;
    }
    final parsedBook = _controller.parsedBook;
    if (parsedBook == null) {
      return;
    }
    final targetIndex = direction == ChapterBoundaryDirection.next
        ? _controller.chapterIndex + 1
        : _controller.chapterIndex - 1;
    if (targetIndex < 0 || targetIndex >= parsedBook.chapters.length) {
      return;
    }
    _chapterSwitching = true;
    try {
      if (triggeredByBoundary) {
        await Future<void>.delayed(const Duration(milliseconds: 280));
      }
      if (!mounted) {
        return;
      }
      final targetChapter = parsedBook.chapters[targetIndex].chapter;
      final anchorOffset = direction == ChapterBoundaryDirection.next
          ? 0
          : targetChapter.content.length;
      await _controller.jumpToChapter(targetIndex, anchorOffset: anchorOffset);
      if (direction == ChapterBoundaryDirection.next) {
        await _controller.setPageIndex(0);
      }
    } finally {
      _chapterSwitching = false;
    }
  }

  void _cycleTheme() {
    final next = (_themeIndex + 1) % _themes.length;
    setState(() {
      _themeIndex = next;
    });
    _applyReaderSystemUI(immersive: !_chromeVisible);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('主题：${_themes[next].name}')),
    );
    if (_chromeVisible) {
      _scheduleAutoImmersive();
    }
  }

  _BookmarkPoint? _currentBookmarkPoint() {
    final chapter = _controller.currentParsedChapter;
    final plan = _controller.pagePlan;
    if (chapter == null || plan == null || plan.pages.isEmpty) {
      return null;
    }
    final pageIndex = _controller.pageIndex.clamp(0, plan.pages.length - 1);
    final page = plan.pages[pageIndex];
    return _BookmarkPoint(
      chapterIndex: _controller.chapterIndex,
      chapterId: chapter.chapter.id,
      anchorOffset: page.startOffset,
    );
  }

  bool _isCurrentPageBookmarked() {
    final current = _currentBookmarkPoint();
    if (current == null) {
      return false;
    }
    return _bookmarks.contains(current);
  }

  void _toggleBookmark() {
    final current = _currentBookmarkPoint();
    if (current == null) {
      return;
    }
    final existed = _bookmarks.contains(current);
    setState(() {
      if (existed) {
        _bookmarks.remove(current);
      } else {
        _bookmarks.add(current);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(existed ? '已移除书签' : '已添加书签')),
    );
  }

  Future<void> _switchEncoding(String encoding) async {
    final normalized = encoding == 'auto' ? null : encoding;
    if (widget.book.id != null) {
      await _bookDao.updateBookTextEncoding(widget.book.id!, normalized);
    }
    await _controller.reloadWithEncoding(normalized);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已切换编码：${encoding.toUpperCase()}')),
    );
  }

  Future<void> _showTocSheet(BuildContext context) async {
    final toc = _controller.parsedBook?.toc ?? const <core.TocItem>[];
    if (toc.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView.builder(
            itemCount: toc.length,
            itemBuilder: (context, index) {
              final item = toc[index];
              return ListTile(
                contentPadding: EdgeInsets.only(
                  left: 16 + (item.level * 12),
                  right: 16,
                ),
                title: Text(item.title),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final chapterIndex =
                      _controller.parsedBook!.chapters.indexWhere(
                    (c) => c.chapter.id == item.chapterId,
                  );
                  if (chapterIndex >= 0) {
                    await _controller.jumpToChapter(
                      chapterIndex,
                      anchorOffset: item.anchorOffset,
                    );
                  }
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _onSelectionAction(
    BuildContext context,
    ReaderSelectionPayload payload,
  ) async {
    if (payload.action == ReaderSelectionAction.note) {
      final note = await _showNoteDialog(context);
      if (!mounted || note == null || note.trim().isEmpty) {
        return;
      }
      await _controller.addNote(payload: payload, note: note.trim());
      return;
    }

    if (payload.action == ReaderSelectionAction.askAi) {
      await _controller.askSelectionAi(
          payload.text, payload.globalStart, payload.globalEnd);
      if (!context.mounted) return;
      _showAiSheet(context, _controller.lastAiAnswer ?? 'AI 暂无回答');
      return;
    }

    await _controller.addHighlight(payload);
  }

  Future<String?> _showNoteDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加笔记/评论'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(hintText: '写下你的想法...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _showTypographySheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final style = _controller.style;
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '排版设置',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildStepAdjustRow(
                      context,
                      label: '字号',
                      valueText: style.fontSize.toStringAsFixed(1),
                      onDecrease: () => _controller.updateStyle(
                        style.copyWith(
                            fontSize: (style.fontSize - 1).clamp(12, 40)),
                      ),
                      onIncrease: () => _controller.updateStyle(
                        style.copyWith(
                            fontSize: (style.fontSize + 1).clamp(12, 40)),
                      ),
                    ),
                    _buildStepAdjustRow(
                      context,
                      label: '行距',
                      valueText: style.lineHeight.toStringAsFixed(2),
                      onDecrease: () => _controller.updateStyle(
                        style.copyWith(
                            lineHeight:
                                (style.lineHeight - 0.1).clamp(1.1, 3.0)),
                      ),
                      onIncrease: () => _controller.updateStyle(
                        style.copyWith(
                            lineHeight:
                                (style.lineHeight + 0.1).clamp(1.1, 3.0)),
                      ),
                    ),
                    _buildStepAdjustRow(
                      context,
                      label: '字距',
                      valueText: style.letterSpacing.toStringAsFixed(2),
                      onDecrease: () => _controller.updateStyle(
                        style.copyWith(
                          letterSpacing:
                              (style.letterSpacing - 0.1).clamp(0.0, 3.0),
                        ),
                      ),
                      onIncrease: () => _controller.updateStyle(
                        style.copyWith(
                          letterSpacing:
                              (style.letterSpacing + 0.1).clamp(0.0, 3.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '对齐方式',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('左对齐'),
                          selected: style.textAlign == TextAlign.start,
                          onSelected: (_) => _controller.updateStyle(
                              style.copyWith(textAlign: TextAlign.start)),
                        ),
                        ChoiceChip(
                          label: const Text('两端'),
                          selected: style.textAlign == TextAlign.justify,
                          onSelected: (_) => _controller.updateStyle(
                              style.copyWith(textAlign: TextAlign.justify)),
                        ),
                        ChoiceChip(
                          label: const Text('居中'),
                          selected: style.textAlign == TextAlign.center,
                          onSelected: (_) => _controller.updateStyle(
                              style.copyWith(textAlign: TextAlign.center)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStepAdjustRow(
    BuildContext context, {
    required String label,
    required String valueText,
    required VoidCallback onDecrease,
    required VoidCallback onIncrease,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label),
          ),
          IconButton(
            tooltip: '$label -',
            icon: const Icon(Icons.remove),
            onPressed: onDecrease,
          ),
          Expanded(
            child: Text(
              valueText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton(
            tooltip: '$label +',
            icon: const Icon(Icons.add),
            onPressed: onIncrease,
          ),
        ],
      ),
    );
  }

  void _showAiSheet(BuildContext context, String text) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Text(text),
          ),
        );
      },
    );
  }

  void _showAiSheetFromState(String text) {
    if (!mounted) return;
    _showAiSheet(context, text);
  }
}

class _ReaderTopStatusOverlay extends StatefulWidget {
  final Color foreground;

  const _ReaderTopStatusOverlay({
    required this.foreground,
  });

  @override
  State<_ReaderTopStatusOverlay> createState() =>
      _ReaderTopStatusOverlayState();
}

class _ReaderTopStatusOverlayState extends State<_ReaderTopStatusOverlay> {
  final Battery _battery = Battery();
  Timer? _timer;
  String _timeText = '';
  int _batteryLevel = 100;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _refreshStatus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    final now = DateTime.now();
    final nextTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    if (mounted) {
      setState(() {
        _timeText = nextTime;
      });
    }
    try {
      final level = await _battery.batteryLevel;
      if (mounted) {
        setState(() {
          _batteryLevel = level;
        });
      }
    } catch (_) {
      // ignore battery read failures on unsupported platforms
    }
  }

  IconData _batteryIcon() {
    if (_batteryLevel >= 90) return Icons.battery_full;
    if (_batteryLevel >= 70) return Icons.battery_6_bar;
    if (_batteryLevel >= 50) return Icons.battery_5_bar;
    if (_batteryLevel >= 30) return Icons.battery_3_bar;
    if (_batteryLevel >= 15) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.foreground;
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        media.padding.top + 2,
        12,
        0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _timeText,
              style: TextStyle(
                color: fg.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _batteryIcon(),
                  size: 16,
                  color: _batteryLevel <= 20
                      ? Colors.redAccent
                      : fg.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 4),
                Text(
                  '$_batteryLevel%',
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderThemePreset {
  final String name;
  final Color background;
  final Color foreground;

  const _ReaderThemePreset({
    required this.name,
    required this.background,
    required this.foreground,
  });
}

class _BookmarkPoint implements Comparable<_BookmarkPoint> {
  final int chapterIndex;
  final String chapterId;
  final int anchorOffset;

  const _BookmarkPoint({
    required this.chapterIndex,
    required this.chapterId,
    required this.anchorOffset,
  });

  @override
  int compareTo(_BookmarkPoint other) {
    final chapterCmp = chapterIndex.compareTo(other.chapterIndex);
    if (chapterCmp != 0) {
      return chapterCmp;
    }
    return anchorOffset.compareTo(other.anchorOffset);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _BookmarkPoint &&
        other.chapterId == chapterId &&
        other.anchorOffset == anchorOffset;
  }

  @override
  int get hashCode => Object.hash(chapterId, anchorOffset);
}
