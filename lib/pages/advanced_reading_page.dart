import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';
import '../models/chapter.dart';
import '../services/advanced_text_paginator.dart';
import '../widgets/advanced_text_reader_widget.dart';

/// 高级阅读页面 - 基于anx-reader技术的精确分页阅读器
class AdvancedReadingPage extends StatefulWidget {
  final Book book;
  final int? initialChapterIndex;
  final double? initialProgress;

  const AdvancedReadingPage({
    super.key,
    required this.book,
    this.initialChapterIndex,
    this.initialProgress,
  });

  @override
  State<AdvancedReadingPage> createState() => _AdvancedReadingPageState();
}

class _AdvancedReadingPageState extends State<AdvancedReadingPage>
    with TickerProviderStateMixin {
  // --- 核心状态 ---
  final AdvancedTextReaderController _readerController =
      AdvancedTextReaderController();
  String _bookContent = '';
  // String _fullText = ''; // 完整文本内容 - 未使用
  PageInfo? _currentPageInfo;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // --- 阅读设置 ---
  late ReadingTheme _currentTheme;
  double _fontSize = 16.0;
  double _lineSpacing = 1.6;
  double _letterSpacing = 0.0;
  String _fontFamily = 'System';
  bool _isScrollMode = false;
  int _maxColumnCount = 1;

  // --- UI状态 ---
  bool _showControlBar = false;
  bool _showToc = false;
  bool _showSettings = false;
  bool _showSearch = false;
  bool _keepScreenOn = false;

  // --- 控制器和动画 ---
  late AnimationController _controlBarAnimationController;
  late Animation<double> _controlBarAnimation;
  final TextEditingController _searchController = TextEditingController();
  Timer? _hideControlBarTimer;

  // --- 阅读数据 ---
  List<Chapter> _chapters = [];
  int _currentChapterIndex = 0;
  // List<Bookmark> _bookmarks = []; // 移除未使用的字段
  List<SearchResult> _searchResults = [];
  int _currentSearchIndex = -1;

  // --- 统计数据 ---
  DateTime? _readingStartTime;
  // int _totalReadingTimeSeconds = 0; // 总阅读时间(秒) - 未使用

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
    _searchController.dispose();
    _hideControlBarTimer?.cancel();
    _saveReadingProgress();
    _updateReadingStats();
    super.dispose();
  }

  // --- 初始化方法 ---

  void _initializeAnimations() {
    _controlBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlBarAnimation = CurvedAnimation(
      parent: _controlBarAnimationController,
      curve: Curves.easeInOut,
    );
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _fontSize = prefs.getDouble('advanced_reading_font_size') ?? 16.0;
        _lineSpacing = prefs.getDouble('advanced_reading_line_spacing') ?? 1.6;
        _letterSpacing =
            prefs.getDouble('advanced_reading_letter_spacing') ?? 0.0;
        _fontFamily =
            prefs.getString('advanced_reading_font_family') ?? 'System';
        _isScrollMode = prefs.getBool('advanced_reading_scroll_mode') ?? false;
        _maxColumnCount = prefs.getInt('advanced_reading_max_columns') ?? 1;
        _keepScreenOn =
            prefs.getBool('advanced_reading_keep_screen_on') ?? false;

        final themeName = prefs.getString('advanced_reading_theme') ?? 'day';
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

      // 加载书签
      await _loadBookmarks();

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
      // TODO: 实现章节加载逻辑
      final chapters = <Chapter>[]; // 临时空列表
      if (chapters.isEmpty) {
        // 使用示例内容
        _bookContent =
            '这是一个演示页面\n\n该页面展示了基于anx-reader技术的精确分页功能。\n\n在实际应用中，这里会加载真实的书籍内容。';
        return;
      }

      final buffer = StringBuffer();
      for (int i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        // if (chapter.HtmlContent?.isNotEmpty == true) { // Chapter模型不包含HtmlContent
        if (buffer.isNotEmpty) {
          buffer.writeln('\n\n${'═' * 30}\n');
        }

        // 添加章节标题
        if (chapter.title.isNotEmpty) {
          buffer.writeln('${chapter.title}\n');
        }

        // 添加章节内容 - 演示数据
        buffer.writeln('这是第${i + 1}章的内容...');
        // }
      }

      _chapters = chapters;
      _bookContent = buffer.toString();
      _currentChapterIndex = widget.initialChapterIndex ?? 0;

      if (_bookContent.isEmpty) {
        throw Exception('书籍内容为空');
      }
    } catch (e) {
      throw Exception('加载书籍内容失败: $e');
    }
  }

  // 未使用的方法，已注释
  /*
  String _stripHtmlTags(String html) {
    // 简单的HTML标签清理
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
  */

  Future<void> _loadBookmarks() async {
    try {
      // TODO: 实现书签加载逻辑
      // _bookmarks = await getBookmarksByBookId(widget.book.id);
    } catch (e) {
      debugPrint('加载书签失败: $e');
      // _bookmarks = [];
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

  // --- 阅读配置 ---

  PaginationConfig get _paginationConfig => PaginationConfig(
    fontSize: _fontSize,
    lineHeight: _lineSpacing,
    letterSpacing: _letterSpacing,
    pagePadding: 20.0,
    paragraphSpacing: '0.8em',
    textIndent: '2em',
    scrollMode: _isScrollMode,
    backgroundColor: _currentTheme.backgroundColor,
    textColor: _currentTheme.textColor,
  );

  // --- 翻页控制 ---
  // _nextPage 和 _prevPage 方法已移除，未被使用

  Future<void> _goToPage(int page) async {
    await _readerController.goToPage(page);
  }

  // --- UI控制 ---

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

  // --- 搜索功能 ---

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _currentSearchIndex = -1;
      });
      return;
    }

    try {
      final results = await _readerController.searchText(query.trim());
      setState(() {
        _searchResults = results;
        _currentSearchIndex = results.isNotEmpty ? 0 : -1;
      });

      if (results.isNotEmpty) {
        await _goToPage(results[0].pageIndex + 1);
        _showMessage('找到 ${results.length} 个结果');
      } else {
        _showMessage('未找到匹配内容');
      }
    } catch (e) {
      debugPrint('搜索失败: $e');
      _showMessage('搜索失败');
    }
  }

  Future<void> _goToNextSearchResult() async {
    if (_searchResults.isEmpty) return;

    setState(() {
      _currentSearchIndex = (_currentSearchIndex + 1) % _searchResults.length;
    });

    final result = _searchResults[_currentSearchIndex];
    await _goToPage(result.pageIndex + 1);
  }

  Future<void> _goToPrevSearchResult() async {
    if (_searchResults.isEmpty) return;

    setState(() {
      _currentSearchIndex =
          (_currentSearchIndex - 1 + _searchResults.length) %
          _searchResults.length;
    });

    final result = _searchResults[_currentSearchIndex];
    await _goToPage(result.pageIndex + 1);
  }

  // --- 设置保存 ---

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setDouble('advanced_reading_font_size', _fontSize),
        prefs.setDouble('advanced_reading_line_spacing', _lineSpacing),
        prefs.setDouble('advanced_reading_letter_spacing', _letterSpacing),
        prefs.setString('advanced_reading_font_family', _fontFamily),
        prefs.setBool('advanced_reading_scroll_mode', _isScrollMode),
        prefs.setInt('advanced_reading_max_columns', _maxColumnCount),
        prefs.setBool('advanced_reading_keep_screen_on', _keepScreenOn),
        prefs.setString('advanced_reading_theme', _currentTheme.name),
      ]);
    } catch (e) {
      debugPrint('保存设置失败: $e');
    }
  }

  Future<void> _saveReadingProgress() async {
    if (_currentPageInfo == null) return;

    try {
      // final progress = _currentPageInfo!.progress; // 暂未使用
      // final lastPosition = jsonEncode({
      //   'page': _currentPageInfo!.currentPage,
      //   'totalPages': _currentPageInfo!.totalPages,
      //   'progress': progress,
      //   'timestamp': DateTime.now().millisecondsSinceEpoch,
      // });

      // TODO: 实现保存阅读进度逻辑
      // final updatedBook = widget.book.copyWith(
      //   currentPage: _currentPageInfo?.currentPage ?? 0,
      // );

      // await updateBook(updatedBook);
    } catch (e) {
      debugPrint('保存阅读进度失败: $e');
    }
  }

  Future<void> _updateReadingStats() async {
    if (_readingStartTime == null) return;

    try {
      // final sessionTime = DateTime.now()
      //     .difference(_readingStartTime!)
      //     .inSeconds;
      // _totalReadingTimeSeconds += sessionTime; // 暂未实现

      // TODO: 实现阅读统计更新逻辑
      // await updateOrInsertReadingStats({
      //   'book_id': widget.book.id,
      //   'total_reading_time': _totalReadingTimeSeconds,
      //   'last_read_date': DateTime.now().millisecondsSinceEpoch,
      //   'pages_read': _currentPageInfo?.currentPage ?? 0,
      // });
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
      children: [
        // 主要阅读区域
        _buildReaderWidget(),

        // 控制栏
        if (_showControlBar) _buildControlBar(),

        // 设置面板
        if (_showSettings) _buildSettingsPanel(),

        // 搜索面板
        if (_showSearch) _buildSearchPanel(),

        // 目录
        if (_showToc) _buildTocPanel(),
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
              '正在加载高级阅读器...',
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

  Widget _buildReaderWidget() {
    return GestureDetector(
      onTap: _toggleControlBar,
      child: ControlledAdvancedTextReaderWidget(
        text: _bookContent,
        config: _paginationConfig,
        controller: _readerController,
        onPageChanged: (pageInfo) {
          setState(() {
            _currentPageInfo = pageInfo;
          });
          _saveReadingProgress();
        },
        onReachStart: () => _showMessage('已到达开始'),
        onReachEnd: () => _showMessage('已到达结尾'),
        onMiddleClick: (x, y) => _toggleControlBar(),
      ),
    );
  }

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
                  if (_currentPageInfo != null) _buildProgressBar(),

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
    final progress = _currentPageInfo!.progress;
    final currentPage = _currentPageInfo!.currentPage;
    final totalPages = _currentPageInfo!.totalPages;

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
              overlayColor: _currentTheme.sliderActiveColor.withValues(
                alpha: 0.2,
              ),
            ),
            child: Slider(
              value: progress,
              onChanged: (value) {
                final targetPage = (value * totalPages).round();
                _goToPage(targetPage);
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '阅读设置',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _currentTheme.controlBarTextColor,
              ),
            ),
            const SizedBox(height: 16),

            // 字体大小
            _buildSettingSlider(
              label: '字体大小',
              value: _fontSize,
              min: 12.0,
              max: 24.0,
              divisions: 12,
              onChanged: (value) {
                setState(() {
                  _fontSize = value;
                });
                _updateReaderConfig();
              },
            ),

            // 行间距
            _buildSettingSlider(
              label: '行间距',
              value: _lineSpacing,
              min: 1.0,
              max: 2.5,
              divisions: 15,
              onChanged: (value) {
                setState(() {
                  _lineSpacing = value;
                });
                _updateReaderConfig();
              },
            ),

            // 主题选择
            _buildThemeSelector(),

            // 模式切换
            _buildModeSwitch(),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: _currentTheme.controlBarTextColor,
              ),
            ),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 14,
                color: _currentTheme.controlBarTextColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _currentTheme.sliderActiveColor,
            inactiveTrackColor: _currentTheme.sliderInactiveColor,
            thumbColor: _currentTheme.sliderActiveColor,
            overlayColor: _currentTheme.sliderActiveColor.withValues(
              alpha: 0.2,
            ),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildThemeSelector() {
    final themes = [
      ReadingThemes.dayTheme,
      ReadingThemes.nightTheme,
      ReadingThemes.greenTheme,
      ReadingThemes.brownTheme,
      ReadingThemes.sepiaTheme,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '阅读主题',
          style: TextStyle(
            fontSize: 14,
            color: _currentTheme.controlBarTextColor,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: themes.map((theme) {
            final isSelected = theme.name == _currentTheme.name;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _currentTheme = theme;
                });
                _updateReaderConfig();
                _saveSettings();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? _currentTheme.sliderActiveColor
                        : Colors.grey.withOpacity(0.3),
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '文',
                    style: TextStyle(color: theme.textColor, fontSize: 12),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildModeSwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '滚动模式',
          style: TextStyle(
            fontSize: 14,
            color: _currentTheme.controlBarTextColor,
          ),
        ),
        Switch(
          value: _isScrollMode,
          onChanged: (value) {
            setState(() {
              _isScrollMode = value;
            });
            _updateReaderConfig();
            _saveSettings();
          },
          activeColor: _currentTheme.sliderActiveColor,
        ),
      ],
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: _currentTheme.controlBarTextColor),
                    decoration: InputDecoration(
                      hintText: '搜索内容...',
                      hintStyle: TextStyle(
                        color: _currentTheme.controlBarTextColor.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _currentTheme.sliderInactiveColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _currentTheme.sliderActiveColor,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: _performSearch,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _performSearch(_searchController.text),
                  icon: Icon(Icons.search, color: _currentTheme.iconColor),
                ),
              ],
            ),
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_currentSearchIndex + 1}/${_searchResults.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _currentTheme.controlBarTextColor,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _goToPrevSearchResult,
                        icon: Icon(
                          Icons.keyboard_arrow_up,
                          color: _currentTheme.iconColor,
                        ),
                      ),
                      IconButton(
                        onPressed: _goToNextSearchResult,
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: _currentTheme.iconColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '目录',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _currentTheme.controlBarTextColor,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _chapters.length,
                itemBuilder: (context, index) {
                  final chapter = _chapters[index];
                  final isCurrentChapter = index == _currentChapterIndex;

                  return ListTile(
                    title: Text(
                      chapter.title.isEmpty ? '第${index + 1}章' : chapter.title,
                      style: TextStyle(
                        color: isCurrentChapter
                            ? _currentTheme.sliderActiveColor
                            : _currentTheme.controlBarTextColor,
                        fontWeight: isCurrentChapter
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      // TODO: 实现章节跳转
                      setState(() {
                        _currentChapterIndex = index;
                        _showToc = false;
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 辅助方法 ---

  Future<void> _updateReaderConfig() async {
    await _readerController.updateConfig(_paginationConfig);
  }

  Future<void> _addBookmark() async {
    if (_currentPageInfo == null) return;

    try {
      // final bookmark = Bookmark(
      //   bookId: widget.book.id ?? 0,
      //   pageNumber: _currentPageInfo!.currentPage,
      //   note: _currentPageInfo!.content.substring(
      //     0,
      //     _currentPageInfo!.content.length > 100
      //         ? 100
      //         : _currentPageInfo!.content.length,
      //   ),
      // );

      // TODO: 实现书签添加逻辑
      // await addBookmark(bookmark);
      // await _loadBookmarks();
      _showMessage('书签已添加（演示）');
    } catch (e) {
      debugPrint('添加书签失败: $e');
      _showMessage('添加书签失败');
    }
  }
}

// --- 阅读主题定义 ---

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

  static const ReadingTheme greenTheme = ReadingTheme(
    name: 'green',
    displayName: '护眼绿',
    backgroundColor: Color(0xFFE8F5E8),
    textColor: Color(0xFF2E4A2E),
    controlBarColor: Color(0xFFDCE9DC),
    controlBarTextColor: Color(0xFF1B3A1B),
    iconColor: Color(0xFF4A6E4A),
    sliderActiveColor: Color(0xFF66BB6A),
    sliderInactiveColor: Color(0xFFC8E6C9),
  );

  static const ReadingTheme brownTheme = ReadingTheme(
    name: 'brown',
    displayName: '牛皮纸',
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
    displayName: '古典',
    backgroundColor: Color(0xFFFDF6E3),
    textColor: Color(0xFF5D4E37),
    controlBarColor: Color(0xFFEEE5D0),
    controlBarTextColor: Color(0xFF4A3E28),
    iconColor: Color(0xFF8B7355),
    sliderActiveColor: Color(0xFFCD853F),
    sliderInactiveColor: Color(0xFFF5DEB3),
  );
}
