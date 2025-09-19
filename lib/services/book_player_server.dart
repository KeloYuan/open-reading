import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';

/// 基于anx-reader架构的简化本地HTTP服务器
/// 为WebView提供书籍文件和foliate-js资源服务
class BookPlayerServer {
  static final BookPlayerServer _singleton = BookPlayerServer._internal();

  factory BookPlayerServer() {
    return _singleton;
  }

  BookPlayerServer._internal();

  HttpServer? _server;
  int _port = 8080;

  /// 启动服务器（简化版本，基于anx-reader）
  Future<void> start() async {
    // 防止重复启动
    if (_server != null) {
      print('BookPlayerServer: 服务器已在运行，端口: $_port');
      return;
    }

    var handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(_handleRequests);

    try {
      final prefs = await SharedPreferences.getInstance();
      _port = prefs.getInt('last_server_port') ?? 8080;

      try {
        _server = await io.serve(handler, '127.0.0.1', _port);
      } catch (e) {
        // 如果指定端口失败，让系统自动分配
        _server = await io.serve(handler, '127.0.0.1', 0);
        _port = _server!.port;
      }

      // 保存成功的端口
      await prefs.setInt('last_server_port', _port);
      print('BookPlayerServer: 服务器启动成功 http://127.0.0.1:$_port');
    } catch (e) {
      print('BookPlayerServer: 服务器启动失败: $e');
      rethrow;
    }
  }

  /// 获取服务器端口
  int get port => _port;

  /// 停止服务器
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      print('BookPlayerServer: 服务器已停止');
    }
  }

  /// 重启服务器
  Future<void> restart() async {
    print('BookPlayerServer: 正在重启服务器...');
    await stop();
    await Future.delayed(const Duration(milliseconds: 500)); // 等待端口释放
    await start();
  }

  /// 检查服务器是否正在运行
  bool get isRunning => _server != null;

  /// 从assets加载资源
  Future<String> _loadAsset(String path) async {
    return await rootBundle.loadString(path);
  }

  File? _tempFile;
  String? _tempFileName;

  /// 设置临时文件（用于测试）
  String setTempFile(File file) {
    _tempFile = file;
    _tempFileName = DateTime.timestamp().hashCode.toString();
    return _tempFileName!;
  }

  /// 处理HTTP请求（基于anx-reader简化版本）
  Future<shelf.Response> _handleRequests(shelf.Request request) async {
    final uriPath = request.requestedUri.path;
    print('BookPlayerServer: 请求路径 $uriPath');

    try {
      // 处理临时文件请求
      if (_tempFileName != null && uriPath == "/$_tempFileName") {
        return _handleTempFileRequest();
      }

      // 处理书籍文件请求
      if (uriPath.startsWith('/book/')) {
        return _handleBookRequest(request);
      }

      // 处理foliate-js资源请求
      if (uriPath.startsWith('/foliate-js/')) {
        return await _handleFoliateJsRequest(uriPath);
      }

      // 默认响应
      return shelf.Response.ok(
        'BookPlayerServer 运行中',
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      print('BookPlayerServer 错误: $e');
      return shelf.Response.internalServerError(
        body: '服务器内部错误: $e',
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }
  }

  /// 处理临时文件请求
  shelf.Response _handleTempFileRequest() {
    if (_tempFile == null || !_tempFile!.existsSync()) {
      return shelf.Response.notFound('临时文件未找到');
    }

    return shelf.Response.ok(
      _tempFile!.openRead(),
      headers: {
        'Content-Type': 'application/epub+zip',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      },
    );
  }

  /// 处理书籍文件请求（基于anx-reader简化版本）
  shelf.Response _handleBookRequest(shelf.Request request) {
    // 移除 '/book' 前缀(5个字符)，保留完整的文件路径
    final relativePath = request.url.path.substring(5);
    final bookPath = Uri.decodeComponent(relativePath);

    // 确保路径以 / 开头
    final fullBookPath = bookPath.startsWith('/') ? bookPath : '/$bookPath';
    final file = File(fullBookPath);

    print('BookPlayerServer: 请求路径: ${request.url.path}');
    print('BookPlayerServer: 解析后的文件路径: $fullBookPath');

    if (!file.existsSync()) {
      print('BookPlayerServer: 文件不存在: $fullBookPath');
      return shelf.Response.notFound('书籍文件未找到: $fullBookPath');
    }

    // 简化Content-Type设置，统一使用epub格式（参考anx-reader做法）
    // foliate-js内部会自动检测实际的文件格式
    String contentType = 'application/epub+zip';

    // switch语句已移除，使用统一的contentType

    final headers = {
      'Content-Type': contentType,
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    print('BookPlayerServer: 成功找到文件，返回内容');
    return shelf.Response.ok(file.openRead(), headers: headers);
  }

  /// 处理foliate-js资源请求（基于anx-reader简化版本）
  Future<shelf.Response> _handleFoliateJsRequest(String uriPath) async {
    try {
      final assetPath = 'assets$uriPath';
      final content = await _loadAsset(assetPath);

      String contentType = 'text/html';
      if (uriPath.endsWith('.js')) {
        contentType = 'application/javascript';
      } else if (uriPath.endsWith('.css')) {
        contentType = 'text/css';
      }

      return shelf.Response.ok(
        content,
        headers: {
          'Content-Type': contentType,
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      print('加载foliate-js资源失败: $uriPath, 错误: $e');
      return shelf.Response.notFound('资源未找到: $uriPath');
    }
  }

  /// 获取支持的书籍格式列表
  static List<String> getSupportedFormats() {
    return [
      'epub', // EPUB电子书
      'pdf', // PDF文档
      'mobi', // Kindle格式
      'azw', // Kindle格式
      'azw3', // Kindle格式
      'fb2', // FictionBook格式
      'txt', // 纯文本
      'html', // HTML文档
      'htm', // HTML文档
      'rtf', // 富文本格式
      'cbr', // 漫画格式
      'cbz', // 漫画格式
    ];
  }

  /// 检查文件格式是否受支持
  static bool isFormatSupported(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    return getSupportedFormats().contains(extension);
  }

  /// 获取格式的友好名称
  static String getFormatDisplayName(String extension) {
    switch (extension.toLowerCase()) {
      case 'epub':
        return 'EPUB 电子书';
      case 'pdf':
        return 'PDF 文档';
      case 'mobi':
      case 'azw':
      case 'azw3':
        return 'Kindle 电子书';
      case 'fb2':
        return 'FictionBook';
      case 'txt':
        return '纯文本';
      case 'html':
      case 'htm':
        return 'HTML 网页';
      case 'rtf':
        return '富文本格式';
      case 'cbr':
      case 'cbz':
        return '漫画书';
      default:
        return extension.toUpperCase();
    }
  }

  /// 生成WebView访问URL（基于anx-reader的方式）
  String generateUrl(
    String bookPath, {
    String? initialCfi,
    String? backgroundColor,
    String? textColor,
    double fontSize = 16.0,
    double lineHeight = 1.5,
  }) {
    try {
      final indexHtmlPath = "http://127.0.0.1:$_port/foliate-js/index.html";
      // 不需要编码bookPath，因为稍后在JSON编码时会自动处理
      final bookUrl = 'http://127.0.0.1:$_port/book$bookPath';

      // 完整样式对象，参考anx-reader实现
      // 注意：fontSize应该是相对值(em)，不是像素值！
      final style = {
        'fontSize': 1.4, // 使用anx-reader的默认值1.4em，而不是像素值
        'fontName': 'System',
        'fontPath': '',
        'fontWeight': 400,
        'letterSpacing': 0.0,
        'spacing': lineHeight,
        'paragraphSpacing': 1.0,
        'textIndent': 0,
        'fontColor': textColor ?? '#2c2c2c',
        'backgroundColor': backgroundColor ?? '#fffbf0',
        'topMargin': 90, // 参考anx-reader的默认值
        'bottomMargin': 50, // 参考anx-reader的默认值
        'sideMargin': 6, // 参考anx-reader的默认值
        'justify': true,
        'hyphenate': false,
        'pageTurnStyle': 'slide',
        'maxColumnCount': 0, // anx-reader默认值
        'writingMode': 'horizontal-tb',
        'textAlign': 'justify',
        'backgroundImage': '',
        'allowScript': false,
        'customCSS': '',
        'customCSSEnabled': false,
      };

      // 构建参数（模仿anx-reader的方式）
      final params = {
        'importing': false,
        'url': bookUrl,
        'initialCfi': initialCfi ?? '',
        'style': style,
        'readingRules': {
          'convertChineseMode': 'none',
          'bionicReadingMode': false,
        },
      };

      // 生成查询字符串
      String query = '';
      for (var key in params.keys) {
        if (query.isNotEmpty) query += '&';
        query += '$key=${Uri.encodeComponent(jsonEncode(params[key]))}';
      }

      final finalUrl = '$indexHtmlPath?$query';

      print('生成的WebView URL: $finalUrl');
      print('书籍路径: $bookPath');
      return finalUrl;
    } catch (e) {
      print('生成URL失败: $e');
      rethrow;
    }
  }
}
