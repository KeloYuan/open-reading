import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// iOS布局适配工具类
///
/// 解决iOS平台特有的布局间距问题，提供智能间距管理
/// 和平台特定的布局适配方案
///
/// 核心功能：
/// - [getAdaptiveSpacing] 获取平台适配的间距
/// - [buildAdaptiveColumn] 构建适配的列布局
/// - [wrapWithPlatformPadding] 平台特定内边距包装
/// - [getListViewPadding] ListView专用间距适配
class PlatformLayoutHelper {
  // iOS平台默认间距问题的补偿值
  static const double _iosDefaultSpacing = 12.0; // 调整iOS补偿值，移除内置margin后

  // 调试模式，用于可视化间距调整
  static bool debugMode = false;

  /// 获取平台适配的垂直间距
  ///
  /// [baseSpacing] 基础间距值
  /// [compensateIOS] 是否对iOS进行间距补偿
  /// Returns: 适配后的间距值
  static double getAdaptiveSpacing(
    double baseSpacing, {
    bool compensateIOS = true,
  }) {
    if (!compensateIOS) return baseSpacing;

    if (kIsWeb) return baseSpacing;

    // iOS平台间距补偿
    if (Platform.isIOS) {
      final compensatedSpacing = baseSpacing - _iosDefaultSpacing;
      return compensatedSpacing < 0 ? 0 : compensatedSpacing;
    }

    return baseSpacing;
  }

  /// 构建平台适配的Column布局
  ///
  /// [children] 子组件列表
  /// [spacing] 组件间基础间距
  /// [crossAxisAlignment] 横轴对齐方式
  /// [mainAxisAlignment] 主轴对齐方式
  /// Returns: 适配的Column组件
  static Widget buildAdaptiveColumn({
    required List<Widget> children,
    double spacing = 16.0,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();

    final adaptiveSpacing = getAdaptiveSpacing(spacing);
    final spacedChildren = <Widget>[];

    for (int i = 0; i < children.length; i++) {
      spacedChildren.add(children[i]);

      // 为非最后一个元素添加间距
      if (i < children.length - 1) {
        spacedChildren.add(_buildSpacingWidget(adaptiveSpacing));
      }
    }

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      children: spacedChildren,
    );
  }

  /// 构建间距组件（调试模式下可视化）
  static Widget _buildSpacingWidget(double spacing) {
    if (debugMode) {
      return Container(
        height: spacing,
        color: Colors.red.withOpacity(0.3),
        child: Center(
          child: Text(
            '${spacing.toInt()}px',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return SizedBox(height: spacing);
  }

  /// 使用平台特定内边距包装组件
  ///
  /// [child] 要包装的子组件
  /// [padding] 基础内边距
  /// Returns: 带有适配内边距的组件
  static Widget wrapWithPlatformPadding({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16.0),
  }) {
    if (kIsWeb) return Padding(padding: padding, child: child);

    if (Platform.isIOS) {
      // iOS特定的内边距调整
      final adaptedPadding = EdgeInsets.only(
        left: padding.left,
        right: padding.right,
        top: getAdaptiveSpacing(padding.top),
        bottom: getAdaptiveSpacing(padding.bottom),
      );
      return Padding(padding: adaptedPadding, child: child);
    }

    return Padding(padding: padding, child: child);
  }

  /// 获取ListView专用的平台适配内边距
  ///
  /// [basePadding] 基础内边距
  /// Returns: 适配后的EdgeInsets
  static EdgeInsets getListViewPadding(EdgeInsets basePadding) {
    if (kIsWeb) return basePadding;

    if (Platform.isIOS) {
      return EdgeInsets.only(
        left: basePadding.left,
        right: basePadding.right,
        top: getAdaptiveSpacing(basePadding.top),
        bottom: getAdaptiveSpacing(basePadding.bottom),
      );
    }

    return basePadding;
  }

  /// 获取iOS大屏设备的额外间距补偿
  ///
  /// [context] BuildContext用于获取屏幕信息
  /// Returns: 额外的间距补偿值
  static double getIOSLargeScreenCompensation(BuildContext context) {
    if (!Platform.isIOS) return 0.0;

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // iPhone Pro Max等大屏设备额外补偿
    if (screenHeight > 800 || screenWidth > 400) {
      return 8.0; // 调整大屏设备补偿，移除内置margin后
    }

    return 0.0;
  }

  /// 创建平台适配的分隔器
  ///
  /// [height] 分隔器高度
  /// [color] 分隔器颜色
  /// Returns: 适配的分隔器组件
  static Widget buildAdaptiveDivider({double height = 1.0, Color? color}) {
    final adaptiveHeight = getAdaptiveSpacing(height);

    return Container(
      height: adaptiveHeight,
      color: color ?? Colors.grey.withOpacity(0.2),
    );
  }

  /// 开启调试模式
  /// 用于可视化间距调整效果
  static void enableDebugMode() {
    debugMode = true;
    debugPrint('PlatformLayoutHelper: Debug mode enabled');
  }

  /// 关闭调试模式
  static void disableDebugMode() {
    debugMode = false;
    debugPrint('PlatformLayoutHelper: Debug mode disabled');
  }

  /// 获取当前平台的布局信息（调试用）
  static Map<String, dynamic> getPlatformLayoutInfo(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return {
      'platform': kIsWeb ? 'Web' : Platform.operatingSystem,
      'screenSize': '${mediaQuery.size.width}x${mediaQuery.size.height}',
      'devicePixelRatio': mediaQuery.devicePixelRatio,
      'padding': mediaQuery.padding.toString(),
      'viewInsets': mediaQuery.viewInsets.toString(),
      'iosCompensation': Platform.isIOS ? _iosDefaultSpacing : 0,
      'largeScreenCompensation': getIOSLargeScreenCompensation(context),
    };
  }
}

/// iOS布局适配扩展
/// 为常用Widget提供便捷的适配方法
extension PlatformLayoutExtension on Widget {
  /// 为Widget添加平台适配的垂直间距
  Widget withAdaptiveSpacing(double spacing) {
    return Column(
      children: [
        this,
        SizedBox(height: PlatformLayoutHelper.getAdaptiveSpacing(spacing)),
      ],
    );
  }

  /// 为Widget添加平台适配的内边距
  Widget withAdaptivePadding(EdgeInsets padding) {
    return PlatformLayoutHelper.wrapWithPlatformPadding(
      padding: padding,
      child: this,
    );
  }
}
