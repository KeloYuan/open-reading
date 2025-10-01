import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 翻页动画类型
enum PageAnimationType {
  /// 覆盖翻页动画
  cover(0, '覆盖翻页', '页面覆盖滑动效果'),

  /// 滑动翻页动画
  slide(1, '滑动翻页', '页面左右滑动效果'),

  /// 仿真翻页动画
  simulation(2, '仿真翻页', '3D仿真翻书效果'),

  /// 滚动翻页动画
  scroll(3, '滚动翻页', '垂直滚动阅读效果'),

  /// 无动画
  none(4, '无动画', '直接切换无过渡');

  const PageAnimationType(this.value, this.displayName, this.description);

  final int value;
  final String displayName;
  final String description;

  static PageAnimationType fromValue(int value) {
    return PageAnimationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => PageAnimationType.slide,
    );
  }
}

/// 翻页动画管理器
class PageAnimationManager {
  static const String _preferenceKey = 'pageAnimationType';
  static const Duration _defaultDuration = Duration(milliseconds: 300);
  static const Curve _defaultCurve = Curves.easeInOut;

  /// 获取当前翻页动画类型
  static Future<PageAnimationType> getCurrentAnimationType() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_preferenceKey) ?? PageAnimationType.slide.value;
    return PageAnimationType.fromValue(value);
  }

  /// 设置翻页动画类型
  static Future<void> setAnimationType(PageAnimationType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_preferenceKey, type.value);
  }

  /// 创建翻页动画
  static Widget createPageTransition({
    required PageAnimationType animationType,
    required Widget child,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    bool isForward = true,
    Duration? duration,
    Curve? curve,
  }) {
    final effectiveCurve = curve ?? _defaultCurve;

    switch (animationType) {
      case PageAnimationType.cover:
        return _buildCoverTransition(
          child: child,
          animation: animation,
          isForward: isForward,
          curve: effectiveCurve,
        );

      case PageAnimationType.slide:
        return _buildSlideTransition(
          child: child,
          animation: animation,
          isForward: isForward,
          curve: effectiveCurve,
        );

      case PageAnimationType.simulation:
        return _buildSimulationTransition(
          child: child,
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          isForward: isForward,
          curve: effectiveCurve,
        );

      case PageAnimationType.scroll:
        return _buildScrollTransition(
          child: child,
          animation: animation,
          isForward: isForward,
          curve: effectiveCurve,
        );

      case PageAnimationType.none:
        return child;
    }
  }

  /// 覆盖翻页动画
  static Widget _buildCoverTransition({
    required Widget child,
    required Animation<double> animation,
    required bool isForward,
    required Curve curve,
  }) {
    final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);

    return SlideTransition(
      position: Tween<Offset>(
        begin: isForward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0),
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: child,
    );
  }

  /// 滑动翻页动画
  static Widget _buildSlideTransition({
    required Widget child,
    required Animation<double> animation,
    required bool isForward,
    required Curve curve,
  }) {
    final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);

    return SlideTransition(
      position: Tween<Offset>(
        begin: isForward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0),
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: FadeTransition(opacity: curvedAnimation, child: child),
    );
  }

  /// 仿真翻页动画 (3D效果)
  static Widget _buildSimulationTransition({
    required Widget child,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required bool isForward,
    required Curve curve,
  }) {
    final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);

    return AnimatedBuilder(
      animation: curvedAnimation,
      builder: (context, child) {
        final angle = (1.0 - curvedAnimation.value) * (isForward ? 1.0 : -1.0);

        return Transform(
          alignment: isForward ? Alignment.centerLeft : Alignment.centerRight,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // 添加透视效果
            ..rotateY(angle),
          child: child,
        );
      },
      child: child,
    );
  }

  /// 滚动翻页动画
  static Widget _buildScrollTransition({
    required Widget child,
    required Animation<double> animation,
    required bool isForward,
    required Curve curve,
  }) {
    final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);

    return SlideTransition(
      position: Tween<Offset>(
        begin: isForward ? const Offset(0.0, 1.0) : const Offset(0.0, -1.0),
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: child,
    );
  }

  /// 创建页面路由过渡
  static PageRouteBuilder<T> createPageRoute<T>({
    required Widget page,
    required PageAnimationType animationType,
    Duration? transitionDuration,
    Curve? curve,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: transitionDuration ?? _defaultDuration,
      reverseTransitionDuration: transitionDuration ?? _defaultDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return createPageTransition(
          animationType: animationType,
          child: child,
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          isForward: true,
          duration: transitionDuration,
          curve: curve,
        );
      },
    );
  }

  /// 创建翻页手势检测器
  static Widget createPageGestureDetector({
    required Widget child,
    required VoidCallback? onPreviousPage,
    required VoidCallback? onNextPage,
    required VoidCallback? onToggleControls,
    double? leftZoneWidth,
    double? rightZoneWidth,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final effectiveLeftZone = leftZoneWidth ?? screenWidth * 0.3;
        final effectiveRightZone = rightZoneWidth ?? screenWidth * 0.3;

        return Stack(
          children: [
            child,

            // 左侧翻页区域
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: effectiveLeftZone,
              child: GestureDetector(
                onTap: onPreviousPage,
                child: Container(color: Colors.transparent),
              ),
            ),

            // 右侧翻页区域
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: effectiveRightZone,
              child: GestureDetector(
                onTap: onNextPage,
                child: Container(color: Colors.transparent),
              ),
            ),

            // 中央控制区域
            Positioned(
              left: effectiveLeftZone,
              right: effectiveRightZone,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: onToggleControls,
                child: Container(color: Colors.transparent),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 获取所有动画类型供设置页面使用
  static List<PageAnimationType> getAllAnimationTypes() {
    return PageAnimationType.values;
  }

  /// 动画性能优化建议
  static Map<PageAnimationType, String> getPerformanceNotes() {
    return {
      PageAnimationType.cover: '性能较好，适合大多数设备',
      PageAnimationType.slide: '性能优秀，推荐使用',
      PageAnimationType.simulation: '性能消耗较大，建议高端设备使用',
      PageAnimationType.scroll: '性能良好，适合长文本阅读',
      PageAnimationType.none: '性能最佳，无动画开销',
    };
  }
}

/// 翻页动画配置
class PageAnimationConfig {
  final PageAnimationType type;
  final Duration duration;
  final Curve curve;
  final bool enableGestures;
  final double leftZoneWidth;
  final double rightZoneWidth;

  const PageAnimationConfig({
    this.type = PageAnimationType.slide,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.enableGestures = true,
    this.leftZoneWidth = 0.3,
    this.rightZoneWidth = 0.3,
  });

  PageAnimationConfig copyWith({
    PageAnimationType? type,
    Duration? duration,
    Curve? curve,
    bool? enableGestures,
    double? leftZoneWidth,
    double? rightZoneWidth,
  }) {
    return PageAnimationConfig(
      type: type ?? this.type,
      duration: duration ?? this.duration,
      curve: curve ?? this.curve,
      enableGestures: enableGestures ?? this.enableGestures,
      leftZoneWidth: leftZoneWidth ?? this.leftZoneWidth,
      rightZoneWidth: rightZoneWidth ?? this.rightZoneWidth,
    );
  }
}
