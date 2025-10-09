import 'package:flutter/material.dart';

/// 📄 覆盖翻页动画
///
/// 原理：
/// - 当前页保持不动（或被推走）
/// - 新页面从右侧（下一页）或左侧（上一页）覆盖上来
/// - 添加阴影效果，增强立体感
class CoverPageAnimationController {
  final AnimationController controller;
  final PageDirection direction;

  CoverPageAnimationController({
    required this.controller,
    required this.direction,
  });

  /// 获取当前动画进度（0.0 ~ 1.0）
  double get progress => controller.value;

  /// 获取偏移量
  double getOffset(double viewWidth) {
    if (direction == PageDirection.next) {
      // 下一页：从右侧覆盖
      return viewWidth * (1.0 - progress);
    } else {
      // 上一页：从左侧覆盖
      return -viewWidth * (1.0 - progress);
    }
  }
}

/// 页面方向
enum PageDirection {
  next, // 下一页
  prev, // 上一页
  none, // 无方向
}

/// 覆盖翻页动画组件
class CoverPageAnimation extends StatelessWidget {
  final Widget currentPage;
  final Widget? nextPage;
  final Widget? prevPage;
  final PageDirection direction;
  final Animation<double> animation;
  final bool showShadow;

  const CoverPageAnimation({
    Key? key,
    required this.currentPage,
    this.nextPage,
    this.prevPage,
    required this.direction,
    required this.animation,
    this.showShadow = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (direction == PageDirection.none || animation.value == 0.0) {
      return currentPage;
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final viewWidth = constraints.maxWidth;
            final viewHeight = constraints.maxHeight;
            final offsetX = viewWidth * animation.value;

            if (direction == PageDirection.next) {
              return _buildNextPageAnimation(viewWidth, viewHeight, offsetX);
            } else {
              return _buildPrevPageAnimation(viewWidth, viewHeight, offsetX);
            }
          },
        );
      },
    );
  }

  /// 构建下一页动画（从右侧覆盖）
  Widget _buildNextPageAnimation(
      double viewWidth, double viewHeight, double offsetX) {
    return Stack(
      children: [
        // 当前页（被推向左侧）
        Transform.translate(
          offset: Offset(-offsetX, 0),
          child: currentPage,
        ),

        // 下一页（从右侧覆盖）
        if (nextPage != null)
          ClipRect(
            clipper: _RightClipper(offsetX: offsetX, viewWidth: viewWidth),
            child: Transform.translate(
              offset: Offset(viewWidth - offsetX, 0),
              child: nextPage,
            ),
          ),

        // 阴影效果
        if (showShadow && offsetX > 0)
          Positioned(
            left: viewWidth - offsetX - 30,
            top: 0,
            child: Container(
              width: 30,
              height: viewHeight,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0x66111111),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 构建上一页动画（从左侧覆盖）
  Widget _buildPrevPageAnimation(
      double viewWidth, double viewHeight, double offsetX) {
    return Stack(
      children: [
        // 当前页（保持不动）
        currentPage,

        // 上一页（从左侧覆盖）
        if (prevPage != null)
          Transform.translate(
            offset: Offset(-viewWidth + offsetX, 0),
            child: prevPage,
          ),

        // 阴影效果
        if (showShadow && offsetX > 0)
          Positioned(
            left: offsetX - 30,
            top: 0,
            child: Container(
              width: 30,
              height: viewHeight,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0x66111111),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 右侧裁剪器（用于裁剪下一页）
class _RightClipper extends CustomClipper<Rect> {
  final double offsetX;
  final double viewWidth;

  _RightClipper({required this.offsetX, required this.viewWidth});

  @override
  Rect getClip(Size size) {
    // 只显示右侧部分
    return Rect.fromLTRB(
      viewWidth - offsetX,
      0,
      size.width,
      size.height,
    );
  }

  @override
  bool shouldReclip(_RightClipper oldClipper) {
    return oldClipper.offsetX != offsetX || oldClipper.viewWidth != viewWidth;
  }
}

/// 滑动翻页动画（原有的实现，保持兼容）
class SlidePageAnimation extends StatelessWidget {
  final Widget currentPage;
  final Widget? nextPage;
  final PageDirection direction;
  final Animation<double> animation;

  const SlidePageAnimation({
    Key? key,
    required this.currentPage,
    this.nextPage,
    required this.direction,
    required this.animation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final viewWidth = constraints.maxWidth;
            final offset = viewWidth * animation.value;

            return Stack(
              children: [
                Transform.translate(
                  offset: Offset(
                    direction == PageDirection.next ? -offset : offset,
                    0,
                  ),
                  child: currentPage,
                ),
                if (nextPage != null)
                  Transform.translate(
                    offset: Offset(
                      direction == PageDirection.next
                          ? viewWidth - offset
                          : -viewWidth + offset,
                      0,
                    ),
                    child: nextPage,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// 滚动翻页动画
class ScrollPageAnimation extends StatelessWidget {
  final Widget currentPage;
  final Animation<double> animation;

  const ScrollPageAnimation({
    Key? key,
    required this.currentPage,
    required this.animation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 滚动翻页使用不同的实现方式，这里简化为渐变
    return FadeTransition(
      opacity: animation,
      child: currentPage,
    );
  }
}

/// 无动画翻页
class NoPageAnimation extends StatelessWidget {
  final Widget currentPage;

  const NoPageAnimation({
    Key? key,
    required this.currentPage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return currentPage;
  }
}
