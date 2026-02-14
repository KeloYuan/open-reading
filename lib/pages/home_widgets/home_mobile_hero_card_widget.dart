import 'dart:ui';

import 'package:flutter/material.dart';
import '../../utils/localization_extension.dart';
import '../../widgets/app_brand_icon.dart';

/// 手机首页顶部欢迎卡片。
///
/// 输入当天/本周/累计统计和书架数量，输出整张视觉卡片。
class HomeMobileHeroCardWidget extends StatelessWidget {
  final Map<String, int> summaryStats;
  final int bookCount;

  const HomeMobileHeroCardWidget({
    super.key,
    required this.summaryStats,
    required this.bookCount,
  });

  @override
  Widget build(BuildContext context) {
    final totalMinutes = (summaryStats['total'] ?? 0) ~/ 60;
    final todayMinutes = (summaryStats['today'] ?? 0) ~/ 60;
    final weekMinutes = (summaryStats['week'] ?? 0) ~/ 60;
    final totalHours = totalMinutes / 60;
    final totalValue =
        totalHours >= 1 ? totalHours.toStringAsFixed(1) : '$totalMinutes';
    final totalUnit =
        totalHours >= 1 ? context.l10n.unitHour : context.l10n.unitMinute;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withValues(alpha: 0.16),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AppBrandIcon(
                      size: 22,
                      borderRadius: 6,
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.homeTodayReadingMoment,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          todayMinutes > 0
                              ? context.l10n.homeReadMinutesKeepGoing(
                                  todayMinutes,
                                )
                              : context.l10n.homeTodayReadingPrompt,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$todayMinutes',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      context.l10n.unitMinute,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HomeMobileStatChip(
                    label: context.l10n.homeWeeklyReading,
                    value: '$weekMinutes',
                    unit: context.l10n.unitMinute,
                    icon: Icons.calendar_view_week,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  _HomeMobileStatChip(
                    label: context.l10n.homeTotalReading,
                    value: totalValue,
                    unit: totalUnit,
                    icon: Icons.emoji_events,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  _HomeMobileStatChip(
                    label: context.l10n.homeLibraryCount,
                    value: '$bookCount',
                    unit: context.l10n.unitBook,
                    icon: Icons.library_books,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeMobileStatChip extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _HomeMobileStatChip({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '$value $unit',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
