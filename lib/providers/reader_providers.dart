import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/advanced_text_paginator.dart';
import '../services/tts/system_tts.dart';
import '../services/tts/base_tts.dart';

/// 翻页模式枚举
enum PaginationMode {
  slide, // 左右滑动
  scroll, // 上下滚动
  simulation, // 仿真翻页
}

/// 阅读主题枚举
enum ReadingTheme {
  day, // 白天模式
  night, // 夜间模式
  eyeCare, // 护眼模式
}

/// 阅读器设置状态
class ReaderSettings {
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final EdgeInsets padding;
  final ReadingTheme theme;
  final PaginationMode paginationMode;
  final bool showPageIndicator;
  final bool enableTextSelection;

  const ReaderSettings({
    this.fontSize = 18.0,
    this.lineHeight = 1.8,
    this.letterSpacing = 0.2,
    this.padding = const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
    this.theme = ReadingTheme.day,
    this.paginationMode = PaginationMode.slide,
    this.showPageIndicator = true,
    this.enableTextSelection = true,
  });

  /// 复制并修改设置
  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? letterSpacing,
    EdgeInsets? padding,
    ReadingTheme? theme,
    PaginationMode? paginationMode,
    bool? showPageIndicator,
    bool? enableTextSelection,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      padding: padding ?? this.padding,
      theme: theme ?? this.theme,
      paginationMode: paginationMode ?? this.paginationMode,
      showPageIndicator: showPageIndicator ?? this.showPageIndicator,
      enableTextSelection: enableTextSelection ?? this.enableTextSelection,
    );
  }

  /// 获取主题对应的文本样式
  TextStyle get textStyle {
    Color textColor;
    String? fontFamily;

    switch (theme) {
      case ReadingTheme.day:
        textColor = const Color(0xFF333333);
        break;
      case ReadingTheme.night:
        textColor = const Color(0xFFE0E0E0);
        break;
      case ReadingTheme.eyeCare:
        textColor = const Color(0xFF2D4A2B);
        break;
    }

    return TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      letterSpacing: letterSpacing,
      color: textColor,
      fontFamily: fontFamily,
      decoration: TextDecoration.none,
    );
  }

  /// 获取主题对应的背景色
  Color get backgroundColor {
    switch (theme) {
      case ReadingTheme.day:
        return const Color(0xFFFFFBF0);
      case ReadingTheme.night:
        return const Color(0xFF1A1A1A);
      case ReadingTheme.eyeCare:
        return const Color(0xFFF5F7E3);
    }
  }
}

/// 阅读器分页状态
class ReaderPaginationState {
  final List<String> pages;
  final int currentPageIndex;
  final bool isLoading;
  final String? error;
  final PaginationParams? paginationParams;

  const ReaderPaginationState({
    this.pages = const [],
    this.currentPageIndex = 0,
    this.isLoading = false,
    this.error,
    this.paginationParams,
  });

  /// 复制并修改状态
  ReaderPaginationState copyWith({
    List<String>? pages,
    int? currentPageIndex,
    bool? isLoading,
    String? error,
    PaginationParams? paginationParams,
  }) {
    return ReaderPaginationState(
      pages: pages ?? this.pages,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      paginationParams: paginationParams ?? this.paginationParams,
    );
  }

  /// 获取总页数
  int get totalPages => pages.length;

  /// 获取当前页内容
  String? get currentPageContent {
    if (pages.isEmpty || currentPageIndex >= pages.length) return null;
    return pages[currentPageIndex];
  }

  /// 获取阅读进度（0.0-1.0）
  double get progress {
    if (pages.isEmpty) return 0.0;
    return (currentPageIndex + 1) / pages.length;
  }

  /// 是否有下一页
  bool get hasNextPage => currentPageIndex < pages.length - 1;

  /// 是否有上一页
  bool get hasPreviousPage => currentPageIndex > 0;
}

/// 工具栏显示状态
class ToolbarState {
  final bool isVisible;
  final double opacity;

  const ToolbarState({
    this.isVisible = false,
    this.opacity = 0.0,
  });

  ToolbarState copyWith({
    bool? isVisible,
    double? opacity,
  }) {
    return ToolbarState(
      isVisible: isVisible ?? this.isVisible,
      opacity: opacity ?? this.opacity,
    );
  }
}

/// TTS状态
class ReaderTtsState {
  final bool isPlaying;
  final bool isPaused;
  final TtsStateEnum ttsState;
  final String? currentSpeakingText;
  final int? highlightedSentenceIndex;
  final double volume;
  final double pitch;
  final double rate;

  const ReaderTtsState({
    this.isPlaying = false,
    this.isPaused = false,
    this.ttsState = TtsStateEnum.stopped,
    this.currentSpeakingText,
    this.highlightedSentenceIndex,
    this.volume = 1.0,
    this.pitch = 1.0,
    this.rate = 0.5,
  });

  ReaderTtsState copyWith({
    bool? isPlaying,
    bool? isPaused,
    TtsStateEnum? ttsState,
    String? currentSpeakingText,
    int? highlightedSentenceIndex,
    double? volume,
    double? pitch,
    double? rate,
  }) {
    return ReaderTtsState(
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      ttsState: ttsState ?? this.ttsState,
      currentSpeakingText: currentSpeakingText ?? this.currentSpeakingText,
      highlightedSentenceIndex:
          highlightedSentenceIndex ?? this.highlightedSentenceIndex,
      volume: volume ?? this.volume,
      pitch: pitch ?? this.pitch,
      rate: rate ?? this.rate,
    );
  }
}

/// 阅读器设置状态管理 - Riverpod StateNotifier
class ReaderSettingsNotifier extends StateNotifier<ReaderSettings> {
  ReaderSettingsNotifier() : super(const ReaderSettings());

  /// 更新字体大小
  void updateFontSize(double fontSize) {
    state = state.copyWith(fontSize: fontSize.clamp(12.0, 36.0));
  }

  /// 更新行高
  void updateLineHeight(double lineHeight) {
    state = state.copyWith(lineHeight: lineHeight.clamp(1.0, 3.0));
  }

  /// 更新字间距
  void updateLetterSpacing(double letterSpacing) {
    state = state.copyWith(letterSpacing: letterSpacing.clamp(-1.0, 2.0));
  }

  /// 更新页边距
  void updatePadding(EdgeInsets padding) {
    state = state.copyWith(padding: padding);
  }

  /// 切换阅读主题
  void switchTheme(ReadingTheme theme) {
    state = state.copyWith(theme: theme);
  }

  /// 切换翻页模式
  void switchPaginationMode(PaginationMode mode) {
    state = state.copyWith(paginationMode: mode);
  }

  /// 切换页面指示器显示
  void togglePageIndicator() {
    state = state.copyWith(showPageIndicator: !state.showPageIndicator);
  }

  /// 切换文本选择功能
  void toggleTextSelection() {
    state = state.copyWith(enableTextSelection: !state.enableTextSelection);
  }
}

/// 阅读器分页状态管理 - Riverpod StateNotifier
class ReaderPaginationNotifier extends StateNotifier<ReaderPaginationState> {
  ReaderPaginationNotifier() : super(const ReaderPaginationState());

  /// 初始化分页
  Future<void> initializePagination({
    required String text,
    required Size screenSize,
    required ReaderSettings settings,
  }) async {
    if (text.isEmpty) {
      state = state.copyWith(
        error: '文本内容为空',
        isLoading: false,
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // 计算分页参数
      final params = AdvancedTextPaginator.calculatePreciseParams(
        screenSize: screenSize,
        fontSize: settings.fontSize,
        lineHeight: settings.lineHeight,
        letterSpacing: settings.letterSpacing,
        padding: settings.padding,
        statusBarHeight: 0.0,
        controlBarHeight: 0.0,
        isLandscape: screenSize.width > screenSize.height,
      );

      // 执行分页
      final pages = AdvancedTextPaginator.paginateText(text, params);

      if (pages.isEmpty) {
        throw Exception('分页结果为空');
      }

      state = state.copyWith(
        pages: pages,
        currentPageIndex: 0,
        isLoading: false,
        paginationParams: params,
      );

      debugPrint('✅ 分页初始化完成: ${pages.length}页');
    } catch (e) {
      state = state.copyWith(
        error: '分页失败: $e',
        isLoading: false,
      );
      debugPrint('❌ 分页初始化失败: $e');
    }
  }

  /// 跳转到指定页面
  void goToPage(int pageIndex) {
    if (state.pages.isEmpty) return;

    final targetIndex = pageIndex.clamp(0, state.pages.length - 1);
    if (targetIndex != state.currentPageIndex) {
      state = state.copyWith(currentPageIndex: targetIndex);
    }
  }

  /// 下一页
  void nextPage() {
    if (state.hasNextPage) {
      state = state.copyWith(currentPageIndex: state.currentPageIndex + 1);
    }
  }

  /// 上一页
  void previousPage() {
    if (state.hasPreviousPage) {
      state = state.copyWith(currentPageIndex: state.currentPageIndex - 1);
    }
  }

  /// 跳转到进度位置
  void goToProgress(double progress) {
    if (state.pages.isEmpty) return;

    final targetPage = (progress * state.pages.length).floor();
    goToPage(targetPage);
  }
}

/// 工具栏状态管理 - Riverpod StateNotifier
class ToolbarNotifier extends StateNotifier<ToolbarState> {
  ToolbarNotifier() : super(const ToolbarState());

  /// 显示工具栏
  void show() {
    state = state.copyWith(isVisible: true, opacity: 1.0);
  }

  /// 隐藏工具栏
  void hide() {
    state = state.copyWith(isVisible: false, opacity: 0.0);
  }

  /// 切换工具栏显示状态
  void toggle() {
    if (state.isVisible) {
      hide();
    } else {
      show();
    }
  }

  /// 设置透明度
  void setOpacity(double opacity) {
    state = state.copyWith(opacity: opacity.clamp(0.0, 1.0));
  }
}

/// TTS状态管理 - Riverpod StateNotifier
class ReaderTtsNotifier extends StateNotifier<ReaderTtsState> {
  ReaderTtsNotifier() : super(const ReaderTtsState());

  late SystemTts _systemTts;
  bool _isInitialized = false;

  /// 初始化TTS
  Future<void> initialize({
    required Function getCurrentText,
    required Function getNextText,
    required Function getPrevText,
  }) async {
    if (_isInitialized) return;

    try {
      _systemTts = SystemTts();
      await _systemTts.init(getCurrentText, getNextText, getPrevText);

      // 监听TTS状态变化
      _systemTts.ttsStateNotifier.addListener(_onTtsStateChanged);

      // 设置句子高亮回调
      _systemTts.setSentenceHighlightCallback(_onSentenceHighlightChanged);

      _isInitialized = true;
      debugPrint('✅ TTS初始化完成');
    } catch (e) {
      debugPrint('❌ TTS初始化失败: $e');
    }
  }

  /// TTS状态变化回调
  void _onTtsStateChanged() {
    final ttsState = _systemTts.ttsStateNotifier.value;
    state = state.copyWith(
      ttsState: ttsState,
      isPlaying: ttsState == TtsStateEnum.playing,
      isPaused: ttsState == TtsStateEnum.paused,
      currentSpeakingText: _systemTts.currentVoiceText,
    );
  }

  /// 句子高亮变化回调
  void _onSentenceHighlightChanged(int? sentenceIndex) {
    state = state.copyWith(highlightedSentenceIndex: sentenceIndex);
  }

  /// 开始播放
  Future<void> play({String? text}) async {
    if (!_isInitialized) return;

    try {
      await _systemTts.speak(content: text);
    } catch (e) {
      debugPrint('❌ TTS播放失败: $e');
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    if (!_isInitialized) return;

    try {
      await _systemTts.pause();
    } catch (e) {
      debugPrint('❌ TTS暂停失败: $e');
    }
  }

  /// 继续播放
  Future<void> resume() async {
    if (!_isInitialized) return;

    try {
      await _systemTts.resume();
    } catch (e) {
      debugPrint('❌ TTS继续播放失败: $e');
    }
  }

  /// 停止播放
  Future<void> stop() async {
    if (!_isInitialized) return;

    try {
      await _systemTts.stop();
    } catch (e) {
      debugPrint('❌ TTS停止失败: $e');
    }
  }

  /// 上一句
  Future<void> previous() async {
    if (!_isInitialized) return;

    try {
      await _systemTts.prev();
    } catch (e) {
      debugPrint('❌ TTS上一句失败: $e');
    }
  }

  /// 下一句
  Future<void> next() async {
    if (!_isInitialized) return;

    try {
      await _systemTts.next();
    } catch (e) {
      debugPrint('❌ TTS下一句失败: $e');
    }
  }

  /// 更新音量
  void updateVolume(double volume) {
    final clampedVolume = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: clampedVolume);

    if (_isInitialized) {
      _systemTts.volume = clampedVolume;
    }
  }

  /// 更新音调
  void updatePitch(double pitch) {
    final clampedPitch = pitch.clamp(0.5, 2.0);
    state = state.copyWith(pitch: clampedPitch);

    if (_isInitialized) {
      _systemTts.pitch = clampedPitch;
    }
  }

  /// 更新语速
  void updateRate(double rate) {
    final clampedRate = rate.clamp(0.1, 2.0);
    state = state.copyWith(rate: clampedRate);

    if (_isInitialized) {
      _systemTts.rate = clampedRate;
    }
  }

  /// 设置高亮句子索引
  void setHighlightedSentence(int? index) {
    state = state.copyWith(highlightedSentenceIndex: index);
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _systemTts.ttsStateNotifier.removeListener(_onTtsStateChanged);
      _systemTts.dispose();
    }
    super.dispose();
  }
}

/// ============================================================================
/// Riverpod Providers
/// ============================================================================

/// 阅读器设置状态 Provider
final readerSettingsProvider =
    StateNotifierProvider<ReaderSettingsNotifier, ReaderSettings>((ref) {
  return ReaderSettingsNotifier();
});

/// 阅读器分页状态 Provider
final readerPaginationProvider =
    StateNotifierProvider<ReaderPaginationNotifier, ReaderPaginationState>(
        (ref) {
  return ReaderPaginationNotifier();
});

/// 工具栏状态 Provider
final toolbarProvider =
    StateNotifierProvider<ToolbarNotifier, ToolbarState>((ref) {
  return ToolbarNotifier();
});

/// TTS状态 Provider
final readerTtsProvider =
    StateNotifierProvider<ReaderTtsNotifier, ReaderTtsState>((ref) {
  return ReaderTtsNotifier();
});
