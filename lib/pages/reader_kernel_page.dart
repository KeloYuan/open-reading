import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/models/book.dart' as legacy;
import 'package:xxread/models/bookmark.dart' as legacy_bookmark;
import 'package:xxread/reader_core/ai/ai_service.dart';
import 'package:xxread/reader_core/data/reader_models.dart' as core;
import 'package:xxread/reader_core/paginator/page_plan.dart' hide Page;
import 'package:xxread/reader_core/parser/parser_models.dart';
import 'package:xxread/reader_core/reader_kernel_controller.dart';
import 'package:xxread/reader_core/renderer/reader_view.dart';
import 'package:xxread/reader_core/selection/reader_selection.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/books/bookmark_dao.dart';
import 'package:xxread/services/reading/reading_stats_dao.dart';
import 'package:xxread/services/tts_service.dart';
import 'package:xxread/utils/font_catalog_helper.dart';
import 'package:xxread/utils/glass_config.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/system_ui_helper.dart';
import 'package:xxread/widgets/side_toast.dart';

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
  static const String _volumeKeyTurnPrefKey = 'enableVolumeKeyTurn';
  static const String _themePrefKey = 'reader_theme_index_v1';
  static const String _ttsEnabledPrefKey = 'reader_tts_enabled_v1';
  static const String _readerFontPrefKey = 'reader_font_family_v1';
  static const String _readerTypographyPrefKey = 'reader_typography_v1';
  static const String _bookmarkPrefKeyPrefix = 'reader_bookmarks_v1';
  static const String _bookmarkCfiPrefix = 'rk|';
  static const double _floatingPanelRadius = 30;
  static const MethodChannel _readerUIChannel =
      MethodChannel('com.niki.xxread/reader_ui');
  static const MethodChannel _readerKeysChannel =
      MethodChannel('com.niki.xxread/reader_keys');

  late final ReaderKernelController _controller;
  final _bookDao = BookDao();
  final _bookmarkDao = BookmarkDao();
  final _statsDao = ReadingStatsDao();
  bool _chapterSwitching = false;
  ChapterBoundaryDirection? _chapterTransitionDirection;
  bool _chromeVisible = false;
  bool _isAndroidTabletViewport = false;
  double _stableAndroidTopInset = 24.0;
  double _stableAndroidBottomInset = 20.0;
  Timer? _immersiveTimer;
  final List<_ReaderThemePreset> _themes = const [
    _ReaderThemePreset(
      name: '纯白',
      background: Color(0xFFFFFFFF),
      foreground: Color(0xFF111111),
    ),
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
      name: '象牙',
      background: Color(0xFFFFFBF2),
      foreground: Color(0xFF2C251A),
    ),
    _ReaderThemePreset(
      name: '云灰',
      background: Color(0xFFF2F4F8),
      foreground: Color(0xFF1F2630),
    ),
    _ReaderThemePreset(
      name: '晨雾',
      background: Color(0xFFF8FAFC),
      foreground: Color(0xFF1E2933),
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
      name: '暖杏',
      background: Color(0xFFFFF4E9),
      foreground: Color(0xFF33261C),
    ),
    _ReaderThemePreset(
      name: '夜间',
      background: Color(0xFF171A1F),
      foreground: Color(0xFFE5E7EC),
    ),
    _ReaderThemePreset(
      name: '深蓝夜',
      background: Color(0xFF101A2A),
      foreground: Color(0xFFDCE8FF),
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
  bool _exitingReader = false;
  bool _exitFlushScheduled = false;
  bool _ttsEnabled = true;
  bool _enableVolumeKeyTurn = true;
  DateTime? _lastVolumeKeyTurnAt;
  String? _pendingReaderFontFamily;
  core.ReaderStyle? _pendingReaderStyle;

  static const Duration _statsFlushInterval = Duration(seconds: 20);
  static const Duration _statsIdleThreshold = Duration(seconds: 70);
  static const Duration _statsMinWindow = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    _isAndroidTabletViewport = _detectAndroidTabletViewport();
    WidgetsBinding.instance.addObserver(this);
    _readerKeysChannel.setMethodCallHandler(_handleReaderKeyCall);
    _controller = ReaderKernelController();
    _lastPersistedCurrentPage = widget.book.currentPage;
    _lastPersistedTotalPages = widget.book.totalPages;
    _applyReaderSystemUI(immersive: true);
    _startStatsTracking();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_bootstrap());
    });
  }

  bool _detectAndroidTabletViewport() {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      return false;
    }
    final view = views.first;
    final logicalWidth = view.physicalSize.width / view.devicePixelRatio;
    final logicalHeight = view.physicalSize.height / view.devicePixelRatio;
    final shortestSide = math.min(logicalWidth, logicalHeight);
    return shortestSide >= 600.0;
  }

  Future<void> _bootstrap() async {
    await _restoreTheme();
    await _restoreTtsPreference();
    await _restoreVolumeKeyTurnPreference();
    await _restoreReaderFontPreference();
    await _restoreReaderTypographyPreference();
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

  Future<void> _restoreTtsPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_ttsEnabledPrefKey) ?? true;
    if (!mounted || enabled == _ttsEnabled) {
      return;
    }
    setState(() {
      _ttsEnabled = enabled;
    });
  }

  Future<void> _restoreVolumeKeyTurnPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _enableVolumeKeyTurn = prefs.getBool(_volumeKeyTurnPrefKey) ?? true;
    await _syncVolumeKeyPagingEnabled();
  }

  Future<void> _restoreReaderFontPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final family = prefs.getString(_readerFontPrefKey);
    _pendingReaderFontFamily =
        (family == null || family.isEmpty) ? null : family;
  }

  Future<void> _restoreReaderTypographyPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_readerTypographyPrefKey);
    if (raw == null || raw.trim().isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      final map = decoded.cast<String, dynamic>();

      double? toDouble(dynamic value) {
        if (value is double) return value;
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value);
        return null;
      }

      final fontSize = toDouble(map['fontSize'])?.clamp(12.0, 40.0);
      final lineHeight = toDouble(map['lineHeight'])?.clamp(1.1, 3.0);
      final letterSpacing = toDouble(map['letterSpacing'])?.clamp(0.0, 3.0);
      TextAlign? textAlign;
      final alignRaw = map['textAlign'];
      if (alignRaw is int &&
          alignRaw >= 0 &&
          alignRaw < TextAlign.values.length) {
        textAlign = TextAlign.values[alignRaw];
      }

      _pendingReaderStyle = _controller.style.copyWith(
        fontSize: fontSize,
        lineHeight: lineHeight,
        letterSpacing: letterSpacing,
        textAlign: textAlign,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Reader] restore typography failed: $e');
      }
    }
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
    var targetStyle = _controller.style;
    if (_pendingReaderFontFamily != _controller.style.fontFamily) {
      targetStyle = targetStyle.copyWith(
        fontFamily: _pendingReaderFontFamily,
        clearFontFamily: _pendingReaderFontFamily == null,
      );
    }
    if (_pendingReaderStyle != null) {
      final pending = _pendingReaderStyle!;
      targetStyle = targetStyle.copyWith(
        fontSize: pending.fontSize,
        lineHeight: pending.lineHeight,
        letterSpacing: pending.letterSpacing,
        textAlign: pending.textAlign,
      );
    }
    if (targetStyle.cacheSignature() != _controller.style.cacheSignature()) {
      await _controller.updateStyle(targetStyle);
    }
    await _restoreBookmarks();
    _lastTrackedChapterId = _controller.currentParsedChapter?.chapter.id;
    _lastTrackedPageIndex = _controller.pageIndex;
    _markReadingInteraction();
    _schedulePersistBookProgress(immediate: true);
  }

  String _bookmarkStorageKey() {
    final fallbackId = widget.book.filePath.hashCode.abs().toString();
    final bookKey = (widget.book.id ?? fallbackId).toString();
    return '$_bookmarkPrefKeyPrefix::$bookKey';
  }

  int? get _legacyBookId => widget.book.id;

  Future<void> _restoreBookmarks() async {
    final parsedBook = _controller.parsedBook;
    if (parsedBook == null) {
      return;
    }
    final restored = <_BookmarkPoint>{};
    restored.addAll(await _loadBookmarksFromPrefs(parsedBook));
    restored.addAll(await _loadBookmarksFromDatabase(parsedBook));

    if (!mounted) {
      _bookmarks
        ..clear()
        ..addAll(restored);
    } else {
      setState(() {
        _bookmarks
          ..clear()
          ..addAll(restored);
      });
    }
    await _persistBookmarks(syncDatabase: true);
  }

  Future<Set<_BookmarkPoint>> _loadBookmarksFromPrefs(
    ParsedBook parsedBook,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bookmarkStorageKey());
    if (raw == null || raw.trim().isEmpty) {
      return <_BookmarkPoint>{};
    }
    final restored = <_BookmarkPoint>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return restored;
      }
      final chapterIndexById = <String, int>{};
      for (int i = 0; i < parsedBook.chapters.length; i++) {
        chapterIndexById[parsedBook.chapters[i].chapter.id] = i;
      }
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        final map = item.cast<dynamic, dynamic>();
        String chapterId = (map['chapterId'] ?? '').toString();
        int? chapterIndex = _parseIntSafe(map['chapterIndex']);
        final anchorOffset = _parseIntSafe(map['anchorOffset']) ?? 0;

        if (chapterId.isEmpty &&
            chapterIndex != null &&
            chapterIndex >= 0 &&
            chapterIndex < parsedBook.chapters.length) {
          chapterId = parsedBook.chapters[chapterIndex].chapter.id;
        }
        if (chapterId.isEmpty) {
          continue;
        }

        chapterIndex ??= chapterIndexById[chapterId];
        if (chapterIndex == null ||
            chapterIndex < 0 ||
            chapterIndex >= parsedBook.chapters.length) {
          continue;
        }
        restored.add(
          _BookmarkPoint(
            chapterIndex: chapterIndex,
            chapterId: chapterId,
            anchorOffset: math.max(0, anchorOffset),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Reader] restore bookmarks from prefs failed: $e');
      }
    }
    return restored;
  }

  Future<Set<_BookmarkPoint>> _loadBookmarksFromDatabase(
    ParsedBook parsedBook,
  ) async {
    final bookId = _legacyBookId;
    if (bookId == null) {
      return <_BookmarkPoint>{};
    }
    final points = <_BookmarkPoint>{};
    try {
      final rows = await _bookmarkDao.getBookmarksForBook(bookId);
      for (final row in rows) {
        final point = _pointFromBookmarkRecord(row, parsedBook);
        if (point != null) {
          points.add(point);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Reader] restore bookmarks from db failed: $e');
      }
    }
    return points;
  }

  Future<void> _persistBookmarks({bool syncDatabase = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (_bookmarks.isEmpty) {
      await prefs.remove(_bookmarkStorageKey());
      if (syncDatabase) {
        await _syncBookmarksToDatabase();
      }
      return;
    }
    final payload = _bookmarks
        .map(
          (item) => <String, dynamic>{
            'chapterId': item.chapterId,
            'chapterIndex': item.chapterIndex,
            'anchorOffset': item.anchorOffset,
          },
        )
        .toList();
    await prefs.setString(_bookmarkStorageKey(), jsonEncode(payload));
    if (syncDatabase) {
      await _syncBookmarksToDatabase();
    }
  }

  Future<void> _syncBookmarksToDatabase() async {
    final parsedBook = _controller.parsedBook;
    final bookId = _legacyBookId;
    if (parsedBook == null || bookId == null) {
      return;
    }
    try {
      final rows = await _bookmarkDao.getBookmarksForBook(bookId);
      final managedInDb = <_BookmarkPoint, legacy_bookmark.Bookmark>{};
      int removedCount = 0;
      int insertedCount = 0;
      for (final row in rows) {
        final point = _pointFromBookmarkRecord(row, parsedBook);
        if (point != null) {
          managedInDb[point] = row;
        }
      }

      final desired = _bookmarks.toSet();
      for (final entry in managedInDb.entries) {
        if (!desired.contains(entry.key) && entry.value.id != null) {
          await _bookmarkDao.deleteBookmark(entry.value.id!);
          removedCount++;
        }
      }

      for (final point in desired) {
        if (!managedInDb.containsKey(point)) {
          await _bookmarkDao.insertBookmark(
            _bookmarkRecordFromPoint(point, bookId),
          );
          insertedCount++;
        }
      }
      if (kDebugMode) {
        debugPrint(
          '[Reader] bookmark db sync done bookId=$bookId desired=${desired.length} '
          'inserted=$insertedCount removed=$removedCount',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Reader] sync bookmarks to db failed: $e');
      }
    }
  }

  legacy_bookmark.Bookmark _bookmarkRecordFromPoint(
    _BookmarkPoint point,
    int bookId,
  ) {
    return legacy_bookmark.Bookmark(
      bookId: bookId,
      pageNumber: _stableBookmarkPageNumber(point),
      note: '',
      cfi: _encodeBookmarkCfi(point),
    );
  }

  _BookmarkPoint? _pointFromBookmarkRecord(
    legacy_bookmark.Bookmark bookmark,
    ParsedBook parsedBook,
  ) {
    final cfi = bookmark.cfi;
    if (cfi == null || cfi.isEmpty) {
      return null;
    }
    final map = _decodeBookmarkCfi(cfi);
    if (map == null) {
      return null;
    }

    String chapterId = (map['chapterId'] ?? '').toString();
    int? chapterIndex = _parseIntSafe(map['chapterIndex']);
    final anchorOffset = _parseIntSafe(map['anchorOffset']) ?? 0;
    if (chapterId.isEmpty &&
        chapterIndex != null &&
        chapterIndex >= 0 &&
        chapterIndex < parsedBook.chapters.length) {
      chapterId = parsedBook.chapters[chapterIndex].chapter.id;
    }
    if (chapterId.isEmpty) {
      return null;
    }

    chapterIndex ??= parsedBook.chapters
        .indexWhere((element) => element.chapter.id == chapterId);
    if (chapterIndex < 0 || chapterIndex >= parsedBook.chapters.length) {
      return null;
    }

    return _BookmarkPoint(
      chapterIndex: chapterIndex,
      chapterId: chapterId,
      anchorOffset: math.max(0, anchorOffset),
    );
  }

  String _encodeBookmarkCfi(_BookmarkPoint point) {
    final payload = jsonEncode({
      'chapterId': point.chapterId,
      'chapterIndex': point.chapterIndex,
      'anchorOffset': point.anchorOffset,
    });
    return '$_bookmarkCfiPrefix${base64Url.encode(utf8.encode(payload))}';
  }

  Map<String, dynamic>? _decodeBookmarkCfi(String rawCfi) {
    if (rawCfi.startsWith(_bookmarkCfiPrefix)) {
      final encoded = rawCfi.substring(_bookmarkCfiPrefix.length);
      try {
        final decoded = utf8.decode(base64Url.decode(encoded));
        final map = jsonDecode(decoded);
        if (map is Map<String, dynamic>) {
          return map;
        }
        if (map is Map) {
          return map.cast<String, dynamic>();
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  int _stableBookmarkPageNumber(_BookmarkPoint point) {
    int hash = 0x811C9DC5;
    for (final unit in point.chapterId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    hash ^= point.anchorOffset;
    hash = (hash * 0x01000193) & 0x7fffffff;
    if (hash <= 0) {
      hash = 1;
    }
    return hash;
  }

  int? _parseIntSafe(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _immersiveTimer?.cancel();
    _statsFlushTimer?.cancel();
    _bookProgressTimer?.cancel();
    unawaited(_disableVolumeKeyPaging());
    _readerKeysChannel.setMethodCallHandler(null);
    if (!_exitFlushScheduled) {
      unawaited(_persistBookProgress(force: true));
      unawaited(_flushReadingStats(force: true, resetWindow: false));
    }
    _applyHostSystemUI();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markReadingInteraction();
      unawaited(_restoreVolumeKeyTurnPreference());
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
    if (bookId == null ||
        parsedBook == null ||
        plan == null ||
        plan.pages.isEmpty) {
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
      if (defaultTargetPlatform == TargetPlatform.android &&
          _isAndroidTabletViewport) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else if (immersive) {
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

  Future<void> _syncVolumeKeyPagingEnabled() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _readerKeysChannel.invokeMethod<void>(
        'setVolumePagingEnabled',
        <String, dynamic>{'enabled': _enableVolumeKeyTurn},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Reader] sync volume key paging failed: $e');
      }
    }
  }

  Future<void> _disableVolumeKeyPaging() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _readerKeysChannel.invokeMethod<void>(
        'setVolumePagingEnabled',
        const <String, dynamic>{'enabled': false},
      );
    } catch (_) {
      // ignore
    }
  }

  Future<dynamic> _handleReaderKeyCall(MethodCall call) async {
    if (!mounted || call.method != 'onVolumeKey' || !_enableVolumeKeyTurn) {
      return;
    }
    // 防抖：避免系统长按或重复分发造成连续多次翻页。
    final now = DateTime.now();
    if (_lastVolumeKeyTurnAt != null &&
        now.difference(_lastVolumeKeyTurnAt!) <
            const Duration(milliseconds: 120)) {
      return;
    }
    _lastVolumeKeyTurnAt = now;

    final arguments = call.arguments;
    if (arguments is! Map) {
      return;
    }
    final direction = arguments['direction']?.toString();
    if (direction == 'next') {
      unawaited(_stepPageForward());
      return;
    }
    if (direction == 'previous') {
      unawaited(_stepPageBackward());
    }
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

  bool _isAndroidTabletByMedia(MediaQueryData media) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    final shortestSide = math.min(media.size.width, media.size.height);
    return shortestSide >= 600.0;
  }

  void _captureStableAndroidInsets(MediaQueryData media) {
    _stableAndroidTopInset = math.max(
      _stableAndroidTopInset,
      math.max(media.viewPadding.top, 24.0),
    );
    _stableAndroidBottomInset = math.max(
      _stableAndroidBottomInset,
      math.max(media.viewPadding.bottom, 20.0),
    );
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
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleExitReader();
      },
      child: Scaffold(
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
                final isLandscape =
                    constraints.maxWidth > constraints.maxHeight;
                final enableSpread = constraints.maxWidth >= 900 && isLandscape;
                final platform = Theme.of(context).platform;
                final isAndroid = platform == TargetPlatform.android;
                final isAndroidTablet = _isAndroidTabletByMedia(media);
                if (isAndroidTablet) {
                  _captureStableAndroidInsets(media);
                }
                if (_isAndroidTabletViewport != isAndroidTablet) {
                  _isAndroidTabletViewport = isAndroidTablet;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) {
                      return;
                    }
                    _applyReaderSystemUI(immersive: !_chromeVisible);
                  });
                }
                // Use viewPadding to keep pagination area stable when chrome toggles.
                final topInset = isAndroidTablet
                    ? _stableAndroidTopInset
                    : media.viewPadding.top;
                final bottomInset = isAndroidTablet
                    ? _stableAndroidBottomInset
                    : media.viewPadding.bottom;
                final topUiReserve = isAndroidTablet ? 38.0 : 8.0;
                // Keep a dedicated footer-safe lane for bottom page label to avoid text overlap.
                final bottomUiReserve = isAndroidTablet
                    ? 36.0
                    : isAndroid
                        ? 32.0
                        : 28.0;
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
              onPressed: () => _handleExitReader(),
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
              onPressed: () => _showAiChatSheet(),
            ),
            IconButton(
              tooltip: 'TTS',
              icon: Icon(
                Icons.record_voice_over_rounded,
                color: _activeTheme.foreground,
              ),
              onPressed: () => _showTtsSheet(context),
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
    bool forceDisableBlur = false,
    double blurSigma = 14,
  }) {
    final fg = _activeTheme.foreground;
    final isLowPerformance =
        GlassEffectConfig.shouldDisableBlur || forceDisableBlur;
    final panelBaseColor = isLowPerformance
        ? Color.alphaBlend(
            fg.withValues(alpha: 0.06),
            _activeTheme.background,
          )
        : _activeTheme.background.withValues(
            alpha: GlassEffectConfig.effectiveOpacity(0.50),
          );
    final panelGradientColors = isLowPerformance
        ? <Color>[panelBaseColor, panelBaseColor]
        : <Color>[
            Colors.white.withValues(
              alpha: GlassEffectConfig.effectiveOpacity(0.20),
            ),
            Colors.white.withValues(
              alpha: GlassEffectConfig.effectiveOpacity(0.08),
            ),
          ];
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          enabled: !isLowPerformance,
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: fg.withValues(alpha: 0.24)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: panelGradientColors,
              ),
              color: panelBaseColor,
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
          '第 $chapterNo/$chapterTotal 块 · 第 $pageNo/$pageTotal 页',
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

  Future<void> _handleExitReader() async {
    if (_exitingReader || !mounted) {
      return;
    }
    _exitingReader = true;
    try {
      _exitFlushScheduled = true;
      unawaited(_persistBookProgress(force: true));
      unawaited(_flushReadingStats(force: true, resetWindow: false));
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      _exitingReader = false;
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
      showSideToast(context, '主题：${_themes[next].name}',
          icon: Icons.palette_rounded);
    }
    if (_chromeVisible) {
      _scheduleAutoImmersive();
    }
  }

  Future<void> _persistTheme(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themePrefKey, index);
  }

  Future<void> _setReaderFontFamily(String? family) async {
    if (!mounted) {
      return;
    }
    final normalized = (family == null || family.isEmpty) ? null : family;
    if (_controller.style.fontFamily == normalized) {
      return;
    }
    await _controller.updateStyle(
      _controller.style.copyWith(
        fontFamily: normalized,
        clearFontFamily: normalized == null,
      ),
    );
    _pendingReaderFontFamily = normalized;
    final prefs = await SharedPreferences.getInstance();
    if (normalized == null) {
      await prefs.remove(_readerFontPrefKey);
      return;
    }
    await prefs.setString(_readerFontPrefKey, normalized);
  }

  Future<void> _applyTypographyStyle(core.ReaderStyle nextStyle) async {
    await _controller.updateStyle(nextStyle);
    await _persistTypographyStyle(nextStyle);
  }

  Future<void> _persistTypographyStyle(core.ReaderStyle style) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'fontSize': style.fontSize,
      'lineHeight': style.lineHeight,
      'letterSpacing': style.letterSpacing,
      'textAlign': style.textAlign.index,
    };
    await prefs.setString(_readerTypographyPrefKey, jsonEncode(payload));
  }

  Future<void> _setTtsEnabled(bool enabled) async {
    if (!mounted) {
      return;
    }
    final ttsService = Provider.of<TtsService>(context, listen: false);
    setState(() {
      _ttsEnabled = enabled;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ttsEnabledPrefKey, enabled);
    if (!enabled) {
      await ttsService.stop();
    }
  }

  String _currentPageTextForTts() {
    final plan = _controller.pagePlan;
    if (plan == null || plan.pages.isEmpty) {
      return '';
    }
    final pageIndex = _controller.pageIndex.clamp(0, plan.pages.length - 1);
    final page = plan.pages[pageIndex];
    final pageText = _controller.pageText(page).trim();
    if (pageText.isEmpty) {
      return '';
    }
    final chapterTitle =
        _controller.currentParsedChapter?.chapter.title.trim() ?? '';
    if (chapterTitle.isEmpty) {
      return pageText;
    }
    return '$chapterTitle。\n$pageText';
  }

  Future<void> _playCurrentPageTts() async {
    if (!_ttsEnabled) {
      showSideToast(context, '请先在 TTS 菜单中启用朗读',
          icon: Icons.record_voice_over_rounded);
      return;
    }
    final ttsService = Provider.of<TtsService>(context, listen: false);
    if (!ttsService.isInitialized) {
      await ttsService.initialize();
    }
    if (!ttsService.isInitialized) {
      if (!mounted) return;
      showSideToast(
        context,
        ttsService.lastError ?? 'TTS不可用，请重试初始化',
        icon: Icons.error_outline_rounded,
      );
      return;
    }
    final text = _currentPageTextForTts();
    if (text.isEmpty) {
      if (!mounted) return;
      showSideToast(context, '本页暂无可朗读文本', icon: Icons.info_outline_rounded);
      return;
    }
    await ttsService.speak(text);
  }

  Future<void> _togglePauseResumeTts(TtsService ttsService) async {
    if (ttsService.isPlaying && !ttsService.isPaused) {
      await ttsService.pause();
      return;
    }
    if (ttsService.isPaused) {
      await ttsService.resume();
      return;
    }
    await _playCurrentPageTts();
  }

  Future<void> _showTtsSheet(BuildContext context) async {
    await _showReaderBottomSheet<void>(
      context: context,
      title: 'TTS 朗读',
      maxHeightFactor: 0.74,
      builder: (_) {
        return Consumer<TtsService>(
          builder: (context, ttsService, __) {
            final fg = _activeTheme.foreground;
            final statusText = ttsService.isInitializing
                ? '引擎初始化中'
                : !ttsService.isInitialized
                    ? '不可用'
                    : !_ttsEnabled
                        ? '已关闭'
                        : ttsService.isPaused
                            ? '已暂停'
                            : ttsService.isPlaying
                                ? '朗读中'
                                : '待机';
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white.withValues(alpha: 0.08),
                      border: Border.all(
                        color: fg.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.graphic_eq_rounded,
                          color: fg.withValues(alpha: 0.92),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '状态：$statusText',
                            style: TextStyle(
                              color: fg.withValues(alpha: 0.90),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: _ttsEnabled,
                          onChanged: (value) {
                            unawaited(_setTtsEnabled(value));
                          },
                        ),
                      ],
                    ),
                  ),
                  if (ttsService.lastError?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Text(
                        '错误：${ttsService.lastError}',
                        style: TextStyle(
                          color: fg.withValues(alpha: 0.90),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _ttsEnabled ? _playCurrentPageTts : null,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('朗读本页'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _ttsEnabled
                            ? () => _togglePauseResumeTts(ttsService)
                            : null,
                        icon: Icon(
                          ttsService.isPlaying && !ttsService.isPaused
                              ? Icons.pause_rounded
                              : Icons.play_circle_outline_rounded,
                        ),
                        label: Text(
                          ttsService.isPlaying && !ttsService.isPaused
                              ? '暂停'
                              : '继续',
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _ttsEnabled ? () => ttsService.stop() : null,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('停止'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            unawaited(ttsService.retryInitialize()),
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: fg.withValues(alpha: 0.90),
                        ),
                        label: Text(
                          ttsService.isInitializing ? '初始化中' : '重试初始化',
                          style: TextStyle(
                            color: fg.withValues(alpha: 0.90),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '语速 ${ttsService.speechRate.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.86),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Slider(
                    value: ttsService.speechRate.clamp(0.2, 0.9),
                    min: 0.2,
                    max: 0.9,
                    divisions: 14,
                    onChanged: _ttsEnabled
                        ? (value) => unawaited(ttsService.setSpeechRate(value))
                        : null,
                  ),
                  Text(
                    '音量 ${ttsService.speechVolume.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.86),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Slider(
                    value: ttsService.speechVolume.clamp(0.0, 1.0),
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    onChanged: _ttsEnabled
                        ? (value) => unawaited(ttsService.setVolume(value))
                        : null,
                  ),
                ],
              ),
            );
          },
        );
      },
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
    unawaited(_persistBookmarks());
    showSideToast(
      context,
      existed ? '已移除书签' : '已添加书签',
      icon: existed
          ? Icons.bookmark_remove_rounded
          : Icons.bookmark_added_rounded,
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
    if (point.chapterIndex < 0 ||
        point.chapterIndex >= parsedBook.chapters.length) {
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
    bool forceDisableOuterBlur = false,
  }) {
    final fg = _activeTheme.foreground;
    final bg = _activeTheme.background;
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.20),
      isScrollControlled: true,
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        final maxHeight = media.size.height * maxHeightFactor;
        final keyboardVisible = media.viewInsets.bottom > 0;
        final disableOuterBlur = forceDisableOuterBlur || keyboardVisible;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: RepaintBoundary(
              child: _buildGlassPanel(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                radius: _floatingPanelRadius,
                forceDisableBlur: disableOuterBlur,
                blurSigma: disableOuterBlur ? 0 : 14,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Theme(
                    data: Theme.of(sheetContext).copyWith(
                      dividerColor: fg.withValues(alpha: 0.14),
                      iconTheme:
                          IconThemeData(color: fg.withValues(alpha: 0.92)),
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
          ),
        );
      },
    );
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
        return _ReaderTocSheetPanel(
          toc: toc,
          currentChapterId: _controller.currentParsedChapter?.chapter.id,
          foreground: _activeTheme.foreground,
          background: _activeTheme.background,
          onTapItem: (item) async {
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
      final selected = payload.text.trim();
      final question =
          selected.isEmpty ? null : '请解释这段内容，并给我 3 条可执行建议：\n$selected';
      await _showAiChatSheet(initialQuestion: question);
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
                final bg = _activeTheme.background;
                final sectionTextStyle =
                    Theme.of(context).textTheme.labelLarge?.copyWith(
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
                        onDecrease: () => unawaited(
                          _applyTypographyStyle(
                            style.copyWith(
                              fontSize: (style.fontSize - 1).clamp(12, 40),
                            ),
                          ),
                        ),
                        onIncrease: () => unawaited(
                          _applyTypographyStyle(
                            style.copyWith(
                              fontSize: (style.fontSize + 1).clamp(12, 40),
                            ),
                          ),
                        ),
                      ),
                      _buildStepAdjustRow(
                        context,
                        label: '行距',
                        valueText: style.lineHeight.toStringAsFixed(2),
                        foreground: fg,
                        onDecrease: () => unawaited(
                          _applyTypographyStyle(
                            style.copyWith(
                              lineHeight:
                                  (style.lineHeight - 0.1).clamp(1.1, 3.0),
                            ),
                          ),
                        ),
                        onIncrease: () => unawaited(
                          _applyTypographyStyle(
                            style.copyWith(
                              lineHeight:
                                  (style.lineHeight + 0.1).clamp(1.1, 3.0),
                            ),
                          ),
                        ),
                      ),
                      _buildStepAdjustRow(
                        context,
                        label: '字距',
                        valueText: style.letterSpacing.toStringAsFixed(2),
                        foreground: fg,
                        onDecrease: () => unawaited(
                          _applyTypographyStyle(
                            style.copyWith(
                              letterSpacing:
                                  (style.letterSpacing - 0.1).clamp(0.0, 3.0),
                            ),
                          ),
                        ),
                        onIncrease: () => unawaited(
                          _applyTypographyStyle(
                            style.copyWith(
                              letterSpacing:
                                  (style.letterSpacing + 0.1).clamp(0.0, 3.0),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('阅读字体', style: sectionTextStyle),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List<Widget>.generate(
                          FontCatalog.readerFonts.length,
                          (index) {
                            final option = FontCatalog.readerFonts[index];
                            final selected = style.fontFamily == option.family;
                            return _buildReaderFontChoiceChip(
                              label: FontCatalog.labelFor(
                                context.l10n,
                                option,
                              ),
                              fontFamily: option.family,
                              selected: selected,
                              foreground: fg,
                              background: bg,
                              onTap: () => unawaited(
                                _setReaderFontFamily(option.family),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('对齐方式', style: sectionTextStyle),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildAlignChoiceChip(
                            label: '左对齐',
                            selected: style.textAlign == TextAlign.start,
                            foreground: fg,
                            background: bg,
                            onTap: () => unawaited(
                              _applyTypographyStyle(
                                style.copyWith(textAlign: TextAlign.start),
                              ),
                            ),
                          ),
                          _buildAlignChoiceChip(
                            label: '两端',
                            selected: style.textAlign == TextAlign.justify,
                            foreground: fg,
                            background: bg,
                            onTap: () => unawaited(
                              _applyTypographyStyle(
                                style.copyWith(textAlign: TextAlign.justify),
                              ),
                            ),
                          ),
                          _buildAlignChoiceChip(
                            label: '居中',
                            selected: style.textAlign == TextAlign.center,
                            foreground: fg,
                            background: bg,
                            onTap: () => unawaited(
                              _applyTypographyStyle(
                                style.copyWith(textAlign: TextAlign.center),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('阅读主题', style: sectionTextStyle),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            List<Widget>.generate(_themes.length, (index) {
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

  Widget _buildAlignChoiceChip({
    required String label,
    required bool selected,
    required Color foreground,
    required Color background,
    required VoidCallback onTap,
  }) {
    final bgColor = Color.lerp(background, Colors.white, 0.10)!
        .withValues(alpha: selected ? 0.62 : 0.46);
    final selectedColor = Color.lerp(background, foreground, 0.10)!
        .withValues(alpha: selected ? 0.58 : 0.40);
    final borderColor = foreground.withValues(alpha: selected ? 0.34 : 0.18);
    final textColor = foreground.withValues(alpha: selected ? 0.96 : 0.86);

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      backgroundColor: bgColor,
      selectedColor: selectedColor,
      side: BorderSide(
        color: borderColor,
        width: selected ? 1.2 : 1.0,
      ),
      labelStyle: TextStyle(
        color: textColor,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      ),
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildReaderFontChoiceChip({
    required String label,
    required String? fontFamily,
    required bool selected,
    required Color foreground,
    required Color background,
    required VoidCallback onTap,
  }) {
    final bgColor = Color.lerp(background, Colors.white, 0.10)!
        .withValues(alpha: selected ? 0.66 : 0.48);
    final selectedColor = Color.lerp(background, foreground, 0.10)!
        .withValues(alpha: selected ? 0.58 : 0.40);
    final borderColor = foreground.withValues(alpha: selected ? 0.34 : 0.18);
    final textColor = foreground.withValues(alpha: selected ? 0.96 : 0.86);

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      backgroundColor: bgColor,
      selectedColor: selectedColor,
      side: BorderSide(
        color: borderColor,
        width: selected ? 1.2 : 1.0,
      ),
      labelStyle: TextStyle(
        color: textColor,
        fontFamily: fontFamily,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      ),
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildThemeSelectorChip({
    required _ReaderThemePreset theme,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final chipRadius = BorderRadius.circular(16);
    final isLowPerformance = GlassEffectConfig.shouldDisableBlur;
    final borderColor =
        theme.foreground.withValues(alpha: selected ? 0.78 : 0.34);
    final startColor = isLowPerformance
        ? Color.alphaBlend(
            theme.foreground.withValues(alpha: selected ? 0.08 : 0.04),
            theme.background,
          )
        : Color.lerp(theme.background, Colors.white, 0.10)!
            .withValues(alpha: selected ? 0.70 : 0.52);
    final endColor = isLowPerformance
        ? Color.alphaBlend(
            theme.foreground.withValues(alpha: selected ? 0.04 : 0.02),
            theme.background,
          )
        : Color.lerp(theme.background, Colors.black, 0.08)!
            .withValues(alpha: selected ? 0.62 : 0.44);
    final textColor =
        theme.foreground.withValues(alpha: selected ? 0.96 : 0.84);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: chipRadius,
        child: ClipRRect(
          borderRadius: chipRadius,
          child: BackdropFilter(
            enabled: !GlassEffectConfig.shouldDisableBlur,
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

  Future<void> _showAiChatSheet({String? initialQuestion}) async {
    final plan = _controller.pagePlan;
    if (plan == null || plan.pages.isEmpty) {
      return;
    }
    final page =
        plan.pages[_controller.pageIndex.clamp(0, plan.pages.length - 1)];
    final chapter = _controller.currentParsedChapter;
    final chapterTitle = chapter?.chapter.title ?? '当前章节';
    final pageText = _controller.pageText(page).trim();

    await _showReaderBottomSheet<void>(
      context: context,
      title: 'AI 阅读助手',
      maxHeightFactor: 0.90,
      forceDisableOuterBlur: true,
      builder: (_) {
        return _ReaderAiChatPanel(
          controller: _controller,
          theme: _activeTheme,
          chapterTitle: chapterTitle,
          pageLabel: '第 ${_controller.pageIndex + 1}/${plan.pages.length} 页',
          pageText: pageText,
          initialQuestion: initialQuestion,
        );
      },
    );
    if (_chromeVisible) {
      _scheduleAutoImmersive();
    }
  }
}

class _ReaderTocSheetPanel extends StatefulWidget {
  const _ReaderTocSheetPanel({
    required this.toc,
    required this.currentChapterId,
    required this.foreground,
    required this.background,
    required this.onTapItem,
  });

  final List<core.TocItem> toc;
  final String? currentChapterId;
  final Color foreground;
  final Color background;
  final ValueChanged<core.TocItem> onTapItem;

  @override
  State<_ReaderTocSheetPanel> createState() => _ReaderTocSheetPanelState();
}

class _ReaderTocSheetPanelState extends State<_ReaderTocSheetPanel> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _didAutoLocateCurrentChapter = false;
  String _query = '';

  static const double _estimatedTileExtent = 57.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLocateCurrentChapter();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _autoLocateCurrentChapter() {
    if (_didAutoLocateCurrentChapter ||
        !_scrollController.hasClients ||
        widget.currentChapterId == null) {
      return;
    }
    final currentIndex =
        widget.toc.indexWhere((t) => t.chapterId == widget.currentChapterId);
    if (currentIndex < 0) {
      _didAutoLocateCurrentChapter = true;
      return;
    }
    final previewOffset = math.max(0, currentIndex - 2);
    final rawOffset = previewOffset * _estimatedTileExtent;
    final maxOffset = _scrollController.position.maxScrollExtent;
    final targetOffset = rawOffset.clamp(0.0, maxOffset);
    _scrollController.jumpTo(targetOffset);
    _didAutoLocateCurrentChapter = true;
  }

  List<_TocSearchResult> _filteredItems() {
    final query = _query.trim().toLowerCase();
    final results = <_TocSearchResult>[];
    for (var i = 0; i < widget.toc.length; i++) {
      final item = widget.toc[i];
      if (query.isNotEmpty && !item.title.toLowerCase().contains(query)) {
        continue;
      }
      results.add(_TocSearchResult(index: i, item: item));
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.foreground;
    final filtered = _filteredItems();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _query = value;
              });
            },
            style: TextStyle(
              color: fg.withValues(alpha: 0.92),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: '搜索章节名',
              hintStyle: TextStyle(color: fg.withValues(alpha: 0.56)),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: fg.withValues(alpha: 0.72),
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: fg.withValues(alpha: 0.72),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                        });
                      },
                    ),
              isDense: true,
              filled: true,
              fillColor: GlassEffectConfig.shouldDisableBlur
                  ? Color.alphaBlend(
                      fg.withValues(alpha: 0.05),
                      widget.background,
                    )
                  : Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: fg.withValues(alpha: 0.16),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: fg.withValues(alpha: 0.14),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: fg.withValues(alpha: 0.30),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    '没有找到相关章节',
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.70),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : RawScrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  interactive: true,
                  thickness: 5.5,
                  radius: const Radius.circular(999),
                  thumbColor: fg.withValues(alpha: 0.40),
                  trackVisibility: false,
                  crossAxisMargin: 3,
                  minThumbLength: 36,
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(8, 2, 10, 10),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: fg.withValues(alpha: 0.08),
                    ),
                    itemBuilder: (context, index) {
                      final result = filtered[index];
                      final item = result.item;
                      final isCurrent =
                          item.chapterId == widget.currentChapterId;
                      return ListTile(
                        contentPadding: EdgeInsets.only(
                          left: 12 + (item.level * 12),
                          right: 10,
                        ),
                        leading: Container(
                          width: 32,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${result.index + 1}',
                            style: TextStyle(
                              color:
                                  fg.withValues(alpha: isCurrent ? 0.92 : 0.54),
                              fontWeight:
                                  isCurrent ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                        ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                fg.withValues(alpha: isCurrent ? 0.96 : 0.90),
                            fontWeight:
                                isCurrent ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        trailing: isCurrent
                            ? Icon(
                                Icons.my_location_rounded,
                                size: 16,
                                color: fg.withValues(alpha: 0.86),
                              )
                            : null,
                        onTap: () => widget.onTapItem(item),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _TocSearchResult {
  const _TocSearchResult({
    required this.index,
    required this.item,
  });

  final int index;
  final core.TocItem item;
}

class _ReaderAiChatPanel extends StatefulWidget {
  const _ReaderAiChatPanel({
    required this.controller,
    required this.theme,
    required this.chapterTitle,
    required this.pageLabel,
    required this.pageText,
    this.initialQuestion,
  });

  final ReaderKernelController controller;
  final _ReaderThemePreset theme;
  final String chapterTitle;
  final String pageLabel;
  final String pageText;
  final String? initialQuestion;

  @override
  State<_ReaderAiChatPanel> createState() => _ReaderAiChatPanelState();
}

class _ReaderAiChatPanelState extends State<_ReaderAiChatPanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final List<_AiUiMessage> _messages = <_AiUiMessage>[];

  AIProviderSettings? _settings;
  bool _loadingSettings = true;
  bool _sending = false;
  bool _entered = false;
  bool _scrollTaskScheduled = false;

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(_handleInputFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _entered = true;
      });
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _inputFocusNode
      ..removeListener(_handleInputFocusChanged)
      ..dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleInputFocusChanged() {
    if (_inputFocusNode.hasFocus) {
      _scrollToBottom();
    }
  }

  Future<void> _bootstrap() async {
    try {
      final settings = await widget.controller.loadAiSettings();
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _loadingSettings = false;
        _messages.add(
          _AiUiMessage.assistant(
            '我已经读取了本页内容（${widget.pageText.length} 字），可以直接问我：总结、解释、提炼要点、出题都可以。',
            includeInHistory: false,
          ),
        );
      });
      _scrollToBottom();
      final initial = widget.initialQuestion?.trim();
      if (initial != null && initial.isNotEmpty) {
        await _send(message: initial);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingSettings = false;
        _messages.add(_AiUiMessage.system('初始化 AI 失败：$e'));
      });
    }
  }

  Future<void> _switchProvider(AIProviderType provider) async {
    try {
      final loaded = await widget.controller.loadAiSettings(provider);
      await widget.controller.saveAiSettings(loaded);
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = loaded;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(_AiUiMessage.system('切换服务商失败：$e'));
      });
      _scrollToBottom();
    }
  }

  Future<void> _openProviderConfigDialog() async {
    try {
      final current = _settings ?? await widget.controller.loadAiSettings();
      if (!mounted) {
        return;
      }
      final providerSettings = <AIProviderType, AIProviderSettings>{};
      for (final provider in AIProviderType.values) {
        try {
          providerSettings[provider] =
              await widget.controller.loadAiSettings(provider);
        } catch (_) {
          providerSettings[provider] = AIProviderSettings.defaults(provider);
        }
      }
      if (!mounted) {
        return;
      }

      final result = await showDialog<AIProviderSettings>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.30),
        builder: (dialogContext) {
          return _AiProviderConfigDialog(
            theme: widget.theme,
            initialSettings: current,
            providerSettings: providerSettings,
          );
        },
      );

      if (result == null) {
        return;
      }
      await widget.controller.saveAiSettings(result);
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = result;
        _messages.add(
          _AiUiMessage.system(
            '已切换到 ${result.provider.displayName} · 模型 ${result.model}',
          ),
        );
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(_AiUiMessage.system('配置保存失败：$e'));
      });
      _scrollToBottom();
    }
  }

  Future<void> _send({String? message}) async {
    final text = (message ?? _inputController.text).trim();
    if (text.isEmpty || _sending) {
      return;
    }

    final settings = _settings;
    if (settings == null) {
      return;
    }

    if (!settings.isConfigured) {
      await _openProviderConfigDialog();
      if (!mounted || !(_settings?.isConfigured ?? false)) {
        return;
      }
    }

    FocusScope.of(context).unfocus();
    _inputController.clear();

    setState(() {
      _sending = true;
      _messages.add(_AiUiMessage.user(text));
    });
    _scrollToBottom();

    final history = _messages
        .where((m) => m.includeInHistory)
        .map(
          (m) => AIChatMessage(
            role: m.role,
            content: m.text,
          ),
        )
        .toList();

    try {
      final answer = await widget.controller.askAiChat(
        history: history,
        pageText: widget.pageText,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(_AiUiMessage.assistant(answer));
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(_AiUiMessage.system('$e'));
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollTaskScheduled) {
      return;
    }
    _scrollTaskScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollTaskScheduled = false;
      if (!_scrollController.hasClients) {
        return;
      }
      final targetOffset = _scrollController.position.maxScrollExtent;
      final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
      if (keyboardVisible) {
        _scrollController.jumpTo(targetOffset);
        return;
      }
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.theme.foreground;
    final settings = _settings;
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final keyboardVisible = keyboardInset > 0;
    final inputLift = keyboardVisible
        ? math.max(0.0, keyboardInset - media.padding.bottom)
        : 0.0;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      offset: _entered ? Offset.zero : const Offset(0, 0.04),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: _entered ? 1 : 0,
        child: Column(
          children: [
            _buildGlassSection(
              fg: fg,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.chapterTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fg.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.pageLabel,
                        style: TextStyle(
                          color: fg.withValues(alpha: 0.78),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<AIProviderType>(
                            value: settings?.provider ?? AIProviderType.minimax,
                            iconEnabledColor: fg.withValues(alpha: 0.90),
                            dropdownColor:
                                widget.theme.background.withValues(alpha: 0.98),
                            style: TextStyle(
                              color: fg.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w600,
                            ),
                            items: AIProviderType.values
                                .map(
                                  (provider) => DropdownMenuItem(
                                    value: provider,
                                    child: Text(provider.displayName),
                                  ),
                                )
                                .toList(),
                            onChanged: (provider) {
                              if (provider == null) {
                                return;
                              }
                              unawaited(_switchProvider(provider));
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        settings == null || !settings.isConfigured
                            ? '未配置 Key'
                            : settings.model,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg.withValues(alpha: 0.76),
                          fontSize: 12,
                        ),
                      ),
                      IconButton(
                        tooltip: '配置 API',
                        icon: Icon(
                          Icons.settings_suggest_rounded,
                          color: fg.withValues(alpha: 0.90),
                        ),
                        onPressed: _openProviderConfigDialog,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildGlassSection(
                fg: fg,
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: _loadingSettings
                    ? Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: fg.withValues(alpha: 0.86),
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                        itemCount: _messages.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return _AiMessageBubble(
                            key: ValueKey(msg.id),
                            message: msg,
                            foreground: fg,
                            background: widget.theme.background,
                            enableAnimation: !keyboardVisible,
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 8),
            RepaintBoundary(
              child: Padding(
                padding: EdgeInsets.only(bottom: inputLift),
                child: _buildGlassSection(
                  fg: fg,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          focusNode: _inputFocusNode,
                          controller: _inputController,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          onTap: _scrollToBottom,
                          style: TextStyle(color: fg.withValues(alpha: 0.93)),
                          decoration: InputDecoration(
                            hintText: '问点什么？例如：总结本页重点',
                            hintStyle: TextStyle(
                              color: fg.withValues(alpha: 0.58),
                            ),
                            filled: true,
                            fillColor: GlassEffectConfig.shouldDisableBlur
                                ? Color.alphaBlend(
                                    fg.withValues(alpha: 0.06),
                                    widget.theme.background,
                                  )
                                : Colors.white.withValues(alpha: 0.12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: fg.withValues(alpha: 0.18),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: fg.withValues(alpha: 0.16),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: fg.withValues(alpha: 0.34),
                              ),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: GlassEffectConfig.shouldDisableBlur
                              ? Color.alphaBlend(
                                  fg.withValues(
                                    alpha: _sending ? 0.10 : 0.16,
                                  ),
                                  widget.theme.background,
                                )
                              : Colors.white.withValues(
                                  alpha: _sending ? 0.18 : 0.28,
                                ),
                        ),
                        child: IconButton(
                          tooltip: '发送',
                          iconSize: 20,
                          icon: _sending
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: fg.withValues(alpha: 0.92),
                                  ),
                                )
                              : Icon(
                                  Icons.send_rounded,
                                  color: fg.withValues(alpha: 0.92),
                                ),
                          onPressed: _sending ? null : () => _send(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassSection({
    required Color fg,
    required EdgeInsets padding,
    required Widget child,
  }) {
    final isLowPerformance = GlassEffectConfig.shouldDisableBlur;
    final sectionBaseColor = isLowPerformance
        ? Color.alphaBlend(
            fg.withValues(alpha: 0.05),
            widget.theme.background,
          )
        : widget.theme.background.withValues(
            alpha: GlassEffectConfig.effectiveOpacity(0.36),
          );
    final sectionGradientColors = isLowPerformance
        ? <Color>[sectionBaseColor, sectionBaseColor]
        : <Color>[
            Colors.white.withValues(
              alpha: GlassEffectConfig.effectiveOpacity(0.18),
            ),
            Colors.white.withValues(
              alpha: GlassEffectConfig.effectiveOpacity(0.08),
            ),
          ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        enabled: !GlassEffectConfig.shouldDisableBlur,
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: fg.withValues(alpha: 0.18)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: sectionGradientColors,
            ),
            color: sectionBaseColor,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AiMessageBubble extends StatefulWidget {
  const _AiMessageBubble({
    super.key,
    required this.message,
    required this.foreground,
    required this.background,
    required this.enableAnimation,
  });

  final _AiUiMessage message;
  final Color foreground;
  final Color background;
  final bool enableAnimation;

  @override
  State<_AiMessageBubble> createState() => _AiMessageBubbleState();
}

class _AiMessageBubbleState extends State<_AiMessageBubble> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _visible = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    final isUser = msg.role == 'user';
    final isSystem = msg.role == 'system';
    final bubbleColor = isSystem
        ? widget.background.withValues(alpha: 0.38)
        : isUser
            ? widget.foreground.withValues(alpha: 0.22)
            : widget.background.withValues(alpha: 0.46);
    final borderColor = isUser
        ? widget.foreground.withValues(alpha: 0.36)
        : widget.foreground.withValues(alpha: 0.18);
    final textColor =
        widget.foreground.withValues(alpha: isSystem ? 0.78 : 0.93);

    if (!widget.enableAnimation) {
      return Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                color: textColor,
                height: 1.45,
                fontSize: isSystem ? 12.5 : 13.5,
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedSlide(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      offset: _visible ? Offset.zero : const Offset(0, 0.08),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _visible ? 1 : 0,
        child: Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: textColor,
                  height: 1.45,
                  fontSize: isSystem ? 12.5 : 13.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AiProviderConfigDialog extends StatefulWidget {
  const _AiProviderConfigDialog({
    required this.theme,
    required this.initialSettings,
    required this.providerSettings,
  });

  final _ReaderThemePreset theme;
  final AIProviderSettings initialSettings;
  final Map<AIProviderType, AIProviderSettings> providerSettings;

  @override
  State<_AiProviderConfigDialog> createState() =>
      _AiProviderConfigDialogState();
}

class _AiProviderConfigDialogState extends State<_AiProviderConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _keyController;
  late final TextEditingController _modelController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _tempController;

  late final Map<AIProviderType, AIProviderSettings> _draftByProvider;
  late AIProviderType _selectedProvider;
  bool _obscureApiKey = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _draftByProvider = {
      for (final provider in AIProviderType.values)
        provider: (widget.providerSettings[provider] ??
                AIProviderSettings.defaults(provider))
            .normalized(),
    };
    _selectedProvider = widget.initialSettings.provider;
    _draftByProvider[_selectedProvider] = widget.initialSettings.normalized();

    _keyController = TextEditingController();
    _modelController = TextEditingController();
    _baseUrlController = TextEditingController();
    _tempController = TextEditingController();
    _applyProviderDraft(_selectedProvider);
  }

  @override
  void dispose() {
    _keyController.dispose();
    _modelController.dispose();
    _baseUrlController.dispose();
    _tempController.dispose();
    super.dispose();
  }

  void _applyProviderDraft(AIProviderType provider) {
    final draft =
        _draftByProvider[provider] ?? AIProviderSettings.defaults(provider);
    _keyController.text = draft.apiKey;
    _modelController.text = draft.model;
    _baseUrlController.text = draft.baseUrl;
    _tempController.text = draft.temperature.toStringAsFixed(2);
  }

  AIProviderSettings _buildDraftFromInputs(
    AIProviderType provider, {
    bool allowFallbackTemp = true,
  }) {
    final previous =
        _draftByProvider[provider] ?? AIProviderSettings.defaults(provider);
    final parsedTemp = double.tryParse(_tempController.text.trim());
    final nextTemp =
        parsedTemp ?? (allowFallbackTemp ? previous.temperature : double.nan);
    return previous
        .copyWith(
          provider: provider,
          apiKey: _keyController.text,
          model: _modelController.text,
          baseUrl: _baseUrlController.text,
          temperature: nextTemp,
        )
        .normalized();
  }

  bool _validateTemperature(double value) {
    if (!value.isFinite) {
      return false;
    }
    if (value < 0 || value > 2) {
      return false;
    }
    if (_selectedProvider == AIProviderType.minimax &&
        (value <= 0 || value > 1)) {
      return false;
    }
    if ((_selectedProvider == AIProviderType.claude ||
            _selectedProvider == AIProviderType.gemini) &&
        value > 1) {
      return false;
    }
    return true;
  }

  String _temperatureHint(AIProviderType provider) {
    switch (provider) {
      case AIProviderType.minimax:
        return 'Temperature: MiniMax 建议 0.01 ~ 1.00';
      case AIProviderType.claude:
      case AIProviderType.gemini:
        return 'Temperature: 0.00 ~ 1.00';
      case AIProviderType.glm:
      case AIProviderType.openai:
        return 'Temperature: 0.00 ~ 2.00';
    }
  }

  void _onProviderChanged(AIProviderType provider) {
    _draftByProvider[_selectedProvider] =
        _buildDraftFromInputs(_selectedProvider);
    setState(() {
      _selectedProvider = provider;
      _errorText = null;
      _applyProviderDraft(provider);
    });
  }

  void _onSave() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }
    final parsedTemp = double.tryParse(_tempController.text.trim());
    if (parsedTemp == null || !_validateTemperature(parsedTemp)) {
      setState(() {
        _errorText = _selectedProvider == AIProviderType.minimax
            ? 'MiniMax 的 Temperature 必须在 0.01 ~ 1.00 之间'
            : 'Temperature 超出范围，请按提示填写';
      });
      return;
    }

    final result = _buildDraftFromInputs(
      _selectedProvider,
      allowFallbackTemp: false,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.theme.foreground;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          enabled: !GlassEffectConfig.shouldDisableBlur,
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: widget.theme.background.withValues(
                alpha: GlassEffectConfig.effectiveOpacity(0.68),
              ),
              border: Border.all(color: fg.withValues(alpha: 0.26)),
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 接口配置',
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<AIProviderType>(
                      initialValue: _selectedProvider,
                      decoration: const InputDecoration(
                        labelText: '服务商',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: AIProviderType.values
                          .map(
                            (provider) => DropdownMenuItem(
                              value: provider,
                              child: Text(provider.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (provider) {
                        if (provider == null || provider == _selectedProvider) {
                          return;
                        }
                        _onProviderChanged(provider);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _keyController,
                      obscureText: _obscureApiKey,
                      decoration: InputDecoration(
                        labelText: 'API Key',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          tooltip: _obscureApiKey ? '显示' : '隐藏',
                          icon: Icon(_obscureApiKey
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded),
                          onPressed: () {
                            setState(() {
                              _obscureApiKey = !_obscureApiKey;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'API Key 不能为空';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Model',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Model 不能为空';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Base URL',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) {
                          return 'Base URL 不能为空';
                        }
                        final uri = Uri.tryParse(text);
                        if (uri == null ||
                            !(uri.isScheme('http') || uri.isScheme('https'))) {
                          return '请输入合法的 http/https 地址';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _tempController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Temperature',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (value) {
                        final parsed = double.tryParse((value ?? '').trim());
                        if (parsed == null) {
                          return 'Temperature 必须是数字';
                        }
                        if (!_validateTemperature(parsed)) {
                          return _selectedProvider == AIProviderType.minimax
                              ? 'MiniMax 需 0.01 ~ 1.00'
                              : '超出允许范围';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _temperatureHint(_selectedProvider),
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.72),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'MiniMax: https://api.minimax.io/v1\nGLM: https://open.bigmodel.cn/api/paas/v4\nOpenAI: https://api.openai.com/v1\nClaude: https://api.anthropic.com\nGemini: https://generativelanguage.googleapis.com/v1beta',
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.66),
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorText!,
                        style: TextStyle(
                          color: Colors.redAccent.shade200,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: _onSave,
                          child: const Text('保存'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AiUiMessage {
  _AiUiMessage({
    required this.role,
    required this.text,
    required this.includeInHistory,
  }) : id = '${DateTime.now().microsecondsSinceEpoch}-${text.hashCode}';

  factory _AiUiMessage.user(String text) => _AiUiMessage(
        role: 'user',
        text: text,
        includeInHistory: true,
      );
  factory _AiUiMessage.assistant(String text, {bool includeInHistory = true}) =>
      _AiUiMessage(
        role: 'assistant',
        text: text,
        includeInHistory: includeInHistory,
      );
  factory _AiUiMessage.system(String text) => _AiUiMessage(
        role: 'system',
        text: text,
        includeInHistory: false,
      );

  final String id;
  final String role;
  final String text;
  final bool includeInHistory;
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
