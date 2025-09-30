import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:intl/intl.dart';

import '../models/book.dart';
import 'book_player_server.dart';
import '../services/reading_theme_manager.dart'; // 引入主题管理器

/// 基于anx-reader架构的增强WebView阅读器
/// 完全保留原有UI风格，使用WebView作为渲染引擎
class EnhancedWebViewReader extends StatefulWidget {
  final Book book;
  final String? initialCfi;
  final ReadingTheme theme;
  final double fontSize;
  final double lineSpacing;
  final double letterSpacing;
  final String fontFamily;
  final bool scrollMode;
  final VoidCallback? onToggleControlBar;
  final Function(PageInfo)? onPageChanged;
  final Function(String, String, String, bool)? onTextSelected;
  final Function(String, String, String, int?)? onAnnotationClicked;
  final Function()? onLoadEnd;

  const EnhancedWebViewReader({
    super.key,
    required this.book,
    this.initialCfi,
    required this.theme,
    this.fontSize = 16.0,
    this.lineSpacing = 1.6,
    this.letterSpacing = 0.0,
    this.fontFamily = 'System',
    this.scrollMode = false,
    this.onToggleControlBar,
    this.onPageChanged,
    this.onTextSelected,
    this.onAnnotationClicked,
    this.onLoadEnd,
  });

  @override
  State<EnhancedWebViewReader> createState() => _EnhancedWebViewReaderState();
}

class _EnhancedWebViewReaderState extends State<EnhancedWebViewReader>
    with TickerProviderStateMixin {
  InAppWebViewController? _webViewController;
  final BookPlayerServer _server = BookPlayerServer();

  // 服务器状态
  bool _isServerReady = false;
  String? _serverError;

  // 阅读状态
  double _percentage = 0.0;
  String _chapterTitle = '';
  int _chapterCurrentPage = 0;
  int _chapterTotalPages = 0;

  // 历史导航
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _showHistory = false;
  Timer? _historyTimer;

  // 注释和高亮
  final List<Map<String, dynamic>> _searchResults = [];

  // 动画控制器
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

  // 阅读信息显示
  Timer? _batteryTimer;
  int _batteryLevel = 100;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startBatteryMonitoring();
    WakelockPlus.enable();
    _initializeServer(); // 异步初始化服务器
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _historyTimer?.cancel();
    _batteryTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  void _initializeAnimations() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeOut),
    );

    // 启动淡入动画（模拟anx开书动画）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fadeAnimationController.forward();
    });
  }

  Future<void> _initializeServer() async {
    try {
      debugPrint('正在启动BookPlayerServer...');
      await _server.start();

      // 等待一小段时间确保服务器完全就绪
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _isServerReady = true;
          _serverError = null;
        });
        debugPrint('BookPlayerServer启动成功，端口: ${_server.port}');
      }
    } catch (e) {
      debugPrint('BookPlayerServer启动失败: $e');
      if (mounted) {
        setState(() {
          _isServerReady = false;
          _serverError = e.toString();
        });
      }
    }
  }

  void _startBatteryMonitoring() {
    _batteryTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        final battery = Battery();
        final level = await battery.batteryLevel;
        if (mounted) {
          setState(() {
            _batteryLevel = level;
          });
        }
      } catch (e) {
        // 忽略电池状态获取错误
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.theme.backgroundColor,
      body: Stack(
        children: [
          // 根据服务器状态显示不同内容
          if (!_isServerReady)
            _buildServerLoadingWidget()
          else if (_serverError != null)
            _buildServerErrorWidget()
          else
            _buildWebView(),

          // 阅读信息覆盖层（保持你的UI风格）
          if (_isServerReady && _serverError == null)
            _buildReadingInfoOverlay(),

          // 历史导航按钮
          if (_showHistory && _isServerReady) _buildHistoryNavigation(),

          // 开书动画覆盖层
          if (_isServerReady) _buildBookOpeningAnimation(),
        ],
      ),
    );
  }

  Widget _buildWebView() {
    final bookPath = widget.book.filePath;
    final url = _server.generateUrl(
      bookPath,
      initialCfi: widget.initialCfi,
      backgroundColor: widget.theme.backgroundColor.value
          .toRadixString(16)
          .padLeft(8, '0')
          .substring(2),
      textColor: widget.theme.textColor.value
          .toRadixString(16)
          .padLeft(8, '0')
          .substring(2),
    );

    debugPrint('WebView URL: $url');
    debugPrint('Book Path: $bookPath');

    return GestureDetector(
      onTap: () {
        // 保持你原有的点击逻辑
        widget.onToggleControlBar?.call();
      },
      child: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          supportZoom: false,
          transparentBackground: true,
          isInspectable: kDebugMode,
          allowsInlineMediaPlayback: true,
          mediaPlaybackRequiresUserGesture: false,
          iframeAllow: "camera; microphone; geolocation",
          iframeAllowFullscreen: true,
        ),
        onWebViewCreated: _onWebViewCreated,
        onLoadStop: _onLoadStop,
        onConsoleMessage: _onConsoleMessage,
      ),
    );
  }

  Future<void> _onWebViewCreated(InAppWebViewController controller) async {
    _webViewController = controller;
    await _setupJavaScriptHandlers(controller);
  }

  Future<void> _onLoadStop(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    await _applyReadingSettings();
    widget.onLoadEnd?.call();
  }

  void _onConsoleMessage(
    InAppWebViewController controller,
    ConsoleMessage consoleMessage,
  ) {
    if (kDebugMode) {
      print('WebView Console: ${consoleMessage.message}');
    }
  }

  Future<void> _setupJavaScriptHandlers(
    InAppWebViewController controller,
  ) async {
    // 页面位置变化处理
    controller.addJavaScriptHandler(
      handlerName: 'onRelocated',
      callback: (args) {
        if (args.isNotEmpty) {
          final location = args[0] as Map<String, dynamic>;
          _updateReadingProgress(location);
        }
      },
    );

    // 点击处理
    controller.addJavaScriptHandler(
      handlerName: 'onClick',
      callback: (args) {
        if (args.isNotEmpty) {
          final clickData = args[0] as Map<String, dynamic>;
          _handleClick(clickData);
        }
      },
    );

    // 文本选择结束
    controller.addJavaScriptHandler(
      handlerName: 'onSelectionEnd',
      callback: (args) {
        if (args.isNotEmpty) {
          final selectionData = args[0] as Map<String, dynamic>;
          _handleTextSelection(selectionData);
        }
      },
    );

    // 注释点击
    controller.addJavaScriptHandler(
      handlerName: 'onAnnotationClick',
      callback: (args) {
        if (args.isNotEmpty) {
          final annotationData = args[0] as Map<String, dynamic>;
          _handleAnnotationClick(annotationData);
        }
      },
    );

    // 搜索结果
    controller.addJavaScriptHandler(
      handlerName: 'onSearch',
      callback: (args) {
        if (args.isNotEmpty) {
          final searchData = args[0] as Map<String, dynamic>;
          _handleSearchResult(searchData);
        }
      },
    );

    // 历史状态变化
    controller.addJavaScriptHandler(
      handlerName: 'onPushState',
      callback: (args) {
        if (args.isNotEmpty) {
          final stateData = args[0] as Map<String, dynamic>;
          _updateHistoryState(stateData);
        }
      },
    );

    // 加载完成
    controller.addJavaScriptHandler(
      handlerName: 'onLoadEnd',
      callback: (args) {
        widget.onLoadEnd?.call();
      },
    );
  }

  void _updateReadingProgress(Map<String, dynamic> location) {
    setState(() {
      _percentage = (location['percentage'] ?? 0.0).toDouble();
      _chapterTitle = location['chapterTitle'] ?? '';
      _chapterCurrentPage = location['chapterCurrentPage'] ?? 0;
      _chapterTotalPages = location['chapterTotalPages'] ?? 0;
    });

    // 通知外部页面信息变化
    if (widget.onPageChanged != null) {
      widget.onPageChanged!(
        PageInfo(
          currentPage: _chapterCurrentPage,
          totalPages: _chapterTotalPages,
          progress: _percentage,
          content: _chapterTitle,
        ),
      );
    }
  }

  void _handleClick(Map<String, dynamic> clickData) {
    // 保持你原有的点击处理逻辑
    widget.onToggleControlBar?.call();
  }

  void _handleTextSelection(Map<String, dynamic> selectionData) {
    final cfi = selectionData['cfi'] as String? ?? '';
    final text = selectionData['text'] as String? ?? '';
    final pos = selectionData['pos'] as Map<String, dynamic>? ?? {};
    final dir = pos['dir'] as String? ?? '';
    final footnote = selectionData['footnote'] as bool? ?? false;

    widget.onTextSelected?.call(text, cfi, dir, footnote);
  }

  void _handleAnnotationClick(Map<String, dynamic> annotationData) {
    final annotation =
        annotationData['annotation'] as Map<String, dynamic>? ?? {};
    final pos = annotationData['pos'] as Map<String, dynamic>? ?? {};

    final id = annotation['id'] as int?;
    final cfi = annotation['value'] as String? ?? '';
    final note = annotation['note'] as String? ?? '';
    final dir = pos['dir'] as String? ?? '';

    widget.onAnnotationClicked?.call(note, cfi, dir, id);
  }

  void _handleSearchResult(Map<String, dynamic> searchData) {
    if (searchData.containsKey('process')) {
      // 搜索进度更新，可以在这里处理进度显示
      final progress = (searchData['process'] ?? 0.0).toDouble();
      debugPrint('搜索进度: ${(progress * 100).toStringAsFixed(1)}%');
    } else {
      setState(() {
        _searchResults.add(searchData);
      });
    }
  }

  void _updateHistoryState(Map<String, dynamic> stateData) {
    setState(() {
      _canGoBack = stateData['canGoBack'] ?? false;
      _canGoForward = stateData['canGoForward'] ?? false;
      _showHistory = true;
    });

    _historyTimer?.cancel();
    _historyTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showHistory = false;
        });
      }
    });
  }

  Future<void> _applyReadingSettings() async {
    if (_webViewController == null) return;

    await _webViewController!.evaluateJavascript(
      source: '''
      if (typeof reader !== 'undefined' && reader.view) {
        reader.view.renderer?.setStyles({
            fontSize: ${widget.fontSize}px,
          lineHeight: ${widget.lineSpacing},
          letterSpacing: ${widget.letterSpacing}em,
          fontFamily: '${widget.fontFamily}',
          backgroundColor: '#${widget.theme.backgroundColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
          color: '#${widget.theme.textColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
          scrollMode: ${widget.scrollMode}
        });
      }
    ''',
    );
  }

  Widget _buildReadingInfoOverlay() {
    if (_chapterCurrentPage == 0 && _percentage == 0.0) {
      return const SizedBox.shrink();
    }

    // 保持你原有的文字样式
    final textStyle = TextStyle(
      color: widget.theme.textColor.withOpacity(0.6),
      fontSize: 11,
      fontFamily: widget.fontFamily,
    );

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部信息
              SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 章节标题
                    Expanded(
                      child: Text(
                        _chapterCurrentPage == 1
                            ? widget.book.title
                            : _chapterTitle,
                        style: textStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 时间
                    StreamBuilder(
                      stream: Stream.periodic(const Duration(seconds: 1)),
                      builder: (context, snapshot) {
                        return Text(
                          DateFormat('HH:mm').format(DateTime.now()),
                          style: textStyle,
                        );
                      },
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // 底部信息
              SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 页面进度
                    Text(
                      '$_chapterCurrentPage/$_chapterTotalPages',
                      style: textStyle,
                    ),

                    // 电池和阅读进度
                    Row(
                      children: [
                        // 电池图标
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.battery_full,
                              size: 20,
                              color: widget.theme.textColor.withOpacity(0.6),
                            ),
                            Positioned(
                              right: 3,
                              child: Text(
                                '$_batteryLevel',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: widget.theme.textColor.withOpacity(
                                    0.8,
                                  ),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        // 阅读进度
                        Text(
                          '${(_percentage * 100).toStringAsFixed(1)}%',
                          style: textStyle,
                        ),
                      ],
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

  Widget _buildHistoryNavigation() {
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_canGoBack)
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: FloatingActionButton.small(
                onPressed: _goBack,
                backgroundColor: widget.theme.controlBarColor,
                child: Icon(
                  Icons.arrow_back_ios,
                  color: widget.theme.iconColor,
                ),
              ),
            ),
          if (_canGoForward)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: FloatingActionButton.small(
                onPressed: _goForward,
                backgroundColor: widget.theme.controlBarColor,
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: widget.theme.iconColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBookOpeningAnimation() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        if (_fadeAnimation.value <= 0) {
          return const SizedBox.shrink();
        }

        return Positioned.fill(
          child: Container(
            color: widget.theme.backgroundColor,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: Container(
                  width: 200,
                  height: 280,
                  decoration: BoxDecoration(
                    color: widget.theme.controlBarColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_stories,
                        size: 48,
                        color: widget.theme.iconColor,
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          widget.book.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: widget.theme.textColor,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 公共方法，供外部调用

  Future<void> nextPage() async {
    await _webViewController?.evaluateJavascript(source: 'reader.view.next()');
  }

  Future<void> prevPage() async {
    await _webViewController?.evaluateJavascript(source: 'reader.view.prev()');
  }

  Future<void> goToPage(int page) async {
    final progress = page / _chapterTotalPages;
    await _webViewController?.evaluateJavascript(
      source: 'reader.view.goTo($progress)',
    );
  }

  Future<void> goToCfi(String cfi) async {
    await _webViewController?.evaluateJavascript(
      source: "reader.view.goTo('$cfi')",
    );
  }

  Future<void> _goBack() async {
    await _webViewController?.evaluateJavascript(
      source: 'reader.view.goBack()',
    );
  }

  Future<void> _goForward() async {
    await _webViewController?.evaluateJavascript(
      source: 'reader.view.goForward()',
    );
  }

  Future<void> addHighlight(String cfi, String color, String note) async {
    await _webViewController?.evaluateJavascript(
      source: '''
      reader.view.addAnnotation({
        type: 'highlight',
        value: '$cfi',
        color: '$color',
        note: '$note'
      })
    ''',
    );
  }

  Future<void> removeAnnotation(String cfi) async {
    await _webViewController?.evaluateJavascript(
      source: "reader.view.deleteAnnotation('$cfi')",
    );
  }

  Future<void> search(String query) async {
    await _webViewController?.evaluateJavascript(
      source: "reader.search('$query')",
    );
  }

  Future<void> updateSettings() async {
    await _applyReadingSettings();
  }

  // --- 服务器状态UI组件 ---

  Widget _buildServerLoadingWidget() {
    return Container(
      color: widget.theme.backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: widget.theme.textColor),
            const SizedBox(height: 24),
            Text(
              '正在启动阅读服务器...',
              style: TextStyle(
                fontSize: 16,
                color: widget.theme.textColor.withOpacity(0.8),
                fontFamily: widget.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请稍等片刻',
              style: TextStyle(
                fontSize: 14,
                color: widget.theme.textColor.withOpacity(0.6),
                fontFamily: widget.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerErrorWidget() {
    return Container(
      color: widget.theme.backgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
              const SizedBox(height: 24),
              Text(
                '服务器启动失败',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: widget.theme.textColor,
                  fontFamily: widget.fontFamily,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _serverError ?? '未知错误',
                style: TextStyle(
                  fontSize: 14,
                  color: widget.theme.textColor.withOpacity(0.7),
                  fontFamily: widget.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _retryServerStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.theme.textColor,
                  foregroundColor: widget.theme.backgroundColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _retryServerStart() async {
    setState(() {
      _isServerReady = false;
      _serverError = null;
    });

    try {
      // 尝试重启服务器
      await _server.restart();

      // 等待一小段时间确保服务器完全就绪
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _isServerReady = true;
          _serverError = null;
        });
        debugPrint('BookPlayerServer重启成功，端口: ${_server.port}');
      }
    } catch (e) {
      debugPrint('BookPlayerServer重启失败: $e');
      if (mounted) {
        setState(() {
          _isServerReady = false;
          _serverError = e.toString();
        });
      }
    }
  }
}

/// 页面信息数据类（兼容你现有的接口）
class PageInfo {
  final int currentPage;
  final int totalPages;
  final double progress;
  final String content;

  PageInfo({
    required this.currentPage,
    required this.totalPages,
    required this.progress,
    required this.content,
  });
}
