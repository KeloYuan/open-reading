// 文件说明：Foliate 阅读页面 UI 壳——委托 EpubPlayer 处理 WebView / JS Bridge，
// 自身仅负责玻璃面板、主题/排版/目录 Sheet、进度保存、系统 UI。
// 技术要点：GlobalKey<EpubPlayerState>、SharedPreferences、WidgetsBindingObserver。

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:xxread/models/book.dart' as legacy;
import 'package:xxread/page/epub_player.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/reading/local_reader_file_server.dart';
import 'package:xxread/utils/glass_config.dart';
import 'package:xxread/utils/system_ui_helper.dart';
import 'package:xxread/widgets/side_toast.dart';

class FoliateReaderPage extends StatefulWidget {
  final legacy.Book book;
  final String? sourceFilePath;

  const FoliateReaderPage({
    super.key,
    required this.book,
    this.sourceFilePath,
  });

  @override
  State<FoliateReaderPage> createState() => _FoliateReaderPageState();
}

class _FoliateReaderPageState extends State<FoliateReaderPage>
    with WidgetsBindingObserver {
  static const String _themePrefKey = 'reader_theme_index_v1';
  static const String _fontSizePrefKey = 'reader_web_font_size_v1';
  static const String _lineHeightPrefKey = 'reader_web_line_height_v1';
  static const String _showSystemStatusBarPrefKey = 'readerShowSystemStatusBar';
  static const String _readerCfiPrefKeyPrefix = 'reader_web_cfi_v1_';
  static const String _readerProgressPrefKeyPrefix = 'reader_web_progress_v1_';
  static const double _floatingPanelRadius = 30;

  final _epubPlayerKey = GlobalKey<EpubPlayerState>();

  bool _configReady = false;
  bool _readerReady = false;
  bool _chromeVisible = false;
  bool _showSystemStatusBarInReader = false;
  bool _hasCurrentBookmark = false;
  int _themeIndex = 0;
  String? _serverUrl;
  String? _currentBookmarkCfi;

  double _overallProgress = 0.0;
  String? _lastKnownCfi;

  double _fontSize = 1.25;
  double _lineHeight = 1.5;

  final _bookDao = BookDao();

  static const List<_ReaderThemePreset> _themes = [
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveProgressNow();
    _restoreHostSystemUI();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _themeIndex =
        (prefs.getInt(_themePrefKey) ?? 0).clamp(0, _themes.length - 1);
    _fontSize = prefs.getDouble(_fontSizePrefKey) ?? _fontSize;
    _lineHeight = prefs.getDouble(_lineHeightPrefKey) ?? _lineHeight;
    _showSystemStatusBarInReader =
        prefs.getBool(_showSystemStatusBarPrefKey) ?? false;

    final path = widget.sourceFilePath ?? widget.book.filePath;
    try {
      _serverUrl = await LocalReaderFileServer.instance.registerBookFile(path);
      debugPrint('📖 Foliate Reader URL: $_serverUrl');
    } catch (e) {
      debugPrint('❌ Failed to register book file: $e');
    }

    final bookId = widget.book.id;
    _lastKnownCfi = bookId == null
        ? null
        : prefs.getString('$_readerCfiPrefKeyPrefix$bookId');
    final storedProgress = bookId == null
        ? null
        : prefs.getDouble('$_readerProgressPrefKeyPrefix$bookId');
    _overallProgress = storedProgress ??
        (widget.book.totalPages > 0
            ? widget.book.currentPage / widget.book.totalPages
            : 0.0);

    _applyReaderSystemUI();
    if (mounted) {
      setState(() => _configReady = true);
    }
  }

  void _applyReaderSystemUI() {
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
    if (_showSystemStatusBarInReader) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: const [SystemUiOverlay.top],
      );
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _restoreHostSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiHelper.overlayStyleForBrightness(brightness),
    );
  }

  _ReaderThemePreset get _activeTheme => _themes[_themeIndex];

  Map<String, dynamic> _foliateConfig() {
    final preset = _activeTheme;
    return {
      'url': _serverUrl ?? widget.sourceFilePath ?? widget.book.filePath,
      'initialCfi': _lastKnownCfi,
      'initialProgress': _overallProgress,
      'style': {
        'backgroundColor': _toHex8(preset.background),
        'fontColor': _toHex8(preset.foreground),
        'fontSize': _fontSize,
        'spacing': _lineHeight,
        'sideMargin': 16.0,
        'topMargin': 20.0,
        'bottomMargin': 20.0,
      },
    };
  }

  String _toHex8(Color color) {
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    final a = (color.a * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b$a';
  }

  // ── EpubPlayer 委托方法 ──

  Future<void> _updateTheme(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themePrefKey, index);
    setState(() => _themeIndex = index);
    final preset = _activeTheme;
    _epubPlayerKey.currentState?.changeStyle({
      'backgroundColor': _toHex8(preset.background),
      'fontColor': _toHex8(preset.foreground),
    });
    _applyReaderSystemUI();
  }

  Future<void> _updateTypography({double? fontSize, double? lineHeight}) async {
    final prefs = await SharedPreferences.getInstance();
    final style = <String, dynamic>{};
    if (fontSize != null) {
      style['fontSize'] = fontSize;
      await prefs.setDouble(_fontSizePrefKey, fontSize);
    }
    if (lineHeight != null) {
      style['spacing'] = lineHeight;
      await prefs.setDouble(_lineHeightPrefKey, lineHeight);
    }
    if (style.isNotEmpty) {
      _epubPlayerKey.currentState?.changeStyle(style);
    }
  }

  Future<void> _saveProgressNow() async {
    final player = _epubPlayerKey.currentState;
    if (player == null) return;
    final bookId = widget.book.id;
    if (bookId == null) return;

    final cfi = player.cfi;
    final percentage = player.percentage;
    final currentPage = player.bookCurrentPage;
    final totalPages = player.bookTotalPages;

    await _bookDao.updateBookProgress(bookId, currentPage - 1);
    await _bookDao.updateBookTotalPages(bookId, totalPages);
    final prefs = await SharedPreferences.getInstance();
    if (cfi.isNotEmpty) {
      await prefs.setString('$_readerCfiPrefKeyPrefix$bookId', cfi);
    }
    await prefs.setDouble(
        '$_readerProgressPrefKeyPrefix$bookId', percentage);
  }

  void _handleTap(double x) {
    // 点击前先移除上下文菜单
    final player = _epubPlayerKey.currentState;
    if (player?.contextMenuEntry != null) {
      player?.removeOverlay();
      player?.clearWebViewSelection();
      return;
    }
    if (x < 0.3) {
      player?.prevPage();
    } else if (x > 0.7) {
      player?.nextPage();
    } else {
      setState(() => _chromeVisible = !_chromeVisible);
    }
  }

  void _onRelocated() {
    final player = _epubPlayerKey.currentState;
    if (player == null) return;
    setState(() {
      _overallProgress = player.percentage;
      _lastKnownCfi = player.cfi;
      _hasCurrentBookmark = player.bookmarkExists;
      _currentBookmarkCfi = player.bookmarkCfi;
    });
  }

  void _onBookmarkChanged(bool exists) {
    setState(() {
      _hasCurrentBookmark = exists;
    });
    if (exists) {
      showSideToast(context, '已添加当前书签', icon: Icons.bookmark_added_rounded);
    } else {
      showSideToast(context, '已移除当前书签', icon: Icons.bookmark_remove_rounded);
    }
  }

  void _onLoadEnd() {
    setState(() => _readerReady = true);
  }

  void _onPullUp() {
    if (!_chromeVisible) {
      setState(() => _chromeVisible = true);
    }
  }

  void _onExternalLink(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.scheme.isEmpty || uri.scheme == 'javascript') {
      showSideToast(context, '无法打开无效链接', icon: Icons.link_off_rounded);
      return;
    }
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _toggleCurrentBookmark() async {
    if (_hasCurrentBookmark) {
      final cfi = _currentBookmarkCfi;
      if (cfi == null || cfi.isEmpty) return;
      _epubPlayerKey.currentState?.removeAnnotation(cfi);
      return;
    }
    _epubPlayerKey.currentState?.addBookmarkHere();
  }

  // ── Sheet 面板 ──

  void _showThemeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _activeTheme.background,
      showDragHandle: true,
      builder: (context) => Container(
        height: 180,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Text(
              '阅读主题',
              style: TextStyle(
                color: _activeTheme.foreground,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _themes.length,
                itemBuilder: (context, index) {
                  final theme = _themes[index];
                  final isSelected = index == _themeIndex;
                  return GestureDetector(
                    onTap: () {
                      _updateTheme(index);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 50,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: theme.background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Colors.blueAccent
                              : theme.foreground.withValues(alpha: 0.15),
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color:
                                      Colors.blueAccent.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.blueAccent)
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTocSheet() {
    final player = _epubPlayerKey.currentState;
    final toc = player?.toc ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: _activeTheme.background,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '目录',
                style: TextStyle(
                  color: _activeTheme.foreground,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: toc.length,
                separatorBuilder: (context, index) => Divider(
                  color: _activeTheme.foreground.withValues(alpha: 0.1),
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final item = Map<String, dynamic>.from(toc[index] as Map);
                  final title = item['label']?.toString() ?? '无标题';
                  final href = item['href']?.toString();
                  return ListTile(
                    title: Text(
                      title,
                      style: TextStyle(
                        color: _activeTheme.foreground,
                        fontSize: 15,
                      ),
                    ),
                    onTap: href == null
                        ? null
                        : () {
                            player?.goToHref(href);
                            Navigator.pop(context);
                            setState(() => _chromeVisible = false);
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

  void _showTypographySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _activeTheme.background,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '排版设置',
                style: TextStyle(
                  color: _activeTheme.foreground,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.text_fields, size: 20),
                  const SizedBox(width: 12),
                  Text('字号', style: TextStyle(color: _activeTheme.foreground)),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 0.8,
                      max: 2.5,
                      onChanged: (val) {
                        setSheetState(() => _fontSize = val);
                        setState(() => _fontSize = val);
                        _updateTypography(fontSize: val);
                      },
                    ),
                  ),
                  Text(
                    _fontSize.toStringAsFixed(2),
                    style: TextStyle(color: _activeTheme.foreground),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.format_line_spacing, size: 20),
                  const SizedBox(width: 12),
                  Text('行高', style: TextStyle(color: _activeTheme.foreground)),
                  Expanded(
                    child: Slider(
                      value: _lineHeight,
                      min: 1.0,
                      max: 3.0,
                      onChanged: (val) {
                        setSheetState(() => _lineHeight = val);
                        setState(() => _lineHeight = val);
                        _updateTypography(lineHeight: val);
                      },
                    ),
                  ),
                  Text(
                    _lineHeight.toStringAsFixed(2),
                    style: TextStyle(color: _activeTheme.foreground),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 构建 UI ──

  @override
  Widget build(BuildContext context) {
    if (!_configReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final player = _epubPlayerKey.currentState;
    final chapterTitle = player?.chapterTitle ?? '';
    final bookCurrentPage = player?.bookCurrentPage ?? 1;
    final bookTotalPages = player?.bookTotalPages ?? 1;

    return Scaffold(
      backgroundColor: _activeTheme.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: EpubPlayer(
              key: _epubPlayerKey,
              book: widget.book,
              sourceFilePath: widget.sourceFilePath,
              serverUrl: _serverUrl,
              initialCfi: _lastKnownCfi,
              initialProgress: _overallProgress,
              foliateConfig: _foliateConfig(),
              onRelocated: _onRelocated,
              onBookmarkChanged: _onBookmarkChanged,
              onClick: _handleTap,
              onLoadEnd: _onLoadEnd,
              onPullUp: _onPullUp,
              onExternalLink: _onExternalLink,
            ),
          ),
          if (!_readerReady)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.transparent,
                child: Center(child: CircularProgressIndicator()),
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
            child: _buildBottomPanelAnimated(),
          ),
          if (!_chromeVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: _buildBottomReadingInfoOverlay(
                  chapterTitle, bookCurrentPage, bookTotalPages),
            ),
        ],
      ),
    );
  }

  Widget _buildTopControlBarAnimated() {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      offset: _chromeVisible ? Offset.zero : const Offset(0, -1.2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: _chromeVisible ? 1 : 0,
        child: SafeArea(
          bottom: false,
          child: _buildGlassPanel(
            margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: _activeTheme.foreground),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    widget.book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _activeTheme.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon:
                      Icon(Icons.auto_awesome, color: _activeTheme.foreground),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanelAnimated() {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      offset: _chromeVisible ? Offset.zero : const Offset(0, 1.2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: _chromeVisible ? 1 : 0,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGlassPanel(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '${(_overallProgress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: _activeTheme.foreground,
                        fontSize: 12,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: _overallProgress.clamp(0.0, 1.0),
                        onChanged: (val) {
                          setState(() => _overallProgress = val);
                          _epubPlayerKey.currentState?.goToPercent(val);
                        },
                      ),
                    ),
                    Text(
                      '全书',
                      style: TextStyle(
                        color: _activeTheme.foreground,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _buildGlassPanel(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(Icons.toc, color: _activeTheme.foreground),
                      onPressed: _showTocSheet,
                    ),
                    IconButton(
                      icon: Icon(Icons.palette, color: _activeTheme.foreground),
                      onPressed: _showThemeSheet,
                    ),
                    IconButton(
                      icon: Icon(Icons.tune, color: _activeTheme.foreground),
                      onPressed: _showTypographySheet,
                    ),
                    IconButton(
                      icon: Icon(
                        _hasCurrentBookmark
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_add_outlined,
                        color: _activeTheme.foreground,
                      ),
                      onPressed: _toggleCurrentBookmark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassPanel({
    required Widget child,
    required EdgeInsets margin,
    required EdgeInsets padding,
  }) {
    final isLowPerformance = GlassEffectConfig.shouldDisableBlur;
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_floatingPanelRadius),
        child: BackdropFilter(
          enabled: !isLowPerformance,
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_floatingPanelRadius),
              border: Border.all(
                color: _activeTheme.foreground.withValues(alpha: 0.24),
              ),
              color: _activeTheme.background
                  .withValues(alpha: isLowPerformance ? 1.0 : 0.6),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomReadingInfoOverlay(
      String chapterTitle, int currentPage, int totalPages) {
    return SafeArea(
      top: false,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _activeTheme.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$chapterTitle · 第 $currentPage/$totalPages 页',
            style: TextStyle(
              color: _activeTheme.foreground.withValues(alpha: 0.8),
              fontSize: 11,
            ),
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
