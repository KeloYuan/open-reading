import 'package:flutter/material.dart';

import '../../utils/localization_extension.dart';

/// 首页“今日速览”双卡（今日/累计）。
class HomeMobileSummaryGridWidget extends StatelessWidget {
  final Map<String, int> summaryStats;
  final int bookCount;
  final double cardSpacing;
  final VoidCallback onOpenDetailedStats;

  const HomeMobileSummaryGridWidget({
    super.key,
    required this.summaryStats,
    required this.bookCount,
    required this.cardSpacing,
    required this.onOpenDetailedStats,
  });

  @override
  Widget build(BuildContext context) {
    final totalMinutes = (summaryStats['total'] ?? 0) ~/ 60;
    final todayMinutes = (summaryStats['today'] ?? 0) ~/ 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今日速览',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
        ),
        SizedBox(height: cardSpacing * 0.8),
        Row(
          children: [
            Expanded(
              child: _HomeOverviewCard(
                value: '$todayMinutes',
                label: '${context.l10n.todayReading}（${context.l10n.unitMinute}）',
                onTap: onOpenDetailedStats,
              ),
            ),
            SizedBox(width: cardSpacing),
            Expanded(
              child: _HomeOverviewCard(
                value: '$totalMinutes',
                label: '${context.l10n.homeTotalReading}（${context.l10n.unitMinute}）',
                onTap: onOpenDetailedStats,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HomeOverviewCard extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback onTap;

  const _HomeOverviewCard({
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
