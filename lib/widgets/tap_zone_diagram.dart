import 'package:flutter/material.dart';
import '../models/page_turning_config.dart';

/// 点击区域可视化组件
///
/// 显示3x3网格，展示每个区域的翻页动作
class TapZoneDiagram extends StatelessWidget {
  final TapTurningPattern pattern;
  final bool isSelected;
  final VoidCallback? onTap;
  final double size;

  const TapZoneDiagram({
    super.key,
    required this.pattern,
    this.isSelected = false,
    this.onTap,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2.5 : 1.5,
          ),
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // 左区域：上一页
            Expanded(
              child: _buildZoneCell(context, TapZoneAction.prev, 0),
            ),
            const SizedBox(width: 2),
            // 中区域：菜单
            Expanded(
              child: _buildZoneCell(context, TapZoneAction.menu, 1),
            ),
            const SizedBox(width: 2),
            // 右区域：下一页
            Expanded(
              child: _buildZoneCell(context, TapZoneAction.next, 2),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建单个区域格子
  Widget _buildZoneCell(BuildContext context, TapZoneAction action, int index) {
    Color backgroundColor;
    IconData icon;
    Color iconColor;

    switch (action) {
      case TapZoneAction.next:
        backgroundColor = Colors.red.withValues(alpha: 0.15);
        icon = Icons.arrow_forward_rounded;
        iconColor = Colors.red;
        break;
      case TapZoneAction.prev:
        backgroundColor = Colors.blue.withValues(alpha: 0.15);
        icon = Icons.arrow_back_rounded;
        iconColor = Colors.blue;
        break;
      case TapZoneAction.menu:
        backgroundColor = Colors.green.withValues(alpha: 0.15);
        icon = Icons.menu_rounded;
        iconColor = Colors.green;
        break;
    }

    // 只在关键位置显示图标
    final shouldShowIcon = _shouldShowIcon(index, action);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: shouldShowIcon
          ? Center(
              child: Icon(
                icon,
                size: size / 10,
                color: iconColor.withValues(alpha: 0.8),
              ),
            )
          : null,
    );
  }

  /// 判断是否应该显示图标
  bool _shouldShowIcon(int index, TapZoneAction action) {
    // 中心格子
    if (index == 4) return true;

    // 左中格子 - 如果是上一页
    if (index == 3 && action == TapZoneAction.prev) return true;

    // 右中格子 - 如果是下一页
    if (index == 5 && action == TapZoneAction.next) return true;

    return false;
  }
}

/// 点击区域设置页面
class TapZoneSettingsSheet extends StatefulWidget {
  final int currentPatternIndex;

  const TapZoneSettingsSheet({
    super.key,
    required this.currentPatternIndex,
  });

  @override
  State<TapZoneSettingsSheet> createState() => _TapZoneSettingsSheetState();
}

class _TapZoneSettingsSheetState extends State<TapZoneSettingsSheet> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.currentPatternIndex;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽指示器
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 标题
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '点击翻页区域',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context, _selectedIndex),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 说明文字
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  _buildLegend(context, '下一页', Colors.red),
                  const SizedBox(width: 16),
                  _buildLegend(context, '上一页', Colors.blue),
                  const SizedBox(width: 16),
                  _buildLegend(context, '菜单', Colors.green),
                ],
              ),
            ),

            // 方案列表
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: 1, // 只显示默认方案
                itemBuilder: (context, index) {
                  final pattern = TapTurningPattern.defaultPattern;
                  final isSelected = index == _selectedIndex;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? theme.primaryColor
                                : Colors.grey.withValues(alpha: 0.2),
                            width: isSelected ? 2 : 1,
                          ),
                          color: isSelected
                              ? theme.primaryColor.withValues(alpha: 0.05)
                              : null,
                        ),
                        child: Row(
                          children: [
                            // 可视化图
                            TapZoneDiagram(
                              pattern: pattern,
                              isSelected: isSelected,
                              size: 90,
                            ),
                            const SizedBox(width: 16),
                            // 文字说明
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pattern.name,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? theme.primaryColor
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    pattern.description,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.textTheme.bodySmall?.color
                                          ?.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 选中图标
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: theme.primaryColor,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 构建图例
  Widget _buildLegend(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// 显示点击区域设置页面
Future<int?> showTapZoneSettingsSheet(
  BuildContext context,
  int currentPatternIndex,
) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => TapZoneSettingsSheet(
      currentPatternIndex: currentPatternIndex,
    ),
  );
}
