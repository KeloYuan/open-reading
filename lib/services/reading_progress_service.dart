import 'dart:async';
import 'package:flutter/foundation.dart';
import 'data_cache_service.dart';
import 'book_dao.dart';

/// 阅读进度管理服务
///
/// 负责管理用户的阅读进度，包括实时保存、自动同步、
/// 进度恢复和跨设备同步等功能
///
/// 核心功能：
/// - 实时进度保存
/// - 智能批量更新
/// - 进度历史记录
/// - 断点续读支持
class ReadingProgressService {
  static final ReadingProgressService _instance =
      ReadingProgressService._internal();
  factory ReadingProgressService() => _instance;
  ReadingProgressService._internal();

  // 依赖服务
  final DataCacheService _cacheService = DataCacheService();
  final BookDao _bookDao = BookDao();

  // 进度更新定时器
  Timer? _progressSaveTimer;
  Timer? _batchUpdateTimer;

  // 待保存的进度数据
  final Map<int, ReadingProgressData> _pendingUpdates = {};
  final Map<int, DateTime> _lastUpdateTime = {};

  // 配置参数
  static const Duration _progressSaveInterval = Duration(seconds: 10);
  static const Duration _batchUpdateInterval = Duration(seconds: 30);

  /// 初始化阅读进度服务
  Future<void> initialize() async {
    debugPrint('📚 初始化阅读进度服务');

    try {
      // 启动定时器
      _startProgressSaveTimer();
      _startBatchUpdateTimer();

      // 恢复待保存的进度数据
      await _restorePendingProgress();

      debugPrint('✅ 阅读进度服务初始化成功');
    } catch (e) {
      debugPrint('❌ 阅读进度服务初始化失败: $e');
      rethrow;
    }
  }

  /// 销毁阅读进度服务
  Future<void> dispose() async {
    debugPrint('🛑 销毁阅读进度服务');

    try {
      // 停止定时器
      _progressSaveTimer?.cancel();
      _batchUpdateTimer?.cancel();

      // 保存所有待更新的进度
      await _saveAllPendingProgress();

      // 清理数据
      _pendingUpdates.clear();
      _lastUpdateTime.clear();

      debugPrint('✅ 阅读进度服务销毁完成');
    } catch (e) {
      debugPrint('❌ 阅读进度服务销毁失败: $e');
    }
  }

  /// 更新阅读进度
  ///
  /// [bookId] 书籍ID
  /// [currentPage] 当前页数
  /// [totalPages] 总页数，可选
  /// [readingPosition] 阅读位置信息，可选
  /// [chapterInfo] 章节信息，可选
  /// [immediateSync] 是否立即同步到数据库
  Future<void> updateProgress(
    int bookId,
    int currentPage, {
    int? totalPages,
    Map<String, dynamic>? readingPosition,
    Map<String, dynamic>? chapterInfo,
    bool immediateSync = false,
  }) async {
    try {
      final now = DateTime.now();

      // 创建进度数据
      final progressData = ReadingProgressData(
        bookId: bookId,
        currentPage: currentPage,
        totalPages: totalPages,
        readingPosition: readingPosition,
        chapterInfo: chapterInfo,
        lastReadTime: now,
      );

      // 更新内存缓存
      _pendingUpdates[bookId] = progressData;
      _lastUpdateTime[bookId] = now;

      // 缓存到本地存储
      await _cacheService.setCache(
        'reading_progress_$bookId',
        progressData.toJson(),
        persistImmediately: true,
      );

      debugPrint(
        '📖 更新阅读进度: 书籍[$bookId] 页面[$currentPage/${totalPages ?? "?"}]',
      );

      // 如果需要立即同步，直接保存到数据库
      if (immediateSync) {
        await _saveProgressToDatabase(progressData);
        _pendingUpdates.remove(bookId);
        debugPrint('💾 立即同步进度到数据库: 书籍[$bookId]');
      }
    } catch (e) {
      debugPrint('❌ 更新阅读进度失败: 书籍[$bookId], 错误: $e');
      rethrow;
    }
  }

  /// 获取阅读进度
  ///
  /// [bookId] 书籍ID
  /// Returns: 阅读进度数据，如果不存在则返回null
  Future<ReadingProgressData?> getProgress(int bookId) async {
    try {
      // 首先检查内存中的待更新数据
      if (_pendingUpdates.containsKey(bookId)) {
        final progress = _pendingUpdates[bookId]!;
        debugPrint('📖 从内存获取阅读进度: 书籍[$bookId] 页面[${progress.currentPage}]');
        return progress;
      }

      // 检查缓存
      final cachedData = _cacheService.getCache<Map<String, dynamic>>(
        'reading_progress_$bookId',
      );
      if (cachedData != null) {
        final progress = ReadingProgressData.fromJson(cachedData);
        debugPrint('📖 从缓存获取阅读进度: 书籍[$bookId] 页面[${progress.currentPage}]');
        return progress;
      }

      // 从数据库获取
      final book = await _bookDao.getBookById(bookId);
      if (book != null) {
        final progress = ReadingProgressData(
          bookId: bookId,
          currentPage: book.currentPage,
          totalPages: book.totalPages,
          lastReadTime: book.importDate,
        );

        // 缓存到本地
        await _cacheService.setCache(
          'reading_progress_$bookId',
          progress.toJson(),
        );

        debugPrint('📖 从数据库获取阅读进度: 书籍[$bookId] 页面[${progress.currentPage}]');
        return progress;
      }

      debugPrint('📖 未找到阅读进度: 书籍[$bookId]');
      return null;
    } catch (e) {
      debugPrint('❌ 获取阅读进度失败: 书籍[$bookId], 错误: $e');
      return null;
    }
  }

  /// 获取阅读历史记录
  ///
  /// [bookId] 书籍ID
  /// [limit] 限制返回条数，默认10
  /// Returns: 阅读历史记录列表
  Future<List<ReadingProgressData>> getProgressHistory(
    int bookId, {
    int limit = 10,
  }) async {
    try {
      final historyKey = 'reading_history_$bookId';
      final cachedHistory = _cacheService.getCache<List<dynamic>>(
        historyKey,
        <dynamic>[],
      );

      final history = (cachedHistory ?? <dynamic>[])
          .map(
            (item) =>
                ReadingProgressData.fromJson(item as Map<String, dynamic>),
          )
          .toList();

      // 按时间倒序排列
      history.sort((a, b) => b.lastReadTime.compareTo(a.lastReadTime));

      // 限制返回数量
      if (history.length > limit) {
        return history.take(limit).toList();
      }

      debugPrint('📜 获取阅读历史: 书籍[$bookId] 共${history.length}条记录');
      return history;
    } catch (e) {
      debugPrint('❌ 获取阅读历史失败: 书籍[$bookId], 错误: $e');
      return [];
    }
  }

  /// 保存阅读历史快照
  ///
  /// [progressData] 进度数据
  Future<void> _saveProgressHistory(ReadingProgressData progressData) async {
    try {
      final historyKey = 'reading_history_${progressData.bookId}';
      final cachedHistory = _cacheService.getCache<List<dynamic>>(
        historyKey,
        <dynamic>[],
      );

      final history = (cachedHistory ?? <dynamic>[])
          .map(
            (item) =>
                ReadingProgressData.fromJson(item as Map<String, dynamic>),
          )
          .toList();

      // 添加新记录
      history.add(progressData);

      // 保持最近50条记录
      if (history.length > 50) {
        history.sort((a, b) => b.lastReadTime.compareTo(a.lastReadTime));
        history.removeRange(50, history.length);
      }

      // 保存到缓存
      await _cacheService.setCache(
        historyKey,
        history.map((item) => item.toJson()).toList(),
      );

      debugPrint('📜 保存阅读历史快照: 书籍[${progressData.bookId}]');
    } catch (e) {
      debugPrint('❌ 保存阅读历史失败: $e');
    }
  }

  /// 获取所有书籍的进度摘要
  ///
  /// Returns: 书籍进度摘要Map，key为书籍ID，value为进度百分比
  Future<Map<int, double>> getAllProgressSummary() async {
    try {
      final summary = <int, double>{};

      // 从待更新数据中获取
      for (final entry in _pendingUpdates.entries) {
        final progress = entry.value;
        if (progress.totalPages != null && progress.totalPages! > 0) {
          summary[entry.key] = progress.currentPage / progress.totalPages!;
        }
      }

      // 从数据库获取其他书籍进度
      final allBooks = await _bookDao.getAllBooks();
      for (final book in allBooks) {
        if (book.id != null &&
            !summary.containsKey(book.id) &&
            book.totalPages > 0) {
          summary[book.id!] = book.currentPage / book.totalPages;
        }
      }

      debugPrint('📊 获取进度摘要: 共${summary.length}本书籍');
      return summary;
    } catch (e) {
      debugPrint('❌ 获取进度摘要失败: $e');
      return {};
    }
  }

  /// 启动进度保存定时器
  void _startProgressSaveTimer() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer.periodic(_progressSaveInterval, (timer) async {
      if (_pendingUpdates.isNotEmpty) {
        debugPrint('⏰ 进度保存定时器触发，待保存: ${_pendingUpdates.length}项');
        try {
          await _saveRecentProgress();
        } catch (e) {
          debugPrint('❌ 定时保存进度失败: $e');
        }
      }
    });
    debugPrint('⏰ 进度保存定时器已启动，间隔: ${_progressSaveInterval.inSeconds}秒');
  }

  /// 启动批量更新定时器
  void _startBatchUpdateTimer() {
    _batchUpdateTimer?.cancel();
    _batchUpdateTimer = Timer.periodic(_batchUpdateInterval, (timer) async {
      if (_pendingUpdates.isNotEmpty) {
        debugPrint('📦 批量更新定时器触发，待更新: ${_pendingUpdates.length}项');
        try {
          await _saveAllPendingProgress();
        } catch (e) {
          debugPrint('❌ 批量更新失败: $e');
        }
      }
    });
    debugPrint('📦 批量更新定时器已启动，间隔: ${_batchUpdateInterval.inSeconds}秒');
  }

  /// 保存最近更新的进度
  Future<void> _saveRecentProgress() async {
    final now = DateTime.now();
    final recentUpdates = <int, ReadingProgressData>{};

    // 筛选最近更新的进度（10秒内）
    for (final entry in _pendingUpdates.entries) {
      final lastUpdate = _lastUpdateTime[entry.key];
      if (lastUpdate != null && now.difference(lastUpdate).inSeconds <= 10) {
        recentUpdates[entry.key] = entry.value;
      }
    }

    // 保存到数据库
    for (final progressData in recentUpdates.values) {
      await _saveProgressToDatabase(progressData);
      await _saveProgressHistory(progressData);
    }

    // 从待更新列表中移除
    for (final bookId in recentUpdates.keys) {
      _pendingUpdates.remove(bookId);
    }

    if (recentUpdates.isNotEmpty) {
      debugPrint('💾 保存最近进度: ${recentUpdates.length}项');
    }
  }

  /// 保存所有待更新的进度
  Future<void> _saveAllPendingProgress() async {
    if (_pendingUpdates.isEmpty) return;

    final pendingSnapshot = Map<int, ReadingProgressData>.from(_pendingUpdates);

    try {
      // 批量保存到数据库
      for (final progressData in pendingSnapshot.values) {
        await _saveProgressToDatabase(progressData);
        await _saveProgressHistory(progressData);
      }

      // 清理已保存的数据
      for (final bookId in pendingSnapshot.keys) {
        _pendingUpdates.remove(bookId);
      }

      debugPrint('💾 批量保存进度完成: ${pendingSnapshot.length}项');
    } catch (e) {
      debugPrint('❌ 批量保存进度失败: $e');
      rethrow;
    }
  }

  /// 保存进度到数据库
  Future<void> _saveProgressToDatabase(ReadingProgressData progressData) async {
    try {
      await _bookDao.updateBookProgress(
        progressData.bookId,
        progressData.currentPage,
      );

      debugPrint(
        '💾 进度已保存到数据库: 书籍[${progressData.bookId}] 页面[${progressData.currentPage}]',
      );
    } catch (e) {
      debugPrint('❌ 保存进度到数据库失败: 书籍[${progressData.bookId}], 错误: $e');
      rethrow;
    }
  }

  /// 恢复待保存的进度数据
  Future<void> _restorePendingProgress() async {
    try {
      // 从缓存中恢复进度数据
      final allBooks = await _bookDao.getAllBooks();
      for (final book in allBooks) {
        final cachedData = _cacheService.getCache<Map<String, dynamic>>(
          'reading_progress_${book.id}',
        );
        if (cachedData != null) {
          final progressData = ReadingProgressData.fromJson(cachedData);

          // 检查缓存是否比数据库更新
          if (progressData.currentPage != book.currentPage && book.id != null) {
            _pendingUpdates[book.id!] = progressData;
            _lastUpdateTime[book.id!] = progressData.lastReadTime;
            debugPrint(
              '🔄 恢复待保存进度: 书籍[${book.id}] 页面[${progressData.currentPage}]',
            );
          }
        }
      }

      if (_pendingUpdates.isNotEmpty) {
        debugPrint('🔄 恢复待保存进度完成: ${_pendingUpdates.length}项');
      }
    } catch (e) {
      debugPrint('❌ 恢复待保存进度失败: $e');
    }
  }
}

/// 阅读进度数据模型
class ReadingProgressData {
  final int bookId;
  final int currentPage;
  final int? totalPages;
  final Map<String, dynamic>? readingPosition;
  final Map<String, dynamic>? chapterInfo;
  final DateTime lastReadTime;

  const ReadingProgressData({
    required this.bookId,
    required this.currentPage,
    this.totalPages,
    this.readingPosition,
    this.chapterInfo,
    required this.lastReadTime,
  });

  /// 从JSON创建实例
  factory ReadingProgressData.fromJson(Map<String, dynamic> json) {
    return ReadingProgressData(
      bookId: json['bookId'] as int,
      currentPage: json['currentPage'] as int,
      totalPages: json['totalPages'] as int?,
      readingPosition: json['readingPosition'] as Map<String, dynamic>?,
      chapterInfo: json['chapterInfo'] as Map<String, dynamic>?,
      lastReadTime: DateTime.parse(json['lastReadTime'] as String),
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'readingPosition': readingPosition,
      'chapterInfo': chapterInfo,
      'lastReadTime': lastReadTime.toIso8601String(),
    };
  }

  /// 计算阅读进度百分比
  double get progressPercentage {
    if (totalPages == null || totalPages! <= 0) return 0.0;
    return (currentPage / totalPages!).clamp(0.0, 1.0);
  }

  /// 获取可读的进度描述
  String get progressDescription {
    if (totalPages == null) {
      return '第 $currentPage 页';
    } else {
      final percentage = (progressPercentage * 100).toStringAsFixed(1);
      return '第 $currentPage 页 / 共 $totalPages 页 ($percentage%)';
    }
  }

  @override
  String toString() {
    return 'ReadingProgressData(bookId: $bookId, currentPage: $currentPage, totalPages: $totalPages, lastReadTime: $lastReadTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReadingProgressData &&
        other.bookId == bookId &&
        other.currentPage == currentPage &&
        other.totalPages == totalPages;
  }

  @override
  int get hashCode {
    return Object.hash(bookId, currentPage, totalPages);
  }
}
