import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/advanced_text_paginator.dart';

/// 高级文本阅读器Widget
/// 基于WebView实现的精确分页阅读器
class AdvancedTextReaderWidget extends StatefulWidget {
  final String text;
  final PaginationConfig config;
  final VoidCallback? onReachStart;
  final VoidCallback? onReachEnd;
  final Function(PageInfo)? onPageChanged;
  final Function(int, int)? onMiddleClick;
  final Function(String)? onTextSelected;
  final bool enableInteraction;

  const AdvancedTextReaderWidget({
    Key? key,
    required this.text,
    required this.config,
    this.onReachStart,
    this.onReachEnd,
    this.onPageChanged,
    this.onMiddleClick,
    this.onTextSelected,
    this.enableInteraction = true,
  }) : super(key: key);

  @override
  State<AdvancedTextReaderWidget> createState() => _AdvancedTextReaderWidgetState();
}

class _AdvancedTextReaderWidgetState extends State<AdvancedTextReaderWidget> {
  InAppWebViewController? _webViewController;
  String? _htmlUri;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  PageInfo? _currentPageInfo;
  final Completer<void> _loadCompleter = Completer<void>();

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  @override
  void didUpdateWidget(AdvancedTextReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 如果文本或配置发生变化，重新设置内容
    if (oldWidget.text != widget.text || oldWidget.config != widget.config) {
      _setText();
    }
  }

  /// 初始化WebView
  Future<void> _initializeWebView() async {
    try {
      _htmlUri = await AdvancedTextPaginator.getHtmlUri();
      if (mounted) {
        setState(() {
          _isLoading = true;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('初始化WebView失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = '初始化失败: $e';
        });
      }
    }
  }

  /// 设置文本内容
  Future<void> _setText() async {
    if (_webViewController == null || widget.text.isEmpty) return;

    try {
      await _loadCompleter.future; // 等待WebView加载完成
      
      final configMap = widget.config.toMap();
      final result = await _webViewController!.callAsyncJavaScript(
        functionBody: '''
          return new Promise((resolve, reject) => {
            try {
              setText($1, $2).then(() => {
                resolve(true);
              }).catch(reject);
            } catch (error) {
              reject(error);
            }
          });
        ''',
        arguments: [widget.text, configMap],
      );
      
      if (result?.value != true) {
        throw Exception('设置文本失败');
      }
    } catch (e) {
      debugPrint('设置文本失败: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '设置文本失败: $e';
        });
      }
    }
  }

  /// WebView加载完成回调
  Future<void> _onWebViewCreated(InAppWebViewController controller) async {
    _webViewController = controller;

    // 添加JavaScript处理器
    await _addJavaScriptHandlers(controller);
  }

  /// 添加JavaScript处理器
  Future<void> _addJavaScriptHandlers(InAppWebViewController controller) async {
    // 分页完成处理器
    controller.addJavaScriptHandler(
      handlerName: 'onPaginationComplete',
      callback: (args) {
        final data = args.isNotEmpty ? args[0] as Map<String, dynamic> : {};
        debugPrint('分页完成: $data');
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = false;
          });
        }
      },
    );

    // 页面变化处理器
    controller.addJavaScriptHandler(
      handlerName: 'onPageChanged',
      callback: (args) {
        if (args.isNotEmpty) {
          final data = args[0] as Map<String, dynamic>;
          final pageInfo = PageInfo.fromMap(data);
          
          if (mounted) {
            setState(() {
              _currentPageInfo = pageInfo;
            });
          }
          
          widget.onPageChanged?.call(pageInfo);
        }
      },
    );

    // 到达开始位置处理器
    controller.addJavaScriptHandler(
      handlerName: 'onReachStart',
      callback: (args) {
        widget.onReachStart?.call();
      },
    );

    // 到达结束位置处理器
    controller.addJavaScriptHandler(
      handlerName: 'onReachEnd',
      callback: (args) {
        widget.onReachEnd?.call();
      },
    );

    // 中间点击处理器
    controller.addJavaScriptHandler(
      handlerName: 'onMiddleClick',
      callback: (args) {
        if (args.isNotEmpty) {
          final data = args[0] as Map<String, dynamic>;
          final x = data['x']?.toInt() ?? 0;
          final y = data['y']?.toInt() ?? 0;
          widget.onMiddleClick?.call(x, y);
        }
      },
    );
  }

  /// WebView加载完成
  Future<void> _onLoadStop(InAppWebViewController controller, WebUri? url) async {
    try {
      // 等待DOM完全加载
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (!_loadCompleter.isCompleted) {
        _loadCompleter.complete();
      }
      
      // 设置文本内容
      await _setText();
    } catch (e) {
      debugPrint('WebView加载完成处理失败: $e');
      if (!_loadCompleter.isCompleted) {
        _loadCompleter.completeError(e);
      }
    }
  }

  /// 下一页
  Future<bool> nextPage() async {
    if (_webViewController == null) return false;
    
    try {
      final result = await _webViewController!.evaluateJavascript(
        source: 'nextPage()',
      );
      return result == true;
    } catch (e) {
      debugPrint('下一页失败: $e');
      return false;
    }
  }

  /// 上一页
  Future<bool> prevPage() async {
    if (_webViewController == null) return false;
    
    try {
      final result = await _webViewController!.evaluateJavascript(
        source: 'prevPage()',
      );
      return result == true;
    } catch (e) {
      debugPrint('上一页失败: $e');
      return false;
    }
  }

  /// 跳转到指定页面
  Future<bool> goToPage(int page) async {
    if (_webViewController == null) return false;
    
    try {
      final result = await _webViewController!.evaluateJavascript(
        source: 'goToPage($page)',
      );
      return result == true;
    } catch (e) {
      debugPrint('跳转页面失败: $e');
      return false;
    }
  }

  /// 获取当前页面信息
  Future<PageInfo?> getCurrentPageInfo() async {
    if (_webViewController == null) return null;
    
    try {
      final result = await _webViewController!.evaluateJavascript(
        source: 'getCurrentPageInfo()',
      );
      
      if (result is Map<String, dynamic>) {
        return PageInfo.fromMap(result);
      }
    } catch (e) {
      debugPrint('获取页面信息失败: $e');
    }
    
    return null;
  }

  /// 搜索文本
  Future<List<SearchResult>> searchText(String query) async {
    if (_webViewController == null || query.isEmpty) return [];
    
    try {
      final result = await _webViewController!.callAsyncJavaScript(
        functionBody: 'return searchText($1);',
        arguments: [query],
      );
      
      if (result?.value is List) {
        final List<dynamic> resultList = result!.value as List<dynamic>;
        return resultList
            .where((item) => item is Map<String, dynamic>)
            .map((item) => SearchResult.fromMap(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('搜索文本失败: $e');
    }
    
    return [];
  }

  /// 更新配置
  Future<void> updateConfig(PaginationConfig config) async {
    if (_webViewController == null) return;
    
    try {
      await _webViewController!.callAsyncJavaScript(
        functionBody: '''
          return new Promise((resolve, reject) => {
            try {
              updateConfig($1).then(() => {
                resolve(true);
              }).catch(reject);
            } catch (error) {
              reject(error);
            }
          });
        ''',
        arguments: [config.toMap()],
      );
    } catch (e) {
      debugPrint('更新配置失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_htmlUri == null) {
      return _buildLoadingWidget();
    }

    return Stack(
      children: [
        // WebView
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(_htmlUri!)),
          initialSettings: InAppWebViewSettings(
            supportZoom: false,
            useOnLoadResource: false,
            useShouldOverrideUrlLoading: false,
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            iframeAllow: "camera; microphone",
            iframeAllowFullscreen: true,
            transparentBackground: true,
            disableContextMenu: !widget.enableInteraction,
            javaScriptEnabled: true,
            verticalScrollBarEnabled: false,
            horizontalScrollBarEnabled: false,
            disableHorizontalScroll: true,
            disableVerticalScroll: true,
            clearCache: false,
            cacheEnabled: true,
          ),
          onWebViewCreated: _onWebViewCreated,
          onLoadStop: _onLoadStop,
          onLoadError: (controller, url, code, message) {
            debugPrint('WebView加载错误: $code - $message');
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
                _errorMessage = 'WebView加载错误: $message';
              });
            }
          },
          onConsoleMessage: (controller, consoleMessage) {
            if (kDebugMode) {
              debugPrint('WebView控制台: ${consoleMessage.message}');
            }
          },
        ),
        
        // 加载指示器
        if (_isLoading) _buildLoadingWidget(),
        
        // 错误指示器
        if (_hasError) _buildErrorWidget(),
      ],
    );
  }

  /// 构建加载Widget
  Widget _buildLoadingWidget() {
    return Container(
      color: widget.config.backgroundColor != null 
          ? Color(int.parse(widget.config.backgroundColor!.replaceFirst('#', '0x')))
          : const Color(0xFFFFFBF0),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              '正在加载阅读器...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建错误Widget
  Widget _buildErrorWidget() {
    return Container(
      color: widget.config.backgroundColor != null 
          ? Color(int.parse(widget.config.backgroundColor!.replaceFirst('#', '0x')))
          : const Color(0xFFFFFBF0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.config.textColor != null 
                    ? Color(int.parse(widget.config.textColor!.replaceFirst('#', '0x')))
                    : const Color(0xFF2C2C2C),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.config.textColor != null 
                      ? Color(int.parse(widget.config.textColor!.replaceFirst('#', '0x')))
                      : const Color(0xFF2C2C2C),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _initializeWebView,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _webViewController = null;
    super.dispose();
  }
}

/// 阅读器控制器
class AdvancedTextReaderController {
  _AdvancedTextReaderWidgetState? _state;

  void _attach(_AdvancedTextReaderWidgetState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
  }

  /// 下一页
  Future<bool> nextPage() async {
    return await _state?.nextPage() ?? false;
  }

  /// 上一页
  Future<bool> prevPage() async {
    return await _state?.prevPage() ?? false;
  }

  /// 跳转到指定页面
  Future<bool> goToPage(int page) async {
    return await _state?.goToPage(page) ?? false;
  }

  /// 获取当前页面信息
  Future<PageInfo?> getCurrentPageInfo() async {
    return await _state?.getCurrentPageInfo();
  }

  /// 搜索文本
  Future<List<SearchResult>> searchText(String query) async {
    return await _state?.searchText(query) ?? [];
  }

  /// 更新配置
  Future<void> updateConfig(PaginationConfig config) async {
    await _state?.updateConfig(config);
  }
}

/// 带控制器的高级文本阅读器Widget
class ControlledAdvancedTextReaderWidget extends StatefulWidget {
  final String text;
  final PaginationConfig config;
  final AdvancedTextReaderController? controller;
  final VoidCallback? onReachStart;
  final VoidCallback? onReachEnd;
  final Function(PageInfo)? onPageChanged;
  final Function(int, int)? onMiddleClick;
  final Function(String)? onTextSelected;
  final bool enableInteraction;

  const ControlledAdvancedTextReaderWidget({
    Key? key,
    required this.text,
    required this.config,
    this.controller,
    this.onReachStart,
    this.onReachEnd,
    this.onPageChanged,
    this.onMiddleClick,
    this.onTextSelected,
    this.enableInteraction = true,
  }) : super(key: key);

  @override
  State<ControlledAdvancedTextReaderWidget> createState() => _ControlledAdvancedTextReaderWidgetState();
}

class _ControlledAdvancedTextReaderWidgetState extends State<ControlledAdvancedTextReaderWidget> {
  final GlobalKey<_AdvancedTextReaderWidgetState> _readerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(_readerKey.currentState!);
  }

  @override
  void didUpdateWidget(ControlledAdvancedTextReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(_readerKey.currentState!);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdvancedTextReaderWidget(
      key: _readerKey,
      text: widget.text,
      config: widget.config,
      onReachStart: widget.onReachStart,
      onReachEnd: widget.onReachEnd,
      onPageChanged: widget.onPageChanged,
      onMiddleClick: widget.onMiddleClick,
      onTextSelected: widget.onTextSelected,
      enableInteraction: widget.enableInteraction,
    );
  }
}
