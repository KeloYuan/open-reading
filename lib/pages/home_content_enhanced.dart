import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui';
import '../services/book_dao.dart';
import '../services/reading_stats_dao.dart';
import '../utils/color_extensions.dart';
import '../utils/glass_config.dart';
import 'detailed_stats_page.dart';

class HomeContentEnhanced extends StatefulWidget {
  const HomeContentEnhanced({super.key});

  @override
  State<HomeContentEnhanced> createState() => _HomeContentEnhancedState();
}

class _HomeContentEnhancedState extends State<HomeContentEnhanced> {
  final _statsDao = ReadingStatsDao();
  final _bookDao = BookDao();
  Map<String, int> _summaryStats = {};
  List<Map<String, dynamic>> _weeklyData = [];
  Map<String, dynamic> _achievementStats = {};
  int _bookCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllStats();
  }

  Future<void> _loadAllStats() async {
    setState(() => _isLoading = true);
    try {
      final summary = await _statsDao.getSummaryStats();
      final weekly = await _statsDao.getWeeklyChartData();
      final achievements = await _statsDao.getAchievementStats();
      final bookCount = await _bookDao.getBooksCount();

      setState(() {
        _summaryStats = summary;
        _weeklyData = weekly;
        _achievementStats = achievements;
        _bookCount = bookCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // 错误处理 - 静默处理，不影响用户体验
      debugPrint('Error loading stats: $e');
    }
  }

  // 导航到详细统计页面
  void _navigateToDetailedStats(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DetailedStatsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          '阅读统计',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: GlassEffectConfig.createProgressiveAppBar(
          context: context,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withOpacityValues(0.2),
                  width: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
            colors: [
              Theme.of(
                context,
              ).colorScheme.primaryContainer.withOpacityValues(0.15),
              Theme.of(
                context,
              ).colorScheme.secondaryContainer.withOpacityValues(0.08),
              Theme.of(
                context,
              ).colorScheme.tertiaryContainer.withOpacityValues(0.12),
              Theme.of(
                context,
              ).colorScheme.primaryContainer.withOpacityValues(0.06),
              Theme.of(context).colorScheme.surface.withOpacityValues(0.95),
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAllStats,
                child: SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    children: [
                      _buildWelcomeCard(),
                      const SizedBox(height: 20),
                      _buildSummaryCards(),
                      const SizedBox(height: 24),
                      _buildWeeklyChartCard(),
                      const SizedBox(height: 24),
                      _buildRecentActivity(),
                      const SizedBox(height: 40), // 底部留白
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final totalMinutes = (_summaryStats['total'] ?? 0) ~/ 60;
    final todayMinutes = (_summaryStats['today'] ?? 0) ~/ 60;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacityValues(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withOpacityValues(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacityValues(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_stories,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '今日阅读时光',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          todayMinutes > 0
                              ? '已阅读 $todayMinutes 分钟，继续保持！'
                              : '开始今天的阅读之旅吧',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacityValues(0.7),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (totalMinutes > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withOpacityValues(0.4),
                        Theme.of(
                          context,
                        ).colorScheme.secondaryContainer.withOpacityValues(0.3),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacityValues(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.emoji_events,
                          color: Theme.of(context).colorScheme.primary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '累计阅读 ${(totalMinutes / 60).toStringAsFixed(1)} 小时',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalMinutes = (_summaryStats['total'] ?? 0) ~/ 60;
    final todayMinutes = (_summaryStats['today'] ?? 0) ~/ 60;
    final weekMinutes = (_summaryStats['week'] ?? 0) ~/ 60;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 400;
        return isNarrow
            ? _buildNarrowLayout(todayMinutes, weekMinutes, totalMinutes)
            : _buildWideLayout(todayMinutes, weekMinutes, totalMinutes);
      },
    );
  }

  Widget _buildNarrowLayout(
    int todayMinutes,
    int weekMinutes,
    int totalMinutes,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: '今日阅读',
                value: '$todayMinutes',
                unit: '分钟',
                icon: Icons.today,
                color: Colors.blue,
                onTap: () => _navigateToDetailedStats(context), // 跳转到详细统计
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: '本周阅读',
                value: '$weekMinutes',
                unit: '分钟',
                icon: Icons.calendar_view_week,
                color: Colors.orange,
                onTap: () => _navigateToDetailedStats(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: '累计阅读',
                value: '$totalMinutes',
                unit: '分钟',
                icon: Icons.history,
                color: Colors.green,
                onTap: () => _navigateToDetailedStats(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: '书架藏书',
                value: '$_bookCount',
                unit: '本',
                icon: Icons.book,
                color: Colors.purple,
                onTap: () => _navigateToDetailedStats(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWideLayout(int todayMinutes, int weekMinutes, int totalMinutes) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _StatCard(
          title: '今日阅读',
          value: '$todayMinutes',
          unit: '分钟',
          icon: Icons.today,
          color: Colors.blue,
          onTap: () => _navigateToDetailedStats(context),
        ),
        _StatCard(
          title: '本周阅读',
          value: '$weekMinutes',
          unit: '分钟',
          icon: Icons.calendar_view_week,
          color: Colors.orange,
          onTap: () => _navigateToDetailedStats(context),
        ),
        _StatCard(
          title: '累计阅读',
          value: '$totalMinutes',
          unit: '分钟',
          icon: Icons.history,
          color: Colors.green,
          onTap: () => _navigateToDetailedStats(context),
        ),
        _StatCard(
          title: '书架藏书',
          value: '$_bookCount',
          unit: '本',
          icon: Icons.book,
          color: Colors.purple,
          onTap: () => _navigateToDetailedStats(context),
        ),
      ],
    );
  }

  Widget _buildWeeklyChartCard() {
    if (_weeklyData.isEmpty) {
      return Container();
    }

    final maxY =
        (_weeklyData
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
            color: Theme.of(context).colorScheme.surface.withOpacityValues(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withOpacityValues(0.2),
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
                      ).colorScheme.secondary.withOpacityValues(0.1),
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
                    '本周阅读趋势',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 200,
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
                            '${rod.toY.toInt()} 分钟',
                            TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onInverseSurface,
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
                          getTitlesWidget: _getBottomTitles,
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
                          ).colorScheme.outline.withOpacityValues(0.1),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: _weeklyData.map((data) {
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
                                ).colorScheme.primary.withOpacityValues(0.8),
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

  Widget _buildRecentActivity() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacityValues(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withOpacityValues(0.2),
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
                      ).colorScheme.tertiary.withOpacityValues(0.1),
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
                    '阅读成就',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildAchievementItem(
                icon: Icons.local_fire_department,
                title: '连续阅读',
                description: '保持每日阅读习惯',
                value: '${_achievementStats['consecutiveDays'] ?? 0} 天',
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildAchievementItem(
                icon: Icons.timer,
                title: '专注时长',
                description: '单次最长阅读时间',
                value: '${_achievementStats['maxSessionMinutes'] ?? 0} 分钟',
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              _buildAchievementItem(
                icon: Icons.trending_up,
                title: '本周总计',
                description: '本周阅读时长',
                value: '${((_summaryStats['week'] ?? 0) / 60).round()} 分钟',
                color: Colors.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementItem({
    required IconData icon,
    required String title,
    required String description,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacityValues(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacityValues(0.2),
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
                    ).colorScheme.onSurface.withOpacityValues(0.6),
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

  Widget _getBottomTitles(double value, TitleMeta meta) {
    const style = TextStyle(fontSize: 10);
    String text;
    switch (value.toInt()) {
      case 1:
        text = '一';
        break;
      case 2:
        text = '二';
        break;
      case 3:
        text = '三';
        break;
      case 4:
        text = '四';
        break;
      case 5:
        text = '五';
        break;
      case 6:
        text = '六';
        break;
      case 7:
        text = '日';
        break;
      default:
        text = '';
    }
    return SideTitleWidget(
      meta: meta,
      space: 4.0,
      child: Text(text, style: style),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap; // 新增点击回调

  const _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.onTap, // 可选的点击事件
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, // 添加点击事件
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withOpacityValues(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withOpacityValues(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacityValues(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 22, color: color),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacityValues(0.8),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              value,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              unit,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacityValues(0.6),
                                    fontSize: 10,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ), // GestureDetector
    );
  }
}
