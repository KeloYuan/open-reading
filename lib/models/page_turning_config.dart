/// 点击翻页区域类型
enum TapZoneAction {
  next, // 下一页
  prev, // 上一页
  menu, // 显示菜单
}

/// 点击翻页方案（简化版：左中右三区域）
class TapTurningPattern {
  final String name;
  final String description;

  const TapTurningPattern({
    required this.name,
    required this.description,
  });

  /// 预设方案（固定为左中右）
  static const TapTurningPattern defaultPattern = TapTurningPattern(
    name: '左中右',
    description: '左侧上一页，中间菜单，右侧下一页',
  );

  /// 根据点击位置计算动作
  ///
  /// 将屏幕横向分为3个区域：
  /// - 左侧1/3：上一页
  /// - 中间1/3：菜单
  /// - 右侧1/3：下一页
  ///
  /// 参数:
  /// - tapX: 点击位置的X坐标
  /// - screenWidth: 屏幕宽度
  ///
  /// 返回:
  /// - TapZoneAction
  static TapZoneAction getActionByPosition(
    double tapX,
    double screenWidth,
  ) {
    // 计算点击位置所在的区域（0=左，1=中，2=右）
    final zone = (tapX / (screenWidth / 3)).floor().clamp(0, 2);

    switch (zone) {
      case 0:
        return TapZoneAction.prev; // 左侧区域 - 上一页
      case 1:
        return TapZoneAction.menu; // 中间区域 - 菜单
      case 2:
        return TapZoneAction.next; // 右侧区域 - 下一页
      default:
        return TapZoneAction.menu;
    }
  }
}
