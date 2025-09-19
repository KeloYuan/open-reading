import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;

import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/book.dart';
import '../models/bookmark.dart';
import '../models/chapter.dart';
import '../services/book_dao.dart';
import '../services/bookmark_dao.dart';
import '../services/reading_stats_dao.dart';
import '../services/book_import_service.dart';
import '../services/enhanced_text_paginator.dart';
import '../widgets/custom_slider_components.dart';
import '../widgets/toc_widget.dart';
import '../widgets/tts_panel_enhanced.dart';
import '../widgets/share_dialog.dart';
import '../widgets/enhanced_text_selection_toolbar.dart';
import '../widgets/highlight_color_picker.dart';
import '../widgets/custom_selectable_text.dart';
import '../services/highlight_dao.dart';
// import '../services/note_dao.dart'; // TODO: 待实现
import '../models/highlight.dart';
import '../utils/responsive_helper.dart';

// 性能优化配置
class PerformanceConfig {
  static const int cachePageCount = 5; // 缓存前后5页
  static const int preloadPageCount = 2; // 预加载前后2页
  static const Duration debounceDelay = Duration(milliseconds: 300);
}

// 页面缓存管理器
class PageCacheManager {
  final Map<int, String> _cache = {};
  final int maxCacheSize;

  PageCacheManager({this.maxCacheSize = 10});

  void setPage(int index, String content) {
    if (_cache.length >= maxCacheSize) {
      // 移除最远的页面
      final keys = _cache.keys.toList()..sort();
      _cache.remove(keys.first);
    }
    _cache[index] = content;
  }

  String? getPage(int index) => _cache[index];

  void clear() => _cache.clear();

  bool hasPage(int index) => _cache.containsKey(index);
}

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
  // --- UI控件尺寸常量 ---
  static const double _controlBarHideOffset = 150.0; // 控制栏隐藏时的偏移
  static const double _topBarHideOffset = 80.0; // 顶部栏隐藏时的偏移

  // --- DAOs & Controllers ---
  late final PageController _pageController;
  final _bookDao = BookDao();
  final _statsDao = ReadingStatsDao();
  final _bookmarkDao = BookmarkDao();
  final _bookImportService = BookImportService();
  final _highlightDao = HighlightDao();
  // TODO: 待实现NoteDao
  // final _noteDao = NoteDao();

  // --- 性能优化相关 ---
  final PageCacheManager _pageCacheManager = PageCacheManager(
    maxCacheSize: PerformanceConfig.cachePageCount * 2,
  );
  Timer? _saveProgressTimer;
  Timer? _preloadTimer;
  Timer? _debounceTimer;
  bool _isInitializing = true;
  bool _isDisposed = false;

  // 防抖动相关
  int _lastPageChangeTime = 0;

  // 内存管理
  final List<Timer> _timers = [];
  final List<StreamSubscription> _subscriptions = [];

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

  // --- Highlight State ---
  List<Highlight> _currentPageHighlights = [];
  // bool _isTextSelectionMode = false; // TODO: 待实现
  String? _selectedText;
  int? _selectionStart;
  int? _selectionEnd;
  OverlayEntry? _selectionToolbarOverlay;

  // --- Chapter State ---
  List<Chapter> _chapters = [];
  bool _chaptersLoaded = false;

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

    // 优化：延迟非关键任务
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookmarks();
      _initializeReading();
    });

    // 设置定时保存进度
    _setupPeriodicSave();
  }

  /// 设置定时保存进度
  void _setupPeriodicSave() {
    _saveProgressTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _saveReadingProgress();
    });
  }

  Future<void> _initializeReading() async {
    try {
      _isInitializing = true;
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
          // 加载章节信息
          _loadChapters();
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
    var currentFilePath = widget.book.filePath;
    var file = File(currentFilePath);

    if (!await file.exists()) {
      // 尝试重新定位文件
      final newPath = await _tryRelocateFile(currentFilePath);
      if (newPath != null) {
        debugPrint('📂 文件已重新定位到: $newPath');
        currentFilePath = newPath;
        file = File(currentFilePath);
      } else {
        throw Exception('文件不存在且无法重新定位: $currentFilePath');
      }
    }

    final fileExtension = widget.book.format.toLowerCase();

    try {
      if (fileExtension == 'epub') {
        debugPrint('开始解析 EPUB: $currentFilePath');
        _bookContent = await _parseEpubDirectly(currentFilePath);
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

  /// 加载章节信息
  Future<void> _loadChapters() async {
    if (_chaptersLoaded) return;

    try {
      final fileExtension = widget.book.format.toLowerCase();

      if (fileExtension == 'epub') {
        debugPrint('🔖 开始解析EPUB章节...');
        _chapters = await _bookImportService.extractEpubChapters(
          widget.book.filePath,
        );

        // 如果分页已完成，更新章节页码
        if (_pages.isNotEmpty) {
          _chapters = await _bookImportService.updateChapterPages(
            _chapters,
            _bookContent,
            _pages,
          );
        }

        debugPrint('🔖 章节解析完成: ${_chapters.length} 个章节');
      } else {
        // 对于TXT等格式，生成简单的章节结构
        _generateSimpleChapters();
      }

      _chaptersLoaded = true;
    } catch (e) {
      debugPrint('❌ 章节加载失败: $e');
      _chapters = [];
    }
  }

  /// 为非EPUB格式生成简单的章节结构
  void _generateSimpleChapters() {
    _chapters = [];

    if (_pages.isEmpty) return;

    final chapterSize = (_pages.length / 10).ceil().clamp(1, 50); // 每10-50页一个章节

    for (int i = 0; i < _pages.length; i += chapterSize) {
      final chapterIndex = (i / chapterSize).floor() + 1;
      final startPage = i;
      final endPage = (i + chapterSize - 1).clamp(0, _pages.length - 1);

      _chapters.add(
        Chapter(
          title: '第 $chapterIndex 部分',
          startPage: startPage,
          endPage: endPage,
          level: 0,
        ),
      );
    }

    debugPrint('🔖 生成简单章节结构: ${_chapters.length} 个章节');
  }

  // 直接解析 EPUB，避免 isolate 通信限制
  Future<String> _parseEpubDirectly(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        // 尝试检查文件是否在新的Documents路径下
        final newPath = await _tryRelocateFile(filePath);
        if (newPath != null) {
          debugPrint('📂 文件已重新定位到: $newPath');
          return _parseEpubDirectly(newPath);
        }
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

  // 尝试重新定位文件 - 处理iOS沙盒路径变更问题
  Future<String?> _tryRelocateFile(String oldPath) async {
    try {
      // 从路径中提取文件名
      final fileName = oldPath.split('/').last;
      debugPrint('🔍 尝试重新定位文件: $fileName');

      // 获取当前的Documents目录
      final documentsDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory(path.join(documentsDir.path, 'books'));

      if (!await booksDir.exists()) {
        debugPrint('📂 books目录不存在，无法重新定位');
        return null;
      }

      // 检查文件是否在当前的books目录中
      final newPath = path.join(booksDir.path, fileName);
      final newFile = File(newPath);

      if (await newFile.exists()) {
        debugPrint('✅ 文件已重新定位到: $newPath');
        // 更新数据库中的文件路径
        await _updateBookFilePath(oldPath, newPath);
        return newPath;
      }

      debugPrint('❌ 无法在新路径中找到文件: $fileName');
      return null;
    } catch (e) {
      debugPrint('❌ 重新定位文件时出错: $e');
      return null;
    }
  }

  // 更新数据库中的文件路径
  Future<void> _updateBookFilePath(String oldPath, String newPath) async {
    try {
      final bookDao = BookDao();
      await bookDao.updateBookFilePath(widget.book.id!, newPath);
      debugPrint('✅ 已更新数据库中的文件路径');
    } catch (e) {
      debugPrint('❌ 更新文件路径失败: $e');
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
    // 使用异步处理避免UI阻塞
    _splitIntoPagesAsync(_bookContent);
  }

  // 异步分页处理，使用增强分页器
  Future<void> _splitIntoPagesAsync(String content) async {
    try {
      debugPrint('🔄 使用增强分页器处理内容，长度: ${content.length}');

      final screenSize = MediaQuery.of(context).size;
      final statusBarHeight = MediaQuery.of(context).padding.top;
      final isLandscape = screenSize.width > screenSize.height;

      // 使用增强分页器计算最佳参数
      final params = EnhancedTextPaginator.calculateOptimalParams(
        screenSize: screenSize,
        fontSize: _fontSize,
        lineHeight: _lineSpacing,
        padding: EdgeInsets.symmetric(
          horizontal: _horizontalPadding,
          vertical: _pageMargin,
        ),
        statusBarHeight: statusBarHeight,
        isLandscape: isLandscape,
        customSampleText: content.length > 100
            ? content.substring(0, 100)
            : content,
      );

      // 执行智能分页
      final pages = await EnhancedTextPaginator.paginateText(
        text: content,
        params: params,
      );

      if (mounted && !_isDisposed) {
        setState(() {
          _pages = pages.where((page) => page.trim().isNotEmpty).toList();

          // 确保页面索引在有效范围内
          if (_currentPageIndex >= _pages.length) {
            _currentPageIndex = _pages.isNotEmpty ? _pages.length - 1 : 0;
          }
          if (_currentPageIndex < 0) {
            _currentPageIndex = 0;
          }
        });

        // 更新页面控制器到正确位置
        if (_pageController.hasClients && _pages.isNotEmpty) {
          _pageController.animateToPage(
            _currentPageIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }

        // 更新数据库页数
        _updateBookTotalPages();

        debugPrint('✅ 增强分页完成: ${_pages.length}页');
      }
    } catch (e) {
      debugPrint('❌ 增强分页处理失败: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _pages = ['分页处理失败: $e\n\n请尝试调整字体大小或重新加载'];
        });
      }
    }
  }

  // 移除旧的分块方法，已被增强分页器替代

  // 处理单个内容块
  // 移除旧的分块处理方法，已被增强分页器替代

  // 更新书籍总页数
  void _updateBookTotalPages() {
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

  // [已删除] 原_standardizedPagination函数，已使用更高效的异步分页

  // 优化的分页算法实现 - 未使用，已移除避免语法错误

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

    // 使用防抖机制，避免频繁重新分页 - 增加防抖时间提升性能
    _repaginationTimer?.cancel();
    _repaginationTimer = Timer(const Duration(milliseconds: 800), () {
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

  // --- 统一主题配置 ---
  /// 为二级页面提供统一的主题配置
  BoxDecoration _getModalDecoration() {
    return BoxDecoration(
      color: _currentTheme.controlBarColor.withValues(alpha: 0.98),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      border: Border.all(
        color: _currentTheme.iconColor.withValues(alpha: 0.3),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: _currentTheme.textColor.withValues(alpha: 0.1),
          blurRadius: 20,
          offset: const Offset(0, -5),
        ),
      ],
    );
  }

  /// 获取二级页面的文本颜色 - 优化版
  Color _getModalTextColor() {
    switch (_currentTheme.name) {
      case 'day':
        return const Color(0xFF1A1A1A); // 深黑色文字
      case 'night':
        return const Color(0xFFE5E5E5); // 亮灰色文字
      case 'eye_protection':
        return const Color(0xFF1B3A1B); // 深绿色文字
      case 'parchment':
        return const Color(0xFF4A3E28); // 深棕色文字
      case 'sepia':
        return const Color(0xFF3D2F1F); // 深棕褐色文字
      default:
        return _currentTheme.controlBarTextColor;
    }
  }

  /// 获取二级页面的图标颜色 - 优化版
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

  /// 获取二级页面的分割线颜色 - 优化版
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
        return _currentTheme.iconColor.withValues(alpha: 0.3);
    }
  }

  /// 获取二级页面的背景色 - 优化版
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

  /// 获取二级页面的次要文字颜色
  Color _getModalSecondaryTextColor() {
    switch (_currentTheme.name) {
      case 'day':
        return const Color(0xFF757575); // 中灰色次要文字
      case 'night':
        return const Color(0xFF9E9E9E); // 浅灰色次要文字
      case 'eye_protection':
        return const Color(0xFF4A6B4A); // 中绿色次要文字
      case 'parchment':
        return const Color(0xFF8B7355); // 中棕色次要文字
      case 'sepia':
        return const Color(0xFF7D6E5D); // 中棕褐色次要文字
      default:
        return _getModalTextColor().withValues(alpha: 0.7);
    }
  }

  /// 获取二级页面的强调色
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

  /// 带防抖动的页面切换处理
  void _onPageChangedWithDebounce(int index) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastPageChangeTime = now;

    // 立即更新页面索引以确保UI响应
    if (mounted) {
      setState(() {
        _currentPageIndex = index;
        _isInitializing = false; // 标记初始化完成
      });
    }

    // 防抖动处理其他操作
    _debounceTimer?.cancel();
    _debounceTimer = Timer(PerformanceConfig.debounceDelay, () {
      if (_lastPageChangeTime == now && mounted) {
        _onPageTurn();
        _preloadAdjacentPages(); // 预加载相邻页面

        // 加载当前页面的高亮
        _loadCurrentPageHighlights();

        // 保存到定时器列表以便清理
        _timers.add(_debounceTimer!);
      }
    });
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

    // 如果控制栏显示中，且点击了控制栏区域，则不处理翻页
    if (_showControls &&
        (tapPosition.dy < 150 || tapPosition.dy > screenHeight - 200)) {
      return;
    }

    final leftBoundary = screenWidth / 3;
    final rightBoundary = screenWidth * 2 / 3;

    if (tapPosition.dx < leftBoundary) {
      // 左侧区域：上一页
      if (!_showControls) {
        _goToPreviousPage();
      }
    } else if (tapPosition.dx > rightBoundary) {
      // 右侧区域：下一页
      if (!_showControls) {
        _goToNextPage();
      }
    } else {
      // 中间区域：显示/隐藏控制栏
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
            _onPageChangedWithDebounce(index);
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

    // 智能显示区域计算 - 与增强分页算法保持严格一致
    final screenSize = MediaQuery.of(context).size;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isLandscape = screenSize.width > screenSize.height;

    // 使用与EnhancedTextPaginator完全相同的计算逻辑
    final targetContentHeight = screenSize.height * 0.90;
    final safeAreaHeight = screenSize.height * 0.10;

    // 根据设备类型确定安全区域分配比例 - 与分页器保持一致
    final deviceType = _getDeviceTypeForLayout(screenSize);
    double topSafeRatio;
    double bottomSafeRatio;

    switch (deviceType) {
      case 'tablet':
        topSafeRatio = isLandscape ? 0.3 : 0.4;
        bottomSafeRatio = isLandscape ? 0.7 : 0.6;
        break;
      case 'largeMobile':
        topSafeRatio = isLandscape ? 0.35 : 0.4;
        bottomSafeRatio = isLandscape ? 0.65 : 0.6;
        break;
      default: // mobile
        topSafeRatio = isLandscape ? 0.4 : 0.35;
        bottomSafeRatio = isLandscape ? 0.6 : 0.65;
        break;
    }

    // 计算实际的顶部和底部预留空间
    final topReserve = math.max(
      statusBarHeight + (safeAreaHeight * topSafeRatio),
      statusBarHeight + 10.0,
    );

    final bottomReserve = math.max(safeAreaHeight * bottomSafeRatio, 20.0);

    // 优化的padding设置，确保与分页算法一致
    final topPadding = topReserve;
    final bottomPadding = bottomReserve;

    // 确保内容区域充分利用可用高度
    final maxContentHeight = targetContentHeight - topReserve - bottomReserve;

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
              top: topPadding,
              bottom: bottomPadding,
            ),
            child: SizedBox(
              height: maxContentHeight, // 严格限制内容区域高度
              child: Column(
                children: [
                  // 主要文本内容区域 - 支持文本选择和高亮
                  Expanded(child: _buildHighlightedText(pageContent)),
                  // 页码标签 - 紧凑设计
                  Container(
                    height: 20.0,
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1} / ${_pages.length}',
                      style: TextStyle(
                        fontSize: 11,
                        color: _currentTheme.textColor.withValues(alpha: 0.6),
                        fontFamily: 'System',
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
      top: _showControls ? 0 : -_topBarHideOffset,
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
                              color: _getModalSecondaryTextColor(),
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
    // final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    // 统一的控制栏背景色，与阅读主题保持一致
    // final Color toolbarBgColor = _currentTheme.controlBarColor;
    // final Color handleColor = _currentTheme.iconColor.withValues(alpha:  0.8);
    // final Color iconColor = _currentTheme.iconColor;
    // final Color textColor = _currentTheme.controlBarTextColor;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      bottom: _showControls ? 0 : -_controlBarHideOffset,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _showControls ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !_showControls,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 12),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: bottomPadding + 12,
                  ),
                  decoration: BoxDecoration(
                    // 使用阅读主题的控制栏颜色，提高透明度以获得更好的毛玻璃效果
                    color: _currentTheme.controlBarColor.withValues(
                      alpha: 0.92,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border.all(
                      color: _currentTheme.sliderActiveColor.withValues(
                        alpha: 0.2,
                      ),
                      width: 1,
                    ),
                    // 添加微妙的阴影以增强层次感
                    boxShadow: [
                      BoxShadow(
                        color: _currentTheme.backgroundColor.withValues(
                          alpha: 0.1,
                        ),
                        blurRadius: 20,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 可拖拽的小横条指示器 - 使用主题色
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: _currentTheme.sliderActiveColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ModernToolbarButton(
            icon: Icons.format_list_bulleted_rounded,
            label: '目录',
            onTap: _showTableOfContents,
            iconColor: _currentTheme.controlBarTextColor,
            pressedColor: _currentTheme.sliderActiveColor.withValues(
              alpha: 0.15,
            ),
            iconSize: 24,
            fontSize: 12,
          ),
          _ModernToolbarButton(
            icon: Icons.record_voice_over_rounded,
            label: '朗读',
            onTap: _showTtsPanel,
            iconColor: _currentTheme.controlBarTextColor,
            pressedColor: _currentTheme.sliderActiveColor.withValues(
              alpha: 0.15,
            ),
            iconSize: 24,
            fontSize: 12,
          ),
          _ModernToolbarButton(
            icon: _isCurrentPageBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_add_rounded,
            label: '书签',
            onTap: _toggleBookmark,
            iconColor: _isCurrentPageBookmarked
                ? _currentTheme.sliderActiveColor
                : _currentTheme.controlBarTextColor,
            pressedColor: _currentTheme.sliderActiveColor.withValues(
              alpha: 0.15,
            ),
            iconSize: 24,
            fontSize: 12,
          ),
          _ModernToolbarButton(
            icon: Icons.share_rounded,
            label: '分享',
            onTap: _showShareDialog,
            iconColor: _currentTheme.controlBarTextColor,
            pressedColor: _currentTheme.sliderActiveColor.withValues(
              alpha: 0.15,
            ),
            iconSize: 24,
            fontSize: 12,
          ),
          _ModernToolbarButton(
            icon: Icons.palette_rounded,
            label: '主题',
            onTap: _showThemePanel,
            iconColor: _currentTheme.controlBarTextColor,
            pressedColor: _currentTheme.sliderActiveColor.withValues(
              alpha: 0.15,
            ),
            iconSize: 24,
            fontSize: 12,
          ),
          _ModernToolbarButton(
            icon: Icons.tune_rounded,
            label: '设置',
            onTap: _showSettingsPanel,
            iconColor: _currentTheme.controlBarTextColor,
            pressedColor: _currentTheme.sliderActiveColor.withValues(
              alpha: 0.15,
            ),
            iconSize: 24,
            fontSize: 12,
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
                        // 主题内容
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: _buildEnhancedColorThemeSelector(
                              setModalState,
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
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSettingSection(
                                  title: '文字设置',
                                  icon: Icons.text_fields_rounded,
                                  children: [
                                    _buildEnhancedSettingSlider(
                                      label: '字号',
                                      value: _fontSize,
                                      min: 12,
                                      max: 30,
                                      divisions: 18,
                                      unit: 'pt',
                                      icon: Icons.format_size,
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
                                      onChanged: (v) {
                                        setModalState(() => _letterSpacing = v);
                                        setState(() {});
                                        _saveSetting(
                                          (p) =>
                                              p.setDouble('letterSpacing', v),
                                        );
                                      },
                                    ),
                                    _buildFontFamilySelector(setModalState),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                _buildSettingSection(
                                  title: '页面设置',
                                  icon: Icons.article_rounded,
                                  children: [
                                    _buildEnhancedSettingSlider(
                                      label: '页面边距',
                                      value: _pageMargin,
                                      min: 8,
                                      max: 32,
                                      divisions: 12,
                                      unit: 'px',
                                      icon: Icons.crop_free,
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
                                  children: [
                                    _buildSwitchSetting(
                                      label: '保持屏幕常亮',
                                      value: _keepScreenOn,
                                      icon: Icons.screen_lock_portrait,
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
                                color: _getModalDividerColor(),
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
                                    backgroundColor:
                                        _currentTheme.sliderActiveColor,
                                    foregroundColor:
                                        _currentTheme.controlBarColor,
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
  }) {
    final textColor = _getModalTextColor();
    final sectionBgColor = _getModalBackgroundColor().withValues(alpha: 0.6);
    final sectionBorderColor = _getModalDividerColor();
    final iconBgColor = _currentTheme.sliderActiveColor.withValues(alpha: 0.3);
    final iconColor = _currentTheme.sliderActiveColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: sectionBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sectionBorderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: _currentTheme.textColor.withValues(alpha: 0.1),
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
    required ValueChanged<double> onChanged,
  }) {
    final textColor = _getModalTextColor();
    final activeColor = _currentTheme.sliderActiveColor;
    final inactiveColor = _getModalDividerColor().withValues(alpha: 0.5);
    final badgeColor = activeColor.withValues(alpha: 0.15);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getModalBackgroundColor().withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: activeColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: activeColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
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
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: activeColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${value.toStringAsFixed(unit == 'x' ? 1 : 0)}$unit',
                      style: TextStyle(
                        color: activeColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              // 右侧值显示
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: activeColor.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.tune, color: activeColor, size: 16),
                    const SizedBox(height: 2),
                    Text(
                      value.toStringAsFixed(unit == 'x' ? 1 : 0),
                      style: TextStyle(
                        color: activeColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 8,
              thumbShape: CustomSliderThumbShape(
                enabledThumbRadius: 14,
                thumbColor: activeColor,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
              activeTrackColor: activeColor,
              inactiveTrackColor: inactiveColor,
              overlayColor: activeColor.withValues(alpha: 0.15),
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

  Widget _buildFontFamilySelector(StateSetter setModalState) {
    final textColor = _getModalTextColor();
    final cardColor = _getModalBackgroundColor().withValues(alpha: 0.6);
    final activeColor = _currentTheme.sliderActiveColor;

    final fontFamilies = [
      {
        'name': '系统默认',
        'value': 'System',
        'description': '跟随系统',
        'icon': Icons.phone_android,
      },
      {
        'name': '宋体',
        'value': 'Serif',
        'description': '经典衬线',
        'icon': Icons.text_fields,
      },
      {
        'name': '黑体',
        'value': 'Sans-serif',
        'description': '现代无衬线',
        'icon': Icons.format_bold,
      },
      {
        'name': '等宽字体',
        'value': 'Monospace',
        'description': '代码风格',
        'icon': Icons.code,
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _getModalDividerColor(), width: 1),
        boxShadow: [
          BoxShadow(
            color: _currentTheme.textColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.font_download_rounded,
                  size: 18,
                  color: activeColor,
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
          const SizedBox(height: 20),
          // 使用网格布局替代Wrap，更整齐美观
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: fontFamilies.length,
            itemBuilder: (context, index) {
              final font = fontFamilies[index];
              final isSelected = _fontFamily == font['value'];

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setModalState(
                        () => _fontFamily = font['value'] as String,
                      );
                      setState(() {});
                      _saveSetting(
                        (p) =>
                            p.setString('fontFamily', font['value'] as String),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? activeColor.withValues(alpha: 0.15)
                            : _getModalBackgroundColor().withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? activeColor
                              : _getModalDividerColor().withValues(alpha: 0.5),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: activeColor.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Icon(
                                font['icon'] as IconData,
                                size: 16,
                                color: isSelected
                                    ? activeColor
                                    : textColor.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  font['name'] as String,
                                  style: TextStyle(
                                    color: isSelected ? activeColor : textColor,
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    fontFamily: font['value'] == 'System'
                                        ? null
                                        : font['value'] as String?,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            font['description'] as String,
                            style: TextStyle(
                              color: (isSelected ? activeColor : textColor)
                                  .withValues(alpha: 0.6),
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  Widget _buildSwitchSetting({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    IconData? icon,
  }) {
    final textColor = _getModalTextColor();
    final activeColor = _currentTheme.sliderActiveColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: _getModalBackgroundColor().withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getModalDividerColor(), width: 1),
        boxShadow: [
          BoxShadow(
            color: _currentTheme.textColor.withValues(alpha: 0.1),
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
            thumbColor: WidgetStateProperty.resolveWith<Color?>((
              Set<WidgetState> states,
            ) {
              if (states.contains(WidgetState.selected)) {
                return _getModalBackgroundColor();
              }
              return _getModalIconColor();
            }),
            activeTrackColor: activeColor,
            inactiveTrackColor: _getModalDividerColor(),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedColorThemeSelector(StateSetter setModalState) {
    final textColor = _getModalTextColor();
    final selectedBorderColor = _getModalAccentColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.palette_rounded,
              color: _getModalAccentColor(),
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
                        : _getModalDividerColor(),
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

  // 未使用的方法 - 保留作为参考
  /*
  Future<void> _removeBookmark() async {
    // 保存要删除的书签信息（用于撤销功能）
    final bookmarkToRemove = _bookmarks.firstWhere(
      (bookmark) => bookmark.pageNumber == _currentPageIndex + 1,
      orElse: () => Bookmark(
        bookId: widget.book.id!,
        pageNumber: _currentPageIndex + 1,
        note: '',
        createDate: DateTime.now(),
      ),
    );

    try {
      // 立即更新UI状态
      if (mounted) {
        setState(() {
          _isCurrentPageBookmarked = false;
          _bookmarks.removeWhere(
            (bookmark) => bookmark.pageNumber == _currentPageIndex + 1,
          );
        });
      }

      // 显示撤销消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.bookmark_remove,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text('已删除书签：第${_currentPageIndex + 1}页'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '撤销',
            textColor: Colors.white,
            onPressed: () => _restoreBookmark(bookmarkToRemove),
          ),
        ),
      );
    } catch (e) {
      debugPrint('删除书签失败: $e');

      // 回滚UI状态
      if (mounted) {
        setState(() {
          _isCurrentPageBookmarked = true;
          _bookmarks.add(bookmarkToRemove);
          _bookmarks.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
        });

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
  */

  Future<void> _restoreBookmark(Bookmark bookmark) async {
    try {
      // 立即更新UI状态
      if (mounted) {
        setState(() {
          _bookmarks.add(bookmark);
          _bookmarks.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));

          // 如果恢复的是当前页的书签，更新状态
          if (bookmark.pageNumber == _currentPageIndex + 1) {
            _isCurrentPageBookmarked = true;
          }
        });
      }

      // 后台保存到数据库
      await _bookmarkDao.insertBookmark(bookmark);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.bookmark_added, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('已恢复书签：第${bookmark.pageNumber}页'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('恢复书签失败: $e');

      // 回滚UI状态
      if (mounted) {
        setState(() {
          _bookmarks.removeWhere((b) => b.pageNumber == bookmark.pageNumber);
          if (bookmark.pageNumber == _currentPageIndex + 1) {
            _isCurrentPageBookmarked = false;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('恢复书签失败'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteBookmarkWithAnimation(int bookmarkId) async {
    // 找到要删除的书签
    final bookmarkToDelete = _bookmarks.firstWhere(
      (bookmark) => bookmark.id == bookmarkId,
      orElse: () => Bookmark(
        id: bookmarkId,
        bookId: widget.book.id!,
        pageNumber: 0,
        note: '',
        createDate: DateTime.now(),
      ),
    );

    try {
      // 立即更新UI状态
      if (mounted) {
        setState(() {
          _bookmarks.removeWhere((bookmark) => bookmark.id == bookmarkId);

          // 如果删除的是当前页的书签，更新状态
          if (bookmarkToDelete.pageNumber == _currentPageIndex + 1) {
            _isCurrentPageBookmarked = false;
          }
        });
      }

      // 后台从数据库删除
      await _bookmarkDao.deleteBookmark(bookmarkId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.bookmark_remove,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text('已删除书签：第${bookmarkToDelete.pageNumber}页'),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: '撤销',
              textColor: Colors.white,
              onPressed: () => _restoreBookmark(bookmarkToDelete),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('删除书签失败: $e');

      // 回滚UI状态
      if (mounted) {
        setState(() {
          _bookmarks.add(bookmarkToDelete);
          _bookmarks.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
          if (bookmarkToDelete.pageNumber == _currentPageIndex + 1) {
            _isCurrentPageBookmarked = true;
          }
        });

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

  // 编辑书签
  void _editBookmark(Bookmark bookmark) {
    Navigator.pop(context); // 关闭书签面板

    showDialog(
      context: context,
      builder: (context) => _buildBookmarkEditDialog(bookmark),
    );
  }

  Widget _buildBookmarkEditDialog(Bookmark bookmark) {
    final TextEditingController noteController = TextEditingController(
      text: bookmark.note,
    );

    return AlertDialog(
      backgroundColor: _currentTheme.backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.edit_note, color: _currentTheme.textColor, size: 24),
          const SizedBox(width: 12),
          Text(
            '编辑书签',
            style: TextStyle(
              color: _currentTheme.textColor,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _currentTheme.sliderActiveColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bookmark,
                  color: _currentTheme.sliderActiveColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '第 ${bookmark.pageNumber} 页',
                  style: TextStyle(
                    color: _currentTheme.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '备注：',
            style: TextStyle(
              color: _currentTheme.textColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '为这个书签添加备注...',
              hintStyle: TextStyle(
                color: _currentTheme.textColor.withValues(alpha: 0.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: _currentTheme.textColor.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: _currentTheme.sliderActiveColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: TextStyle(color: _currentTheme.textColor, fontSize: 14),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            '取消',
            style: TextStyle(
              color: _currentTheme.textColor.withValues(alpha: 0.7),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            _updateBookmarkNote(bookmark, noteController.text.trim());
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _currentTheme.sliderActiveColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }

  // 更新书签备注
  Future<void> _updateBookmarkNote(Bookmark bookmark, String note) async {
    try {
      final updatedBookmark = bookmark.copyWith(note: note);
      await _bookmarkDao.updateBookmark(updatedBookmark);

      if (mounted) {
        setState(() {
          final index = _bookmarks.indexWhere((b) => b.id == bookmark.id);
          if (index != -1) {
            _bookmarks[index] = updatedBookmark;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text('书签备注已更新'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('更新书签备注失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('更新书签备注失败'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

  // 快速切换书签
  void _toggleBookmark() async {
    if (_isCurrentPageBookmarked) {
      // 删除当前页书签
      final bookmarksToRemove = _bookmarks
          .where((b) => b.pageNumber == _currentPageIndex + 1)
          .toList();

      for (final bookmark in bookmarksToRemove) {
        await _bookmarkDao.deleteBookmark(bookmark.id!);
      }

      setState(() {
        _bookmarks.removeWhere((b) => b.pageNumber == _currentPageIndex + 1);
        _isCurrentPageBookmarked = false;
      });

      // 触觉反馈
      HapticFeedback.lightImpact();
    } else {
      // 添加书签
      final bookmark = Bookmark(
        bookId: widget.book.id!,
        pageNumber: _currentPageIndex + 1,
        note: '',
        createDate: DateTime.now(),
      );

      final bookmarkId = await _bookmarkDao.insertBookmark(bookmark);

      setState(() {
        _bookmarks.add(bookmark.copyWith(id: bookmarkId));
        _isCurrentPageBookmarked = true;
      });

      // 触觉反馈
      HapticFeedback.mediumImpact();
    }
  }

  // 显示进度面板
  void _showProgressPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => _buildProgressPanel(),
    );
  }

  // 显示TTS朗读面板
  void _showTtsPanel() {
    final currentPageContent = _getCurrentPageText();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => TtsPanelEnhanced(textToRead: currentPageContent),
    );
  }

  /// 获取设备类型用于布局计算 - 与EnhancedTextPaginator保持一致
  String _getDeviceTypeForLayout(Size screenSize) {
    final diagonal = math.sqrt(
      screenSize.width * screenSize.width +
          screenSize.height * screenSize.height,
    );

    if (diagonal > 1200) {
      return 'tablet';
    } else if (diagonal > 800) {
      return 'largeMobile';
    } else {
      return 'mobile';
    }
  }

  // --- 高亮功能 ---

  /// 构建包含高亮的文本
  Widget _buildHighlightedText(String pageContent) {
    final textStyle = TextStyle(
      fontSize: _fontSize,
      height: _lineSpacing,
      letterSpacing: _letterSpacing,
      color: _currentTheme.textColor,
      fontFamily: _fontFamily == 'System' ? null : _fontFamily,
    );

    return CustomSelectableText(
      text: pageContent,
      style: textStyle,
      highlights: _currentPageHighlights,
      textAlign: TextAlign.justify,
      onTextSelected: (selectedText, startOffset, endOffset) {
        _handleTextSelected(selectedText, startOffset, endOffset);
      },
      onHighlightTap: _handleHighlightTap,
    );
  }

  /// 加载当前页面的高亮
  Future<void> _loadCurrentPageHighlights() async {
    try {
      final highlights = await _highlightDao.getHighlightsByPage(
        widget.book.id!,
        _currentPageIndex + 1,
      );

      if (mounted) {
        setState(() {
          _currentPageHighlights = highlights;
        });
      }
    } catch (e) {
      debugPrint('加载高亮失败: $e');
    }
  }

  /// 处理文本选择 - 通过SelectableText的内置选择功能
  void _onTextSelection() {
    // 这个方法将被 SelectableText 的选择回调触发
    // 暂时保留为空，等待SelectableText选择回调的实现
  }

  /// 处理文字选中
  void _handleTextSelected(
    String selectedText,
    int startOffset,
    int endOffset,
  ) {
    setState(() {
      _selectedText = selectedText;
      _selectionStart = startOffset;
      _selectionEnd = endOffset;
    });

    _showSelectionToolbar();
  }

  /// 显示选择工具栏
  void _showSelectionToolbar() {
    if (_selectedText == null) return;

    _hideSelectionToolbar(); // 确保之前的工具栏被隐藏

    final overlay = Overlay.of(context);
    _selectionToolbarOverlay = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 150, // 在控制栏上方显示
        left: 20,
        right: 20,
        child: Center(
          child: EnhancedTextSelectionToolbar(
            selectedText: _selectedText!,
            bookId: widget.book.id!,
            pageNumber: _currentPageIndex + 1,
            chapterTitle: _getCurrentChapterTitle(),
            onCopy: _handleCopyText,
            onHighlight: _handleHighlightText,
            onNote: _handleAddNote,
            onShare: _handleShareText,
            onClose: _hideSelectionToolbar,
            backgroundColor: _currentTheme.controlBarColor,
            iconColor: _currentTheme.sliderActiveColor,
            textColor: _currentTheme.controlBarTextColor,
          ),
        ),
      ),
    );

    overlay.insert(_selectionToolbarOverlay!);
  }

  /// 隐藏选择工具栏
  void _hideSelectionToolbar() {
    _selectionToolbarOverlay?.remove();
    _selectionToolbarOverlay = null;

    setState(() {
      _selectedText = null;
      _selectionStart = null;
      _selectionEnd = null;
      // _isTextSelectionMode = false; // TODO: 待实现
    });
  }

  /// 处理复制文字
  void _handleCopyText() {
    // EnhancedTextSelectionToolbar已经处理了复制逻辑
  }

  /// 处理高亮文字
  void _handleHighlightText() async {
    if (_selectedText == null ||
        _selectionStart == null ||
        _selectionEnd == null) {
      return;
    }

    final color = await showHighlightColorPicker(context: context);
    if (color == null) return;

    await _createHighlight(
      selectedText: _selectedText!,
      startOffset: _selectionStart!,
      endOffset: _selectionEnd!,
      color: color,
    );

    // 隐藏选择工具栏
    _hideSelectionToolbar();
  }

  /// 创建高亮
  Future<void> _createHighlight({
    required String selectedText,
    required int startOffset,
    required int endOffset,
    required Color color,
    String? noteText,
  }) async {
    try {
      final highlight = Highlight(
        bookId: widget.book.id!,
        pageNumber: _currentPageIndex + 1,
        selectedText: selectedText,
        startOffset: startOffset,
        endOffset: endOffset,
        color: color,
        chapter: _getCurrentChapterTitle(),
        noteText: noteText,
      );

      await _highlightDao.insertHighlight(highlight);
      await _loadCurrentPageHighlights(); // 重新加载高亮

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已添加${Highlight.getColorName(color)}高亮'),
            backgroundColor: color.withValues(alpha: 0.8),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('创建高亮失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('添加高亮失败')));
      }
    }
  }

  /// 处理添加笔记
  void _handleAddNote() {
    // 显示笔记输入对话框
    _showNoteDialog();
  }

  /// 显示笔记对话框
  void _showNoteDialog() {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加笔记'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选中文字：',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: _currentTheme.textColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _currentTheme.backgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _selectedText ?? '',
                style: TextStyle(fontSize: 14, color: _currentTheme.textColor),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: '笔记内容',
                hintText: '请输入您的笔记...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final noteText = noteController.text.trim();
              if (noteText.isNotEmpty) {
                final color = await showHighlightColorPicker(context: context);
                if (color != null) {
                  await _createHighlight(
                    selectedText: _selectedText!,
                    startOffset: _selectionStart!,
                    endOffset: _selectionEnd!,
                    color: color,
                    noteText: noteText,
                  );
                }
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 处理分享文字
  void _handleShareText() {
    // EnhancedTextSelectionToolbar已经处理了分享逻辑
  }

  /// 处理高亮点击
  void _handleHighlightTap(Highlight highlight) {
    // 显示高亮详情
    _showHighlightDetails(highlight);
  }

  /// 处理高亮长按
  void _handleHighlightLongPress(Highlight highlight) {
    // 显示高亮操作菜单
    _showHighlightMenu(highlight);
  }

  /// 显示高亮详情
  void _showHighlightDetails(Highlight highlight) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: highlight.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text('${Highlight.getColorName(highlight.color)}高亮'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              highlight.selectedText,
              style: TextStyle(
                fontSize: 16,
                backgroundColor: highlight.color.withValues(alpha: 0.3),
              ),
            ),
            if (highlight.noteText?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              const Text('笔记：', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(highlight.noteText!),
            ],
            const SizedBox(height: 16),
            Text(
              '创建时间：${_formatDateTime(highlight.createDate)}',
              style: TextStyle(
                fontSize: 12,
                color: _currentTheme.textColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 显示高亮操作菜单
  void _showHighlightMenu(Highlight highlight) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: _currentTheme.sliderActiveColor),
              title: const Text('编辑笔记'),
              onTap: () {
                Navigator.pop(context);
                _editHighlightNote(highlight);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.palette,
                color: _currentTheme.sliderActiveColor,
              ),
              title: const Text('更改颜色'),
              onTap: () {
                Navigator.pop(context);
                _changeHighlightColor(highlight);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除高亮'),
              onTap: () {
                Navigator.pop(context);
                _deleteHighlight(highlight);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 编辑高亮笔记
  void _editHighlightNote(Highlight highlight) {
    final noteController = TextEditingController(
      text: highlight.noteText ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑笔记'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            labelText: '笔记内容',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final noteText = noteController.text.trim();
              await _updateHighlight(
                highlight.copyWith(
                  noteText: noteText.isEmpty ? null : noteText,
                  updateDate: DateTime.now(),
                ),
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 更改高亮颜色
  void _changeHighlightColor(Highlight highlight) async {
    final newColor = await showHighlightColorPicker(
      context: context,
      initialColor: highlight.color,
    );

    if (newColor != null && newColor != highlight.color) {
      await _updateHighlight(
        highlight.copyWith(color: newColor, updateDate: DateTime.now()),
      );
    }
  }

  /// 更新高亮
  Future<void> _updateHighlight(Highlight highlight) async {
    try {
      // 注意：这里需要在HighlightDao中添加updateHighlight方法
      // await _highlightDao.updateHighlight(highlight);
      await _loadCurrentPageHighlights();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('高亮已更新')));
      }
    } catch (e) {
      debugPrint('更新高亮失败: $e');
    }
  }

  /// 删除高亮
  void _deleteHighlight(Highlight highlight) async {
    try {
      await _highlightDao.deleteHighlight(highlight.id!);
      await _loadCurrentPageHighlights();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('高亮已删除')));
      }
    } catch (e) {
      debugPrint('删除高亮失败: $e');
    }
  }

  /// 获取当前章节标题
  String _getCurrentChapterTitle() {
    if (_chapters.isNotEmpty) {
      // 寻找当前页面所属的章节
      for (final chapter in _chapters.reversed) {
        if (chapter.startPage <= _currentPageIndex + 1) {
          return chapter.title;
        }
      }
    }
    return '第${_currentPageIndex + 1}页';
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}年${dateTime.month}月${dateTime.day}日 '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // 显示分享对话框
  void _showShareDialog() {
    final currentPageContent = _getCurrentPageText();
    final progressPercentage = (_currentPageIndex + 1) / _pages.length * 100;

    showShareDialog(
      context: context,
      bookTitle: widget.book.title,
      author: widget.book.author,
      currentPageContent: currentPageContent,
      currentPage: _currentPageIndex + 1,
      totalPages: _pages.length,
      progressPercentage: progressPercentage,
      readingTime: Duration(minutes: _getTotalReadingMinutes()),
    );
  }

  // 获取当前页面文本内容
  String _getCurrentPageText() {
    if (_currentPageIndex < _pages.length) {
      return _pages[_currentPageIndex].replaceAll(RegExp(r'<[^>]*>'), '');
    }
    return '';
  }

  // 获取总阅读时长（分钟）
  int _getTotalReadingMinutes() {
    // TODO: 从数据库获取实际阅读时长
    // 这里暂时返回一个估算值
    return (_currentPageIndex + 1) * 2; // 假设每页阅读2分钟
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
    return TocWidget(
      book: widget.book,
      chapters: _chapters,
      bookmarks: _bookmarks,
      currentPageIndex: _currentPageIndex,
      onPageTap: (pageIndex) {
        Navigator.pop(context);
        _goToPage(pageIndex);
      },
      onBookmarkTap: (bookmark) {
        Navigator.pop(context);
        _goToPage(bookmark.pageNumber - 1);
      },
    );
  }

  // 构建进度面板
  Widget _buildProgressPanel() {
    final progress = _pages.isNotEmpty
        ? (_currentPageIndex + 1) / _pages.length
        : 0.0;
    final progressPercent = (progress * 100).toStringAsFixed(1);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: _getModalDecoration(),
            child: Column(
              children: [
                // 标题栏
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getModalAccentColor().withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.data_usage_rounded,
                          color: _getModalAccentColor(),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '阅读进度',
                        style: TextStyle(
                          color: _getModalTextColor(),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                // 进度信息
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // 进度环形图
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _getModalAccentColor().withValues(
                                alpha: 0.3,
                              ),
                              width: 8,
                            ),
                          ),
                          child: Stack(
                            children: [
                              // 进度弧
                              SizedBox(
                                width: 120,
                                height: 120,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 8,
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation(
                                    _getModalAccentColor(),
                                  ),
                                ),
                              ),
                              // 百分比文字
                              Center(
                                child: Text(
                                  '$progressPercent%',
                                  style: TextStyle(
                                    color: _getModalTextColor(),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // 详细信息
                        _buildProgressInfo('当前页码', '${_currentPageIndex + 1}'),
                        _buildProgressInfo('总页数', '${_pages.length}'),
                        _buildProgressInfo(
                          '剩余页数',
                          '${_pages.length - _currentPageIndex - 1}',
                        ),

                        const SizedBox(height: 24),

                        // 快速跳转按钮
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _goToPage(0);
                                },
                                icon: const Icon(Icons.first_page),
                                label: const Text('回到开头'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _getModalAccentColor()
                                      .withValues(alpha: 0.2),
                                  foregroundColor: _getModalAccentColor(),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _goToPage(_pages.length - 1);
                                },
                                icon: const Icon(Icons.last_page),
                                label: const Text('跳到末尾'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _getModalAccentColor()
                                      .withValues(alpha: 0.2),
                                  foregroundColor: _getModalAccentColor(),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _getModalSecondaryTextColor(),
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: _getModalTextColor(),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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

  /// 保存阅读进度（优化版）
  Future<void> _saveReadingProgress() async {
    if (_isInitializing || !mounted) return;

    try {
      // 异步保存，避免阻塞UI
      _bookDao.updateBook(widget.book.copyWith(currentPage: _currentPageIndex));
    } catch (e) {
      // 静默处理错误
      debugPrint('保存阅读进度失败: $e');
    }
  }

  /// 预加载相邻页面内容
  void _preloadAdjacentPages() {
    _preloadTimer?.cancel();
    _preloadTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      final startIndex =
          (_currentPageIndex - PerformanceConfig.preloadPageCount).clamp(
            0,
            _pages.length - 1,
          );
      final endIndex = (_currentPageIndex + PerformanceConfig.preloadPageCount)
          .clamp(0, _pages.length - 1);

      for (int i = startIndex; i <= endIndex; i++) {
        if (!_pageCacheManager.hasPage(i) && i < _pages.length) {
          _pageCacheManager.setPage(i, _pages[i]);
        }
      }
    });
  }

  @override
  void dispose() {
    // 标记为已销毁
    _isDisposed = true;

    // 清理所有定时器
    _hideControlsTimer?.cancel();
    _autoScrollTimer?.cancel();
    _repaginationTimer?.cancel();
    _saveProgressTimer?.cancel();
    _preloadTimer?.cancel();
    _debounceTimer?.cancel();

    // 清理定时器列表
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();

    // 清理订阅
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // 清理页面控制器和缓存
    _pageController.dispose();
    _pageCacheManager.clear();

    // 恢复系统UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );

    // 保存阅读统计
    if (_sessionStartTime != null) {
      final duration = DateTime.now().difference(_sessionStartTime!);
      if (duration.inSeconds > 10) {
        _statsDao.insertReadingTime(DateTime.now(), duration.inSeconds);
      }
    }

    // 最后保存进度
    Future.delayed(Duration.zero, () {
      _saveReadingProgress();
    });

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
                    backgroundColor: _getModalAccentColor().withValues(
                      alpha: 0.3,
                    ),
                    foregroundColor: _getModalTextColor(),
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
                    backgroundColor: _getModalAccentColor().withValues(
                      alpha: 0.3,
                    ),
                    foregroundColor: _getModalTextColor(),
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
                color: _getModalSecondaryTextColor(),
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
        color: _getModalBackgroundColor().withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: _getModalDividerColor(), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '分享选项',
            style: TextStyle(
              color: _getModalTextColor(),
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
                color: _getModalAccentColor().withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.content_copy, color: _getModalAccentColor()),
            ),
            title: Text(
              '复制当前页面',
              style: TextStyle(color: _getModalTextColor()),
            ),
            subtitle: Text(
              '复制当前页面内容到剪贴板',
              style: TextStyle(color: _getModalSecondaryTextColor()),
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
                color: _getModalAccentColor().withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.timeline, color: _getModalAccentColor()),
            ),
            title: Text(
              '分享阅读进度',
              style: TextStyle(color: _getModalTextColor()),
            ),
            subtitle: Text(
              '分享书籍信息和阅读进度',
              style: TextStyle(color: _getModalSecondaryTextColor()),
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
                color: _getModalAccentColor().withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.format_quote, color: _getModalAccentColor()),
            ),
            title: Text(
              '创建书摘卡片',
              style: TextStyle(color: _getModalTextColor()),
            ),
            subtitle: Text(
              '生成精美的书摘分享卡片',
              style: TextStyle(color: _getModalSecondaryTextColor()),
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

  const _ModernToolbarButton({
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
              width: 56, // 进一步减少宽度
              height: 48, // 进一步减少高度
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
                    size: widget.iconSize, // 使用可配置的图标大小
                  ),
                  const SizedBox(height: 3), // 进一步减少间距
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.iconColor,
                      fontSize: widget.fontSize, // 使用可配置的字体大小
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
