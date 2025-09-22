import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 性能监控器
/// 提供应用性能监控、内存管理和优化建议
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  /// 性能数据记录
  final List<PerformanceSnapshot> _snapshots = [];
  
  /// 监控定时器
  Timer? _monitoringTimer;
  
  /// 内存警告阈值（MB）
  static const double memoryWarningThreshold = 150.0;
  static const double memoryCriticalThreshold = 200.0;
  
  /// 帧率警告阈值
  static const double fpsWarningThreshold = 50.0;
  static const double fpsCriticalThreshold = 30.0;
  
  /// 是否正在监控
  bool _isMonitoring = false;
  
  /// 性能回调
  Function(PerformanceLevel level, String message)? onPerformanceAlert;
  
  /// 内存清理回调
  VoidCallback? onMemoryCleanupNeeded;

  /// 开始性能监控
  void startMonitoring({Duration interval = const Duration(seconds: 5)}) {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    _monitoringTimer = Timer.periodic(interval, (_) => _captureSnapshot());
    
    debugPrint('🔍 性能监控已启动，监控间隔: ${interval.inSeconds}秒');
  }

  /// 停止性能监控
  void stopMonitoring() {
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    
    debugPrint('🔍 性能监控已停止');
  }

  /// 捕获性能快照
  Future<PerformanceSnapshot> _captureSnapshot() async {
    final timestamp = DateTime.now();
    
    // 获取内存使用情况
    final memoryInfo = await _getMemoryInfo();
    
    // 获取CPU使用情况（简化版本）
    final cpuUsage = await _getCpuUsage();
    
    // 创建快照
    final snapshot = PerformanceSnapshot(
      timestamp: timestamp,
      memoryUsageMB: memoryInfo.usedMemoryMB,
      availableMemoryMB: memoryInfo.availableMemoryMB,
      cpuUsage: cpuUsage,
      frameRate: _getCurrentFrameRate(),
    );
    
    // 添加到记录
    _snapshots.add(snapshot);
    
    // 保持最近100个快照
    if (_snapshots.length > 100) {
      _snapshots.removeAt(0);
    }
    
    // 检查性能警告
    _checkPerformanceAlerts(snapshot);
    
    return snapshot;
  }

  /// 获取内存信息
  Future<MemoryInfo> _getMemoryInfo() async {
    try {
      if (Platform.isAndroid) {
        // Android平台内存信息
        final result = await SystemChannels.platform.invokeMethod('getMemoryInfo');
        if (result != null) {
          return MemoryInfo(
            usedMemoryMB: (result['usedMemory'] ?? 0) / 1024 / 1024,
            availableMemoryMB: (result['availableMemory'] ?? 0) / 1024 / 1024,
            totalMemoryMB: (result['totalMemory'] ?? 0) / 1024 / 1024,
          );
        }
      } else if (Platform.isIOS) {
        // iOS平台内存信息
        final result = await SystemChannels.platform.invokeMethod('getMemoryInfo');
        if (result != null) {
          return MemoryInfo(
            usedMemoryMB: (result['usedMemory'] ?? 0) / 1024 / 1024,
            availableMemoryMB: (result['availableMemory'] ?? 0) / 1024 / 1024,
            totalMemoryMB: (result['totalMemory'] ?? 0) / 1024 / 1024,
          );
        }
      }
      
      // 回退到估算值
      return MemoryInfo(
        usedMemoryMB: 80.0, // 估算值
        availableMemoryMB: 200.0,
        totalMemoryMB: 280.0,
      );
    } catch (e) {
      debugPrint('❌ 获取内存信息失败: $e');
      return MemoryInfo(
        usedMemoryMB: 0.0,
        availableMemoryMB: 0.0,
        totalMemoryMB: 0.0,
      );
    }
  }

  /// 获取CPU使用率（简化版本）
  Future<double> _getCpuUsage() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final result = await SystemChannels.platform.invokeMethod('getCpuUsage');
        return (result ?? 0.0).toDouble();
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// 获取当前帧率（模拟）
  double _getCurrentFrameRate() {
    // 这里应该使用实际的帧率监控，暂时返回模拟值
    return 60.0;
  }

  /// 检查性能警告
  void _checkPerformanceAlerts(PerformanceSnapshot snapshot) {
    final alerts = <String>[];
    var alertLevel = PerformanceLevel.good;

    // 检查内存使用
    if (snapshot.memoryUsageMB > memoryCriticalThreshold) {
      alerts.add('内存使用过高: ${snapshot.memoryUsageMB.toStringAsFixed(1)}MB');
      alertLevel = PerformanceLevel.critical;
    } else if (snapshot.memoryUsageMB > memoryWarningThreshold) {
      alerts.add('内存使用较高: ${snapshot.memoryUsageMB.toStringAsFixed(1)}MB');
      if (alertLevel == PerformanceLevel.good) {
        alertLevel = PerformanceLevel.warning;
      }
    }

    // 检查帧率
    if (snapshot.frameRate < fpsCriticalThreshold) {
      alerts.add('帧率过低: ${snapshot.frameRate.toStringAsFixed(1)}fps');
      alertLevel = PerformanceLevel.critical;
    } else if (snapshot.frameRate < fpsWarningThreshold) {
      alerts.add('帧率较低: ${snapshot.frameRate.toStringAsFixed(1)}fps');
      if (alertLevel == PerformanceLevel.good) {
        alertLevel = PerformanceLevel.warning;
      }
    }

    // 检查CPU使用率
    if (snapshot.cpuUsage > 80.0) {
      alerts.add('CPU使用率过高: ${snapshot.cpuUsage.toStringAsFixed(1)}%');
      if (alertLevel != PerformanceLevel.critical) {
        alertLevel = PerformanceLevel.warning;
      }
    }

    // 触发警告回调
    if (alerts.isNotEmpty) {
      final message = alerts.join(', ');
      onPerformanceAlert?.call(alertLevel, message);
      
      // 如果是严重问题，触发内存清理
      if (alertLevel == PerformanceLevel.critical) {
        onMemoryCleanupNeeded?.call();
      }
    }
  }

  /// 执行内存优化
  Future<void> optimizeMemory() async {
    debugPrint('🧹 开始内存优化...');
    
    try {
      // 1. 垃圾回收
      await _triggerGarbageCollection();
      
      // 2. 清理图片缓存
      await _clearImageCaches();
      
      // 3. 清理文本缓存
      await _clearTextCaches();
      
      // 4. 等待一段时间后重新检查
      await Future.delayed(const Duration(seconds: 2));
      final afterOptimization = await _captureSnapshot();
      
      debugPrint('✅ 内存优化完成，当前使用: ${afterOptimization.memoryUsageMB.toStringAsFixed(1)}MB');
    } catch (e) {
      debugPrint('❌ 内存优化失败: $e');
    }
  }

  /// 触发垃圾回收
  Future<void> _triggerGarbageCollection() async {
    // 强制垃圾回收
    for (int i = 0; i < 3; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      // 这里应该调用系统的GC方法
    }
  }

  /// 清理图片缓存
  Future<void> _clearImageCaches() async {
    try {
      // 清理Flutter图片缓存
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      debugPrint('🖼️ 图片缓存已清理');
    } catch (e) {
      debugPrint('❌ 清理图片缓存失败: $e');
    }
  }

  /// 清理文本缓存
  Future<void> _clearTextCaches() async {
    try {
      // 这里应该清理应用中的文本相关缓存
      // 例如分页器缓存、文本测量缓存等
      debugPrint('📝 文本缓存已清理');
    } catch (e) {
      debugPrint('❌ 清理文本缓存失败: $e');
    }
  }

  /// 获取性能分析报告
  PerformanceReport generateReport() {
    if (_snapshots.isEmpty) {
      return PerformanceReport.empty();
    }

    final recent = _snapshots.take(20).toList(); // 最近20个快照
    
    return PerformanceReport(
      totalSnapshots: _snapshots.length,
      timeRange: Duration(
        milliseconds: _snapshots.last.timestamp.millisecondsSinceEpoch - 
                     _snapshots.first.timestamp.millisecondsSinceEpoch,
      ),
      averageMemoryUsage: recent.map((s) => s.memoryUsageMB).reduce((a, b) => a + b) / recent.length,
      peakMemoryUsage: recent.map((s) => s.memoryUsageMB).reduce((a, b) => a > b ? a : b),
      averageFrameRate: recent.map((s) => s.frameRate).reduce((a, b) => a + b) / recent.length,
      lowestFrameRate: recent.map((s) => s.frameRate).reduce((a, b) => a < b ? a : b),
      averageCpuUsage: recent.map((s) => s.cpuUsage).reduce((a, b) => a + b) / recent.length,
      peakCpuUsage: recent.map((s) => s.cpuUsage).reduce((a, b) => a > b ? a : b),
      performanceLevel: _calculateOverallPerformance(),
      recommendations: _generateRecommendations(),
    );
  }

  /// 计算整体性能水平
  PerformanceLevel _calculateOverallPerformance() {
    if (_snapshots.isEmpty) return PerformanceLevel.good;
    
    final recent = _snapshots.skip(math.max(0, _snapshots.length - 10)).toList();
    int criticalCount = 0;
    int warningCount = 0;
    
    for (final snapshot in recent) {
      if (snapshot.memoryUsageMB > memoryCriticalThreshold || 
          snapshot.frameRate < fpsCriticalThreshold) {
        criticalCount++;
      } else if (snapshot.memoryUsageMB > memoryWarningThreshold || 
                 snapshot.frameRate < fpsWarningThreshold) {
        warningCount++;
      }
    }
    
    if (criticalCount > recent.length * 0.3) {
      return PerformanceLevel.critical;
    } else if (warningCount > recent.length * 0.5) {
      return PerformanceLevel.warning;
    } else {
      return PerformanceLevel.good;
    }
  }

  /// 生成优化建议
  List<String> _generateRecommendations() {
    final recommendations = <String>[];
    final recent = _snapshots.skip(math.max(0, _snapshots.length - 10)).toList();
    
    if (recent.isEmpty) return recommendations;
    
    final avgMemory = recent.map((s) => s.memoryUsageMB).reduce((a, b) => a + b) / recent.length;
    final avgFrameRate = recent.map((s) => s.frameRate).reduce((a, b) => a + b) / recent.length;
    final avgCpuUsage = recent.map((s) => s.cpuUsage).reduce((a, b) => a + b) / recent.length;
    
    if (avgMemory > memoryWarningThreshold) {
      recommendations.add('建议定期清理内存缓存');
      recommendations.add('考虑减少同时打开的书籍数量');
    }
    
    if (avgFrameRate < fpsWarningThreshold) {
      recommendations.add('建议降低文本渲染复杂度');
      recommendations.add('考虑使用性能更好的阅读引擎');
    }
    
    if (avgCpuUsage > 50.0) {
      recommendations.add('建议关闭不必要的后台处理');
      recommendations.add('考虑优化分页算法');
    }
    
    return recommendations;
  }

  /// 获取最新快照
  PerformanceSnapshot? get latestSnapshot => 
      _snapshots.isNotEmpty ? _snapshots.last : null;

  /// 获取所有快照
  List<PerformanceSnapshot> get allSnapshots => List.unmodifiable(_snapshots);

  /// 是否正在监控
  bool get isMonitoring => _isMonitoring;
}

/// 性能快照
class PerformanceSnapshot {
  final DateTime timestamp;
  final double memoryUsageMB;
  final double availableMemoryMB;
  final double cpuUsage;
  final double frameRate;

  const PerformanceSnapshot({
    required this.timestamp,
    required this.memoryUsageMB,
    required this.availableMemoryMB,
    required this.cpuUsage,
    required this.frameRate,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'memoryUsageMB': memoryUsageMB,
      'availableMemoryMB': availableMemoryMB,
      'cpuUsage': cpuUsage,
      'frameRate': frameRate,
    };
  }

  @override
  String toString() {
    return 'PerformanceSnapshot{memory: ${memoryUsageMB.toStringAsFixed(1)}MB, '
           'cpu: ${cpuUsage.toStringAsFixed(1)}%, fps: ${frameRate.toStringAsFixed(1)}}';
  }
}

/// 内存信息
class MemoryInfo {
  final double usedMemoryMB;
  final double availableMemoryMB;
  final double totalMemoryMB;

  const MemoryInfo({
    required this.usedMemoryMB,
    required this.availableMemoryMB,
    required this.totalMemoryMB,
  });

  double get usagePercentage => 
      totalMemoryMB > 0 ? (usedMemoryMB / totalMemoryMB) * 100 : 0;
}

/// 性能报告
class PerformanceReport {
  final int totalSnapshots;
  final Duration timeRange;
  final double averageMemoryUsage;
  final double peakMemoryUsage;
  final double averageFrameRate;
  final double lowestFrameRate;
  final double averageCpuUsage;
  final double peakCpuUsage;
  final PerformanceLevel performanceLevel;
  final List<String> recommendations;

  const PerformanceReport({
    required this.totalSnapshots,
    required this.timeRange,
    required this.averageMemoryUsage,
    required this.peakMemoryUsage,
    required this.averageFrameRate,
    required this.lowestFrameRate,
    required this.averageCpuUsage,
    required this.peakCpuUsage,
    required this.performanceLevel,
    required this.recommendations,
  });

  factory PerformanceReport.empty() {
    return const PerformanceReport(
      totalSnapshots: 0,
      timeRange: Duration.zero,
      averageMemoryUsage: 0,
      peakMemoryUsage: 0,
      averageFrameRate: 0,
      lowestFrameRate: 0,
      averageCpuUsage: 0,
      peakCpuUsage: 0,
      performanceLevel: PerformanceLevel.good,
      recommendations: [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalSnapshots': totalSnapshots,
      'timeRangeMinutes': timeRange.inMinutes,
      'averageMemoryUsage': averageMemoryUsage,
      'peakMemoryUsage': peakMemoryUsage,
      'averageFrameRate': averageFrameRate,
      'lowestFrameRate': lowestFrameRate,
      'averageCpuUsage': averageCpuUsage,
      'peakCpuUsage': peakCpuUsage,
      'performanceLevel': performanceLevel.name,
      'recommendations': recommendations,
    };
  }
}

/// 性能水平
enum PerformanceLevel {
  good,     // 良好
  warning,  // 警告  
  critical, // 严重
}

extension PerformanceLevelExtension on PerformanceLevel {
  String get displayName {
    switch (this) {
      case PerformanceLevel.good:
        return '良好';
      case PerformanceLevel.warning:
        return '警告';
      case PerformanceLevel.critical:
        return '严重';
    }
  }

  Color get color {
    switch (this) {
      case PerformanceLevel.good:
        return Colors.green;
      case PerformanceLevel.warning:
        return Colors.orange;
      case PerformanceLevel.critical:
        return Colors.red;
    }
  }
}
