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
import 'advanced_reading_page.dart'; // 引入你的主题定义
import 'webview_reading_page_enhanced_toc.dart';

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
  ReadingTheme _currentTheme = ReadingThemes.dayTheme;
  double _fontSize = 16.0;
  double _lineSpacing = 1.6;
  double _letterSpacing = 0.2;
  double _pageMargin = 16.0;
  double _horizontalPadding = 16.0; // 新增：左右留白距离
  String _fontFamily = 'System';

  // WebView Reader引用 (暂未实现)
  // SimpleWebViewReader? _webViewReader;

  // --- UI状态（保持你的原有设计） ---
  bool _showControlBar = false;
  bool _keepScreenOn = false;

  // --- 控制器和动画（保持你的原有设计） ---
  late AnimationController _controlBarAnimationController;
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
  final EnhancedBookService _bookService = EnhancedBookService();

  // --- 注释和高亮数据 ---
  final List<Highlight> _highlights = [];
  final List<Note> _notes = [];
  final List<Bookmark> _bookmarks = [];
  final List<Chapter> _chapters = [];

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
    // 优化资源释放，减少退出卡顿
    _controlBarAnimationController.dispose();
    _pageFlipAnimationController.dispose();
    _searchController.dispose();
    _hideControlBarTimer?.cancel();

    // 异步保存数据，避免阻塞UI线程
    _saveDataAsync();

    super.dispose();
  }

  /// 异步保存阅读数据，避免阻塞UI
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

  // --- 初始化方法（保持你的原有逻辑） ---

  void _initializeAnimations() {
    _controlBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300), // 恢复合理的标准动画时间
      vsync: this,
    );

    // 添加翻页动画控制器
    _pageFlipAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800), // 恢复合理的翻页动画时间
      vsync: this,
    );
    _pageFlipAnimation = CurvedAnimation(
      parent: _pageFlipAnimationController,
      curve: Curves.easeInOutCubic, // 使用更自然的缓动曲线
    );
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 根据屏幕尺寸计算默认字体大小
      final defaultFontSize = _calculateDefaultFontSize();

      setState(() {
        _fontSize =
            prefs.getDouble('webview_reading_font_size') ?? defaultFontSize;
        _lineSpacing = prefs.getDouble('webview_reading_line_spacing') ?? 1.6;
        _letterSpacing =
            prefs.getDouble('webview_reading_letter_spacing') ?? 0.2;
        _pageMargin = prefs.getDouble('webview_reading_page_margin') ?? 16.0;
        _horizontalPadding =
            prefs.getDouble('webview_reading_horizontal_padding') ?? 16.0;
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

  /// 根据屏幕尺寸计算默认字体大小
  double _calculateDefaultFontSize() {
    final screenHeight = MediaQuery.of(context).size.height;

    // 精确的iPhone系列识别
    if (screenHeight > 920) {
      // iPhone 16 Pro Max (956点高)
      return 22.0;
    } else if (screenHeight > 880) {
      // iPhone 16 Pro (932点高)
      return 21.0;
    } else if (screenHeight > 850) {
      // iPhone 16 Plus (874点高)
      return 20.0;
    } else if (screenHeight > 800) {
      // iPhone 16 标准版 (852点高)
      return 19.0;
    } else if (screenHeight > 700) {
      // iPhone 12/13/14/15 系列
      return 17.0;
    } else {
      // 小屏幕设备 (iPhone SE 等)
      return 16.0;
    }
  }

  /// 保存阅读设置
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setDouble('webview_reading_font_size', _fontSize);
      await prefs.setDouble('webview_reading_line_spacing', _lineSpacing);
      await prefs.setDouble('webview_reading_letter_spacing', _letterSpacing);
      await prefs.setDouble('webview_reading_page_margin', _pageMargin);
      await prefs.setDouble(
        'webview_reading_horizontal_padding',
        _horizontalPadding,
      );
      await prefs.setString('webview_reading_font_family', _fontFamily);
      await prefs.setBool('webview_reading_keep_screen_on', _keepScreenOn);

      // 保存主题设置
      String themeName = 'day';
      if (_currentTheme == ReadingThemes.dayTheme) {
        themeName = 'day';
      } else if (_currentTheme == ReadingThemes.nightTheme) {
        themeName = 'night';
      } else if (_currentTheme == ReadingThemes.sepiaTheme) {
        themeName = 'sepia';
      }
      await prefs.setString('webview_reading_theme', themeName);

      debugPrint('阅读设置已保存: 字号=${_fontSize}, 主题=${themeName}');
    } catch (e) {
      debugPrint('保存设置失败: $e');
    }
  }

  /// 更新WebView显示设置（实时响应）
  void _updateWebViewSettings() {
    // 强制重新构建SimpleWebViewReader以应用新的设置
    // 这是最简单可靠的方法，因为SimpleWebViewReader会接收新的参数
    setState(() {
      // setState会触发build方法，重新创建SimpleWebViewReader
      // 新的字体设置、主题颜色都会传递给SimpleWebViewReader构造函数
    });

    // 立即保存设置，确保全局响应
    _saveSettings();

    // 发送全局字体设置更新通知
    _notifyGlobalFontSettingsChanged();

    debugPrint(
      '🔄 WebView设置已更新 - 字号: ${_fontSize.toStringAsFixed(1)}px, '
      '行距: ${_lineSpacing.toStringAsFixed(1)}, '
      '字间距: ${_letterSpacing.toStringAsFixed(1)}pt, '
      '字体: $_fontFamily',
    );
    debugPrint(
      '🎨 主题设置 - ${_currentTheme.name}: '
      '背景色: ${_currentTheme.backgroundColor.value.toRadixString(16)}, '
      '文字色: ${_currentTheme.textColor.value.toRadixString(16)}',
    );
    debugPrint(
      '📐 页面设置 - 边距: ${_pageMargin.toStringAsFixed(1)}px, '
      '左右留白: ${_horizontalPadding.toStringAsFixed(1)}px',
    );
  }

  /// 通知全局字体设置变更
  void _notifyGlobalFontSettingsChanged() {
    // 创建全局设置更新通知
    try {
      // 这里可以添加EventBus或Provider通知机制
      // 暂时使用debugPrint记录，将来可以扩展为全局状态管理
      debugPrint('🌐 全局字体设置已更新 - 所有相关UI组件将立即响应字体变更');

      // 如果有其他页面或组件需要响应字体变更，在这里添加通知逻辑
      // 例如: EventBus.instance.fire(FontSettingsChangedEvent(_fontSize, _fontFamily));
    } catch (e) {
      debugPrint('⚠️ 全局字体设置通知发送失败: $e');
    }
  }

  /// 显示删除书籍确认对话框
  void _showDeleteBookDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _currentTheme.backgroundColor,
        title: Text(
          '删除书籍',
          style: TextStyle(
            color: _currentTheme.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '确定要删除这本书籍的记录吗？',
              style: TextStyle(color: _currentTheme.textColor.withOpacity(0.8)),
            ),
            const SizedBox(height: 8),
            Text(
              '书籍标题：${widget.book.title}',
              style: TextStyle(
                color: _currentTheme.textColor.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '注意：这只会删除应用中的书籍记录，不会删除原始文件。',
                style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(color: _currentTheme.textColor.withOpacity(0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // 关闭对话框
              await _deleteBookRecord();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 删除书籍记录
  Future<void> _deleteBookRecord() async {
    try {
      // 删除书籍记录
      await _bookDao.deleteBook(widget.book.id!);

      // 显示成功消息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除书籍记录：${widget.book.title}'),
            backgroundColor: Colors.green.shade400,
          ),
        );

        // 返回上一页
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('删除书籍记录失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败：$e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
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

      // 加载章节目录
      await _loadChapters();

      // 加载书签和注释
      await _loadAnnotations();

      // 初始化TTS服务
      await _initializeTts();

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
        // 简化错误消息，提供用户友好的提示
        if (e.toString().contains('书籍文件不存在')) {
          _errorMessage = '书籍文件似乎已被移动或删除。请尝试重新导入此书籍。';
        } else if (e.toString().contains('加载书籍内容失败')) {
          _errorMessage = '无法读取书籍文件。文件可能已损坏或格式不支持。';
        } else {
          _errorMessage = '初始化阅读器时出现问题。请稍后重试。';
        }
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

      setState(() {
        _chapters.clear();
        _chapters.addAll(chapters);
      });

      debugPrint('成功加载章节目录，共${_chapters.length}章');
    } catch (e) {
      debugPrint('加载章节目录失败: $e');
    }
  }

  Future<void> _initializeTts() async {
    try {
      // TTS服务在构造时已自动初始化
      debugPrint('TTS服务初始化成功');
    } catch (e) {
      debugPrint('TTS服务初始化失败: $e');
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

        // 顶部标题栏
        _buildTopBar(),

        // 底部控制栏
        _buildControlBar(),

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
            // 顶部导航栏
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
            // 错误内容
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 错误图标
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.book_outlined,
                          size: 40,
                          color: Colors.orange.shade400,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // 错误标题
                      Text(
                        '无法打开书籍',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _currentTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 错误描述
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
                      // 操作按钮
                      Column(
                        children: [
                          // 重试按钮
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _initializeReading,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _currentTheme.sliderActiveColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                '重新加载',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 删除记录按钮
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _showDeleteBookDialog,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade400,
                                side: BorderSide(color: Colors.red.shade400),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                '删除书籍记录',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 返回书库按钮
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: _currentTheme.textColor
                                    .withOpacity(0.8),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text(
                                '返回书库',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    final Color toolbarBgColor = _currentTheme.controlBarColor;
    final Color handleColor = _currentTheme.iconColor.withOpacity(0.6);

    // 使用AnimatedPositioned实现伸出和收回动画，参考enhanced版本
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300), // 恢复合理的动画时间
      curve: Curves.easeInOutCubic, // 更自然的缓动曲线
      bottom: _showControlBar ? 0 : -150.0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300), // 同步透明度动画
        opacity: _showControlBar ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !_showControlBar,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 8),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Container(
                padding: EdgeInsets.only(bottom: bottomPadding + 8),
                decoration: BoxDecoration(
                  color: toolbarBgColor, // 完全不透明，确保可见
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.08),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 拖拽指示器
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 3,
                          decoration: BoxDecoration(
                            color: handleColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildToolbarButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarButtons() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), // 优化padding，增加垂直空间
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _ModernToolbarButton(
              icon: Icons.format_list_bulleted_rounded,
              label: '目录',
              onTap: _showTableOfContents,
              iconColor: _currentTheme.controlBarTextColor,
              pressedColor: _currentTheme.iconColor.withOpacity(0.15),
              iconSize: 22, // 略大的图标
              fontSize: 11, // 略大的字体
            ),
          ),
          const SizedBox(width: 6), // 按钮间距
          Expanded(
            child: _ModernToolbarButton(
              icon: Icons.record_voice_over_rounded,
              label: '朗读',
              onTap: _showTtsPanel,
              iconColor: _currentTheme.controlBarTextColor,
              pressedColor: _currentTheme.iconColor.withOpacity(0.15),
              iconSize: 22,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ModernToolbarButton(
              icon: Icons.bookmark_add_rounded,
              label: '书签',
              onTap: _addBookmark,
              iconColor: _currentTheme.controlBarTextColor,
              pressedColor: _currentTheme.iconColor.withOpacity(0.15),
              iconSize: 22,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ModernToolbarButton(
              icon: Icons.share_rounded,
              label: '分享',
              onTap: () {
                _showMessage('分享功能开发中');
              },
              iconColor: _currentTheme.controlBarTextColor,
              pressedColor: _currentTheme.iconColor.withOpacity(0.15),
              iconSize: 22,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ModernToolbarButton(
              icon: Icons.tune_rounded,
              label: '设置',
              onTap: _showSettingsPanel,
              iconColor: _currentTheme.controlBarTextColor,
              pressedColor: _currentTheme.iconColor.withOpacity(0.15),
              iconSize: 22,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    // 根据背景颜色动态调整工具栏颜色
    final isLightBackground =
        _currentTheme.backgroundColor.computeLuminance() > 0.5;
    final textColor = isLightBackground ? Colors.black87 : Colors.white;
    final iconBgColor = isLightBackground
        ? Colors.grey.withOpacity(0.2)
        : Colors.grey.withOpacity(0.3);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300), // 恢复合理的动画时间
      curve: Curves.easeInOutCubic, // 更自然的缓动曲线
      top: _showControlBar ? 0 : -80.0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300), // 同步透明度动画
        opacity: _showControlBar ? 1.0 : 0.0,
        curve: Curves.easeInOutCubic, // 统一曲线
        child: IgnorePointer(
          ignoring: !_showControlBar,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // 适度的毛玻璃效果
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: statusBarHeight + 8,
                  left: 16,
                  right: 16,
                  bottom: 12,
                ),
                decoration: BoxDecoration(
                  color: Color.lerp(
                    _currentTheme.backgroundColor,
                    isLightBackground ? Colors.white : Colors.black,
                    0.15,
                  )!, // 完全不透明，确保可见
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border.all(
                    color: isLightBackground
                        ? Colors.black.withOpacity(0.08)
                        : Colors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back_ios_rounded,
                          color: textColor,
                          size: 20,
                        ),
                        padding: const EdgeInsets.all(8),
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
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.book.author,
                            style: TextStyle(
                              color: textColor.withOpacity(0.7),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 页码显示
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${_currentPageNum}/${_totalPages}',
                            style: TextStyle(
                              color: isLightBackground
                                  ? Colors.blue[700]
                                  : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // 百分比显示
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _currentTheme.sliderActiveColor.withOpacity(
                              0.2,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${(_currentProgress * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: isLightBackground
                                  ? _currentTheme.sliderActiveColor
                                  : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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

  /// 显示TTS朗读面板
  void _showTtsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: MediaQuery.of(context).size.height * 0.6,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                decoration: _getModalDecoration(),
                child: TtsControlPanel(
                  textToRead: '当前页面内容', // TODO: 获取当前页面文本
                  onClose: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 显示设置面板
  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: MediaQuery.of(context).size.height * 0.75,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Container(
                    decoration: _getModalDecoration(),
                    child: Column(
                      children: [
                        // 拖拽指示器
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: _getModalIconColor(),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        // 设置内容
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 字体设置部分 - 最重要的设置
                                _buildSettingSection(
                                  title: '字体设置',
                                  icon: Icons.font_download,
                                  description: '调整文字显示效果，实时预览',
                                  children: [
                                    _buildFontSizeSlider(),
                                    const SizedBox(height: 20),
                                    _buildLineSpacingSlider(),
                                    const SizedBox(height: 20),
                                    _buildLetterSpacingSlider(),
                                    const SizedBox(height: 20),
                                    _buildFontFamilySelector(),
                                  ],
                                ),

                                const SizedBox(height: 32),

                                // 页面设置部分
                                _buildSettingSection(
                                  title: '页面设置',
                                  icon: Icons.article_rounded,
                                  description: '调整页面布局和留白',
                                  children: [
                                    _buildPageMarginSlider(),
                                    const SizedBox(height: 20),
                                    _buildHorizontalPaddingSlider(),
                                  ],
                                ),

                                const SizedBox(height: 32),

                                // 主题设置部分
                                _buildSettingSection(
                                  title: '主题设置',
                                  icon: Icons.color_lens,
                                  description: '选择合适的阅读配色方案',
                                  children: [_buildThemeSelector()],
                                ),

                                const SizedBox(height: 32),

                                // 阅读模式设置部分
                                _buildSettingSection(
                                  title: '阅读模式',
                                  icon: Icons.chrome_reader_mode,
                                  description: '优化阅读体验设置',
                                  children: [
                                    _buildScreenOnSwitch(),
                                    const SizedBox(height: 16),
                                    _buildFullScreenSwitch(),
                                  ],
                                ),

                                // 底部安全区域
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).padding.bottom +
                                      20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // 底部按钮
                        Container(
                          padding: EdgeInsets.only(
                            left: 24,
                            right: 24,
                            bottom: MediaQuery.of(context).padding.bottom + 20,
                            top: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: _getModalDividerColor(),
                                width: 1,
                              ),
                            ),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getModalAccentColor(),
                                foregroundColor: _getModalBackgroundColor(),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                '完成',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 构建设置分组
  /// 为模态框提供统一的主题配置
  BoxDecoration _getModalDecoration() {
    return BoxDecoration(
      color: _currentTheme.controlBarColor.withOpacity(0.98),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      border: Border.all(
        color: _currentTheme.iconColor.withOpacity(0.3),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: _currentTheme.textColor.withOpacity(0.1),
          blurRadius: 20,
          offset: const Offset(0, -5),
        ),
      ],
    );
  }

  /// 获取模态框的图标颜色
  Color _getModalIconColor() {
    switch (_currentTheme.name) {
      case 'day':
        return const Color(0xFF4A4A4A); // 中灰色图标
      case 'night':
        return const Color(0xFFB0B0B0); // 亮灰色图标
      case 'eye_protection':
        return const Color(0xFF2E5A2E); // 中绿色图标
      case 'parchment':
        return const Color(0xFF6B4E3D); // 中棕色图标
      case 'sepia':
        return const Color(0xFF5D4037); // 中棕褐色图标
      default:
        return _currentTheme.iconColor;
    }
  }

  /// 获取模态框的分割线颜色
  Color _getModalDividerColor() {
    switch (_currentTheme.name) {
      case 'day':
        return const Color(0xFFE0E0E0); // 浅灰色分割线
      case 'night':
        return const Color(0xFF3A3A3A); // 深灰色分割线
      case 'eye_protection':
        return const Color(0xFFC8E6C9); // 浅绿色分割线
      case 'parchment':
        return const Color(0xFFD7C4B0); // 浅棕色分割线
      case 'sepia':
        return const Color(0xFFE6D7C3); // 浅棕褐色分割线
      default:
        return _currentTheme.iconColor.withOpacity(0.3);
    }
  }

  /// 获取模态框的背景色
  Color _getModalBackgroundColor() {
    switch (_currentTheme.name) {
      case 'day':
        return const Color(0xFFFAFAFA); // 浅灰白色背景
      case 'night':
        return const Color(0xFF2A2A2A); // 深灰色背景
      case 'eye_protection':
        return const Color(0xFFF1F8F1); // 浅绿色背景
      case 'parchment':
        return const Color(0xFFF7F3ED); // 浅米色背景
      case 'sepia':
        return const Color(0xFFFAF6F0); // 浅棕褐色背景
      default:
        return _currentTheme.controlBarColor;
    }
  }

  /// 获取模态框的强调色
  Color _getModalAccentColor() {
    switch (_currentTheme.name) {
      case 'day':
        return const Color(0xFF2196F3); // 蓝色强调
      case 'night':
        return const Color(0xFF64B5F6); // 亮蓝色强调
      case 'eye_protection':
        return const Color(0xFF4CAF50); // 绿色强调
      case 'parchment':
        return const Color(0xFFD2B48C); // 棕色强调
      case 'sepia':
        return const Color(0xFFCD853F); // 棕褐色强调
      default:
        return _currentTheme.sliderActiveColor;
    }
  }

  Widget _buildSettingSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    String? description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题区域
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _currentTheme.sliderActiveColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: _currentTheme.sliderActiveColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: _currentTheme.controlBarTextColor,
                          ),
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 13,
                              color: _currentTheme.controlBarTextColor
                                  .withOpacity(0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 内容区域
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _currentTheme.backgroundColor.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _currentTheme.sliderInactiveColor.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _currentTheme.textColor.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  /// 构建字体大小滑块
  Widget _buildFontSizeSlider() {
    return _buildSlider(
      label: '字体大小',
      value: _fontSize,
      min: 12.0,
      max: 28.0,
      divisions: 16,
      onChanged: (value) {
        setState(() {
          _fontSize = value;
        });
        _updateWebViewSettings(); // 立即更新WebView显示（包含保存）
      },
      suffix: 'px',
    );
  }

  /// 构建行间距滑块
  Widget _buildLineSpacingSlider() {
    return _buildSlider(
      label: '行间距',
      value: _lineSpacing,
      min: 1.0,
      max: 2.5,
      divisions: 15,
      onChanged: (value) {
        setState(() {
          _lineSpacing = value;
        });
        _updateWebViewSettings(); // 立即更新WebView显示（包含保存）
      },
      suffix: '',
    );
  }

  /// 构建字间距滑块
  Widget _buildLetterSpacingSlider() {
    return _buildSlider(
      label: '字间距',
      value: _letterSpacing,
      min: 0.0,
      max: 2.0,
      divisions: 20,
      onChanged: (value) {
        setState(() {
          _letterSpacing = value;
        });
        _updateWebViewSettings(); // 立即更新WebView显示（包含保存）
      },
      suffix: 'pt',
    );
  }

  /// 构建页面边距滑块
  Widget _buildPageMarginSlider() {
    return _buildSlider(
      label: '页面边距',
      value: _pageMargin,
      min: 8,
      max: 32,
      divisions: 12,
      onChanged: (value) {
        setState(() {
          _pageMargin = value;
        });
        _updateWebViewSettings(); // 立即更新WebView显示（包含保存）
      },
      suffix: 'px',
    );
  }

  /// 构建左右留白滑块
  Widget _buildHorizontalPaddingSlider() {
    return _buildSlider(
      label: '左右留白',
      value: _horizontalPadding,
      min: 8,
      max: 48,
      divisions: 20,
      onChanged: (value) {
        setState(() {
          _horizontalPadding = value;
        });
        _updateWebViewSettings(); // 立即更新WebView显示（包含保存）
      },
      suffix: 'px',
    );
  }

  /// 构建通用滑块
  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String suffix,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: _currentTheme.controlBarTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${value.toStringAsFixed(1)}$suffix',
              style: TextStyle(
                fontSize: 14,
                color: _currentTheme.sliderActiveColor,
                fontWeight: FontWeight.w600,
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
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
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

  /// 构建字体家族选择器
  Widget _buildFontFamilySelector() {
    final fontFamilies = [
      {'name': 'System', 'label': '系统默认'},
      {'name': 'serif', 'label': '衬线字体'},
      {'name': 'sans-serif', 'label': '无衬线字体'},
      {'name': 'monospace', 'label': '等宽字体'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '字体类型',
          style: TextStyle(
            fontSize: 14,
            color: _currentTheme.controlBarTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: fontFamilies.map((font) {
            final isSelected = _fontFamily == font['name'];
            return InkWell(
              onTap: () {
                setState(() {
                  _fontFamily = font['name']!;
                });
                _updateWebViewSettings(); // 立即更新WebView显示（包含保存）
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _currentTheme.sliderActiveColor
                      : _currentTheme.sliderInactiveColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? _currentTheme.sliderActiveColor
                        : _currentTheme.sliderInactiveColor,
                    width: 1,
                  ),
                ),
                child: Text(
                  font['label']!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? Colors.white
                        : _currentTheme.controlBarTextColor,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 构建主题选择器
  Widget _buildThemeSelector() {
    final themes = [
      {'theme': ReadingThemes.dayTheme, 'label': '日间'},
      {'theme': ReadingThemes.nightTheme, 'label': '夜间'},
      {'theme': ReadingThemes.greenTheme, 'label': '护眼绿'},
      {'theme': ReadingThemes.brownTheme, 'label': '牛皮纸'},
      {'theme': ReadingThemes.sepiaTheme, 'label': '古典'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '阅读主题',
          style: TextStyle(
            fontSize: 14,
            color: _currentTheme.controlBarTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: themes.map((themeData) {
            final theme = themeData['theme'] as ReadingTheme;
            final isSelected = theme.name == _currentTheme.name;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _currentTheme = theme;
                });
                _updateWebViewSettings(); // 立即更新WebView显示（包含保存）

                // 延迟关闭设置面板，让用户看到立即的变化
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    Navigator.of(context).pop(); // 关闭设置面板
                  }
                });
              },
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: theme.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? _currentTheme.sliderActiveColor
                            : Colors.grey.withOpacity(0.3),
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: _currentTheme.sliderActiveColor.withOpacity(
                              0.3,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '文',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    themeData['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? _currentTheme.sliderActiveColor
                          : _currentTheme.controlBarTextColor.withOpacity(0.7),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 构建保持屏幕常亮开关
  Widget _buildScreenOnSwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.wb_sunny,
              color: _currentTheme.sliderActiveColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              '保持屏幕常亮',
              style: TextStyle(
                fontSize: 14,
                color: _currentTheme.controlBarTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Switch(
          value: _keepScreenOn,
          onChanged: (value) {
            setState(() {
              _keepScreenOn = value;
            });
            _saveSettings();
            if (value) {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
            } else {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
            }
          },
          activeColor: _currentTheme.sliderActiveColor,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }

  /// 构建全屏模式开关（占位）
  Widget _buildFullScreenSwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.fullscreen,
              color: _currentTheme.sliderActiveColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              '沉浸式阅读',
              style: TextStyle(
                fontSize: 14,
                color: _currentTheme.controlBarTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Switch(
          value: false, // TODO: 实现沉浸式阅读模式
          onChanged: (value) {
            _showMessage('沉浸式阅读功能开发中');
          },
          activeColor: _currentTheme.sliderActiveColor,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }

  /// 显示目录面板
  void _showTableOfContents() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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

  void _goToBookmark(Bookmark bookmark) {
    try {
      Navigator.pop(context);
      // TODO: 实现书签跳转
      _showMessage('跳转到书签: ${bookmark.note}');
    } catch (e) {
      debugPrint('书签跳转失败: $e');
    }
  }

  void _goToChapter(Chapter chapter) {
    try {
      // 如果有href信息，使用WebView定位到指定章节
      if (chapter.href != null && chapter.href!.isNotEmpty) {
        // TODO: 实现WebView章节跳转
        _showMessage('跳转到: ${chapter.title}');
      } else {
        // 否则按页数跳转
        final targetPage = chapter.startPage + 1;
        _showMessage('跳转到第${targetPage}页');
      }
    } catch (e) {
      debugPrint('章节跳转失败: $e');
      _showMessage('跳转失败');
    }
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

// 现代化工具栏按钮
class _ModernToolbarButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final Color pressedColor;
  final double iconSize;
  final double fontSize;

  _ModernToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.iconColor,
    required this.pressedColor,
    this.iconSize = 24.0,
    this.fontSize = 12.0,
  });

  @override
  State<_ModernToolbarButton> createState() => _ModernToolbarButtonState();
}

class _ModernToolbarButtonState extends State<_ModernToolbarButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _colorAnimation = ColorTween(
      begin: Colors.transparent,
      end: widget.pressedColor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: () {
        widget.onTap();
        HapticFeedback.mediumImpact();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              constraints: const BoxConstraints(minWidth: 48, maxWidth: 64),
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: _colorAnimation.value,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    color: widget.iconColor,
                    size: widget.iconSize,
                  ),
                  const SizedBox(height: 2),
                  Flexible(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.iconColor,
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
