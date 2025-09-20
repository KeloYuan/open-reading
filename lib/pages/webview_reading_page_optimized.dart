import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';
import '../models/chapter.dart';
import '../models/highlight.dart';
import '../models/note.dart';
import '../models/bookmark.dart';
import '../services/simple_webview_reader.dart';
import '../services/book_dao.dart';
import '../services/highlight_dao.dart';
import '../services/note_dao.dart';
import '../services/bookmark_dao.dart';
import '../services/reading_stats_dao.dart';
import '../services/enhanced_book_service.dart';
import '../widgets/tts_control_panel.dart';
import 'advanced_reading_page.dart';
import 'webview_reading_page_enhanced_toc.dart';

/// 性能优化版WebView阅读页面
/// 主要优化：减少setState调用、简化动画、优化UI层级
class WebViewReadingPageOptimized extends StatefulWidget {
  final Book book;
  final int? initialChapterIndex;
  final double? initialProgress;

  const WebViewReadingPageOptimized({
    super.key,
    required this.book,
    this.initialChapterIndex,
    this.initialProgress,
  });

  @override
  State<WebViewReadingPageOptimized> createState() =>
      _WebViewReadingPageOptimizedState();
}

class _WebViewReadingPageOptimizedState
    extends State<WebViewReadingPageOptimized> {
  // --- 核心状态（使用ValueNotifier减少重绘） ---
  final ValueNotifier<double> _currentProgress = ValueNotifier(0.0);
  final ValueNotifier<int> _currentPageNum = ValueNotifier(0);
  final ValueNotifier<int> _totalPages = ValueNotifier(0);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);
  final ValueNotifier<bool> _hasError = ValueNotifier(false);
  final ValueNotifier<String> _errorMessage = ValueNotifier('');

  // --- 阅读设置 ---
  ReadingTheme _currentTheme = ReadingThemes.dayTheme;
  double _fontSize = 16.0;
  double _lineSpacing = 1.6;
  String _fontFamily = 'System';

  // --- UI状态（简化控制） ---
  final ValueNotifier<bool> _showControlBar = ValueNotifier(false);
  bool _keepScreenOn = false;

  // --- 控制器（仅保留必要的） ---
  final TextEditingController _searchController = TextEditingController();
  Timer? _hideControlBarTimer;
  Timer? _batchUpdateTimer; // 批量更新定时器

  // --- 数据访问层 ---
  final BookDao _bookDao = BookDao();
  final HighlightDao _highlightDao = HighlightDao();
  final NoteDao _noteDao = NoteDao();
  final BookmarkDao _bookmarkDao = BookmarkDao();
  final ReadingStatsDao _readingStatsDao = ReadingStatsDao();
  final EnhancedBookService _bookService = EnhancedBookService();

  // --- 数据缓存（减少数据库查询） ---
  final List<Highlight> _highlights = [];
  final List<Note> _notes = [];
  final List<Bookmark> _bookmarks = [];
  final List<Chapter> _chapters = [];

  // --- 批量更新缓存 ---
  String? _pendingCfi;
  double? _pendingPercentage;
  int? _pendingCurrentPage;
  int? _pendingTotalPages;

  // --- 统计数据 ---
  DateTime? _readingStartTime;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initializeReading();
    _setupBatchUpdate(); // 设置批量更新
  }

  @override
  void dispose() {
    // 清理资源
    _searchController.dispose();
    _hideControlBarTimer?.cancel();
    _batchUpdateTimer?.cancel();

    // 清理ValueNotifier
    _currentProgress.dispose();
    _currentPageNum.dispose();
    _totalPages.dispose();
    _isLoading.dispose();
    _hasError.dispose();
    _errorMessage.dispose();
    _showControlBar.dispose();

    // 异步保存数据
    _saveDataAsync();

    super.dispose();
  }

  /// 设置批量更新机制（减少setState频率）
  void _setupBatchUpdate() {
    _batchUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      if (_pendingCfi != null || _pendingPercentage != null) {
        _applyBatchedUpdates();
      }
    });
  }

  /// 应用批量更新
  void _applyBatchedUpdates() {
    if (_pendingCfi != null) {
      if (_pendingCurrentPage != null)
        _currentPageNum.value = _pendingCurrentPage!;
      if (_pendingTotalPages != null) _totalPages.value = _pendingTotalPages!;
      if (_pendingPercentage != null)
        _currentProgress.value = _pendingPercentage!;

      // 保存进度（异步，不阻塞UI）
      _saveReadingProgressAsync();

      // 清空缓存
      _pendingCfi = null;
      _pendingPercentage = null;
      _pendingCurrentPage = null;
      _pendingTotalPages = null;
    }
  }

  /// 异步保存阅读数据
  void _saveDataAsync() {
    Future.microtask(() async {
      try {
        await _saveReadingProgress();
        await _updateReadingStats();
      } catch (e) {
        debugPrint('保存阅读数据时出错: $e');
      }
    });
  }

  /// 异步保存阅读进度（不阻塞UI）
  void _saveReadingProgressAsync() {
    Future.microtask(() => _saveReadingProgress());
  }

  // --- 初始化方法（简化版本） ---

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final defaultFontSize = _calculateDefaultFontSize();

      // 一次性批量更新状态，避免多次setState
      setState(() {
        _fontSize =
            prefs.getDouble('webview_reading_font_size') ?? defaultFontSize;
        _lineSpacing = prefs.getDouble('webview_reading_line_spacing') ?? 1.6;
        _fontFamily =
            prefs.getString('webview_reading_font_family') ?? 'System';
        _keepScreenOn =
            prefs.getBool('webview_reading_keep_screen_on') ?? false;

        final themeName = prefs.getString('webview_reading_theme') ?? 'day';
        _currentTheme = _getThemeByName(themeName);
      });

      if (_keepScreenOn) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      }
    } catch (e) {
      debugPrint('加载设置失败: $e');
      _currentTheme = ReadingThemes.dayTheme;
      _fontSize = _calculateDefaultFontSize();
    }
  }

  double _calculateDefaultFontSize() {
    final screenHeight = MediaQuery.of(context).size.height;
    if (screenHeight > 920) return 22.0;
    if (screenHeight > 880) return 21.0;
    if (screenHeight > 850) return 20.0;
    if (screenHeight > 800) return 19.0;
    if (screenHeight > 700) return 17.0;
    return 16.0;
  }

  Future<void> _initializeReading() async {
    _isLoading.value = true;
    _hasError.value = false;

    try {
      await _loadBookContent();
      await _loadChapters();
      await _loadAnnotations();
      _readingStartTime = DateTime.now();

      _isLoading.value = false;
    } catch (e) {
      debugPrint('初始化阅读失败: $e');
      _isLoading.value = false;
      _hasError.value = true;

      if (e.toString().contains('书籍文件不存在')) {
        _errorMessage.value = '书籍文件似乎已被移动或删除。请尝试重新导入此书籍。';
      } else if (e.toString().contains('加载书籍内容失败')) {
        _errorMessage.value = '无法读取书籍文件。文件可能已损坏或格式不支持。';
      } else {
        _errorMessage.value = '初始化阅读器时出现问题。请稍后重试。';
      }
    }
  }

  Future<void> _loadBookContent() async {
    try {
      final bookFile = File(widget.book.filePath);
      if (!bookFile.existsSync()) {
        throw Exception('书籍文件不存在: ${widget.book.filePath}');
      }
      debugPrint('书籍文件验证成功: ${widget.book.title}');
    } catch (e) {
      throw Exception('加载书籍内容失败: $e');
    }
  }

  Future<void> _loadChapters() async {
    try {
      final filePath = widget.book.filePath;
      final extension = filePath.split('.').last.toLowerCase();

      List<Chapter> chapters;
      if (extension == 'epub') {
        chapters = await _bookService.analyzeEpubToc(filePath);
      } else if (extension == 'pdf') {
        chapters = await _bookService.analyzePdfToc(filePath);
      } else {
        chapters = [];
      }

      _chapters.clear();
      _chapters.addAll(chapters);
      debugPrint('成功加载章节目录，共${_chapters.length}章');
    } catch (e) {
      debugPrint('加载章节目录失败: $e');
    }
  }

  Future<void> _loadAnnotations() async {
    try {
      if (widget.book.id == null) return;

      // 并发加载所有注释数据，提高效率
      final futures = await Future.wait([
        _highlightDao.getHighlightsByBook(widget.book.id!),
        _noteDao.getNotesByBook(widget.book.id!),
        _bookmarkDao.getBookmarksForBook(widget.book.id!),
      ]);

      _highlights.clear();
      _highlights.addAll(futures[0] as List<Highlight>);

      _notes.clear();
      _notes.addAll(futures[1] as List<Note>);

      _bookmarks.clear();
      _bookmarks.addAll(futures[2] as List<Bookmark>);

      debugPrint(
        '成功加载注释数据: ${_highlights.length}个高亮, ${_notes.length}个笔记, ${_bookmarks.length}个书签',
      );
    } catch (e) {
      debugPrint('加载注释失败: $e');
    }
  }

  ReadingTheme _getThemeByName(String name) {
    switch (name) {
      case 'night':
        return ReadingThemes.nightTheme;
      case 'green':
        return ReadingThemes.greenTheme;
      case 'brown':
        return ReadingThemes.brownTheme;
      case 'sepia':
        return ReadingThemes.sepiaTheme;
      default:
        return ReadingThemes.dayTheme;
    }
  }

  // --- UI控制（简化版本） ---

  void _toggleControlBar() {
    _showControlBar.value = !_showControlBar.value;

    if (_showControlBar.value) {
      _resetHideControlBarTimer();
    } else {
      _hideControlBarTimer?.cancel();
    }
  }

  void _hideControlBar() {
    _showControlBar.value = false;
    _hideControlBarTimer?.cancel();
  }

  void _resetHideControlBarTimer() {
    _hideControlBarTimer?.cancel();
    _hideControlBarTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _showControlBar.value) {
        _hideControlBar();
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: _currentTheme.controlBarColor,
      ),
    );
  }

  // --- WebView事件处理（批量更新） ---

  void _onPageChanged(
    String cfi,
    double percentage,
    int currentPage,
    int totalPages,
  ) {
    // 批量缓存更新，而不是立即setState
    _pendingCfi = cfi;
    _pendingPercentage = percentage;
    _pendingCurrentPage = currentPage;
    _pendingTotalPages = totalPages;
  }

  void _onTextSelected(String text, String cfi) {
    debugPrint('文本选择: $text');
    if (text.trim().isEmpty) return;
    _addHighlight(text, cfi, Colors.yellow);
  }

  // --- 注释操作（异步优化） ---

  Future<void> _addHighlight(String text, String cfi, Color color) async {
    try {
      if (widget.book.id == null) {
        _showMessage('书籍ID无效，无法保存高亮');
        return;
      }

      final highlight = Highlight(
        bookId: widget.book.id!,
        pageNumber: _currentPageNum.value,
        selectedText: text,
        startOffset: 0,
        endOffset: text.length,
        color: color,
        cfi: cfi,
        chapter: '第${_currentPageNum.value}页',
      );

      // 异步保存，不阻塞UI
      Future.microtask(() async {
        try {
          final id = await _highlightDao.insertHighlight(highlight);
          final savedHighlight = highlight.copyWith(id: id);

          if (mounted) {
            setState(() {
              _highlights.add(savedHighlight);
            });
          }
        } catch (e) {
          debugPrint('高亮保存错误: $e');
        }
      });

      _showMessage('高亮已添加');
    } catch (e) {
      _showMessage('添加高亮失败: $e');
    }
  }

  // --- 保存方法（异步优化） ---

  Future<void> _saveReadingProgress() async {
    if (_currentPageNum.value == 0) return;

    try {
      final currentPage = _currentPageNum.value;

      if (widget.book.id != null) {
        await _bookDao.updateBookProgress(widget.book.id!, currentPage);
      }
    } catch (e) {
      debugPrint('保存阅读进度失败: $e');
    }
  }

  Future<void> _updateReadingStats() async {
    if (_readingStartTime == null) return;

    try {
      final readingDuration = DateTime.now()
          .difference(_readingStartTime!)
          .inSeconds;

      if (readingDuration >= 30) {
        await _readingStatsDao.insertReadingTime(
          DateTime.now(),
          readingDuration,
        );
      }
    } catch (e) {
      debugPrint('更新阅读统计失败: $e');
    }
  }

  // --- UI构建（简化版本） ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentTheme.backgroundColor,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoading,
      builder: (context, isLoading, child) {
        if (isLoading) {
          return _buildLoadingWidget();
        }

        return ValueListenableBuilder<bool>(
          valueListenable: _hasError,
          builder: (context, hasError, child) {
            if (hasError) {
              return _buildErrorWidget();
            }

            return Stack(
              children: [
                _buildWebViewReader(),
                _buildTopBar(),
                _buildControlBar(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: _currentTheme.backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _currentTheme.textColor),
            const SizedBox(height: 16),
            Text(
              '正在加载优化版阅读器...',
              style: TextStyle(
                fontSize: 16,
                color: _currentTheme.textColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return ValueListenableBuilder<String>(
      valueListenable: _errorMessage,
      builder: (context, errorMsg, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _currentTheme.backgroundColor,
                _currentTheme.backgroundColor.withOpacity(0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 简化的顶部导航栏
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back,
                          color: _currentTheme.textColor,
                        ),
                      ),
                      Text(
                        widget.book.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _currentTheme.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // 简化的错误内容
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.book_outlined,
                            size: 64,
                            color: Colors.orange.shade400,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '无法打开书籍',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _currentTheme.textColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            errorMsg,
                            style: TextStyle(
                              fontSize: 16,
                              color: _currentTheme.textColor.withOpacity(0.7),
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton(
                            onPressed: _initializeReading,
                            child: const Text('重新加载'),
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
      },
    );
  }

  Widget _buildWebViewReader() {
    return SimpleWebViewReader(
      book: widget.book,
      backgroundColor: _currentTheme.backgroundColor,
      textColor: _currentTheme.textColor,
      fontFamily: _fontFamily,
      fontSize: _fontSize,
      lineHeight: _lineSpacing,
      onPageChanged: _onPageChanged,
      onTextSelected: _onTextSelected,
      onTap: _toggleControlBar,
      onReady: () {
        debugPrint('优化版WebView阅读器已就绪');
      },
    );
  }

  Widget _buildControlBar() {
    return ValueListenableBuilder<bool>(
      valueListenable: _showControlBar,
      builder: (context, showControlBar, child) {
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 200), // 缩短动画时间
          curve: Curves.easeOut, // 简化动画曲线
          bottom: showControlBar ? 0 : -150.0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: showControlBar ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !showControlBar,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 8,
                  top: 8,
                ),
                decoration: BoxDecoration(
                  color: _currentTheme.controlBarColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 简化的拖拽指示器
                    Container(
                      width: 40,
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: _currentTheme.iconColor.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    _buildSimplifiedToolbar(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSimplifiedToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSimpleButton(
            Icons.format_list_bulleted,
            '目录',
            _showTableOfContents,
          ),
          _buildSimpleButton(Icons.record_voice_over, '朗读', _showTtsPanel),
          _buildSimpleButton(Icons.bookmark_add, '书签', _addBookmark),
          _buildSimpleButton(Icons.share, '分享', () => _showMessage('分享功能开发中')),
          _buildSimpleButton(Icons.tune, '设置', _showSettingsPanel),
        ],
      ),
    );
  }

  Widget _buildSimpleButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _currentTheme.controlBarTextColor, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: _currentTheme.controlBarTextColor,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return ValueListenableBuilder<bool>(
      valueListenable: _showControlBar,
      builder: (context, showControlBar, child) {
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          top: showControlBar ? 0 : -80.0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: showControlBar ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !showControlBar,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                  bottom: 12,
                ),
                decoration: BoxDecoration(
                  color: _currentTheme.controlBarColor,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back,
                        color: _currentTheme.textColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.book.title,
                            style: TextStyle(
                              color: _currentTheme.textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.book.author,
                            style: TextStyle(
                              color: _currentTheme.textColor.withOpacity(0.7),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        ValueListenableBuilder<int>(
                          valueListenable: _currentPageNum,
                          builder: (context, currentPage, child) {
                            return ValueListenableBuilder<int>(
                              valueListenable: _totalPages,
                              builder: (context, totalPages, child) {
                                return Text(
                                  '$currentPage/$totalPages',
                                  style: TextStyle(
                                    color: _currentTheme.textColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        ValueListenableBuilder<double>(
                          valueListenable: _currentProgress,
                          builder: (context, progress, child) {
                            return Text(
                              '${(progress * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: _currentTheme.textColor.withOpacity(0.7),
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ],
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

  // --- 占位符方法（简化实现） ---

  void _showTableOfContents() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return EnhancedTocModal(
          chapters: _chapters,
          bookmarks: _bookmarks,
          currentTheme: _currentTheme,
          onChapterTap: _goToChapter,
          onBookmarkTap: _goToBookmark,
        );
      },
    );
  }

  void _showTtsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: _currentTheme.controlBarColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: TtsControlPanel(
            textToRead: '当前页面内容',
            onClose: () => Navigator.pop(context),
          ),
        );
      },
    );
  }

  void _showSettingsPanel() {
    _showMessage('设置面板功能开发中');
  }

  void _goToChapter(Chapter chapter) {
    _showMessage('跳转到: ${chapter.title}');
  }

  void _goToBookmark(Bookmark bookmark) {
    _showMessage('跳转到书签: ${bookmark.note}');
  }

  Future<void> _addBookmark() async {
    try {
      if (widget.book.id == null || _currentPageNum.value == 0) {
        _showMessage('无法添加书签：书籍信息不完整');
        return;
      }

      final currentPage = _currentPageNum.value;
      final existingBookmark = await _bookmarkDao.getBookmarkOnPage(
        widget.book.id!,
        currentPage,
      );

      if (existingBookmark != null) {
        await _bookmarkDao.deleteBookmark(existingBookmark.id!);
        _bookmarks.removeWhere((b) => b.id == existingBookmark.id);
        _showMessage('书签已移除');
      } else {
        final bookmark = Bookmark(
          bookId: widget.book.id!,
          pageNumber: currentPage,
          note: '第${currentPage}页',
        );

        final id = await _bookmarkDao.insertBookmark(bookmark);
        _bookmarks.add(bookmark.copyWith(id: id));
        _showMessage('书签已添加');
      }
    } catch (e) {
      _showMessage('书签操作失败: $e');
    }
  }
}
