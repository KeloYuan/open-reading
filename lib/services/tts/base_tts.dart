import 'dart:async';
import 'package:flutter/material.dart';

enum TtsStateEnum { playing, stopped, paused, continued }

/// TTS音色模型
class TtsVoice {
  final String name;
  final String locale;
  final String? identifier;
  final String? displayName;

  const TtsVoice({
    required this.name,
    required this.locale,
    this.identifier,
    this.displayName,
  });

  /// 用于显示的标签
  String get label => displayName ?? name;

  /// 唯一标识符
  String get id => identifier ?? '$locale-$name';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TtsVoice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

abstract class BaseTts {
  double get volume;
  set volume(double volume);

  double get pitch;
  set pitch(double pitch);

  double get rate;
  set rate(double rate);

  ValueNotifier<TtsStateEnum> get ttsStateNotifier;
  void updateTtsState(TtsStateEnum newState);

  Future<void> init(
    Function getCurrentText,
    Function getNextText,
    Function getPrevText,
  );

  Future<void> speak({String? content});

  Future<dynamic> stop();

  Future<void> pause();

  Future<void> resume();

  Future<void> prev();

  Future<void> next();

  Future<void> restart();

  Future<void> dispose();

  bool get isPlaying;

  String? get currentVoiceText;

  /// 获取当前音色
  TtsVoice? get currentVoice;

  /// 设置音色
  Future<void> setVoice(TtsVoice voice);

  /// 获取可用音色列表
  Future<List<TtsVoice>> getVoices();

  /// 按语言筛选音色
  Future<List<TtsVoice>> getVoicesByLanguage(String language);
}
