// 文件说明：Foliate 阅读页面，采用 Foliate (WebView) 渲染并使用 Flutter 原生控制 UI。
// 技术要点：Flutter UI、InAppWebView、Foliate-JS Bridge、SharedPreferences。

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:xxread/models/book.dart' as legacy;
import 'package:xxread/models/bookmark.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/books/book_note_dao.dart';
import 'package:xxread/services/books/bookmark_dao.dart';
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

  InAppWebViewController? _webController;
  bool _configReady = false;
  bool _readerReady = false;
  bool _chromeVisible = false;
  bool _showSystemStatusBarInReader = false;
  bool _hasCurrentBookmark = false;
  int _themeIndex = 0;
  String? _serverUrl;
  String? _currentBookmarkCfi;

  String _chapterTitle = '';
  int _bookCurrentPage = 1;
  int _bookTotalPages = 1;
  double _overallProgress = 0.0;
  String? _lastKnownCfi;
  List<dynamic> _toc = <dynamic>[];

  double _fontSize = 1.25;
  double _lineHeight = 1.5;

  final _bookDao = BookDao();
  final _bookNoteDao = BookNoteDao();
  final _bookmarkDao = BookmarkDao();

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

  Future<void> _callReaderMethod(String method, [dynamic argument]) async {
    final controller = _webController;
    if (controller == null) {
      return;
    }
    final source = argument == null
        ? 'window.$method && window.$method();'
        : 'window.$method && window.$method(${jsonEncode(argument)});';
    await controller.evaluateJavascript(source: source);
  }

  Future<void> _applyReaderStyle(Map<String, dynamic> style) async {
    if (style.isEmpty) {
      return;
    }
    await _callReaderMethod('changeStyle', style);
  }

  Future<void> _updateTheme(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themePrefKey, index);
    setState(() => _themeIndex = index);
    final preset = _activeTheme;
    await _applyReaderStyle({
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
    await _applyReaderStyle(style);
  }

  Future<void> _saveProgressNow() async {
    final bookId = widget.book.id;
    if (bookId == null) {
      return;
    }
    await _bookDao.updateBookProgress(bookId, _bookCurrentPage - 1);
    await _bookDao.updateBookTotalPages(bookId, _bookTotalPages);
    final prefs = await SharedPreferences.getInstance();
    if (_lastKnownCfi != null) {
      await prefs.setString('$_readerCfiPrefKeyPrefix$bookId', _lastKnownCfi!);
    }
    await prefs.setDouble(
        '$_readerProgressPrefKeyPrefix$bookId', _overallProgress);
  }

  void _handleTap(double x) {
    if (x < 0.3) {
      _callReaderMethod('prevPage');
    } else if (x > 0.7) {
      _callReaderMethod('nextPage');
    } else {
      setState(() => _chromeVisible = !_chromeVisible);
    }
  }

  Future<void> _renderSavedAnnotations() async {
    final bookId = widget.book.id;
    if (bookId == null) {
      await _callReaderMethod(
          'renderAnnotations', const <Map<String, dynamic>>[]);
      return;
    }

    final bookmarks = await _bookmarkDao.getBookmarksForBook(bookId);
    final notes = await _bookNoteDao.selectBookNotesByBookId(bookId);
    final annotations = <Map<String, dynamic>>[
      for (final bookmark in bookmarks)
        if ((bookmark.cfi ?? '').trim().isNotEmpty)
          {
            'id': bookmark.id,
            'value': bookmark.cfi,
            'type': 'bookmark',
            'color': '#215a8f',
            'note': bookmark.note,
          },
      for (final note in notes)
        if (note.cfi.trim().isNotEmpty)
          {
            'id': note.id,
            'value': note.cfi,
            'type': note.type,
            'color': '#${note.color}',
            'note': note.content,
          },
    ];
    await _callReaderMethod('renderAnnotations', annotations);
  }

  Future<void> _handleBookmarkEvent(Map<String, dynamic> payload) async {
    final bookId = widget.book.id;
    if (bookId == null) {
      return;
    }
    final detailRaw = payload['detail'];
    if (detailRaw is! Map) {
      return;
    }
    final detail = Map<String, dynamic>.from(detailRaw);
    final remove = payload['remove'] == true;
    final cfi = detail['cfi']?.toString().trim() ?? '';
    if (cfi.isEmpty) {
      return;
    }

    if (remove) {
      await _bookmarkDao.deleteBookmarkByCfi(bookId, cfi);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasCurrentBookmark = false;
        _currentBookmarkCfi = null;
      });
      showSideToast(
        context,
        '已移除当前书签',
        icon: Icons.bookmark_remove_rounded,
      );
    } else {
      final existing = await _bookmarkDao.getBookmarkByCfi(bookId, cfi);
      if (existing == null) {
        final snippet = detail['content']?.toString().trim() ?? '';
        await _bookmarkDao.insertBookmark(
          Bookmark(
            bookId: bookId,
            pageNumber: _bookCurrentPage > 0 ? _bookCurrentPage - 1 : 0,
            note: snippet,
            cfi: cfi,
          ),
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _hasCurrentBookmark = true;
        _currentBookmarkCfi = cfi;
      });
      showSideToast(
        context,
        '已添加当前书签',
        icon: Icons.bookmark_added_rounded,
      );
    }

    await _renderSavedAnnotations();
  }

  Future<void> _openExternalLink(dynamic rawLink) async {
    String? link;
    if (rawLink is String) {
      link = rawLink.trim();
    } else if (rawLink is Map) {
      final href = rawLink['href'];
      if (href is String) {
        link = href.trim();
      }
    }
    if (!mounted || link == null || link.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(link);
    if (uri == null || uri.scheme.isEmpty || uri.scheme == 'javascript') {
      showSideToast(context, '无法打开无效链接', icon: Icons.link_off_rounded);
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      showSideToast(context, '外部链接打开失败', icon: Icons.error_outline_rounded);
    }
  }

  Future<void> _toggleCurrentBookmark() async {
    if (_hasCurrentBookmark) {
      final cfi = _currentBookmarkCfi;
      if (cfi == null || cfi.isEmpty) {
        return;
      }
      await _callReaderMethod('removeAnnotation', cfi);
      return;
    }
    await _callReaderMethod('addBookmarkHere');
  }

  void _registerJSHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'onLoadEnd',
      callback: (args) {
        if (mounted) {
          setState(() => _readerReady = true);
        }
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onRelocated',
      callback: (args) {
        if (args.isEmpty || args.first is! Map) {
          return null;
        }
        final payload = Map<String, dynamic>.from(args.first as Map);
        final bookmark = payload['bookmark'];
        final bookmarkMap =
            bookmark is Map ? Map<String, dynamic>.from(bookmark) : null;
        setState(() {
          _chapterTitle = payload['chapterTitle']?.toString() ?? '';
          _bookCurrentPage = (payload['bookCurrentPage'] as num?)?.toInt() ?? 1;
          _bookTotalPages = (payload['bookTotalPages'] as num?)?.toInt() ?? 1;
          _overallProgress = (payload['percentage'] as num?)?.toDouble() ?? 0.0;
          _lastKnownCfi = payload['cfi']?.toString();
          _hasCurrentBookmark = bookmarkMap?['exists'] == true;
          _currentBookmarkCfi = bookmarkMap?['cfi']?.toString();
        });
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onSetToc',
      callback: (args) {
        if (args.isNotEmpty) {
          setState(() => _toc = List<dynamic>.from(args.first as List));
        }
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onClick',
      callback: (args) {
        if (args.isEmpty || args.first is! Map) {
          return null;
        }
        final payload = Map<String, dynamic>.from(args.first as Map);
        _handleTap((payload['x'] as num).toDouble());
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'renderAnnotations',
      callback: (args) async {
        await _renderSavedAnnotations();
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'handleBookmark',
      callback: (args) async {
        if (args.isNotEmpty && args.first is Map) {
          await _handleBookmarkEvent(
              Map<String, dynamic>.from(args.first as Map));
        }
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onExternalLink',
      callback: (args) async {
        await _openExternalLink(args.isNotEmpty ? args.first : null);
        return null;
      },
    );
  }

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
                itemCount: _toc.length,
                separatorBuilder: (context, index) => Divider(
                  color: _activeTheme.foreground.withValues(alpha: 0.1),
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final item = Map<String, dynamic>.from(_toc[index] as Map);
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
                            _callReaderMethod('goToHref', href);
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

  @override
  Widget build(BuildContext context) {
    if (!_configReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: _activeTheme.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: InAppWebView(
              initialFile: 'assets/foliate-js/app.html',
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                transparentBackground: true,
                allowFileAccessFromFileURLs: true,
                allowUniversalAccessFromFileURLs: true,
                allowFileAccess: true,
              ),
              initialUserScripts: UnmodifiableListView<UserScript>([
                UserScript(
                  source:
                      'window.__XXREAD_CONFIG__ = ${jsonEncode(_foliateConfig())};',
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                ),
              ]),
              onWebViewCreated: (controller) {
                _webController = controller;
                _registerJSHandlers(controller);
              },
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
              child: _buildBottomReadingInfoOverlay(),
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
                          _callReaderMethod('goToPercent', val);
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

  Widget _buildBottomReadingInfoOverlay() {
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
            '$_chapterTitle · 第 $_bookCurrentPage/$_bookTotalPages 页',
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
