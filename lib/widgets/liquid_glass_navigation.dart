import 'package:flutter/material.dart';
import 'dart:ui';

/// 液态玻璃导航栏组件
/// 实现双层玻璃效果、拖拽切换、动态动画等功能
class LiquidGlassNavigation extends StatefulWidget {
  /// 导航项列表
  final List<LiquidGlassNavigationItem> items;

  /// 当前选中的索引
  final int selectedIndex;

  /// 选中项改变回调
  final ValueChanged<int> onItemSelected;

  /// 背景颜色
  final Color backgroundColor;

  /// 选中指示器颜色
  final Color indicatorColor;

  /// 导航栏高度
  final double height;

  /// 水平边距
  final double horizontalPadding;

  /// 是否启用拖拽
  final bool enableDrag;

  const LiquidGlassNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    this.backgroundColor = Colors.white,
    this.indicatorColor = Colors.blue,
    this.height = 75,
    this.horizontalPadding = 36,
    this.enableDrag = true,
  });

  @override
  State<LiquidGlassNavigation> createState() => _LiquidGlassNavigationState();
}

class _LiquidGlassNavigationState extends State<LiquidGlassNavigation>
    with TickerProviderStateMixin {
  late AnimationController _indicatorController;
  late AnimationController _scaleController;
  late AnimationController _refractionController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _refractionAnimation;

  double _dragOffset = 0.0;
  bool _isDragging = false;
  late double _itemWidth;

  @override
  void initState() {
    super.initState();

    // 指示器位置动画控制器
    _indicatorController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // 缩放动画控制器
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // 折射效果动画控制器
    _refractionController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _refractionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _refractionController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    _scaleController.dispose();
    _refractionController.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    if (index != widget.selectedIndex) {
      widget.onItemSelected(index);
      _animateToIndex(index);
    }
  }

  void _animateToIndex(int index) {
    // 播放指示器动画
    _indicatorController.forward();

    // 播放缩放和折射动画
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
    _refractionController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _refractionController.reverse();
        }
      });
    });
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.enableDrag) return;

    setState(() {
      _isDragging = true;
    });
    _refractionController.forward();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.enableDrag) return;

    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx)
          .clamp(0.0, _itemWidth * (widget.items.length - 1));
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.enableDrag) return;

    setState(() {
      _isDragging = false;
    });

    // 计算目标索引
    final velocity = details.velocity.pixelsPerSecond.dx;
    final currentIndex = _dragOffset / _itemWidth;

    int targetIndex;
    if (velocity.abs() > 500) {
      // 快速滑动
      targetIndex = velocity > 0 ? currentIndex.ceil() : currentIndex.floor();
    } else {
      // 静态释放
      targetIndex = currentIndex.round();
    }

    targetIndex = targetIndex.clamp(0, widget.items.length - 1);

    if (targetIndex != widget.selectedIndex) {
      widget.onItemSelected(targetIndex);
    }

    // 动画回到正确位置
    _animateToCorrectPosition(targetIndex);
    _refractionController.reverse();
  }

  void _animateToCorrectPosition(int targetIndex) {
    final targetOffset = targetIndex * _itemWidth;
    final duration = Duration(
        milliseconds: ((_dragOffset - targetOffset).abs() / _itemWidth * 300)
            .round()
            .clamp(150, 500));

    // 使用 Tween 动画平滑移动到目标位置
    final tween = Tween<double>(begin: _dragOffset, end: targetOffset);
    final controller = AnimationController(duration: duration, vsync: this);

    final animation = tween.animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    ));

    animation.addListener(() {
      setState(() {
        _dragOffset = animation.value;
      });
    });

    controller.forward().then((_) {
      controller.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth - (widget.horizontalPadding * 2);
        _itemWidth = availableWidth / widget.items.length;

        // 如果不在拖拽状态，则使用选中索引计算偏移
        if (!_isDragging) {
          _dragOffset = widget.selectedIndex * _itemWidth;
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.height / 2),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: widget.height,
              decoration: BoxDecoration(
                color: widget.backgroundColor.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(widget.height / 2),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 48,
                    offset: const Offset(0, 12),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // 液态指示器
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _scaleAnimation,
                      _refractionAnimation,
                    ]),
                    builder: (context, child) {
                      return Positioned(
                        left: widget.horizontalPadding + _dragOffset,
                        top: (widget.height -
                                _itemWidth * _scaleAnimation.value) /
                            2,
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: _itemWidth,
                            height: _itemWidth,
                            decoration: BoxDecoration(
                              color: widget.indicatorColor.withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(_itemWidth / 2),
                            ),
                            child: CustomPaint(
                              painter: LiquidGlassPainter(
                                color: widget.indicatorColor,
                                refractionIntensity: _refractionAnimation.value,
                                isDragging: _isDragging,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // 导航项
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: widget.horizontalPadding),
                      child: GestureDetector(
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: widget.items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final isSelected = index == widget.selectedIndex;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () => _onTap(index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedScale(
                                        scale: isSelected ? 1.1 : 1.0,
                                        duration:
                                            const Duration(milliseconds: 200),
                                        child: Icon(
                                          isSelected
                                              ? item.selectedIcon
                                              : item.icon,
                                          color: isSelected
                                              ? widget.indicatorColor
                                              : Colors.black.withValues(alpha: 0.6),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      AnimatedDefaultTextStyle(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? widget.indicatorColor
                                              : Colors.black.withValues(alpha: 0.6),
                                        ),
                                        child: Text(
                                          item.label,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 液态玻璃效果画笔
class LiquidGlassPainter extends CustomPainter {
  final Color color;
  final double refractionIntensity;
  final bool isDragging;

  LiquidGlassPainter({
    required this.color,
    required this.refractionIntensity,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 外层玻璃效果
    final outerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.3),
          color.withValues(alpha: 0.1),
          Colors.transparent,
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, outerPaint);

    // 内层折射效果（拖拽时显示）
    if (isDragging || refractionIntensity > 0) {
      final refractionPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.4 * refractionIntensity)
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, 2 * refractionIntensity);

      // 绘制高光效果
      final highlightPath = Path();
      highlightPath.addOval(Rect.fromCircle(
        center: Offset(center.dx - radius * 0.3, center.dy - radius * 0.3),
        radius: radius * 0.3,
      ));

      canvas.drawPath(highlightPath, refractionPaint);

      // 绘制液态波纹效果
      for (int i = 0; i < 3; i++) {
        final ripplePaint = Paint()
          ..color = color.withValues(alpha: 0.1 * refractionIntensity * (1 - i * 0.3))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

        canvas.drawCircle(
          center,
          radius * (0.5 + i * 0.2) * (1 + refractionIntensity * 0.5),
          ripplePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant LiquidGlassPainter oldDelegate) {
    return oldDelegate.refractionIntensity != refractionIntensity ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.color != color;
  }
}

/// 导航项数据类
class LiquidGlassNavigationItem {
  /// 默认图标
  final IconData icon;

  /// 选中时的图标
  final IconData selectedIcon;

  /// 标签文本
  final String label;

  const LiquidGlassNavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
