import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/models/book.dart' as legacy;
import 'package:xxread/reader_core/renderer/reader_view.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/reading/local_reader_file_server.dart';
import 'package:xxread/utils/system_ui_helper.dart';
import 'package:xxread/widgets/side_toast.dart';

class EpubFoliateReaderPage extends StatefulWidget {
  final legacy.Book book;
  final bool strictPagination;

  const EpubFoliateReaderPage({
    super.key,
    required this.book,
    this.strictPagination = false,
  });

  @override
  State<EpubFoliateReaderPage> createState() => _EpubFoliateReaderPageState();
}

class _EpubFoliateReaderPageState extends State<EpubFoliateReaderPage>
    with WidgetsBindingObserver {
  static const String _pageTurnModePrefKey = 'reader_page_turn_mode_v1';
  static const String _showSystemStatusBarPrefKey = 'readerShowSystemStatusBar';
  static const String _themePrefKey = 'reader_theme_index_v1';
  static const String _readerTypographyPrefKey = 'reader_typography_v1';
  static const String _readerFontPrefKey = 'reader_font_family_v1';

  final BookDao _bookDao = BookDao();
  InAppWebViewController? _webController;
  Timer? _persistTimer;
  bool _configReady = false;
  bool _loading = true;
  bool _chromeVisible = false;
  bool _showSystemStatusBarInReader = false;
  ReaderPageTurnAnimation _pageTurnAnimation = ReaderPageTurnAnimation.cover;
  Color _background = const Color(0xFFFFFFFF);
  Color _foreground = const Color(0xFF111111);
  String? _readerFontFamily;
  double _readerFontSize = 1.25;
  double _readerLineHeight = 1.5;
  double _readerLetterSpacing = 0.0;
  String _chapterTitle = '';
  int _chapterCurrentPage = 1;
  int _chapterTotalPages = 1;
  int _bookCurrentPage = 1;
  int _bookTotalPages = 1;
  int _lastSavedCurrentPage = -1;
  int _lastSavedTotalPages = -1;
  String? _bookResourceUrl;

  static const List<_FoliateThemePreset> _themes = <_FoliateThemePreset>[
    _FoliateThemePreset(
      background: Color(0xFFFFFFFF),
      foreground: Color(0xFF111111),
    ),
    _FoliateThemePreset(
      background: Color(0xFFF7F2E7),
      foreground: Color(0xFF2A241C),
    ),
    _FoliateThemePreset(
      background: Color(0xFFFCF7EE),
      foreground: Color(0xFF2F271C),
    ),
    _FoliateThemePreset(
      background: Color(0xFFFFFBF2),
      foreground: Color(0xFF2C251A),
    ),
    _FoliateThemePreset(
      background: Color(0xFFF2F4F8),
      foreground: Color(0xFF1F2630),
    ),
    _FoliateThemePreset(
      background: Color(0xFFF8FAFC),
      foreground: Color(0xFF1E2933),
    ),
    _FoliateThemePreset(
      background: Color(0xFFEDF7F2),
      foreground: Color(0xFF1E302A),
    ),
    _FoliateThemePreset(
      background: Color(0xFFEAF3FA),
      foreground: Color(0xFF1D2C39),
    ),
    _FoliateThemePreset(
      background: Color(0xFFFFF4E9),
      foreground: Color(0xFF33261C),
    ),
    _FoliateThemePreset(
      background: Color(0xFF171A1F),
      foreground: Color(0xFFE5E7EC),
    ),
    _FoliateThemePreset(
      background: Color(0xFF101A2A),
      foreground: Color(0xFFDCE8FF),
    ),
    _FoliateThemePreset(
      background: Color(0xFF0D1015),
      foreground: Color(0xFFDCE3ED),
    ),
    _FoliateThemePreset(
      background: Color(0xFF1C1712),
      foreground: Color(0xFFF0E3CF),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadReaderPrefs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _persistTimer?.cancel();
    unawaited(_saveProgressNow());
    _restoreHostSystemUI();
    super.dispose();
  }

  Future<void> _loadReaderPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = ReaderPageTurnAnimationPrefs.fromPrefValue(
      prefs.getString(_pageTurnModePrefKey),
    );
    final showSystemStatusBar =
        prefs.getBool(_showSystemStatusBarPrefKey) ?? false;
    final themeIndex =
        (prefs.getInt(_themePrefKey) ?? 0).clamp(0, _themes.length - 1).toInt();
    final readerFontFamily = prefs.getString(_readerFontPrefKey);

    var fontSize = 1.25;
    var lineHeight = 1.5;
    var letterSpacing = 0.0;
    final rawTypography = prefs.getString(_readerTypographyPrefKey);
    if (rawTypography != null && rawTypography.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTypography);
        if (decoded is Map) {
          final map = decoded.cast<String, dynamic>();
          final parsedFontSize = _toDouble(map['fontSize']);
          final parsedLineHeight = _toDouble(map['lineHeight']);
          final parsedLetterSpacing = _toDouble(map['letterSpacing']);
          if (parsedFontSize != null) {
            fontSize = (parsedFontSize / 16.0).clamp(0.85, 2.4).toDouble();
          }
          if (parsedLineHeight != null) {
            lineHeight = parsedLineHeight.clamp(1.1, 3.0).toDouble();
          }
          if (parsedLetterSpacing != null) {
            letterSpacing = parsedLetterSpacing.clamp(0.0, 2.4).toDouble();
          }
        }
      } catch (_) {
        // Ignore malformed preference payloads.
      }
    }

    final preset = _themes[themeIndex];
    _pageTurnAnimation = mode ?? ReaderPageTurnAnimation.cover;
    _showSystemStatusBarInReader = showSystemStatusBar;
    _background = preset.background;
    _foreground = preset.foreground;
    _readerFontFamily = (readerFontFamily == null || readerFontFamily.isEmpty)
        ? null
        : readerFontFamily;
    _readerFontSize = fontSize;
    _readerLineHeight = lineHeight;
    _readerLetterSpacing = letterSpacing;
    _bookResourceUrl = await _resolveBookResourceUrl();
    _applyReaderSystemUI();
    if (!mounted) {
      return;
    }
    setState(() {
      _configReady = true;
    });
  }

  Future<String> _resolveBookResourceUrl() async {
    try {
      return await LocalReaderFileServer.instance
          .registerBookFile(widget.book.filePath);
    } catch (_) {
      return Uri.file(widget.book.filePath).toString();
    }
  }

  void _applyReaderSystemUI() {
    if (_showSystemStatusBarInReader) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: const [SystemUiOverlay.top],
      );
      final brightness = ThemeData.estimateBrightnessForColor(_background);
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiHelper.overlayStyleForBrightness(brightness),
      );
    } else {
      final brightness = ThemeData.estimateBrightnessForColor(_background);
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: const [SystemUiOverlay.top],
      );
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiHelper.overlayStyleForBrightness(brightness),
      );
    }
  }

  void _restoreHostSystemUI() {
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiHelper.overlayStyleForBrightness(platformBrightness),
    );
  }

  double? _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic> _foliateConfig() {
    final strictCustomCss = widget.strictPagination
        ? '''
html, body {
  text-rendering: optimizeLegibility !important;
  -webkit-font-smoothing: antialiased !important;
}
p, li, blockquote, dd, div, font {
  overflow-wrap: anywhere !important;
  word-break: normal !important;
  line-break: auto !important;
}
img, svg, video, canvas, table, pre, code, samp, kbd {
  max-width: 100% !important;
  overflow-wrap: anywhere !important;
  word-break: break-word !important;
}
'''
        : '';
    final style = <String, dynamic>{
      'fontSize': _readerFontSize,
      'fontName': _readerFontFamily ?? 'book',
      'fontPath': '',
      'fontWeight': 400.0,
      'letterSpacing': _readerLetterSpacing,
      'spacing': _readerLineHeight,
      'paragraphSpacing': 0.0,
      'textIndent': 0.0,
      'fontColor': _toHex8(_foreground),
      'backgroundColor': _toHex8(_background),
      'topMargin': 12.0,
      'bottomMargin': 24.0,
      'sideMargin': 6.0,
      'justify': true,
      'textAlign': 'auto',
      'hyphenate': true,
      'pageTurnStyle': _foliatePageTurnStyle(_pageTurnAnimation),
      'maxColumnCount': 1,
      'writingMode': 'horizontal-tb',
      'backgroundImage': 'none',
      'allowScript': true,
      'customCSS': strictCustomCss,
      'customCSSEnabled': strictCustomCss.isNotEmpty,
    };

    return <String, dynamic>{
      'importing': false,
      'url': _bookResourceUrl ?? Uri.file(widget.book.filePath).toString(),
      'initialCfi': null,
      'style': style,
      'readingRules': <String, dynamic>{
        'convertChineseMode': 'none',
        'bionicReadingMode': false,
      },
    };
  }

  String _foliatePageTurnStyle(ReaderPageTurnAnimation mode) {
    switch (mode) {
      case ReaderPageTurnAnimation.scroll:
        return 'scroll';
      case ReaderPageTurnAnimation.slide:
      case ReaderPageTurnAnimation.cover:
      case ReaderPageTurnAnimation.simulation:
        return 'slide';
    }
  }

  String _toHex8(Color color) {
    final r = (color.r * 255.0).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255.0).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255.0).round().toRadixString(16).padLeft(2, '0');
    final a = (color.a * 255.0).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b$a';
  }

  void _registerJavaScriptHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'onLoadEnd',
      callback: (args) {
        if (!mounted) {
          return null;
        }
        setState(() {
          _loading = false;
        });
        return null;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onRelocated',
      callback: (args) {
        final payload = _safeMap(args.isNotEmpty ? args.first : null);
        final chapterTitle = (payload['chapterTitle'] ?? '').toString();
        final chapterCurrent = _toInt(payload['chapterCurrentPage']) ?? 1;
        final chapterTotal = _toInt(payload['chapterTotalPages']) ?? 1;
        final bookCurrent = _toInt(payload['bookCurrentPage']) ?? 1;
        final bookTotal = _toInt(payload['bookTotalPages']) ?? 1;
        if (!mounted) {
          return null;
        }
        setState(() {
          _chapterTitle = chapterTitle;
          _chapterCurrentPage = math.max(1, chapterCurrent);
          _chapterTotalPages = math.max(1, chapterTotal);
          _bookCurrentPage = math.max(1, bookCurrent);
          _bookTotalPages = math.max(1, bookTotal);
        });
        _scheduleSaveProgress();
        return null;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onClick',
      callback: (args) {
        final payload = _safeMap(args.isNotEmpty ? args.first : null);
        final x = (_toDouble(payload['x']) ?? 0.5).clamp(0.0, 1.0);
        _handleReaderTap(x);
        return null;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'translateText',
      callback: (args) {
        if (args.isEmpty) {
          return '';
        }
        return args.first?.toString() ?? '';
      },
    );

    const noopHandlers = <String>[
      'onSetToc',
      'renderAnnotations',
      'onSelectionEnd',
      'onAnnotationClick',
      'onImageClick',
      'onPushState',
      'onFootnoteClose',
      'onPullUp',
      'onSearch',
      'onMetadata',
    ];
    for (final name in noopHandlers) {
      controller.addJavaScriptHandler(
        handlerName: name,
        callback: (args) => null,
      );
    }
  }

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), val),
      );
    }
    return const <String, dynamic>{};
  }

  int? _toInt(dynamic value) {
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

  void _handleReaderTap(double x) {
    if (x < 0.33) {
      _invokeReaderJs('window.prevPage && window.prevPage();');
      return;
    }
    if (x > 0.67) {
      _invokeReaderJs('window.nextPage && window.nextPage();');
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _chromeVisible = !_chromeVisible;
    });
  }

  Future<void> _invokeReaderJs(String source) async {
    final controller = _webController;
    if (controller == null) {
      return;
    }
    try {
      await controller.evaluateJavascript(source: source);
    } catch (_) {
      // Ignore JS execution failures.
    }
  }

  void _scheduleSaveProgress() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 850), () {
      unawaited(_saveProgressNow());
    });
  }

  Future<void> _saveProgressNow() async {
    final bookId = widget.book.id;
    if (bookId == null) {
      return;
    }
    final currentPage = math.max(0, _bookCurrentPage - 1);
    final totalPages = math.max(1, _bookTotalPages);
    if (currentPage == _lastSavedCurrentPage &&
        totalPages == _lastSavedTotalPages) {
      return;
    }
    try {
      await _bookDao.updateBookProgress(bookId, currentPage);
      await _bookDao.updateBookTotalPages(bookId, totalPages);
      _lastSavedCurrentPage = currentPage;
      _lastSavedTotalPages = totalPages;
    } catch (e) {
      if (mounted) {
        showSideToast(
          context,
          '保存阅读进度失败：$e',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_configReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final config = _foliateConfig();
    final scriptSource = 'window.__XXREAD_CONFIG__ = ${jsonEncode(config)};';
    final infoText =
        '第 $_chapterCurrentPage/$_chapterTotalPages 页 · 全书 $_bookCurrentPage/$_bookTotalPages';

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned.fill(
            child: InAppWebView(
              initialFile: 'assets/foliate-js/app.html',
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
                transparentBackground: true,
                supportZoom: false,
                builtInZoomControls: false,
                displayZoomControls: false,
                allowFileAccessFromFileURLs: true,
                allowUniversalAccessFromFileURLs: true,
                allowFileAccess: true,
                allowsInlineMediaPlayback: true,
              ),
              initialUserScripts: UnmodifiableListView<UserScript>([
                UserScript(
                  source: scriptSource,
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                ),
              ]),
              onWebViewCreated: (controller) {
                _webController = controller;
                _registerJavaScriptHandlers(controller);
              },
              onReceivedError: (controller, request, error) {
                if (!mounted || request.isForMainFrame != true) {
                  return;
                }
                setState(() {
                  _loading = false;
                });
                showSideToast(
                  context,
                  'Foliate 页面异常：${error.description}',
                  icon: Icons.error_outline_rounded,
                );
              },
            ),
          ),
          if (_loading)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _chromeVisible ? 1 : 0,
            child: IgnorePointer(
              ignoring: !_chromeVisible,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _chapterTitle.isEmpty
                              ? widget.book.title
                              : _chapterTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _foreground,
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: IgnorePointer(
              child: SafeArea(
                top: false,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _background.withValues(
                          alpha: _chromeVisible ? 0.72 : 0.58),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _foreground.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      infoText,
                      style: TextStyle(
                        color: _foreground.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoliateThemePreset {
  final Color background;
  final Color foreground;

  const _FoliateThemePreset({
    required this.background,
    required this.foreground,
  });
}
