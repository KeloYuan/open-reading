import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'base_tts.dart';
import 'tts_preferences.dart';

class SystemTts extends BaseTts {
  static final SystemTts _instance = SystemTts._internal();

  factory SystemTts() {
    return _instance;
  }

  SystemTts._internal();

  late FlutterTts flutterTts;

  String? _currentVoiceText;

  bool restarting = false;
  bool _isTtsEngineReady = false; // TTS引擎是否就绪
  final List<Function> _pendingSpeakTasks = []; // 待执行的朗读任务
  int _speakRetryCount = 0; // speak重试计数
  static const int _maxSpeakRetries = 2; // 最大重试次数

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

  /// 当前音色
  TtsVoice? _currentVoice;
  List<TtsVoice> _availableVoices = [];
  bool _hasLoadedVoices = false;

  @override
  void updateTtsState(TtsStateEnum newState) {
    ttsStateNotifier.value = newState;
  }

  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  bool get isWindows => !kIsWeb && Platform.isWindows;
  bool get isWeb => kIsWeb;

  @override
  double get volume => TtsPreferences().volume;

  @override
  set volume(double volume) {
    TtsPreferences().volume = volume;
    restart();
  }

  @override
  double get pitch => TtsPreferences().pitch;

  @override
  set pitch(double pitch) {
    TtsPreferences().pitch = pitch;
    restart();
  }

  @override
  double get rate => TtsPreferences().rate;

  @override
  set rate(double rate) {
    TtsPreferences().rate = rate;
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
    try {
      debugPrint('🔧 开始初始化TTS引擎...');

      // 初始化配置
      await TtsPreferences().init();

      getHereFunction = getCurrentText;
      getNextTextFunction = getNextText;
      getPrevTextFunction = getPrevText;

      // 创建新的FlutterTts实例并等待初始化完成
      flutterTts = FlutterTts();
      debugPrint('   ✅ FlutterTts实例已创建');

      // Android平台：给TTS引擎足够的初始化时间
      if (isAndroid) {
        debugPrint('   ⏳ 等待Android TTS引擎初始化（2秒）...');
        await Future.delayed(const Duration(seconds: 2));
        debugPrint('   ✅ TTS引擎初始化等待完成');
      }

      // 设置语言
      await flutterTts.setLanguage(TtsPreferences().language);
      debugPrint('   语言设置: ${TtsPreferences().language}');

      // 设置TTS基础参数
      await flutterTts.setVolume(TtsPreferences().volume);
      await flutterTts.setSpeechRate(TtsPreferences().rate);
      await flutterTts.setPitch(TtsPreferences().pitch);
      debugPrint('   TTS参数设置: 音量=${TtsPreferences().volume}, 语速=${TtsPreferences().rate}, 音调=${TtsPreferences().pitch}');

      // Android平台需要特殊配置
      if (isAndroid) {
        // 设置TTS引擎（如果有指定）
        final preferredEngine = TtsPreferences().ttsEngine;
        if (preferredEngine != null && preferredEngine.isNotEmpty) {
          try {
            await flutterTts.setEngine(preferredEngine);
            debugPrint('   ✅ 已设置TTS引擎: $preferredEngine');
          } catch (e) {
            debugPrint('   ⚠️ 设置TTS引擎失败，使用默认引擎: $e');
          }
        } else {
          debugPrint('   ℹ️ 使用系统默认TTS引擎');
        }

        await flutterTts.awaitSpeakCompletion(true);
        await flutterTts.awaitSynthCompletion(true);
        await flutterTts.setQueueMode(1);
        debugPrint('   ✅ Android TTS队列模式已启用');
      }

      debugPrint('   ✅ TTS引擎配置完成');

      // 加载保存的音色设置
      await _loadSavedVoice();

      // 标记引擎已就绪
      _isTtsEngineReady = true;
      debugPrint('   ✅ TTS引擎已就绪，可以开始朗读');

      // 执行待处理的朗读任务
      if (_pendingSpeakTasks.isNotEmpty) {
        debugPrint('   🔄 执行 ${_pendingSpeakTasks.length} 个待处理的朗读任务');
        for (final task in _pendingSpeakTasks) {
          await task();
        }
        _pendingSpeakTasks.clear();
      }

      flutterTts.setStartHandler(() async {
        debugPrint('🎬 TTS开始播放回调');
        _speakRetryCount = 0; // 重置重试计数
        updateTtsState(TtsStateEnum.playing);
        _startHighlightTimer(); // 开始句子高亮
      });

      flutterTts.setCompletionHandler(() async {
        debugPrint('🏁 TTS播放完成回调');
        _stopHighlightTimer();
        _resetHighlightedSentence();

        // 播放完成后，自动播放下一段（如果需要的话）
        // 这里暂时停止，让用户手动控制
        updateTtsState(TtsStateEnum.stopped);
      });

      flutterTts.setErrorHandler((msg) {
        debugPrint('❌ TTS错误回调: $msg');

        // 在OPPO等设备上，合成错误后需要重试
        if (_speakRetryCount < _maxSpeakRetries && _currentVoiceText != null) {
          _speakRetryCount++;
          debugPrint('⚠️ TTS合成失败，尝试重试 (第$_speakRetryCount次)...');

          // 延迟后重试
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_currentVoiceText != null) {
              speak(content: _currentVoiceText);
            }
          });
        } else {
          debugPrint('❌ TTS重试次数已达上限或无内容，停止播放');
          updateTtsState(TtsStateEnum.stopped);
          _stopHighlightTimer();
          _resetHighlightedSentence();
        }
      });

      flutterTts.setCancelHandler(() {
        debugPrint('⏸️ TTS取消回调');
        updateTtsState(TtsStateEnum.stopped);
        _stopHighlightTimer();
        _resetHighlightedSentence();
      });

      flutterTts.setPauseHandler(() {
        debugPrint('⏸️ TTS暂停回调');
        updateTtsState(TtsStateEnum.paused);
        _stopHighlightTimer();
      });

      flutterTts.setContinueHandler(() {
        debugPrint('▶️ TTS继续回调');
        updateTtsState(TtsStateEnum.playing);
        _startHighlightTimer();
      });

      debugPrint('✅ TTS引擎初始化完成');
    } catch (e, stack) {
      debugPrint('❌ TTS初始化失败: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
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

  /// 获取可用的TTS引擎列表（仅Android）
  Future<List<dynamic>> getAvailableEngines() async {
    if (!isAndroid) {
      return [];
    }
    try {
      final engines = await flutterTts.getEngines;
      debugPrint('📋 可用的TTS引擎: $engines');
      return engines ?? [];
    } catch (e) {
      debugPrint('❌ 获取TTS引擎列表失败: $e');
      return [];
    }
  }

  /// 设置TTS引擎（仅Android）
  Future<bool> setTtsEngine(String engineName) async {
    if (!isAndroid) {
      return false;
    }
    try {
      debugPrint('🔧 正在切换TTS引擎到: $engineName');
      await flutterTts.setEngine(engineName);
      TtsPreferences().ttsEngine = engineName;
      debugPrint('✅ TTS引擎切换成功');
      return true;
    } catch (e) {
      debugPrint('❌ TTS引擎切换失败: $e');
      return false;
    }
  }

  @override
  Future<void> speak({String? content}) async {
    try {
      debugPrint('📢 SystemTts.speak() 被调用');
      debugPrint(
          '   参数 content: ${content != null ? "有 (${content.length}字符)" : "null"}');

      // 必须提供内容
      if (content == null || content.isEmpty) {
        debugPrint('   ❌ 验证失败: 文本为 ${content == null ? "null" : "空字符串"}');
        return;
      }

      _currentVoiceText = content;
      debugPrint('   ✅ 验证通过，准备朗读文本，长度: ${_currentVoiceText!.length}');
      debugPrint(
          '   文本预览: ${_currentVoiceText!.substring(0, _currentVoiceText!.length.clamp(0, 100))}...');

      // 检查TTS引擎是否就绪
      if (!_isTtsEngineReady) {
        debugPrint('   ⏳ TTS引擎未就绪，将任务加入队列');
        _pendingSpeakTasks.add(() => speak(content: content));
        return;
      }

      // 分割当前文本为句子，用于高亮显示
      _currentSentences = _splitIntoSentences(_currentVoiceText!);
      debugPrint('   ✅ 分割为 ${_currentSentences.length} 个句子');

      // 简化设置：只设置必要参数
      debugPrint('   设置TTS参数: 音量=$volume, 语速=$rate, 音调=$pitch');
      await flutterTts.setVolume(volume);
      await flutterTts.setSpeechRate(rate);
      await flutterTts.setPitch(pitch);

      // 开始朗读
      debugPrint('🎤 开始朗读: "${_currentVoiceText!.substring(0, _currentVoiceText!.length.clamp(0, 50))}..."');

      // 调用TTS引擎播放
      final result = await flutterTts.speak(_currentVoiceText!);
      debugPrint('✅ TTS speak() 返回结果: $result');

      debugPrint('✅ SystemTts.speak() 完成');
    } catch (e, stackTrace) {
      debugPrint('❌ SystemTts.speak() 发生错误: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
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
    speak(content: _currentVoiceText);
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
    _stopHighlightTimer();
    await flutterTts.stop();
  }

  @override
  TtsVoice? get currentVoice => _currentVoice;

  @override
  Future<void> setVoice(TtsVoice voice) async {
    try {
      debugPrint('🔊 设置音色: ${voice.label} (${voice.id})');

      // iOS: 设置语音
      if (isIOS) {
        await flutterTts.setVoice({
          'name': voice.name,
          'locale': voice.locale,
        });
        debugPrint('   ✅ iOS 音色已设置');
      }
      // Android: 设置语言和语音
      else if (isAndroid) {
        await flutterTts.setLanguage(voice.locale);
        if (voice.name.isNotEmpty) {
          await flutterTts.setVoice({
            'name': voice.name,
            'locale': voice.locale,
          });
        }
        debugPrint('   ✅ Android 音色已设置');
      }

      _currentVoice = voice;
      TtsPreferences().voiceId = voice.id;

      // 如果正在播放，重新应用音色
      if (_currentVoiceText != null && ttsStateNotifier.value == TtsStateEnum.playing) {
        debugPrint('   🔄 重新应用音色到当前播放');
        await stop();
        await Future.delayed(const Duration(milliseconds: 100));
        await speak(content: _currentVoiceText);
      }

      debugPrint('✅ 音色设置完成');
    } catch (e, stack) {
      debugPrint('❌ 设置音色失败: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  @override
  Future<List<TtsVoice>> getVoices() async {
    if (_hasLoadedVoices && _availableVoices.isNotEmpty) {
      return _availableVoices;
    }

    try {
      debugPrint('🔍 获取可用音色列表...');

      final voices = <TtsVoice>[];

      // iOS: 获取语音列表
      if (isIOS) {
        final iosVoices = await flutterTts.getVoices;
        if (iosVoices != null) {
          for (final voice in iosVoices) {
            if (voice is Map<String, dynamic>) {
              final name = voice['name'] as String? ?? '';
              final locale = voice['locale'] as String? ?? 'zh-CN';
              voices.add(TtsVoice(
                name: name,
                locale: locale,
                identifier: name,
                displayName: voice['displayName'] as String?,
              ));
            }
          }
        }
        debugPrint('   ✅ iOS: 找到 ${voices.length} 个音色');
      }
      // Android: 获取语音列表
      else if (isAndroid) {
        // Android 需要先设置语言才能获取该语言的语音
        final currentLang = TtsPreferences().language;
        final androidVoices = await flutterTts.getVoices;
        if (androidVoices != null) {
          for (final voice in androidVoices) {
            if (voice is Map<String, dynamic>) {
              final name = voice['name'] as String? ?? '';
              final locale = voice['locale'] as String? ?? currentLang;
              voices.add(TtsVoice(
                name: name,
                locale: locale,
                identifier: name,
                displayName: voice['displayName'] as String?,
              ));
            }
          }
        }
        debugPrint('   ✅ Android: 找到 ${voices.length} 个音色');
      }
      // Windows: 使用 getLanguages 模拟
      else if (isWindows) {
        final languages = await flutterTts.getLanguages;
        if (languages != null) {
          for (final lang in languages) {
            if (lang is String) {
              voices.add(TtsVoice(
                name: 'Default',
                locale: lang,
                displayName: lang,
              ));
            }
          }
        }
        debugPrint('   ✅ Windows: 找到 ${voices.length} 个音色');
      }

      _availableVoices = voices;
      _hasLoadedVoices = true;

      debugPrint('✅ 共找到 ${voices.length} 个可用音色');
      return voices;
    } catch (e, stack) {
      debugPrint('❌ 获取音色列表失败: $e');
      debugPrint('Stack: $stack');
      return [];
    }
  }

  @override
  Future<List<TtsVoice>> getVoicesByLanguage(String language) async {
    final allVoices = await getVoices();
    final filtered = allVoices.where((v) => v.locale.startsWith(language)).toList();
    debugPrint('🔍 语言 $language 的音色: ${filtered.length} 个');
    return filtered;
  }

  /// 初始化时加载并应用保存的音色
  Future<void> _loadSavedVoice() async {
    try {
      final savedVoiceId = TtsPreferences().voiceId;
      if (savedVoiceId == null) {
        debugPrint('   ℹ️ 无保存的音色设置，使用系统默认');
        return;
      }

      debugPrint('   🔄 加载保存的音色: $savedVoiceId');

      final voices = await getVoices();
      final savedVoice = voices.where((v) => v.id == savedVoiceId).firstOrNull;

      if (savedVoice != null) {
        _currentVoice = savedVoice;
        // iOS/Android: 设置语音
        if (isIOS || isAndroid) {
          await flutterTts.setVoice({
            'name': savedVoice.name,
            'locale': savedVoice.locale,
          });
          if (isAndroid) {
            await flutterTts.setLanguage(savedVoice.locale);
          }
        }
        debugPrint('   ✅ 已加载保存的音色: ${savedVoice.label}');
      } else {
        debugPrint('   ⚠️ 保存的音色不存在，使用系统默认');
      }
    } catch (e) {
      debugPrint('   ⚠️ 加载保存的音色失败: $e');
    }
  }
}
