import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';
import '../widgets/advanced_text_reader.dart';
import '../widgets/flutter_advanced_reader_widget.dart';

/// 阅读引擎协调器
/// 管理WebView和高级引擎的切换，提供统一的阅读接口
class ReadingEngineCoordinator {
  static final ReadingEngineCoordinator _instance =
      ReadingEngineCoordinator._internal();
  factory ReadingEngineCoordinator() => _instance;
  ReadingEngineCoordinator._internal();

  /// 当前使用的引擎类型
  ReadingEngineType _currentEngine = ReadingEngineType.webView;

  /// 引擎选择策略
  EngineSelectionStrategy _strategy = EngineSelectionStrategy.automatic;

  /// 性能监控数据
  final Map<ReadingEngineType, PerformanceMetrics> _performanceMetrics = {};

  /// 用户偏好设置
  ReadingPreferences? _preferences;

  /// 初始化协调器
  Future<void> initialize() async {
    await _loadPreferences();
    _initializePerformanceMetrics();
    debugPrint('📖 ReadingEngineCoordinator 初始化完成');
  }

  /// 选择最适合的阅读引擎
  Future<ReadingEngineType> selectOptimalEngine(Book book) async {
    switch (_strategy) {
      case EngineSelectionStrategy.automatic:
        return await _selectAutomaticEngine(book);
      case EngineSelectionStrategy.alwaysWebView:
        return ReadingEngineType.webView;
      case EngineSelectionStrategy.alwaysAdvanced:
        return ReadingEngineType.advanced;
      case EngineSelectionStrategy.userPreference:
        return _preferences?.preferredEngine ?? ReadingEngineType.webView;
    }
  }

  /// 创建阅读器Widget
  Widget createReaderWidget({
    required Book book,
    required String content,
    required ReadingEngineType engineType,
    required TextStyle textStyle,
    EdgeInsets padding = const EdgeInsets.all(20.0),
    Color backgroundColor = const Color(0xFFFFFBF0),
    Function(int currentPage, int totalPages)? onPageChanged,
    Function(String selectedText, int startIndex, int endIndex)? onTextSelected,
    VoidCallback? onTap,
  }) {
    debugPrint('🔧 创建阅读器: ${engineType.name}');

    switch (engineType) {
      case ReadingEngineType.advanced:
        return AdvancedTextReader(
          text: content,
          textStyle: textStyle,
          backgroundColor: backgroundColor,
          padding: padding,
          onPageChanged: onPageChanged,
          onTextSelected: onTextSelected,
          onTap: onTap,
          enableTextSelection: true,
          enablePageIndicator: true,
        );

      case ReadingEngineType.webView:
        return FlutterAdvancedReaderWidget(
          text: content,
          textStyle: textStyle,
          backgroundColor: backgroundColor,
          onPageChanged: onPageChanged,
        );
    }
  }

  /// 切换阅读引擎
  Future<bool> switchEngine(ReadingEngineType newEngine) async {
    if (_currentEngine == newEngine) return true;

    try {
      debugPrint('🔄 切换阅读引擎: ${_currentEngine.name} -> ${newEngine.name}');

      // 记录切换时间
      final switchStartTime = DateTime.now();

      // 执行引擎切换
      _currentEngine = newEngine;

      // 保存用户偏好
      await _saveEnginePreference(newEngine);

      // 记录性能指标
      final switchDuration = DateTime.now().difference(switchStartTime);
      _updatePerformanceMetric(
        newEngine,
        'switchDuration',
        switchDuration.inMilliseconds.toDouble(),
      );

      debugPrint('✅ 引擎切换完成，耗时: ${switchDuration.inMilliseconds}ms');
      return true;
    } catch (e) {
      debugPrint('❌ 引擎切换失败: $e');
      return false;
    }
  }

  /// 获取引擎性能对比报告
  Map<String, dynamic> getPerformanceReport() {
    final report = <String, dynamic>{};

    for (final entry in _performanceMetrics.entries) {
      final engineType = entry.key;
      final metrics = entry.value;

      report[engineType.name] = {
        'averageLoadTime': metrics.averageLoadTime,
        'memoryUsage': metrics.memoryUsage,
        'renderingPerformance': metrics.renderingPerformance,
        'userSatisfaction': metrics.userSatisfaction,
        'errorRate': metrics.errorRate,
        'switchCount': metrics.switchCount,
      };
    }

    return report;
  }

  /// 自动选择引擎
  Future<ReadingEngineType> _selectAutomaticEngine(Book book) async {
    // 基于多个因素选择引擎
    final factors = <String, double>{};

    // 1. 文件格式权重
    final formatWeight = _getFormatWeight(book.format);
    factors['format'] = formatWeight;

    // 2. 文件大小权重
    final sizeWeight = _getSizeWeight(book);
    factors['size'] = sizeWeight;

    // 3. 历史性能权重
    final performanceWeight = _getPerformanceWeight();
    factors['performance'] = performanceWeight;

    // 4. 用户偏好权重
    final preferenceWeight = _getPreferenceWeight();
    factors['preference'] = preferenceWeight;

    // 计算综合分数
    double webViewScore = 0.0;
    double advancedScore = 0.0;

    factors.forEach((factor, weight) {
      switch (factor) {
        case 'format':
          if (book.format.toLowerCase() == 'txt') {
            advancedScore += weight * 0.8;
            webViewScore += weight * 0.2;
          } else {
            webViewScore += weight * 0.8;
            advancedScore += weight * 0.2;
          }
          break;
        case 'size':
          // 大文件倾向于使用高级引擎
          advancedScore += weight * sizeWeight;
          webViewScore += weight * (1.0 - sizeWeight);
          break;
        case 'performance':
          advancedScore += weight * performanceWeight;
          webViewScore += weight * (1.0 - performanceWeight);
          break;
        case 'preference':
          if (_preferences?.preferredEngine == ReadingEngineType.advanced) {
            advancedScore += weight;
          } else {
            webViewScore += weight;
          }
          break;
      }
    });

    final selectedEngine = advancedScore > webViewScore
        ? ReadingEngineType.advanced
        : ReadingEngineType.webView;

    debugPrint(
      '🤖 自动选择引擎: ${selectedEngine.name} (Advanced: $advancedScore, WebView: $webViewScore)',
    );
    return selectedEngine;
  }

  /// 获取格式权重
  double _getFormatWeight(String format) {
    switch (format.toLowerCase()) {
      case 'txt':
        return 0.8; // TXT适合高级引擎
      case 'epub':
        return 0.3; // EPUB适合WebView
      case 'pdf':
        return 0.2; // PDF适合WebView
      default:
        return 0.5;
    }
  }

  /// 获取大小权重
  double _getSizeWeight(Book book) {
    // 假设大于5MB的文件适合高级引擎
    const largeSizeThreshold = 5 * 1024 * 1024; // 5MB

    try {
      // 这里需要实际的文件大小，暂时使用模拟值
      final estimatedSize = book.title.length * 1000; // 简单估算
      return (estimatedSize > largeSizeThreshold) ? 0.7 : 0.3;
    } catch (e) {
      return 0.5;
    }
  }

  /// 获取性能权重
  double _getPerformanceWeight() {
    final advancedMetrics = _performanceMetrics[ReadingEngineType.advanced];
    final webViewMetrics = _performanceMetrics[ReadingEngineType.webView];

    if (advancedMetrics == null || webViewMetrics == null) {
      return 0.5; // 没有数据时返回中性值
    }

    // 基于平均加载时间计算权重
    final advancedLoad = advancedMetrics.averageLoadTime;
    final webViewLoad = webViewMetrics.averageLoadTime;

    if (advancedLoad + webViewLoad == 0) return 0.5;

    return webViewLoad / (advancedLoad + webViewLoad);
  }

  /// 获取偏好权重
  double _getPreferenceWeight() {
    return _preferences?.enginePreferenceStrength ?? 0.5;
  }

  /// 加载用户偏好设置
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final engineIndex = prefs.getInt('preferred_reading_engine') ?? 0;
      final strategyIndex = prefs.getInt('engine_selection_strategy') ?? 0;
      final preferenceStrength =
          prefs.getDouble('engine_preference_strength') ?? 0.5;

      _preferences = ReadingPreferences(
        preferredEngine: ReadingEngineType.values[engineIndex],
        enginePreferenceStrength: preferenceStrength,
      );

      _strategy = EngineSelectionStrategy.values[strategyIndex];

      debugPrint('📖 用户偏好加载完成: ${_preferences!.preferredEngine.name}');
    } catch (e) {
      debugPrint('❌ 加载用户偏好失败: $e');
      _preferences = ReadingPreferences.defaultPreferences();
    }
  }

  /// 保存引擎偏好
  Future<void> _saveEnginePreference(ReadingEngineType engine) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('preferred_reading_engine', engine.index);

      if (_preferences != null) {
        _preferences = _preferences!.copyWith(preferredEngine: engine);
      }
    } catch (e) {
      debugPrint('❌ 保存引擎偏好失败: $e');
    }
  }

  /// 初始化性能指标
  void _initializePerformanceMetrics() {
    for (final engineType in ReadingEngineType.values) {
      _performanceMetrics[engineType] = PerformanceMetrics();
    }
  }

  /// 更新性能指标
  void _updatePerformanceMetric(
    ReadingEngineType engine,
    String metric,
    double value,
  ) {
    final metrics = _performanceMetrics[engine];
    if (metrics != null) {
      metrics.updateMetric(metric, value);
    }
  }

  /// 记录引擎使用情况
  void recordEngineUsage(ReadingEngineType engine, Duration usageTime) {
    _updatePerformanceMetric(
      engine,
      'usageTime',
      usageTime.inMilliseconds.toDouble(),
    );
  }

  /// 记录引擎错误
  void recordEngineError(ReadingEngineType engine, String errorType) {
    _updatePerformanceMetric(engine, 'errorCount', 1.0);
    debugPrint('⚠️ 引擎错误记录: ${engine.name} - $errorType');
  }

  /// 获取当前引擎
  ReadingEngineType get currentEngine => _currentEngine;

  /// 获取选择策略
  EngineSelectionStrategy get selectionStrategy => _strategy;

  /// 设置选择策略
  Future<void> setSelectionStrategy(EngineSelectionStrategy strategy) async {
    _strategy = strategy;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('engine_selection_strategy', strategy.index);
    } catch (e) {
      debugPrint('❌ 保存选择策略失败: $e');
    }
  }
}

/// 阅读引擎类型
enum ReadingEngineType {
  webView, // WebView引擎（基于anx-reader）
  advanced, // 高级引擎（自定义实现）
}

/// 引擎选择策略
enum EngineSelectionStrategy {
  automatic, // 自动选择
  alwaysWebView, // 总是使用WebView
  alwaysAdvanced, // 总是使用高级
  userPreference, // 根据用户偏好
}

/// 用户阅读偏好
class ReadingPreferences {
  final ReadingEngineType preferredEngine;
  final double enginePreferenceStrength; // 0.0-1.0，偏好强度

  const ReadingPreferences({
    required this.preferredEngine,
    required this.enginePreferenceStrength,
  });

  factory ReadingPreferences.defaultPreferences() {
    return const ReadingPreferences(
      preferredEngine: ReadingEngineType.webView,
      enginePreferenceStrength: 0.5,
    );
  }

  ReadingPreferences copyWith({
    ReadingEngineType? preferredEngine,
    double? enginePreferenceStrength,
  }) {
    return ReadingPreferences(
      preferredEngine: preferredEngine ?? this.preferredEngine,
      enginePreferenceStrength:
          enginePreferenceStrength ?? this.enginePreferenceStrength,
    );
  }
}

/// 性能指标
class PerformanceMetrics {
  final Map<String, List<double>> _metrics = {};

  double get averageLoadTime => _calculateAverage('loadTime');
  double get memoryUsage => _calculateAverage('memoryUsage');
  double get renderingPerformance => _calculateAverage('renderingPerformance');
  double get userSatisfaction => _calculateAverage('userSatisfaction');
  double get errorRate => _calculateAverage('errorCount');
  int get switchCount => _metrics['switchCount']?.length ?? 0;

  void updateMetric(String metricName, double value) {
    _metrics.putIfAbsent(metricName, () => []);
    _metrics[metricName]!.add(value);

    // 保持最近100个数据点
    if (_metrics[metricName]!.length > 100) {
      _metrics[metricName]!.removeAt(0);
    }
  }

  double _calculateAverage(String metricName) {
    final values = _metrics[metricName];
    if (values == null || values.isEmpty) return 0.0;

    return values.reduce((a, b) => a + b) / values.length;
  }

  Map<String, dynamic> toMap() {
    return {
      'averageLoadTime': averageLoadTime,
      'memoryUsage': memoryUsage,
      'renderingPerformance': renderingPerformance,
      'userSatisfaction': userSatisfaction,
      'errorRate': errorRate,
      'switchCount': switchCount,
    };
  }
}
