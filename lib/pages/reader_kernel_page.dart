import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/models/book.dart' as legacy;
import 'package:xxread/reader_core/data/reader_models.dart' as core;
import 'package:xxread/reader_core/paginator/page_plan.dart' hide Page;
import 'package:xxread/reader_core/parser/parser_models.dart';
import 'package:xxread/reader_core/reader_kernel_controller.dart';
import 'package:xxread/reader_core/renderer/reader_view.dart';
import 'package:xxread/reader_core/selection/reader_selection.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/reading/reading_stats_dao.dart';
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

class _ReaderKernelPageState extends State<ReaderKernelPage>
    with WidgetsBindingObserver {
  static const String _themePrefKey = 'reader_theme_index_v1';
  static const double _floatingPanelRadius = 30;
  static const MethodChannel _readerUIChannel =
      MethodChannel('com.niki.xxread/reader_ui');

  late final ReaderKernelController _controller;
  final _bookDao = BookDao();
  final _statsDao = ReadingStatsDao();
  bool _chapterSwitching = false;
  ChapterBoundaryDirection? _chapterTransitionDirection;
  bool _chromeVisible = false;
  Timer? _immersiveTimer;
  final List<_ReaderThemePreset> _themes = const [
    _ReaderThemePreset(
      name: '纸张',
      background: Color(0xFFF7F2E7),
      foreground: Color(0xFF2A241C),
    ),
    _ReaderThemePreset(
      name: '米白',
      background: Color(0xFFFCF7EE),
      foreground: Color(0xFF2F271C),
    ),
    _ReaderThemePreset(
      name: '云灰',
      background: Color(0xFFF2F4F8),
      foreground: Color(0xFF1F2630),
    ),
    _ReaderThemePreset(
      name: '薄荷',
      background: Color(0xFFEDF7F2),
      foreground: Color(0xFF1E302A),
    ),
    _ReaderThemePreset(
      name: '青蓝',
      background: Color(0xFFEAF3FA),
      foreground: Color(0xFF1D2C39),
    ),
    _ReaderThemePreset(
      name: '夜间',
      background: Color(0xFF171A1F),
      foreground: Color(0xFFE5E7EC),
    ),
    _ReaderThemePreset(
      name: '墨黑',
      background: Color(0xFF0D1015),
      foreground: Color(0xFFDCE3ED),
    ),
    _ReaderThemePreset(
      name: '棕夜',
      background: Color(0xFF1C1712),
      foreground: Color(0xFFF0E3CF),
    ),
  ];
  final Set<_BookmarkPoint> _bookmarks = <_BookmarkPoint>{};
  int _themeIndex = 0;
  int? _activePointer;
  Offset? _pointerDownPosition;
  Offset? _pointerLatestPosition;
  DateTime? _pointerDownTime;
  bool _pointerMovedTooMuch = false;
  Timer? _statsFlushTimer;
  Timer? _bookProgressTimer;
  DateTime? _statsWindowStart;
  DateTime? _lastInteractionAt;
  String? _lastTrackedChapterId;
  int? _lastTrackedPageIndex;
  int _pendingPagesRead = 0;
  bool _statsFlushInFlight = false;
  bool _bookProgressSaving = false;
  int _lastPersistedCurrentPage = -1;
  int _lastPersistedTotalPages = -1;

  static const Duration _statsFlushInterval = Duration(seconds: 20);
  static const Duration _statsIdleThreshold = Duration(seconds: 70);
  static const Duration _statsMinWindow = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = ReaderKernelController();
    _lastPersistedCurrentPage = widget.book.currentPage;
    _lastPersistedTotalPages = widget.book.totalPages;
    _applyReaderSystemUI(immersive: true);
    _startStatsTracking();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _restoreTheme();
    if (!mounted) {
      return;
    }
    await _open();
  }

  Future<void> _restoreTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_themePrefKey);
    if (saved == null) {
      return;
    }
    final normalized = saved.clamp(0, _themes.length - 1);
    if (!mounted || normalized == _themeIndex) {
      return;
    }
    setState(() {
      _themeIndex = normalized;
    });
    _applyReaderSystemUI(immersive: !_chromeVisible);
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
    _lastTrackedChapterId = _controller.currentParsedChapter?.chapter.id;
    _lastTrackedPageIndex = _controller.pageIndex;
    _markReadingInteraction();
    _schedulePersistBookProgress(immediate: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _immersiveTimer?.cancel();
    _statsFlushTimer?.cancel();
    _bookProgressTimer?.cancel();
    unawaited(_persistBookProgress(force: true));
    unawaited(_flushReadingStats(force: true, resetWindow: false));
    _applyHostSystemUI();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markReadingInteraction();
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_persistBookProgress(force: true));
      unawaited(_flushReadingStats(force: true));
    }
  }

  void _startStatsTracking() {
    _markReadingInteraction();
    _statsFlushTimer?.cancel();
    _statsFlushTimer = Timer.periodic(_statsFlushInterval, (_) {
      unawaited(_flushReadingStats());
    });
  }

  void _markReadingInteraction() {
    final now = DateTime.now();
    _lastInteractionAt = now;
    _statsWindowStart ??= now;
  }

  void _trackPageTurn(int index) {
    final chapterId = _controller.currentParsedChapter?.chapter.id;
    if (chapterId == null) {
      _lastTrackedChapterId = null;
      _lastTrackedPageIndex = index;
      return;
    }

    if (_lastTrackedChapterId == chapterId && _lastTrackedPageIndex != null) {
      final delta = (index - _lastTrackedPageIndex!).abs();
      if (delta > 0) {
        _pendingPagesRead += delta;
      }
    } else if (_lastTrackedChapterId != null &&
        _lastTrackedChapterId != chapterId) {
      // 章节切换时按一次翻页计入，避免章节边界丢失。
      _pendingPagesRead += 1;
    }

    _lastTrackedChapterId = chapterId;
    _lastTrackedPageIndex = index;
    _schedulePersistBookProgress();
  }

  void _schedulePersistBookProgress({bool immediate = false}) {
    if (widget.book.id == null) {
      return;
    }
    _bookProgressTimer?.cancel();
    if (immediate) {
      unawaited(_persistBookProgress(force: true));
      return;
    }
    _bookProgressTimer = Timer(const Duration(milliseconds: 600), () {
      unawaited(_persistBookProgress());
    });
  }

  Future<void> _persistBookProgress({bool force = false}) async {
    final bookId = widget.book.id;
    final parsedBook = _controller.parsedBook;
    final plan = _controller.pagePlan;
    if (bookId == null || parsedBook == null || plan == null || plan.pages.isEmpty) {
      return;
    }
    if (_bookProgressSaving && !force) {
      return;
    }

    final chapterCount = math.max(1, parsedBook.chapters.length);
    final pageCount = math.max(1, plan.pages.length);
    final pageIndex = _controller.pageIndex.clamp(0, pageCount - 1);
    final chapterProgress = (pageIndex + 1) / pageCount;
    final overallProgress =
        ((_controller.chapterIndex + chapterProgress) / chapterCount)
            .clamp(0.0, 1.0);

    final baselineTotalPages = widget.book.totalPages > 1
        ? widget.book.totalPages
        : math.max(120, chapterCount * 8);
    final totalPages = math.max(chapterCount, baselineTotalPages);

    var currentPage = (overallProgress * totalPages).round();
    if (overallProgress > 0 && currentPage <= 0) {
      currentPage = 1;
    }
    currentPage = currentPage.clamp(0, totalPages);

    if (!force &&
        currentPage == _lastPersistedCurrentPage &&
        totalPages == _lastPersistedTotalPages) {
      return;
    }

    _bookProgressSaving = true;
    try {
      if (totalPages != _lastPersistedTotalPages) {
        await _bookDao.updateBookTotalPages(bookId, totalPages);
        _lastPersistedTotalPages = totalPages;
      }
      if (currentPage != _lastPersistedCurrentPage) {
        await _bookDao.updateBookProgress(bookId, currentPage);
        _lastPersistedCurrentPage = currentPage;
      }
      if (kDebugMode) {
        debugPrint(
          '[ReaderProgress] saved book=$bookId chapter=${_controller.chapterIndex + 1}/$chapterCount '
          'page=${pageIndex + 1}/$pageCount db=$currentPage/$totalPages '
          'progress=${(overallProgress * 100).toStringAsFixed(1)}%',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ReaderProgress] save failed: $e');
      }
    } finally {
      _bookProgressSaving = false;
    }
  }

  Future<void> _flushReadingStats({
    bool force = false,
    bool resetWindow = true,
  }) async {
    if (_statsFlushInFlight) {
      return;
    }
    final start = _statsWindowStart;
    final lastTouch = _lastInteractionAt;
    if (start == null || lastTouch == null) {
      return;
    }

    final now = DateTime.now();
    if (!force) {
      if (now.difference(lastTouch) > _statsIdleThreshold) {
        _statsWindowStart = now;
        _pendingPagesRead = 0;
        return;
      }
      if (now.difference(start) < _statsMinWindow) {
        return;
      }
    }

    final durationSeconds = now.difference(start).inSeconds;
    if (durationSeconds <= 0) {
      if (resetWindow) {
        _statsWindowStart = now;
      }
      return;
    }

    _statsFlushInFlight = true;
    try {
      await _statsDao.recordReadingSession(
        startTime: start,
        endTime: now,
        bookId: widget.book.id,
        pagesRead: _pendingPagesRead,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ReaderStats] flush failed: $e');
      }
    } finally {
      _statsFlushInFlight = false;
      _pendingPagesRead = 0;
      if (resetWindow) {
        _statsWindowStart = now;
      }
    }
  }

  void _applyHostSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiHelper.overlayStyleForBrightness(brightness),
    );
    _syncIOSReaderImmersive(false);
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
    final isMobilePlatform = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (isMobilePlatform) {
      if (immersive) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: const [SystemUiOverlay.top],
        );
      }
      _syncIOSReaderImmersive(immersive);
      return;
    }
    SystemChrome.setEnabledSystemUIMode(
      immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    _syncIOSReaderImmersive(false);
  }

  void _syncIOSReaderImmersive(bool enabled) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    _readerUIChannel.invokeMethod<void>('setReaderImmersive', <String, dynamic>{
      'enabled': enabled,
    }).catchError((_) {});
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

  void _handleReaderTapAt(Offset localPosition, BoxConstraints constraints) {
    _markReadingInteraction();
    final x = localPosition.dx;
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

  void _handlePointerDown(PointerDownEvent event) {
    _markReadingInteraction();
    _activePointer = event.pointer;
    _pointerDownPosition = event.localPosition;
    _pointerLatestPosition = event.localPosition;
    _pointerDownTime = DateTime.now();
    _pointerMovedTooMuch = false;
    if (!_chromeVisible) {
      _syncIOSReaderImmersive(true);
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }
    final start = _pointerDownPosition;
    if (start == null) {
      return;
    }
    _pointerLatestPosition = event.localPosition;
    if ((event.localPosition - start).distance > 14) {
      _pointerMovedTooMuch = true;
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointer == event.pointer) {
      _resetPointerTracking();
    }
  }

  void _handlePointerUp(
    PointerUpEvent event,
    BoxConstraints constraints, {
    required EdgeInsets mediaPadding,
  }) {
    if (_activePointer != event.pointer) {
      return;
    }
    final downTime = _pointerDownTime;
    final start = _pointerDownPosition;
    final end = _pointerLatestPosition ?? event.localPosition;
    final movedTooMuch = _pointerMovedTooMuch;
    _resetPointerTracking();
    if (downTime == null || start == null) {
      return;
    }
    final elapsed = DateTime.now().difference(downTime);
    if (movedTooMuch) {
      _handleBoundarySwipeGesture(start: start, end: end, elapsed: elapsed);
      return;
    }

    if (elapsed > const Duration(milliseconds: 260)) {
      return;
    }
    if (_isTapInControlArea(
      event.localPosition,
      constraints,
      mediaPadding: mediaPadding,
    )) {
      return;
    }
    _handleReaderTapAt(event.localPosition, constraints);
  }

  bool _isTapInControlArea(
    Offset localPosition,
    BoxConstraints constraints, {
    required EdgeInsets mediaPadding,
  }) {
    if (!_chromeVisible) {
      return false;
    }
    final topControlBottom = mediaPadding.top + 110;
    if (localPosition.dy <= topControlBottom) {
      return true;
    }
    final bottomControlTop =
        constraints.maxHeight - (mediaPadding.bottom + 128);
    return localPosition.dy >= bottomControlTop;
  }

  void _resetPointerTracking() {
    _activePointer = null;
    _pointerDownPosition = null;
    _pointerLatestPosition = null;
    _pointerDownTime = null;
    _pointerMovedTooMuch = false;
  }

  void _handleBoundarySwipeGesture({
    required Offset start,
    required Offset end,
    required Duration elapsed,
  }) {
    if (_chapterSwitching) {
      return;
    }
    if (elapsed > const Duration(milliseconds: 900)) {
      return;
    }
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    if (dx.abs() < 30 || dx.abs() <= dy.abs() * 1.15) {
      return;
    }

    final direction = dx < 0
        ? ChapterBoundaryDirection.next
        : ChapterBoundaryDirection.previous;
    if (!_canSwipeAcrossBoundary(direction)) {
      return;
    }

    unawaited(_jumpByDirection(direction, triggeredByBoundary: true));
    if (_chromeVisible) {
      _scheduleAutoImmersive();
    }
  }

  bool _canSwipeAcrossBoundary(ChapterBoundaryDirection direction) {
    final parsedBook = _controller.parsedBook;
    final plan = _controller.pagePlan;
    if (parsedBook == null || plan == null || plan.pages.isEmpty) {
      return false;
    }
    final current = _controller.pageIndex.clamp(0, plan.pages.length - 1);
    final atFirst = current <= 0;
    final atLast = _isAtLastPageBoundary(plan, current);
    if (direction == ChapterBoundaryDirection.next) {
      return atLast &&
          _controller.chapterIndex < parsedBook.chapters.length - 1;
    }
    return atFirst && _controller.chapterIndex > 0;
  }

  bool _isAtLastPageBoundary(PagePlan plan, int currentPageIndex) {
    if (_controller.layout.columns <= 1) {
      return currentPageIndex >= plan.pages.length - 1;
    }
    final lastSpreadStart =
        (((plan.pages.length - 1) ~/ 2) * 2).clamp(0, plan.pages.length - 1);
    return currentPageIndex >= lastSpreadStart;
  }

  void _setChapterTransitionDirection(ChapterBoundaryDirection? direction) {
    _chapterTransitionDirection = direction;
  }

  void _scheduleClearChapterTransitionDirection() {
    Future<void>.delayed(const Duration(milliseconds: 360), () {
      if (!mounted || _chapterSwitching) {
        return;
      }
      if (_chapterTransitionDirection == null) {
        return;
      }
      setState(() {
        _chapterTransitionDirection = null;
      });
    });
  }

  _ReaderThemePreset get _activeTheme => _themes[_themeIndex % _themes.length];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _activeTheme.background,
      extendBody: true,
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
              final platform = Theme.of(context).platform;
              final isAndroid = platform == TargetPlatform.android;
              // Use viewPadding to keep pagination area stable when chrome toggles.
              final topInset = media.viewPadding.top;
              final bottomInset = media.viewPadding.bottom;
              const topUiReserve = 8.0;
              // Keep a dedicated footer-safe lane for bottom page label to avoid text overlap.
              final bottomUiReserve = isAndroid ? 32.0 : 28.0;
              final padding = EdgeInsets.fromLTRB(
                16,
                topInset + topUiReserve,
                16,
                bottomInset + bottomUiReserve,
              );

              WidgetsBinding.instance.addPostFrameCallback((_) {
                _controller.updateViewport(
                  viewport: Size(constraints.maxWidth, constraints.maxHeight),
                  padding: padding,
                  enableSpread: enableSpread,
                );
              });

              final readerIdentity =
                  'reader-${chapter.chapter.id}-${_controller.layout.columns}';
              final readerKey = ValueKey(readerIdentity);
              final reader = ReaderView(
                key: readerKey,
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
                  _markReadingInteraction();
                  _trackPageTurn(index);
                  _controller.setPageIndex(index);
                  if (!_chromeVisible) {
                    _syncIOSReaderImmersive(true);
                  }
                  if (_chromeVisible) {
                    _scheduleAutoImmersive();
                  }
                },
                onSelectionAction: (payload) =>
                    _onSelectionAction(context, payload),
                onReachChapterBoundary: _onBoundaryReached,
              );
              final animatedReader = AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                transitionBuilder: (child, animation) {
                  final direction = _chapterTransitionDirection;
                  if (direction == null) {
                    return FadeTransition(opacity: animation, child: child);
                  }
                  final sign =
                      direction == ChapterBoundaryDirection.next ? 1.0 : -1.0;
                  final isIncoming = child.key == readerKey;
                  final slideTween = Tween<Offset>(
                    begin: Offset(isIncoming ? 0.12 * sign : 0, 0),
                    end: Offset(isIncoming ? 0 : -0.12 * sign, 0),
                  );
                  return ClipRect(
                    child: FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: slideTween.animate(animation),
                        child: child,
                      ),
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: readerKey,
                  child: reader,
                ),
              );

              return Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _handlePointerDown,
                onPointerMove: _handlePointerMove,
                onPointerCancel: _handlePointerCancel,
                onPointerUp: (event) => _handlePointerUp(
                  event,
                  constraints,
                  mediaPadding: media.padding,
                ),
                child: Stack(
                  children: [
                    Positioned.fill(child: animatedReader),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          opacity: _chromeVisible ? 0 : 1,
                          child: _ReaderTopStatusOverlay(
                            foreground: _activeTheme.foreground,
                          ),
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
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildTopControlBarAnimated(),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 34,
                      child: _buildBottomToolbarAnimated(),
                    ),
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
            child: _buildGlassPanel(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              radius: _floatingPanelRadius,
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
                      tooltip: '书签列表',
                      icon: const Icon(Icons.bookmarks_outlined),
                      onPressed: () => _showBookmarksSheet(context),
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
      child: _buildGlassPanel(
        margin: const EdgeInsets.fromLTRB(10, 34, 10, 0),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        radius: _floatingPanelRadius,
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
            IconButton(
              tooltip: '更多',
              icon: Icon(Icons.more_horiz, color: _activeTheme.foreground),
              onPressed: () => _showEncodingSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopControlBarAnimated() {
    return IgnorePointer(
      ignoring: !_chromeVisible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        offset: _chromeVisible ? Offset.zero : const Offset(0, -0.22),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          opacity: _chromeVisible ? 1 : 0,
          child: _buildTopControlBar(),
        ),
      ),
    );
  }

  Widget _buildBottomToolbarAnimated() {
    return IgnorePointer(
      ignoring: !_chromeVisible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        offset: _chromeVisible ? Offset.zero : const Offset(0, 0.26),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          opacity: _chromeVisible ? 1 : 0,
          child: _buildBottomToolbar(),
        ),
      ),
    );
  }

  Widget _buildGlassPanel({
    required Widget child,
    required EdgeInsets margin,
    required EdgeInsets padding,
    double radius = 14,
  }) {
    final fg = _activeTheme.foreground;
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: fg.withValues(alpha: 0.24)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.20),
                  Colors.white.withValues(alpha: 0.08),
                ],
              ),
              color: _activeTheme.background.withValues(alpha: 0.50),
            ),
            child: child,
          ),
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
    final media = MediaQuery.of(context);
    final platform = Theme.of(context).platform;
    final isMobilePlatform =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    final isIOS = platform == TargetPlatform.iOS;
    final bottomInset = media.viewPadding.bottom > 0 ? 1.0 : 0.0;
    final mobileLift = isIOS
        ? 10.0
        : isMobilePlatform
            ? 6.0
            : 0.0;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset + mobileLift),
        child: Text(
          '第 $chapterNo/$chapterTotal 章 · 第 $pageNo/$pageTotal 页',
          style: TextStyle(
            color: _activeTheme.foreground.withValues(alpha: 0.92),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            shadows: [
              Shadow(
                color: _activeTheme.background.withValues(alpha: 0.65),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onBoundaryReached(ChapterBoundaryDirection direction) async {
    await _jumpByDirection(direction, triggeredByBoundary: true);
  }

  Future<void> _stepPageForward() async {
    _markReadingInteraction();
    final plan = _controller.pagePlan;
    if (plan == null || plan.pages.isEmpty) {
      return;
    }
    final next = _controller.pageIndex + 1;
    if (next < plan.pages.length) {
      await _controller.setPageIndex(next);
      _trackPageTurn(next);
      return;
    }
    await _jumpByDirection(
      ChapterBoundaryDirection.next,
      triggeredByBoundary: true,
    );
  }

  Future<void> _stepPageBackward() async {
    _markReadingInteraction();
    final plan = _controller.pagePlan;
    if (plan == null || plan.pages.isEmpty) {
      return;
    }
    final previous = _controller.pageIndex - 1;
    if (previous >= 0) {
      await _controller.setPageIndex(previous);
      _trackPageTurn(previous);
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
    _markReadingInteraction();
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
    _setChapterTransitionDirection(direction);
    _chapterSwitching = true;
    try {
      if (triggeredByBoundary) {
        await Future<void>.delayed(const Duration(milliseconds: 90));
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
        _trackPageTurn(0);
      } else {
        _trackPageTurn(_controller.pageIndex);
      }
    } finally {
      _chapterSwitching = false;
      _scheduleClearChapterTransitionDirection();
    }
  }

  void _setTheme(
    int index, {
    bool showSnackBar = false,
  }) {
    final next = index.clamp(0, _themes.length - 1);
    if (next == _themeIndex) {
      return;
    }
    setState(() {
      _themeIndex = next;
    });
    unawaited(_persistTheme(next));
    _applyReaderSystemUI(immersive: !_chromeVisible);
    if (showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('主题：${_themes[next].name}')),
      );
    }
    if (_chromeVisible) {
      _scheduleAutoImmersive();
    }
  }

  Future<void> _persistTheme(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themePrefKey, index);
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
    if (_chromeVisible) {
      _scheduleAutoImmersive();
    }
  }

  List<_BookmarkPoint> _sortedBookmarks() {
    final items = _bookmarks.toList();
    items.sort();
    return items;
  }

  Future<void> _jumpToBookmark(_BookmarkPoint point) async {
    final parsedBook = _controller.parsedBook;
    if (parsedBook == null) {
      return;
    }
    if (point.chapterIndex < 0 || point.chapterIndex >= parsedBook.chapters.length) {
      return;
    }

    final currentChapterIndex = _controller.chapterIndex;
    if (point.chapterIndex > currentChapterIndex) {
      _setChapterTransitionDirection(ChapterBoundaryDirection.next);
    } else if (point.chapterIndex < currentChapterIndex) {
      _setChapterTransitionDirection(ChapterBoundaryDirection.previous);
    } else {
      _setChapterTransitionDirection(null);
    }

    await _controller.jumpToChapter(
      point.chapterIndex,
      anchorOffset: point.anchorOffset,
    );
    _scheduleClearChapterTransitionDirection();
  }

  String _bookmarkChapterTitle(_BookmarkPoint point) {
    final parsedBook = _controller.parsedBook;
    if (parsedBook == null ||
        point.chapterIndex < 0 ||
        point.chapterIndex >= parsedBook.chapters.length) {
      return '第 ${point.chapterIndex + 1} 章';
    }
    final raw = parsedBook.chapters[point.chapterIndex].chapter.title.trim();
    if (raw.isNotEmpty) {
      return raw;
    }
    return '第 ${point.chapterIndex + 1} 章';
  }

  String _bookmarkSubtitle(_BookmarkPoint point) {
    final parsedBook = _controller.parsedBook;
    if (parsedBook == null ||
        point.chapterIndex < 0 ||
        point.chapterIndex >= parsedBook.chapters.length) {
      return '偏移 ${point.anchorOffset}';
    }
    final chapter = parsedBook.chapters[point.chapterIndex].chapter;
    final total = math.max(1, chapter.content.length);
    final progress =
        ((point.anchorOffset / total) * 100).clamp(0.0, 100.0).round();
    return '第 ${point.chapterIndex + 1} 章 · 章节内 $progress%';
  }

  Future<T?> _showReaderBottomSheet<T>({
    required BuildContext context,
    required String title,
    required WidgetBuilder builder,
    double maxHeightFactor = 0.84,
  }) {
    final fg = _activeTheme.foreground;
    final bg = _activeTheme.background;
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.20),
      isScrollControlled: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.of(sheetContext).size.height * maxHeightFactor;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: _buildGlassPanel(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              radius: _floatingPanelRadius,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Theme(
                  data: Theme.of(sheetContext).copyWith(
                    dividerColor: fg.withValues(alpha: 0.14),
                    iconTheme: IconThemeData(color: fg.withValues(alpha: 0.92)),
                    listTileTheme: ListTileThemeData(
                      iconColor: fg.withValues(alpha: 0.92),
                      textColor: fg.withValues(alpha: 0.94),
                    ),
                    textTheme: Theme.of(sheetContext).textTheme.apply(
                          bodyColor: fg.withValues(alpha: 0.94),
                          displayColor: fg.withValues(alpha: 0.94),
                        ),
                    chipTheme: Theme.of(sheetContext).chipTheme.copyWith(
                          backgroundColor: fg.withValues(alpha: 0.10),
                          selectedColor: fg.withValues(alpha: 0.20),
                          disabledColor: fg.withValues(alpha: 0.06),
                          side: BorderSide(
                            color: fg.withValues(alpha: 0.18),
                          ),
                          labelStyle: TextStyle(
                            color: fg.withValues(alpha: 0.90),
                            fontWeight: FontWeight.w600,
                          ),
                          checkmarkColor: fg.withValues(alpha: 0.96),
                          showCheckmark: false,
                          shape: const StadiumBorder(),
                        ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: fg.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: fg.withValues(alpha: 0.95),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '关闭',
                            icon: const Icon(Icons.close_rounded),
                            color: fg.withValues(alpha: 0.90),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Flexible(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: ColoredBox(
                            color: bg.withValues(alpha: 0.16),
                            child: builder(sheetContext),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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

  Future<void> _showEncodingSheet(BuildContext context) async {
    const options = <MapEntry<String, String>>[
      MapEntry('自动识别', 'auto'),
      MapEntry('UTF-8', 'utf8'),
      MapEntry('GBK / GB2312', 'gbk'),
      MapEntry('UTF-16 LE', 'utf16le'),
      MapEntry('UTF-16 BE', 'utf16be'),
    ];
    await _showReaderBottomSheet<void>(
      context: context,
      title: '文本编码',
      maxHeightFactor: 0.62,
      builder: (sheetContext) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          itemCount: options.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: _activeTheme.foreground.withValues(alpha: 0.08),
          ),
          itemBuilder: (context, index) {
            final option = options[index];
            return ListTile(
              leading: const Icon(Icons.code_rounded),
              title: Text(option.key),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _switchEncoding(option.value);
              },
            );
          },
        );
      },
    );
    if (_chromeVisible) {
      _scheduleAutoImmersive();
    }
  }

  Future<void> _showTocSheet(BuildContext context) async {
    final toc = _controller.parsedBook?.toc ?? const <core.TocItem>[];
    if (toc.isEmpty) {
      return;
    }

    await _showReaderBottomSheet<void>(
      context: context,
      title: '目录',
      maxHeightFactor: 0.80,
      builder: (sheetContext) {
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          itemCount: toc.length,
          itemBuilder: (context, index) {
            final item = toc[index];
            return ListTile(
              contentPadding: EdgeInsets.only(
                left: 12 + (item.level * 14),
                right: 12,
              ),
              leading: Text(
                '${index + 1}',
                style: TextStyle(
                  color: _activeTheme.foreground.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                ),
              ),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final chapterIndex = _controller.parsedBook!.chapters.indexWhere(
                  (c) => c.chapter.id == item.chapterId,
                );
                if (chapterIndex >= 0) {
                  final currentChapterIndex = _controller.chapterIndex;
                  if (chapterIndex > currentChapterIndex) {
                    _setChapterTransitionDirection(
                      ChapterBoundaryDirection.next,
                    );
                  } else if (chapterIndex < currentChapterIndex) {
                    _setChapterTransitionDirection(
                      ChapterBoundaryDirection.previous,
                    );
                  } else {
                    _setChapterTransitionDirection(null);
                  }
                  await _controller.jumpToChapter(
                    chapterIndex,
                    anchorOffset: 0,
                  );
                  await _controller.setPageIndex(0);
                  _scheduleClearChapterTransitionDirection();
                }
              },
            );
          },
        );
      },
    );
    if (_chromeVisible) {
      _scheduleAutoImmersive();
    }
  }

  Future<void> _showBookmarksSheet(BuildContext context) async {
    final bookmarks = _sortedBookmarks();
    await _showReaderBottomSheet<void>(
      context: context,
      title: '书签',
      maxHeightFactor: 0.80,
      builder: (sheetContext) {
        if (bookmarks.isEmpty) {
          return Center(
            child: Text(
              '还没有书签，先点击底栏书签图标添加当前页',
              style: TextStyle(
                color: _activeTheme.foreground.withValues(alpha: 0.72),
              ),
              textAlign: TextAlign.center,
            ),
          );
        }
        final current = _currentBookmarkPoint();
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          itemCount: bookmarks.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: _activeTheme.foreground.withValues(alpha: 0.08),
          ),
          itemBuilder: (context, index) {
            final point = bookmarks[index];
            final selected = current != null && current == point;
            return ListTile(
              leading: Icon(
                selected ? Icons.bookmark : Icons.bookmark_outline,
                color: selected
                    ? _activeTheme.foreground.withValues(alpha: 0.96)
                    : _activeTheme.foreground.withValues(alpha: 0.72),
              ),
              title: Text(
                _bookmarkChapterTitle(point),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(_bookmarkSubtitle(point)),
              trailing: selected
                  ? Text(
                      '当前',
                      style: TextStyle(
                        color: _activeTheme.foreground.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _jumpToBookmark(point);
              },
            );
          },
        );
      },
    );
    if (_chromeVisible) {
      _scheduleAutoImmersive();
    }
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
    await _showReaderBottomSheet<void>(
      context: context,
      title: '排版与主题',
      maxHeightFactor: 0.86,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final style = _controller.style;
                final fg = _activeTheme.foreground;
                final sectionTextStyle = Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(
                      color: fg.withValues(alpha: 0.90),
                      fontWeight: FontWeight.w600,
                    );
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStepAdjustRow(
                        context,
                        label: '字号',
                        valueText: style.fontSize.toStringAsFixed(1),
                        foreground: fg,
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
                        foreground: fg,
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
                        foreground: fg,
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
                      const SizedBox(height: 10),
                      Text('对齐方式', style: sectionTextStyle),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('左对齐'),
                            selected: style.textAlign == TextAlign.start,
                            backgroundColor: fg.withValues(alpha: 0.10),
                            selectedColor: fg.withValues(alpha: 0.20),
                            side: BorderSide(color: fg.withValues(alpha: 0.20)),
                            labelStyle: TextStyle(
                              color: fg.withValues(alpha: 0.86),
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) => _controller.updateStyle(
                                style.copyWith(textAlign: TextAlign.start)),
                          ),
                          ChoiceChip(
                            label: const Text('两端'),
                            selected: style.textAlign == TextAlign.justify,
                            backgroundColor: fg.withValues(alpha: 0.10),
                            selectedColor: fg.withValues(alpha: 0.20),
                            side: BorderSide(color: fg.withValues(alpha: 0.20)),
                            labelStyle: TextStyle(
                              color: fg.withValues(alpha: 0.86),
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) => _controller.updateStyle(
                                style.copyWith(textAlign: TextAlign.justify)),
                          ),
                          ChoiceChip(
                            label: const Text('居中'),
                            selected: style.textAlign == TextAlign.center,
                            backgroundColor: fg.withValues(alpha: 0.10),
                            selectedColor: fg.withValues(alpha: 0.20),
                            side: BorderSide(color: fg.withValues(alpha: 0.20)),
                            labelStyle: TextStyle(
                              color: fg.withValues(alpha: 0.86),
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) => _controller.updateStyle(
                                style.copyWith(textAlign: TextAlign.center)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('阅读主题', style: sectionTextStyle),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List<Widget>.generate(_themes.length, (index) {
                          final theme = _themes[index];
                          final selected = _themeIndex == index;
                          return _buildThemeSelectorChip(
                            theme: theme,
                            selected: selected,
                            onTap: () {
                              _setTheme(index);
                              setModalState(() {});
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
    if (_chromeVisible) {
      _scheduleAutoImmersive();
    }
  }

  Widget _buildStepAdjustRow(
    BuildContext context, {
    required String label,
    required String valueText,
    required VoidCallback onDecrease,
    required VoidCallback onIncrease,
    Color? foreground,
  }) {
    final fg = foreground ?? Theme.of(context).textTheme.bodyMedium?.color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: TextStyle(color: fg?.withValues(alpha: 0.90)),
            ),
          ),
          IconButton(
            tooltip: '$label -',
            color: fg?.withValues(alpha: 0.92),
            icon: const Icon(Icons.remove),
            onPressed: onDecrease,
          ),
          Expanded(
            child: Text(
              valueText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: fg?.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          IconButton(
            tooltip: '$label +',
            color: fg?.withValues(alpha: 0.92),
            icon: const Icon(Icons.add),
            onPressed: onIncrease,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelectorChip({
    required _ReaderThemePreset theme,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final chipRadius = BorderRadius.circular(16);
    final borderColor = theme.foreground
        .withValues(alpha: selected ? 0.78 : 0.34);
    final startColor = Color.lerp(theme.background, Colors.white, 0.10)!
        .withValues(alpha: selected ? 0.70 : 0.52);
    final endColor = Color.lerp(theme.background, Colors.black, 0.08)!
        .withValues(alpha: selected ? 0.62 : 0.44);
    final textColor = theme.foreground.withValues(alpha: selected ? 0.96 : 0.84);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: chipRadius,
        child: ClipRRect(
          borderRadius: chipRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: chipRadius,
                border: Border.all(
                  color: borderColor,
                  width: selected ? 1.4 : 1.0,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [startColor, endColor],
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: theme.foreground.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.background,
                      border: Border.all(
                        color: theme.foreground.withValues(alpha: 0.48),
                        width: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    theme.name,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAiSheet(BuildContext context, String text) {
    unawaited(_showReaderBottomSheet<void>(
      context: context,
      title: 'AI 分析',
      maxHeightFactor: 0.72,
      builder: (_) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          child: Text(
            text,
            style: TextStyle(
              color: _activeTheme.foreground.withValues(alpha: 0.93),
              height: 1.52,
            ),
          ),
        );
      },
    ));
    if (_chromeVisible) {
      _scheduleAutoImmersive();
    }
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
    final statusBarHeight = math.max(media.viewPadding.top, 24.0);
    final platform = Theme.of(context).platform;
    final isAndroid = platform == TargetPlatform.android;
    final isIOS = platform == TargetPlatform.iOS;
    final isDynamicIslandIPhone = isIOS && media.viewPadding.top >= 51.0;
    final isLegacyNotchedIPhone =
        isIOS && media.viewPadding.top >= 44.0 && !isDynamicIslandIPhone;
    final horizontalInset = isAndroid
        ? 42.0
        : isDynamicIslandIPhone
            ? 36.0
            : isLegacyNotchedIPhone
                ? 20.0
                : 36.0;
    final topPadding = isAndroid
        ? 9.0
        : isIOS
            ? 22.0
            : 24.0;
    final topOffsetY = isDynamicIslandIPhone
        ? 0.0
        : isLegacyNotchedIPhone
            ? -5.0
            : 0.0;
    final timeOffsetX = isDynamicIslandIPhone
        ? 6.0
        : isLegacyNotchedIPhone
            ? -8.0
            : 0.0;
    final batteryOffsetX = isDynamicIslandIPhone
        ? 0.0
        : isLegacyNotchedIPhone
            ? 11.0
            : 0.0;
    final batteryOffsetY = isDynamicIslandIPhone
        ? topOffsetY
        : isLegacyNotchedIPhone
            ? -6.0
            : topOffsetY;
    return SizedBox(
      height: statusBarHeight + 30,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            horizontalInset, topPadding, horizontalInset, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Transform.translate(
                offset: Offset(timeOffsetX, topOffsetY),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
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
              ),
              Transform.translate(
                offset: Offset(batteryOffsetX, batteryOffsetY),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _batteryIcon(),
                        size: 15,
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
              ),
            ],
          ),
        ),
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
