import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/books/bookmark_dao.dart';
import 'package:xxread/services/books/book_note_dao.dart';
import 'package:xxread/services/reading/reading_stats_dao.dart';
import 'package:xxread/services/books/book_source_dao.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/models/bookmark.dart';
import 'package:xxread/models/book_note.dart';
import 'package:xxread/models/book_source.dart';
import 'package:xxread/services/sync/webdav_sync_manifest_model.dart';
import 'package:xxread/services/sync/webdav_sync_path_helper.dart';
import 'package:xxread/services/sync/sync_utils.dart';

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
///
/// 支持同步的数据类型：
/// - 书籍元数据（差异化字段）
/// - 书签
/// - 笔记/高亮
/// - 批注（从笔记中派生）
/// - 阅读进度
/// - 阅读统计
/// - 书源配置
/// - 书籍文件（按需上传）
class WebDavSyncService {
  static final WebDavSyncService _instance = WebDavSyncService._internal();
  factory WebDavSyncService() => _instance;
  WebDavSyncService._internal();

  final Dio _dio = Dio();
  final ValueNotifier<SyncStatus> _statusNotifier =
      ValueNotifier<SyncStatus>(SyncStatus.notConfigured);

  // WebDAV配置
  String _serverUrl = '';
  String _username = '';
  String _password = '';
  bool _isConfigured = false;
  String _lastErrorMessage = '';

  // 同步设置
  bool _autoSync = true;
  int _syncInterval = 30; // 分钟
  DateTime? _lastSyncTime;
  Timer? _syncTimer;

  // DAO实例
  final BookDao _bookDao = BookDao();
  final BookmarkDao _bookmarkDao = BookmarkDao();
  final BookNoteDao _noteDao = BookNoteDao();
  final ReadingStatsDao _statsDao = ReadingStatsDao();
  // BookSourceDao 使用静态方法，不需要实例

  // 按需上传的书籍文件集合
  final Set<int> _selectedBooksForSync = {};
  final List<String> _lastSyncWarnings = <String>[];

  // 网络监听
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _hasNetwork = true;
  static const int _maxRetryAttempts = 3;

  // Getters
  ValueNotifier<SyncStatus> get statusNotifier => _statusNotifier;
  SyncStatus get status => _statusNotifier.value;
  bool get isConfigured => _isConfigured;
  bool get autoSync => _autoSync;
  int get syncInterval => _syncInterval;
  DateTime? get lastSyncTime => _lastSyncTime;
  String get serverUrl => _serverUrl;
  String get username => _username;
  String get lastErrorMessage => _lastErrorMessage;

  /// 初始化同步服务
  Future<void> initialize() async {
    await _loadConfiguration();
    await _loadSyncSettings();
    await _setupNetworkListener();

    if (_isConfigured && _autoSync) {
      _startAutoSync();
    }
  }

  /// 加载配置
  Future<void> _loadConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverUrl = _normalizeServerUrl(
        prefs.getString('webdav_server_url') ?? '',
      );
      _username = prefs.getString('webdav_username') ?? '';
      _password = prefs.getString('webdav_password') ?? '';
      _autoSync = prefs.getBool('webdav_auto_sync') ?? true;
      _syncInterval = _sanitizeSyncInterval(
        prefs.getInt('webdav_sync_interval') ?? 30,
      );

      final lastSyncStr = prefs.getString('webdav_last_sync');
      if (lastSyncStr != null) {
        _lastSyncTime = DateTime.parse(lastSyncStr);
      }

      _isConfigured =
          _serverUrl.isNotEmpty && _username.isNotEmpty && _password.isNotEmpty;

      if (_isConfigured) {
        _setupDioClient();
        _statusNotifier.value = SyncStatus.idle;
        _lastErrorMessage = '';
      } else {
        _statusNotifier.value = SyncStatus.notConfigured;
      }
    } catch (e) {
      debugPrint('加载WebDAV配置失败: $e');
      _lastErrorMessage = '加载WebDAV配置失败: $e';
      _statusNotifier.value = SyncStatus.notConfigured;
    }
  }

  /// 加载同步设置
  Future<void> _loadSyncSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedBooksStr = prefs.getStringList('webdav_selected_books');
      if (selectedBooksStr != null) {
        _selectedBooksForSync.clear();
        _selectedBooksForSync.addAll(
          selectedBooksStr
              .map((s) => int.tryParse(s) ?? -1)
              .where((bookId) => bookId > 0),
        );
      }
    } catch (e) {
      debugPrint('加载同步设置失败: $e');
    }
  }

  /// 保存同步设置
  Future<void> _saveSyncSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'webdav_selected_books',
        _selectedBooksForSync.map((s) => s.toString()).toList(),
      );
    } catch (e) {
      debugPrint('保存同步设置失败: $e');
    }
  }

  /// 设置网络监听
  Future<void> _setupNetworkListener() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final hasNetwork =
            results.any((result) => result != ConnectivityResult.none);

        if (_hasNetwork != hasNetwork) {
          _hasNetwork = hasNetwork;

          if (hasNetwork && _isConfigured && _autoSync) {
            // 网络恢复，执行同步
            _performSync();
          } else if (!hasNetwork) {
            _statusNotifier.value = SyncStatus.noNetwork;
          }
        }
      },
    );
  }

  /// 设置Dio客户端
  void _setupDioClient() {
    _dio.options = _buildBaseOptions(
      serverUrl: _serverUrl,
      username: _username,
      password: _password,
    );
    _dio.interceptors.clear();

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

  BaseOptions _buildBaseOptions({
    required String serverUrl,
    required String username,
    required String password,
  }) {
    return BaseOptions(
      baseUrl: _normalizeServerUrl(serverUrl),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Authorization': _generateAuthHeader(username, password),
        'Content-Type': 'application/octet-stream',
        'Accept': '*/*',
      },
    );
  }

  /// 生成认证头
  String _generateAuthHeader(String username, String password) {
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $credentials';
  }

  String _normalizeServerUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }

  bool _isValidServerUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  int _sanitizeSyncInterval(int value) {
    if (value < 5) return 5;
    if (value > 24 * 60) return 24 * 60;
    return value;
  }

  void _setLastError(String message) {
    _lastErrorMessage = message;
    debugPrint('WebDAV错误: $message');
  }

  /// 配置WebDAV
  Future<bool> configure({
    required String serverUrl,
    required String username,
    required String password,
    bool autoSync = true,
    int syncInterval = 30,
  }) async {
    final normalizedServerUrl = _normalizeServerUrl(serverUrl);
    final normalizedUsername = username.trim();
    final normalizedPassword = password.trim();
    final effectivePassword =
        normalizedPassword.isNotEmpty ? normalizedPassword : _password;

    if (!_isValidServerUrl(normalizedServerUrl)) {
      _setLastError('服务器地址无效，请使用 http 或 https URL');
      return false;
    }
    if (normalizedUsername.isEmpty) {
      _setLastError('用户名不能为空');
      return false;
    }
    if (effectivePassword.isEmpty) {
      _setLastError('密码不能为空');
      return false;
    }

    final previousServerUrl = _serverUrl;
    final previousUsername = _username;
    final previousPassword = _password;
    final previousAutoSync = _autoSync;
    final previousSyncInterval = _syncInterval;
    final previousConfigured = _isConfigured;

    try {
      _serverUrl = normalizedServerUrl;
      _username = normalizedUsername;
      _password = effectivePassword;
      _autoSync = autoSync;
      _syncInterval = _sanitizeSyncInterval(syncInterval);

      _setupDioClient();

      // 测试连接
      final isValid = await testConnection();
      if (!isValid) {
        _serverUrl = previousServerUrl;
        _username = previousUsername;
        _password = previousPassword;
        _autoSync = previousAutoSync;
        _syncInterval = previousSyncInterval;
        _isConfigured = previousConfigured;
        if (_isConfigured) {
          _setupDioClient();
        }
        return false;
      }

      await _ensureSyncDirectories();

      // 保存配置
      await _saveConfiguration();
      _isConfigured = true;
      _statusNotifier.value = SyncStatus.idle;
      _lastErrorMessage = '';

      // 启动自动同步
      if (_autoSync) {
        _startAutoSync();
      } else {
        _stopAutoSync();
      }

      return true;
    } catch (e) {
      _setLastError('配置失败: $e');

      _serverUrl = previousServerUrl;
      _username = previousUsername;
      _password = previousPassword;
      _autoSync = previousAutoSync;
      _syncInterval = previousSyncInterval;
      _isConfigured = previousConfigured;
      if (_isConfigured) {
        _setupDioClient();
      }

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
    if (_serverUrl.isEmpty || _username.isEmpty || _password.isEmpty) {
      _setLastError('请先填写完整的 WebDAV 配置');
      return false;
    }

    try {
      if (!_hasNetwork) {
        _setLastError('当前无网络连接');
        _statusNotifier.value = SyncStatus.noNetwork;
        return false;
      }

      return _testConnectionByDio(_dio);
    } catch (e) {
      _setLastError('WebDAV 连接测试失败: $e');
      return false;
    }
  }

  /// 测试连接（不保存配置）
  Future<bool> testConnectionWith({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    if (!_hasNetwork) {
      _setLastError('当前无网络连接');
      return false;
    }

    final normalizedServerUrl = _normalizeServerUrl(serverUrl);
    final normalizedUsername = username.trim();
    final normalizedPassword = password.trim();
    final effectivePassword =
        normalizedPassword.isNotEmpty ? normalizedPassword : _password;

    if (!_isValidServerUrl(normalizedServerUrl)) {
      _setLastError('服务器地址无效，请使用 http 或 https URL');
      return false;
    }
    if (normalizedUsername.isEmpty) {
      _setLastError('用户名不能为空');
      return false;
    }
    if (effectivePassword.isEmpty) {
      _setLastError('密码不能为空');
      return false;
    }

    final testDio = Dio(
      _buildBaseOptions(
        serverUrl: normalizedServerUrl,
        username: normalizedUsername,
        password: effectivePassword,
      ),
    );
    try {
      return await _testConnectionByDio(testDio);
    } catch (e) {
      _setLastError('WebDAV 连接测试失败: $e');
      return false;
    } finally {
      testDio.close(force: true);
    }
  }

  Future<bool> _testConnectionByDio(Dio dio) async {
    final probePaths = <String>['', WebDavSyncPathHelper.rootDir];

    for (final path in probePaths) {
      try {
        final response = await dio.request(
          path,
          options: Options(
            method: 'PROPFIND',
            headers: {'Depth': '0'},
            validateStatus: (status) => status != null && status > 0,
          ),
        );
        final statusCode = response.statusCode ?? 0;

        if (statusCode == 401 || statusCode == 403) {
          _setLastError('认证失败，请检查用户名或密码');
          return false;
        }
        if (<int>{200, 201, 204, 207, 301, 302, 405}.contains(statusCode)) {
          _lastErrorMessage = '';
          return true;
        }
      } catch (e) {
        debugPrint('WebDAV探测失败($path): $e');
      }
    }

    _setLastError('无法访问 WebDAV 目录，请检查服务器地址与权限');
    return false;
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
      _setLastError('同步正在进行中，请稍后再试');
      return false;
    }

    if (!_isConfigured) {
      _statusNotifier.value = SyncStatus.notConfigured;
      _setLastError('请先配置 WebDAV');
      return false;
    }

    return await _performSync();
  }

  /// 设置书籍是否需要同步文件
  Future<void> setBookForSync(int bookId, bool shouldSync) async {
    if (shouldSync) {
      _selectedBooksForSync.add(bookId);
    } else {
      _selectedBooksForSync.remove(bookId);
    }
    await _saveSyncSettings();
  }

  /// 获取选择需要同步的书籍集合
  Set<int> getBooksSelectedForSync() {
    return Set.from(_selectedBooksForSync);
  }

  /// 上传指定书籍的文件
  Future<bool> uploadBookFile(int bookId) async {
    try {
      final book = await _bookDao.getBookById(bookId);
      if (book == null) {
        debugPrint('书籍不存在: $bookId');
        return false;
      }

      final bookFile = File(book.filePath);
      if (!await bookFile.exists()) {
        debugPrint('书籍文件不存在: ${book.filePath}');
        return false;
      }

      final fileName = book.contentHash ?? 'book_$bookId.${book.format}';
      final remotePath = WebDavSyncPathHelper.buildBookFilePath(fileName);

      final fileBytes = await bookFile.readAsBytes();
      await _dio.put(
        remotePath,
        data: fileBytes,
        options: Options(
          headers: {'Content-Type': 'application/octet-stream'},
        ),
      );

      debugPrint('已上传书籍文件: ${book.title}');
      return true;
    } catch (e) {
      debugPrint('上传书籍文件失败: $e');
      return false;
    }
  }

  /// 执行同步
  Future<bool> _performSync() async {
    if (!_isConfigured) {
      _statusNotifier.value = SyncStatus.notConfigured;
      _setLastError('请先配置 WebDAV');
      return false;
    }
    if (!_hasNetwork) {
      _statusNotifier.value = SyncStatus.noNetwork;
      _setLastError('当前无网络连接');
      return false;
    }

    _statusNotifier.value = SyncStatus.syncing;
    _lastErrorMessage = '';
    _lastSyncWarnings.clear();

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
      if (_lastSyncWarnings.isNotEmpty) {
        _lastErrorMessage = '同步完成（部分项目失败）：${_lastSyncWarnings.join('；')}';
      } else {
        _lastErrorMessage = '';
      }

      // 3秒后恢复空闲状态
      Timer(const Duration(seconds: 3), () {
        if (_statusNotifier.value == SyncStatus.completed) {
          _statusNotifier.value = SyncStatus.idle;
        }
      });

      return true;
    } catch (e) {
      _setLastError('同步失败: ${_toFriendlySyncError(e)}');
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
    const directories = WebDavSyncPathHelper.allDirectories;

    for (final dir in directories) {
      final response = await _retryRequest(
        label: '创建目录 $dir',
        action: () => _dio.request(
          dir,
          options: Options(
            method: 'MKCOL',
            validateStatus: (status) => status != null && status > 0,
          ),
        ),
      );
      final statusCode = response.statusCode ?? 0;
      // 201: 创建成功, 405: 已存在, 301/302: 服务端重定向
      if (!<int>{200, 201, 204, 301, 302, 405}.contains(statusCode)) {
        throw Exception('创建目录失败: $dir (HTTP $statusCode)');
      }
    }

    // 保存设备信息
    await _saveDeviceMeta();
  }

  /// 保存设备元数据
  Future<void> _saveDeviceMeta() async {
    try {
      final deviceId = await SyncUtils.getDeviceId();
      final deviceMeta = {
        'device_id': deviceId,
        'device_name': 'xxread',
        'platform': Platform.operatingSystem,
        'first_sync_time': (await _getFirstSyncTime())?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'last_sync_time': DateTime.now().toIso8601String(),
      };

      await _dio.put(
        WebDavSyncPathHelper.deviceMetaFile,
        data: jsonEncode(deviceMeta),
      );
    } catch (e) {
      debugPrint('保存设备元数据失败: $e');
    }
  }

  /// 获取首次同步时间
  Future<DateTime?> _getFirstSyncTime() async {
    try {
      final response = await _dio.get(WebDavSyncPathHelper.deviceMetaFile);
      if (response.statusCode == 200) {
        final data = _asJsonMap(response.data);
        final firstSync = data['first_sync_time']?.toString();
        if (firstSync != null && firstSync.isNotEmpty) {
          return DateTime.parse(firstSync);
        }
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
  }

  /// 上传本地数据
  Future<void> _uploadLocalData() async {
    await _runSyncStage('上传书籍列表', _uploadBooks);
    await _runSyncStage('上传书签', _uploadBookmarks);
    await _runSyncStage('上传笔记', _uploadNotes);
    await _runSyncStage('上传高亮与批注', _uploadHighlightsAndAnnotations);
    await _runSyncStage('上传阅读进度', _uploadProgress, optional: true);
    await _runSyncStage('上传阅读统计', _uploadStats);
    await _runSyncStage('上传书源', _uploadSources, optional: true);

    await _runSyncStage('上传同步清单', _uploadSyncManifest, optional: true);
    await _runSyncStage('上传书籍文件', _uploadBookFiles, optional: true);
  }

  /// 上传书籍列表（使用差异化同步）
  Future<void> _uploadBooks() async {
    try {
      final books = await _bookDao.getAllBooks();

      // 生成书籍元数据（不包含大字段）
      final booksMetadata = books.map((book) {
        final map = book.toMap();
        // 移除大字段以减少上传数据量
        map.remove('cached_content');
        map.remove('cached_pages');
        map.remove('table_of_contents');
        // 添加更新时间
        map['update_time'] = DateTime.now().toIso8601String();
        return map;
      }).toList();

      final booksData = {
        'version': 3,
        'device_id': await SyncUtils.getDeviceId(),
        'timestamp': DateTime.now().toIso8601String(),
        'books': booksMetadata,
        'book_count': books.length,
      };

      final jsonData = jsonEncode(booksData);
      await _retryRequest(
        label: '上传书籍列表',
        action: () => _dio.put(WebDavSyncPathHelper.booksFile, data: jsonData),
      );

      debugPrint('📚 已上传 ${books.length} 本书籍的元数据');
    } catch (e) {
      throw Exception('上传书籍列表失败: $e');
    }
  }

  /// 上传书签
  Future<void> _uploadBookmarks() async {
    try {
      final bookmarks = await _bookmarkDao.getAllBookmarks();

      final bookmarksData = {
        'version': 1,
        'device_id': await SyncUtils.getDeviceId(),
        'timestamp': DateTime.now().toIso8601String(),
        'bookmarks': bookmarks.map((b) => b.toMap()).toList(),
      };

      final jsonData = jsonEncode(bookmarksData);
      await _retryRequest(
        label: '上传书签',
        action: () =>
            _dio.put(WebDavSyncPathHelper.bookmarksFile, data: jsonData),
      );

      debugPrint('🔖 已上传 ${bookmarks.length} 个书签');
    } catch (e) {
      throw Exception('上传书签失败: $e');
    }
  }

  /// 上传笔记/高亮
  Future<void> _uploadNotes() async {
    try {
      final notes = await _noteDao.getAllNotes();

      final notesData = {
        'version': 1,
        'device_id': await SyncUtils.getDeviceId(),
        'timestamp': DateTime.now().toIso8601String(),
        'notes': notes.map((n) => n.toMap()).toList(),
      };

      final jsonData = jsonEncode(notesData);
      await _retryRequest(
        label: '上传笔记',
        action: () => _dio.put(WebDavSyncPathHelper.notesFile, data: jsonData),
      );

      debugPrint('📝 已上传 ${notes.length} 条笔记');
    } catch (e) {
      throw Exception('上传笔记失败: $e');
    }
  }

  /// 上传高亮与批注（由当前 notes 派生，方便未来独立升级数据结构）
  Future<void> _uploadHighlightsAndAnnotations() async {
    try {
      final notes = await _noteDao.getAllNotes();
      final deviceId = await SyncUtils.getDeviceId();
      final now = DateTime.now().toIso8601String();

      final highlights = notes
          .where((n) => n.type == 'highlight' || n.type == 'underline')
          .map((n) => n.toMap())
          .toList();
      final annotations = notes
          .where((n) => n.type == 'note' || (n.readerNote?.isNotEmpty ?? false))
          .map((n) => n.toMap())
          .toList();

      final highlightsData = {
        'version': 1,
        'device_id': deviceId,
        'timestamp': now,
        'highlights': highlights,
      };
      final annotationsData = {
        'version': 1,
        'device_id': deviceId,
        'timestamp': now,
        'annotations': annotations,
      };

      await _retryRequest(
        label: '上传高亮',
        action: () => _dio.put(
          WebDavSyncPathHelper.highlightsFile,
          data: jsonEncode(highlightsData),
        ),
      );
      await _retryRequest(
        label: '上传批注',
        action: () => _dio.put(
          WebDavSyncPathHelper.annotationsFile,
          data: jsonEncode(annotationsData),
        ),
      );

      debugPrint('✨ 已上传 ${highlights.length} 条高亮');
      debugPrint('🗒️ 已上传 ${annotations.length} 条批注');
    } catch (e) {
      throw Exception('上传高亮/批注失败: $e');
    }
  }

  /// 上传阅读进度
  Future<void> _uploadProgress() async {
    try {
      final books = await _bookDao.getAllBooks();

      final progressItems = books.map((book) {
        final hasHash = (book.contentHash ?? '').trim().isNotEmpty;
        return {
          'bookId': book.id,
          if (hasHash) 'contentHash': book.contentHash,
          if (!hasHash) 'filePath': book.filePath,
          'currentPage': book.currentPage,
          'totalPages': book.totalPages,
        };
      }).toList();

      final progressData = {
        'version': 2,
        'device_id': await SyncUtils.getDeviceId(),
        'timestamp': DateTime.now().toIso8601String(),
        'progress': progressItems,
      };

      final jsonData = jsonEncode(progressData);
      await _retryRequest(
        label: '上传阅读进度',
        action: () =>
            _dio.put(WebDavSyncPathHelper.progressFile, data: jsonData),
      );

      debugPrint('📄 已上传 ${progressItems.length} 本书籍的阅读进度');
    } catch (e) {
      throw Exception('上传阅读进度失败: $e');
    }
  }

  /// 上传阅读统计
  Future<void> _uploadStats() async {
    try {
      final stats = await _statsDao.getAllStats();

      final statsData = {
        'version': 1,
        'device_id': await SyncUtils.getDeviceId(),
        'timestamp': DateTime.now().toIso8601String(),
        'stats': stats,
      };

      final jsonData = jsonEncode(statsData);
      await _retryRequest(
        label: '上传阅读统计',
        action: () => _dio.put(WebDavSyncPathHelper.statsFile, data: jsonData),
      );

      debugPrint('📊 已上传 ${stats.length} 条阅读统计');
    } catch (e) {
      throw Exception('上传阅读统计失败: $e');
    }
  }

  /// 上传书源
  Future<void> _uploadSources() async {
    try {
      final sources = await BookSourceDao.getAll();

      final sourcesData = {
        'version': 1,
        'device_id': await SyncUtils.getDeviceId(),
        'timestamp': DateTime.now().toIso8601String(),
        'sources': sources.map((s) => s.toJson()).toList(),
      };

      final jsonData = jsonEncode(sourcesData);
      await _retryRequest(
        label: '上传书源',
        action: () =>
            _dio.put(WebDavSyncPathHelper.sourcesFile, data: jsonData),
      );

      debugPrint('📡 已上传 ${sources.length} 个书源');
    } catch (e) {
      throw Exception('上传书源失败: $e');
    }
  }

  /// 上传同步清单，统一描述“这次同步包含了什么”
  Future<void> _uploadSyncManifest() async {
    try {
      final books = await _bookDao.getAllBooks();
      final bookmarks = await _bookmarkDao.getAllBookmarks();
      final notes = await _noteDao.getAllNotes();
      final stats = await _statsDao.getAllStats();
      final sources = await BookSourceDao.getAll();

      final highlightsCount = notes
          .where((n) => n.type == 'highlight' || n.type == 'underline')
          .length;
      final annotationsCount = notes
          .where((n) => n.type == 'note' || (n.readerNote?.isNotEmpty ?? false))
          .length;

      final manifest = WebDavSyncManifestModel(
        schemaVersion: 1,
        appName: 'xxread',
        deviceId: await SyncUtils.getDeviceId(),
        generatedAt: DateTime.now(),
        booksCount: books.length,
        bookmarksCount: bookmarks.length,
        notesCount: notes.length,
        highlightsCount: highlightsCount,
        annotationsCount: annotationsCount,
        progressCount: books.length,
        statsCount: stats.length,
        sourcesCount: sources.length,
        selectedBookFilesCount: _selectedBooksForSync.length,
      );

      await _retryRequest(
        label: '上传同步清单',
        action: () => _dio.put(
          WebDavSyncPathHelper.syncManifestFile,
          data: jsonEncode(manifest.toJson()),
        ),
      );
    } catch (e) {
      throw Exception('上传同步清单失败: $e');
    }
  }

  /// 上传书籍文件（按需上传）
  Future<void> _uploadBookFiles() async {
    try {
      if (_selectedBooksForSync.isEmpty) {
        debugPrint('⏭️ 没有选择需要同步的书籍文件');
        return;
      }

      final books = await _bookDao.getAllBooks();
      final booksToSync =
          books.where((b) => _selectedBooksForSync.contains(b.id)).toList();

      if (booksToSync.isEmpty) {
        debugPrint('⏭️ 选择的书籍不存在');
        return;
      }

      int uploadedCount = 0;
      int skippedCount = 0;

      for (final book in booksToSync) {
        final bookFile = File(book.filePath);
        if (!await bookFile.exists()) {
          debugPrint('跳过不存在的文件: ${book.filePath}');
          skippedCount++;
          continue;
        }

        final fileSize = await bookFile.length();
        const maxFileSize = 100 * 1024 * 1024; // 100MB限制
        if (fileSize > maxFileSize) {
          debugPrint(
            '跳过过大文件 (${SyncUtils.formatFileSize(fileSize)}): ${book.title}',
          );
          skippedCount++;
          continue;
        }

        final fileName = book.contentHash ?? 'book_${book.id}.${book.format}';
        final remotePath = WebDavSyncPathHelper.buildBookFilePath(fileName);

        try {
          await _dio.head(remotePath);
          debugPrint('文件已存在，跳过: ${book.title}');
          skippedCount++;
          continue;
        } catch (e) {
          // 文件不存在，继续上传
        }

        final fileBytes = await bookFile.readAsBytes();
        await _retryRequest(
          label: '上传书籍文件 ${book.title}',
          action: () => _dio.put(
            remotePath,
            data: fileBytes,
            options: Options(
              headers: {'Content-Type': 'application/octet-stream'},
            ),
          ),
        );

        uploadedCount++;
        debugPrint(
            '📦 已上传书籍: ${book.title} (${SyncUtils.formatFileSize(fileSize)})');
      }

      debugPrint(
        '📚 书籍文件上传完成: 上传 $uploadedCount 个, 跳过 $skippedCount 个',
      );
    } catch (e) {
      throw Exception('上传书籍文件失败: $e');
    }
  }

  /// 下载远程数据
  Future<void> _downloadRemoteData() async {
    await Future.wait([
      _downloadBooks(),
      _downloadBookmarks(),
      _downloadNotes(),
      _downloadProgress(),
      _downloadStats(),
      _downloadSources(),
    ]);
  }

  /// 下载书籍列表
  Future<void> _downloadBooks() async {
    try {
      final response = await _dio.get(WebDavSyncPathHelper.booksFile);
      if (response.statusCode == 200) {
        final data = _asJsonMap(response.data);
        final remoteBooks = _asJsonList(data['books']);

        await _mergeBooks(remoteBooks);
      }
    } catch (e) {
      if (_isRemoteFileMissing(e)) {
        debugPrint('远程书籍数据不存在，跳过下载');
        return;
      }
      throw Exception('下载书籍列表失败: $e');
    }
  }

  /// 下载书签
  Future<void> _downloadBookmarks() async {
    try {
      final response = await _dio.get(WebDavSyncPathHelper.bookmarksFile);
      if (response.statusCode == 200) {
        final data = _asJsonMap(response.data);
        final remoteBookmarks = _asJsonList(data['bookmarks']);

        await _mergeBookmarks(remoteBookmarks);
      }
    } catch (e) {
      if (_isRemoteFileMissing(e)) {
        debugPrint('远程书签数据不存在，跳过下载');
        return;
      }
      throw Exception('下载书签失败: $e');
    }
  }

  /// 下载笔记
  Future<void> _downloadNotes() async {
    try {
      final response = await _dio.get(WebDavSyncPathHelper.notesFile);
      if (response.statusCode == 200) {
        final data = _asJsonMap(response.data);
        final remoteNotes = _asJsonList(data['notes']);

        await _mergeNotes(remoteNotes);
      }
    } catch (e) {
      if (_isRemoteFileMissing(e)) {
        debugPrint('远程笔记数据不存在，跳过下载');
        return;
      }
      throw Exception('下载笔记失败: $e');
    }
  }

  /// 下载阅读进度
  Future<void> _downloadProgress() async {
    try {
      final response = await _dio.get(WebDavSyncPathHelper.progressFile);
      if (response.statusCode == 200) {
        final data = _asJsonMap(response.data);
        final remoteProgress = _asJsonList(data['progress']);

        await _mergeProgress(remoteProgress);
      }
    } catch (e) {
      if (_isRemoteFileMissing(e)) {
        debugPrint('远程进度数据不存在，跳过下载');
        return;
      }
      throw Exception('下载阅读进度失败: $e');
    }
  }

  /// 下载阅读统计
  Future<void> _downloadStats() async {
    try {
      final response = await _dio.get(WebDavSyncPathHelper.statsFile);
      if (response.statusCode == 200) {
        final data = _asJsonMap(response.data);
        final remoteStats = _asJsonList(data['stats']);

        await _mergeStats(remoteStats);
      }
    } catch (e) {
      if (_isRemoteFileMissing(e)) {
        debugPrint('远程统计数据不存在，跳过下载');
        return;
      }
      throw Exception('下载阅读统计失败: $e');
    }
  }

  /// 下载书源
  Future<void> _downloadSources() async {
    try {
      final response = await _dio.get(WebDavSyncPathHelper.sourcesFile);
      if (response.statusCode == 200) {
        final data = _asJsonMap(response.data);
        final remoteSources = _asJsonList(data['sources']);

        await _mergeSources(remoteSources);
      }
    } catch (e) {
      if (_isRemoteFileMissing(e)) {
        debugPrint('远程书源数据不存在，跳过下载');
        return;
      }
      throw Exception('下载书源失败: $e');
    }
  }

  /// 合并书签（双向合并，按 bookId+pageNumber 去重）
  Future<void> _mergeBookmarks(
      List<Map<String, dynamic>> remoteBookmarks) async {
    int addedCount = 0;
    int mergedCount = 0;

    final localBookmarks = await _bookmarkDao.getAllBookmarks();
    final localMap = <String, Bookmark>{};

    for (final bookmark in localBookmarks) {
      final key = _bookmarkSyncKey(bookmark);
      localMap[key] = bookmark;
    }

    for (final remoteMap in remoteBookmarks) {
      try {
        final remoteBookmark = Bookmark.fromMap(remoteMap);
        final key = _bookmarkSyncKey(remoteBookmark);

        if (localMap.containsKey(key)) {
          // 已存在，跳过（保留创建时间较早的）
          mergedCount++;
        } else {
          // 新增远程书签
          await _bookmarkDao.insertBookmark(remoteBookmark);
          localMap[key] = remoteBookmark;
          addedCount++;
        }
      } catch (e) {
        debugPrint('合并书签失败: $e');
      }
    }

    debugPrint('🔖 书签合并完成: 新增 $addedCount, 已存在 $mergedCount');
  }

  String _bookmarkSyncKey(Bookmark bookmark) {
    final cfi = bookmark.cfi?.trim() ?? '';
    if (cfi.isNotEmpty) {
      return 'bookmark-cfi:${bookmark.bookId}:$cfi';
    }
    return SyncUtils.generateBookmarkKey(bookmark.bookId, bookmark.pageNumber);
  }

  /// 合并笔记（按位置去重，时间戳优先）
  Future<void> _mergeNotes(List<Map<String, dynamic>> remoteNotes) async {
    int addedCount = 0;
    int updatedCount = 0;

    final localNotes = await _noteDao.getAllNotes();
    final localMap = <String, BookNote>{};

    for (final note in localNotes) {
      final key = SyncUtils.generateNoteKey(
        note.bookId,
        note.cfi,
        note.startOffset,
        note.endOffset,
      );
      localMap[key] = note;
    }

    for (final remoteMap in remoteNotes) {
      try {
        final remoteNote = BookNote.fromMap(remoteMap);
        final key = SyncUtils.generateNoteKey(
          remoteNote.bookId,
          remoteNote.cfi,
          remoteNote.startOffset,
          remoteNote.endOffset,
        );

        if (localMap.containsKey(key)) {
          final localNote = localMap[key]!;

          // 比较更新时间，使用较新的
          if (SyncUtils.isRemoteNewer(
            localNote.updateTime.toIso8601String(),
            remoteNote.updateTime.toIso8601String(),
          )) {
            await _noteDao.updateBookNoteById(remoteNote);
            updatedCount++;
          }
        } else {
          // 新增远程笔记
          await _noteDao.insertBookNote(remoteNote);
          localMap[key] = remoteNote;
          addedCount++;
        }
      } catch (e) {
        debugPrint('合并笔记失败: $e');
      }
    }

    debugPrint('📝 笔记合并完成: 新增 $addedCount, 更新 $updatedCount');
  }

  /// 合并阅读进度（时间戳优先）
  Future<void> _mergeProgress(List<Map<String, dynamic>> remoteProgress) async {
    int updatedCount = 0;
    final localBooks = await _bookDao.getAllBooks();
    final localById = <int, Book>{};
    final localByHash = <String, Book>{};
    final localByPath = <String, Book>{};

    for (final book in localBooks) {
      if (book.id != null) {
        localById[book.id!] = book;
      }
      final hash = (book.contentHash ?? '').trim();
      if (hash.isNotEmpty) {
        localByHash[hash] = book;
      }
      final pathKey = _normalizePathKey(book.filePath);
      if (pathKey.isNotEmpty) {
        localByPath[pathKey] = book;
      }
    }

    for (final progress in remoteProgress) {
      try {
        final remoteCurrentPage = (progress['currentPage'] as num?)?.toInt();
        if (remoteCurrentPage == null || remoteCurrentPage < 0) {
          continue;
        }

        final remoteBookId = progress['bookId'];
        final remoteContentHash = (progress['contentHash'] ?? '').toString();
        final remoteFilePath = (progress['filePath'] ?? '').toString();
        final remoteTotalPages = (progress['totalPages'] as num?)?.toInt();

        Book? localBook;
        if (remoteBookId is int) {
          localBook = localById[remoteBookId];
        }
        if (localBook == null && remoteContentHash.trim().isNotEmpty) {
          localBook = localByHash[remoteContentHash.trim()];
        }
        if (localBook == null && remoteFilePath.trim().isNotEmpty) {
          localBook = localByPath[_normalizePathKey(remoteFilePath)];
        }

        if (localBook == null || localBook.id == null) {
          continue;
        }

        if (remoteCurrentPage > localBook.currentPage) {
          final mergedTotalPages = remoteTotalPages != null &&
                  remoteTotalPages > localBook.totalPages
              ? remoteTotalPages
              : localBook.totalPages;

          final updatedBook = localBook.copyWith(
            currentPage: remoteCurrentPage,
            totalPages: mergedTotalPages,
          );
          await _bookDao.updateBook(updatedBook);
          localById[updatedBook.id!] = updatedBook;
          updatedCount++;
          debugPrint(
            '📄 更新书籍进度 ${updatedBook.id}: ${localBook.currentPage} -> $remoteCurrentPage',
          );
        }
      } catch (e) {
        debugPrint('合并进度失败: $e');
      }
    }

    debugPrint('📄 阅读进度合并完成: 更新 $updatedCount');
  }

  /// 合并阅读统计（同日期累加）
  Future<void> _mergeStats(List<Map<String, dynamic>> remoteStats) async {
    int mergedCount = 0;

    for (final stat in remoteStats) {
      try {
        final date = stat['date'] as String;
        final remoteDuration = stat['durationInSeconds'] as int;

        final db = await _statsDao.dbService.database;
        final existing = await db.query(
          'reading_stats',
          where: 'date = ?',
          whereArgs: [date],
        );

        if (existing.isNotEmpty) {
          // 累加时长
          final localDuration = existing.first['durationInSeconds'] as int;
          final newDuration = localDuration + remoteDuration;

          await db.update(
            'reading_stats',
            {'durationInSeconds': newDuration},
            where: 'date = ?',
            whereArgs: [date],
          );
          mergedCount++;
        } else {
          // 插入新记录
          await db.insert('reading_stats', {
            'date': date,
            'durationInSeconds': remoteDuration,
          });
        }
      } catch (e) {
        debugPrint('合并统计失败: $e');
      }
    }

    debugPrint('📊 阅读统计合并完成: 累加 $mergedCount');
  }

  /// 合并书源（按 URL 去重，双向合并）
  Future<void> _mergeSources(List<Map<String, dynamic>> remoteSources) async {
    int addedCount = 0;
    int mergedCount = 0;

    final localSources = await BookSourceDao.getAll();
    final localUrlSet = <String>{};

    for (final source in localSources) {
      localUrlSet.add(source.bookSourceUrl);
    }

    for (final remoteMap in remoteSources) {
      try {
        final url = (remoteMap['bookSourceUrl'] ?? remoteMap['book_source_url'])
            ?.toString()
            .trim();
        if (url == null || url.isEmpty) {
          continue;
        }

        if (localUrlSet.contains(url)) {
          // URL 已存在，跳过（保留本地）
          mergedCount++;
        } else {
          // 新增远程书源
          final bookSource = BookSource.fromJson(remoteMap);
          await BookSourceDao.insert(bookSource);
          localUrlSet.add(url);
          addedCount++;
        }
      } catch (e) {
        debugPrint('合并书源失败: $e');
      }
    }

    debugPrint('📡 书源合并完成: 新增 $addedCount, 已存在 $mergedCount');
  }

  /// 合并书籍数据
  Future<void> _mergeBooks(List<Map<String, dynamic>> remoteBooks) async {
    final localBooks = await _bookDao.getAllBooks();
    final localById = <int, Book>{};
    final localByHash = <String, Book>{};
    final localByPath = <String, Book>{};

    for (final localBook in localBooks) {
      if (localBook.id != null) {
        localById[localBook.id!] = localBook;
      }
      final hash = (localBook.contentHash ?? '').trim();
      if (hash.isNotEmpty) {
        localByHash[hash] = localBook;
      }
      final pathKey = _normalizePathKey(localBook.filePath);
      if (pathKey.isNotEmpty) {
        localByPath[pathKey] = localBook;
      }
    }

    for (final remoteBook in remoteBooks) {
      Book book;
      try {
        book = Book.fromMap(remoteBook);
      } catch (e) {
        debugPrint('解析远程书籍失败: $e');
        continue;
      }

      Book? localBook;
      final remoteHash = (book.contentHash ?? '').trim();
      if (remoteHash.isNotEmpty) {
        localBook = localByHash[remoteHash];
      }
      if (localBook == null && book.filePath.isNotEmpty) {
        localBook = localByPath[_normalizePathKey(book.filePath)];
      }
      if (localBook == null && book.id != null) {
        localBook = localById[book.id!];
      }

      if (localBook == null) {
        // 远程书籍在本地不存在，检查文件是否存在
        if (book.filePath.isNotEmpty && await File(book.filePath).exists()) {
          await _bookDao.insertBook(book);
        }
      } else {
        // 合并数据
        final mergedBook = _mergeBookData(localBook, book);
        if (mergedBook.currentPage != localBook.currentPage ||
            mergedBook.totalPages != localBook.totalPages ||
            mergedBook.contentHash != localBook.contentHash) {
          await _bookDao.updateBook(mergedBook);
          if (mergedBook.id != null) {
            localById[mergedBook.id!] = mergedBook;
          }
          if ((mergedBook.contentHash ?? '').trim().isNotEmpty) {
            localByHash[mergedBook.contentHash!.trim()] = mergedBook;
          }
          localByPath[_normalizePathKey(mergedBook.filePath)] = mergedBook;
        }
      }
    }
  }

  /// 合并书籍数据（以阅读进度更大的为准）
  Book _mergeBookData(Book local, Book remote) {
    final mergedCurrentPage = remote.currentPage > local.currentPage
        ? remote.currentPage
        : local.currentPage;
    final mergedTotalPages = remote.totalPages > local.totalPages
        ? remote.totalPages
        : local.totalPages;
    final mergedContentHash = (local.contentHash?.isNotEmpty ?? false)
        ? local.contentHash
        : remote.contentHash;

    return local.copyWith(
      currentPage: mergedCurrentPage,
      totalPages: mergedTotalPages,
      contentHash: mergedContentHash,
    );
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
    await prefs.remove('webdav_selected_books');

    _stopAutoSync();
    _serverUrl = '';
    _username = '';
    _password = '';
    _autoSync = true;
    _syncInterval = 30;
    _lastSyncTime = null;
    _lastErrorMessage = '';
    _isConfigured = false;
    _selectedBooksForSync.clear();
    _statusNotifier.value = SyncStatus.notConfigured;
    _dio.interceptors.clear();
    _dio.options.baseUrl = '';
  }

  /// 释放资源
  void dispose() {
    _stopAutoSync();
    _connectivitySubscription?.cancel();
    _dio.close();
  }

  Map<String, dynamic> _asJsonMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is String && data.isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }
    throw const FormatException('响应不是有效的 JSON 对象');
  }

  List<Map<String, dynamic>> _asJsonList(dynamic data) {
    if (data is! List) {
      return const [];
    }
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _normalizePathKey(String path) {
    return path.trim().replaceAll('\\', '/').toLowerCase();
  }

  bool _isRemoteFileMissing(Object error) {
    return error is DioException && error.response?.statusCode == 404;
  }

  Future<void> _runSyncStage(
    String stageName,
    Future<void> Function() action, {
    bool optional = false,
  }) async {
    try {
      await action();
    } catch (e) {
      final friendly = '$stageName失败：${_toFriendlySyncError(e)}';
      if (optional) {
        _lastSyncWarnings.add(friendly);
        debugPrint('⚠️ $friendly');
        return;
      }
      throw Exception(friendly);
    }
  }

  Future<T> _retryRequest<T>({
    required String label,
    required Future<T> Function() action,
  }) async {
    Object? lastError;
    for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        return await action();
      } catch (e) {
        lastError = e;
        if (!_isRetryableError(e) || attempt >= _maxRetryAttempts) {
          break;
        }
        final backoffMs = 500 * (1 << (attempt - 1));
        debugPrint(
          'WebDAV重试[$attempt/$_maxRetryAttempts] $label，等待 ${backoffMs}ms，原因: $e',
        );
        await Future.delayed(Duration(milliseconds: backoffMs));
      }
    }
    throw lastError ?? Exception('$label 请求失败');
  }

  bool _isRetryableError(Object error) {
    if (error is! DioException) {
      return false;
    }
    final code = error.response?.statusCode ?? 0;
    if (code == 429 ||
        code == 500 ||
        code == 502 ||
        code == 503 ||
        code == 504) {
      return true;
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return true;
    }
    return false;
  }

  String _toFriendlySyncError(Object error) {
    if (error is DioException) {
      final code = error.response?.statusCode;
      if (code == 503) {
        return '服务器暂时不可用（503），请稍后重试';
      }
      if (code == 429) {
        return '请求过于频繁（429），请稍后再试';
      }
      if (code == 401 || code == 403) {
        return '认证失败，请检查 WebDAV 账号或密码';
      }
      if (code != null && code > 0) {
        return '服务器返回异常状态码（$code）';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return '网络超时，请检查网络后重试';
      }
      if (error.type == DioExceptionType.connectionError) {
        return '网络连接失败，请检查网络或服务器地址';
      }
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    final text = error.toString();
    if (text.contains('503')) {
      return '服务器暂时不可用（503），请稍后重试';
    }
    if (text.contains('401') || text.contains('403')) {
      return '认证失败，请检查 WebDAV 账号或密码';
    }
    if (text.length > 120) {
      return text.substring(0, 120);
    }
    return text;
  }
}
