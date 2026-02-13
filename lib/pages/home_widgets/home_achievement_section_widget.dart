import 'dart:ui';

import 'package:flutter/material.dart';
import '../../utils/localization_extension.dart';

/// 首页阅读成就区。
class HomeAchievementSectionWidget extends StatelessWidget {
  final Map<String, dynamic> achievementStats;
  final Map<String, int> summaryStats;

  const HomeAchievementSectionWidget({
    super.key,
    required this.achievementStats,
    required this.summaryStats,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.tertiary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.schedule,
                      color: Theme.of(context).colorScheme.tertiary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.homeAchievements,
                    style: Theme.of(
                      context,
                    )
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _AchievementItem(
                icon: Icons.local_fire_department,
                title: context.l10n.homeConsecutiveReading,
                description: context.l10n.homeConsecutiveReadingDesc,
                value:
                    '${achievementStats['consecutiveDays'] ?? 0} ${context.l10n.unitDay}',
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              _AchievementItem(
                icon: Icons.timer,
                title: context.l10n.homeFocusDuration,
                description: context.l10n.homeFocusDurationDesc,
                value:
                    '${achievementStats['maxSessionMinutes'] ?? 0} ${context.l10n.unitMinute}',
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              _AchievementItem(
                icon: Icons.trending_up,
                title: context.l10n.homeWeeklyTotal,
                description: context.l10n.homeWeeklyTotalDesc,
                value:
                    '${((summaryStats['week'] ?? 0) / 60).round()} ${context.l10n.unitMinute}',
                color: Colors.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String value;
  final Color color;

  const _AchievementItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}
