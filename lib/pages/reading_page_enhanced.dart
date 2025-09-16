import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';
import '../models/bookmark.dart';
import '../services/book_dao.dart';
import '../services/bookmark_dao.dart';
import '../services/reading_stats_dao.dart';
import '../utils/text_painter_pagination.dart';
import '../widgets/custom_slider_components.dart';
import '../utils/responsive_helper.dart';

// 阅读主题数据结构
class ReadingTheme {
  final String name;
  final String displayName;
  final Color backgroundColor;
  final Color textColor;
  final Color controlBarColor;
  final Color controlBarTextColor;
  final Color iconColor;
  final Color sliderActiveColor;
  final Color sliderInactiveColor;

  const ReadingTheme({
    required this.name,
    required this.displayName,
    required this.backgroundColor,
    required this.textColor,
    required this.controlBarColor,
    required this.controlBarTextColor,
    required this.iconColor,
    required this.sliderActiveColor,
    required this.sliderInactiveColor,
  });
}

// 预设阅读主题
class ReadingThemes {
  static const ReadingTheme dayTheme = ReadingTheme(
    name: 'day',
    displayName: '白天',
    backgroundColor: Color(0xFFFFFBF0),
    textColor: Color(0xFF2C2C2C),
    controlBarColor: Color(0xFFF5F5F5),
    controlBarTextColor: Color(0xFF333333),
    iconColor: Color(0xFF666666),
    sliderActiveColor: Color(0xFF4CAF50),
    sliderInactiveColor: Color(0xFFE0E0E0),
  );

  static const ReadingTheme nightTheme = ReadingTheme(
    name: 'night',
    displayName: '夜间',
    backgroundColor: Color(0xFF121212),
    textColor: Color(0xFFE8E8E8),
    controlBarColor: Color(0xFF1E1E1E),
    controlBarTextColor: Color(0xFFE0E0E0),
    iconColor: Color(0xFFB0B0B0),
    sliderActiveColor: Color(0xFF81C784),
    sliderInactiveColor: Color(0xFF424242),
  );

  static const ReadingTheme eyeProtectionTheme = ReadingTheme(
    name: 'eye_protection',
    displayName: '护眼',
    backgroundColor: Color(0xFFE8F5E8),
    textColor: Color(0xFF2E4A2E),
    controlBarColor: Color(0xFFDCE9DC),
    controlBarTextColor: Color(0xFF1B3A1B),
    iconColor: Color(0xFF4A6E4A),
    sliderActiveColor: Color(0xFF66BB6A),
    sliderInactiveColor: Color(0xFFC8E6C9),
  );

  static const ReadingTheme parchmentTheme = ReadingTheme(
    name: 'parchment',
    displayName: '羊皮纸',
    backgroundColor: Color(0xFFF4F1E8),
    textColor: Color(0xFF8B4513),
    controlBarColor: Color(0xFFE8E2D6),
    controlBarTextColor: Color(0xFF654321),
    iconColor: Color(0xFFA0522D),
    sliderActiveColor: Color(0xFFD2B48C),
    sliderInactiveColor: Color(0xFFF5DEB3),
  );

  static const ReadingTheme sepiaTheme = ReadingTheme(
    name: 'sepia',
    displayName: '棕褐色',
    backgroundColor: Color(0xFFFDF6E3),
    textColor: Color(0xFF5D4E37),
    controlBarColor: Color(0xFFEEE5D0),
    controlBarTextColor: Color(0xFF4A3E28),
    iconColor: Color(0xFF8B7355),
    sliderActiveColor: Color(0xFFCD853F),
    sliderInactiveColor: Color(0xFFF5DEB3),
  );

  static const List<ReadingTheme> allThemes = [
    dayTheme,
    nightTheme,
    eyeProtectionTheme,
    parchmentTheme,
    sepiaTheme,
  ];

  static ReadingTheme getThemeByName(String name) {
    return allThemes.firstWhere(
      (theme) => theme.name == name,
      orElse: () => dayTheme,
    );
  }
}

class ReadingPageEnhanced extends StatefulWidget {
  final Book book;
  const ReadingPageEnhanced({super.key, required this.book});

  @override
  State<ReadingPageEnhanced> createState() => _ReadingPageEnhancedState();
}

class _ReadingPageEnhancedState extends State<ReadingPageEnhanced> {
  // --- DAOs & Controllers ---
  late final PageController _pageController;
  final _bookDao = BookDao();
  final _statsDao = ReadingStatsDao();
  final _bookmarkDao = BookmarkDao();

  // --- Content & Pages ---
  List<String> _pages = [];
  String _bookContent = '';
  int _currentPageIndex = 0;
  Size? _lastScreenSize; // 用于检测屏幕尺寸变化

  // --- UI State ---
  bool _showControls = false; // 默认隐藏工具栏
  Timer? _hideControlsTimer;
  DateTime? _sessionStartTime;

  // --- Bookmark State ---
  List<Bookmark> _bookmarks = [];
  bool _isCurrentPageBookmarked = false;

  // --- Reading Settings ---
  double _fontSize = 18.0;
  double _lineSpacing = 1.8;
  double _letterSpacing = 0.2;
  double _pageMargin = 16.0;
  double _horizontalPadding = 16.0; // 新增：左右留白距离
  ReadingTheme _currentTheme = ReadingThemes.dayTheme; // 当前阅读主题
  bool _autoScroll = false;
  bool _keepScreenOn = false;
  String _fontFamily = 'System';

  // --- UI Text Prefix ---
  static const String _kLoadingPrefix = '📚';
  static const String _kErrorPrefix = '❌';

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.book.currentPage;
    _pageController = PageController(initialPage: _currentPageIndex);
    _sessionStartTime = DateTime.now();

    // 进入沉浸式模式
    _setImmersiveMode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookmarks();
      _initializeReading();
    });
  }

  Future<void> _initializeReading() async {
    try {
      if (mounted) {
        setState(() => _pages = ['$_kLoadingPrefix 正在加载书籍...']);
      }

      await _loadSettings();
      await _loadBookContent();

      if (_bookContent.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 80));
        if (mounted) {
          _splitIntoPages();
        }

        if (_pages.isEmpty || _pages.first.startsWith(_kLoadingPrefix)) {
          throw Exception('分页失败，无法生成有效页面');
        }

        if (mounted) {
          setState(() {});
          // 初始加载完成后，短暂显示工具栏提示用户
          _showControlsInitially();
        }
      } else {
        throw Exception('书籍内容为空，无法加载');
      }
    } catch (e) {
      debugPrint('书籍初始化失败: $e');
      if (mounted) {
        setState(
          () => _pages = ['$_kErrorPrefix 书籍加载失败: $e\n\n请检查文件是否存在或格式是否正确'],
        );
      }
    }
  }

  void _showControlsInitially() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_showControls) {
        _showControlsWithAnimation();
      }
    });
  }

  Future<void> _loadBookContent() async {
    final file = File(widget.book.filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在: ${widget.book.filePath}');
    }

    final fileExtension = widget.book.format.toLowerCase();

    try {
      if (fileExtension == 'epub') {
        debugPrint('开始解析 EPUB: ${widget.book.filePath}');
        _bookContent = await _parseEpubDirectly(widget.book.filePath);
        debugPrint('EPUB 解析完成，长度: ${_bookContent.length}');

        // 验证内容是否足够丰富
        if (_bookContent.length < 1000) {
          debugPrint('⚠️ 警告: EPUB 内容过少 (${_bookContent.length} 字符)，可能解析不完整');
        } else {
          debugPrint('✅ EPUB 内容验证通过，共 ${_bookContent.length} 字符');
        }
      } else if (fileExtension == 'txt') {
        debugPrint('开始读取 TXT: ${widget.book.filePath}');
        try {
          _bookContent = await file.readAsString();
        } catch (e) {
          debugPrint('按 UTF-8 失败，尝试按字节解码: $e');
          final bytes = await file.readAsBytes();
          _bookContent = String.fromCharCodes(bytes);
        }
        debugPrint('TXT 读取完成，长度: ${_bookContent.length}');
      } else {
        debugPrint('按文本读取: ${widget.book.filePath}');
        _bookContent = await file.readAsString();
      }

      if (_bookContent.isEmpty) {
        throw Exception('文件内容为空或读取失败');
      }

      // 预处理文本
      _bookContent = _bookContent
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();

      if (_bookContent.length < 10) {
        throw Exception('文件内容过短，可能不是有效的书籍文件');
      }

      // 打印内容统计信息
      final lines = _bookContent.split('\n').length;
      final words = _bookContent.split(RegExp(r'\s+')).length;
      debugPrint('📈 文本统计: $lines 行, $words 个词, ${_bookContent.length} 字符');
    } catch (e) {
      debugPrint('文件读取异常: $e');
      rethrow;
    }
  }

  // 直接解析 EPUB，避免 isolate 通信限制
  Future<String> _parseEpubDirectly(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('EPUB 文件不存在: $filePath');
      }

      debugPrint('📂 开始读取 EPUB 文件...');
      final bytes = await file.readAsBytes();
      debugPrint('📂 EPUB 文件大小: ${bytes.length} 字节');

      if (bytes.isEmpty) {
        throw Exception('EPUB 文件为空: $filePath');
      }

      debugPrint('📂 开始解析 EPUB 结构...');
      final epubBook = await EpubReader.readBook(bytes);

      // 检查基本信息
      debugPrint('📚 书籍标题: ${epubBook.Title}');
      debugPrint('📚 作者: ${epubBook.Author}');
      debugPrint('📚 章节数量: ${epubBook.Chapters?.length ?? 0}');

      if (epubBook.Chapters == null || epubBook.Chapters!.isEmpty) {
        throw Exception('EPUB 文件无有效章节: $filePath');
      }

      final buffer = StringBuffer();
      final chapters = epubBook.Chapters!;
      int processedChapters = 0;

      // 全面章节处理函数
      void processChapter(dynamic chapter, int depth) {
        try {
          final htmlContent = chapter.HtmlContent;
          if (htmlContent != null && htmlContent.isNotEmpty) {
            final cleanText = _stripHtmlTags(htmlContent);
            if (cleanText.trim().isNotEmpty) {
              if (buffer.isNotEmpty) {
                buffer.writeln('\n${'─' * 30}\n');
              }
              buffer.writeln(cleanText.trim());
              processedChapters++;
              debugPrint(
                '📝 处理章节 $processedChapters, 深度: $depth, 内容长度: ${cleanText.length}',
              );
            }
          }

          // 递归处理子章节
          if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
            debugPrint(
              '📁 章节 "${chapter.Title ?? 'Unknown'}" 包含 ${chapter.SubChapters!.length} 个子章节',
            );
            for (final subChapter in chapter.SubChapters!) {
              processChapter(subChapter, depth + 1);
            }
          }

          // 检查是否有其他可能的内容源
          if (chapter.Anchor != null && chapter.Anchor!.isNotEmpty) {
            debugPrint('🔗 章节附加信息: ${chapter.Anchor}');
          }
        } catch (e) {
          debugPrint('⚠️ 处理章节错误: $e');
        }
      }

      // 处理所有主章节
      for (int i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        final title = chapter.Title ?? '无标题';
        debugPrint('📄 开始处理第 ${i + 1}/${chapters.length} 章: "$title"');
        processChapter(chapter, 0);
      }

      final finalContent = buffer.toString().trim();
      debugPrint('✅ EPUB 解析完成!');
      debugPrint('📈 总章节数: $processedChapters');
      debugPrint('📈 最终内容长度: ${finalContent.length} 字符');
      debugPrint(
        '📈 内容预览: ${finalContent.length > 200 ? '${finalContent.substring(0, 200)}...' : finalContent}',
      );

      if (finalContent.isEmpty) {
        throw Exception('EPUB 解析后内容为空: $filePath');
      }

      return finalContent;
    } catch (e) {
      debugPrint('❌ EPUB 解析失败: $e');
      throw Exception('EPUB 解析失败: $e');
    }
  }

  String _stripHtmlTags(String htmlString) {
    // 增强HTML清理逻辑
    String text = htmlString
        // 先处理段落和换行
        .replaceAll(
          RegExp(r'<\s*\/?\s*(p|div|br|h[1-6])\s*[^>]*>', caseSensitive: false),
          '\n',
        )
        // 移除其他HTML标签
        .replaceAll(RegExp(r'<[^>]*>'), '')
        // 处理HTML实体
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&hellip;', '...')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll(RegExp(r'&[a-zA-Z0-9#]+;'), '') // 移除其他实体
        // 清理多余空格和换行
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\n\s*\n'), '\n\n') // 保留段落间距
        .trim();

    return text;
  }

  void _splitIntoPages() {
    debugPrint('🔄 开始标准化分页处理...');

    if (_bookContent.isEmpty) {
      _pages = ['内容为空'];
      debugPrint('内容为空，分页终止');
      return;
    }

    _pages.clear();

    // 使用标准化分页算法，避免设备差异
    _standardizedPagination(_bookContent);

    if (_currentPageIndex >= _pages.length) {
      _currentPageIndex = _pages.isNotEmpty ? _pages.length - 1 : 0;
    }

    // 更新数据库页数
    if (_pages.length != widget.book.totalPages) {
      Future.microtask(() {
        try {
          _bookDao.updateBookTotalPages(widget.book.id!, _pages.length);
        } catch (e) {
          debugPrint('更新书籍页数失败: $e');
        }
      });
    }
  }

  // 精确分页算法 - 基于真实可用区域计算字符数
  void _standardizedPagination(String content) {
    debugPrint('📱 开始基于TextPainter的精确分页算法...');

    try {
      if (content.isEmpty) {
        _pages = ['内容为空'];
        return;
      }

      // 获取屏幕尺寸和系统边距
      final screenSize = MediaQuery.of(context).size;
      final systemPadding = MediaQuery.of(context).padding;

      debugPrint(
        '📐 屏幕信息: ${screenSize.width.toInt()}x${screenSize.height.toInt()}',
      );
      debugPrint(
        '📐 系统边距: 状态栏${systemPadding.top.toInt()}px, 导航栏${systemPadding.bottom.toInt()}px',
      );

      // 使用TextPainter进行精确分页
      _pages = TextPainterPagination.performTextPainterBasedPagination(
        content: content,
        screenSize: screenSize,
        systemPadding: systemPadding,
        fontSize: _fontSize,
        lineSpacing: _lineSpacing,
        letterSpacing: _letterSpacing,
        fontFamily: _fontFamily,
        horizontalPadding: _horizontalPadding,
      );

      debugPrint('✅ 精确分页完成: 总共 ${_pages.length} 页');
    } catch (e) {
      debugPrint('❌ 分页出错: $e');
      // 备用分页方法
      _fallbackPagination(content);
    }
  }

  // 备用分页方法 - 确保边界连续性
  void _fallbackPagination(String content) {
    debugPrint('🆘 使用备用分页方法...');
    _pages.clear();

    if (content.isEmpty) {
      _pages.add('内容为空');
      return;
    }

    const int charsPerPage = 1200; // 增加每页字符数以提高文本密度
    int currentPos = 0;

    while (currentPos < content.length) {
      int endPos = currentPos + charsPerPage;

      // 如果超出内容长度，直接到末尾
      if (endPos >= content.length) {
        final lastPageContent = content.substring(currentPos);
        if (lastPageContent.isNotEmpty) {
          _pages.add(lastPageContent);
        }
        break;
      }

      // 尝试在合适位置分割，避免断字
      int actualEndPos = endPos;
      for (int offset = 0; offset < 50; offset++) {
        int checkPos = endPos - offset;
        if (checkPos <= currentPos) break;

        String char = content[checkPos];
        if (char == '。' ||
            char == '！' ||
            char == '？' ||
            char == '\n' ||
            char == ' ') {
          actualEndPos = char == '\n' ? checkPos : checkPos + 1;
          break;
        }
      }

      String pageContent = content.substring(currentPos, actualEndPos);
      // 只移除开头结尾的换行，保持内容完整性
      pageContent = pageContent
          .replaceAll(RegExp(r'^\n+'), '')
          .replaceAll(RegExp(r'\n+$'), '');

      if (pageContent.isNotEmpty) {
        _pages.add(pageContent);
        debugPrint(
          '🆘 备用分页第${_pages.length}页: 位置$currentPos-$actualEndPos, 长度${pageContent.length}字符',
        );
      }

      currentPos = actualEndPos;
    }

    debugPrint('🆘 备用分页完成: 总共 ${_pages.length} 页');
  }

  // --- Settings Persistence ---
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = prefs.getDouble('fontSize') ?? 18.0;
      _lineSpacing = prefs.getDouble('lineSpacing') ?? 1.8;
      _letterSpacing = prefs.getDouble('letterSpacing') ?? 0.2;
      _pageMargin = prefs.getDouble('pageMargin') ?? 16.0;
      _horizontalPadding = prefs.getDouble('horizontalPadding') ?? 16.0;
      _autoScroll = prefs.getBool('autoScroll') ?? false;
      _keepScreenOn = prefs.getBool('keepScreenOn') ?? false;
      _fontFamily = prefs.getString('fontFamily') ?? 'System';

      // 加载阅读主题设置，独立于全局主题
      final readingThemeName = prefs.getString('readingTheme') ?? 'day';
      _currentTheme = ReadingThemes.getThemeByName(readingThemeName);
    });
  }

  // 切换阅读主题
  Future<void> _switchReadingTheme(ReadingTheme theme) async {
    setState(() {
      _currentTheme = theme;
    });

    // 保存主题设置
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('readingTheme', theme.name);

    // 更新沉浸式状态栏颜色
    _setImmersiveMode();
  }

  Timer? _repaginationTimer;

  Future<void> _saveSetting(Function(SharedPreferences) saver) async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    saver(prefs);

    // 使用防抖机制，避免频繁重新分页
    _repaginationTimer?.cancel();
    _repaginationTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _bookContent.isNotEmpty) {
        debugPrint('🔄 设置变化，智能重新分页...');
        _intelligentRepagination();
      }
    });
  }

  // 智能重新分页 - 保持当前阅读位置
  void _intelligentRepagination() {
    if (!mounted || _bookContent.isEmpty) return;

    // 记录当前阅读位置（字符位置）
    int currentCharPosition = 0;
    for (int i = 0; i < _currentPageIndex && i < _pages.length; i++) {
      currentCharPosition += _pages[i].length;
    }

    // 重新分页
    _splitIntoPages();

    // 根据字符位置找到新的页码
    int newPageIndex = 0;
    int charCount = 0;
    for (int i = 0; i < _pages.length; i++) {
      if (charCount + _pages[i].length > currentCharPosition) {
        newPageIndex = i;
        break;
      }
      charCount += _pages[i].length;
      newPageIndex = i + 1;
    }

    // 安全地更新页码
    _currentPageIndex = newPageIndex.clamp(0, _pages.length - 1);

    // 更新页面控制器
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        _currentPageIndex,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }

    setState(() {});
    debugPrint('✅ 智能重新分页完成，保持阅读位置在第${_currentPageIndex + 1}页');
  }

  // --- UI Controls ---
  void _setImmersiveMode() {
    final isLightBackground =
        _currentTheme.backgroundColor.computeLuminance() > 0.5;

    if (!_showControls) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
      );

      // 设置系统UI样式与控制栏颜色保持一致
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
      final Color navigationBarColor = isDarkMode
          ? Color.lerp(_currentTheme.backgroundColor, Colors.grey[800]!, 0.3)!
          : Color.lerp(_currentTheme.backgroundColor, Colors.grey[100]!, 0.4)!;

      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLightBackground
              ? Brightness.dark
              : Brightness.light,
          systemNavigationBarColor: navigationBarColor,
          systemNavigationBarIconBrightness: isDarkMode
              ? Brightness.light
              : Brightness.dark,
        ),
      );
    }
  }

  void _toggleControls() {
    if (_showControls) {
      _hideControls();
    } else {
      _showControlsWithAnimation();
    }
  }

  void _showControlsWithAnimation() {
    if (!_showControls) {
      setState(() => _showControls = true);
      _startHideControlsTimer();
      _setImmersiveMode(); // 使用统一的方法设置系统UI
    }
  }

  void _hideControls() {
    if (_showControls) {
      setState(() => _showControls = false);
      _setImmersiveMode(); // 使用统一的方法设置系统UI
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), _hideControls);
  }

  void _onPageTurn() {
    if (!mounted) return;

    // 检查当前页面书签状态
    _checkCurrentPageBookmark();

    // 不立即隐藏控件，让用户有时间看到页面变化
    if (_showControls) {
      _startHideControlsTimer(); // 重新开始计时而不是立即隐藏
    }

    try {
      _bookDao.updateBookProgress(widget.book.id!, _currentPageIndex);
    } catch (e) {
      debugPrint('更新阅读进度失败: $e');
    }
  }

  void _handleTap(TapUpDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final tapPosition = details.globalPosition;

    if (_showControls &&
        (tapPosition.dy < 150 || tapPosition.dy > screenHeight - 200)) {
      return;
    }

    final leftBoundary = screenWidth / 3;
    final rightBoundary = screenWidth * 2 / 3;

    if (tapPosition.dx < leftBoundary) {
      _goToPreviousPage();
    } else if (tapPosition.dx > rightBoundary) {
      _goToNextPage();
    } else {
      _toggleControls();
    }
  }

  void _goToPreviousPage() {
    if (_currentPageIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      HapticFeedback.lightImpact();
    }
  }

  void _goToNextPage() {
    if (_currentPageIndex < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 检测屏幕尺寸变化，智能响应式重新分页
    final currentScreenSize = MediaQuery.of(context).size;
    if (_lastScreenSize != null &&
        (_lastScreenSize!.width != currentScreenSize.width ||
            _lastScreenSize!.height != currentScreenSize.height)) {
      debugPrint('🔄 屏幕尺寸变化，触发智能重新分页');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _bookContent.isNotEmpty) {
          _intelligentRepagination();
        }
      });
    }
    _lastScreenSize = currentScreenSize;

    return Scaffold(
      backgroundColor: _currentTheme.backgroundColor, // 使用阅读主题的背景色，确保切换主题时立即生效
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: GestureDetector(
                onTapUp: _handleTap,
                onHorizontalDragEnd: _handleHorizontalDragEnd,
                child: Container(
                  color: Colors.transparent,
                  child: _buildMainContent(),
                ),
              ),
            ),
          ),
          _buildControlsOverlay(),
          // 调试信息显示 - 已禁用
          // if (_pages.isNotEmpty && _pages.length > 1) _buildDebugInfo(),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_pages.isEmpty) {
      return Container(
        color: _currentTheme.backgroundColor, // 使用阅读主题背景色
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _currentTheme.textColor),
              const SizedBox(height: 16),
              Text(
                '正在初始化阅读器...',
                style: TextStyle(
                  fontSize: 16,
                  color: _currentTheme.textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final first = _pages.first;
    if (first.startsWith(_kLoadingPrefix) || first.startsWith(_kErrorPrefix)) {
      final isError = first.startsWith(_kErrorPrefix);
      return Container(
        color: _currentTheme.backgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isError)
                const CircularProgressIndicator()
              else
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  first,
                  style: TextStyle(
                    fontSize: 16,
                    color: isError
                        ? Colors.red.shade300
                        : _currentTheme.textColor.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (isError)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: ElevatedButton(
                    onPressed: _initializeReading,
                    child: const Text('重试'),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // 检查是否应该显示双页布局
    final shouldShowDoublePage = ResponsiveHelper.shouldShowDoublePage(context);

    if (shouldShowDoublePage) {
      return _buildDoublePageView();
    } else {
      return Container(
        color: _currentTheme.backgroundColor,
        child: PageView.builder(
          controller: _pageController,
          itemCount: _pages.length,
          itemBuilder: (context, index) => _buildPageWidget(index),
          onPageChanged: (index) {
            if (mounted) {
              setState(() => _currentPageIndex = index);
              _onPageTurn();
            }
          },
          physics: const ClampingScrollPhysics(),
        ),
      );
    }
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    const threshold = 500.0;

    if (velocity > threshold) {
      if (_currentPageIndex > 0) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    } else if (velocity < -threshold) {
      if (_currentPageIndex < _pages.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  // 双页布局视图 - 简化版，只有中间分隔线
  Widget _buildDoublePageView() {
    return Container(
      color: _currentTheme.backgroundColor, // 使用阅读主题背景色
      child: PageView.builder(
        controller: _pageController,
        itemCount: (_pages.length / 2).ceil(),
        itemBuilder: (context, index) {
          final leftPageIndex = index * 2;
          final rightPageIndex = leftPageIndex + 1;

          return Row(
            children: [
              // 左页
              Expanded(
                child: leftPageIndex < _pages.length
                    ? _buildPageWidget(leftPageIndex, isDoublePage: true)
                    : Container(color: _currentTheme.backgroundColor),
              ),
              // 中间分隔线
              Container(
                width: 1,
                height: double.infinity,
                color: _currentTheme.textColor.withValues(alpha: 0.2),
              ),
              // 右页
              Expanded(
                child: rightPageIndex < _pages.length
                    ? _buildPageWidget(rightPageIndex, isDoublePage: true)
                    : Container(color: _currentTheme.backgroundColor),
              ),
            ],
          );
        },
        onPageChanged: (index) {
          if (mounted) {
            final newPageIndex = index * 2;
            setState(() => _currentPageIndex = newPageIndex);
            _onPageTurn();
          }
        },
        physics: const ClampingScrollPhysics(),
      ),
    );
  }

  Widget _buildPageWidget(int index, {bool isDoublePage = false}) {
    if (index < 0 || index >= _pages.length) {
      return Container(
        color: _currentTheme.backgroundColor, // 使用阅读主题背景色
        child: Center(
          child: Text(
            '页面索引错误: $index',
            style: TextStyle(fontSize: 16, color: _currentTheme.textColor),
          ),
        ),
      );
    }

    final pageContent = _pages[index];
    if (pageContent.isEmpty) {
      return Container(
        color: _currentTheme.backgroundColor, // 使用阅读主题背景色
        child: Center(
          child: Text(
            '页面内容为空',
            style: TextStyle(
              fontSize: 16,
              color: _currentTheme.textColor.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    // 根据是否为双页布局调整边距和间距
    final horizontalPadding = isDoublePage
        ? _horizontalPadding *
              0.5 // 双页时减少内边距
        : _horizontalPadding;

    // 简化留白计算，确保文字完整显示
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // 适度的固定留白，确保文字完整显示
    final topPadding = isDoublePage ? 30.0 : 40.0;
    // 优化底部留白，减少过多的空白区域
    final baseBottomPadding = isDoublePage ? 30.0 : 40.0; // 减少基础底部留白
    final toolbarSpace = 100.0; // 减少控制栏预留空间
    final bottomPadding = baseBottomPadding + toolbarSpace;

    return RepaintBoundary(
      child: Container(
        color: _currentTheme.backgroundColor, // 使用阅读主题背景色
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          top: false, // 顶部由我们自己控制
          bottom: true, // 底部使用SafeArea确保不被导航栏遮挡
          child: Padding(
            padding: EdgeInsets.only(
              left: horizontalPadding,
              right: horizontalPadding,
              top: topPadding + statusBarHeight,
              bottom: bottomPadding,
            ),
            child: Text(
              pageContent,
              style: TextStyle(
                fontSize: _fontSize,
                height: _lineSpacing,
                letterSpacing: _letterSpacing,
                color: _currentTheme.textColor, // 使用阅读主题的文字颜色
                fontFamily: _fontFamily == 'System' ? null : _fontFamily,
              ),
              textAlign: TextAlign.justify,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return RepaintBoundary(
      child: Stack(
        children: [
          // 顶部工具栏 - 标题栏在顶部
          _buildTopBar(),
          // 底部工具栏 - 控制栏在底部
          _buildBottomToolbar(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double topBarHeight = statusBarHeight + 60;

    // 根据背景颜色动态调整工具栏颜色
    final isLightBackground =
        _currentTheme.backgroundColor.computeLuminance() > 0.5;
    final textColor = isLightBackground ? Colors.black87 : Colors.white;
    final iconBgColor = isLightBackground
        ? Colors.grey.withValues(alpha: 0.2)
        : Colors.grey.withValues(alpha: 0.3);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: _showControls ? 0 : -topBarHeight,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _showControls ? 1.0 : 0.0,
        curve: Curves.easeInOut,
        child: IgnorePointer(
          ignoring: !_showControls,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            // 毛玻璃效果 - 阅读页面顶部控制栏
            // 创建半透明控制栏，不遮挡阅读内容的视觉体验
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // 较轻的模糊避免干扰阅读
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
                  )!.withValues(alpha: 0.85),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border.all(
                    color: isLightBackground
                        ? Colors.black.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
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
                              color: textColor.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${_currentPageIndex + 1}/${_pages.length}',
                        style: TextStyle(
                          color: isLightBackground
                              ? Colors.blue[700]
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
  }

  Widget _buildBottomToolbar() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    final Color toolbarBgColor = _currentTheme.controlBarColor;

    final Color handleColor = _currentTheme.iconColor.withValues(alpha: 0.6);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      bottom: _showControls ? 0 : -200,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _showControls ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !_showControls,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: 8, // 只保留顶部内边距，让背景延伸到底部
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: bottomPadding + 8, // 内容区域保持底部间距
                  ),
                  decoration: BoxDecoration(
                    color: toolbarBgColor.withValues(alpha: 0.95),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 可拖拽的小横条指示器
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                        ), // 减少垂直内边距
                        child: Center(
                          child: Container(
                            width: 48,
                            height: 4, // 减少高度
                            decoration: BoxDecoration(
                              color: handleColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8), // 减少间距
                      _buildToolbarButtons(),
                    ],
                  ),
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
      padding: const EdgeInsets.fromLTRB(
        20,
        4,
        20,
        8,
      ), // 减少顶部内边距，增加底部内边距确保按钮不贴边
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ModernToolbarButton(
            icon: Icons.format_list_bulleted_rounded,
            label: '目录',
            onTap: _showTableOfContents,
            iconColor: _currentTheme.controlBarTextColor,
            pressedColor: _currentTheme.iconColor.withValues(alpha: 0.15),
          ),
          _ModernToolbarButton(
            icon: Icons.tune_rounded,
            label: '设置',
            onTap: _showSettingsPanel,
            iconColor: _currentTheme.controlBarTextColor,
            pressedColor: _currentTheme.iconColor.withValues(alpha: 0.15),
          ),
          _ModernToolbarButton(
            icon: Icons.palette_rounded,
            label: '主题',
            onTap: _showThemePanel,
            iconColor: _currentTheme.controlBarTextColor,
            pressedColor: _currentTheme.iconColor.withValues(alpha: 0.15),
          ),
          _ModernToolbarButton(
            icon: _isCurrentPageBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_add_rounded,
            label: '书签',
            onTap: _showBookmarks,
            iconColor: _currentTheme.controlBarTextColor,
            pressedColor: _currentTheme.iconColor.withValues(alpha: 0.15),
          ),
          _ModernToolbarButton(
            icon: Icons.more_horiz_rounded,
            label: '更多',
            onTap: _showMoreOptions,
            iconColor: _currentTheme.controlBarTextColor,
            pressedColor: _currentTheme.iconColor.withValues(alpha: 0.15),
          ),
        ],
      ),
    );
  }

  // --- 主题面板 ---
  void _showThemePanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent, // 去除阴影遮挡
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDarkMode = Theme.of(context).brightness == Brightness.dark;
            final panelBgColor = isDarkMode
                ? Colors.grey[900]!.withValues(alpha: 0.98)
                : Colors.grey[50]!.withValues(alpha: 0.98);

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: MediaQuery.of(context).size.height * 0.6,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Container(
                    decoration: BoxDecoration(
                      color: panelBgColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
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
                                color: isDarkMode
                                    ? Colors.grey[600]
                                    : Colors.grey[400],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        // 标题栏
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.purple[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.palette_rounded,
                                  color: Colors.purple[600],
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '阅读主题',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.grey[800],
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 主题内容
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: _buildEnhancedColorThemeSelector(
                              setModalState,
                              isDarkMode,
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
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple[600],
                                foregroundColor: Colors.white,
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

  // --- Settings Panel ---
  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent, // 去除阴影遮挡
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDarkMode = Theme.of(context).brightness == Brightness.dark;
            final panelBgColor = isDarkMode
                ? Colors.grey[900]!.withValues(alpha: 0.98)
                : Colors.grey[50]!.withValues(alpha: 0.98);
            final panelBorderColor = isDarkMode
                ? Colors.grey[700]!.withValues(alpha: 0.6)
                : Colors.grey[300]!.withValues(alpha: 0.8);

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: MediaQuery.of(context).size.height * 0.6,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Container(
                    decoration: BoxDecoration(
                      color: panelBgColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      border: Border.all(color: panelBorderColor, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDarkMode ? 0.4 : 0.1,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
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
                                color: isDarkMode
                                    ? Colors.grey[600]
                                    : Colors.grey[400],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        // 标题栏
                        Container(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: isDarkMode
                                    ? Colors.grey[700]!.withValues(alpha: 0.5)
                                    : Colors.grey[300]!.withValues(alpha: 0.8),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.blue[600]!.withValues(alpha: 0.2)
                                      : Colors.blue[100]!.withValues(
                                          alpha: 0.8,
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  color: isDarkMode
                                      ? Colors.blue[300]
                                      : Colors.blue[600],
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '阅读设置',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.grey[800],
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.grey[700]!.withValues(alpha: 0.5)
                                      : Colors.grey[200]!.withValues(
                                          alpha: 0.8,
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.refresh_rounded,
                                    color: isDarkMode
                                        ? Colors.grey[300]
                                        : Colors.grey[600],
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _resetSettings();
                                    setModalState(() {});
                                    setState(() {});
                                  },
                                  tooltip: '重置设置',
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 设置内容
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSettingSection(
                                  title: '文字设置',
                                  icon: Icons.text_fields_rounded,
                                  isDarkMode: isDarkMode,
                                  children: [
                                    _buildEnhancedSettingSlider(
                                      label: '字号',
                                      value: _fontSize,
                                      min: 12,
                                      max: 30,
                                      divisions: 18,
                                      unit: 'pt',
                                      icon: Icons.format_size,
                                      isDarkMode: isDarkMode,
                                      onChanged: (v) {
                                        setModalState(() => _fontSize = v);
                                        setState(() {});
                                        _saveSetting(
                                          (p) => p.setDouble('fontSize', v),
                                        );
                                      },
                                    ),
                                    _buildEnhancedSettingSlider(
                                      label: '行距',
                                      value: _lineSpacing,
                                      min: 1.0,
                                      max: 3.0,
                                      divisions: 20,
                                      unit: 'x',
                                      icon: Icons.format_line_spacing,
                                      isDarkMode: isDarkMode,
                                      onChanged: (v) {
                                        setModalState(() => _lineSpacing = v);
                                        setState(() {});
                                        _saveSetting(
                                          (p) => p.setDouble('lineSpacing', v),
                                        );
                                      },
                                    ),
                                    _buildEnhancedSettingSlider(
                                      label: '字间距',
                                      value: _letterSpacing,
                                      min: 0.0,
                                      max: 2.0,
                                      divisions: 20,
                                      unit: 'pt',
                                      icon: Icons.text_fields,
                                      isDarkMode: isDarkMode,
                                      onChanged: (v) {
                                        setModalState(() => _letterSpacing = v);
                                        setState(() {});
                                        _saveSetting(
                                          (p) =>
                                              p.setDouble('letterSpacing', v),
                                        );
                                      },
                                    ),
                                    _buildFontFamilySelector(
                                      isDarkMode,
                                      setModalState,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                _buildSettingSection(
                                  title: '页面设置',
                                  icon: Icons.article_rounded,
                                  isDarkMode: isDarkMode,
                                  children: [
                                    _buildEnhancedSettingSlider(
                                      label: '页面边距',
                                      value: _pageMargin,
                                      min: 8,
                                      max: 32,
                                      divisions: 12,
                                      unit: 'px',
                                      icon: Icons.crop_free,
                                      isDarkMode: isDarkMode,
                                      onChanged: (v) {
                                        setModalState(() => _pageMargin = v);
                                        setState(() {});
                                        _saveSetting(
                                          (p) => p.setDouble('pageMargin', v),
                                        );
                                      },
                                    ),
                                    _buildEnhancedSettingSlider(
                                      label: '左右留白',
                                      value: _horizontalPadding,
                                      min: 8,
                                      max: 48,
                                      divisions: 20,
                                      unit: 'px',
                                      icon: Icons.horizontal_distribute,
                                      isDarkMode: isDarkMode,
                                      onChanged: (v) {
                                        setModalState(
                                          () => _horizontalPadding = v,
                                        );
                                        setState(() {});
                                        _saveSetting(
                                          (p) => p.setDouble(
                                            'horizontalPadding',
                                            v,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                _buildSettingSection(
                                  title: '阅读体验',
                                  icon: Icons.auto_stories_rounded,
                                  isDarkMode: isDarkMode,
                                  children: [
                                    _buildSwitchSetting(
                                      label: '保持屏幕常亮',
                                      value: _keepScreenOn,
                                      icon: Icons.screen_lock_portrait,
                                      isDarkMode: isDarkMode,
                                      onChanged: (v) {
                                        setModalState(() => _keepScreenOn = v);
                                        setState(() {});
                                        _saveSetting(
                                          (p) => p.setBool('keepScreenOn', v),
                                        );
                                      },
                                    ),
                                    _buildSwitchSetting(
                                      label: '自动滚动',
                                      value: _autoScroll,
                                      icon: Icons.auto_mode,
                                      isDarkMode: isDarkMode,
                                      onChanged: (v) {
                                        setModalState(() => _autoScroll = v);
                                        setState(() {});
                                        _saveSetting(
                                          (p) => p.setBool('autoScroll', v),
                                        );
                                      },
                                    ),
                                  ],
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
                                color: isDarkMode
                                    ? Colors.grey[700]!.withValues(alpha: 0.5)
                                    : Colors.grey[300]!.withValues(alpha: 0.8),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDarkMode
                                        ? Colors.blue[600]
                                        : Colors.blue[500],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        '完成设置',
                                        style: TextStyle(
                                          fontSize: 16,
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
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _splitIntoPages();
          setState(() {});
        }
      });
    });
  }

  Widget _buildSettingSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool isDarkMode = true,
  }) {
    final textColor = isDarkMode ? Colors.white : Colors.grey[800]!;
    final sectionBgColor = isDarkMode
        ? Colors.grey[850]!.withValues(alpha: 0.6)
        : Colors.grey[50]!.withValues(alpha: 0.9);
    final sectionBorderColor = isDarkMode
        ? Colors.grey[700]!.withValues(alpha: 0.5)
        : Colors.grey[300]!.withValues(alpha: 0.8);
    final iconBgColor = isDarkMode
        ? Colors.blue[600]!.withValues(alpha: 0.3)
        : Colors.blue[100]!.withValues(alpha: 0.8);
    final iconColor = isDarkMode ? Colors.blue[300] : Colors.blue[600];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: sectionBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sectionBorderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildEnhancedSettingSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    String unit = '',
    required IconData icon,
    required bool isDarkMode,
    required ValueChanged<double> onChanged,
  }) {
    final textColor = isDarkMode ? Colors.white : Colors.grey[800]!;
    final activeColor = isDarkMode ? Colors.blue[400]! : Colors.blue[500]!;
    final inactiveColor = isDarkMode
        ? Colors.grey[600]!.withValues(alpha: 0.5)
        : Colors.grey[300]!.withValues(alpha: 0.8);
    final badgeColor = isDarkMode
        ? Colors.blue[600]!.withValues(alpha: 0.3)
        : Colors.blue[100]!.withValues(alpha: 0.8);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.grey[800]!.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.grey[700]!.withValues(alpha: 0.5)
              : Colors.grey[300]!.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isDarkMode ? Colors.blue[300] : Colors.blue[600],
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: activeColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${value.toStringAsFixed(1)}$unit',
                  style: TextStyle(
                    color: activeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbShape: CustomSliderThumbShape(
                enabledThumbRadius: 12,
                thumbColor: activeColor,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              activeTrackColor: activeColor,
              inactiveTrackColor: inactiveColor,
              overlayColor: activeColor.withValues(alpha: 0.1),
              trackShape: CustomSliderTrackShape(),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontFamilySelector(bool isDarkMode, StateSetter setModalState) {
    final textColor = isDarkMode ? Colors.white : Colors.grey[800]!;
    final cardColor = isDarkMode
        ? Colors.grey[800]!.withValues(alpha: 0.6)
        : Colors.grey[100]!.withValues(alpha: 0.8);

    final fontFamilies = [
      {'name': '系统默认', 'value': 'System'},
      {'name': '宋体', 'value': 'Serif'},
      {'name': '黑体', 'value': 'Sans-serif'},
      {'name': '等宽字体', 'value': 'Monospace'},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.grey[600]!.withValues(alpha: 0.3)
              : Colors.grey[300]!.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.orange[600]!.withValues(alpha: 0.3)
                      : Colors.orange[100]!.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.font_download_rounded,
                  size: 16,
                  color: isDarkMode ? Colors.orange[300] : Colors.orange[600],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '字体样式',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: fontFamilies.map((font) {
              final isSelected = _fontFamily == font['value'];
              return GestureDetector(
                onTap: () {
                  setModalState(() => _fontFamily = font['value']!);
                  setState(() {});
                  _saveSetting(
                    (p) => p.setString('fontFamily', font['value']!),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDarkMode ? Colors.blue[600] : Colors.blue[500])
                        : (isDarkMode
                              ? Colors.grey[700]!.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.8)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? (isDarkMode ? Colors.blue[400]! : Colors.blue[300]!)
                          : (isDarkMode
                                ? Colors.grey[600]!.withValues(alpha: 0.3)
                                : Colors.grey[300]!.withValues(alpha: 0.5)),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    font['name']!,
                    style: TextStyle(
                      color: isSelected ? Colors.white : textColor,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      fontFamily: font['value'] == 'System'
                          ? null
                          : font['value'],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchSetting({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    IconData? icon,
    bool isDarkMode = true,
  }) {
    final textColor = isDarkMode ? Colors.white : Colors.grey[800]!;
    final activeColor = isDarkMode ? Colors.blue[400]! : Colors.blue[500]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.grey[800]!.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.grey[700]!.withValues(alpha: 0.5)
              : Colors.grey[300]!.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: activeColor, size: 18),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: activeColor,
            inactiveTrackColor: isDarkMode
                ? Colors.grey[600]!.withValues(alpha: 0.5)
                : Colors.grey[300]!.withValues(alpha: 0.8),
            inactiveThumbColor: isDarkMode
                ? Colors.grey[400]
                : Colors.grey[600],
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedColorThemeSelector(
    StateSetter setModalState,
    bool isDarkMode,
  ) {
    final textColor = isDarkMode ? Colors.white : Colors.grey[800]!;
    final selectedBorderColor = isDarkMode
        ? Colors.blue[400]!
        : Colors.blue[500]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.palette_rounded,
              color: isDarkMode ? Colors.blue[300] : Colors.blue[600],
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              '阅读主题',
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.6, // 进一步增加高度比例
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: ReadingThemes.allThemes.length,
          itemBuilder: (context, index) {
            final theme = ReadingThemes.allThemes[index];
            final isSelected = _currentTheme.name == theme.name;

            return GestureDetector(
              onTap: () {
                _switchReadingTheme(theme);
                setModalState(() {});
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: theme.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? selectedBorderColor
                        : (isDarkMode
                              ? Colors.grey[600]!.withValues(alpha: 0.5)
                              : Colors.grey[300]!.withValues(alpha: 0.8)),
                    width: isSelected ? 3 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: selectedBorderColor.withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10), // 减少padding从12到10
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6), // 减少padding从8到6
                          decoration: BoxDecoration(
                            color: theme.textColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6), // 相应减少圆角
                          ),
                          child: Icon(
                            _getThemeIcon(theme.name),
                            color: theme.textColor,
                            size: 14, // 减少图标大小从16到14
                          ),
                        ),
                        const SizedBox(width: 6), // 减少间距从8到6
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Aa',
                                  style: TextStyle(
                                    color: theme.textColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  theme.displayName,
                                  style: TextStyle(
                                    color: theme.textColor.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: selectedBorderColor,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // 获取主题对应的图标
  IconData _getThemeIcon(String themeName) {
    switch (themeName) {
      case 'day':
        return Icons.light_mode;
      case 'night':
        return Icons.dark_mode;
      case 'eye_protection':
        return Icons.eco;
      case 'parchment':
        return Icons.article;
      case 'sepia':
        return Icons.auto_stories;
      default:
        return Icons.palette;
    }
  }

  // --- Bookmark Management ---
  Future<void> _loadBookmarks() async {
    try {
      final bookmarks = await _bookmarkDao.getBookmarksForBook(widget.book.id!);
      if (mounted) {
        setState(() {
          _bookmarks = bookmarks;
          _checkCurrentPageBookmark();
        });
      }
    } catch (e) {
      debugPrint('加载书签失败: $e');
    }
  }

  void _checkCurrentPageBookmark() {
    _isCurrentPageBookmarked = _bookmarks.any(
      (bookmark) => bookmark.pageNumber == _currentPageIndex + 1,
    );
  }

  Future<void> _addBookmark() async {
    try {
      final bookmark = Bookmark(
        bookId: widget.book.id!,
        pageNumber: _currentPageIndex + 1,
        note: '',
        createDate: DateTime.now(),
      );

      await _bookmarkDao.insertBookmark(bookmark);
      await _loadBookmarks(); // 重新加载书签列表

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已添加书签：第${_currentPageIndex + 1}页'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('添加书签失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('添加书签失败'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _removeBookmark() async {
    try {
      await _bookmarkDao.deleteBookmarkOnPage(
        widget.book.id!,
        _currentPageIndex + 1,
      );
      await _loadBookmarks(); // 重新加载书签列表

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除书签：第${_currentPageIndex + 1}页'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('删除书签失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('删除书签失败'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteBookmark(int bookmarkId) async {
    try {
      await _bookmarkDao.deleteBookmark(bookmarkId);
      await _loadBookmarks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('书签已删除'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('删除书签失败: $e');
    }
  }

  void _goToBookmark(int pageNumber) {
    Navigator.pop(context); // 关闭书签面板
    _goToPage(pageNumber - 1); // pageNumber是从1开始的，而pageIndex是从0开始的
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '昨天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${date.month}月${date.day}日';
    }
  }

  // --- TOC / Bookmarks / More ---
  void _showTableOfContents() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildTableOfContentsPanel(),
    );
  }

  void _showBookmarks() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildBookmarksPanel(),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildMoreOptionsPanel(),
    );
  }

  Timer? _autoScrollTimer;

  void _toggleAutoScroll() {
    setState(() {
      _autoScroll = !_autoScroll;
    });
    _saveSetting((p) => p.setBool('autoScroll', _autoScroll));

    if (_autoScroll) {
      _startAutoScroll();
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll() {
    _stopAutoScroll(); // 确保之前的定时器被清除
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentPageIndex < _pages.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        // 到达最后一页，停止自动滚动
        _toggleAutoScroll();
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  Widget _buildTableOfContentsPanel() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  child: const Text(
                    '目录',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final isCurrentPage = index == _currentPageIndex;
                      return ListTile(
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isCurrentPage
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: isCurrentPage
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          '第 ${index + 1} 页',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: isCurrentPage
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          _getPagePreview(index),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _goToPage(index);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookmarksPanel() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // 标题栏
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '书签',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // 当前页面书签操作按钮
                      GestureDetector(
                        onTap: () {
                          if (_isCurrentPageBookmarked) {
                            _removeBookmark();
                          } else {
                            _addBookmark();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _isCurrentPageBookmarked
                                ? Colors.orange.withValues(alpha: 0.2)
                                : Colors.blue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isCurrentPageBookmarked
                                  ? Colors.orange
                                  : Colors.blue,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isCurrentPageBookmarked
                                    ? Icons.bookmark_remove
                                    : Icons.bookmark_add,
                                color: _isCurrentPageBookmarked
                                    ? Colors.orange
                                    : Colors.blue,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isCurrentPageBookmarked ? '删除书签' : '添加书签',
                                style: TextStyle(
                                  color: _isCurrentPageBookmarked
                                      ? Colors.orange
                                      : Colors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 书签列表
                Expanded(
                  child: _bookmarks.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bookmark_border,
                                color: Colors.white38,
                                size: 48,
                              ),
                              SizedBox(height: 16),
                              Text(
                                '暂无书签',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '点击上方按钮添加当前页面为书签',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _bookmarks.length,
                          itemBuilder: (context, index) {
                            final bookmark = _bookmarks[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () =>
                                      _goToBookmark(bookmark.pageNumber),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.bookmark,
                                            color: Colors.blue,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '第 ${bookmark.pageNumber} 页',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '创建于 ${_formatDate(bookmark.createDate)}',
                                                style: const TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // 删除按钮
                                        GestureDetector(
                                          onTap: () =>
                                              _deleteBookmark(bookmark.id!),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                              size: 18,
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
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOptionsPanel() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '更多选项',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.search, color: Colors.white),
                title: const Text('搜索', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showSearchDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.white),
                title: const Text('分享', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _shareCurrentPage();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _getPagePreview(int pageIndex) {
    if (pageIndex >= _pages.length) return '';
    final content = _pages[pageIndex];
    final preview = content.length > 50
        ? '${content.substring(0, 50)}...'
        : content;
    return preview.replaceAll('\n', ' ');
  }

  void _goToPage(int pageIndex) {
    if (pageIndex >= 0 && pageIndex < _pages.length) {
      setState(() {
        _currentPageIndex = pageIndex;
      });
      _pageController.animateToPage(
        pageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _resetSettings() {
    _fontSize = 18.0;
    _lineSpacing = 1.8;
    _letterSpacing = 0.2;
    _pageMargin = 16.0;
    _horizontalPadding = 16.0;
    _autoScroll = false;
    _keepScreenOn = false;
    _fontFamily = 'System';
    _currentTheme = ReadingThemes.dayTheme;
    _saveSetting((p) async {
      await p.remove('fontSize');
      await p.remove('lineSpacing');
      await p.remove('letterSpacing');
      await p.remove('pageMargin');
      await p.remove('horizontalPadding');
      await p.remove('autoScroll');
      await p.remove('keepScreenOn');
      await p.remove('fontFamily');
      await p.remove('backgroundColor');
      await p.remove('fontColor');
      await p.remove('readingTheme');
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _autoScrollTimer?.cancel();
    _repaginationTimer?.cancel();
    _pageController.dispose();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );

    if (_sessionStartTime != null) {
      final duration = DateTime.now().difference(_sessionStartTime!);
      if (duration.inSeconds > 10) {
        _statsDao.insertReadingTime(DateTime.now(), duration.inSeconds);
      }
    }
    super.dispose();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) {
        String searchQuery = '';
        return AlertDialog(
          backgroundColor: _currentTheme.controlBarColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '搜索内容',
            style: TextStyle(color: _currentTheme.controlBarTextColor),
          ),
          content: TextField(
            style: TextStyle(color: _currentTheme.controlBarTextColor),
            decoration: InputDecoration(
              hintText: '输入要搜索的内容...',
              hintStyle: TextStyle(
                color: _currentTheme.controlBarTextColor.withValues(alpha: 0.6),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: _currentTheme.controlBarTextColor.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: _currentTheme.controlBarTextColor,
                ),
              ),
            ),
            onChanged: (value) => searchQuery = value,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '取消',
                style: TextStyle(
                  color: _currentTheme.controlBarTextColor.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (searchQuery.isNotEmpty) {
                  _searchInBook(searchQuery);
                }
              },
              child: Text(
                '搜索',
                style: TextStyle(color: _currentTheme.controlBarTextColor),
              ),
            ),
          ],
        );
      },
    );
  }

  void _searchInBook(String query) {
    List<int> searchResults = [];

    // 查找所有匹配的页面
    for (int i = 0; i < _pages.length; i++) {
      if (_pages[i].toLowerCase().contains(query.toLowerCase())) {
        searchResults.add(i);
      }
    }

    if (searchResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('未找到："$query"'),
          backgroundColor: Colors.red.withValues(alpha: 0.8),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 找到第一个匹配项并跳转
    int firstResult = searchResults.first;
    _pageController.animateToPage(
      firstResult,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    // 显示搜索结果底部面板
    _showSearchResultsPanel(query, searchResults, 0);
  }

  void _showSearchResultsPanel(
    String query,
    List<int> results,
    int currentIndex,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _currentTheme.controlBarColor.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '搜索结果：$query',
                  style: TextStyle(
                    color: _currentTheme.controlBarTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${currentIndex + 1}/${results.length}',
                  style: TextStyle(
                    color: _currentTheme.controlBarTextColor.withValues(
                      alpha: 0.7,
                    ),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 上一个结果
                ElevatedButton.icon(
                  onPressed: currentIndex > 0
                      ? () {
                          Navigator.pop(context);
                          int prevIndex = currentIndex - 1;
                          _pageController.animateToPage(
                            results[prevIndex],
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                          _showSearchResultsPanel(query, results, prevIndex);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentTheme.controlBarTextColor
                        .withValues(alpha: 0.2),
                    foregroundColor: _currentTheme.controlBarTextColor,
                  ),
                  icon: const Icon(Icons.keyboard_arrow_up),
                  label: const Text('上一个'),
                ),
                // 下一个结果
                ElevatedButton.icon(
                  onPressed: currentIndex < results.length - 1
                      ? () {
                          Navigator.pop(context);
                          int nextIndex = currentIndex + 1;
                          _pageController.animateToPage(
                            results[nextIndex],
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                          _showSearchResultsPanel(query, results, nextIndex);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentTheme.sliderActiveColor.withValues(
                      alpha: 0.3,
                    ),
                    foregroundColor: _currentTheme.controlBarTextColor,
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down),
                  label: const Text('下一个'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '第 ${results[currentIndex] + 1} 页',
              style: TextStyle(
                color: _currentTheme.controlBarTextColor.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareCurrentPage() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSharePanel(),
    );
  }

  Widget _buildSharePanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '分享选项',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),

          // 分享当前页面
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.content_copy, color: Colors.blue),
            ),
            title: const Text('复制当前页面', style: TextStyle(color: Colors.white)),
            subtitle: const Text(
              '复制当前页面内容到剪贴板',
              style: TextStyle(color: Colors.white70),
            ),
            onTap: () {
              Navigator.pop(context);
              _copyCurrentPage();
            },
          ),

          // 分享阅读进度
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.timeline, color: Colors.green),
            ),
            title: const Text('分享阅读进度', style: TextStyle(color: Colors.white)),
            subtitle: const Text(
              '分享书籍信息和阅读进度',
              style: TextStyle(color: Colors.white70),
            ),
            onTap: () {
              Navigator.pop(context);
              _copyReadingProgress();
            },
          ),

          // 分享书籍摘录
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.format_quote, color: Colors.purple),
            ),
            title: const Text('创建书摘卡片', style: TextStyle(color: Colors.white)),
            subtitle: const Text(
              '生成精美的书摘分享卡片',
              style: TextStyle(color: Colors.white70),
            ),
            onTap: () {
              Navigator.pop(context);
              _createBookQuoteCard();
            },
          ),

          // 分享书籍信息
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.book, color: Colors.orange),
            ),
            title: const Text('分享书籍信息', style: TextStyle(color: Colors.white)),
            subtitle: const Text(
              '分享书名、作者等基本信息',
              style: TextStyle(color: Colors.white70),
            ),
            onTap: () {
              Navigator.pop(context);
              _copyBookInfo();
            },
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _copyCurrentPage() {
    if (_pages.isNotEmpty && _currentPageIndex < _pages.length) {
      final currentPageContent = _pages[_currentPageIndex];
      final bookInfo = '《${widget.book.title}》- ${widget.book.author}';
      final shareText =
          '$bookInfo\n\n第${_currentPageIndex + 1}页:\n\n$currentPageContent';

      Clipboard.setData(ClipboardData(text: shareText));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前页面内容已复制到剪贴板'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _copyReadingProgress() {
    final progress = _pages.isNotEmpty
        ? ((_currentPageIndex + 1) / _pages.length * 100)
        : 0;
    final progressText =
        '''📚 阅读进度分享

《${widget.book.title}》
作者：${widget.book.author}

📖 阅读进度：${progress.toStringAsFixed(1)}% (第${_currentPageIndex + 1}页 / 共${_pages.length}页)
📅 ${DateTime.now().year}年${DateTime.now().month}月${DateTime.now().day}日

#读书记录 #阅读进度''';

    Clipboard.setData(ClipboardData(text: progressText));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('阅读进度已复制到剪贴板'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _createBookQuoteCard() {
    if (_pages.isNotEmpty && _currentPageIndex < _pages.length) {
      String pageContent = _pages[_currentPageIndex];

      // 取前200字符作为摘录
      String excerpt = pageContent.length > 200
          ? '${pageContent.substring(0, 200)}...'
          : pageContent;

      final quoteCard =
          '''✨ 书摘分享

"$excerpt"

——《${widget.book.title}》
   ${widget.book.author}

📍 第${_currentPageIndex + 1}页
📅 ${DateTime.now().year}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().day.toString().padLeft(2, '0')}

#读书笔记 #书摘 #阅读感悟''';

      Clipboard.setData(ClipboardData(text: quoteCard));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('书摘卡片已复制到剪贴板'),
          backgroundColor: Colors.purple,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _copyBookInfo() {
    final bookInfoText =
        '''📚 书籍推荐

《${widget.book.title}》
作者：${widget.book.author}
格式：${widget.book.filePath.split('.').last.toUpperCase()}

推荐理由：这是一本值得阅读的好书！

#读书推荐 #好书分享''';

    Clipboard.setData(ClipboardData(text: bookInfoText));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('书籍信息已复制到剪贴板'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 构建调试信息显示
  /*
  Widget _buildDebugInfo() {
    if (_pages.isEmpty) return const SizedBox.shrink();

    final currentPage = _pages[_currentPageIndex];
    final isLastPage = _currentPageIndex >= _pages.length - 1;
    final isFirstPage = _currentPageIndex <= 0;

    // 获取当前页面的边界字符
    String currentPageInfo = '';
    if (currentPage.isNotEmpty) {
      final firstChar = currentPage[0];
      final lastChar = currentPage[currentPage.length - 1];
      currentPageInfo = '首"$firstChar" 尾"$lastChar"';
    }

    // 获取下一页第一个字符（如果存在）
    String nextPageInfo = '';
    if (!isLastPage && _currentPageIndex + 1 < _pages.length) {
      final nextPage = _pages[_currentPageIndex + 1];
      if (nextPage.isNotEmpty) {
        final nextFirstChar = nextPage[0];
        nextPageInfo = '下页首"$nextFirstChar"';
      }
    }

    // 获取上一页最后一个字符（如果存在）
    String prevPageInfo = '';
    if (!isFirstPage && _currentPageIndex - 1 >= 0) {
      final prevPage = _pages[_currentPageIndex - 1];
      if (prevPage.isNotEmpty) {
        final prevLastChar = prevPage[prevPage.length - 1];
        prevPageInfo = '上页尾"$prevLastChar"';
      }
    }

    return Positioned(
      right: 10,
      bottom: 120, // 在控制栏上方
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _currentTheme.backgroundColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _currentTheme.textColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '第${_currentPageIndex + 1}/${_pages.length}页',
              style: TextStyle(
                color: _currentTheme.textColor.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '长度:${currentPage.length}字符',
              style: TextStyle(
                color: _currentTheme.textColor.withValues(alpha: 0.6),
                fontSize: 9,
              ),
            ),
            if (currentPageInfo.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                currentPageInfo,
                style: TextStyle(
                  color: _currentTheme.textColor.withValues(alpha: 0.6),
                  fontSize: 9,
                ),
              ),
            ],
            if (prevPageInfo.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                prevPageInfo,
                style: TextStyle(
                  color: Colors.blue.withValues(alpha: 0.6),
                  fontSize: 9,
                ),
              ),
            ],
            if (nextPageInfo.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                nextPageInfo,
                style: TextStyle(
                  color: Colors.green.withValues(alpha: 0.6),
                  fontSize: 9,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  */
}

// 现代化工具栏按钮
class _ModernToolbarButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final Color pressedColor;

  const _ModernToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.iconColor,
    required this.pressedColor,
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
              width: 60, // 减少宽度
              height: 52, // 减少高度
              decoration: BoxDecoration(
                color: _colorAnimation.value,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    color: widget.iconColor,
                    size: 20, // 减少图标大小
                  ),
                  const SizedBox(height: 4), // 减少间距
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.iconColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
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
