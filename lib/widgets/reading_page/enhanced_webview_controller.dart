import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../models/book.dart';
import '../../models/chapter.dart';

/// 增强的WebView控制器
/// 集成anx-reader的JavaScript交互功能
class EnhancedWebViewController {
  InAppWebViewController? _controller;
  final Book book;
  
  // 状态回调
  final ValueChanged<String>? onCfiChanged;
  final ValueChanged<double>? onProgressChanged;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<String>? onChapterChanged;
  final ValueChanged<bool>? onBookmarkChanged;
  final Function(String text, String cfi, Offset position)? onTextSelected;
  final VoidCallback? onLoadComplete;
  final Function(String error)? onError;

  // 当前状态
  String _currentCfi = '';
  double _currentProgress = 0.0;
  int _currentPage = 1;
  int _totalPages = 1;
  String _chapterTitle = '';
  bool _bookmarkExists = false;
  List<Chapter> _chapters = [];
  
  EnhancedWebViewController({
    required this.book,
    this.onCfiChanged,
    this.onProgressChanged,
    this.onPageChanged,
    this.onChapterChanged,
    this.onBookmarkChanged,
    this.onTextSelected,
    this.onLoadComplete,
    this.onError,
  });

  // Getters
  String get currentCfi => _currentCfi;
  double get currentProgress => _currentProgress;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  String get chapterTitle => _chapterTitle;
  bool get bookmarkExists => _bookmarkExists;
  List<Chapter> get chapters => _chapters;

  /// 初始化WebView控制器
  void initialize(InAppWebViewController controller) {
    _controller = controller;
    _setupJavaScriptHandlers();
  }

  /// 设置JavaScript处理器
  void _setupJavaScriptHandlers() {
    if (_controller == null) return;

    // 位置更新处理
    _controller!.addJavaScriptHandler(
      handlerName: 'onLocation',
      callback: (args) {
        final Map<String, dynamic> location = args[0];
        _updateLocation(location);
      },
    );

    // 文本选择处理
    _controller!.addJavaScriptHandler(
      handlerName: 'onSelectionEnd',
      callback: (args) {
        final Map<String, dynamic> selection = args[0];
        _handleTextSelection(selection);
      },
    );

    // 目录设置处理
    _controller!.addJavaScriptHandler(
      handlerName: 'onSetToc',
      callback: (args) {
        final List<dynamic> tocData = args[0];
        _updateToc(tocData);
      },
    );

    // 书签点击处理
    _controller!.addJavaScriptHandler(
      handlerName: 'onAnnotationClick',
      callback: (args) {
        final Map<String, dynamic> annotation = args[0];
        _handleAnnotationClick(annotation);
      },
    );

    // 加载完成处理
    _controller!.addJavaScriptHandler(
      handlerName: 'onLoadEnd',
      callback: (args) {
        onLoadComplete?.call();
      },
    );

    // 错误处理
    _controller!.addJavaScriptHandler(
      handlerName: 'onError',
      callback: (args) {
        final String error = args[0];
        onError?.call(error);
      },
    );
  }

  /// 更新位置信息
  void _updateLocation(Map<String, dynamic> location) {
    _currentCfi = location['cfi'] ?? '';
    _currentProgress = (location['fraction'] ?? 0.0).toDouble();
    _currentPage = location['current'] ?? 1;
    _totalPages = location['total'] ?? 1;
    _chapterTitle = location['chapter'] ?? '';
    
    // 书签状态
    if (location['bookmark'] != null) {
      _bookmarkExists = location['bookmark']['exists'] ?? false;
    }

    // 触发回调
    onCfiChanged?.call(_currentCfi);
    onProgressChanged?.call(_currentProgress);
    onPageChanged?.call(_currentPage);
    onChapterChanged?.call(_chapterTitle);
    onBookmarkChanged?.call(_bookmarkExists);
  }

  /// 处理文本选择
  void _handleTextSelection(Map<String, dynamic> selection) {
    final String cfi = selection['cfi'] ?? '';
    final String text = selection['text'] ?? '';
    final Map<String, dynamic> pos = selection['pos'] ?? {};
    final double x = (pos['point']?['x'] ?? 0.0).toDouble();
    final double y = (pos['point']?['y'] ?? 0.0).toDouble();
    
    onTextSelected?.call(text, cfi, Offset(x, y));
  }

  /// 更新目录
  void _updateToc(List<dynamic> tocData) {
    _chapters = tocData.map((item) {
      return Chapter(
        id: item['id'] ?? 0,
        title: item['label'] ?? '',
        href: item['href'] ?? '',
        level: item['level'] ?? 0,
        anchor: item['anchor'] ?? '',
        startPage: item['startPage'] ?? 0,
      );
    }).toList();
  }

  /// 处理注释点击
  void _handleAnnotationClick(Map<String, dynamic> annotation) {
    // 处理书签、高亮等注释的点击
    // 可以在这里处理注释的编辑、删除等操作
    debugPrint('Annotation clicked: ${annotation.toString()}');
  }

  /// 加载书籍
  Future<void> loadBook({String? initialCfi}) async {
    if (_controller == null) return;

    try {
      final String bookPath = book.filePath;
      final String loadScript = '''
        if (window.loadBook) {
          window.loadBook('$bookPath', ${initialCfi != null ? "'$initialCfi'" : 'null'});
        }
      ''';
      
      await _controller!.evaluateJavascript(source: loadScript);
    } catch (e) {
      onError?.call('加载书籍失败: $e');
    }
  }

  /// 下一页
  Future<void> nextPage() async {
    if (_controller == null) return;
    
    try {
      await _controller!.evaluateJavascript(source: '''
        if (window.reader && window.reader.next) {
          window.reader.next();
        }
      ''');
    } catch (e) {
      print('翻页失败: $e');
    }
  }

  /// 上一页  
  Future<void> prevPage() async {
    if (_controller == null) return;
    
    try {
      await _controller!.evaluateJavascript(source: '''
        if (window.reader && window.reader.prev) {
          window.reader.prev();
        }
      ''');
    } catch (e) {
      print('翻页失败: $e');
    }
  }

  /// 跳转到CFI位置
  Future<void> goToCfi(String cfi) async {
    if (_controller == null) return;
    
    try {
      await _controller!.evaluateJavascript(source: '''
        if (window.reader && window.reader.goto) {
          window.reader.goto('$cfi');
        }
      ''');
    } catch (e) {
      print('跳转失败: $e');
    }
  }

  /// 跳转到页面
  Future<void> goToPage(int page) async {
    if (_controller == null) return;
    
    try {
      await _controller!.evaluateJavascript(source: '''
        if (window.reader && window.reader.goToPage) {
          window.reader.goToPage($page);
        }
      ''');
    } catch (e) {
      print('跳转失败: $e');
    }
  }

  /// 添加书签
  Future<void> addBookmark({String? note}) async {
    if (_controller == null) return;
    
    try {
      final String noteParam = note != null ? "'$note'" : 'null';
      await _controller!.evaluateJavascript(source: '''
        if (window.reader && window.reader.addBookmark) {
          window.reader.addBookmark($_currentCfi, $noteParam);
        }
      ''');
    } catch (e) {
      print('添加书签失败: $e');
    }
  }

  /// 删除书签
  Future<void> removeBookmark(String cfi) async {
    if (_controller == null) return;
    
    try {
      await _controller!.evaluateJavascript(source: '''
        if (window.reader && window.reader.removeAnnotation) {
          window.reader.removeAnnotation('$cfi');
        }
      ''');
    } catch (e) {
      print('删除书签失败: $e');
    }
  }

  /// 添加高亮
  Future<void> addHighlight(String cfi, String color, {String? note}) async {
    if (_controller == null) return;
    
    try {
      final String noteParam = note != null ? "'$note'" : 'null';
      await _controller!.evaluateJavascript(source: '''
        if (window.reader && window.reader.addHighlight) {
          window.reader.addHighlight('$cfi', '$color', $noteParam);
        }
      ''');
    } catch (e) {
      print('添加高亮失败: $e');
    }
  }

  /// 删除高亮
  Future<void> removeHighlight(String cfi) async {
    if (_controller == null) return;
    
    try {
      await _controller!.evaluateJavascript(source: '''
        if (window.reader && window.reader.removeAnnotation) {
          window.reader.removeAnnotation('$cfi');
        }
      ''');
    } catch (e) {
      print('删除高亮失败: $e');
    }
  }

  /// 搜索文本
  Future<void> searchText(String query) async {
    if (_controller == null) return;
    
    try {
      await _controller!.evaluateJavascript(source: '''
        if (window.reader && window.reader.search) {
          window.reader.search('$query');
        }
      ''');
    } catch (e) {
      print('搜索失败: $e');
    }
  }

  /// 设置主题
  Future<void> setTheme(Map<String, dynamic> theme) async {
    if (_controller == null) return;
    
    try {
      final String themeJson = jsonEncode(theme);
      await _controller!.evaluateJavascript(source: '''
        if (window.reader && window.reader.setTheme) {
          window.reader.setTheme($themeJson);
        }
      ''');
    } catch (e) {
      print('设置主题失败: $e');
    }
  }

  /// 设置字体大小
  Future<void> setFontSize(double fontSize) async {
    if (_controller == null) return;
    
    try {
      await _controller!.evaluateJavascript(source: '''
        if (window.reader && window.reader.setFontSize) {
          window.reader.setFontSize($fontSize);
        }
      ''');
    } catch (e) {
      print('设置字体大小失败: $e');
    }
  }

  /// 获取当前章节内容（用于TTS）
  Future<String> getCurrentChapterText() async {
    if (_controller == null) return '';
    
    try {
      final result = await _controller!.evaluateJavascript(source: '''
        if (window.reader && window.reader.getCurrentText) {
          window.reader.getCurrentText();
        } else {
          '';
        }
      ''');
      return result?.toString() ?? '';
    } catch (e) {
      print('获取章节内容失败: $e');
      return '';
    }
  }

  /// 保存阅读进度
  Future<void> saveProgress() async {
    // 这里可以调用数据库保存当前进度
    print('保存进度: CFI=$_currentCfi, Progress=$_currentProgress');
  }

  /// 释放资源
  void dispose() {
    _controller = null;
  }
}
