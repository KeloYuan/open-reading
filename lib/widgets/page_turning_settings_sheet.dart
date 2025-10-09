import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/reader_providers.dart';
import 'tap_zone_diagram.dart';

/// 翻页方式设置页面
///
/// 包含：
/// - 翻页模式选择（滑动/滚动/仿真）
/// - 点击区域配置
class PageTurningSettingsSheet extends ConsumerWidget {
  const PageTurningSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final settingsNotifier = ref.read(readerSettingsProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
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
                      Icons.auto_stories_rounded,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '翻页方式',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 翻页模式选择
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '翻页模式',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: PaginationMode.values.map((mode) {
                        final isSelected = settings.paginationMode == mode;
                        return _buildModeChip(
                          context,
                          mode,
                          isSelected,
                          () => settingsNotifier.switchPaginationMode(mode),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 点击区域配置
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '点击翻页区域',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      settings.tapTurningPattern.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 当前方案预览（固定为默认方案）
                    Center(
                      child: TapZoneDiagram(
                        pattern: settings.tapTurningPattern,
                        isSelected: true,
                        size: 150,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        settings.tapTurningPattern.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建模式选择芯片
  Widget _buildModeChip(
    BuildContext context,
    PaginationMode mode,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    IconData icon;
    String label;

    switch (mode) {
      case PaginationMode.cover:
        icon = Icons.layers_rounded;
        label = '覆盖翻页';
        break;
      case PaginationMode.slide:
        icon = Icons.swipe_rounded;
        label = '左右滑动';
        break;
      case PaginationMode.scroll:
        icon = Icons.swap_vert_rounded;
        label = '上下滚动';
        break;
      case PaginationMode.simulation:
        icon = Icons.auto_stories;
        label = '仿真翻页';
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.primaryColor
                : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? theme.primaryColor.withValues(alpha: 0.1) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? theme.primaryColor
                  : theme.iconTheme.color?.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? theme.primaryColor : null,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: theme.primaryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 显示翻页方式设置页面
Future<void> showPageTurningSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const PageTurningSettingsSheet(),
  );
}
