import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 只使用系统 TTS（flutter_tts 封装平台系统引擎）。
class TtsService extends ChangeNotifier {
  FlutterTts? _flutterTts;
  Future<void>? _initializationFuture;
  bool _isDisposed = false;

  bool _isPlaying = false;
  bool _isPaused = false;
  bool _isInitialized = false;
  bool _isInitializing = false;
  double _speechRate = 0.5;
  double _speechVolume = 1.0;
  double _speechPitch = 1.0;
  String _currentLanguage = 'zh-CN';
  List<String> _availableLanguages = const <String>[];
  String _currentText = '';
  int _currentPosition = 0;
  String? _lastError;

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  bool get isAvailable => _isInitialized;
  String? get lastError => _lastError;
  double get speechRate => _speechRate;
  double get speechVolume => _speechVolume;
  double get speechPitch => _speechPitch;
  String get currentLanguage => _currentLanguage;
  List<String> get availableLanguages => _availableLanguages;
  String get currentText => _currentText;
  int get currentPosition => _currentPosition;

  TtsService() {
    unawaited(initialize());
  }

  Future<void> initialize({bool force = false}) async {
    if (_isDisposed) return;

    if (_isInitializing) {
      final pending = _initializationFuture;
      if (pending != null) {
        await pending;
      }
      return;
    }

    if (!force && _isInitialized && _flutterTts != null) {
      return;
    }

    final completer = Completer<void>();
    _initializationFuture = completer.future;

    _isInitializing = true;
    _lastError = null;
    if (force) {
      _isInitialized = false;
    }
    _notifySafe();

    try {
      await _loadSettings();

      final tts = FlutterTts();
      _wireHandlers(tts);
      await _configureSystemTts(tts);
      await _safeSetSpeechRate(tts, _speechRate);
      await _safeSetVolume(tts, _speechVolume);
      await _safeSetPitch(tts, _speechPitch);
      await _refreshAvailableLanguages(tts);
      await _applyBestLanguage(tts);

      _flutterTts = tts;
      _isInitialized = true;
      _lastError = null;
      debugPrint('TTS 初始化成功，语言: $_currentLanguage');
    } catch (e) {
      _isInitialized = false;
      _isPlaying = false;
      _isPaused = false;
      _lastError = _toErrorText(e);
      debugPrint('TTS 初始化失败: $e');
    } finally {
      _isInitializing = false;
      _notifySafe();

      if (!completer.isCompleted) {
        completer.complete();
      }
      if (identical(_initializationFuture, completer.future)) {
        _initializationFuture = null;
      }
    }
  }

  Future<void> retryInitialize() async {
    await initialize(force: true);
  }

  Future<void> _configureSystemTts(FlutterTts tts) async {
    await tts.awaitSpeakCompletion(true);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await tts.awaitSynthCompletion(true);
      // 0: flush，确保每次朗读直接替换旧任务，避免排队导致“没反应”。
      await tts.setQueueMode(0);
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await tts.setSharedInstance(true);
      await tts.autoStopSharedSession(true);
      await tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        const [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    }
  }

  void _wireHandlers(FlutterTts tts) {
    tts.setStartHandler(() {
      _isPlaying = true;
      _isPaused = false;
      _lastError = null;
      _notifySafe();
    });

    tts.setCompletionHandler(() {
      _isPlaying = false;
      _isPaused = false;
      _currentPosition = 0;
      _notifySafe();
    });

    tts.setPauseHandler(() {
      _isPlaying = false;
      _isPaused = true;
      _notifySafe();
    });

    tts.setContinueHandler(() {
      _isPlaying = true;
      _isPaused = false;
      _notifySafe();
    });

    tts.setCancelHandler(() {
      _isPlaying = false;
      _isPaused = false;
      _notifySafe();
    });

    tts.setProgressHandler((
      String text,
      int startOffset,
      int endOffset,
      String word,
    ) {
      _currentPosition = startOffset.clamp(0, _currentText.length);
      _notifySafe();
    });

    tts.setErrorHandler((message) {
      _isPlaying = false;
      _isPaused = false;
      _lastError = message;
      _notifySafe();
      debugPrint('TTS 运行错误: $message');
    });
  }

  Future<void> _refreshAvailableLanguages(FlutterTts tts) async {
    try {
      final result = await tts.getLanguages;
      if (result is Iterable) {
        final unique = <String>{};
        for (final item in result) {
          final value = item.toString().trim();
          if (value.isNotEmpty) {
            unique.add(value);
          }
        }
        _availableLanguages = unique.toList(growable: false)..sort();
      } else {
        _availableLanguages = const <String>[];
      }
    } catch (e) {
      _availableLanguages = const <String>[];
      debugPrint('获取 TTS 语言列表失败: $e');
    }
  }

  Future<void> _applyBestLanguage(FlutterTts tts) async {
    final locale = PlatformDispatcher.instance.locale;
    final deviceLocaleTag = _localeTag(locale);

    final candidates = <String>[
      _currentLanguage,
      if (deviceLocaleTag.isNotEmpty) deviceLocaleTag,
      if (locale.languageCode.isNotEmpty) locale.languageCode,
      'zh-CN',
      'zh_CN',
      'zh',
      'en-US',
      'en_US',
      'en',
    ];

    final tested = <String>{};
    for (final lang in candidates) {
      final value = lang.trim();
      if (value.isEmpty || !tested.add(value)) continue;
      if (await _trySetLanguage(tts, value)) {
        _currentLanguage = value;
        await _saveSettings();
        return;
      }
    }
  }

  String _localeTag(Locale locale) {
    if (locale.countryCode?.isNotEmpty ?? false) {
      return '${locale.languageCode}-${locale.countryCode}';
    }
    return locale.languageCode;
  }

  Future<bool> _trySetLanguage(FlutterTts tts, String language) async {
    try {
      final available = await tts.isLanguageAvailable(language);
      if (available == false) {
        return false;
      }
    } catch (_) {
      // 某些平台不支持 isLanguageAvailable，直接尝试设置。
    }

    try {
      await tts.setLanguage(language);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _safeSetSpeechRate(FlutterTts tts, double rate) async {
    try {
      await tts.setSpeechRate(rate.clamp(0.1, 1.0));
    } catch (e) {
      debugPrint('设置 TTS 语速失败: $e');
    }
  }

  Future<void> _safeSetVolume(FlutterTts tts, double volume) async {
    try {
      await tts.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('设置 TTS 音量失败: $e');
    }
  }

  Future<void> _safeSetPitch(FlutterTts tts, double pitch) async {
    try {
      await tts.setPitch(pitch.clamp(0.5, 2.0));
    } catch (e) {
      debugPrint('设置 TTS 音调失败: $e');
    }
  }

  Future<void> speak(String text) async {
    final content = text.trim();
    if (content.isEmpty) {
      return;
    }

    await initialize();
    final tts = _flutterTts;
    if (!_isInitialized || tts == null) {
      _lastError = _lastError ?? '系统 TTS 不可用';
      _notifySafe();
      return;
    }

    try {
      if (_isPlaying || _isPaused) {
        await tts.stop();
      }

      _currentText = content;
      _currentPosition = 0;
      _lastError = null;
      _notifySafe();

      await tts.speak(content);
    } catch (e) {
      _isPlaying = false;
      _isPaused = false;
      _lastError = _toErrorText(e);
      _notifySafe();
      debugPrint('TTS 播放失败: $e');
    }
  }

  Future<void> pause() async {
    final tts = _flutterTts;
    if (!_isInitialized || tts == null || !_isPlaying || _isPaused) {
      return;
    }

    try {
      await tts.pause();
      _isPlaying = false;
      _isPaused = true;
      _notifySafe();
    } catch (e) {
      _lastError = _toErrorText(e);
      _notifySafe();
      debugPrint('TTS 暂停失败: $e');
    }
  }

  Future<void> resume() async {
    final tts = _flutterTts;
    if (!_isInitialized || tts == null || !_isPaused) {
      return;
    }

    try {
      final fallbackText = _currentText;
      final startIndex = _currentPosition.clamp(0, fallbackText.length);
      final remainingText = startIndex < fallbackText.length
          ? fallbackText.substring(startIndex)
          : '';
      await tts.speak(remainingText.isEmpty ? fallbackText : remainingText);
      _isPlaying = true;
      _isPaused = false;
      _notifySafe();
    } catch (e) {
      _lastError = _toErrorText(e);
      _notifySafe();
      debugPrint('TTS 继续播放失败: $e');
    }
  }

  Future<void> stop() async {
    final tts = _flutterTts;
    if (tts == null) {
      return;
    }

    try {
      await tts.stop();
    } catch (e) {
      _lastError = _toErrorText(e);
      debugPrint('TTS 停止失败: $e');
    } finally {
      _isPlaying = false;
      _isPaused = false;
      _currentPosition = 0;
      _notifySafe();
    }
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.1, 1.0);
    final tts = _flutterTts;
    if (tts != null) {
      await _safeSetSpeechRate(tts, _speechRate);
    }
    await _saveSettings();
    _notifySafe();
  }

  Future<void> setVolume(double volume) async {
    _speechVolume = volume.clamp(0.0, 1.0);
    final tts = _flutterTts;
    if (tts != null) {
      await _safeSetVolume(tts, _speechVolume);
    }
    await _saveSettings();
    _notifySafe();
  }

  Future<void> setPitch(double pitch) async {
    _speechPitch = pitch.clamp(0.5, 2.0);
    final tts = _flutterTts;
    if (tts != null) {
      await _safeSetPitch(tts, _speechPitch);
    }
    await _saveSettings();
    _notifySafe();
  }

  Future<void> setLanguage(String language) async {
    final normalized = language.trim();
    if (normalized.isEmpty) {
      return;
    }

    _currentLanguage = normalized;
    await _saveSettings();

    final tts = _flutterTts;
    if (!_isInitialized || tts == null) {
      return;
    }

    final success = await _trySetLanguage(tts, normalized);
    if (!success) {
      _lastError = '系统不支持语言: $normalized';
    } else {
      _lastError = null;
    }
    _notifySafe();
  }

  double get playbackProgress {
    if (_currentText.isEmpty) return 0.0;
    return (_currentPosition / _currentText.length).clamp(0.0, 1.0);
  }

  Future<bool> isLanguageAvailable(String language) async {
    final tts = _flutterTts;
    if (!_isInitialized || tts == null) {
      return false;
    }

    try {
      final result = await tts.isLanguageAvailable(language);
      return result ?? false;
    } catch (e) {
      debugPrint('检查语言可用性失败: $e');
      return false;
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _speechRate = (prefs.getDouble('tts_speech_rate') ??
              prefs.getDouble('ttsSpeed') ??
              0.5)
          .clamp(0.1, 1.0);
      _speechVolume = (prefs.getDouble('tts_speech_volume') ??
              prefs.getDouble('ttsVolume') ??
              1.0)
          .clamp(0.0, 1.0);
      _speechPitch = (prefs.getDouble('tts_speech_pitch') ??
              prefs.getDouble('ttsPitch') ??
              1.0)
          .clamp(0.5, 2.0);
      _currentLanguage = prefs.getString('tts_language') ?? 'zh-CN';
    } catch (e) {
      debugPrint('加载 TTS 设置失败: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('tts_speech_rate', _speechRate);
      await prefs.setDouble('tts_speech_volume', _speechVolume);
      await prefs.setDouble('tts_speech_pitch', _speechPitch);
      await prefs.setString('tts_language', _currentLanguage);

      // 兼容设置页旧键名，确保两处入口数据一致。
      await prefs.setDouble('ttsSpeed', _speechRate);
      await prefs.setDouble('ttsVolume', _speechVolume);
      await prefs.setDouble('ttsPitch', _speechPitch);
    } catch (e) {
      debugPrint('保存 TTS 设置失败: $e');
    }
  }

  String _toErrorText(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return '系统 TTS 调用失败';
    return raw.length > 220 ? raw.substring(0, 220) : raw;
  }

  void _notifySafe() {
    if (_isDisposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    final tts = _flutterTts;
    _flutterTts = null;
    _initializationFuture = null;
    if (tts != null) {
      unawaited(tts.stop());
    }
    super.dispose();
  }
}
