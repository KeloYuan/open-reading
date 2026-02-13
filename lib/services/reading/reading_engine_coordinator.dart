import 'package:flutter/foundation.dart';

/// 阅读引擎协调器（简化版）
/// 只使用沉浸式阅读器
class ReadingEngineCoordinator {
  static final ReadingEngineCoordinator _instance =
      ReadingEngineCoordinator._internal();
  factory ReadingEngineCoordinator() => _instance;
  ReadingEngineCoordinator._internal();

  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  /// 只使用沉浸式阅读器，不需要引擎选择

  /// 初始化协调器
  Future<void> initialize() => ensureInitialized();

  Future<void> ensureInitialized() {
    _initializationFuture ??= _doInitialize();
    return _initializationFuture!;
  }

  Future<void> _doInitialize() async {
    if (_isInitialized) {
      return;
    }

    _isInitialized = true;
    debugPrint('📖 ReadingEngineCoordinator 初始化完成（简化版）');
  }
}

/// 阅读引擎类型（简化版，仅保留沉浸式阅读器）
enum ReadingEngineType {
  immersive, // 沉浸式阅读器
}
