import 'package:flutter/material.dart';

/// 翻页手势区域类型
enum PageTurningType {
  prev,   // 上一页
  next,   // 下一页
  menu,   // 显示菜单
}

/// 翻页区域配置
class PageTurningZones {
  /// 将屏幕分为九个区域的翻页设置
  /// 参考anx-reader的设计，提供5种翻页模式
  
  // 模式1：两边翻页，中间菜单
  static const List<PageTurningType> mode1 = [
    PageTurningType.prev, PageTurningType.menu, PageTurningType.next,  // 上排
    PageTurningType.prev, PageTurningType.menu, PageTurningType.next,  // 中排
    PageTurningType.prev, PageTurningType.menu, PageTurningType.next,  // 下排
  ];

  // 模式2：左边上一页，右边下一页，中间菜单
  static const List<PageTurningType> mode2 = [
    PageTurningType.prev, PageTurningType.prev, PageTurningType.next,  // 上排
    PageTurningType.prev, PageTurningType.menu, PageTurningType.next,  // 中排
    PageTurningType.prev, PageTurningType.next, PageTurningType.next,  // 下排
  ];

  // 模式3：左边上一页，右边下一页区域更大
  static const List<PageTurningType> mode3 = [
    PageTurningType.prev, PageTurningType.prev, PageTurningType.next,  // 上排
    PageTurningType.prev, PageTurningType.menu, PageTurningType.next,  // 中排
    PageTurningType.next, PageTurningType.next, PageTurningType.next,  // 下排
  ];

  // 模式4：中央控制，边缘翻页
  static const List<PageTurningType> mode4 = [
    PageTurningType.menu, PageTurningType.menu, PageTurningType.menu,  // 上排
    PageTurningType.prev, PageTurningType.next, PageTurningType.next,  // 中排
    PageTurningType.prev, PageTurningType.next, PageTurningType.next,  // 下排
  ];

  // 模式5：右侧为主要翻页区域
  static const List<PageTurningType> mode5 = [
    PageTurningType.next, PageTurningType.menu, PageTurningType.next,  // 上排
    PageTurningType.next, PageTurningType.prev, PageTurningType.next,  // 中排
    PageTurningType.next, PageTurningType.next, PageTurningType.next,  // 下排
  ];

  static const List<List<PageTurningType>> allModes = [
    mode1, mode2, mode3, mode4, mode5,
  ];

  /// 获取翻页模式的描述
  static String getModeDescription(int modeIndex) {
    switch (modeIndex) {
      case 0: return '经典模式：两边翻页，中间菜单';
      case 1: return '分区模式：左上一页，右下一页';
      case 2: return '下一页优先：右侧大面积下一页';
      case 3: return '中央控制：上方菜单，下方翻页';
      case 4: return '右手模式：右侧主要翻页区';
      default: return '未知模式';
    }
  }

  /// 根据屏幕坐标和模式获取操作类型
  static PageTurningType getActionFromPosition(
    Offset position, 
    Size screenSize, 
    int modeIndex
  ) {
    if (modeIndex < 0 || modeIndex >= allModes.length) {
      return PageTurningType.menu;
    }

    // 将屏幕分为3x3网格
    final double sectionWidth = screenSize.width / 3;
    final double sectionHeight = screenSize.height / 3;

    int row = (position.dy / sectionHeight).floor().clamp(0, 2);
    int col = (position.dx / sectionWidth).floor().clamp(0, 2);

    int index = row * 3 + col;
    return allModes[modeIndex][index];
  }
}

/// 翻页区域可视化组件
class PageTurningZoneVisualizer extends StatelessWidget {
  final int currentMode;
  final bool showZones;
  
  const PageTurningZoneVisualizer({
    super.key,
    required this.currentMode,
    required this.showZones,
  });

  @override
  Widget build(BuildContext context) {
    if (!showZones || currentMode < 0 || currentMode >= PageTurningZones.allModes.length) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.3),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.0,
          ),
          itemCount: 9,
          itemBuilder: (context, index) {
            final action = PageTurningZones.allModes[currentMode][index];
            return Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: _getActionColor(action),
                border: Border.all(color: Colors.white, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getActionIcon(action),
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getActionText(action),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
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

  Color _getActionColor(PageTurningType action) {
    switch (action) {
      case PageTurningType.prev:
        return Colors.blue.withValues(alpha: 0.7);
      case PageTurningType.next:
        return Colors.green.withValues(alpha: 0.7);
      case PageTurningType.menu:
        return Colors.orange.withValues(alpha: 0.7);
    }
  }

  IconData _getActionIcon(PageTurningType action) {
    switch (action) {
      case PageTurningType.prev:
        return Icons.navigate_before;
      case PageTurningType.next:
        return Icons.navigate_next;
      case PageTurningType.menu:
        return Icons.menu;
    }
  }

  String _getActionText(PageTurningType action) {
    switch (action) {
      case PageTurningType.prev:
        return '上一页';
      case PageTurningType.next:
        return '下一页';
      case PageTurningType.menu:
        return '菜单';
    }
  }
}

/// 翻页手势检测器
class PageTurningGestureDetector extends StatelessWidget {
  final Widget child;
  final int currentMode;
  final VoidCallback? onPrevPage;
  final VoidCallback? onNextPage;
  final VoidCallback? onShowMenu;
  final bool enableGestures;

  const PageTurningGestureDetector({
    super.key,
    required this.child,
    required this.currentMode,
    this.onPrevPage,
    this.onNextPage,
    this.onShowMenu,
    this.enableGestures = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableGestures) {
      return child;
    }

    return GestureDetector(
      onTapUp: (details) {
        final screenSize = MediaQuery.of(context).size;
        final action = PageTurningZones.getActionFromPosition(
          details.globalPosition,
          screenSize,
          currentMode,
        );

        switch (action) {
          case PageTurningType.prev:
            onPrevPage?.call();
            break;
          case PageTurningType.next:
            onNextPage?.call();
            break;
          case PageTurningType.menu:
            onShowMenu?.call();
            break;
        }
      },
      child: child,
    );
  }
}
