import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'reading_progress_service.dart';
import 'sync/webdav_sync_service.dart';
import 'tts/enhanced_tts_handler.dart';

/// 应用生命周期管理器
/// 管理应用的生命周期事件，协调各个服务的状态
class AppLifecycleManager with WidgetsBindingObserver {
  static final AppLifecycleManager _instance = AppLifecycleManager._internal();
  factory AppLifecycleManager() => _instance;
  AppLifecycleManager._internal();

  // 服务实例
  final ReadingProgressService _progressService = ReadingProgressService();
  final WebDavSyncService _syncService = WebDavSyncService();

  // 状态管理
  bool _isInitialized = false;
  AppLifecycleState? _lastLifecycleState;
  DateTime? _pausedTime;
  DateTime? _resumedTime;

  // 统计
  int _pauseCount = 0;
  int _resumeCount = 0;
  Duration _totalPausedDuration = Duration.zero;

  /// 初始化管理器
  Future<void> initialize() async {
    if (_isInitialized) return;

    WidgetsBinding.instance.addObserver(this);

    // 初始化各个服务
    await _progressService.initialize();
    await _syncService.initialize();

    // 加载统计信息
    await _loadLifecycleStats();

    _isInitialized = true;
    debugPrint('应用生命周期管理器已初始化');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    debugPrint('应用生命周期状态变化: ${_lastLifecycleState?.name} -> ${state.name}');

    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.inactive:
        _onAppInactive();
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
      case AppLifecycleState.hidden:
        _onAppHidden();
        break;
    }

    _lastLifecycleState = state;
  }

  /// 应用恢复
  void _onAppResumed() {
    _resumedTime = DateTime.now();
    _resumeCount++;

    // 计算暂停时长
    if (_pausedTime != null) {
      final pausedDuration = _resumedTime!.difference(_pausedTime!);
      _totalPausedDuration += pausedDuration;

      debugPrint('应用恢复，暂停了 ${pausedDuration.inSeconds} 秒');
    }

    // 通知各个服务
    _progressService.onAppResumed();

    // 如果暂停时间超过5分钟，触发同步
    if (_pausedTime != null &&
        _resumedTime!.difference(_pausedTime!).inMinutes > 5) {
      _syncService.manualSync();
    }

    _saveLifecycleStats();
  }

  /// 应用暂停
  void _onAppPaused() {
    _pausedTime = DateTime.now();
    _pauseCount++;

    debugPrint('应用暂停');

    // 立即保存所有数据
    _saveAllData();

    _saveLifecycleStats();
  }

  /// 应用非活跃
  void _onAppInactive() {
    debugPrint('应用变为非活跃状态');

    // 轻度保存，主要是关键数据
    _saveCriticalData();
  }

  /// 应用隐藏
  void _onAppHidden() {
    debugPrint('应用被隐藏');

    // 保存关键数据
    _saveCriticalData();
  }

  /// 应用分离
  void _onAppDetached() {
    debugPrint('应用即将退出');

    // 最终保存
    _saveAllData();

    // 释放资源
    _cleanup();
  }

  /// 保存所有数据
  Future<void> _saveAllData() async {
    try {
      // 保存阅读进度
      await _progressService.forceSaveAll();

      // 如果TTS正在播放，停止它
      final ttsHandler = EnhancedTtsHandler();
      if (ttsHandler.isPlaying) {
        await ttsHandler.pause();
      }

      debugPrint('所有数据已保存');
    } catch (e) {
      debugPrint('保存数据失败: $e');
    }
  }

  /// 保存关键数据
  Future<void> _saveCriticalData() async {
    try {
      // 只保存当前正在阅读的书籍进度
      await _progressService.onAppPaused();

      debugPrint('关键数据已保存');
    } catch (e) {
      debugPrint('保存关键数据失败: $e');
    }
  }

  /// 加载生命周期统计
  Future<void> _loadLifecycleStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _pauseCount = prefs.getInt('lifecycle_pause_count') ?? 0;
      _resumeCount = prefs.getInt('lifecycle_resume_count') ?? 0;

      final totalPausedMs = prefs.getInt('lifecycle_total_paused_ms') ?? 0;
      _totalPausedDuration = Duration(milliseconds: totalPausedMs);

      debugPrint(
        '生命周期统计已加载: 暂停 $_pauseCount 次, 恢复 $_resumeCount 次, 总暂停时长 ${_totalPausedDuration.inMinutes} 分钟',
      );
    } catch (e) {
      debugPrint('加载生命周期统计失败: $e');
    }
  }

  /// 保存生命周期统计
  Future<void> _saveLifecycleStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lifecycle_pause_count', _pauseCount);
      await prefs.setInt('lifecycle_resume_count', _resumeCount);
      await prefs.setInt(
        'lifecycle_total_paused_ms',
        _totalPausedDuration.inMilliseconds,
      );
    } catch (e) {
      debugPrint('保存生命周期统计失败: $e');
    }
  }

  /// 清理资源
  Future<void> _cleanup() async {
    try {
      // 停止TTS
      final ttsHandler = EnhancedTtsHandler();
      await ttsHandler.dispose();

      // 释放进度服务
      _progressService.dispose();

      // 释放同步服务
      _syncService.dispose();

      debugPrint('资源清理完成');
    } catch (e) {
      debugPrint('清理资源失败: $e');
    }
  }

  /// 手动触发数据保存
  Future<void> manualSave() async {
    await _saveAllData();
  }

  /// 手动触发同步
  Future<bool> manualSync() async {
    return await _syncService.manualSync();
  }

  /// 获取生命周期统计
  Map<String, dynamic> getLifecycleStats() {
    return {
      'pauseCount': _pauseCount,
      'resumeCount': _resumeCount,
      'totalPausedDuration': _totalPausedDuration.inMinutes,
      'lastPausedTime': _pausedTime?.toIso8601String(),
      'lastResumedTime': _resumedTime?.toIso8601String(),
      'currentState': _lastLifecycleState?.name,
      'isInitialized': _isInitialized,
    };
  }

  /// 获取服务状态
  Map<String, dynamic> getServiceStatus() {
    return {
      'progressService': _progressService.getCacheStats(),
      'syncService': {
        'isConfigured': _syncService.isConfigured,
        'status': _syncService.status.name,
        'lastSyncTime': _syncService.lastSyncTime?.toIso8601String(),
      },
    };
  }

  /// 重置统计
  Future<void> resetStats() async {
    _pauseCount = 0;
    _resumeCount = 0;
    _totalPausedDuration = Duration.zero;
    _pausedTime = null;
    _resumedTime = null;

    await _saveLifecycleStats();
    debugPrint('生命周期统计已重置');
  }

  /// 释放管理器
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanup();
    _isInitialized = false;
    debugPrint('应用生命周期管理器已释放');
  }
}

/// 全局生命周期管理器实例
final appLifecycleManager = AppLifecycleManager();
