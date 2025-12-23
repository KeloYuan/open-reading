import 'dart:developer' as developer;
import 'dart:async';
import 'package:flutter/foundation.dart';

/// 性能监控服务
///
/// 用于监控应用各项性能指标，包括：
/// - 操作耗时
/// - 内存使用
/// - 缓存命中率
/// - 数据库查询性能
/// - 文件I/O性能
class PerformanceMonitorService {
  // 单例模式
  static final PerformanceMonitorService _instance =
      PerformanceMonitorService._internal();
  factory PerformanceMonitorService() => _instance;
  PerformanceMonitorService._internal();

  // 性能指标存储
  final Map<String, List<int>> _operationTimes = {};
  final Map<String, DateTime> _startTimes = {};
  final Map<String, int> _operationCounts = {};

  // 内存监控
  final List<MemorySnapshot> _memorySnapshots = [];
  Timer? _memoryTimer;

  // 缓存统计
  final Map<String, CacheStats> _cacheStats = {};

  /// 开始计时操作
  ///
  /// [operationName] 操作名称
  void startTimer(String operationName) {
    _startTimes[operationName] = DateTime.now();
  }

  /// 结束计时操作
  ///
  /// [operationName] 操作名称
  /// [logResult] 是否记录日志
  void endTimer(String operationName, {bool logResult = true}) {
    final startTime = _startTimes[operationName];
    if (startTime == null) {
      debugPrint('⚠️ 性能监控：未找到操作开始时间 $operationName');
      return;
    }

    final duration = DateTime.now().difference(startTime).inMilliseconds;
    _recordMetric(operationName, duration, logResult: logResult);
    _startTimes.remove(operationName);
  }

  /// 记录性能指标
  ///
  /// [operationName] 操作名称
  /// [duration] 耗时（毫秒）
  /// [logResult] 是否记录日志
  void _recordMetric(String operationName, int duration,
      {bool logResult = true}) {
    // 存储指标
    if (!_operationTimes.containsKey(operationName)) {
      _operationTimes[operationName] = [];
    }
    _operationTimes[operationName]!.add(duration);

    // 更新计数
    _operationCounts[operationName] =
        (_operationCounts[operationName] ?? 0) + 1;

    // 记录日志
    if (logResult) {
      final avgTime = _getAverageTime(operationName);
      final count = _operationCounts[operationName] ?? 0;

      debugPrint('⏱️ 性能监控: $operationName');
      debugPrint('   当前耗时: ${duration}ms');
      debugPrint('   平均耗时: ${avgTime.toStringAsFixed(1)}ms');
      debugPrint('   执行次数: $count');

      // 性能警告
      if (duration > _getSlowThreshold(operationName)) {
        debugPrint('⚠️ 性能警告: $operationName 执行过慢 (${duration}ms)');
      }
    }

    // 发送到分析服务（生产环境）
    if (!kDebugMode) {
      _sendToAnalytics(operationName, duration);
    }
  }

  /// 获取操作的平均耗时
  ///
  /// [operationName] 操作名称
  double _getAverageTime(String operationName) {
    final times = _operationTimes[operationName];
    if (times == null || times.isEmpty) return 0.0;

    return times.reduce((a, b) => a + b) / times.length;
  }

  /// 获取操作的慢阈值
  ///
  /// [operationName] 操作名称
  int _getSlowThreshold(String operationName) {
    final thresholds = {
      'database_query': 100,
      'file_read': 500,
      'file_write': 1000,
      'image_decode': 200,
      'pagination': 300,
      'text_rendering': 50,
      'ui_build': 16, // 60fps
      'book_import': 5000,
    };

    return thresholds[operationName] ?? 1000;
  }

  /// 开始内存监控
  void startMemoryMonitoring() {
    _memoryTimer?.cancel();
    _memoryTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _captureMemorySnapshot();
    });
    debugPrint('📊 内存监控已启动');
  }

  /// 停止内存监控
  void stopMemoryMonitoring() {
    _memoryTimer?.cancel();
    _memoryTimer = null;
    debugPrint('📊 内存监控已停止');
  }

  /// 捕获内存快照
  void _captureMemorySnapshot() {
    // 注意：在Flutter中获取精确内存使用情况需要平台特定代码
    // 这里提供一个基础实现
    final snapshot = MemorySnapshot(
      timestamp: DateTime.now(),
      // 这些值需要通过平台通道获取
      totalMemory: 0, // MB
      usedMemory: 0, // MB
      cacheMemory: 0, // MB
    );

    _memorySnapshots.add(snapshot);

    // 保持最近100个快照
    if (_memorySnapshots.length > 100) {
      _memorySnapshots.removeAt(0);
    }

    // 内存警告
    if (snapshot.usedMemory > 200) {
      // 200MB警告阈值
      debugPrint('⚠️ 内存警告: 当前使用 ${snapshot.usedMemory}MB');
    }
  }

  /// 记录缓存统计
  ///
  /// [cacheName] 缓存名称
  /// [hit] 是否命中
  /// [size] 缓存大小（可选）
  void recordCacheHit(String cacheName, bool hit, {int? size}) {
    if (!_cacheStats.containsKey(cacheName)) {
      _cacheStats[cacheName] = CacheStats();
    }

    final stats = _cacheStats[cacheName]!;
    if (hit) {
      stats.hits++;
    } else {
      stats.misses++;
    }

    if (size != null) {
      stats.totalSize = size;
    }

    // 每100次访问输出一次统计
    if ((stats.hits + stats.misses) % 100 == 0) {
      final hitRate = stats.getHitRate();
      debugPrint('📦 缓存统计: $cacheName');
      debugPrint('   命中率: ${(hitRate * 100).toStringAsFixed(1)}%');
      debugPrint('   总大小: ${stats.totalSize}MB');
    }
  }

  /// 获取性能报告
  PerformanceReport getPerformanceReport() {
    final report = PerformanceReport();

    // 操作性能
    for (final entry in _operationTimes.entries) {
      final operation = entry.key;
      final times = entry.value;

      if (times.isNotEmpty) {
        final avgTime = times.reduce((a, b) => a + b) / times.length;
        final maxTime = times.reduce((a, b) => a > b ? a : b);
        final minTime = times.reduce((a, b) => a < b ? a : b);

        report.operations.add(OperationStats(
          name: operation,
          count: times.length,
          avgTime: avgTime,
          maxTime: maxTime,
          minTime: minTime,
        ));
      }
    }

    // 缓存统计
    for (final entry in _cacheStats.entries) {
      report.caches.add(entry.value);
    }

    // 内存统计
    if (_memorySnapshots.isNotEmpty) {
      final latest = _memorySnapshots.last;
      report.memoryUsage = latest.usedMemory;
    }

    return report;
  }

  /// 清除所有统计数据
  void clearAllStats() {
    _operationTimes.clear();
    _startTimes.clear();
    _operationCounts.clear();
    _memorySnapshots.clear();
    _cacheStats.clear();
    debugPrint('🗑️ 性能统计数据已清除');
  }

  /// 发送数据到分析服务
  void _sendToAnalytics(String operationName, int duration) {
    // 实现发送到分析服务的逻辑
    // 例如：Firebase Analytics, 自定义分析服务
    developer.log('Performance metric: $operationName = ${duration}ms');
  }

  /// 监控函数执行时间
  ///
  /// [function] 要监控的函数
  /// [operationName] 操作名称
  Future<T> monitorFunction<T>(
    Future<T> Function() function,
    String operationName,
  ) async {
    startTimer(operationName);
    try {
      final result = await function();
      endTimer(operationName);
      return result;
    } catch (e) {
      endTimer(operationName);
      rethrow;
    }
  }

  /// 监控同步函数执行时间
  ///
  /// [function] 要监控的函数
  /// [operationName] 操作名称
  T monitorSyncFunction<T>(
    T Function() function,
    String operationName,
  ) {
    startTimer(operationName);
    try {
      final result = function();
      endTimer(operationName);
      return result;
    } catch (e) {
      endTimer(operationName);
      rethrow;
    }
  }
}

/// 内存快照
class MemorySnapshot {
  final DateTime timestamp;
  final int totalMemory; // MB
  final int usedMemory; // MB
  final int cacheMemory; // MB

  MemorySnapshot({
    required this.timestamp,
    required this.totalMemory,
    required this.usedMemory,
    required this.cacheMemory,
  });
}

/// 缓存统计
class CacheStats {
  int hits = 0;
  int misses = 0;
  int totalSize = 0; // MB

  double getHitRate() {
    final total = hits + misses;
    return total > 0 ? hits / total : 0.0;
  }
}

/// 操作统计
class OperationStats {
  final String name;
  final int count;
  final double avgTime;
  final int maxTime;
  final int minTime;

  OperationStats({
    required this.name,
    required this.count,
    required this.avgTime,
    required this.maxTime,
    required this.minTime,
  });
}

/// 性能报告
class PerformanceReport {
  final List<OperationStats> operations = [];
  final List<CacheStats> caches = [];
  int memoryUsage = 0; // MB

  /// 生成报告摘要
  String generateSummary() {
    final buffer = StringBuffer();
    buffer.writeln('=== 性能报告摘要 ===');

    // 操作性能摘要
    buffer.writeln('\n📊 操作性能:');
    for (final op in operations) {
      buffer.writeln(
          '  ${op.name}: 平均${op.avgTime.toStringAsFixed(1)}ms (${op.count}次)');
    }

    // 缓存命中率
    buffer.writeln('\n📦 缓存性能:');
    for (final cache in caches) {
      final hitRate = cache.getHitRate();
      buffer.writeln('  命中率: ${(hitRate * 100).toStringAsFixed(1)}%');
    }

    // 内存使用
    buffer.writeln('\n💾 内存使用: ${memoryUsage}MB');

    return buffer.toString();
  }
}

/// 性能监控装饰器
///
/// 用于装饰函数以自动监控性能
class PerformanceDecorator {
  static T decorateSync<T>(
    T Function() function,
    String operationName,
  ) {
    final monitor = PerformanceMonitorService();
    return monitor.monitorSyncFunction(function, operationName);
  }

  static Future<T> decorateAsync<T>(
    Future<T> Function() function,
    String operationName,
  ) {
    final monitor = PerformanceMonitorService();
    return monitor.monitorFunction(function, operationName);
  }
}

/// 使用示例扩展
extension PerformanceExtension on Future {
  /// 监控Future执行时间
  Future<T> withPerformanceMonitoring<T>(String operationName) {
    return PerformanceDecorator.decorateAsync(
        () => this as Future<T>, operationName);
  }
}
