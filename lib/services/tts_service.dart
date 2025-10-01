import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TTS语音朗读服务
/// 提供优雅的文本转语音功能，支持多语言和个性化设置
class TtsService extends ChangeNotifier {
  late FlutterTts _flutterTts;
  bool _isPlaying = false;
  bool _isPaused = false;
  bool _isInitialized = false;
  double _speechRate = 0.5;
  double _speechVolume = 1.0;
  double _speechPitch = 1.0;
  String _currentLanguage = 'zh-CN';
  List<String> _availableLanguages = [];
  String _currentText = '';
  int _currentPosition = 0;

  // Getters
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  bool get isInitialized => _isInitialized;
  double get speechRate => _speechRate;
  double get speechVolume => _speechVolume;
  double get speechPitch => _speechPitch;
  String get currentLanguage => _currentLanguage;
  List<String> get availableLanguages => _availableLanguages;
  String get currentText => _currentText;
  int get currentPosition => _currentPosition;

  TtsService() {
    _initializeTts();
  }

  /// 初始化TTS引擎
  Future<void> _initializeTts() async {
    try {
      _flutterTts = FlutterTts();

      // 加载保存的设置
      await _loadSettings();

      // 设置语音参数
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setVolume(_speechVolume);
      await _flutterTts.setPitch(_speechPitch);
      await _flutterTts.setLanguage(_currentLanguage);

      // 获取可用语言列表
      final languages = await _flutterTts.getLanguages;
      if (languages != null) {
        _availableLanguages = List<String>.from(languages);
      }

      // 设置播放状态回调
      _flutterTts.setStartHandler(() {
        _isPlaying = true;
        _isPaused = false;
        notifyListeners();
      });

      _flutterTts.setCompletionHandler(() {
        _isPlaying = false;
        _isPaused = false;
        _currentPosition = 0;
        notifyListeners();
      });

      _flutterTts.setPauseHandler(() {
        _isPaused = true;
        notifyListeners();
      });

      _flutterTts.setContinueHandler(() {
        _isPaused = false;
        notifyListeners();
      });

      _flutterTts.setCancelHandler(() {
        _isPlaying = false;
        _isPaused = false;
        _currentPosition = 0;
        notifyListeners();
      });

      // 设置进度回调（如果支持）
      _flutterTts.setProgressHandler((
        String text,
        int startOffset,
        int endOffset,
        String word,
      ) {
        _currentPosition = startOffset;
        notifyListeners();
      });

      _isInitialized = true;
      notifyListeners();

      debugPrint('TTS服务初始化成功');
    } catch (e) {
      debugPrint('TTS初始化失败: $e');
      _isInitialized = false;
    }
  }

  /// 播放文本
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      debugPrint('TTS未初始化，无法播放');
      return;
    }

    try {
      if (_isPlaying) {
        await stop();
      }

      _currentText = text;
      _currentPosition = 0;

      await _flutterTts.speak(text);
      debugPrint(
        '开始播放: ${text.substring(0, text.length > 50 ? 50 : text.length)}...',
      );
    } catch (e) {
      debugPrint('TTS播放错误: $e');
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    if (!_isInitialized || !_isPlaying || _isPaused) return;

    try {
      await _flutterTts.pause();
      debugPrint('TTS暂停');
    } catch (e) {
      debugPrint('TTS暂停错误: $e');
    }
  }

  /// 继续播放
  Future<void> resume() async {
    if (!_isInitialized || !_isPaused) return;

    try {
      await _flutterTts.speak(_currentText);
      debugPrint('TTS继续播放');
    } catch (e) {
      debugPrint('TTS继续播放错误: $e');
    }
  }

  /// 停止播放
  Future<void> stop() async {
    if (!_isInitialized) return;

    try {
      await _flutterTts.stop();
      _currentPosition = 0;
      debugPrint('TTS停止');
    } catch (e) {
      debugPrint('TTS停止错误: $e');
    }
  }

  /// 设置语速
  Future<void> setSpeechRate(double rate) async {
    if (!_isInitialized) return;

    _speechRate = rate.clamp(0.0, 1.0);
    await _flutterTts.setSpeechRate(_speechRate);
    await _saveSettings();
    notifyListeners();
    debugPrint('语速设置为: $_speechRate');
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    if (!_isInitialized) return;

    _speechVolume = volume.clamp(0.0, 1.0);
    await _flutterTts.setVolume(_speechVolume);
    await _saveSettings();
    notifyListeners();
    debugPrint('音量设置为: $_speechVolume');
  }

  /// 设置音调
  Future<void> setPitch(double pitch) async {
    if (!_isInitialized) return;

    _speechPitch = pitch.clamp(0.5, 2.0);
    await _flutterTts.setPitch(_speechPitch);
    await _saveSettings();
    notifyListeners();
    debugPrint('音调设置为: $_speechPitch');
  }

  /// 设置语言
  Future<void> setLanguage(String language) async {
    if (!_isInitialized || !_availableLanguages.contains(language)) return;

    _currentLanguage = language;
    await _flutterTts.setLanguage(_currentLanguage);
    await _saveSettings();
    notifyListeners();
    debugPrint('语言设置为: $_currentLanguage');
  }

  /// 获取当前播放进度百分比
  double get playbackProgress {
    if (_currentText.isEmpty) return 0.0;
    return _currentPosition / _currentText.length;
  }

  /// 检查TTS是否可用
  Future<bool> isLanguageAvailable(String language) async {
    if (!_isInitialized) return false;

    try {
      final result = await _flutterTts.isLanguageAvailable(language);
      return result ?? false;
    } catch (e) {
      debugPrint('检查语言可用性错误: $e');
      return false;
    }
  }

  /// 加载保存的设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _speechRate = prefs.getDouble('tts_speech_rate') ?? 0.5;
      _speechVolume = prefs.getDouble('tts_speech_volume') ?? 1.0;
      _speechPitch = prefs.getDouble('tts_speech_pitch') ?? 1.0;
      _currentLanguage = prefs.getString('tts_language') ?? 'zh-CN';
      debugPrint('TTS设置加载完成');
    } catch (e) {
      debugPrint('加载TTS设置错误: $e');
    }
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('tts_speech_rate', _speechRate);
      await prefs.setDouble('tts_speech_volume', _speechVolume);
      await prefs.setDouble('tts_speech_pitch', _speechPitch);
      await prefs.setString('tts_language', _currentLanguage);
    } catch (e) {
      debugPrint('保存TTS设置错误: $e');
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}
