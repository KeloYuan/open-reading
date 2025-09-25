import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'book_dao.dart';

/// 阅读进度保存服务
/// 参考anx-reader的数据持久化机制，提供完整的进度管理
class ReadingProgressService {
  static final ReadingProgressService _instance =
      ReadingProgressService._internal();
  factory ReadingProgressService() => _instance;
  ReadingProgressService._internal();

  final BookDao _bookDao = BookDao();

  // 缓存管理
  final Map<String, ReadingProgress> _progressCache = {};
  final Map<String, Timer> _saveTimers = {};

  // 配置
  static const Duration _saveDelay = Duration(seconds: 2); // 防抖延迟
  static const Duration _forceInterval = Duration(seconds: 30); // 强制保存间隔
  static const Duration _criticalSaveInterval = Duration(seconds: 5); // 关键保存间隔

  Timer? _forceSaveTimer;
  Timer? _criticalSaveTimer;
  bool _isInitialized = false;

  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _loadCachedProgress();
    _startPeriodicSave();
    _isInitialized = true;

    debugPrint('阅读进度服务已初始化');
  }

  /// 加载缓存的进度
  Future<void> _loadCachedProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKeys = prefs.getKeys().where(
        (key) => key.startsWith('progress_cache_'),
      );

      for (final key in cacheKeys) {
        final jsonStr = prefs.getString(key);
        if (jsonStr != null) {
          try {
            final progress = ReadingProgress.fromJson(jsonStr);
            _progressCache[progress.bookId] = progress;
          } catch (e) {
            debugPrint('加载进度缓存失败: $key, $e');
          }
        }
      }

      debugPrint('已加载 ${_progressCache.length} 个进度缓存');
    } catch (e) {
      debugPrint('加载进度缓存失败: $e');
    }
  }

  /// 开始定期保存
  void _startPeriodicSave() {
    // 强制保存定时器
    _forceSaveTimer = Timer.periodic(_forceInterval, (_) {
      _saveAllCachedProgress();
    });

    // 关键保存定时器（用于重要操作）
    _criticalSaveTimer = Timer.periodic(_criticalSaveInterval, (_) {
      _saveCriticalProgress();
    });
  }

  /// 更新阅读进度
  Future<void> updateProgress({
    required String bookId,
    required int bookDatabaseId,
    String? cfi,
    int? currentPage,
    int? totalPages,
    double? progress,
    String? chapterTitle,
    bool immediate = false,
    bool critical = false,
  }) async {
    try {
      final readingProgress = ReadingProgress(
        bookId: bookId,
        bookDatabaseId: bookDatabaseId,
        cfi: cfi,
        currentPage: currentPage,
        totalPages: totalPages,
        progress: progress,
        chapterTitle: chapterTitle,
        lastUpdated: DateTime.now(),
        isCritical: critical,
      );

      // 更新缓存
      _progressCache[bookId] = readingProgress;

      // 缓存到SharedPreferences
      await _cacheProgress(readingProgress);

      if (immediate || critical) {
        // 立即保存到数据库
        await _saveProgressToDatabase(readingProgress);
      } else {
        // 防抖延迟保存
        _scheduleSave(bookId);
      }

      debugPrint(
        '进度已更新: $bookId, 页面: $currentPage/$totalPages, 进度: ${(progress ?? 0).toStringAsFixed(2)}',
      );
    } catch (e) {
      debugPrint('更新进度失败: $e');
    }
  }

  /// 缓存进度到SharedPreferences
  Future<void> _cacheProgress(ReadingProgress progress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'progress_cache_${progress.bookId}';
      await prefs.setString(key, progress.toJson());
    } catch (e) {
      debugPrint('缓存进度失败: $e');
    }
  }

  /// 计划保存（防抖）
  void _scheduleSave(String bookId) {
    // 取消之前的定时器
    _saveTimers[bookId]?.cancel();

    // 设置新的定时器
    _saveTimers[bookId] = Timer(_saveDelay, () {
      final progress = _progressCache[bookId];
      if (progress != null) {
        _saveProgressToDatabase(progress);
      }
      _saveTimers.remove(bookId);
    });
  }

  /// 保存进度到数据库
  Future<void> _saveProgressToDatabase(ReadingProgress progress) async {
    try {
      // 获取书籍信息
      final book = await _bookDao.getBookById(progress.bookDatabaseId);
      if (book == null) {
        debugPrint('书籍不存在: ${progress.bookDatabaseId}');
        return;
      }

      // 更新书籍进度
      final updatedBook = book.copyWith(
        currentPage: progress.currentPage ?? book.currentPage,
        totalPages: progress.totalPages ?? book.totalPages,
      );

      await _bookDao.updateBook(updatedBook);

      // 清除缓存中的critical标记
      if (_progressCache.containsKey(progress.bookId)) {
        _progressCache[progress.bookId] = progress.copyWith(isCritical: false);
      }

      debugPrint('进度已保存到数据库: ${progress.bookId}');
    } catch (e) {
      debugPrint('保存进度到数据库失败: $e');
    }
  }

  /// 保存所有缓存的进度
  Future<void> _saveAllCachedProgress() async {
    final progressList = _progressCache.values.toList();

    for (final progress in progressList) {
      await _saveProgressToDatabase(progress);
    }

    if (progressList.isNotEmpty) {
      debugPrint('强制保存了 ${progressList.length} 个进度');
    }
  }

  /// 保存关键进度
  Future<void> _saveCriticalProgress() async {
    final criticalProgress = _progressCache.values
        .where((progress) => progress.isCritical)
        .toList();

    for (final progress in criticalProgress) {
      await _saveProgressToDatabase(progress);
    }

    if (criticalProgress.isNotEmpty) {
      debugPrint('关键保存了 ${criticalProgress.length} 个进度');
    }
  }

  /// 获取书籍进度
  ReadingProgress? getProgress(String bookId) {
    return _progressCache[bookId];
  }

  /// 清除书籍进度缓存
  Future<void> clearProgress(String bookId) async {
    _progressCache.remove(bookId);
    _saveTimers[bookId]?.cancel();
    _saveTimers.remove(bookId);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('progress_cache_$bookId');
    } catch (e) {
      debugPrint('清除进度缓存失败: $e');
    }
  }

  /// 强制保存所有进度
  Future<void> forceSaveAll() async {
    // 取消所有防抖定时器，立即保存
    for (final timer in _saveTimers.values) {
      timer.cancel();
    }
    _saveTimers.clear();

    await _saveAllCachedProgress();
    debugPrint('已强制保存所有进度');
  }

  /// 应用暂停时保存
  Future<void> onAppPaused() async {
    await forceSaveAll();
    debugPrint('应用暂停，已保存所有进度');
  }

  /// 应用恢复时的处理
  Future<void> onAppResumed() async {
    // 重新开始定时器
    _startPeriodicSave();
    debugPrint('应用恢复，重新启动定时保存');
  }

  /// 获取缓存统计
  Map<String, dynamic> getCacheStats() {
    final totalCached = _progressCache.length;
    final criticalCached = _progressCache.values
        .where((progress) => progress.isCritical)
        .length;
    final pendingSaves = _saveTimers.length;

    return {
      'totalCached': totalCached,
      'criticalCached': criticalCached,
      'pendingSaves': pendingSaves,
      'isInitialized': _isInitialized,
    };
  }

  /// 释放资源
  Future<void> dispose() async {
    _forceSaveTimer?.cancel();
    _forceSaveTimer = null;
    _criticalSaveTimer?.cancel();
    _criticalSaveTimer = null;

    for (final timer in _saveTimers.values) {
      timer.cancel();
    }
    _saveTimers.clear();

    // 最后一次保存
    await _saveAllCachedProgress();

    _isInitialized = false;
    debugPrint('阅读进度服务已释放');
  }
}

/// 阅读进度数据模型
class ReadingProgress {
  final String bookId;
  final int bookDatabaseId;
  final String? cfi;
  final int? currentPage;
  final int? totalPages;
  final double? progress;
  final String? chapterTitle;
  final DateTime lastUpdated;
  final bool isCritical;

  const ReadingProgress({
    required this.bookId,
    required this.bookDatabaseId,
    this.cfi,
    this.currentPage,
    this.totalPages,
    this.progress,
    this.chapterTitle,
    required this.lastUpdated,
    this.isCritical = false,
  });

  ReadingProgress copyWith({
    String? bookId,
    int? bookDatabaseId,
    String? cfi,
    int? currentPage,
    int? totalPages,
    double? progress,
    String? chapterTitle,
    DateTime? lastUpdated,
    bool? isCritical,
  }) {
    return ReadingProgress(
      bookId: bookId ?? this.bookId,
      bookDatabaseId: bookDatabaseId ?? this.bookDatabaseId,
      cfi: cfi ?? this.cfi,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      progress: progress ?? this.progress,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isCritical: isCritical ?? this.isCritical,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookId': bookId,
      'bookDatabaseId': bookDatabaseId,
      'cfi': cfi,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'progress': progress,
      'chapterTitle': chapterTitle,
      'lastUpdated': lastUpdated.toIso8601String(),
      'isCritical': isCritical,
    };
  }

  String toJson() {
    return '''
{
  "bookId": "$bookId",
  "bookDatabaseId": $bookDatabaseId,
  "cfi": ${cfi != null ? '"$cfi"' : 'null'},
  "currentPage": $currentPage,
  "totalPages": $totalPages,
  "progress": $progress,
  "chapterTitle": ${chapterTitle != null ? '"$chapterTitle"' : 'null'},
  "lastUpdated": "${lastUpdated.toIso8601String()}",
  "isCritical": $isCritical
}
''';
  }

  static ReadingProgress fromJson(String jsonStr) {
    final RegExp bookIdRegex = RegExp(r'"bookId":\s*"([^"]*)"');
    final RegExp bookDatabaseIdRegex = RegExp(r'"bookDatabaseId":\s*(\d+)');
    final RegExp cfiRegex = RegExp(r'"cfi":\s*"([^"]*)"');
    final RegExp currentPageRegex = RegExp(r'"currentPage":\s*(\d+)');
    final RegExp totalPagesRegex = RegExp(r'"totalPages":\s*(\d+)');
    final RegExp progressRegex = RegExp(r'"progress":\s*([\d.]+)');
    final RegExp chapterTitleRegex = RegExp(r'"chapterTitle":\s*"([^"]*)"');
    final RegExp lastUpdatedRegex = RegExp(r'"lastUpdated":\s*"([^"]*)"');
    final RegExp isCriticalRegex = RegExp(r'"isCritical":\s*(true|false)');

    return ReadingProgress(
      bookId: bookIdRegex.firstMatch(jsonStr)?.group(1) ?? '',
      bookDatabaseId: int.parse(
        bookDatabaseIdRegex.firstMatch(jsonStr)?.group(1) ?? '0',
      ),
      cfi: cfiRegex.firstMatch(jsonStr)?.group(1),
      currentPage: int.tryParse(
        currentPageRegex.firstMatch(jsonStr)?.group(1) ?? '',
      ),
      totalPages: int.tryParse(
        totalPagesRegex.firstMatch(jsonStr)?.group(1) ?? '',
      ),
      progress: double.tryParse(
        progressRegex.firstMatch(jsonStr)?.group(1) ?? '',
      ),
      chapterTitle: chapterTitleRegex.firstMatch(jsonStr)?.group(1),
      lastUpdated: DateTime.parse(
        lastUpdatedRegex.firstMatch(jsonStr)?.group(1) ??
            DateTime.now().toIso8601String(),
      ),
      isCritical: isCriticalRegex.firstMatch(jsonStr)?.group(1) == 'true',
    );
  }
}
