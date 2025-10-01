import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'enhanced_tts_handler.dart';

/// TTS服务管理器
/// 统一管理TTS功能，提供全局访问接口
class TtsServiceManager {
  static final TtsServiceManager _instance = TtsServiceManager._internal();
  factory TtsServiceManager() => _instance;
  TtsServiceManager._internal();

  EnhancedTtsHandler? _ttsHandler;
  bool _isInitialized = false;
  late AudioHandler _audioHandler;

  /// 初始化TTS服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 初始化音频服务
      _audioHandler = await AudioService.init(
        builder: () => EnhancedTtsHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.xxread.audio',
          androidNotificationChannelName: '小元读书朗读',
          androidNotificationChannelDescription: '语音朗读功能',
          androidNotificationOngoing: true,
          androidShowNotificationBadge: true,
          androidNotificationClickStartsActivity: true,
          androidStopForegroundOnPause: true,
        ),
      );

      _ttsHandler = _audioHandler as EnhancedTtsHandler;
      _isInitialized = true;

      debugPrint('TTS服务初始化成功');
    } catch (e) {
      debugPrint('TTS服务初始化失败: $e');
      rethrow;
    }
  }

  /// 获取TTS处理器
  EnhancedTtsHandler? get ttsHandler => _ttsHandler;

  /// 获取音频处理器
  AudioHandler get audioHandler => _audioHandler;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 检查TTS是否可用
  bool get isAvailable => _isInitialized && _ttsHandler != null;

  /// 开始朗读
  Future<void> startReading({
    Function? getCurrentText,
    Function? getNextText,
    Function? getPrevText,
  }) async {
    if (!isAvailable) {
      throw Exception('TTS服务未初始化');
    }

    await _ttsHandler!.initialize(
      getCurrentText: getCurrentText,
      getNextText: getNextText,
      getPrevText: getPrevText,
    );

    await _ttsHandler!.play();
  }

  /// 暂停朗读
  Future<void> pauseReading() async {
    if (!isAvailable) return;
    await _ttsHandler!.pause();
  }

  /// 恢复朗读
  Future<void> resumeReading() async {
    if (!isAvailable) return;
    await _ttsHandler!.play();
  }

  /// 停止朗读
  Future<void> stopReading() async {
    if (!isAvailable) return;
    await _ttsHandler!.stop();
  }

  /// 下一段
  Future<void> nextChapter() async {
    if (!isAvailable) return;
    await _ttsHandler!.skipToNext();
  }

  /// 上一段
  Future<void> previousChapter() async {
    if (!isAvailable) return;
    await _ttsHandler!.skipToPrevious();
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    if (!isAvailable) return;
    await _ttsHandler!.setVolume(volume);
  }

  /// 设置语速
  Future<void> setRate(double rate) async {
    if (!isAvailable) return;
    await _ttsHandler!.setRate(rate);
  }

  /// 设置音调
  Future<void> setPitch(double pitch) async {
    if (!isAvailable) return;
    await _ttsHandler!.setPitch(pitch);
  }

  /// 设置语言
  Future<void> setLanguage(String language) async {
    if (!isAvailable) return;
    await _ttsHandler!.setLanguage(language);
  }

  /// 设置语音
  Future<void> setVoice(String voice) async {
    if (!isAvailable) return;
    await _ttsHandler!.setVoice(voice);
  }

  /// 获取当前状态
  TtsState get currentState {
    if (!isAvailable) return TtsState.stopped;
    return _ttsHandler!.state;
  }

  /// 监听状态变化
  ValueNotifier<TtsState>? get stateNotifier {
    if (!isAvailable) return null;
    return _ttsHandler!.stateNotifier;
  }

  /// 是否正在播放
  bool get isPlaying {
    if (!isAvailable) return false;
    return _ttsHandler!.isPlaying;
  }

  /// 是否已暂停
  bool get isPaused {
    if (!isAvailable) return false;
    return _ttsHandler!.isPaused;
  }

  /// 获取可用语言
  Future<List<String>> getAvailableLanguages() async {
    if (!isAvailable) return [];
    return await _ttsHandler!.getLanguages();
  }

  /// 获取可用语音
  Future<List<Map<String, String>>> getAvailableVoices() async {
    if (!isAvailable) return [];
    return await _ttsHandler!.getVoices();
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_isInitialized) {
      await _ttsHandler?.dispose();
      _isInitialized = false;
      _ttsHandler = null;
    }
  }
}

/// 全局TTS服务实例
final ttsService = TtsServiceManager();
