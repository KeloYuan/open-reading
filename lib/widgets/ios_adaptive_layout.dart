import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../utils/platform_layout_helper.dart';

/// iOS自适应布局组件
///
/// 专门解决iOS平台的布局间距问题，提供智能的
/// 间距管理和平台特定的布局优化
///
/// 核心功能：
/// - 自动检测iOS平台并应用间距补偿
/// - 支持调试模式可视化间距调整
/// - 提供多种布局模式适配
/// - 智能处理大屏设备的额外间距需求
class IOSAdaptiveLayout extends StatelessWidget {
  /// 子组件列表
  final List<Widget> children;

  /// 组件间基础间距
  final double spacing;

  /// 横轴对齐方式
  final CrossAxisAlignment crossAxisAlignment;

  /// 主轴对齐方式
  final MainAxisAlignment mainAxisAlignment;

  /// 主轴大小
  final MainAxisSize mainAxisSize;

  /// 是否启用iOS间距补偿
  final bool enableIOSCompensation;

  /// 额外的间距调整（用于特殊情况）
  final double extraSpacingAdjustment;

  /// 是否显示调试信息
  final bool showDebugInfo;

  /// 自定义间距计算函数
  final double Function(double baseSpacing, int index)? customSpacingCalculator;

  const IOSAdaptiveLayout({
    super.key,
    required this.children,
    this.spacing = 16.0,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.enableIOSCompensation = true,
    this.extraSpacingAdjustment = 0.0,
    this.showDebugInfo = false,
    this.customSpacingCalculator,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    // 获取平台信息
    final isIOS = !kIsWeb && Platform.isIOS;
    final shouldCompensate = isIOS && enableIOSCompensation;

    // 获取额外的大屏补偿
    final largeScreenCompensation = isIOS
        ? PlatformLayoutHelper.getIOSLargeScreenCompensation(context)
        : 0.0;

    // 构建适配的子组件列表
    final adaptedChildren = _buildAdaptedChildren(
      context,
      shouldCompensate,
      largeScreenCompensation,
    );

    final column = Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: adaptedChildren,
    );

    // 如果启用调试信息，添加调试覆盖层
    if (showDebugInfo) {
      return Stack(
        children: [
          column,
          _buildDebugOverlay(
            context,
            shouldCompensate,
            largeScreenCompensation,
          ),
        ],
      );
    }

    return column;
  }

  /// 构建适配的子组件列表
  List<Widget> _buildAdaptedChildren(
    BuildContext context,
    bool shouldCompensate,
    double largeScreenCompensation,
  ) {
    final adaptedChildren = <Widget>[];

    for (int i = 0; i < children.length; i++) {
      // 添加子组件
      adaptedChildren.add(children[i]);

      // 为非最后一个元素添加间距
      if (i < children.length - 1) {
        double currentSpacing = spacing;

        // 应用自定义间距计算
        if (customSpacingCalculator != null) {
          currentSpacing = customSpacingCalculator!(currentSpacing, i);
        }

        // 应用iOS补偿
        if (shouldCompensate) {
          currentSpacing = PlatformLayoutHelper.getAdaptiveSpacing(
            currentSpacing,
          );
        }

        // 应用额外调整
        currentSpacing += extraSpacingAdjustment - largeScreenCompensation;

        // 确保间距不为负数
        currentSpacing = currentSpacing < 0 ? 0 : currentSpacing;

        adaptedChildren.add(_buildSpacingWidget(currentSpacing, i));
      }
    }

    return adaptedChildren;
  }

  /// 构建间距组件
  Widget _buildSpacingWidget(double spacing, int index) {
    if (PlatformLayoutHelper.debugMode || showDebugInfo) {
      return Container(
        height: spacing,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: _getDebugColor(index).withValues(alpha: 0.3),
          border: Border.all(color: _getDebugColor(index), width: 1),
        ),
        child: Center(
          child: Text(
            'Spacing $index: ${spacing.toStringAsFixed(1)}px',
            style: TextStyle(
              fontSize: 9,
              color: _getDebugColor(index),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return SizedBox(height: spacing);
  }

  /// 获取调试颜色
  Color _getDebugColor(int index) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }

  /// 构建调试覆盖层
  Widget _buildDebugOverlay(
    BuildContext context,
    bool shouldCompensate,
    double largeScreenCompensation,
  ) {
    final platformInfo = PlatformLayoutHelper.getPlatformLayoutInfo(context);

    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'iOS Layout Debug',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Platform: ${platformInfo['platform']}',
              style: const TextStyle(color: Colors.white, fontSize: 8),
            ),
            Text(
              'Compensation: ${shouldCompensate ? 'ON' : 'OFF'}',
              style: TextStyle(
                color: shouldCompensate ? Colors.green : Colors.red,
                fontSize: 8,
              ),
            ),
            Text(
              'Large Screen: ${largeScreenCompensation}px',
              style: const TextStyle(color: Colors.white, fontSize: 8),
            ),
            Text(
              'Base Spacing: ${spacing}px',
              style: const TextStyle(color: Colors.white, fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }
}

/// iOS适配的ListView组件
///
/// 专门为ListView提供iOS平台的间距适配
class IOSAdaptiveListView extends StatelessWidget {
  /// ListView的子组件
  final List<Widget> children;

  /// 滚动方向
  final Axis scrollDirection;

  /// 是否反向滚动
  final bool reverse;

  /// 滚动控制器
  final ScrollController? controller;

  /// 滚动物理特性
  final ScrollPhysics? physics;

  /// 是否收缩包装
  final bool shrinkWrap;

  /// ListView的内边距
  final EdgeInsetsGeometry? padding;

  /// 组件间分隔器构建器
  final Widget Function(BuildContext, int)? separatorBuilder;

  /// 是否启用iOS补偿
  final bool enableIOSCompensation;

  const IOSAdaptiveListView({
    super.key,
    required this.children,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.separatorBuilder,
    this.enableIOSCompensation = true,
  });

  @override
  Widget build(BuildContext context) {
    EdgeInsetsGeometry? adaptedPadding = padding;

    // 应用iOS间距适配
    if (enableIOSCompensation && padding != null) {
      if (padding is EdgeInsets) {
        adaptedPadding = PlatformLayoutHelper.getListViewPadding(
          padding as EdgeInsets,
        );
      }
    }

    if (separatorBuilder != null) {
      return ListView.separated(
        scrollDirection: scrollDirection,
        reverse: reverse,
        controller: controller,
        physics: physics,
        shrinkWrap: shrinkWrap,
        padding: adaptedPadding,
        itemCount: children.length,
        itemBuilder: (context, index) => children[index],
        separatorBuilder: separatorBuilder!,
      );
    }

    return ListView(
      scrollDirection: scrollDirection,
      reverse: reverse,
      controller: controller,
      physics: physics,
      shrinkWrap: shrinkWrap,
      padding: adaptedPadding,
      children: children,
    );
  }
}

/// iOS适配扩展方法
extension IOSAdaptiveWidgetExtension on Widget {
  /// 包装为iOS适配布局
  Widget asIOSAdaptive({
    double spacing = 16.0,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    bool showDebugInfo = false,
  }) {
    return IOSAdaptiveLayout(
      spacing: spacing,
      crossAxisAlignment: crossAxisAlignment,
      showDebugInfo: showDebugInfo,
      children: [this],
    );
  }
}
