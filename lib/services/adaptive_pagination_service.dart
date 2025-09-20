import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// 自适应分页服务
/// 
/// 根据设备特性和显示参数提供精确的分页估算
/// 
/// 核心功能：
/// - [calculateOptimalPages] 计算最优页数
/// - [getDeviceDisplayInfo] 获取设备显示信息
/// - [estimateReadingParameters] 估算阅读参数
/// - [adaptToScreenSize] 屏幕尺寸适配
class AdaptivePaginationService {
  
  /// 计算最优页数
  /// 
  /// 基于设备特性、文本内容和用户偏好计算精确页数
  /// 
  /// [content] 文本内容
  /// [textStyle] 文本样式
  /// [constraints] 布局约束
  /// [deviceInfo] 设备信息（可选）
  /// Returns: 优化后的总页数
  /// 
  /// 使用示例：
  /// ```dart
  /// final service = AdaptivePaginationService();
  /// final pages = await service.calculateOptimalPages(
  ///   content: bookContent,
  ///   textStyle: TextStyle(fontSize: 16),
  ///   constraints: BoxConstraints(maxWidth: 350, maxHeight: 600),
  /// );
  /// ```
  Future<int> calculateOptimalPages(
    String content, {
    required TextStyle textStyle,
    required BoxConstraints constraints,
    DeviceDisplayInfo? deviceInfo,
    ReadingPreferences? preferences,
  }) async {
    // 1. 获取设备显示信息
    deviceInfo ??= await getDeviceDisplayInfo();
    preferences ??= ReadingPreferences();
    
    // 2. 计算有效显示区域
    final effectiveConstraints = _calculateEffectiveConstraints(
      constraints,
      deviceInfo,
      preferences,
    );
    
    // 3. 文本测量和分析
    final textMetrics = await _analyzeTextMetrics(
      content,
      textStyle,
      effectiveConstraints,
    );
    
    // 4. 智能分页算法
    final pageCount = _calculateSmartPageCount(
      content,
      textMetrics,
      deviceInfo,
      preferences,
    );
    
    debugPrint('自适应分页计算完成:');
    debugPrint('设备类型: ${deviceInfo.deviceType}');
    debugPrint('屏幕尺寸: ${deviceInfo.screenSize.width}x${deviceInfo.screenSize.height}');
    debugPrint('字体大小: ${textStyle.fontSize}');
    debugPrint('计算页数: $pageCount');
    
    return pageCount.clamp(1, 9999);
  }
  
  /// 获取设备显示信息
  Future<DeviceDisplayInfo> getDeviceDisplayInfo() async {
    // 获取屏幕信息
    final window = WidgetsBinding.instance.platformDispatcher.views.first;
    final screenSize = window.physicalSize / window.devicePixelRatio;
    final pixelRatio = window.devicePixelRatio;
    
    // 确定设备类型
    final deviceType = _determineDeviceType(screenSize);
    
    // 获取文本缩放比例（简化实现）
    final textScaleFactor = 1.0; // 默认缩放比例，实际应用中可以从MediaQuery获取
    
    // 检测平台
    final platform = defaultTargetPlatform;
    
    return DeviceDisplayInfo(
      screenSize: screenSize,
      pixelRatio: pixelRatio,
      deviceType: deviceType,
      textScaleFactor: textScaleFactor,
      platform: platform,
    );
  }
  
  /// 估算阅读参数
  ReadingParameters estimateReadingParameters(
    DeviceDisplayInfo deviceInfo,
    TextStyle textStyle,
  ) {
    // 基于设备类型调整参数
    late double optimalLineHeight;
    late int optimalCharsPerLine;
    late int optimalLinesPerPage;
    
    switch (deviceInfo.deviceType) {
      case DeviceType.phone:
        optimalLineHeight = (textStyle.fontSize ?? 16) * 1.4;
        optimalCharsPerLine = 25;
        optimalLinesPerPage = 25;
        break;
      case DeviceType.largPhone:
        optimalLineHeight = (textStyle.fontSize ?? 16) * 1.45;
        optimalCharsPerLine = 30;
        optimalLinesPerPage = 28;
        break;
      case DeviceType.tablet:
        optimalLineHeight = (textStyle.fontSize ?? 16) * 1.5;
        optimalCharsPerLine = 40;
        optimalLinesPerPage = 35;
        break;
      case DeviceType.desktop:
        optimalLineHeight = (textStyle.fontSize ?? 16) * 1.6;
        optimalCharsPerLine = 60;
        optimalLinesPerPage = 40;
        break;
    }
    
    // 根据文本缩放调整
    optimalLineHeight *= deviceInfo.textScaleFactor;
    optimalCharsPerLine = (optimalCharsPerLine / deviceInfo.textScaleFactor).round();
    
    return ReadingParameters(
      lineHeight: optimalLineHeight,
      charsPerLine: optimalCharsPerLine,
      linesPerPage: optimalLinesPerPage,
    );
  }
  
  /// 屏幕尺寸适配
  BoxConstraints adaptToScreenSize(
    BoxConstraints original,
    DeviceDisplayInfo deviceInfo,
    ReadingPreferences preferences,
  ) {
    double maxWidth = original.maxWidth;
    double maxHeight = original.maxHeight;
    
    // 根据设备类型调整
    switch (deviceInfo.deviceType) {
      case DeviceType.phone:
        // 手机：保持较小的阅读区域
        maxWidth *= 0.9;
        maxHeight *= 0.85;
        break;
      case DeviceType.largPhone:
        // 大屏手机：适中的阅读区域
        maxWidth *= 0.85;
        maxHeight *= 0.8;
        break;
      case DeviceType.tablet:
        // 平板：较大的阅读区域，但考虑舒适度
        maxWidth *= 0.8;
        maxHeight *= 0.75;
        break;
      case DeviceType.desktop:
        // 桌面：限制最大宽度以提高可读性
        maxWidth = maxWidth.clamp(0, 800);
        maxHeight *= 0.9;
        break;
    }
    
    // 应用用户偏好
    maxWidth *= preferences.textAreaWidthFactor;
    maxHeight *= preferences.textAreaHeightFactor;
    
    return BoxConstraints(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      minWidth: original.minWidth,
      minHeight: original.minHeight,
    );
  }
  
  // 私有方法
  
  /// 确定设备类型
  DeviceType _determineDeviceType(Size screenSize) {
    final diagonal = _calculateDiagonal(screenSize);
    
    if (diagonal < 5.0) {
      return DeviceType.phone;
    } else if (diagonal < 7.0) {
      return DeviceType.largPhone;
    } else if (diagonal < 12.0) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }
  
  /// 计算屏幕对角线长度（英寸）
  double _calculateDiagonal(Size screenSize) {
    // 假设DPI为160（Android标准）
    const standardDpi = 160.0;
    final widthInches = screenSize.width / standardDpi;
    final heightInches = screenSize.height / standardDpi;
    return sqrt(widthInches * widthInches + heightInches * heightInches);
  }
  
  /// 计算有效约束
  BoxConstraints _calculateEffectiveConstraints(
    BoxConstraints original,
    DeviceDisplayInfo deviceInfo,
    ReadingPreferences preferences,
  ) {
    // 预留UI元素空间
    const topBarHeight = 56.0; // AppBar高度
    const bottomBarHeight = 80.0; // 控制栏高度
    const padding = 32.0; // 边距
    
    final effectiveHeight = original.maxHeight - 
        topBarHeight - bottomBarHeight - padding;
    final effectiveWidth = original.maxWidth - padding;
    
    return BoxConstraints(
      maxWidth: effectiveWidth,
      maxHeight: effectiveHeight,
      minWidth: 0,
      minHeight: 0,
    );
  }
  
  /// 分析文本指标
  Future<TextMetrics> _analyzeTextMetrics(
    String content,
    TextStyle textStyle,
    BoxConstraints constraints,
  ) async {
    // 创建文本画笔进行测量
    final textPainter = TextPainter(
      text: TextSpan(text: '测', style: textStyle),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    final charWidth = textPainter.width;
    final charHeight = textPainter.height;
    
    // 计算行高（包括行间距）
    final lineHeight = charHeight * (textStyle.height ?? 1.4);
    
    // 计算每行字符数
    final charsPerLine = (constraints.maxWidth / charWidth).floor();
    
    // 计算每页行数
    final linesPerPage = (constraints.maxHeight / lineHeight).floor();
    
    // 分析内容特征
    final totalChars = content.length;
    final lineCount = content.split('\n').length;
    final avgCharsPerLine = totalChars / lineCount;
    
    textPainter.dispose();
    
    return TextMetrics(
      charWidth: charWidth,
      charHeight: charHeight,
      lineHeight: lineHeight,
      charsPerLine: charsPerLine,
      linesPerPage: linesPerPage,
      totalChars: totalChars,
      avgCharsPerLine: avgCharsPerLine,
    );
  }
  
  /// 智能分页计算
  int _calculateSmartPageCount(
    String content,
    TextMetrics metrics,
    DeviceDisplayInfo deviceInfo,
    ReadingPreferences preferences,
  ) {
    // 基础计算
    final charsPerPage = metrics.charsPerLine * metrics.linesPerPage;
    int basePageCount = (metrics.totalChars / charsPerPage).ceil();
    
    // 设备类型调整系数
    double deviceFactor = 1.0;
    switch (deviceInfo.deviceType) {
      case DeviceType.phone:
        deviceFactor = 1.2; // 手机屏幕小，页数稍多
        break;
      case DeviceType.largPhone:
        deviceFactor = 1.1;
        break;
      case DeviceType.tablet:
        deviceFactor = 0.9; // 平板屏幕大，页数稍少
        break;
      case DeviceType.desktop:
        deviceFactor = 0.8;
        break;
    }
    
    // 内容特征调整
    double contentFactor = 1.0;
    
    // 根据平均行长度调整
    if (metrics.avgCharsPerLine < 20) {
      contentFactor *= 0.8; // 短行内容，如诗歌
    } else if (metrics.avgCharsPerLine > 60) {
      contentFactor *= 1.1; // 长行内容，需要更多页面
    }
    
    // 用户偏好调整
    final userFactor = preferences.pageCountAdjustment;
    
    // 最终计算
    final adjustedPageCount = (basePageCount * deviceFactor * contentFactor * userFactor).round();
    
    return adjustedPageCount;
  }
}

/// 设备显示信息
class DeviceDisplayInfo {
  final Size screenSize;
  final double pixelRatio;
  final DeviceType deviceType;
  final double textScaleFactor;
  final TargetPlatform platform;
  
  DeviceDisplayInfo({
    required this.screenSize,
    required this.pixelRatio,
    required this.deviceType,
    required this.textScaleFactor,
    required this.platform,
  });
}

/// 设备类型枚举
enum DeviceType {
  phone,      // 手机
  largPhone, // 大屏手机
  tablet,     // 平板
  desktop,    // 桌面
}

/// 阅读参数
class ReadingParameters {
  final double lineHeight;
  final int charsPerLine;
  final int linesPerPage;
  
  ReadingParameters({
    required this.lineHeight,
    required this.charsPerLine,
    required this.linesPerPage,
  });
}

/// 文本指标
class TextMetrics {
  final double charWidth;
  final double charHeight;
  final double lineHeight;
  final int charsPerLine;
  final int linesPerPage;
  final int totalChars;
  final double avgCharsPerLine;
  
  TextMetrics({
    required this.charWidth,
    required this.charHeight,
    required this.lineHeight,
    required this.charsPerLine,
    required this.linesPerPage,
    required this.totalChars,
    required this.avgCharsPerLine,
  });
}

/// 阅读偏好设置
class ReadingPreferences {
  /// 文本区域宽度因子
  final double textAreaWidthFactor;
  
  /// 文本区域高度因子
  final double textAreaHeightFactor;
  
  /// 页数调整因子
  final double pageCountAdjustment;
  
  /// 是否偏好较大字体
  final bool preferLargerFont;
  
  /// 是否偏好较大行距
  final bool preferLargerLineSpacing;
  
  ReadingPreferences({
    this.textAreaWidthFactor = 1.0,
    this.textAreaHeightFactor = 1.0,
    this.pageCountAdjustment = 1.0,
    this.preferLargerFont = false,
    this.preferLargerLineSpacing = false,
  });
}
