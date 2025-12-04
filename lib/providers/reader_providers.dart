import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';
import '../services/enhanced_paginator.dart';
import '../services/pagination_cache_service.dart';
import '../services/tts/system_tts.dart';
import '../services/tts/base_tts.dart';
import '../services/reader_settings_service.dart';
import '../models/page_turning_config.dart';

/// 翻页模式枚举
enum PaginationMode {
  cover, // 覆盖翻页
  slide, // 左右滑动
  scroll, // 上下滚动
  simulation, // 仿真翻页
}

/// 阅读主题枚举
enum ReadingTheme {
  day, // 白天模式 - 米黄色
  night, // 夜间模式 - 深灰色
  eyeCare, // 护眼模式 - 豆沙绿
  warmPaper, // 温暖纸张 - 暖黄色
  coolGray, // 冷灰色 - 浅灰蓝
  sepia, // 复古棕褐 - 棕褐色
  pureBlack, // 纯黑模式 - OLED黑
  blueLight, // 蓝光护眼 - 淡蓝
}

/// 阅读器设置状态
class ReaderSettings {
  final double fontSize;
  final double lineSpacing; // 行距（1.0-3.0倍字体大小）
  final double letterSpacing;
  final EdgeInsets padding;
  final ReadingTheme theme;
  final PaginationMode paginationMode;
  final bool showPageIndicator;
  final bool enableTextSelection;
  final double firstLineIndent; // 首行缩进（0-4字符）
  final double horizontalMargin; // 水平页边距（10-40px）
  final bool enableFirstLineIndent; // 是否启用首行缩进（默认关闭）
  final int paragraphSpacing; // 段落间距（0-2行空行）

  const ReaderSettings({
    this.fontSize = 18.0,
    this.lineSpacing = 1.8,
    this.letterSpacing = 0.2,
    this.padding =
        const EdgeInsets.only(left: 20.0, right: 20.0, top: 60.0, bottom: 60.0),
    this.theme = ReadingTheme.day,
    this.paginationMode = PaginationMode.slide,
    this.showPageIndicator = true,
    this.enableTextSelection = true,
    this.firstLineIndent = 2.0,
    this.horizontalMargin = 20.0,
    this.enableFirstLineIndent = false,
    this.paragraphSpacing = 0, // 默认0行空行（段落紧密排列）
  });

  /// 复制并修改设置
  ReaderSettings copyWith({
    double? fontSize,
    double? lineSpacing,
    double? letterSpacing,
    EdgeInsets? padding,
    ReadingTheme? theme,
    PaginationMode? paginationMode,
    bool? showPageIndicator,
    bool? enableTextSelection,
    double? firstLineIndent,
    double? horizontalMargin,
    bool? enableFirstLineIndent,
    int? paragraphSpacing,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      padding: padding ?? this.padding,
      theme: theme ?? this.theme,
      paginationMode: paginationMode ?? this.paginationMode,
      showPageIndicator: showPageIndicator ?? this.showPageIndicator,
      enableTextSelection: enableTextSelection ?? this.enableTextSelection,
      firstLineIndent: firstLineIndent ?? this.firstLineIndent,
      horizontalMargin: horizontalMargin ?? this.horizontalMargin,
      enableFirstLineIndent:
          enableFirstLineIndent ?? this.enableFirstLineIndent,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
    );
  }

  /// 获取当前点击翻页方案（固定为默认方案）
  TapTurningPattern get tapTurningPattern {
    return TapTurningPattern.defaultPattern;
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
      case ReadingTheme.warmPaper:
        textColor = const Color(0xFF5D4E37);
        break;
      case ReadingTheme.coolGray:
        textColor = const Color(0xFF37474F);
        break;
      case ReadingTheme.sepia:
        textColor = const Color(0xFF3E2723);
        break;
      case ReadingTheme.pureBlack:
        textColor = const Color(0xFFCCCCCC);
        break;
      case ReadingTheme.blueLight:
        textColor = const Color(0xFF1A237E);
        break;
    }

    return TextStyle(
      fontSize: fontSize,
      height: lineSpacing,
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
        return const Color(0xFFFFFBF0); // 米黄色
      case ReadingTheme.night:
        return const Color(0xFF1A1A1A); // 深灰色
      case ReadingTheme.eyeCare:
        return const Color(0xFFC7EDCC); // 豆沙绿
      case ReadingTheme.warmPaper:
        return const Color(0xFFFFF8E1); // 温暖纸张
      case ReadingTheme.coolGray:
        return const Color(0xFFECEFF1); // 冷灰色
      case ReadingTheme.sepia:
        return const Color(0xFFF4ECD8); // 复古棕褐
      case ReadingTheme.pureBlack:
        return const Color(0xFF000000); // 纯黑OLED
      case ReadingTheme.blueLight:
        return const Color(0xFFE3F2FD); // 蓝光护眼
    }
  }

  /// 获取主题显示名称
  String get themeName {
    switch (theme) {
      case ReadingTheme.day:
        return '白天';
      case ReadingTheme.night:
        return '夜间';
      case ReadingTheme.eyeCare:
        return '护眼';
      case ReadingTheme.warmPaper:
        return '温暖纸张';
      case ReadingTheme.coolGray:
        return '冷灰';
      case ReadingTheme.sepia:
        return '复古';
      case ReadingTheme.pureBlack:
        return '纯黑';
      case ReadingTheme.blueLight:
        return '蓝光护眼';
    }
  }

  /// 根据屏幕尺寸计算响应式padding
  /// 确保文字区域避开四角状态UI，不重叠
  /// 顶部状态UI：top=1%屏高 + 时间/电池区域
  /// 底部状态UI：bottom=1%屏高 + 页码/进度区域
  EdgeInsets getResponsivePadding(Size screenSize) {
    // 顶部：1%屏高 + 32px（避开时间/电池即可，状态栏在渲染时单独处理）
    final topPadding = screenSize.height * 0.01;

    // 底部：1%屏高 + 24px（给页码/进度留空间）
    final bottomPadding = screenSize.height * 0.01;

    return EdgeInsets.only(
      left: horizontalMargin,
      right: horizontalMargin,
      top: topPadding,
      bottom: bottomPadding,
    );
  }
}

/// 阅读器分页状态
class ReaderPaginationState {
  final List<String> pages;
  final int currentPageIndex;
  final bool isLoading;
  final String? error;
  final ReaderSettings? paginationSettings; // 保存分页时使用的settings（包含响应式padding）
  final String? cachedText; // 缓存的文本内容
  final String? cacheKey; // 缓存键（排版参数的哈希）
  final bool isProgressiveLoading; // 是否正在渐进式加载
  final String? loadingStage; // 加载阶段提示
  final List<int>? pageCharOffsets; // 每页在原文中的字符起始位置
  final Size? screenSize; // 保存屏幕尺寸用于后台分页
  final List<PageContent>? pageContents; // 每页的内容（包含文本和图片）
  final List<double>? pageExtraLineSpacing; // 每页的额外行间距（用于底部对齐）
  final int? maxLinesPerPage; // 每页最大行数（用于精确分页器）
  final int? estimatedTotal; // 估算的总页数（渐进式分页）
  final bool? isEstimated; // 当前页码是否为估算值

  const ReaderPaginationState({
    this.pages = const [],
    this.currentPageIndex = 0,
    this.isLoading = false,
    this.error,
    this.paginationSettings,
    this.cachedText,
    this.cacheKey,
    this.isProgressiveLoading = false,
    this.loadingStage,
    this.pageCharOffsets,
    this.screenSize,
    this.pageContents,
    this.pageExtraLineSpacing,
    this.maxLinesPerPage,
    this.estimatedTotal,
    this.isEstimated,
  });

  /// 复制并修改状态
  ReaderPaginationState copyWith({
    List<String>? pages,
    int? currentPageIndex,
    bool? isLoading,
    String? error,
    ReaderSettings? paginationSettings,
    String? cachedText,
    String? cacheKey,
    bool? isProgressiveLoading,
    String? loadingStage,
    List<int>? pageCharOffsets,
    Size? screenSize,
    List<PageContent>? pageContents,
    List<double>? pageExtraLineSpacing,
    int? maxLinesPerPage,
    int? estimatedTotal,
    bool? isEstimated,
  }) {
    return ReaderPaginationState(
      pages: pages ?? this.pages,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      paginationSettings: paginationSettings ?? this.paginationSettings,
      cachedText: cachedText ?? this.cachedText,
      cacheKey: cacheKey ?? this.cacheKey,
      isProgressiveLoading: isProgressiveLoading ?? this.isProgressiveLoading,
      loadingStage: loadingStage ?? this.loadingStage,
      pageCharOffsets: pageCharOffsets ?? this.pageCharOffsets,
      screenSize: screenSize ?? this.screenSize,
      pageContents: pageContents ?? this.pageContents,
      pageExtraLineSpacing: pageExtraLineSpacing ?? this.pageExtraLineSpacing,
      maxLinesPerPage: maxLinesPerPage ?? this.maxLinesPerPage,
      estimatedTotal: estimatedTotal ?? this.estimatedTotal,
      isEstimated: isEstimated ?? this.isEstimated,
    );
  }

  /// 获取总页数（如果是估算值，返回估算总数）
  int get totalPages {
    if (isEstimated == true && estimatedTotal != null) {
      return estimatedTotal!;
    }
    return pages.length;
  }

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

  /// 获取当前页面的字符起始位置
  ///
  /// 返回当前页面在原文中的字符偏移量
  /// 如果没有偏移量信息，返回null
  int? get currentCharOffset {
    if (pageCharOffsets == null ||
        pageCharOffsets!.isEmpty ||
        currentPageIndex >= pageCharOffsets!.length) {
      return null;
    }
    return pageCharOffsets![currentPageIndex];
  }
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
  Timer? _debounceTimer;
  Timer? _repaginateTimer; // 🔧 分页防抖计时器

  // 🔧 新增：设置变化回调，用于通知重新分页
  void Function()? onSettingsChanged;

  ReaderSettingsNotifier() : super(const ReaderSettings()) {
    // 初始化时从SharedPreferences加载设置
    _loadSettings();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _repaginateTimer?.cancel(); // 🔧 取消分页防抖
    super.dispose();
  }

  /// 从SharedPreferences加载设置
  Future<void> _loadSettings() async {
    try {
      final loadedSettings = await ReaderSettingsService.loadSettings();
      state = loadedSettings;
      debugPrint('✅ 阅读器设置已加载');
    } catch (e) {
      debugPrint('⚠️ 加载阅读器设置失败，使用默认值: $e');
    }
  }

  /// 保存设置到SharedPreferences
  Future<void> _saveSettings() async {
    try {
      await ReaderSettingsService.saveSettings(state);
      debugPrint('✅ 阅读器设置已保存');
    } catch (e) {
      debugPrint('❌ 保存阅读器设置失败: $e');
    }
  }

  /// 防抖保存：多次快速调用只执行最后一次
  void _debounceSaveSettings() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      _saveSettings();
    });
  }

  /// 🔧 清除所有缓存并通知重新分页（带防抖）
  void _invalidateAndRefresh() {
    // 清除所有分页缓存（已移除FastTextPaginator）
    debugPrint('🔄 [设置变化] 已清除缓存');

    // 🚀 防抖通知重新分页：500ms内多次调用只执行最后一次
    _repaginateTimer?.cancel();
    _repaginateTimer = Timer(const Duration(milliseconds: 500), () {
      debugPrint('🔄 [设置变化] 触发重新分页');
      onSettingsChanged?.call();
    });
  }

  /// 更新字体大小（带防抖）
  void updateFontSize(double fontSize) {
    state = state.copyWith(fontSize: fontSize.clamp(12.0, 36.0));
    _debounceSaveSettings(); // 使用防抖保存
    _invalidateAndRefresh(); // 🔧 立即清除缓存并通知重新分页
  }

  /// 更新行高（带防抖）
  void updateLineSpacing(double spacing) {
    state = state.copyWith(lineSpacing: spacing.clamp(1.0, 3.0));
    _debounceSaveSettings(); // 使用防抖保存
    _invalidateAndRefresh(); // 🔧 立即清除缓存并通知重新分页
  }

  /// 更新字间距（带防抖）
  void updateLetterSpacing(double letterSpacing) {
    state = state.copyWith(letterSpacing: letterSpacing.clamp(-1.0, 2.0));
    _debounceSaveSettings(); // 使用防抖保存
    _invalidateAndRefresh(); // 🔧 立即清除缓存并通知重新分页
  }

  /// 更新页边距
  void updatePadding(EdgeInsets padding) {
    state = state.copyWith(padding: padding);
    _saveSettings();
  }

  /// 更新首行缩进（带防抖）
  void updateFirstLineIndent(double indent) {
    state = state.copyWith(firstLineIndent: indent.clamp(0.0, 4.0));
    _debounceSaveSettings(); // 使用防抖保存
  }

  /// 更新水平页边距（带防抖）
  void updateHorizontalMargin(double margin) {
    final newMargin = margin.clamp(10.0, 40.0);
    state = state.copyWith(
      horizontalMargin: newMargin,
      padding: EdgeInsets.only(
        left: newMargin,
        right: newMargin,
        top: state.padding.top,
        bottom: state.padding.bottom,
      ),
    );
    _debounceSaveSettings(); // 使用防抖保存
  }

  /// 切换阅读主题
  void switchTheme(ReadingTheme theme) {
    state = state.copyWith(theme: theme);
    _saveSettings();
  }

  /// 切换翻页模式
  void switchPaginationMode(PaginationMode mode) {
    state = state.copyWith(paginationMode: mode);
    _saveSettings();
  }

  /// 切换点击翻页方案（已弃用：现在固定使用默认方案）
  @Deprecated('点击翻页方案已固定为默认的左中右模式')
  void switchTapTurningPattern(int patternIndex) {
    // 方法保留以保持兼容性，但不执行任何操作
    debugPrint('switchTapTurningPattern 已弃用：现在固定使用左中右模式');
  }

  /// 切换页面指示器显示
  void togglePageIndicator() {
    state = state.copyWith(showPageIndicator: !state.showPageIndicator);
    _saveSettings();
  }

  /// 切换文本选择功能
  void toggleTextSelection() {
    state = state.copyWith(enableTextSelection: !state.enableTextSelection);
    _saveSettings();
  }
}

/// 阅读器分页状态管理 - Riverpod StateNotifier
class ReaderPaginationNotifier extends StateNotifier<ReaderPaginationState> {
  ReaderPaginationNotifier() : super(const ReaderPaginationState()) {
    _initBackgroundLoader();
  }

  /// 初始化后台加载监听（已禁用 - 统一使用一次性全部加载）
  void _initBackgroundLoader() {
    // 禁用后台渐进式加载，所有内容一次性加载完成
    debugPrint('⚠️ 后台渐进式加载已禁用，使用一次性全部加载');
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// 初始化分页（优化版：支持持久化缓存和渐进式加载）
  ///
  /// [initialPageIndex] 初始页码，用于恢复上次阅读位置
  Future<void> initializePagination({
    required String text,
    required Size screenSize,
    required ReaderSettings settings,
    double? statusBarHeight,
    double? bottomSafeArea,
    double devicePixelRatio = 1.0,
    int initialPageIndex = 0,
  }) async {
    if (text.isEmpty) {
      state = state.copyWith(
        error: '文本内容为空',
        isLoading: false,
      );
      return;
    }

    // 检查文本长度
    final originalLength = text.length;
    final textLengthMB = originalLength / (1024 * 1024);
    debugPrint(
        '📊 文本长度: $originalLength 字符 (${textLengthMB.toStringAsFixed(2)} MB)');

    // 生成缓存键
    final realStatusBarHeight = statusBarHeight ?? 0.0;
    final actualAvailableHeight = screenSize.height - realStatusBarHeight;
    final contentHash = _generateContentHash(text);

    final cacheKey = PaginationCacheService.generateCacheKey(
      contentHash: contentHash,
      screenWidth: screenSize.width,
      screenHeight: actualAvailableHeight,
      fontSize: settings.fontSize,
      lineSpacing: settings.lineSpacing,
      letterSpacing: settings.letterSpacing,
      paddingLeft: settings.padding.left,
      paddingRight: settings.padding.right,
      paddingTop: settings.padding.top,
      paddingBottom: settings.padding.bottom,
      firstLineIndent: settings.firstLineIndent,
      devicePixelRatio: devicePixelRatio,
    );

    // 1. 检查内存缓存（🔧 修复：cacheKey变化时强制重新分页）
    final cacheKeyChanged =
        state.cacheKey != null && state.cacheKey != cacheKey;
    if (cacheKeyChanged) {
      debugPrint('🔄 [参数变化] cacheKey变化，清除所有缓存');
      // 清除持久化缓存
      await PaginationCacheService.clearAllCache();
    } else if (state.cacheKey == cacheKey && state.pages.isNotEmpty) {
      debugPrint('✅ 使用内存缓存，跳过分页');
      return;
    }

    // 2. 检查持久化缓存（如果参数没变化）
    state = state.copyWith(
      isLoading: true,
      error: null,
      loadingStage: cacheKeyChanged ? '参数变化，重新分页...' : '检查缓存...',
      screenSize: Size(screenSize.width, actualAvailableHeight), // 保存屏幕尺寸
    );

    // 如果cacheKey变化，跳过缓存检查，直接重新分页
    if (!cacheKeyChanged) {
      final cachedData =
          await PaginationCacheService.loadCache(cacheKey: cacheKey);
      if (cachedData != null && cachedData.pages.isNotEmpty) {
        debugPrint('✅ 使用持久化缓存: ${cachedData.pages.length}页');
        // 确保初始页码在有效范围内
        final safeInitialPage =
            initialPageIndex.clamp(0, cachedData.pages.length - 1);
        debugPrint('📖 恢复到页码: $safeInitialPage');
        state = state.copyWith(
          pages: cachedData.pages,
          currentPageIndex: safeInitialPage,
          isLoading: false,
          paginationSettings: settings,
          cachedText: text,
          cacheKey: cacheKey,
          loadingStage: '加载完成',
        );
        return;
      }
    }

    // 3. 无缓存，开始分页
    try {
      final actualScreenSize = Size(screenSize.width, actualAvailableHeight);

      debugPrint('📐 开始分页:');
      debugPrint('  - 文本: ${textLengthMB.toStringAsFixed(2)} MB');
      debugPrint(
          '  - 屏幕: ${actualScreenSize.width.toInt()}x${actualScreenSize.height.toInt()}');

      // 统一使用一次性全部加载（不分批）
      debugPrint('  - 策略: 一次性全部加载');
      await _paginateDirectAll(
        text: text,
        screenSize: actualScreenSize,
        settings: settings,
        devicePixelRatio: devicePixelRatio,
        cacheKey: cacheKey,
        initialPageIndex: initialPageIndex,
      );
    } catch (e, stackTrace) {
      state = state.copyWith(
        error: '分页失败: $e\n\n请尝试调整字体大小或重新打开',
        isLoading: false,
        isProgressiveLoading: false,
      );
      debugPrint('❌ 分页失败: $e');
      debugPrint('堆栈: $stackTrace');
    }
  }

  /// 一次性全部加载（使用渐进式分页：快速估算 + 后台精确计算）
  Future<void> _paginateDirectAll({
    required String text,
    required Size screenSize,
    required ReaderSettings settings,
    required double devicePixelRatio,
    required String cacheKey,
    int initialPageIndex = 0,
  }) async {
    state = state.copyWith(
      isLoading: true,
      loadingStage: '快速估算中...',
    );

    try {
      debugPrint('📄 开始渐进式分页: ${text.length} 字符');

      // 🔧 计算响应式padding（与渲染时保持一致）
      final responsivePadding = settings.getResponsivePadding(screenSize);
      debugPrint(
          '   📐 响应式padding: L${responsivePadding.left} R${responsivePadding.right} T${responsivePadding.top} B${responsivePadding.bottom}');

      // ✅ 使用增强分页器（渐进式加载：快速估算 + 后台精确计算）
      debugPrint('   🚀 使用增强分页器（渐进式加载）');
      final result = await EnhancedPaginator.paginateProgressive(
        text: text,
        screenSize: screenSize,
        fontSize: settings.fontSize,
        lineHeight: settings.lineSpacing,
        padding: responsivePadding, // 🔧 使用响应式padding
        letterSpacing: settings.letterSpacing,
        supportImages: true, // 🔑 启用图片支持
        quickSamplePages: 10, // 快速采样前10页
        onProgress: (currentPage, stage) {
          // 更新进度显示
          state = state.copyWith(
            loadingStage: '$stage ($currentPage 页)',
          );
        },
      );

      // 阶段1：使用快速估算结果，立即显示
      final sampledPages = result.sampledPages;
      final estimatedTotal = result.estimatedTotal;

      debugPrint('✅ 快速估算完成: 采样${sampledPages.length}页，估算总页数~$estimatedTotal');

      if (sampledPages.isEmpty) {
        throw Exception('快速估算结果为空');
      }

      // 立即更新状态，显示估算结果（用户可以立即开始阅读）
      // 🔧 保存使用响应式padding的settings，确保渲染时padding一致
      final paginationSettings = settings.copyWith(padding: responsivePadding);

      // 🔧 计算每页最大行数（与分页器保持一致）
      final lineHeightPx = settings.fontSize * settings.lineSpacing;
      final availableHeight =
          screenSize.height - responsivePadding.top - responsivePadding.bottom;
      final maxLinesPerPage = (availableHeight / lineHeightPx).floor();

      state = state.copyWith(
        pages: sampledPages,
        currentPageIndex: initialPageIndex.clamp(0, sampledPages.length - 1),
        isLoading: false,
        paginationSettings: paginationSettings, // 🔧 保存带响应式padding的settings
        cachedText: text,
        cacheKey: cacheKey,
        loadingStage: '加载完成，约 $estimatedTotal 页',
        estimatedTotal: estimatedTotal,
        isEstimated: true, // 标记为估算值
        screenSize: screenSize, // 🔧 保存屏幕尺寸
        maxLinesPerPage: maxLinesPerPage, // 🔧 保存每页最大行数
      );

      debugPrint('📖 用户可以开始阅读，后台继续精确计算...');

      // 阶段2：等待后台精确计算完成
      result.preciseCalculationFuture.then((preciseResult) {
        final pages = preciseResult.pages;
        final pageContents = preciseResult.pageContents;

        debugPrint('✅ 精确计算完成: 实际${pages.length}页');

        // 更新状态为精确值
        // 🔧 保持使用响应式padding的settings
        final paginationSettings =
            settings.copyWith(padding: responsivePadding);
        state = state.copyWith(
          pages: pages,
          currentPageIndex: state.currentPageIndex.clamp(0, pages.length - 1),
          loadingStage: '加载完成，共 ${pages.length} 页',
          pageContents: pageContents,
          paginationSettings: paginationSettings, // 🔧 确保精确计算后也使用相同padding
          estimatedTotal: null,
          isEstimated: false, // 标记为精确值
          // 🔧 保持 screenSize 和 maxLinesPerPage（不覆盖为 null）
        );

        // 保存到持久化缓存
        PaginationCacheService.saveCache(
          pages: pages,
          cacheKey: cacheKey,
        ).then((_) {
          debugPrint('💾 已缓存到本地磁盘');
        });
      }).catchError((e, stackTrace) {
        debugPrint('❌ 后台精确计算失败: $e');
        debugPrint('堆栈: $stackTrace');
        // 保持使用估算结果，不影响用户阅读
      });
    } catch (e, stackTrace) {
      debugPrint('❌ 分页失败: $e');
      debugPrint('堆栈: $stackTrace');
      rethrow;
    }
  }

  /// 生成内容哈希
  String _generateContentHash(String text) {
    final sample = text.length > 10000 ? text.substring(0, 10000) : text;
    final bytes = utf8.encode(sample);
    final digest = md5.convert(bytes);
    return digest.toString();
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

  /// 根据字符索引定位到对应的页面
  ///
  /// 参数:
  /// - charIndex: 目标字符在原文中的位置
  ///
  /// 此方法会找到包含该字符的页面并跳转过去
  /// 如果没有字符偏移量信息，则回退到使用进度百分比
  void goToCharIndex(int charIndex) {
    if (state.pages.isEmpty) return;

    // 如果没有字符偏移量信息，回退到进度百分比方法
    if (state.pageCharOffsets == null || state.pageCharOffsets!.isEmpty) {
      debugPrint('⚠️ 没有字符偏移量信息，使用进度百分比定位');
      // 估算进度百分比
      final textLength = state.cachedText?.length ?? 0;
      if (textLength > 0) {
        final progress = charIndex / textLength;
        goToProgress(progress);
      }
      return;
    }

    // 二分查找最接近的页面
    // 找到第一个起始位置大于charIndex的页面，然后取前一页
    int left = 0;
    int right = state.pageCharOffsets!.length - 1;
    int targetPage = 0;

    while (left <= right) {
      final mid = (left + right) ~/ 2;
      final offset = state.pageCharOffsets![mid];

      if (offset <= charIndex) {
        // 这一页可能包含目标字符
        targetPage = mid;
        left = mid + 1;
      } else {
        // 这一页在目标字符之后
        right = mid - 1;
      }
    }

    debugPrint('📍 根据字符索引 $charIndex 定位到第 ${targetPage + 1} 页');
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
  ReaderTtsNotifier()
      : _systemTts = SystemTts(), // 立即创建SystemTts单例实例（参考anx-reader的TtsHandler）
        super(const ReaderTtsState());

  final SystemTts _systemTts;
  bool _isInitialized = false;

  /// 初始化TTS
  Future<void> initialize({
    required Function getCurrentText,
    required Function getNextText,
    required Function getPrevText,
  }) async {
    try {
      debugPrint('🚀 开始初始化TTS...');

      // 只在第一次初始化时设置监听器
      if (!_isInitialized) {
        _systemTts.ttsStateNotifier.addListener(_onTtsStateChanged);
        _systemTts.setSentenceHighlightCallback(_onSentenceHighlightChanged);
      }

      // 初始化TTS引擎（每次都执行，确保引擎正确绑定）
      await _systemTts.init(getCurrentText, getNextText, getPrevText);

      // 标记为已初始化
      _isInitialized = true;

      debugPrint('✅ TTS初始化完成');
      debugPrint('   - 音量: ${_systemTts.volume}');
      debugPrint('   - 音调: ${_systemTts.pitch}');
      debugPrint('   - 语速: ${_systemTts.rate}');
    } catch (e, stackTrace) {
      debugPrint('❌ TTS初始化失败: $e');
      debugPrint('Stack trace: $stackTrace');
      // 标记为已初始化（虽然失败了），避免重复初始化尝试
      _isInitialized = true;
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
    try {
      debugPrint('🎵 ReaderTtsNotifier.play() 被调用');
      debugPrint('   传入文本: ${text != null ? "有 (${text.length}字符)" : "null"}');

      if (text != null && text.isNotEmpty) {
        // 直接播放传入的文本
        debugPrint('   ✅ 文本验证通过，准备调用 _systemTts.speak()');
        await _systemTts.speak(content: text);
        debugPrint('   ✅ _systemTts.speak() 返回成功');
      } else {
        debugPrint('   ❌ 文本验证失败: ${text == null ? "null" : "空字符串"}');
        throw Exception('请提供要朗读的文本内容');
      }

      debugPrint('✅ ReaderTtsNotifier.play() 完成');
    } catch (e, stack) {
      debugPrint('❌ ReaderTtsNotifier.play() 失败: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    try {
      await _systemTts.pause();
    } catch (e) {
      debugPrint('❌ TTS暂停失败: $e');
    }
  }

  /// 继续播放
  Future<void> resume() async {
    try {
      await _systemTts.resume();
    } catch (e) {
      debugPrint('❌ TTS继续播放失败: $e');
    }
  }

  /// 停止播放
  Future<void> stop() async {
    try {
      await _systemTts.stop();
    } catch (e) {
      debugPrint('❌ TTS停止失败: $e');
    }
  }

  /// 上一句
  Future<void> previous() async {
    try {
      await _systemTts.prev();
    } catch (e) {
      debugPrint('❌ TTS上一句失败: $e');
    }
  }

  /// 下一句
  Future<void> next() async {
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
