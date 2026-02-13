import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../utils/localization_extension.dart';

/// 首页本周趋势图卡片。
class HomeWeeklyChartCardWidget extends StatelessWidget {
  final List<Map<String, dynamic>> weeklyData;
  final double chartHeight;

  const HomeWeeklyChartCardWidget({
    super.key,
    required this.weeklyData,
    required this.chartHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (weeklyData.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxY = (weeklyData
                .map((d) => d['duration'] as int)
                .reduce((a, b) => a > b ? a : b) /
            60) +
        10;

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
                      ).colorScheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.analytics_outlined,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.homeWeeklyTrend,
                    style: Theme.of(
                      context,
                    )
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: chartHeight,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY > 10 ? maxY : 10,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) =>
                            Theme.of(context).colorScheme.inverseSurface,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            context.l10n.homeBarTooltipMinutes(
                              rod.toY.toInt(),
                            ),
                            TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onInverseSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) =>
                              _getBottomTitles(context, value, meta),
                          reservedSize: 22,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}',
                              style: Theme.of(context).textTheme.bodySmall,
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 10,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.1),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: weeklyData.map((data) {
                      return BarChartGroupData(
                        x: data['day'],
                        barRods: [
                          BarChartRodData(
                            toY: (data['duration'] as int) / 60,
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.8),
                                Theme.of(context).colorScheme.primary,
                              ],
                            ),
                            width: 20,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              topRight: Radius.circular(6),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getBottomTitles(BuildContext context, double value, TitleMeta meta) {
    const style = TextStyle(fontSize: 10);
    String text;
    switch (value.toInt()) {
      case 1:
        text = context.l10n.weekdayMonShort;
        break;
      case 2:
        text = context.l10n.weekdayTueShort;
        break;
      case 3:
        text = context.l10n.weekdayWedShort;
        break;
      case 4:
        text = context.l10n.weekdayThuShort;
        break;
      case 5:
        text = context.l10n.weekdayFriShort;
        break;
      case 6:
        text = context.l10n.weekdaySatShort;
        break;
      case 7:
        text = context.l10n.weekdaySunShort;
        break;
      default:
        text = '';
    }
    return SideTitleWidget(
      axisSide: AxisSide.bottom,
      space: 4.0,
      child: Text(text, style: style),
    );
  }
}
