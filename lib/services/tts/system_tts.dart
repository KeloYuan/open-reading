import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'base_tts.dart';

class SystemTts extends BaseTts {
  static final SystemTts _instance = SystemTts._internal();

  factory SystemTts() {
    return _instance;
  }

  SystemTts._internal();

  final FlutterTts flutterTts = FlutterTts();

  String? _currentVoiceText;
  static String? _prevVoiceText;

  bool restarting = false;

  late Function getHereFunction;
  late Function getNextTextFunction;
  late Function getPrevTextFunction;

  // 句子高亮相关
  Function(int?)? _onSentenceHighlightChanged;
  int _currentSentenceIndex = -1;
  List<String> _currentSentences = [];
  Timer? _highlightTimer;
  int _highlightPosition = 0;

  @override
  final ValueNotifier<TtsStateEnum> ttsStateNotifier =
      ValueNotifier<TtsStateEnum>(TtsStateEnum.stopped);

  @override
  void updateTtsState(TtsStateEnum newState) {
    ttsStateNotifier.value = newState;
  }

  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  bool get isWindows => !kIsWeb && Platform.isWindows;
  bool get isWeb => kIsWeb;

  @override
  double get volume => _getVolume();

  @override
  set volume(double volume) {
    _setVolume(volume);
    restart();
  }

  @override
  double get pitch => _getPitch();

  @override
  set pitch(double pitch) {
    _setPitch(pitch);
    restart();
  }

  @override
  double get rate => _getRate();

  @override
  set rate(double rate) {
    _setRate(rate);
    restart();
  }

  @override
  bool get isPlaying => ttsStateNotifier.value == TtsStateEnum.playing;

  @override
  String? get currentVoiceText => _currentVoiceText;

  /// 设置句子高亮回调
  void setSentenceHighlightCallback(Function(int?) callback) {
    _onSentenceHighlightChanged = callback;
  }

  /// 分割文本为句子
  List<String> _splitIntoSentences(String text) {
    final sentences = <String>[];
    final regex = RegExp(r'[^。！？.!?]+[。！？.!?\s]*');
    final matches = regex.allMatches(text);

    for (final match in matches) {
      sentences.add(match.group(0)!);
    }

    return sentences.isEmpty ? [text] : sentences;
  }

  /// 更新高亮句子索引
  void _updateHighlightedSentence(int index) {
    if (_currentSentenceIndex != index) {
      _currentSentenceIndex = index;
      _onSentenceHighlightChanged?.call(index >= 0 ? index : null);
    }
  }

  /// 重置高亮句子
  void _resetHighlightedSentence() {
    _currentSentenceIndex = -1;
    _highlightPosition = 0;
    _stopHighlightTimer();
    _onSentenceHighlightChanged?.call(null);
  }

  /// 开始高亮计时器
  void _startHighlightTimer() {
    _stopHighlightTimer();
    _highlightPosition = 0;
    _currentSentenceIndex = -1;

    if (_currentSentences.isEmpty) return;

    // 估算每个字符的阅读时间（基于语速）
    final charPerSecond = (rate * 200).clamp(50.0, 300.0); // 估算值
    final updateIntervalMs = (1000 / charPerSecond).round().clamp(100, 500);

    _highlightTimer =
        Timer.periodic(Duration(milliseconds: updateIntervalMs), (timer) {
      if (ttsStateNotifier.value != TtsStateEnum.playing) {
        _stopHighlightTimer();
        return;
      }

      _highlightPosition += (charPerSecond * updateIntervalMs / 1000).round();

      // 计算当前应该高亮的句子
      int currentIndex = -1;
      int totalChars = 0;

      for (int i = 0; i < _currentSentences.length; i++) {
        totalChars += _currentSentences[i].length;
        if (_highlightPosition <= totalChars) {
          currentIndex = i;
          break;
        }
      }

      _updateHighlightedSentence(currentIndex);
    });
  }

  /// 停止高亮计时器
  void _stopHighlightTimer() {
    _highlightTimer?.cancel();
    _highlightTimer = null;
  }

  @override
  Future<void> init(
    Function getCurrentText,
    Function getNextText,
    Function getPrevText,
  ) async {
    getHereFunction = getCurrentText;
    getNextTextFunction = getNextText;
    getPrevTextFunction = getPrevText;

    await setAwaitOptions();

    if (isAndroid) {
      await getDefaultEngine();
      await getDefaultVoice();
    }

    flutterTts.setStartHandler(() async {
      updateTtsState(TtsStateEnum.playing);
      _startHighlightTimer(); // 开始句子高亮

      if (!isAndroid) {
        return;
      }
      _prevVoiceText = _currentVoiceText;
      _currentVoiceText = await getCurrentText();

      if (_currentVoiceText?.isNotEmpty ?? false) {
        flutterTts.speak(_currentVoiceText!);
      }
    });

    flutterTts.setCompletionHandler(() async {
      if (!isAndroid) {
        return;
      }
      updateTtsState(TtsStateEnum.playing);
      if (_currentVoiceText?.isEmpty ?? true) {
        _currentVoiceText = await getNextText();
        await speak();
      } else {
        await getNextText();
      }
    });
  }

  Future<void> setAwaitOptions() async {
    await flutterTts.awaitSpeakCompletion(true);
    if (isAndroid) {
      await flutterTts.awaitSynthCompletion(true);
      await flutterTts.setQueueMode(1);
    }
  }

  Future<void> getDefaultEngine() async {
    var engine = await flutterTts.getDefaultEngine;
    if (engine != null) {}
  }

  Future<void> getDefaultVoice() async {
    var voice = await flutterTts.getDefaultVoice;
    if (voice != null) {}
  }

  @override
  Future<void> speak({String? content}) async {
    await setAwaitOptions();
    if (content != null) {
      _currentVoiceText = content;
    }
    _currentVoiceText ??= await getHereFunction();

    // 分割当前文本为句子，用于高亮显示
    if (_currentVoiceText?.isNotEmpty ?? false) {
      _currentSentences = _splitIntoSentences(_currentVoiceText!);
    }

    await flutterTts.setVolume(volume);
    await flutterTts.setSpeechRate(rate);
    await flutterTts.setPitch(pitch);

    await flutterTts.speak(_currentVoiceText!);

    if (!isAndroid && ttsStateNotifier.value == TtsStateEnum.playing) {
      _currentVoiceText = await getNextTextFunction();
      speak();
    }
  }

  @override
  Future<dynamic> stop() async {
    updateTtsState(TtsStateEnum.stopped);
    final result = await flutterTts.stop();
    _currentVoiceText = null;
    _resetHighlightedSentence();
    return result;
  }

  @override
  Future<void> pause() async {
    final result = await flutterTts.stop();
    if (result == 1) {
      updateTtsState(TtsStateEnum.paused);
      _stopHighlightTimer(); // 暂停时停止高亮计时器
    }
  }

  @override
  Future<void> resume() async {
    if (isAndroid) {
      speak(content: _prevVoiceText);
    } else {
      speak(content: _currentVoiceText);
    }
    // resume会在speak中通过setStartHandler重新启动高亮计时器
  }

  @override
  Future<void> prev() async {
    if (restarting) {
      return;
    }
    restarting = true;
    await stop();
    _currentVoiceText = await getPrevTextFunction();
    speak();
    restarting = false;
  }

  @override
  Future<void> next() async {
    if (restarting) {
      return;
    }
    restarting = true;
    await stop();
    _currentVoiceText = await getNextTextFunction();
    speak();
    restarting = false;
  }

  @override
  Future<void> restart() async {
    if (restarting) {
      return;
    }
    restarting = true;
    await stop();
    speak();
    restarting = false;
  }

  @override
  Future<void> dispose() async {
    await flutterTts.stop();
  }

  // Preference helpers
  double _getVolume() {
    // Default to 1.0 if not set
    return 1.0;
  }

  void _setVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tts_volume', volume);
  }

  double _getPitch() {
    // Default to 1.0 if not set
    return 1.0;
  }

  void _setPitch(double pitch) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tts_pitch', pitch);
  }

  double _getRate() {
    // Default to 0.5 if not set
    return 0.5;
  }

  void _setRate(double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tts_rate', rate);
  }
}
