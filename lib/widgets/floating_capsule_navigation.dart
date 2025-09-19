import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/glass_config.dart';

// 悬浮胶囊式导航栏组件
// 仿iOS风格的胶囊选择器，支持毛玻璃效果和平滑动画
class FloatingCapsuleNavigation extends StatefulWidget {
  final List<CapsuleNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final EdgeInsets? margin;
  final double? width;
  final double height;

  const FloatingCapsuleNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    this.margin,
    this.width,
    this.height = 50,
  });

  @override
  State<FloatingCapsuleNavigation> createState() =>
      _FloatingCapsuleNavigationState();
}

class _FloatingCapsuleNavigationState extends State<FloatingCapsuleNavigation>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _bounceController;
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;
  late Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();

    // 主要的缩放动画控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500), // 减少时长
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic, // 改为平滑曲线
      ),
    );

    // Q弹效果控制器
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 400), // 减少时长
      vsync: this,
    );

    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      // 减少弹跳幅度
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.easeOutCubic,
      ), // 改为平滑曲线
    );

    // 按压效果控制器
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 200), // 稍微增加时长
      vsync: this,
    );

    _pressAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      // 减少按压幅度
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _bounceController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FloatingCapsuleNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _animationController.forward(from: 0);
      // 添加Q弹效果
      _bounceController.forward(from: 0).then((_) {
        _bounceController.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _animationController,
        _bounceController,
        _pressController,
      ]),
      builder: (context, child) {
        return Transform.scale(
          scale:
              _scaleAnimation.value *
              _bounceAnimation.value *
              _pressAnimation.value,
          child: Container(
            margin:
                widget.margin ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: widget.height,
            width: widget.width,
            child: _buildCapsuleNavigation(),
          ),
        );
      },
    );
  }

  Widget _buildCapsuleNavigation() {
    // 增大圆角半径，让形状更Q弹圆润
    final borderRadius = (widget.height / 2) + 8; // 增加8px让圆角更大

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          // 悬浮效果阴影 - 增强阴影让Q弹感更强
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 25,
            offset: const Offset(0, 10),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 45,
            offset: const Offset(0, 20),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        // 毛玻璃效果背景
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: GlassEffectConfig.modalBlur,
            sigmaY: GlassEffectConfig.modalBlur,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                width: 0.5,
              ),
            ),
            child: Stack(
              children: [
                // 滑动指示器背景
                _buildSlideIndicator(),
                // 导航项目
                _buildNavigationItems(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlideIndicator() {
    final itemWidth = 1.0 / widget.items.length;
    final borderRadius = (widget.height / 2) + 6; // 与外层圆角保持协调，但稍小

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400), // 增加动画时长
      curve: Curves.easeOutCubic, // 使用平滑曲线
      left: widget.selectedIndex * itemWidth * (widget.width ?? 200),
      top: 6, // 增加内边距
      bottom: 6,
      width: itemWidth * (widget.width ?? 200),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6), // 增加边距
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationItems() {
    final borderRadius = (widget.height / 2) + 8; // 与外层保持一致

    return Row(
      children: widget.items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isSelected = index == widget.selectedIndex;

        return Expanded(
          child: _CapsuleNavigationItem(
            item: item,
            isSelected: isSelected,
            borderRadius: borderRadius,
            onTap: () {
              widget.onItemSelected(index);
              // 触发整体的Q弹效果
              _bounceController.forward(from: 0).then((_) {
                _bounceController.reverse();
              });
            },
            onTapDown: () {
              _pressController.forward();
            },
            onTapUp: () {
              _pressController.reverse();
            },
          ),
        );
      }).toList(),
    );
  }
}

// 胶囊导航项目数据类
class CapsuleNavigationItem {
  final String label;
  final IconData? icon;
  final Widget? customIcon;

  const CapsuleNavigationItem({
    required this.label,
    this.icon,
    this.customIcon,
  });
}

// 预定义的悬浮导航栏样式
class FloatingCapsuleStyles {
  // 标准样式 (适用于顶部导航)
  static Widget standard({
    required List<CapsuleNavigationItem> items,
    required int selectedIndex,
    required ValueChanged<int> onItemSelected,
  }) {
    return FloatingCapsuleNavigation(
      items: items,
      selectedIndex: selectedIndex,
      onItemSelected: onItemSelected,
      height: 44,
      width: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  // 紧凑样式 (适用于工具栏)
  static Widget compact({
    required List<CapsuleNavigationItem> items,
    required int selectedIndex,
    required ValueChanged<int> onItemSelected,
  }) {
    return FloatingCapsuleNavigation(
      items: items,
      selectedIndex: selectedIndex,
      onItemSelected: onItemSelected,
      height: 36,
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }

  // 宽展样式 (适用于标签页)
  static Widget wide({
    required List<CapsuleNavigationItem> items,
    required int selectedIndex,
    required ValueChanged<int> onItemSelected,
  }) {
    return FloatingCapsuleNavigation(
      items: items,
      selectedIndex: selectedIndex,
      onItemSelected: onItemSelected,
      height: 50,
      width: 280,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
  }
}

// 使用示例和说明
/*
使用方式：

1. 基本用法：
FloatingCapsuleNavigation(
  items: const [
    CapsuleNavigationItem(label: '图库', icon: Icons.photo_library),
    CapsuleNavigationItem(label: '精选集', icon: Icons.collections),
  ],
  selectedIndex: selectedIndex,
  onItemSelected: (index) {
    setState(() {
      selectedIndex = index;
    });
  },
)

2. 使用预定义样式：
FloatingCapsuleStyles.standard(
  items: navigationItems,
  selectedIndex: currentIndex,
  onItemSelected: onSelectionChanged,
)

3. 自定义样式：
FloatingCapsuleNavigation(
  items: items,
  selectedIndex: selectedIndex,
  onItemSelected: onItemSelected,
  height: 60,           // 自定义高度
  width: 300,           // 自定义宽度
  margin: EdgeInsets.all(20), // 自定义边距
)

特性：
- 毛玻璃背景效果
- 平滑的切换动画
- 悬浮阴影效果
- iOS风格设计
- 支持图标和文字
- 完全可自定义
*/

// 单个导航项目组件，支持微交互
class _CapsuleNavigationItem extends StatefulWidget {
  final CapsuleNavigationItem item;
  final bool isSelected;
  final double borderRadius;
  final VoidCallback onTap;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;

  const _CapsuleNavigationItem({
    required this.item,
    required this.isSelected,
    required this.borderRadius,
    required this.onTap,
    required this.onTapDown,
    required this.onTapUp,
  });

  @override
  State<_CapsuleNavigationItem> createState() => _CapsuleNavigationItemState();
}

class _CapsuleNavigationItemState extends State<_CapsuleNavigationItem>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _tapController;
  late Animation<double> _hoverAnimation;
  late Animation<double> _tapAnimation;
  late Animation<double> _iconScaleAnimation;

  bool _isHovering = false;

  @override
  void initState() {
    super.initState();

    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _tapController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _hoverAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      // 减少悬停缩放幅度
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );

    _tapAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97, // 减少点击缩放幅度
    ).animate(CurvedAnimation(parent: _tapController, curve: Curves.easeInOut));

    _iconScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      // 减少图标缩放幅度
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: GestureDetector(
        onTapDown: (_) {
          widget.onTapDown();
          _tapController.forward();
        },
        onTapUp: (_) {
          widget.onTapUp();
          _tapController.reverse();
        },
        onTapCancel: () {
          widget.onTapUp();
          _tapController.reverse();
        },
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_hoverController, _tapController]),
          builder: (context, child) {
            return Transform.scale(
              scale: _hoverAnimation.value * _tapAnimation.value,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  color: _isHovering
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
                      : Colors.transparent,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 图标
                    if (widget.item.icon != null) ...[
                      AnimatedBuilder(
                        animation: _iconScaleAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: widget.isSelected
                                ? _iconScaleAnimation.value
                                : 1.0,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                widget.item.icon,
                                size: 18,
                                color: widget.isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                    ],
                    // 文字
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: widget.isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: widget.isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: _isHovering ? 14.5 : 14,
                      ),
                      child: Text(widget.item.label),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _onHover(bool isHovering) {
    if (_isHovering == isHovering) return;

    setState(() {
      _isHovering = isHovering;
    });

    if (isHovering) {
      _hoverController.forward();
    } else {
      _hoverController.reverse();
    }
  }
}
