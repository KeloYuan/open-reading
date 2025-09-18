# AI实现指南：自动获取书籍封面功能

## 概述

本文档详细说明如何实现一个自动从电子书文件中提取封面图片的功能。该功能基于Flutter框架，使用WebView加载JavaScript解析库来处理多种电子书格式。

## 系统架构

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Flutter App   │────│   Local Server   │────│  Book File      │
│                 │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │
         │              ┌──────────────────┐
         └──────────────│   HeadlessWebView │
                        │   (Foliate.js)    │
                        └──────────────────┘
                                 │
                        ┌──────────────────┐
                        │  Cover Extraction │
                        │   (Base64 Data)   │
                        └──────────────────┘
                                 │
                        ┌──────────────────┐
                        │  Local Storage   │
                        │  (Image Files)   │
                        └──────────────────┘
```

## 技术栈要求

### 必需依赖
- **Flutter**: ^3.0.0
- **flutter_inappwebview**: ^6.0.0 (用于WebView)
- **path_provider**: ^2.0.0 (文件路径管理)
- **shelf**: ^1.4.0 (本地HTTP服务器)

### 可选依赖
- **crypto**: ^3.0.0 (MD5校验)
- **flutter_riverpod**: ^2.0.0 (状态管理)

## 实现步骤

### 1. 项目结构设置

```
lib/
├── service/
│   ├── book.dart                    # 书籍服务主文件
│   └── book_player/
│       └── book_player_server.dart  # 本地HTTP服务器
├── utils/
│   ├── import_book.dart             # 封面保存工具
│   └── get_path/
│       └── get_base_path.dart       # 路径管理
├── models/
│   └── book.dart                    # 书籍数据模型
└── dao/
    └── book.dart                    # 数据库操作

assets/
└── foliate-js/                      # JavaScript解析库
    ├── src/
    │   ├── book.js                  # 主控制器
    │   ├── epub.js                  # EPUB格式处理
    │   ├── mobi.js                  # MOBI格式处理
    │   ├── comic-book.js            # CBZ/CBR格式处理
    │   └── fb2.js                   # FB2格式处理
    └── index.html                   # WebView入口页面
```

### 2. 核心组件实现

#### 2.1 本地HTTP服务器 (`lib/service/book_player/book_player_server.dart`)

```dart
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

class BookPlayerServer {
  HttpServer? _server;
  int _port = 8080;
  final Map<String, File> _tempFiles = {};

  // 启动服务器
  Future<void> start() async {
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_handleRequest);

    _server = await shelf_io.serve(handler, 'localhost', _port);
    print('Server running on localhost:${_server!.port}');
  }

  // 处理请求
  Response _handleRequest(Request request) {
    final path = request.url.path;
    
    if (path.startsWith('book/')) {
      return _handleBookRequest(request);
    }
    
    return Response.notFound('Not found');
  }

  // 处理书籍文件请求
  Response _handleBookRequest(Request request) {
    final bookPath = Uri.decodeComponent(request.url.path.substring(5));
    final file = _tempFiles[bookPath];
    
    if (file == null || !file.existsSync()) {
      return Response.notFound('Book not found');
    }

    final headers = {
      'Content-Type': _getContentType(file.path),
      'Access-Control-Allow-Origin': '*',
    };

    return Response.ok(file.openRead(), headers: headers);
  }

  // 设置临时文件
  String setTempFile(File file) {
    final fileName = 'temp_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    _tempFiles[fileName] = file;
    return fileName;
  }

  // 获取内容类型
  String _getContentType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'epub':
        return 'application/epub+zip';
      case 'mobi':
      case 'azw':
      case 'azw3':
        return 'application/x-mobipocket-ebook';
      case 'cbz':
        return 'application/vnd.comicbook+zip';
      case 'cbr':
        return 'application/vnd.comicbook-rar';
      case 'fb2':
        return 'application/x-fictionbook+xml';
      default:
        return 'application/octet-stream';
    }
  }

  // 停止服务器
  Future<void> stop() async {
    await _server?.close();
    _tempFiles.clear();
  }

  int get port => _server?.port ?? _port;
}
```

#### 2.2 书籍数据模型 (`lib/models/book.dart`)

```dart
import 'package:anx_reader/utils/get_path/get_base_path.dart';

class Book {
  int id;
  String title;
  String coverPath;        // 相对路径
  String filePath;         // 相对路径
  String author;
  String? description;
  String? md5;
  DateTime createTime;
  DateTime updateTime;

  Book({
    required this.id,
    required this.title,
    required this.coverPath,
    required this.filePath,
    required this.author,
    this.description,
    this.md5,
    required this.createTime,
    required this.updateTime,
  });

  // 获取封面完整路径
  String get coverFullPath => getBasePath(coverPath);
  
  // 获取文件完整路径
  String get fileFullPath => getBasePath(filePath);

  // 转换为Map用于数据库存储
  Map<String, Object?> toMap() {
    return {
      'title': title,
      'cover_path': coverPath,
      'file_path': filePath,
      'author': author,
      'description': description,
      'file_md5': md5,
      'create_time': createTime.toIso8601String(),
      'update_time': updateTime.toIso8601String(),
    };
  }

  // 从Map创建Book对象
  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'],
      coverPath: map['cover_path'],
      filePath: map['file_path'],
      author: map['author'],
      description: map['description'],
      md5: map['file_md5'],
      createTime: DateTime.parse(map['create_time']),
      updateTime: DateTime.parse(map['update_time']),
    );
  }
}
```

#### 2.3 封面保存工具 (`lib/utils/import_book.dart`)

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:anx_reader/utils/get_path/get_base_path.dart';

/// 将base64编码的图片保存到本地
/// 
/// [imageFile] base64编码的图片数据，格式：data:image/jpeg;base64,/9j/4AAQ...
/// [name] 文件名前缀
/// 
/// 返回保存后的相对路径
Future<String> saveImageToLocal(String? imageFile, String name) async {
  if (imageFile == null || imageFile.isEmpty) {
    return name;
  }

  try {
    // 1. 解析base64数据
    if (!imageFile.startsWith('data:image/')) {
      throw Exception('Invalid image data format');
    }

    final List<String> parts = imageFile.split(',');
    if (parts.length != 2) {
      throw Exception('Invalid base64 format');
    }

    // 2. 提取图片格式和base64数据
    final String mimeType = parts[0]; // data:image/jpeg;base64
    final String base64String = parts[1];
    
    // 提取图片扩展名
    final RegExp mimeRegex = RegExp(r'data:image/([^;]+)');
    final Match? match = mimeRegex.firstMatch(mimeType);
    String extension = match?.group(1) ?? 'png';
    
    // 处理特殊格式
    if (extension == 'jpeg') extension = 'jpg';

    // 3. 解码base64数据
    final Uint8List imageBytes = base64.decode(base64String);

    // 4. 生成保存路径
    final String fileName = '$name.$extension';
    final String fullPath = getBasePath(fileName);

    // 5. 确保目录存在
    final File file = File(fullPath);
    await file.parent.create(recursive: true);

    // 6. 保存文件
    await file.writeAsBytes(imageBytes);

    print('Cover saved: $fileName (${imageBytes.length} bytes)');
    return fileName;

  } catch (e) {
    print('Error saving cover image: $e');
    return name; // 返回原始名称作为fallback
  }
}

/// 验证图片文件是否有效
Future<bool> isValidImageFile(String filePath) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) return false;

    final bytes = await file.readAsBytes();
    if (bytes.length < 10) return false;

    // 检查文件头
    final header = bytes.take(10).toList();
    
    // JPEG: FF D8 FF
    if (header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF) return true;
    
    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47) return true;
    
    // GIF: 47 49 46 38
    if (header[0] == 0x47 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x38) return true;
    
    // WebP: 52 49 46 46 ... 57 45 42 50
    if (header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46 &&
        bytes.length > 12 && bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) return true;

    return false;
  } catch (e) {
    return false;
  }
}
```

#### 2.4 主要服务类 (`lib/service/book.dart`)

```dart
import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:anx_reader/models/book.dart';
import 'package:anx_reader/utils/import_book.dart';
import 'package:anx_reader/service/book_player/book_player_server.dart';

class BookService {
  static final BookService _instance = BookService._internal();
  factory BookService() => _instance;
  BookService._internal();

  final BookPlayerServer _server = BookPlayerServer();
  HeadlessInAppWebView? _webView;

  /// 初始化服务
  Future<void> initialize() async {
    await _server.start();
  }

  /// 销毁服务
  Future<void> dispose() async {
    await _webView?.dispose();
    await _server.stop();
  }

  /// 从书籍文件提取元数据和封面
  /// 
  /// [file] 书籍文件
  /// [onSuccess] 成功回调，返回提取的书籍信息
  /// [onError] 错误回调
  Future<void> extractBookMetadata(
    File file, {
    required Function(Book book) onSuccess,
    required Function(String error) onError,
  }) async {
    try {
      // 1. 验证文件
      if (!await file.exists()) {
        onError('文件不存在');
        return;
      }

      // 2. 设置临时文件
      final String serverFileName = _server.setTempFile(file);
      final String bookUrl = "http://localhost:${_server.port}/book/$serverFileName";

      // 3. 生成WebView URL
      final String webViewUrl = _generateWebViewUrl(bookUrl);

      // 4. 创建WebView
      _webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(webViewUrl)),
        onLoadStop: (controller, url) async {
          // 注册JavaScript回调
          await _registerJavaScriptHandlers(controller, file, onSuccess, onError);
        },
        onConsoleMessage: (controller, consoleMessage) {
          print('WebView Console: ${consoleMessage.message}');
          
          if (consoleMessage.messageLevel == ConsoleMessageLevel.ERROR) {
            onError('WebView错误: ${consoleMessage.message}');
          }
        },
        onLoadError: (controller, url, code, message) {
          onError('WebView加载错误: $message');
        },
      );

    } catch (e) {
      onError('提取元数据失败: $e');
    }
  }

  /// 生成WebView访问URL
  String _generateWebViewUrl(String bookUrl) {
    final Uri uri = Uri(
      scheme: 'http',
      host: 'localhost',
      port: _server.port,
      path: '/foliate-js/index.html',
      queryParameters: {
        'book': bookUrl,
        'importing': 'true',
      },
    );
    return uri.toString();
  }

  /// 注册JavaScript处理器
  Future<void> _registerJavaScriptHandlers(
    InAppWebViewController controller,
    File originalFile,
    Function(Book book) onSuccess,
    Function(String error) onError,
  ) async {
    // 注册元数据回调
    controller.addJavaScriptHandler(
      handlerName: 'onMetadata',
      callback: (args) async {
        try {
          await _handleMetadata(args[0], originalFile, onSuccess, onError);
        } catch (e) {
          onError('处理元数据失败: $e');
        }
      },
    );

    // 注册错误回调
    controller.addJavaScriptHandler(
      handlerName: 'onError',
      callback: (args) {
        onError('JavaScript错误: ${args[0]}');
      },
    );

    // 触发元数据提取
    await controller.evaluateJavascript(source: 'getMetadata()');
  }

  /// 处理提取的元数据
  Future<void> _handleMetadata(
    Map<String, dynamic> metadata,
    File originalFile,
    Function(Book book) onSuccess,
    Function(String error) onError,
  ) async {
    try {
      // 1. 提取基本信息
      final String title = metadata['title'] ?? 'Unknown';
      final String author = _extractAuthor(metadata['author']);
      final String description = metadata['description'] ?? '';
      final String? coverData = metadata['cover'];

      // 2. 生成文件名
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String sanitizedTitle = _sanitizeFileName(title);
      final String baseName = '$sanitizedTitle-$timestamp';

      // 3. 保存书籍文件
      final String extension = originalFile.path.split('.').last;
      final String bookFileName = 'file/$baseName.$extension';
      final String bookPath = getBasePath(bookFileName);
      
      await originalFile.copy(bookPath);

      // 4. 保存封面
      String coverFileName = 'cover/$baseName';
      if (coverData != null && coverData.isNotEmpty) {
        coverFileName = await saveImageToLocal(coverData, coverFileName);
      }

      // 5. 创建Book对象
      final book = Book(
        id: -1, // 数据库插入时会分配ID
        title: title,
        author: author,
        description: description.isNotEmpty ? description : null,
        coverPath: coverFileName,
        filePath: bookFileName,
        createTime: DateTime.now(),
        updateTime: DateTime.now(),
      );

      // 6. 清理
      await _webView?.dispose();
      _webView = null;

      onSuccess(book);

    } catch (e) {
      onError('保存书籍失败: $e');
    }
  }

  /// 提取作者信息
  String _extractAuthor(dynamic authorData) {
    if (authorData == null) return 'Unknown';
    
    if (authorData is String) {
      return authorData.isNotEmpty ? authorData : 'Unknown';
    }
    
    if (authorData is List) {
      final List<String> authors = authorData
          .map((author) => author is String ? author : (author['name'] ?? ''))
          .where((name) => name.isNotEmpty)
          .cast<String>()
          .toList();
      
      return authors.isNotEmpty ? authors.join(', ') : 'Unknown';
    }
    
    return 'Unknown';
  }

  /// 清理文件名中的非法字符
  String _sanitizeFileName(String fileName) {
    final String sanitized = fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .trim();
    
    return sanitized.length > 50 ? sanitized.substring(0, 50) : sanitized;
  }
}
```

### 3. JavaScript解析库配置

#### 3.1 主控制器 (`assets/foliate-js/src/book.js`)

```javascript
// 全局变量
let reader = null;
let book = null;

// Flutter通信桥接
const callFlutter = (method, data) => {
  if (window.flutter_inappwebview) {
    window.flutter_inappwebview.callHandler(method, data);
  }
};

// 获取元数据的主函数
const getMetadata = async () => {
  try {
    if (!reader || !reader.view || !reader.view.book) {
      throw new Error('Book not loaded');
    }

    const book = reader.view.book;
    const metadata = { ...book.metadata };

    // 提取封面
    const cover = await book.getCover();
    if (cover) {
      // 将Blob转换为base64
      const base64 = await blobToBase64(cover);
      metadata.cover = base64;
    } else {
      metadata.cover = null;
    }

    // 发送到Flutter
    callFlutter('onMetadata', metadata);

  } catch (error) {
    console.error('Failed to extract metadata:', error);
    callFlutter('onError', error.message);
  }
};

// Blob转base64工具函数
const blobToBase64 = (blob) => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => resolve(reader.result);
    reader.onerror = reject;
    reader.readAsDataURL(blob);
  });
};

// 书籍加载完成回调
const onBookLoaded = () => {
  console.log('Book loaded successfully');
  // 自动触发元数据提取
  setTimeout(getMetadata, 100);
};

// 错误处理
const onBookError = (error) => {
  console.error('Book loading error:', error);
  callFlutter('onError', error.message || 'Unknown error');
};

// 暴露给全局
window.getMetadata = getMetadata;
window.onBookLoaded = onBookLoaded;
window.onBookError = onBookError;
```

#### 3.2 入口HTML页面 (`assets/foliate-js/index.html`)

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Book Metadata Extractor</title>
    <style>
        body {
            margin: 0;
            padding: 20px;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f5f5;
        }
        .status {
            padding: 10px;
            border-radius: 4px;
            margin: 10px 0;
        }
        .loading { background: #e3f2fd; color: #1976d2; }
        .success { background: #e8f5e9; color: #388e3c; }
        .error { background: #ffebee; color: #d32f2f; }
    </style>
</head>
<body>
    <div id="status" class="status loading">正在加载书籍...</div>
    
    <!-- Foliate.js库文件 -->
    <script src="src/epub.js"></script>
    <script src="src/mobi.js"></script>
    <script src="src/comic-book.js"></script>
    <script src="src/fb2.js"></script>
    <script src="src/book.js"></script>

    <script>
        // 获取URL参数
        const urlParams = new URLSearchParams(window.location.search);
        const bookUrl = urlParams.get('book');
        const isImporting = urlParams.get('importing') === 'true';

        const statusEl = document.getElementById('status');

        const updateStatus = (message, type = 'loading') => {
            statusEl.textContent = message;
            statusEl.className = `status ${type}`;
        };

        const loadBook = async () => {
            try {
                if (!bookUrl) {
                    throw new Error('No book URL provided');
                }

                updateStatus('正在下载书籍文件...');

                // 获取书籍文件
                const response = await fetch(bookUrl);
                if (!response.ok) {
                    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
                }

                const blob = await response.blob();
                const file = new File([blob], bookUrl.split('/').pop() || 'book');

                updateStatus('正在解析书籍格式...');

                // 根据文件类型选择解析器
                const book = await createBookFromFile(file);
                
                updateStatus('正在初始化阅读器...');

                // 创建阅读器
                reader = createReader(book);
                
                updateStatus('正在提取元数据...', 'success');

                // 如果是导入模式，立即提取元数据
                if (isImporting) {
                    await getMetadata();
                }

            } catch (error) {
                console.error('加载失败:', error);
                updateStatus(`加载失败: ${error.message}`, 'error');
                window.onBookError?.(error);
            }
        };

        // 根据文件创建书籍对象
        const createBookFromFile = async (file) => {
            const { name, type } = file;
            
            // 判断文件类型
            if (name.endsWith('.epub') || type === 'application/epub+zip') {
                return await createEPUB(file);
            } else if (name.endsWith('.mobi') || name.endsWith('.azw') || name.endsWith('.azw3')) {
                return await createMOBI(file);
            } else if (name.endsWith('.cbz') || name.endsWith('.cbr')) {
                return await createComicBook(file);
            } else if (name.endsWith('.fb2')) {
                return await createFB2(file);
            } else {
                throw new Error(`不支持的文件格式: ${name}`);
            }
        };

        // 创建阅读器
        const createReader = (book) => {
            return {
                view: { book },
                toc: book.toc || []
            };
        };

        // 页面加载完成后开始加载书籍
        document.addEventListener('DOMContentLoaded', loadBook);
    </script>
</body>
</html>
```

### 4. 数据库操作 (`lib/dao/book.dart`)

```dart
import 'package:sqflite/sqflite.dart';
import 'package:anx_reader/models/book.dart';

class BookDao {
  static final BookDao _instance = BookDao._internal();
  factory BookDao() => _instance;
  BookDao._internal();

  Database? _database;

  /// 获取数据库实例
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    final String path = await getDatabasesPath();
    final String dbPath = '$path/books.db';

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _createTables,
    );
  }

  /// 创建数据表
  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tb_books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        description TEXT,
        cover_path TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_md5 TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        reading_percentage REAL NOT NULL DEFAULT 0.0,
        last_read_position TEXT NOT NULL DEFAULT '',
        rating REAL NOT NULL DEFAULT 0.0,
        group_id INTEGER NOT NULL DEFAULT 0,
        create_time TEXT NOT NULL,
        update_time TEXT NOT NULL
      )
    ''');

    // 创建索引
    await db.execute('CREATE INDEX idx_books_title ON tb_books(title)');
    await db.execute('CREATE INDEX idx_books_author ON tb_books(author)');
    await db.execute('CREATE INDEX idx_books_md5 ON tb_books(file_md5)');
  }

  /// 插入书籍
  Future<int> insertBook(Book book) async {
    final db = await database;
    final id = await db.insert('tb_books', book.toMap());
    return id;
  }

  /// 更新书籍
  Future<void> updateBook(Book book) async {
    final db = await database;
    await db.update(
      'tb_books',
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  /// 根据MD5查找书籍
  Future<Book?> getBookByMd5(String md5) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tb_books',
      where: 'file_md5 = ? AND is_deleted = 0',
      whereArgs: [md5],
    );

    if (maps.isEmpty) return null;
    return Book.fromMap(maps.first);
  }

  /// 查询所有书籍
  Future<List<Book>> getAllBooks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tb_books',
      where: 'is_deleted = 0',
      orderBy: 'update_time DESC',
    );

    return maps.map((map) => Book.fromMap(map)).toList();
  }

  /// 删除书籍（软删除）
  Future<void> deleteBook(int id) async {
    final db = await database;
    await db.update(
      'tb_books',
      {'is_deleted': 1, 'update_time': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
```

### 5. 使用示例

#### 5.1 在Flutter应用中使用

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:anx_reader/service/book.dart';
import 'package:anx_reader/dao/book.dart';
import 'package:anx_reader/models/book.dart';

class BookImportPage extends StatefulWidget {
  @override
  _BookImportPageState createState() => _BookImportPageState();
}

class _BookImportPageState extends State<BookImportPage> {
  final BookService _bookService = BookService();
  final BookDao _bookDao = BookDao();
  
  bool _isLoading = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _bookService.initialize();
  }

  @override
  void dispose() {
    _bookService.dispose();
    super.dispose();
  }

  /// 选择并导入书籍
  Future<void> _importBook() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'mobi', 'azw', 'azw3', 'cbz', 'cbr', 'fb2'],
      allowMultiple: false,
    );

    if (result == null) return;

    final File file = File(result.files.single.path!);
    
    setState(() {
      _isLoading = true;
      _status = '正在处理书籍...';
    });

    await _bookService.extractBookMetadata(
      file,
      onSuccess: (Book book) async {
        try {
          // 保存到数据库
          final int id = await _bookDao.insertBook(book);
          book.id = id;

          setState(() {
            _isLoading = false;
            _status = '导入成功！';
          });

          // 显示成功消息
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('《${book.title}》导入成功'),
              backgroundColor: Colors.green,
            ),
          );

          // 返回上一页或刷新列表
          Navigator.of(context).pop(book);

        } catch (e) {
          setState(() {
            _isLoading = false;
            _status = '保存失败: $e';
          });
        }
      },
      onError: (String error) {
        setState(() {
          _isLoading = false;
          _status = '导入失败: $error';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('导入书籍'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(_status),
                ],
              )
            else
              Column(
                children: [
                  Icon(
                    Icons.book,
                    size: 64,
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '选择书籍文件进行导入',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '支持 EPUB、MOBI、CBZ、FB2 等格式',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _importBook,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      child: Text('选择文件'),
                    ),
                  ),
                  if (_status.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text(
                      _status,
                      style: TextStyle(
                        color: _status.contains('失败') ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}
```

### 6. 错误处理和优化建议

#### 6.1 常见错误处理

```dart
class BookImportError {
  static const String UNSUPPORTED_FORMAT = 'UNSUPPORTED_FORMAT';
  static const String CORRUPTED_FILE = 'CORRUPTED_FILE';
  static const String NETWORK_ERROR = 'NETWORK_ERROR';
  static const String STORAGE_ERROR = 'STORAGE_ERROR';
  static const String WEBVIEW_ERROR = 'WEBVIEW_ERROR';

  static String getErrorMessage(String errorCode) {
    switch (errorCode) {
      case UNSUPPORTED_FORMAT:
        return '不支持的文件格式';
      case CORRUPTED_FILE:
        return '文件已损坏或格式错误';
      case NETWORK_ERROR:
        return '网络连接错误';
      case STORAGE_ERROR:
        return '存储空间不足或无权限';
      case WEBVIEW_ERROR:
        return 'WebView加载失败';
      default:
        return '未知错误';
    }
  }
}
```

#### 6.2 性能优化

1. **并发限制**：限制同时处理的书籍数量
2. **内存管理**：及时释放WebView资源
3. **缓存机制**：缓存已处理的书籍元数据
4. **文件验证**：提前验证文件格式避免无效处理

#### 6.3 测试用例

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:anx_reader/service/book.dart';
import 'package:anx_reader/utils/import_book.dart';

void main() {
  group('BookService Tests', () {
    late BookService bookService;

    setUp(() {
      bookService = BookService();
    });

    tearDown(() {
      bookService.dispose();
    });

    test('should extract metadata from EPUB file', () async {
      // 测试EPUB文件元数据提取
    });

    test('should handle corrupted files gracefully', () async {
      // 测试损坏文件的处理
    });

    test('should save cover image correctly', () async {
      const String testBase64 = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
      
      final String savedPath = await saveImageToLocal(testBase64, 'test_cover');
      expect(savedPath, contains('.png'));
    });
  });
}
```

## 部署注意事项

1. **权限配置**：确保应用有文件读写权限
2. **WebView配置**：配置适当的WebView安全策略
3. **存储管理**：定期清理临时文件和无效封面
4. **格式支持**：根据需要添加更多电子书格式支持

## 总结

这个实现方案提供了一个完整的、可扩展的书籍封面自动提取系统。通过组合使用Flutter的WebView能力和JavaScript解析库，可以支持多种电子书格式的封面提取，同时保持良好的性能和用户体验。

AI在实现时应注意：
1. 严格按照代码结构组织文件
2. 实现完整的错误处理机制
3. 确保内存和资源的正确管理
4. 添加适当的日志和调试信息
5. 考虑不同平台的兼容性问题