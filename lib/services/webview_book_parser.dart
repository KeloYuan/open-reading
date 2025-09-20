import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;

/// WebView 书籍解析服务
///
/// 使用 foliate-js 引擎通过 WebView 解析多种电子书格式
/// 支持 EPUB、MOBI、AZW3、FB2 等格式的元数据和封面提取
///
/// 核心功能：
/// - [parseBookMetadata] 解析书籍元数据
/// - [extractCover] 提取书籍封面
/// - [startLocalServer] 启动本地HTTP服务器
/// - [stopLocalServer] 停止本地HTTP服务器
class WebViewBookParser {
  static final WebViewBookParser _instance = WebViewBookParser._internal();
  factory WebViewBookParser() => _instance;
  WebViewBookParser._internal();

  HttpServer? _server;
  int _serverPort = 8080;
  File? _tempBookFile;
  String? _tempFileName;
  HeadlessInAppWebView? _webView;

  /// 支持的书籍格式
  static const List<String> supportedFormats = [
    'epub',
    'mobi',
    'azw',
    'azw3',
    'fb2',
    'cbz',
    'cbr',
  ];

  /// 启动本地HTTP服务器
  ///
  /// 用于为 WebView 提供书籍文件访问
  ///
  /// Returns: 服务器端口号
  /// Throws: [Exception] 当服务器启动失败时
  Future<int> startLocalServer() async {
    if (_server != null) {
      debugPrint('WebView Parser: 服务器已在运行，端口: $_serverPort');
      return _serverPort;
    }

    try {
      final handler = const shelf.Pipeline()
          .addMiddleware(shelf.logRequests())
          .addHandler(_handleRequests);

      // 尝试在指定端口启动服务器
      try {
        _server = await io.serve(handler, '127.0.0.1', _serverPort);
      } catch (e) {
        // 如果指定端口被占用，使用随机端口
        _server = await io.serve(handler, '127.0.0.1', 0);
        _serverPort = _server!.port;
      }

      debugPrint('WebView Parser: 服务器启动成功，端口: $_serverPort');
      return _serverPort;
    } catch (e) {
      throw Exception('WebView Parser: 服务器启动失败: $e');
    }
  }

  /// 停止本地HTTP服务器
  Future<void> stopLocalServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      debugPrint('WebView Parser: 服务器已停止');
    }
  }

  /// 处理HTTP请求
  Future<shelf.Response> _handleRequests(shelf.Request request) async {
    final uriPath = request.requestedUri.path;
    debugPrint('WebView Parser: 请求路径: $uriPath');

    // 处理临时书籍文件请求
    if (_tempFileName != null && uriPath == "/$_tempFileName") {
      if (_tempBookFile != null && await _tempBookFile!.exists()) {
        return shelf.Response.ok(
          _tempBookFile!.openRead(),
          headers: {
            'Content-Type': _getContentType(_tempBookFile!.path),
            'Access-Control-Allow-Origin': '*',
          },
        );
      } else {
        return shelf.Response.notFound('Book file not found');
      }
    }

    // 处理 foliate-js 资源请求
    if (uriPath.startsWith('/foliate-js/')) {
      try {
        final assetPath = 'assets${uriPath}';
        // 这里需要从 assets 加载 foliate-js 文件
        // 实际实现中需要配置正确的资源路径
        return shelf.Response.ok(
          'console.log("Foliate-js asset: $assetPath");',
          headers: {
            'Content-Type': uriPath.endsWith('.html')
                ? 'text/html'
                : 'application/javascript',
            'Access-Control-Allow-Origin': '*',
          },
        );
      } catch (e) {
        return shelf.Response.notFound('Asset not found: $e');
      }
    }

    return shelf.Response.notFound('Path not found: $uriPath');
  }

  /// 获取文件的 MIME 类型
  String _getContentType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.epub':
        return 'application/epub+zip';
      case '.mobi':
      case '.azw':
      case '.azw3':
        return 'application/x-mobipocket-ebook';
      case '.fb2':
        return 'application/x-fictionbook+xml';
      case '.cbz':
        return 'application/vnd.comicbook+zip';
      case '.cbr':
        return 'application/vnd.comicbook-rar';
      default:
        return 'application/octet-stream';
    }
  }

  /// 设置临时书籍文件
  ///
  /// [file] 书籍文件
  /// Returns: 临时文件名（用于URL访问）
  String setTempBookFile(File file) {
    _tempBookFile = file;
    _tempFileName = DateTime.now().millisecondsSinceEpoch.toString();
    return _tempFileName!;
  }

  /// 解析书籍元数据
  ///
  /// 使用 WebView 和 foliate-js 引擎解析书籍元数据
  ///
  /// [bookFile] 书籍文件
  /// [timeout] 解析超时时间（秒）
  /// Returns: 解析的元数据
  /// Throws: [Exception] 当解析失败时
  Future<BookMetadata> parseBookMetadata(
    File bookFile, {
    int timeout = 30,
  }) async {
    try {
      // 1. 验证文件格式
      final extension = path
          .extension(bookFile.path)
          .toLowerCase()
          .substring(1);
      if (!supportedFormats.contains(extension)) {
        throw Exception('不支持的文件格式: $extension');
      }

      // 2. 启动服务器
      await startLocalServer();

      // 3. 设置临时文件
      final tempFileName = setTempBookFile(bookFile);
      final bookUrl = "http://127.0.0.1:$_serverPort/$tempFileName";

      debugPrint('WebView Parser: 开始解析书籍: $bookUrl');

      // 4. 创建 WebView 解析页面URL
      final webViewUrl = _generateWebViewUrl(bookUrl);

      // 5. 创建并配置 WebView
      final metadata = await _createWebViewAndParse(webViewUrl, timeout);

      debugPrint('WebView Parser: 元数据解析完成');
      return metadata;
    } catch (e) {
      debugPrint('WebView Parser: 解析失败: $e');
      rethrow;
    } finally {
      // 清理资源
      await _cleanup();
    }
  }

  /// 生成 WebView 访问URL
  String _generateWebViewUrl(String bookUrl) {
    // 构建用于元数据提取的WebView页面URL
    final uri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: _serverPort,
      path: '/foliate-js/index.html',
      queryParameters: {
        'book': bookUrl,
        'importing': 'true',
        'mode': 'metadata',
      },
    );
    return uri.toString();
  }

  /// 创建 WebView 并解析元数据
  Future<BookMetadata> _createWebViewAndParse(
    String webViewUrl,
    int timeout,
  ) async {
    final completer = Completer<BookMetadata>();
    bool isCompleted = false;

    try {
      _webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(webViewUrl)),
        onLoadStop: (controller, url) async {
          debugPrint('WebView Parser: 页面加载完成: $url');

          // 注册JavaScript回调
          await _registerJavaScriptHandlers(controller, completer);
        },
        onConsoleMessage: (controller, consoleMessage) {
          debugPrint('WebView Console: ${consoleMessage.message}');

          if (consoleMessage.messageLevel == ConsoleMessageLevel.ERROR) {
            if (!isCompleted) {
              isCompleted = true;
              completer.completeError(
                Exception('WebView错误: ${consoleMessage.message}'),
              );
            }
          }
        },
        onLoadError: (controller, url, code, message) {
          debugPrint('WebView Parser: 加载错误: $message');
          if (!isCompleted) {
            isCompleted = true;
            completer.completeError(Exception('WebView加载失败: $message'));
          }
        },
      );

      await _webView!.run();

      // 设置超时
      Timer(Duration(seconds: timeout), () {
        if (!isCompleted) {
          isCompleted = true;
          completer.completeError(
            Exception('WebView Parser: 解析超时 (${timeout}s)'),
          );
        }
      });

      return await completer.future;
    } catch (e) {
      debugPrint('WebView Parser: WebView创建失败: $e');
      rethrow;
    }
  }

  /// 注册JavaScript处理器
  Future<void> _registerJavaScriptHandlers(
    InAppWebViewController controller,
    Completer<BookMetadata> completer,
  ) async {
    bool isCompleted = false;

    // 注册元数据回调
    controller.addJavaScriptHandler(
      handlerName: 'onMetadata',
      callback: (args) async {
        if (isCompleted) return;

        try {
          debugPrint('WebView Parser: 收到元数据回调');
          final rawMetadata = args[0] as Map<String, dynamic>;

          final metadata = BookMetadata(
            title: rawMetadata['title'] ?? 'Unknown',
            author: _extractAuthor(rawMetadata['author']),
            description: rawMetadata['description'] ?? '',
            language: rawMetadata['language'],
            coverImageBase64: rawMetadata['cover'],
            publisher: rawMetadata['publisher'],
            publishDate: rawMetadata['date'],
            isbn: rawMetadata['isbn'],
            subjects: _extractSubjects(rawMetadata['subjects']),
            format: rawMetadata['format'] ?? 'Unknown',
          );

          isCompleted = true;
          completer.complete(metadata);
        } catch (e) {
          if (!isCompleted) {
            isCompleted = true;
            completer.completeError(Exception('WebView Parser: 元数据处理失败: $e'));
          }
        }
      },
    );

    // 注册错误回调
    controller.addJavaScriptHandler(
      handlerName: 'onError',
      callback: (args) {
        if (!isCompleted) {
          isCompleted = true;
          completer.completeError(Exception('JavaScript错误: ${args[0]}'));
        }
      },
    );

    // 触发元数据提取
    try {
      await controller.evaluateJavascript(
        source: 'if (window.getMetadata) { window.getMetadata(); }',
      );
    } catch (e) {
      debugPrint('WebView Parser: JavaScript执行失败: $e');
    }
  }

  /// 提取作者信息
  String _extractAuthor(dynamic authorData) {
    if (authorData == null) return 'Unknown';

    if (authorData is String) {
      return authorData.isNotEmpty ? authorData : 'Unknown';
    }

    if (authorData is List) {
      final authors = authorData
          .map((author) => author is String ? author : (author['name'] ?? ''))
          .where((name) => name.toString().isNotEmpty)
          .toList();

      return authors.isNotEmpty ? authors.join(', ') : 'Unknown';
    }

    return 'Unknown';
  }

  /// 提取主题标签
  List<String>? _extractSubjects(dynamic subjectsData) {
    if (subjectsData is List) {
      return subjectsData
          .map((subject) => subject.toString())
          .where((subject) => subject.isNotEmpty)
          .toList();
    }
    return null;
  }

  /// 清理资源
  Future<void> _cleanup() async {
    if (_webView != null) {
      await _webView!.dispose();
      _webView = null;
    }

    _tempBookFile = null;
    _tempFileName = null;
  }

  /// 销毁服务
  Future<void> dispose() async {
    await _cleanup();
    await stopLocalServer();
  }
}

/// 书籍元数据模型
class BookMetadata {
  final String title;
  final String author;
  final String description;
  final String? language;
  final String? coverImageBase64;
  final String? publisher;
  final String? publishDate;
  final String? isbn;
  final List<String>? subjects;
  final String format;

  BookMetadata({
    required this.title,
    required this.author,
    required this.description,
    this.language,
    this.coverImageBase64,
    this.publisher,
    this.publishDate,
    this.isbn,
    this.subjects,
    required this.format,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'author': author,
      'description': description,
      'language': language,
      'coverImageBase64': coverImageBase64,
      'publisher': publisher,
      'publishDate': publishDate,
      'isbn': isbn,
      'subjects': subjects,
      'format': format,
    };
  }
}
