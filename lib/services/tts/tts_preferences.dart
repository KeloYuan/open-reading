import 'package:shared_preferences/shared_preferences.dart';

/// TTS配置管理类
///
/// 提供TTS相关配置的统一存取接口，包括音量、音调、语速、语言等设置
class TtsPreferences {
  static final TtsPreferences _instance = TtsPreferences._internal();

  factory TtsPreferences() => _instance;

  TtsPreferences._internal();

  SharedPreferences? _prefs;

  /// 初始化SharedPreferences
  ///
  /// 必须在使用其他方法前调用
  ///
  /// 示例:
  /// ```dart
  /// await TtsPreferences().init();
  /// ```
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 音量 (0.0 - 1.0)
  double get volume {
    return _prefs?.getDouble('tts_volume') ?? 1.0;
  }

  set volume(double value) {
    _prefs?.setDouble('tts_volume', value.clamp(0.0, 1.0));
  }

  /// 音调 (0.5 - 2.0)
  double get pitch {
    return _prefs?.getDouble('tts_pitch') ?? 1.0;
  }

  set pitch(double value) {
    _prefs?.setDouble('tts_pitch', value.clamp(0.5, 2.0));
  }

  /// 语速 (0.1 - 2.0)
  double get rate {
    return _prefs?.getDouble('tts_rate') ?? 0.5;
  }

  set rate(double value) {
    _prefs?.setDouble('tts_rate', value.clamp(0.1, 2.0));
  }

  /// 语言代码 (如: zh-CN, en-US)
  String get language {
    return _prefs?.getString('tts_language') ?? 'zh-CN';
  }

  set language(String value) {
    _prefs?.setString('tts_language', value);
  }

  /// 是否使用系统TTS
  bool get isSystemTts {
    return _prefs?.getBool('tts_is_system') ?? true;
  }

  set isSystemTts(bool value) {
    _prefs?.setBool('tts_is_system', value);
  }

  /// TTS引擎名称（Android平台）
  /// null表示使用系统默认引擎
  String? get ttsEngine {
    return _prefs?.getString('tts_engine');
  }

  set ttsEngine(String? value) {
    if (value == null) {
      _prefs?.remove('tts_engine');
    } else {
      _prefs?.setString('tts_engine', value);
    }
  }

  /// 当前音色标识符
  String? get voiceId {
    return _prefs?.getString('tts_voice_id');
  }

  set voiceId(String? value) {
    if (value == null) {
      _prefs?.remove('tts_voice_id');
    } else {
      _prefs?.setString('tts_voice_id', value);
    }
  }

  /// 清除所有TTS配置
  Future<void> clear() async {
    await _prefs?.remove('tts_volume');
    await _prefs?.remove('tts_pitch');
    await _prefs?.remove('tts_rate');
    await _prefs?.remove('tts_language');
    await _prefs?.remove('tts_is_system');
    await _prefs?.remove('tts_engine');
    await _prefs?.remove('tts_voice_id');
  }

  /// 重置为默认值
  Future<void> reset() async {
    volume = 1.0;
    pitch = 1.0;
    rate = 0.5;
    language = 'zh-CN';
    isSystemTts = true;
  }
}
