import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:battery_plus/battery_plus.dart';

import '../models/book.dart';
import 'book_player_server.dart';

/// 简化的WebView阅读器（基于anx-reader架构）
/// 保留原有UI风格和动画
class SimpleWebViewReader extends StatefulWidget {
  final Book book;
  final Color backgroundColor;
  final Color textColor;
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final Function(
    String cfi,
    double percentage,
    int currentPage,
    int totalPages,
  )?
  onPageChanged;
  final Function(String selectedText, String cfi)? onTextSelected;
  final Function()? onTap;
  final Function()? onReady;

  const SimpleWebViewReader({
    super.key,
    required this.book,
    required this.backgroundColor,
    required this.textColor,
    required this.fontFamily,
    this.fontSize = 16.0,
    this.lineHeight = 1.5,
    this.onPageChanged,
    this.onTextSelected,
    this.onTap,
    this.onReady,
  });

  @override
  State<SimpleWebViewReader> createState() => _SimpleWebViewReaderState();
}

class _SimpleWebViewReaderState extends State<SimpleWebViewReader>
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
  String _currentCfi = '';

  // 历史导航
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _showHistory = false;

  // 动画控制器（保留原有开书动画）
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;
  bool _animationCompleted = false;

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

    // 监听动画完成
    _fadeAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _animationCompleted = true;
        });
      }
    });

    // 启动淡入动画（模拟开书动画）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fadeAnimationController.forward();
    });
  }

  Future<void> _initializeServer() async {
    try {
      debugPrint('正在启动BookPlayerServer...');
      // 如果服务器已经在运行，先停止它
      if (_server.isRunning) {
        await _server.stop();
        await Future.delayed(const Duration(milliseconds: 200));
      }

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
      backgroundColor: widget.backgroundColor,
      body: SafeArea(
        // 为iPhone 16 Pro Max等设备确保顶部安全区域
        top: true,
        bottom: false, // 底部交给控制栏处理
        child: !_isServerReady
            ? _buildServerLoadingWidget()
            : _serverError != null
            ? _buildServerErrorWidget()
            : _buildWebView(),
      ),
    );
  }

  Widget _buildWebView() {
    final bookPath = widget.book.filePath;

    // 验证书籍文件是否存在
    final bookFile = File(bookPath);
    if (!bookFile.existsSync()) {
      debugPrint('❌ 书籍文件不存在: $bookPath');
      return _buildErrorWidget('书籍文件不存在\n路径: $bookPath');
    }

    // 将Color转换为十六进制字符串
    final backgroundColor = _colorToHex(widget.backgroundColor);
    final textColor = _colorToHex(widget.textColor);

    // 获取屏幕尺寸和安全区域进行响应式适配
    final screenSize = MediaQuery.of(context).size;
    final safeArea = MediaQuery.of(context).padding;

    debugPrint('屏幕信息: ${screenSize.width}x${screenSize.height}');
    debugPrint('安全区域: 顶部=${safeArea.top}, 底部=${safeArea.bottom}');

    final url = _server.generateUrl(
      bookPath,
      backgroundColor: backgroundColor,
      textColor: textColor,
      fontSize: widget.fontSize,
      lineHeight: widget.lineHeight,
      screenWidth: screenSize.width,
      screenHeight: screenSize.height,
    );

    debugPrint('WebView URL: $url');
    debugPrint('书籍路径: $bookPath');
    debugPrint('文件存在: ${bookFile.existsSync()}');
    debugPrint(
      '文件大小: ${bookFile.existsSync() ? bookFile.lengthSync() : 0} bytes',
    );

    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        supportZoom: false,
        transparentBackground: true,
        isInspectable: kDebugMode,
        // 确保WebView使用正确的背景色
        allowsBackForwardNavigationGestures: false,
        javaScriptEnabled: true,
        domStorageEnabled: true,
      ),
      onWebViewCreated: (controller) {
        _webViewController = controller;
        _setUpJavaScriptHandlers(controller);
      },
      onLoadStart: (controller, url) {
        debugPrint('WebView开始加载: $url');
      },
      onLoadStop: (controller, url) async {
        debugPrint('WebView加载完成: $url');
      },
      onReceivedError: (controller, request, error) {
        debugPrint('WebView错误: ${error.description}');
      },
      onConsoleMessage: (controller, consoleMessage) {
        debugPrint('WebView控制台: ${consoleMessage.message}');
      },
    );
  }

  void _setUpJavaScriptHandlers(InAppWebViewController controller) {
    // 页面位置变化处理
    controller.addJavaScriptHandler(
      handlerName: 'onRelocated',
      callback: (args) {
        if (args.isNotEmpty) {
          final location = args[0] as Map<String, dynamic>;
          setState(() {
            _currentCfi = location['cfi'] ?? '';
            _percentage = (location['percentage'] ?? 0.0).toDouble();
            _chapterTitle = location['chapterTitle'] ?? '';
            _chapterCurrentPage = location['chapterCurrentPage'] ?? 0;
            _chapterTotalPages = location['chapterTotalPages'] ?? 0;
          });

          // 回调页面变化
          widget.onPageChanged?.call(
            _currentCfi,
            _percentage,
            _chapterCurrentPage,
            _chapterTotalPages,
          );

          debugPrint(
            '页面定位: CFI=$_currentCfi, 进度=${(_percentage * 100).toStringAsFixed(1)}%',
          );
        }
      },
    );

    // 点击处理
    controller.addJavaScriptHandler(
      handlerName: 'onClick',
      callback: (args) {
        widget.onTap?.call();
      },
    );

    // 文本选择处理
    controller.addJavaScriptHandler(
      handlerName: 'onSelectionEnd',
      callback: (args) {
        if (args.isNotEmpty) {
          final location = args[0] as Map<String, dynamic>;
          final text = location['text'] ?? '';
          final cfi = location['cfi'] ?? '';

          if (text.isNotEmpty) {
            widget.onTextSelected?.call(text, cfi);
          }
        }
      },
    );

    // 历史导航状态变化
    controller.addJavaScriptHandler(
      handlerName: 'onPushState',
      callback: (args) {
        if (args.isNotEmpty) {
          final state = args[0] as Map<String, dynamic>;
          setState(() {
            _canGoBack = state['canGoBack'] ?? false;
            _canGoForward = state['canGoForward'] ?? false;
            _showHistory = true;
          });

          // 20秒后隐藏历史导航按钮
          Future.delayed(const Duration(seconds: 20), () {
            if (mounted) {
              setState(() {
                _showHistory = false;
              });
            }
          });
        }
      },
    );

    // 加载完成处理
    controller.addJavaScriptHandler(
      handlerName: 'onLoadEnd',
      callback: (args) {
        debugPrint('书籍内容加载完成');
        widget.onReady?.call();
      },
    );
  }

  // --- 页面控制方法 ---

  void prevPage() {
    _webViewController?.evaluateJavascript(source: 'prevPage()');
  }

  void nextPage() {
    _webViewController?.evaluateJavascript(source: 'nextPage()');
  }

  void goToPercentage(double percentage) {
    _webViewController?.evaluateJavascript(source: 'goToPercent($percentage)');
  }

  void goToCfi(String cfi) {
    _webViewController?.evaluateJavascript(source: "goToCfi('$cfi')");
  }

  void searchText(String query) {
    _webViewController?.evaluateJavascript(source: "search('$query')");
  }

  // --- UI组件 ---

  Widget _buildServerLoadingWidget() {
    return Container(
      color: widget.backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: widget.textColor),
            const SizedBox(height: 24),
            Text(
              '正在启动阅读服务器...',
              style: TextStyle(
                fontSize: 16,
                color: widget.textColor.withOpacity(0.8),
                fontFamily: widget.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '基于优化架构',
              style: TextStyle(
                fontSize: 14,
                color: widget.textColor.withOpacity(0.6),
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
      color: widget.backgroundColor,
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
                  color: widget.textColor,
                  fontFamily: widget.fontFamily,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _serverError ?? '未知错误',
                style: TextStyle(
                  fontSize: 14,
                  color: widget.textColor.withOpacity(0.7),
                  fontFamily: widget.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _retryServerStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.textColor,
                  foregroundColor: widget.backgroundColor,
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

  Widget _buildReadingInfoOverlay() {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        // 参考anx-reader: 不设置color属性，完全透明
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部信息
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      _chapterCurrentPage == 1
                          ? widget.book.title
                          : _chapterTitle,
                      style: TextStyle(
                        color: widget.textColor.withOpacity(0.6),
                        fontSize: 12,
                        fontFamily: widget.fontFamily,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: widget.textColor.withOpacity(0.6),
                      fontSize: 12,
                      fontFamily: widget.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // 底部信息
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_chapterCurrentPage/$_chapterTotalPages',
                    style: TextStyle(
                      color: widget.textColor.withOpacity(0.6),
                      fontSize: 12,
                      fontFamily: widget.fontFamily,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${(_percentage * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: widget.textColor.withOpacity(0.6),
                          fontSize: 12,
                          fontFamily: widget.fontFamily,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '$_batteryLevel%',
                        style: TextStyle(
                          color: widget.textColor.withOpacity(0.6),
                          fontSize: 12,
                          fontFamily: widget.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryNavigation() {
    return Positioned(
      bottom: 30,
      left: 0,
      child: Container(
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_canGoBack)
              IconButton(
                onPressed: _goBack,
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: widget.textColor.withOpacity(0.8),
                ),
              ),
            if (_canGoForward)
              IconButton(
                onPressed: _goForward,
                icon: Icon(
                  Icons.arrow_forward_ios,
                  color: widget.textColor.withOpacity(0.8),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookOpeningAnimation() {
    return SizedBox.expand(
      child: IgnorePointer(
        ignoring: true,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            color: widget.backgroundColor,
            child: Center(
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  color: widget.textColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.textColor.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      widget.book.title,
                      style: TextStyle(
                        color: widget.textColor.withOpacity(0.6),
                        fontSize: 14,
                        fontFamily: widget.fontFamily,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 历史导航方法 ---

  void _goBack() {
    _webViewController?.evaluateJavascript(source: 'back()');
  }

  void _goForward() {
    _webViewController?.evaluateJavascript(source: 'forward()');
  }

  Future<void> _retryServerStart() async {
    setState(() {
      _isServerReady = false;
      _serverError = null;
    });

    try {
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

  // --- 颜色转换工具 ---

  String _colorToHex(Color color) {
    // 确保返回正确的6位十六进制颜色值（不包含alpha通道）
    final hex = color.value.toRadixString(16).padLeft(8, '0').substring(2);
    debugPrint('颜色转换: ${color.toString()} -> $hex');
    return hex;
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      color: widget.backgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: widget.textColor.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              Text(
                'WebView加载错误',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: widget.textColor,
                  fontFamily: widget.fontFamily,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.textColor.withOpacity(0.7),
                  fontFamily: widget.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.textColor,
                  foregroundColor: widget.backgroundColor,
                ),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
