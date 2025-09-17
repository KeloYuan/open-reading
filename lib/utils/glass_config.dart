// 毛玻璃效果配置管理器
// 集中管理所有界面的毛玻璃效果和透明度设置

import 'package:flutter/material.dart';
import 'progressive_blur.dart';
import 'color_extensions.dart';

class GlassEffectConfig {
  // ============ 模糊强度配置 (sigmaX/sigmaY) ============

  // 顶部应用栏 (AppBar)
  static const double appBarBlur = 15.0; // 首页、书库、设置页顶栏 - 增加模糊强度

  // 导航栏
  static const double navigationBarBlur = 15.0; // 底部悬浮式导航栏 - 增加模糊强度

  // 阅读页面控制栏
  static const double readingTopBarBlur = 15.0; // 阅读页顶部控制栏
  static const double readingBottomBarBlur = 15.0; // 阅读页底部控制栏

  // 卡片和容器
  static const double cardBlur = 20.0; // 一般卡片容器
  static const double lightCardBlur = 8.0; // 轻量级容器（图标背景等）
  static const double dialogBlur = 30.0; // 对话框和弹窗
  static const double modalBlur = 25.0; // 底部弹出菜单

  // ============ 透明度配置 (alpha值: 0.0-1.0) ============

  // 顶部应用栏透明度
  static const double appBarOpacity = 0.3; // 可调范围: 0.3-0.9 (修改为不透明)

  // 导航栏透明度
  static const double navigationBarOpacity = 0.3; // 可调范围: 0.7-0.95

  // 阅读页面控制栏透明度
  static const double readingTopBarOpacity = 0.9; // 可调范围: 0.6-0.9
  static const double readingBottomBarOpacity = 0.9; // 可调范围: 0.8-0.95

  // 卡片透明度
  static const double cardOpacity = 0.8; // 一般卡片
  static const double lightCardOpacity = 0.15; // 轻量级容器
  static const double dialogOpacity = 0.95; // 对话框
  static const double modalOpacity = 0.9; // 底部弹出菜单

  // ============ 快速配置预设 ============

  // 预设1: 清晰模式 (透明度偏高，模糊偏低)
  static const GlassPreset clearMode = GlassPreset(
    name: '清晰模式',
    blurReduction: 0.6, // 模糊强度 × 0.6
    opacityIncrease: 0.2, // 透明度 + 0.2
  );

  // 预设2: 毛玻璃模式 (标准设置)
  static const GlassPreset standardMode = GlassPreset(
    name: '标准模式',
    blurReduction: 1.0, // 标准模糊
    opacityIncrease: 0.0, // 标准透明度
  );

  // 预设3: 朦胧模式 (透明度偏低，模糊偏高)
  static const GlassPreset dreamyMode = GlassPreset(
    name: '朦胧模式',
    blurReduction: 1.4, // 模糊强度 × 1.4
    opacityIncrease: -0.15, // 透明度 - 0.15
  );

  // ============ 对外静态转发（兼容旧调用） ============
  static Widget createProgressiveAppBar({
    required BuildContext context,
    required Widget child,
    GlassPreset? preset,
    bool enableBlur = true, // 新增
    double? opacityScale, // 新增：调整透明度强度
  }) {
    return ClipRect(
      child: GlassEffectHelper._progressiveAppBarInternal(
        context: context,
        child: child,
        preset: preset,
        enableBlur: enableBlur,
        opacityScale: opacityScale,
      ),
    );
  }

  static Widget createProgressiveCard({
    required BuildContext context,
    required Widget child,
    BorderRadius? borderRadius,
    GlassPreset? preset,
    bool enableBlur = true, // 新增：可关闭毛玻璃
  }) {
    return GlassEffectHelper.createProgressiveCard(
      context: context,
      child: child,
      borderRadius: borderRadius,
      preset: preset,
      enableBlur: enableBlur,
    );
  }
}

// 毛玻璃预设配置
class GlassPreset {
  final String name;
  final double blurReduction; // 模糊强度倍数
  final double opacityIncrease; // 透明度增减值

  const GlassPreset({
    required this.name,
    required this.blurReduction,
    required this.opacityIncrease,
  });
}

// 毛玻璃效果辅助工具
class GlassEffectHelper {
  // 获取应用栏配置
  static Map<String, double> getAppBarConfig({GlassPreset? preset}) {
    preset ??= GlassEffectConfig.standardMode;
    return {
      'blur': GlassEffectConfig.appBarBlur * preset.blurReduction,
      'opacity': (GlassEffectConfig.appBarOpacity + preset.opacityIncrease)
          .clamp(0.0, 1.0),
    };
  }

  // 获取导航栏配置
  static Map<String, double> getNavigationConfig({GlassPreset? preset}) {
    preset ??= GlassEffectConfig.standardMode;
    return {
      'blur': GlassEffectConfig.navigationBarBlur * preset.blurReduction,
      'opacity':
          (GlassEffectConfig.navigationBarOpacity + preset.opacityIncrease)
              .clamp(0.0, 1.0),
    };
  }

  // 获取阅读页控制栏配置
  static Map<String, double> getReadingControlConfig({
    GlassPreset? preset,
    bool isTopBar = true,
  }) {
    preset ??= GlassEffectConfig.standardMode;
    final blur = isTopBar
        ? GlassEffectConfig.readingTopBarBlur
        : GlassEffectConfig.readingBottomBarBlur;
    final opacity = isTopBar
        ? GlassEffectConfig.readingTopBarOpacity
        : GlassEffectConfig.readingBottomBarOpacity;

    return {
      'blur': blur * preset.blurReduction,
      'opacity': (opacity + preset.opacityIncrease).clamp(0.0, 1.0),
    };
  }

  // ============ 渐进模糊效果配置 ============

  // 创建渐进模糊的AppBar（内部实现，外部通过 ClipRect 包裹后调用）
  static Widget _progressiveAppBarInternal({
    required BuildContext context,
    required Widget child,
    GlassPreset? preset,
    bool enableBlur = true,
    double? opacityScale,
  }) {
    preset ??= GlassEffectConfig.standardMode;
    final config = getAppBarConfig(preset: preset);
    final scaledOpacity = (opacityScale != null)
        ? (config['opacity']! * opacityScale).clamp(0.0, 1.0)
        : config['opacity']!;

    if (!enableBlur) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surface.withOpacityValues(scaledOpacity),
          border: Border(
            bottom: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outline.withOpacityValues(0.16),
              width: 0.5,
            ),
          ),
        ),
        child: child,
      );
    }

    // 使用单层底色 + 轻覆层模糊，避免双重渐变导致的发暗与割裂
    return ProgressiveBlurPresets.topToBottomBlur(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surface.withOpacityValues(scaledOpacity),
        ),
        child: child,
      ),
      context: context,
      maxBlur: config['blur']!,
    );
  }

  // 创建渐进模糊的卡片
  static Widget createProgressiveCard({
    required BuildContext context,
    required Widget child,
    BorderRadius? borderRadius,
    GlassPreset? preset,
    bool enableBlur = true, // 新增
  }) {
    preset ??= GlassEffectConfig.standardMode;

    if (!enableBlur) {
      // 使用更清晰的实体卡片样式
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacityValues(0.98),
          borderRadius: borderRadius,
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outline.withOpacityValues(0.16),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.shadow.withOpacityValues(0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );
    }

    return ProgressiveBlurPresets.radialBlur(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacityValues(
            GlassEffectConfig.cardOpacity,
          ),
          borderRadius: borderRadius,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacityValues(0.2),
            width: 1,
          ),
        ),
        child: child,
      ),
      context: context,
      maxBlur: GlassEffectConfig.cardBlur * preset.blurReduction,
      borderRadius: borderRadius,
    );
  }

  // 创建渐进模糊的对话框
  static Widget createProgressiveDialog({
    required BuildContext context,
    required Widget child,
    BorderRadius? borderRadius,
    GlassPreset? preset,
  }) {
    preset ??= GlassEffectConfig.standardMode;

    return ProgressiveBlurPresets.edgeBlur(
      child: child,
      context: context,
      maxBlur: GlassEffectConfig.dialogBlur * preset.blurReduction,
      borderRadius: borderRadius ?? BorderRadius.circular(20),
    );
  }

  // 创建渐进模糊的底部导航栏
  static Widget createProgressiveBottomNav({
    required BuildContext context,
    required Widget child,
    BorderRadius? borderRadius,
    GlassPreset? preset,
  }) {
    preset ??= GlassEffectConfig.standardMode;
    final config = getNavigationConfig(preset: preset);

    return ProgressiveBlurPresets.bottomNavigationBlur(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Theme.of(
                context,
              ).colorScheme.surface.withOpacityValues(config['opacity']! + 0.1),
              Theme.of(
                context,
              ).colorScheme.surface.withOpacityValues(config['opacity']!),
              Colors.transparent,
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        child: child,
      ),
      context: context,
      maxBlur: config['blur']!,
      borderRadius: borderRadius,
    );
  }
}

// ============ 使用示例 ============
/*
// 1. 直接使用配置值
BackdropFilter(
  filter: ImageFilter.blur(
    sigmaX: GlassEffectConfig.appBarBlur,
    sigmaY: GlassEffectConfig.appBarBlur,
  ),
  child: Container(
    color: Theme.of(context).colorScheme.surface.withOpacityValues(
      GlassEffectConfig.appBarOpacity
    ),
  ),
)

// 2. 使用预设配置
final config = GlassEffectHelper.getAppBarConfig(preset: GlassEffectConfig.clearMode);
BackdropFilter(
  filter: ImageFilter.blur(
    sigmaX: config['blur']!,
    sigmaY: config['blur']!,
  ),
  child: Container(
    color: Theme.of(context).colorScheme.surface.withOpacityValues(
      config['opacity']!
    ),
  ),
)

// 3. 快速调整透明度
// 要让应用栏更透明: 把 appBarOpacity 从 0.6 改为 0.4
// 要让应用栏更不透明: 把 appBarOpacity 从 0.6 改为 0.8
// 要让模糊效果更强: 把 appBarBlur 从 20.0 改为 30.0
// 要让模糊效果更弱: 把 appBarBlur 从 20.0 改为 10.0
*/
