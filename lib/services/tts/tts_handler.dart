import 'package:flutter/material.dart';
import 'base_tts.dart';
import 'tts_factory.dart';

class TtsHandler extends ChangeNotifier {
  final TtsFactory _ttsFactory = TtsFactory();

  TtsHandler() {
    _initAudioSession();
  }

  BaseTts get tts => _ttsFactory.current;

  Future<void> init(
    Function getCurrentText,
    Function getNextText,
    Function getPrevText,
  ) async {
    await tts.init(getCurrentText, getNextText, getPrevText);
  }

  Future<void> _initAudioSession() async {
    // TODO: 实现音频会话管理
    debugPrint('音频会话初始化（模拟）');
  }

  Future<void> play() async {
    if (tts.ttsStateNotifier.value == TtsStateEnum.paused) {
      tts.updateTtsState(TtsStateEnum.playing);
      await tts.resume();
    } else {
      tts.updateTtsState(TtsStateEnum.playing);
      await tts.speak();
    }
  }

  Future<void> pause() async {
    await tts.pause();
    tts.updateTtsState(TtsStateEnum.paused);
  }

  Future<void> stop() async {
    tts.updateTtsState(TtsStateEnum.stopped);
    await tts.stop();
  }

  Future<void> playPrevious() async {
    await tts.prev();
  }

  Future<void> playNext() async {
    await tts.next();
  }

  Future<void> switchTtsType(bool useSystemTts) async {
    await _ttsFactory.switchTtsType(useSystemTts);
  }

  ValueNotifier<TtsStateEnum> get ttsStateNotifier => tts.ttsStateNotifier;

  bool get isPlaying => tts.isPlaying;

  set volume(double volume) {
    tts.volume = volume;
  }

  double get volume => tts.volume;

  set pitch(double pitch) {
    tts.pitch = pitch;
  }

  double get pitch => tts.pitch;

  set rate(double rate) {
    tts.rate = rate;
  }

  double get rate => tts.rate;
}
