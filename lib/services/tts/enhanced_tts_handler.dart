import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TTS状态枚举
enum TtsState { stopped, playing, paused, continuing }

/// 增强的TTS处理器
/// 集成anx-reader的TTS架构设计
/// 支持后台播放、音频会话管理、语音控制
class EnhancedTtsHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  static final EnhancedTtsHandler _instance = EnhancedTtsHandler._internal();
  factory EnhancedTtsHandler() => _instance;
  EnhancedTtsHandler._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final ValueNotifier<TtsState> _stateNotifier = ValueNotifier<TtsState>(
    TtsState.stopped,
  );

  // 文本获取回调
  Function? _getCurrentText;
  Function? _getNextText;
  Function? _getPrevText;

  // TTS设置
  double _volume = 1.0;
  double _pitch = 1.0;
  double _rate = 0.5;
  String _language = 'zh-CN';
  String _voice = '';

  // 状态管理
  bool _isInitialized = false;
  Timer? _progressTimer;

  // Getters
  ValueNotifier<TtsState> get stateNotifier => _stateNotifier;
  TtsState get state => _stateNotifier.value;
  bool get isPlaying => state == TtsState.playing;
  bool get isPaused => state == TtsState.paused;
  double get volume => _volume;
  double get pitch => _pitch;
  double get rate => _rate;
  String get language => _language;
  String get voice => _voice;

  /// 初始化TTS
  Future<void> initialize({
    Function? getCurrentText,
    Function? getNextText,
    Function? getPrevText,
  }) async {
    if (_isInitialized) return;

    _getCurrentText = getCurrentText;
    _getNextText = getNextText;
    _getPrevText = getPrevText;

    await _initializeTts();
    await _initializeAudioService();
    await _loadSettings();

    _isInitialized = true;
  }

  /// 初始化TTS引擎
  Future<void> _initializeTts() async {
    // 设置语言
    await _flutterTts.setLanguage(_language);

    // 设置基础参数
    await _flutterTts.setVolume(_volume);
    await _flutterTts.setPitch(_pitch);
    await _flutterTts.setSpeechRate(_rate);

    // 设置回调
    _flutterTts.setStartHandler(() {
      _updateState(TtsState.playing);
      _startProgressTimer();
    });

    _flutterTts.setCompletionHandler(() {
      _stopProgressTimer();
      if (_getCurrentText != null) {
        // 自动播放下一段
        _playNext();
      } else {
        _updateState(TtsState.stopped);
      }
    });

    _flutterTts.setProgressHandler((
      String text,
      int startOffset,
      int endOffset,
      String word,
    ) {
      // 更新播放进度
      _updatePlaybackState();
    });

    _flutterTts.setPauseHandler(() {
      _updateState(TtsState.paused);
      _stopProgressTimer();
    });

    _flutterTts.setContinueHandler(() {
      _updateState(TtsState.continuing);
      _startProgressTimer();
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint('TTS错误: $msg');
      _updateState(TtsState.stopped);
      _stopProgressTimer();
    });
  }

  /// 初始化音频服务
  Future<void> _initializeAudioService() async {
    final session = await AudioSession.instance;

    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.audibilityEnforced,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ),
    );

    // 监听音频中断
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (isPlaying) {
          pause();
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.pause:
          case AudioInterruptionType.duck:
            // 不自动恢复播放，让用户手动控制
            break;
          case AudioInterruptionType.unknown:
            break;
        }
      }
    });

    // 监听耳机拔出
    session.becomingNoisyEventStream.listen((_) {
      if (isPlaying) pause();
    });
  }

  /// 加载用户设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _volume = prefs.getDouble('tts_volume') ?? 1.0;
      _pitch = prefs.getDouble('tts_pitch') ?? 1.0;
      _rate = prefs.getDouble('tts_rate') ?? 0.5;
      _language = prefs.getString('tts_language') ?? 'zh-CN';
      _voice = prefs.getString('tts_voice') ?? '';

      // 应用设置
      await _flutterTts.setVolume(_volume);
      await _flutterTts.setPitch(_pitch);
      await _flutterTts.setSpeechRate(_rate);
      await _flutterTts.setLanguage(_language);

      if (_voice.isNotEmpty) {
        await _flutterTts.setVoice({'name': _voice, 'locale': _language});
      }
    } catch (e) {
      debugPrint('加载TTS设置失败: $e');
    }
  }

  /// 保存用户设置
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('tts_volume', _volume);
      await prefs.setDouble('tts_pitch', _pitch);
      await prefs.setDouble('tts_rate', _rate);
      await prefs.setString('tts_language', _language);
      await prefs.setString('tts_voice', _voice);
    } catch (e) {
      debugPrint('保存TTS设置失败: $e');
    }
  }

  /// 播放指定文本
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      debugPrint('TTS未初始化');
      return;
    }

    try {
      await _flutterTts.stop();

      await _flutterTts.speak(text);

      // 更新媒体项信息
      _updateMediaItem(text);
    } catch (e) {
      debugPrint('TTS播放失败: $e');
      _updateState(TtsState.stopped);
    }
  }

  /// 播放当前内容
  Future<void> speakCurrent() async {
    if (_getCurrentText != null) {
      final text = await _getCurrentText!();
      if (text != null && text.isNotEmpty) {
        await speak(text);
      }
    }
  }

  /// 播放下一段内容
  Future<void> _playNext() async {
    if (_getNextText != null) {
      final text = await _getNextText!();
      if (text != null && text.isNotEmpty) {
        await speak(text);
      } else {
        _updateState(TtsState.stopped);
      }
    }
  }

  /// 播放上一段内容
  Future<void> _playPrev() async {
    if (_getPrevText != null) {
      final text = await _getPrevText!();
      if (text != null && text.isNotEmpty) {
        await speak(text);
      }
    }
  }

  @override
  Future<void> play() async {
    if (isPaused) {
      // FlutterTts没有resume方法，需要重新播放
      await speakCurrent();
    } else {
      await speakCurrent();
    }
  }

  @override
  Future<void> pause() async {
    await _flutterTts.pause();
  }

  @override
  Future<void> stop() async {
    await _flutterTts.stop();
    _updateState(TtsState.stopped);
    _stopProgressTimer();
  }

  @override
  Future<void> skipToNext() async {
    await _playNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await _playPrev();
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _flutterTts.setVolume(_volume);
    await _saveSettings();
  }

  /// 设置音调
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    await _flutterTts.setPitch(_pitch);
    await _saveSettings();
  }

  /// 设置语速
  Future<void> setRate(double rate) async {
    _rate = rate.clamp(0.0, 1.0);
    await _flutterTts.setSpeechRate(_rate);
    await _saveSettings();
  }

  /// 设置语言
  Future<void> setLanguage(String language) async {
    _language = language;
    await _flutterTts.setLanguage(_language);
    await _saveSettings();
  }

  /// 设置语音
  Future<void> setVoice(String voice) async {
    _voice = voice;
    if (voice.isNotEmpty) {
      await _flutterTts.setVoice({'name': voice, 'locale': _language});
    }
    await _saveSettings();
  }

  /// 获取可用语言
  Future<List<String>> getLanguages() async {
    try {
      final languages = await _flutterTts.getLanguages;
      return languages?.cast<String>() ?? [];
    } catch (e) {
      debugPrint('获取语言列表失败: $e');
      return [];
    }
  }

  /// 获取可用语音
  Future<List<Map<String, String>>> getVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      return voices?.cast<Map<String, String>>() ?? [];
    } catch (e) {
      debugPrint('获取语音列表失败: $e');
      return [];
    }
  }

  /// 更新状态
  void _updateState(TtsState newState) {
    _stateNotifier.value = newState;
    _updatePlaybackState();
  }

  /// 更新播放状态
  void _updatePlaybackState() {
    // 暂时简化PlaybackState更新
    // TODO: 正确实现PlaybackState更新逻辑
  }


  /// 更新媒体项信息
  void _updateMediaItem(String text) {
    final title = text.length > 50 ? '${text.substring(0, 50)}...' : text;

    mediaItem.add(
      MediaItem(
        id: 'tts_${DateTime.now().millisecondsSinceEpoch}',
        album: '语音朗读',
        title: title,
        artist: 'TTS',
        duration: Duration(seconds: (text.length * 0.1).round()), // 估算时长
        artUri: null,
      ),
    );
  }

  /// 开始进度计时器
  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (isPlaying) {
        _updatePlaybackState();
      }
    });
  }

  /// 停止进度计时器
  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  /// 释放资源
  Future<void> dispose() async {
    _stopProgressTimer();
    await _flutterTts.stop();
  }
}
