import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';
import '../models/chapter.dart';
import '../models/highlight.dart';
import '../models/note.dart';
import '../models/bookmark.dart';
import '../services/book_dao.dart';
import '../services/highlight_dao.dart';
import '../services/note_dao.dart';
import '../services/bookmark_dao.dart';
import '../services/reading_stats_dao.dart';
import '../services/enhanced_book_service.dart';
import '../widgets/flutter_advanced_reader_widget.dart';
import '../widgets/tts_control_panel.dart';
import 'advanced_reading_page.dart';
import 'webview_reading_page_enhanced_toc.dart';

/// Flutter原生阅读页面 - WebView的高性能替代方案
/// 使用Flutter原生组件实现，性能更佳，资源占用更少
class NativeReadingPage extends StatefulWidget {
  final Book book;
  final int? initialChapterIndex;
  final double? initialProgress;

  const NativeReadingPage({
    super.key,
    required this.book,
    this.initialChapterIndex,
    this.initialProgress,
  });

  @override
  State<NativeReadingPage> createState() => _NativeReadingPageState();
}

class _NativeReadingPageState extends State<NativeReadingPage> {
  // --- 核心控制器 ---
  final FlutterAdvancedReaderController _readerController =
      FlutterAdvancedReaderController();

  // --- 核心状态 ---
  String _bookContent = '';
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // --- 阅读状态 ---
  double _currentProgress = 0.0;
  int _currentPageNum = 0;
  int _totalPages = 0;

  // --- 阅读设置 ---
  ReadingTheme _currentTheme = ReadingThemes.dayTheme;
  double _fontSize = 18.0;
  double _lineHeight = 1.6;
  double _letterSpacing = 0.2;
  double _pageMargin = 24.0;
  String _fontFamily = 'System';

  // --- UI状态 ---
  bool _showControlBar = false;
  bool _keepScreenOn = false;

  // --- 控制器 ---
  final TextEditingController _searchController = TextEditingController();
  Timer? _hideControlBarTimer;

  // --- 数据访问层 ---
  final BookDao _bookDao = BookDao();
  final HighlightDao _highlightDao = HighlightDao();
  final NoteDao _noteDao = NoteDao();
  final BookmarkDao _bookmarkDao = BookmarkDao();
  final ReadingStatsDao _readingStatsDao = ReadingStatsDao();
  final EnhancedBookService _bookService = EnhancedBookService();

  // --- 数据缓存 ---
  final List<Highlight> _highlights = [];
  final List<Note> _notes = [];
  final List<Bookmark> _bookmarks = [];
  final List<Chapter> _chapters = [];

  // --- 统计数据 ---
  DateTime? _readingStartTime;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initializeReading();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _hideControlBarTimer?.cancel();
    _saveDataAsync();
    super.dispose();
  }

  /// 异步保存数据
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

  // --- 初始化方法 ---

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final defaultFontSize = _calculateDefaultFontSize();

      setState(() {
        _fontSize =
            prefs.getDouble('native_reading_font_size') ?? defaultFontSize;
        _lineHeight = prefs.getDouble('native_reading_line_height') ?? 1.6;
        _letterSpacing =
            prefs.getDouble('native_reading_letter_spacing') ?? 0.2;
        _pageMargin = prefs.getDouble('native_reading_page_margin') ?? 24.0;
        _fontFamily = prefs.getString('native_reading_font_family') ?? 'System';
        _keepScreenOn = prefs.getBool('native_reading_keep_screen_on') ?? false;

        final themeName = prefs.getString('native_reading_theme') ?? 'day';
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
    if (screenHeight > 700) return 18.0;
    return 16.0;
  }

  Future<void> _initializeReading() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // 加载书籍内容
      await _loadBookContent();

      // 加载章节目录
      await _loadChapters();

      // 加载注释数据
      await _loadAnnotations();

      // 开始计时
      _readingStartTime = DateTime.now();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('初始化阅读失败: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = _getErrorMessage(e);
      });
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString();
    if (errorStr.contains('书籍文件不存在')) {
      return '书籍文件似乎已被移动或删除。请尝试重新导入此书籍。';
    } else if (errorStr.contains('加载书籍内容失败')) {
      return '无法读取书籍文件。文件可能已损坏或格式不支持。';
    } else {
      return '初始化阅读器时出现问题。请稍后重试。';
    }
  }

  Future<void> _loadBookContent() async {
    try {
      final bookFile = File(widget.book.filePath);
      if (!bookFile.existsSync()) {
        throw Exception('书籍文件不存在: ${widget.book.filePath}');
      }

      final extension = widget.book.filePath.split('.').last.toLowerCase();
      String content = '';

      if (extension == 'txt') {
        // 直接读取TXT文件
        content = await bookFile.readAsString();
      } else if (extension == 'epub') {
        // 暂时不支持EPUB文本提取，显示提示信息
        content =
            '暂不支持EPUB格式的文本提取。\n\n建议使用WebView阅读器来阅读EPUB格式的书籍，WebView阅读器提供更好的EPUB支持。\n\n或者将EPUB转换为TXT格式后再使用原生阅读器。';
      } else {
        throw Exception('暂不支持该文件格式: $extension');
      }

      if (content.trim().isEmpty) {
        throw Exception('书籍内容为空');
      }

      setState(() {
        _bookContent = content;
      });

      debugPrint('成功加载书籍内容，长度: ${content.length}');
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
      } else {
        // TXT文件简单章节检测
        chapters = _detectTxtChapters(_bookContent);
      }

      setState(() {
        _chapters.clear();
        _chapters.addAll(chapters);
      });

      debugPrint('成功加载章节目录，共${_chapters.length}章');
    } catch (e) {
      debugPrint('加载章节目录失败: $e');
    }
  }

  List<Chapter> _detectTxtChapters(String content) {
    final chapters = <Chapter>[];
    final lines = content.split('\n');
    int chapterIndex = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      // 简单的章节检测：以"第"开头，包含"章"字
      if (line.startsWith('第') && line.contains('章')) {
        chapters.add(
          Chapter(
            id: chapterIndex++,
            title: line,
            level: 0,
            startPage: 0, // 将在分页后更新
          ),
        );
      }
    }

    return chapters;
  }

  Future<void> _loadAnnotations() async {
    try {
      if (widget.book.id == null) return;

      final futures = await Future.wait([
        _highlightDao.getHighlightsByBook(widget.book.id!),
        _noteDao.getNotesByBook(widget.book.id!),
        _bookmarkDao.getBookmarksForBook(widget.book.id!),
      ]);

      setState(() {
        _highlights.clear();
        _highlights.addAll(futures[0] as List<Highlight>);

        _notes.clear();
        _notes.addAll(futures[1] as List<Note>);

        _bookmarks.clear();
        _bookmarks.addAll(futures[2] as List<Bookmark>);
      });

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

  // --- UI控制 ---

  void _toggleControlBar() {
    setState(() {
      _showControlBar = !_showControlBar;
    });

    if (_showControlBar) {
      _resetHideControlBarTimer();
    } else {
      _hideControlBarTimer?.cancel();
    }
  }

  void _hideControlBar() {
    setState(() {
      _showControlBar = false;
    });
    _hideControlBarTimer?.cancel();
  }

  void _resetHideControlBarTimer() {
    _hideControlBarTimer?.cancel();
    _hideControlBarTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _showControlBar) {
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

  // --- 阅读器事件处理 ---

  void _onPageChanged(int currentPage, int totalPages) {
    setState(() {
      _currentPageNum = currentPage;
      _totalPages = totalPages;
      _currentProgress = totalPages > 0 ? currentPage / totalPages : 0.0;
    });

    // 异步保存进度
    Future.microtask(() => _saveReadingProgress());
  }

  void _onTextSelected(String selectedText) {
    debugPrint('文本选择: $selectedText');
    if (selectedText.trim().isEmpty) return;
    _addHighlight(selectedText, Colors.yellow);
  }

  // --- 注释操作 ---

  Future<void> _addHighlight(String text, Color color) async {
    try {
      if (widget.book.id == null) {
        _showMessage('书籍ID无效，无法保存高亮');
        return;
      }

      final highlight = Highlight(
        bookId: widget.book.id!,
        pageNumber: _currentPageNum,
        selectedText: text,
        startOffset: 0,
        endOffset: text.length,
        color: color,
        chapter: '第${_currentPageNum}页',
      );

      final id = await _highlightDao.insertHighlight(highlight);
      final savedHighlight = highlight.copyWith(id: id);

      setState(() {
        _highlights.add(savedHighlight);
      });

      _showMessage('高亮已添加');
    } catch (e) {
      _showMessage('添加高亮失败: $e');
    }
  }

  // --- 保存方法 ---

  Future<void> _saveReadingProgress() async {
    if (_currentPageNum == 0) return;

    try {
      if (widget.book.id != null) {
        await _bookDao.updateBookProgress(widget.book.id!, _currentPageNum);
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

  // --- UI构建 ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentTheme.backgroundColor,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_hasError) {
      return _buildErrorWidget();
    }

    return Stack(
      children: [_buildReader(), _buildTopBar(), _buildControlBar()],
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
              '正在加载原生阅读器...',
              style: TextStyle(
                fontSize: 16,
                color: _currentTheme.textColor.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '更快的性能，更流畅的体验',
              style: TextStyle(
                fontSize: 14,
                color: _currentTheme.textColor.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_stories_outlined,
                        size: 64,
                        color: Colors.blue.shade400,
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
                        _errorMessage,
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentTheme.sliderActiveColor,
                          foregroundColor: Colors.white,
                        ),
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
  }

  Widget _buildReader() {
    return ControlledFlutterAdvancedReaderWidget(
      text: _bookContent,
      textStyle: TextStyle(
        fontSize: _fontSize,
        height: _lineHeight,
        letterSpacing: _letterSpacing,
        color: _currentTheme.textColor,
        fontFamily: _fontFamily == 'System' ? null : _fontFamily,
      ),
      padding: EdgeInsets.all(_pageMargin),
      backgroundColor: _currentTheme.backgroundColor,
      controller: _readerController,
      onPageChanged: _onPageChanged,
      onTextSelected: _onTextSelected,
      onMiddleClick: _toggleControlBar,
      enablePageIndicator: false, // 我们自己实现指示器
      enableTextSelection: true,
    );
  }

  Widget _buildTopBar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      top: _showControlBar ? 0 : -80.0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _showControlBar ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !_showControlBar,
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
                  icon: Icon(Icons.arrow_back, color: _currentTheme.textColor),
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
                        '原生阅读器 • ${widget.book.author}',
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
                    Text(
                      '$_currentPageNum/$_totalPages',
                      style: TextStyle(
                        color: _currentTheme.textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(_currentProgress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: _currentTheme.textColor.withOpacity(0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      bottom: _showControlBar ? 0 : -150.0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _showControlBar ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !_showControlBar,
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
                Container(
                  width: 40,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _currentTheme.iconColor.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _buildToolbar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToolbarButton(
            Icons.format_list_bulleted,
            '目录',
            _showTableOfContents,
          ),
          _buildToolbarButton(Icons.record_voice_over, '朗读', _showTtsPanel),
          _buildToolbarButton(Icons.bookmark_add, '书签', _addBookmark),
          _buildToolbarButton(Icons.search, '搜索', _showSearchDialog),
          _buildToolbarButton(Icons.tune, '设置', _showSettingsPanel),
        ],
      ),
    );
  }

  Widget _buildToolbarButton(IconData icon, String label, VoidCallback onTap) {
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

  // --- 功能方法 ---

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
            textToRead: _getCurrentPageText(),
            onClose: () => Navigator.pop(context),
          ),
        );
      },
    );
  }

  String _getCurrentPageText() {
    final info = _readerController.getCurrentReadingInfo();
    if (info == null) return '当前页面内容';

    // 这里可以实现获取当前页面文本的逻辑
    return '当前页面内容';
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _currentTheme.backgroundColor,
          title: Text('搜索文本', style: TextStyle(color: _currentTheme.textColor)),
          content: TextField(
            controller: _searchController,
            style: TextStyle(color: _currentTheme.textColor),
            decoration: InputDecoration(
              hintText: '输入搜索内容',
              hintStyle: TextStyle(
                color: _currentTheme.textColor.withOpacity(0.5),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '取消',
                style: TextStyle(
                  color: _currentTheme.textColor.withOpacity(0.6),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _performSearch(_searchController.text);
              },
              child: const Text('搜索'),
            ),
          ],
        );
      },
    );
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;

    final results = _readerController.searchText(query);
    _showMessage('找到 ${results.length} 个结果');

    // 这里可以实现搜索结果导航
  }

  void _showSettingsPanel() {
    _showMessage('设置面板功能开发中');
  }

  void _goToChapter(Chapter chapter) {
    // 简单的章节跳转实现
    _showMessage('跳转到: ${chapter.title}');
  }

  void _goToBookmark(Bookmark bookmark) {
    if (bookmark.pageNumber > 0) {
      _readerController.goToPage(bookmark.pageNumber);
      Navigator.pop(context);
      _showMessage('跳转到书签: ${bookmark.note}');
    }
  }

  Future<void> _addBookmark() async {
    try {
      if (widget.book.id == null || _currentPageNum == 0) {
        _showMessage('无法添加书签：书籍信息不完整');
        return;
      }

      final currentPage = _currentPageNum;
      final existingBookmark = await _bookmarkDao.getBookmarkOnPage(
        widget.book.id!,
        currentPage,
      );

      if (existingBookmark != null) {
        await _bookmarkDao.deleteBookmark(existingBookmark.id!);
        setState(() {
          _bookmarks.removeWhere((b) => b.id == existingBookmark.id);
        });
        _showMessage('书签已移除');
      } else {
        final bookmark = Bookmark(
          bookId: widget.book.id!,
          pageNumber: currentPage,
          note: '第${currentPage}页',
        );

        final id = await _bookmarkDao.insertBookmark(bookmark);
        setState(() {
          _bookmarks.add(bookmark.copyWith(id: id));
        });
        _showMessage('书签已添加');
      }
    } catch (e) {
      _showMessage('书签操作失败: $e');
    }
  }
}
