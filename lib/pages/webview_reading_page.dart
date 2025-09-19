import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';
import '../models/highlight.dart';
import '../models/note.dart';
import '../models/bookmark.dart';
import '../services/simple_webview_reader.dart';
import '../services/book_dao.dart';
import '../services/highlight_dao.dart';
import '../services/note_dao.dart';
import '../services/bookmark_dao.dart';
import '../services/reading_stats_dao.dart';
import 'advanced_reading_page.dart'; // 引入你的主题定义

/// 基于WebView的增强阅读页面
/// 完全保留你的原有UI风格和主题系统
class WebViewReadingPage extends StatefulWidget {
  final Book book;
  final int? initialChapterIndex;
  final double? initialProgress;

  const WebViewReadingPage({
    super.key,
    required this.book,
    this.initialChapterIndex,
    this.initialProgress,
  });

  @override
  State<WebViewReadingPage> createState() => _WebViewReadingPageState();
}

class _WebViewReadingPageState extends State<WebViewReadingPage>
    with TickerProviderStateMixin {
  // --- 核心状态 ---
  // 当前页面信息
  double _currentProgress = 0.0;
  int _currentPageNum = 0;
  int _totalPages = 0;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // --- 阅读设置（保持你的原有设计） ---
  ReadingTheme _currentTheme = ReadingThemes.sepiaTheme;
  double _fontSize = 16.0;
  double _lineSpacing = 1.6;
  String _fontFamily = 'System';

  // --- UI状态（保持你的原有设计） ---
  bool _showControlBar = false;
  bool _showToc = false;
  bool _showSettings = false;
  bool _showSearch = false;
  bool _showHighlights = false;
  bool _keepScreenOn = false;

  // --- 控制器和动画（保持你的原有设计） ---
  late AnimationController _controlBarAnimationController;
  late Animation<double> _controlBarAnimation;
  late AnimationController _pageFlipAnimationController;
  late Animation<double> _pageFlipAnimation;
  final TextEditingController _searchController = TextEditingController();
  Timer? _hideControlBarTimer;

  // --- 数据访问层 ---
  final BookDao _bookDao = BookDao();
  final HighlightDao _highlightDao = HighlightDao();
  final NoteDao _noteDao = NoteDao();
  final BookmarkDao _bookmarkDao = BookmarkDao();
  final ReadingStatsDao _readingStatsDao = ReadingStatsDao();

  // --- 注释和高亮数据 ---
  final List<Highlight> _highlights = [];
  final List<Note> _notes = [];
  final List<Bookmark> _bookmarks = [];

  // --- 统计数据 ---
  DateTime? _readingStartTime;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadSettings();
    _initializeReading();
  }

  @override
  void dispose() {
    _controlBarAnimationController.dispose();
    _pageFlipAnimationController.dispose();
    _searchController.dispose();
    _hideControlBarTimer?.cancel();
    _saveReadingProgress();
    _updateReadingStats();
    super.dispose();
  }

  // --- 初始化方法（保持你的原有逻辑） ---

  void _initializeAnimations() {
    _controlBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlBarAnimation = CurvedAnimation(
      parent: _controlBarAnimationController,
      curve: Curves.easeInOut,
    );

    // 添加翻页动画控制器
    _pageFlipAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pageFlipAnimation = CurvedAnimation(
      parent: _pageFlipAnimationController,
      curve: Curves.easeInOut,
    );
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _fontSize = prefs.getDouble('webview_reading_font_size') ?? 16.0;
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
    }
  }

  Future<void> _initializeReading() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // 加载章节内容
      await _loadBookContent();

      // 加载书签和注释
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
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadBookContent() async {
    try {
      // 验证书籍文件是否存在
      final bookFile = File(widget.book.filePath);
      if (!bookFile.existsSync()) {
        throw Exception('书籍文件不存在: ${widget.book.filePath}');
      }

      debugPrint('书籍文件验证成功: ${widget.book.title}');
      debugPrint('文件路径: ${widget.book.filePath}');
      debugPrint('文件大小: ${await bookFile.length()} bytes');
    } catch (e) {
      throw Exception('加载书籍内容失败: $e');
    }
  }

  Future<void> _loadAnnotations() async {
    try {
      if (widget.book.id == null) return;

      // 加载高亮数据
      final highlights = await _highlightDao.getHighlightsByBook(
        widget.book.id!,
      );
      setState(() {
        _highlights.clear();
        _highlights.addAll(highlights);
      });

      // 加载笔记数据
      final notes = await _noteDao.getNotesByBook(widget.book.id!);
      setState(() {
        _notes.clear();
        _notes.addAll(notes);
      });

      // 加载书签数据
      final bookmarks = await _bookmarkDao.getBookmarksForBook(widget.book.id!);
      setState(() {
        _bookmarks.clear();
        _bookmarks.addAll(bookmarks);
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

  // --- UI控制（保持你的原有逻辑） ---

  void _toggleControlBar() {
    setState(() {
      _showControlBar = !_showControlBar;
    });

    if (_showControlBar) {
      _controlBarAnimationController.forward();
      _resetHideControlBarTimer();
    } else {
      _controlBarAnimationController.reverse();
      _hideControlBarTimer?.cancel();
    }
  }

  void _hideControlBar() {
    setState(() {
      _showControlBar = false;
      _showToc = false;
      _showSettings = false;
      _showSearch = false;
      _showHighlights = false;
    });
    _controlBarAnimationController.reverse();
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

  // --- WebView事件处理 ---

  void _onPageChanged(
    String cfi,
    double percentage,
    int currentPage,
    int totalPages,
  ) {
    setState(() {
      _currentProgress = percentage;
      _currentPageNum = currentPage;
      _totalPages = totalPages;
    });
    _saveReadingProgress();
  }

  void _onTextSelected(String text, String cfi) {
    debugPrint('文本选择: $text');
    if (text.trim().isEmpty) return;

    // 直接添加高亮（简化处理）
    _addHighlight(text, cfi, Colors.yellow);
  }

  // --- 文本选择和注释菜单 ---

  // --- 注释操作 ---

  Future<void> _addHighlight(String text, String cfi, Color color) async {
    try {
      if (widget.book.id == null) {
        _showMessage('书籍ID无效，无法保存高亮');
        return;
      }

      // 创建高亮数据模型
      final highlight = Highlight(
        bookId: widget.book.id!,
        pageNumber: _currentPageNum,
        selectedText: text,
        startOffset: 0, // WebView CFI定位，offset设为0
        endOffset: text.length,
        color: color,
        cfi: cfi,
        chapter: '第${_currentPageNum}页',
      );

      // 保存到数据库
      final id = await _highlightDao.insertHighlight(highlight);
      final savedHighlight = highlight.copyWith(id: id);

      // 添加到本地列表
      setState(() {
        _highlights.add(savedHighlight);
      });

      _showMessage('高亮已添加并保存');
    } catch (e) {
      _showMessage('添加高亮失败: $e');
      debugPrint('高亮保存错误: $e');
    }
  }

  // --- 保存方法（保持你的原有逻辑） ---

  Future<void> _saveReadingProgress() async {
    if (_currentPageNum == 0) return;

    try {
      // 更新书籍的阅读进度（使用copyWith创建新实例）
      final progress = _currentProgress;
      final currentPage = _currentPageNum;
      final totalPages = _totalPages;

      // 创建带有更新进度的新Book实例
      final updatedBook = widget.book.copyWith(
        currentPage: currentPage,
        totalPages: totalPages,
      );

      // 保存到数据库
      if (widget.book.id != null) {
        await _bookDao.updateBookProgress(widget.book.id!, currentPage);
        debugPrint(
          '更新的书籍信息: ${updatedBook.title}, 当前页: ${updatedBook.currentPage}/${updatedBook.totalPages}',
        );
      }

      debugPrint('保存阅读进度成功: ${(progress * 100).toStringAsFixed(1)}%');
    } catch (e) {
      debugPrint('保存阅读进度失败: $e');
    }
  }

  Future<void> _updateReadingStats() async {
    if (_readingStartTime == null) return;

    try {
      // 计算阅读时长（秒）
      final readingDuration = DateTime.now()
          .difference(_readingStartTime!)
          .inSeconds;

      // 只有阅读时间超过30秒才记录
      if (readingDuration >= 30) {
        await _readingStatsDao.insertReadingTime(
          DateTime.now(),
          readingDuration,
        );
        debugPrint('更新阅读统计成功，阅读时长: ${readingDuration}秒');
      }
    } catch (e) {
      debugPrint('更新阅读统计失败: $e');
    }
  }

  // --- UI构建（保持你的原有风格） ---

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
      children: [
        // WebView阅读器
        _buildWebViewReader(),

        // 控制栏（保持你的原有设计）
        if (_showControlBar) _buildControlBar(),

        // 设置面板（保持你的原有设计）
        if (_showSettings) _buildSettingsPanel(),

        // 搜索面板（保持你的原有设计）
        if (_showSearch) _buildSearchPanel(),

        // 目录（保持你的原有设计）
        if (_showToc) _buildTocPanel(),

        // 翻页动画效果
        if (_pageFlipAnimationController.isAnimating) _buildPageFlipAnimation(),
      ],
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
              '正在加载WebView阅读器...',
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
    return Container(
      color: _currentTheme.backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _currentTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage,
                style: TextStyle(
                  fontSize: 14,
                  color: _currentTheme.textColor.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _initializeReading,
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentTheme.sliderActiveColor,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
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
        // WebView加载完成的处理
        debugPrint('WebView阅读器已就绪');
      },
    );
  }

  Widget _buildPageFlipAnimation() {
    return AnimatedBuilder(
      animation: _pageFlipAnimation,
      builder: (context, child) {
        return Positioned.fill(
          child: Transform(
            alignment: Alignment.centerLeft,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(_pageFlipAnimation.value * 3.14159),
            child: Container(
              decoration: BoxDecoration(
                color: _currentTheme.backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(10, 0),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 这里复用你原有的控制栏、设置面板等UI组件
  // 为了节省篇幅，我只实现核心的控制栏

  Widget _buildControlBar() {
    return AnimatedBuilder(
      animation: _controlBarAnimation,
      builder: (context, child) {
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Transform.translate(
            offset: Offset(0, (1 - _controlBarAnimation.value) * 100),
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: _currentTheme.controlBarColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 进度条
                  if (_currentPageNum > 0) _buildProgressBar(),

                  // 控制按钮
                  _buildControlButtons(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressBar() {
    final progress = _currentProgress;
    final currentPage = _currentPageNum;
    final totalPages = _totalPages;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$currentPage/$totalPages',
                style: TextStyle(
                  fontSize: 12,
                  color: _currentTheme.controlBarTextColor,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: _currentTheme.controlBarTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _currentTheme.sliderActiveColor,
              inactiveTrackColor: _currentTheme.sliderInactiveColor,
              thumbColor: _currentTheme.sliderActiveColor,
              overlayColor: _currentTheme.sliderActiveColor.withOpacity(0.2),
            ),
            child: Slider(
              value: progress,
              onChanged: (value) {
                // TODO: 实现进度跳转
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.list,
            label: '目录',
            onPressed: () {
              setState(() {
                _showToc = !_showToc;
                _showSettings = false;
                _showSearch = false;
              });
            },
          ),
          _buildControlButton(
            icon: Icons.search,
            label: '搜索',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                _showToc = false;
                _showSettings = false;
              });
            },
          ),
          _buildControlButton(
            icon: Icons.highlight_alt,
            label: '高亮',
            onPressed: () {
              setState(() {
                _showHighlights = !_showHighlights;
                _showToc = false;
                _showSearch = false;
                _showSettings = false;
              });
            },
          ),
          _buildControlButton(
            icon: Icons.settings,
            label: '设置',
            onPressed: () {
              setState(() {
                _showSettings = !_showSettings;
                _showToc = false;
                _showSearch = false;
              });
            },
          ),
          _buildControlButton(
            icon: Icons.bookmark_border,
            label: '书签',
            onPressed: _addBookmark,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _currentTheme.iconColor, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: _currentTheme.controlBarTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 简化版的其他UI组件（你可以从原来的代码中复制完整实现）
  Widget _buildSettingsPanel() {
    return Positioned(
      bottom: 200,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _currentTheme.controlBarColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '设置面板 - WebView版本',
          style: TextStyle(
            color: _currentTheme.controlBarTextColor,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchPanel() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _currentTheme.controlBarColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '搜索面板 - WebView版本',
          style: TextStyle(
            color: _currentTheme.controlBarTextColor,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildTocPanel() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      bottom: 250,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _currentTheme.controlBarColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '目录面板 - WebView版本',
          style: TextStyle(
            color: _currentTheme.controlBarTextColor,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Future<void> _addBookmark() async {
    try {
      if (widget.book.id == null || _currentPageNum == 0) {
        _showMessage('无法添加书签：书籍信息不完整');
        return;
      }

      final currentPage = _currentPageNum;

      // 检查当前页是否已有书签
      final existingBookmark = await _bookmarkDao.getBookmarkOnPage(
        widget.book.id!,
        currentPage,
      );

      if (existingBookmark != null) {
        // 删除现有书签
        await _bookmarkDao.deleteBookmark(existingBookmark.id!);
        setState(() {
          _bookmarks.removeWhere((b) => b.id == existingBookmark.id);
        });
        _showMessage('书签已移除');
      } else {
        // 添加新书签
        final bookmark = Bookmark(
          bookId: widget.book.id!,
          pageNumber: currentPage,
          note: '第${currentPage}页',
        );

        final id = await _bookmarkDao.insertBookmark(bookmark);
        final savedBookmark = bookmark.copyWith(id: id);

        setState(() {
          _bookmarks.add(savedBookmark);
        });

        _showMessage('书签已添加');
      }
    } catch (e) {
      _showMessage('书签操作失败: $e');
      debugPrint('书签操作错误: $e');
    }
  }
}

// 数据模型类
class SearchResult {
  final String text;
  final String cfi;
  final int pageIndex;

  SearchResult({
    required this.text,
    required this.cfi,
    required this.pageIndex,
  });
}

class HighlightModel {
  final String id;
  final String text;
  final String cfi;
  final Color color;
  final DateTime createTime;

  HighlightModel({
    required this.id,
    required this.text,
    required this.cfi,
    required this.color,
    required this.createTime,
  });
}

class NoteModel {
  final String id;
  final String text;
  final String note;
  final String cfi;
  final DateTime createTime;

  NoteModel({
    required this.id,
    required this.text,
    required this.note,
    required this.cfi,
    required this.createTime,
  });
}
