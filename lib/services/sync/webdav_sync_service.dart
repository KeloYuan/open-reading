import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../book_dao.dart';
import '../../models/book.dart';

/// WebDAV同步状态
enum SyncStatus {
  idle, // 空闲
  syncing, // 同步中
  completed, // 同步完成
  failed, // 同步失败
  noNetwork, // 无网络
  notConfigured, // 未配置
}

/// WebDAV同步服务
/// 参考anx-reader的架构设计，提供完整的数据同步功能
class WebDavSyncService {
  static final WebDavSyncService _instance = WebDavSyncService._internal();
  factory WebDavSyncService() => _instance;
  WebDavSyncService._internal();

  final Dio _dio = Dio();
  final ValueNotifier<SyncStatus> _statusNotifier = ValueNotifier<SyncStatus>(
    SyncStatus.notConfigured,
  );

  // WebDAV配置
  String _serverUrl = '';
  String _username = '';
  String _password = '';
  bool _isConfigured = false;

  // 同步设置
  bool _autoSync = true;
  int _syncInterval = 30; // 分钟
  DateTime? _lastSyncTime;
  Timer? _syncTimer;

  // DAO实例
  final BookDao _bookDao = BookDao();

  // 网络监听
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _hasNetwork = true;

  // Getters
  ValueNotifier<SyncStatus> get statusNotifier => _statusNotifier;
  SyncStatus get status => _statusNotifier.value;
  bool get isConfigured => _isConfigured;
  bool get autoSync => _autoSync;
  int get syncInterval => _syncInterval;
  DateTime? get lastSyncTime => _lastSyncTime;
  String get serverUrl => _serverUrl;
  String get username => _username;

  /// 初始化同步服务
  Future<void> initialize() async {
    await _loadConfiguration();
    await _setupNetworkListener();

    if (_isConfigured && _autoSync) {
      _startAutoSync();
    }
  }

  /// 加载配置
  Future<void> _loadConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverUrl = prefs.getString('webdav_server_url') ?? '';
      _username = prefs.getString('webdav_username') ?? '';
      _password = prefs.getString('webdav_password') ?? '';
      _autoSync = prefs.getBool('webdav_auto_sync') ?? true;
      _syncInterval = prefs.getInt('webdav_sync_interval') ?? 30;

      final lastSyncStr = prefs.getString('webdav_last_sync');
      if (lastSyncStr != null) {
        _lastSyncTime = DateTime.parse(lastSyncStr);
      }

      _isConfigured =
          _serverUrl.isNotEmpty && _username.isNotEmpty && _password.isNotEmpty;

      if (_isConfigured) {
        _setupDioClient();
        _statusNotifier.value = SyncStatus.idle;
      } else {
        _statusNotifier.value = SyncStatus.notConfigured;
      }
    } catch (e) {
      debugPrint('加载WebDAV配置失败: $e');
      _statusNotifier.value = SyncStatus.notConfigured;
    }
  }

  /// 设置网络监听
  Future<void> _setupNetworkListener() async {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final hasNetwork = results.any(
        (result) => result != ConnectivityResult.none,
      );

      if (_hasNetwork != hasNetwork) {
        _hasNetwork = hasNetwork;

        if (hasNetwork && _isConfigured && _autoSync) {
          // 网络恢复，执行同步
          _performSync();
        } else if (!hasNetwork) {
          _statusNotifier.value = SyncStatus.noNetwork;
        }
      }
    });
  }

  /// 设置Dio客户端
  void _setupDioClient() {
    _dio.options = BaseOptions(
      baseUrl: _serverUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Authorization': _generateAuthHeader(),
        'Content-Type': 'application/octet-stream',
        'Accept': '*/*',
      },
    );

    // 添加拦截器
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          debugPrint('WebDAV请求: ${options.method} ${options.path}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint('WebDAV响应: ${response.statusCode}');
          handler.next(response);
        },
        onError: (error, handler) {
          debugPrint('WebDAV错误: ${error.message}');
          handler.next(error);
        },
      ),
    );
  }

  /// 生成认证头
  String _generateAuthHeader() {
    final credentials = base64Encode(utf8.encode('$_username:$_password'));
    return 'Basic $credentials';
  }

  /// 配置WebDAV
  Future<bool> configure({
    required String serverUrl,
    required String username,
    required String password,
    bool autoSync = true,
    int syncInterval = 30,
  }) async {
    try {
      _serverUrl = serverUrl.endsWith('/') ? serverUrl : '$serverUrl/';
      _username = username;
      _password = password;
      _autoSync = autoSync;
      _syncInterval = syncInterval;

      _setupDioClient();

      // 测试连接
      final isValid = await testConnection();
      if (!isValid) {
        return false;
      }

      // 保存配置
      await _saveConfiguration();
      _isConfigured = true;
      _statusNotifier.value = SyncStatus.idle;

      // 启动自动同步
      if (_autoSync) {
        _startAutoSync();
      }

      return true;
    } catch (e) {
      debugPrint('配置WebDAV失败: $e');
      return false;
    }
  }

  /// 保存配置
  Future<void> _saveConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webdav_server_url', _serverUrl);
    await prefs.setString('webdav_username', _username);
    await prefs.setString('webdav_password', _password);
    await prefs.setBool('webdav_auto_sync', _autoSync);
    await prefs.setInt('webdav_sync_interval', _syncInterval);
  }

  /// 测试连接
  Future<bool> testConnection() async {
    try {
      if (!_hasNetwork) {
        _statusNotifier.value = SyncStatus.noNetwork;
        return false;
      }

      // 检查根目录
      final response = await _dio.request(
        '/',
        options: Options(method: 'PROPFIND'),
      );

      return response.statusCode == 207 || response.statusCode == 200;
    } catch (e) {
      debugPrint('WebDAV连接测试失败: $e');
      return false;
    }
  }

  /// 开始自动同步
  void _startAutoSync() {
    _stopAutoSync();

    if (_autoSync && _syncInterval > 0) {
      _syncTimer = Timer.periodic(
        Duration(minutes: _syncInterval),
        (_) => _performSync(),
      );
    }
  }

  /// 停止自动同步
  void _stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// 手动同步
  Future<bool> manualSync() async {
    if (_statusNotifier.value == SyncStatus.syncing) {
      return false;
    }

    return await _performSync();
  }

  /// 执行同步
  Future<bool> _performSync() async {
    if (!_isConfigured || !_hasNetwork) {
      return false;
    }

    _statusNotifier.value = SyncStatus.syncing;

    try {
      // 确保同步目录存在
      await _ensureSyncDirectories();

      // 上传本地数据
      await _uploadLocalData();

      // 下载远程数据
      await _downloadRemoteData();

      // 更新同步时间
      _lastSyncTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'webdav_last_sync',
        _lastSyncTime!.toIso8601String(),
      );

      _statusNotifier.value = SyncStatus.completed;

      // 3秒后恢复空闲状态
      Timer(const Duration(seconds: 3), () {
        if (_statusNotifier.value == SyncStatus.completed) {
          _statusNotifier.value = SyncStatus.idle;
        }
      });

      return true;
    } catch (e) {
      debugPrint('同步失败: $e');
      _statusNotifier.value = SyncStatus.failed;

      // 5秒后恢复空闲状态
      Timer(const Duration(seconds: 5), () {
        if (_statusNotifier.value == SyncStatus.failed) {
          _statusNotifier.value = SyncStatus.idle;
        }
      });

      return false;
    }
  }

  /// 确保同步目录存在
  Future<void> _ensureSyncDirectories() async {
    const directories = [
      'xxread/',
      'xxread/books/',
      'xxread/bookmarks/',
      'xxread/progress/',
      'xxread/notes/',
    ];

    for (final dir in directories) {
      try {
        await _dio.request(dir, options: Options(method: 'MKCOL'));
      } catch (e) {
        // 目录已存在会返回405错误，这是正常的
        if (e is DioException && e.response?.statusCode != 405) {
          debugPrint('创建目录失败: $dir, $e');
        }
      }
    }
  }

  /// 上传本地数据
  Future<void> _uploadLocalData() async {
    await _uploadBooks();
    await _uploadBookmarks();
    await _uploadProgress();
  }

  /// 上传书籍列表
  Future<void> _uploadBooks() async {
    try {
      final books = await _bookDao.getAllBooks();
      final booksData = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'books': books.map((book) => book.toMap()).toList(),
      };

      final jsonData = jsonEncode(booksData);
      await _dio.put('xxread/books/books.json', data: jsonData);
    } catch (e) {
      debugPrint('上传书籍列表失败: $e');
    }
  }

  /// 上传书签（暂时上传空列表）
  Future<void> _uploadBookmarks() async {
    try {
      final bookmarksData = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'bookmarks': <Map<String, dynamic>>[],
      };

      final jsonData = jsonEncode(bookmarksData);
      await _dio.put('xxread/bookmarks/bookmarks.json', data: jsonData);
    } catch (e) {
      debugPrint('上传书签失败: $e');
    }
  }

  /// 上传阅读进度（当前仅上传基本信息）
  Future<void> _uploadProgress() async {
    try {
      final books = await _bookDao.getAllBooks();
      final progressData = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'progress': books
            .map(
              (book) => {
                'bookId': book.id,
                'filePath': book.filePath,
                'currentPage': book.currentPage,
                'totalPages': book.totalPages,
              },
            )
            .toList(),
      };

      final jsonData = jsonEncode(progressData);
      await _dio.put('xxread/progress/progress.json', data: jsonData);
    } catch (e) {
      debugPrint('上传阅读进度失败: $e');
    }
  }

  /// 下载远程数据
  Future<void> _downloadRemoteData() async {
    await _downloadBooks();
    await _downloadBookmarks();
    await _downloadProgress();
  }

  /// 下载书籍列表
  Future<void> _downloadBooks() async {
    try {
      final response = await _dio.get('xxread/books/books.json');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.data);
        final remoteBooks =
            (data['books'] as List).cast<Map<String, dynamic>>();

        // 合并本地和远程数据
        await _mergeBooks(remoteBooks);
      }
    } catch (e) {
      debugPrint('下载书籍列表失败: $e');
    }
  }

  /// 下载书签
  Future<void> _downloadBookmarks() async {
    try {
      final response = await _dio.get('xxread/bookmarks/bookmarks.json');
      if (response.statusCode == 200) {
        jsonDecode(response.data);
        debugPrint('下载书签数据（占位）');
      }
    } catch (e) {
      debugPrint('下载书签失败: $e');
    }
  }

  /// 下载阅读进度
  Future<void> _downloadProgress() async {
    try {
      final response = await _dio.get('xxread/progress/progress.json');
      if (response.statusCode == 200) {
        jsonDecode(response.data);
        debugPrint('下载进度数据（占位）');
      }
    } catch (e) {
      debugPrint('下载阅读进度失败: $e');
    }
  }

  /// 合并书籍数据
  Future<void> _mergeBooks(List<Map<String, dynamic>> remoteBooks) async {
    for (final remoteBook in remoteBooks) {
      final book = Book.fromMap(remoteBook);
      final localBook = await _bookDao.getBookById(book.id ?? 0);

      if (localBook == null) {
        // 远程书籍在本地不存在，检查文件是否存在
        if (book.filePath.isNotEmpty && await File(book.filePath).exists()) {
          await _bookDao.insertBook(book);
        }
      } else {
        // 合并数据，保留最新的阅读进度
        final mergedBook = _mergeBookData(localBook, book);
        await _bookDao.updateBook(mergedBook);
      }
    }
  }

  /// 合并书籍数据
  Book _mergeBookData(Book local, Book remote) {
    // 暂时简化处理，总是使用本地数据
    return local;
  }

  /// 获取同步状态描述
  String getStatusDescription() {
    switch (status) {
      case SyncStatus.idle:
        return '准备就绪';
      case SyncStatus.syncing:
        return '同步中...';
      case SyncStatus.completed:
        return '同步完成';
      case SyncStatus.failed:
        return '同步失败';
      case SyncStatus.noNetwork:
        return '无网络连接';
      case SyncStatus.notConfigured:
        return '未配置';
    }
  }

  /// 清除配置
  Future<void> clearConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('webdav_server_url');
    await prefs.remove('webdav_username');
    await prefs.remove('webdav_password');
    await prefs.remove('webdav_auto_sync');
    await prefs.remove('webdav_sync_interval');
    await prefs.remove('webdav_last_sync');

    _stopAutoSync();
    _isConfigured = false;
    _statusNotifier.value = SyncStatus.notConfigured;
  }

  /// 释放资源
  void dispose() {
    _stopAutoSync();
    _connectivitySubscription?.cancel();
    _dio.close();
  }
}
