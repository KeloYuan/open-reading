import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/book.dart';
import '../models/bookmark.dart';
import '../models/chapter.dart';
import '../models/highlight.dart';
import '../models/note.dart';
import '../services/book_dao.dart';
import '../services/bookmark_dao.dart';
import '../services/highlight_dao.dart';
import '../services/note_dao.dart';
import '../services/reading_stats_dao.dart';
import '../services/reading_theme_manager.dart';
import '../services/page_animation_manager.dart';
import '../widgets/tts_panel_enhanced.dart';
import '../widgets/toc_widget.dart';
import '../widgets/share_dialog.dart';
import '../widgets/enhanced_reading_settings_dialog.dart';

/// 增强版WebView阅读页面
/// 集成anx-reader的文字选中、划线、笔记功能
/// UI风格与reading_page_enhanced.dart保持一致
class EnhancedWebViewReadingPage extends StatefulWidget {
  final Book book;
  final String? initialCfi;

  const EnhancedWebViewReadingPage({
    super.key,
    required this.book,
    this.initialCfi,
  });

  @override
  State<EnhancedWebViewReadingPage> createState() =>
      _EnhancedWebViewReadingPageState();
}

class _EnhancedWebViewReadingPageState extends State<EnhancedWebViewReadingPage>
    with TickerProviderStateMixin {
  // --- 核心控制器 ---
  InAppWebViewController? _webViewController;
  late AnimationController _controlBarAnimationController;
  late AnimationController _fadeAnimationController;
  Timer? _hideControlsTimer;

  // --- 阅读状态 ---
  String _currentCfi = '';
  double _currentProgress = 0.0;
  int _currentPageNumber = 1;
  int _totalPages = 1;
  String _chapterTitle = '';
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // --- UI状态 ---
  bool _showControls = false;
  bool _isInitializing = true;

  // --- 文字选中相关 ---
  OverlayEntry? _textSelectionMenu;
  String _selectedText = '';
  String _selectedCfi = '';

  // --- 数据访问层 ---
  final BookDao _bookDao = BookDao();
  final BookmarkDao _bookmarkDao = BookmarkDao();
  final HighlightDao _highlightDao = HighlightDao();
  final NoteDao _noteDao = NoteDao();
  final ReadingStatsDao _statsDao = ReadingStatsDao();

  // --- 数据缓存 ---
  final List<Bookmark> _bookmarks = [];
  final List<Highlight> _highlights = [];
  final List<Note> _notes = [];
  final List<Chapter> _chapters = [];

  // --- 阅读设置 ---
  ReadingTheme _currentTheme = ReadingThemes.dayTheme;
  double _fontSize = 18.0;
  double _lineSpacing = 1.8;
  double _letterSpacing = 0.2;
  String _fontFamily = 'System';
  PageAnimationType _currentAnimationType = PageAnimationType.slide;

  // --- 统计数据 ---
  DateTime? _sessionStartTime;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserSettings();
    _sessionStartTime = DateTime.now();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeReading();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setImmersiveMode();
  }

  void _initializeAnimations() {
    _controlBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  /// 加载用户设置
  Future<void> _loadUserSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final theme = await ReadingThemeManager.getCurrentTheme();
      final animationType =
          await PageAnimationManager.getCurrentAnimationType();

      if (mounted) {
        setState(() {
          _currentTheme = theme;
          _currentAnimationType = animationType;
          _fontSize = prefs.getDouble('fontSize') ?? 18.0;
          _lineSpacing = prefs.getDouble('lineSpacing') ?? 1.8;
          _letterSpacing = prefs.getDouble('letterSpacing') ?? 0.2;
          _fontFamily = prefs.getString('fontFamily') ?? 'System';
        });
      }
    } catch (e) {
      debugPrint('加载用户设置失败: $e');
    }
  }

  /// 初始化阅读
  Future<void> _initializeReading() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      await _loadBookContent();
      await _loadAnnotations();
      await _setupWebView();

      setState(() {
        _isLoading = false;
        _isInitializing = false;
      });

      // 短暂显示控制栏提示用户
      _showControlsInitially();
    } catch (e) {
      debugPrint('初始化阅读失败: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = '加载书籍失败: $e';
      });
    }
  }

  /// 验证书籍内容
  Future<void> _loadBookContent() async {
    final file = File(widget.book.filePath);
    if (!await file.exists()) {
      throw Exception('书籍文件不存在: ${widget.book.filePath}');
    }
  }

  /// 加载注释数据
  Future<void> _loadAnnotations() async {
    if (widget.book.id == null) return;

    try {
      final futures = await Future.wait([
        _bookmarkDao.getBookmarksForBook(widget.book.id!),
        _highlightDao.getHighlightsByBook(widget.book.id!),
        _noteDao.getNotesByBook(widget.book.id!),
      ]);

      _bookmarks.clear();
      _bookmarks.addAll(futures[0] as List<Bookmark>);

      _highlights.clear();
      _highlights.addAll(futures[1] as List<Highlight>);

      _notes.clear();
      _notes.addAll(futures[2] as List<Note>);

      debugPrint(
        '加载注释数据: ${_bookmarks.length}个书签, ${_highlights.length}个高亮, ${_notes.length}个笔记',
      );
    } catch (e) {
      debugPrint('加载注释数据失败: $e');
    }
  }

  /// 设置WebView
  Future<void> _setupWebView() async {
    // WebView将在build方法中创建
  }

  /// 显示控制栏
  void _showControlsInitially() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_showControls) {
        _showControlsWithAnimation();
      }
    });
  }

  /// 设置沉浸式模式
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

  /// 切换控制栏
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
      _setImmersiveMode();
    }
  }

  void _hideControls() {
    if (_showControls) {
      setState(() => _showControls = false);
      _setImmersiveMode();
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), _hideControls);
  }

  /// WebView创建回调
  Future<void> _onWebViewCreated(InAppWebViewController controller) async {
    _webViewController = controller;
    await _setupJavaScriptHandlers(controller);
    await _loadBookInWebView(controller);
  }

  /// 设置JavaScript处理器
  Future<void> _setupJavaScriptHandlers(
    InAppWebViewController controller,
  ) async {
    // 页面重定位事件
    controller.addJavaScriptHandler(
      handlerName: 'onRelocated',
      callback: (args) {
        final data = args[0] as Map<String, dynamic>;
        setState(() {
          _currentCfi = data['cfi'] ?? '';
          _currentProgress = (data['percentage'] ?? 0.0).toDouble();
          _chapterTitle = data['chapterTitle'] ?? '';
          _currentPageNumber = data['currentPage'] ?? 1;
          _totalPages = data['totalPages'] ?? 1;
        });
        _saveReadingProgress();
      },
    );

    // 文字选中事件
    controller.addJavaScriptHandler(
      handlerName: 'onSelectionEnd',
      callback: (args) {
        final data = args[0] as Map<String, dynamic>;
        _onTextSelected(data);
      },
    );

    // 注释点击事件
    controller.addJavaScriptHandler(
      handlerName: 'onAnnotationClick',
      callback: (args) {
        final data = args[0] as Map<String, dynamic>;
        _onAnnotationClick(data);
      },
    );

    // 点击事件
    controller.addJavaScriptHandler(
      handlerName: 'onClick',
      callback: (args) {
        _hideTextSelectionMenu();
        _toggleControls();
      },
    );

    // 加载完成事件
    controller.addJavaScriptHandler(
      handlerName: 'onLoadEnd',
      callback: (args) {
        setState(() {
          _isLoading = false;
        });
        _renderAnnotations();
      },
    );
  }

  /// 在WebView中加载书籍
  Future<void> _loadBookInWebView(InAppWebViewController controller) async {
    final bookPath = widget.book.filePath;
    final bookUri = Uri.file(bookPath);

    // 构建包含折叠式阅读器的HTML
    final html = await _buildReaderHtml(bookUri.toString());

    await controller.loadData(
      data: html,
      mimeType: 'text/html',
      encoding: 'utf-8',
    );
  }

  /// 构建阅读器HTML
  Future<String> _buildReaderHtml(String bookPath) async {
    // 获取foliate-js资源路径
    final assetsPath = path.join(
      (await getApplicationDocumentsDirectory()).parent.path,
      'Frameworks/App.framework/flutter_assets/assets/foliate-js',
    );

    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Enhanced Reader</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            background: ${_getColorHex(_currentTheme.backgroundColor)};
            color: ${_getColorHex(_currentTheme.textColor)};
            font-family: ${_fontFamily == 'System' ? 'system-ui' : _fontFamily};
            font-size: ${_fontSize}px;
            line-height: ${_lineSpacing};
            letter-spacing: ${_letterSpacing}px;
        }
        
        .reader-container {
            height: 100vh;
            position: relative;
        }
        
        foliate-view {
            width: 100%;
            height: 100%;
        }
        
        /* 自定义选择样式 */
        ::selection {
            background: #66ccff80;
        }
        
        /* 高亮样式 */
        .highlight {
            background: yellow;
            cursor: pointer;
        }
        
        .highlight.blue { background: #66ccff80; }
        .highlight.red { background: #ff000080; }
        .highlight.green { background: #00ff0080; }
        .highlight.purple { background: #eb3bff80; }
        .highlight.yellow { background: #ffd70080; }
        
        /* 下划线样式 */
        .underline {
            border-bottom: 2px solid;
            cursor: pointer;
        }
    </style>
</head>
<body>
    <div class="reader-container">
        <foliate-view id="viewer"></foliate-view>
    </div>
    
    <script type="module">
        import { View } from '$assetsPath/dist/bundle.js';
        
        customElements.define('foliate-view', View);
        
        const viewer = document.getElementById('viewer');
        let book;
        
        // 加载书籍
        async function loadBook() {
            try {
                const response = await fetch('$bookPath');
                const buffer = await response.arrayBuffer();
                const { EPUB } = await import('$assetsPath/dist/bundle.js');
                book = await EPUB.readBook(buffer);
                await viewer.open(book);
                
                // 初始化位置
                const initialCfi = '${widget.initialCfi ?? ''}';
                if (initialCfi) {
                    await viewer.goTo(initialCfi);
                }
                
                setupEventListeners();
                
                if (window.flutter_inappwebview) {
                    window.flutter_inappwebview.callHandler('onLoadEnd');
                }
            } catch (error) {
                console.error('Failed to load book:', error);
            }
        }
        
        // 设置事件监听器
        function setupEventListeners() {
            viewer.addEventListener('relocate', handleRelocate);
            viewer.addEventListener('selection-end', handleSelectionEnd);
            viewer.addEventListener('annotation-click', handleAnnotationClick);
            viewer.addEventListener('click', handleClick);
        }
        
        function handleRelocate(event) {
            const location = event.detail;
            if (window.flutter_inappwebview) {
                window.flutter_inappwebview.callHandler('onRelocated', {
                    cfi: location.cfi,
                    percentage: location.progress?.fraction || 0,
                    chapterTitle: location.tocItem?.label || '',
                    currentPage: location.chapterLocation?.current || 1,
                    totalPages: location.chapterLocation?.total || 1
                });
            }
        }
        
        function handleSelectionEnd(event) {
            const selection = event.detail;
            if (window.flutter_inappwebview) {
                window.flutter_inappwebview.callHandler('onSelectionEnd', {
                    text: selection.text,
                    cfi: selection.cfi,
                    pos: selection.pos,
                    footnote: selection.footnote || false
                });
            }
        }
        
        function handleAnnotationClick(event) {
            const annotation = event.detail;
            if (window.flutter_inappwebview) {
                window.flutter_inappwebview.callHandler('onAnnotationClick', annotation);
            }
        }
        
        function handleClick(event) {
            if (window.flutter_inappwebview) {
                window.flutter_inappwebview.callHandler('onClick', {
                    x: event.detail.x,
                    y: event.detail.y
                });
            }
        }
        
        // 全局函数供Flutter调用
        window.addAnnotation = function(annotation) {
            viewer.addAnnotation(annotation);
        };
        
        window.removeAnnotation = function(cfi) {
            viewer.removeAnnotation(cfi);
        };
        
        window.goToCfi = function(cfi) {
            viewer.goTo(cfi);
        };
        
        window.nextPage = function() {
            viewer.next();
        };
        
        window.prevPage = function() {
            viewer.prev();
        };
        
        window.clearSelection = function() {
            if (window.getSelection) {
                window.getSelection().removeAllRanges();
            }
        };
        
        // 应用样式
        window.applyStyle = function(style) {
            document.body.style.fontSize = style.fontSize + 'px';
            document.body.style.lineHeight = style.lineHeight;
            document.body.style.letterSpacing = style.letterSpacing + 'px';
            document.body.style.background = style.backgroundColor;
            document.body.style.color = style.textColor;
        };
        
        // 启动
        loadBook();
    </script>
</body>
</html>
    ''';
  }

  /// 获取颜色的十六进制表示
  String _getColorHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2)}';
  }

  /// 文字选中处理
  void _onTextSelected(Map<String, dynamic> data) {
    _hideTextSelectionMenu();

    _selectedText = data['text'] ?? '';
    _selectedCfi = data['cfi'] ?? '';

    if (_selectedText.trim().isEmpty) return;

    final pos = data['pos'] as Map<String, dynamic>?;
    if (pos != null) {
      final point = pos['point'] as Map<String, dynamic>?;
      if (point != null) {
        final x = (point['x'] as num).toDouble();
        final y = (point['y'] as num).toDouble();
        _showTextSelectionMenu(x, y);
      }
    }
  }

  /// 注释点击处理
  void _onAnnotationClick(Map<String, dynamic> data) {
    // 处理注释点击
    debugPrint('注释点击: $data');
  }

  /// 显示文字选择菜单
  void _showTextSelectionMenu(double x, double y) {
    _hideTextSelectionMenu();

    final screenSize = MediaQuery.of(context).size;
    final menuWidth = 300.0;
    final menuHeight = 120.0;

    // 调整位置确保菜单不超出屏幕
    double left = (x * screenSize.width) - (menuWidth / 2);
    left = left.clamp(20.0, screenSize.width - menuWidth - 20.0);

    double top = (y * screenSize.height) - menuHeight - 20;
    if (top < 100) {
      top = (y * screenSize.height) + 20;
    }

    _textSelectionMenu = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: top,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          color: _currentTheme.controlBarColor,
          child: Container(
            width: menuWidth,
            padding: const EdgeInsets.all(16),
            child: _buildTextSelectionMenuContent(),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_textSelectionMenu!);
  }

  /// 构建文字选择菜单内容
  Widget _buildTextSelectionMenuContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 操作按钮行
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSelectionButton(
              icon: Icons.copy,
              label: '复制',
              onTap: _copySelectedText,
            ),
            _buildSelectionButton(
              icon: Icons.search,
              label: '搜索',
              onTap: _searchSelectedText,
            ),
            _buildSelectionButton(
              icon: Icons.translate,
              label: '翻译',
              onTap: _translateSelectedText,
            ),
            _buildSelectionButton(
              icon: Icons.share,
              label: '分享',
              onTap: _shareSelectedText,
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 高亮颜色行
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildHighlightButton(Colors.yellow, 'FFFF00'),
            _buildHighlightButton(Colors.blue, '66CCFF'),
            _buildHighlightButton(Colors.red, 'FF0000'),
            _buildHighlightButton(Colors.green, '00FF00'),
            _buildHighlightButton(Colors.purple, 'EB3BFF'),
          ],
        ),

        const SizedBox(height: 8),

        // 笔记按钮
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _addNote,
            icon: const Icon(Icons.edit_note, size: 16),
            label: const Text('添加笔记'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _currentTheme.sliderActiveColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建选择按钮
  Widget _buildSelectionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _currentTheme.textColor, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: _currentTheme.textColor, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建高亮按钮
  Widget _buildHighlightButton(Color color, String colorHex) {
    return InkWell(
      onTap: () => _addHighlight(colorHex),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.7),
          shape: BoxShape.circle,
          border: Border.all(
            color: _currentTheme.textColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Icon(Icons.highlight, color: Colors.white, size: 16),
      ),
    );
  }

  /// 隐藏文字选择菜单
  void _hideTextSelectionMenu() {
    if (_textSelectionMenu != null) {
      _textSelectionMenu!.remove();
      _textSelectionMenu = null;

      // 清除WebView中的选择
      _webViewController?.evaluateJavascript(source: 'window.clearSelection()');
    }
  }

  /// 复制选中文本
  void _copySelectedText() {
    Clipboard.setData(ClipboardData(text: _selectedText));
    _hideTextSelectionMenu();
    _showMessage('已复制到剪贴板');
  }

  /// 搜索选中文本
  void _searchSelectedText() {
    _hideTextSelectionMenu();
    // TODO: 实现搜索功能
    _showMessage('搜索功能开发中');
  }

  /// 翻译选中文本
  void _translateSelectedText() {
    _hideTextSelectionMenu();
    // TODO: 实现翻译功能
    _showMessage('翻译功能开发中');
  }

  /// 分享选中文本
  void _shareSelectedText() {
    _hideTextSelectionMenu();
    showShareDialog(
      context: context,
      bookTitle: widget.book.title,
      author: widget.book.author,
      currentPageContent: _selectedText,
      currentPage: _currentPageNumber,
      totalPages: _totalPages,
      progressPercentage: _currentProgress * 100,
      readingTime: Duration(minutes: 0),
    );
  }

  /// 添加高亮
  Future<void> _addHighlight(String colorHex) async {
    try {
      final highlight = Highlight(
        bookId: widget.book.id!,
        pageNumber: _currentPageNumber,
        selectedText: _selectedText,
        startOffset: 0,
        endOffset: _selectedText.length,
        color: Color(int.parse('0xFF$colorHex')),
        cfi: _selectedCfi,
        chapter: _chapterTitle,
      );

      final id = await _highlightDao.insertHighlight(highlight);
      final savedHighlight = highlight.copyWith(id: id);

      _highlights.add(savedHighlight);

      // 在WebView中添加高亮
      await _webViewController?.evaluateJavascript(
        source:
            '''
        window.addAnnotation({
          id: $id,
          type: 'highlight',
          value: '$_selectedCfi',
          color: '#$colorHex',
          note: '',
        });
      ''',
      );

      _hideTextSelectionMenu();
      _showMessage('高亮已添加');
    } catch (e) {
      debugPrint('添加高亮失败: $e');
      _showMessage('添加高亮失败');
    }
  }

  /// 添加笔记
  Future<void> _addNote() async {
    _hideTextSelectionMenu();

    final noteController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _currentTheme.backgroundColor,
        title: Text('添加笔记', style: TextStyle(color: _currentTheme.textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _currentTheme.textColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _selectedText,
                style: TextStyle(
                  color: _currentTheme.textColor.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                hintText: '输入笔记内容...',
                hintStyle: TextStyle(
                  color: _currentTheme.textColor.withValues(alpha: 0.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _currentTheme.sliderActiveColor,
                    width: 2,
                  ),
                ),
              ),
              style: TextStyle(color: _currentTheme.textColor),
              maxLines: 3,
              autofocus: true,
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
            onPressed: () => Navigator.pop(context, noteController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: _currentTheme.sliderActiveColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _saveNote(result);
    }
  }

  /// 保存笔记
  Future<void> _saveNote(String noteText) async {
    try {
      final note = Note(
        bookId: widget.book.id!,
        pageNumber: _currentPageNumber,
        content: _selectedText,
        note: noteText,
        cfi: _selectedCfi,
        chapter: _chapterTitle,
      );

      final id = await _noteDao.insertNote(note);
      final savedNote = note.copyWith(id: id);

      _notes.add(savedNote);

      // 同时添加高亮
      await _addHighlight('FFFF00');

      _showMessage('笔记已保存');
    } catch (e) {
      debugPrint('保存笔记失败: $e');
      _showMessage('保存笔记失败');
    }
  }

  /// 渲染注释
  Future<void> _renderAnnotations() async {
    if (_webViewController == null) return;

    final annotations = <Map<String, dynamic>>[];

    // 添加高亮
    for (final highlight in _highlights) {
      annotations.add({
        'id': highlight.id,
        'type': 'highlight',
        'value': highlight.cfi,
        'color':
            '#${highlight.color.toARGB32().toRadixString(16).substring(2)}',
        'note': '',
      });
    }

    // 添加书签
    for (final bookmark in _bookmarks) {
      annotations.add({
        'id': bookmark.id,
        'type': 'bookmark',
        'value': bookmark.cfi ?? '',
        'color': '#000000',
        'note': bookmark.note,
      });
    }

    if (annotations.isNotEmpty) {
      final annotationsJson = jsonEncode(annotations);
      await _webViewController!.evaluateJavascript(
        source:
            '''
        const annotations = $annotationsJson;
        annotations.forEach(annotation => {
          window.addAnnotation(annotation);
        });
      ''',
      );
    }
  }

  /// 保存阅读进度
  Future<void> _saveReadingProgress() async {
    if (_isInitializing || !mounted || widget.book.id == null) return;

    try {
      await _bookDao.updateBook(
        widget.book.copyWith(currentPage: _currentPageNumber),
      );
    } catch (e) {
      debugPrint('保存阅读进度失败: $e');
    }
  }

  /// 显示消息
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: _currentTheme.controlBarColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentTheme.backgroundColor,
      body: Stack(
        children: [
          // WebView主体
          _buildWebView(),

          // 顶部控制栏
          _buildTopBar(),

          // 底部控制栏
          _buildBottomToolbar(),
        ],
      ),
    );
  }

  /// 构建WebView
  Widget _buildWebView() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _currentTheme.textColor),
            const SizedBox(height: 16),
            Text(
              '正在加载增强阅读器...',
              style: TextStyle(
                fontSize: 16,
                color: _currentTheme.textColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(
                fontSize: 16,
                color: _currentTheme.textColor.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeReading,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return InAppWebView(
      initialSettings: InAppWebViewSettings(
        supportZoom: false,
        transparentBackground: true,
        javaScriptEnabled: true,
        domStorageEnabled: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
      ),
      onWebViewCreated: _onWebViewCreated,
      onLoadStop: (controller, url) {
        debugPrint('WebView加载完成: $url');
      },
      onConsoleMessage: (controller, consoleMessage) {
        debugPrint('WebView控制台: ${consoleMessage.message}');
      },
    );
  }

  /// 构建顶部栏
  Widget _buildTopBar() {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final isLightBackground =
        _currentTheme.backgroundColor.computeLuminance() > 0.5;
    final textColor = isLightBackground ? Colors.black87 : Colors.white;
    final iconBgColor = isLightBackground
        ? Colors.grey.withValues(alpha: 0.2)
        : Colors.grey.withValues(alpha: 0.3);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: _showControls ? 0 : -80.0,
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
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
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
                            _chapterTitle.isNotEmpty
                                ? _chapterTitle
                                : widget.book.author,
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
                        '$_currentPageNumber/$_totalPages',
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

  /// 构建底部工具栏
  Widget _buildBottomToolbar() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final Color toolbarBgColor = _currentTheme.controlBarColor;
    final Color handleColor = _currentTheme.iconColor.withValues(alpha: 0.6);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      bottom: _showControls ? 0 : -150.0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _showControls ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !_showControls,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 8),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: EdgeInsets.only(bottom: bottomPadding + 8),
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
      ),
    );
  }

  /// 构建工具栏按钮
  Widget _buildToolbarButtons() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ReadingThemeManager.createToolbarButton(
            icon: Icons.format_list_bulleted_rounded,
            label: '目录',
            onTap: _showTableOfContents,
            theme: _currentTheme,
          ),
          ReadingThemeManager.createToolbarButton(
            icon: Icons.record_voice_over_rounded,
            label: '朗读',
            onTap: _showTtsPanel,
            theme: _currentTheme,
          ),
          ReadingThemeManager.createToolbarButton(
            icon: Icons.bookmark_add_rounded,
            label: '书签',
            onTap: _toggleBookmark,
            theme: _currentTheme,
          ),
          ReadingThemeManager.createToolbarButton(
            icon: Icons.share_rounded,
            label: '分享',
            onTap: _showShareDialog,
            theme: _currentTheme,
          ),
          ReadingThemeManager.createToolbarButton(
            icon: Icons.palette_rounded,
            label: '主题',
            onTap: _showThemePanel,
            theme: _currentTheme,
          ),
          ReadingThemeManager.createToolbarButton(
            icon: Icons.tune_rounded,
            label: '设置',
            onTap: _showSettingsPanel,
            theme: _currentTheme,
          ),
        ],
      ),
    );
  }

  /// 显示目录
  void _showTableOfContents() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => TocWidget(
        book: widget.book,
        chapters: _chapters,
        bookmarks: _bookmarks,
        currentPageIndex: _currentPageNumber - 1,
        onPageTap: (pageIndex) {
          Navigator.pop(context);
          _goToPage(pageIndex);
        },
        onBookmarkTap: (bookmark) {
          Navigator.pop(context);
          if (bookmark.cfi != null) {
            _goToCfi(bookmark.cfi!);
          }
        },
      ),
    );
  }

  /// 显示TTS面板
  void _showTtsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => TtsPanelEnhanced(
        textToRead: _selectedText.isNotEmpty ? _selectedText : '当前页面内容',
      ),
    );
  }

  /// 切换书签
  Future<void> _toggleBookmark() async {
    if (widget.book.id == null || _currentCfi.isEmpty) {
      _showMessage('无法添加书签');
      return;
    }

    try {
      final existingBookmark = _bookmarks.firstWhere(
        (b) => b.cfi == _currentCfi,
        orElse: () => Bookmark(bookId: -1, pageNumber: 0, note: ''),
      );

      if (existingBookmark.id != null) {
        // 删除书签
        await _bookmarkDao.deleteBookmark(existingBookmark.id!);
        _bookmarks.remove(existingBookmark);

        await _webViewController?.evaluateJavascript(
          source:
              '''
          window.removeAnnotation('$_currentCfi');
        ''',
        );

        _showMessage('书签已删除');
      } else {
        // 添加书签
        final bookmark = Bookmark(
          bookId: widget.book.id!,
          pageNumber: _currentPageNumber,
          note: '第$_currentPageNumber页',
          cfi: _currentCfi,
        );

        final id = await _bookmarkDao.insertBookmark(bookmark);
        final savedBookmark = bookmark.copyWith(id: id);
        _bookmarks.add(savedBookmark);

        await _webViewController?.evaluateJavascript(
          source:
              '''
          window.addAnnotation({
            id: $id,
            type: 'bookmark',
            value: '$_currentCfi',
            color: '#000000',
            note: '${savedBookmark.note}',
          });
        ''',
        );

        _showMessage('书签已添加');
      }
    } catch (e) {
      debugPrint('书签操作失败: $e');
      _showMessage('书签操作失败');
    }
  }

  /// 显示分享对话框
  void _showShareDialog() {
    showShareDialog(
      context: context,
      bookTitle: widget.book.title,
      author: widget.book.author,
      currentPageContent: _selectedText.isNotEmpty ? _selectedText : '当前阅读内容',
      currentPage: _currentPageNumber,
      totalPages: _totalPages,
      progressPercentage: _currentProgress * 100,
      readingTime: Duration(minutes: 0),
    );
  }

  /// 显示主题面板
  void _showThemePanel() {
    // TODO: 实现主题选择面板
    _showMessage('主题面板开发中');
  }

  /// 显示设置面板
  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EnhancedReadingSettingsDialog(
        currentTheme: _currentTheme,
        onThemeChanged: (theme) async {
          setState(() => _currentTheme = theme);
          await ReadingThemeManager.setTheme(theme);
          _updateWebViewStyle();
        },
        fontSize: _fontSize,
        onFontSizeChanged: (size) {
          setState(() => _fontSize = size);
          _updateWebViewStyle();
        },
        lineHeight: _lineSpacing,
        onLineHeightChanged: (height) {
          setState(() => _lineSpacing = height);
          _updateWebViewStyle();
        },
        letterSpacing: _letterSpacing,
        onLetterSpacingChanged: (spacing) {
          setState(() => _letterSpacing = spacing);
          _updateWebViewStyle();
        },
        fontFamily: _fontFamily,
        onFontFamilyChanged: (family) {
          setState(() => _fontFamily = family);
          _updateWebViewStyle();
        },
        currentAnimationType: _currentAnimationType,
        onAnimationTypeChanged: (type) async {
          setState(() => _currentAnimationType = type);
          await PageAnimationManager.setAnimationType(type);
        },
      ),
    );
  }

  /// 更新WebView样式
  Future<void> _updateWebViewStyle() async {
    if (_webViewController == null) return;

    await _webViewController!.evaluateJavascript(
      source:
          '''
      window.applyStyle({
        fontSize: $_fontSize,
        lineHeight: $_lineSpacing,
        letterSpacing: $_letterSpacing,
        backgroundColor: '${_getColorHex(_currentTheme.backgroundColor)}',
        textColor: '${_getColorHex(_currentTheme.textColor)}',
        fontFamily: '${_fontFamily == 'System' ? 'system-ui' : _fontFamily}',
      });
    ''',
    );
  }

  /// 跳转到指定页面
  Future<void> _goToPage(int pageIndex) async {
    // TODO: 实现页面跳转
    _showMessage('跳转到第${pageIndex + 1}页');
  }

  /// 跳转到指定CFI
  Future<void> _goToCfi(String cfi) async {
    if (_webViewController == null) return;

    await _webViewController!.evaluateJavascript(
      source:
          '''
      window.goToCfi('$cfi');
    ''',
    );
  }

  @override
  void dispose() {
    _controlBarAnimationController.dispose();
    _fadeAnimationController.dispose();
    _hideControlsTimer?.cancel();
    _hideTextSelectionMenu();

    // 保存阅读统计
    if (_sessionStartTime != null) {
      final duration = DateTime.now().difference(_sessionStartTime!);
      if (duration.inSeconds > 10) {
        _statsDao.insertReadingTime(DateTime.now(), duration.inSeconds);
      }
    }

    _saveReadingProgress();

    // 恢复系统UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );

    super.dispose();
  }
}
