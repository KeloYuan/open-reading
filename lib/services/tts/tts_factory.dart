import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'base_tts.dart';
import 'system_tts.dart';

class TtsFactory {
  static final TtsFactory _instance = TtsFactory._internal();

  factory TtsFactory() {
    return _instance;
  }

  TtsFactory._internal();

  BaseTts? _currentTts;

  BaseTts get current {
    _currentTts ??= createTts();
    return _currentTts!;
  }

  BaseTts createTts() {
    final bool isSystemTts = _getIsSystemTts();
    return isSystemTts ? SystemTts() : SystemTts(); // For now, only system TTS
  }

  Future<void> switchTtsType(bool useSystemTts) async {
    if (_getIsSystemTts() == useSystemTts) return;

    if (_currentTts != null) {
      await _currentTts!.stop();
      await _currentTts!.dispose();
      _currentTts = null;
    }

    await _setIsSystemTts(useSystemTts);
    _currentTts = createTts();
  }

  Future<void> dispose() async {
    if (_currentTts != null) {
      await _currentTts!.stop();
      await _currentTts!.dispose();
      _currentTts = null;
    }
  }

  ValueNotifier<TtsStateEnum> get ttsStateNotifier {
    return current.ttsStateNotifier;
  }

  // Preference helpers
  bool _getIsSystemTts() {
    // Default to true for system TTS
    return true;
  }

  Future<void> _setIsSystemTts(bool isSystemTts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_system_tts', isSystemTts);
  }
}
