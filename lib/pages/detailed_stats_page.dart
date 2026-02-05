import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/reading_stats_dao.dart';
import '../services/book_dao.dart';
import '../utils/glass_config.dart';
import '../models/book.dart';

// 超级详细的阅读统计页面
class DetailedStatsPage extends StatefulWidget {
  const DetailedStatsPage({super.key});

  @override
  State<DetailedStatsPage> createState() => _DetailedStatsPageState();
}

class _DetailedStatsPageState extends State<DetailedStatsPage>
    with TickerProviderStateMixin {
  final _statsDao = ReadingStatsDao();
  final _bookDao = BookDao();

  late TabController _tabController;
  late PageController _pageController;

  // 统计数据
  Map<String, int> _overallStats = {};
  List<Map<String, dynamic>> _dailyStats = [];
  // List<Map<String, dynamic>> _weeklyStats = [];
  // List<Map<String, dynamic>> _monthlyStats = [];
  List<Map<String, dynamic>> _bookStats = [];
  List<Book> _recentBooks = [];
  Map<int, int> _hourlyDistribution = {}; // 每小时阅读分布
  Map<String, double> _heatmapData = {}; // 热力图数据

  // UI状态
  bool _isLoading = true;
  String _selectedTimeRange = '7天';
  int _selectedStatType = 0; // 0: 时长, 1: 页数, 2: 书籍数

  // 根据选择的时间范围获取窗口化的每日数据
  List<Map<String, dynamic>> get _windowedDailyStats {
    int days;
    switch (_selectedTimeRange) {
      case '7天':
        days = 7;
        break;
      case '30天':
        days = 30;
        break;
      case '90天':
        days = 90;
        break;
      case '1年':
        days = 365;
        break;
      default:
        days = _dailyStats.length;
    }
    if (_dailyStats.isEmpty) return const [];
    return _dailyStats.length <= days
        ? _dailyStats
        : _dailyStats.sublist(_dailyStats.length - days);
  }

  // 平均阅读速度：页/分钟（基于窗口化数据）
  double get _averagePagesPerMinute {
    final data = _windowedDailyStats;
    if (data.isEmpty) return 0;
    final totalPages = data.fold<int>(
      0,
      (sum, e) => sum + ((e['pagesRead'] as int?) ?? 0),
    );
    final totalMinutes = data.fold<int>(
      0,
      (sum, e) => sum + ((e['readingTime'] as int?) ?? 0),
    );
    if (totalMinutes == 0) return 0;
    return totalPages / totalMinutes;
  }

  // 平均单次阅读时长（以有阅读的天为“次”近似）
  String get _avgSessionDurationLabel {
    final data = _windowedDailyStats;
    if (data.isEmpty) return '0 分钟';
    final daysWithReading =
        data.where((e) => ((e['readingTime'] as int?) ?? 0) > 0).length;
    if (daysWithReading == 0) return '0 分钟';
    final totalMinutes = data.fold<int>(
      0,
      (sum, e) => sum + ((e['readingTime'] as int?) ?? 0),
    );
    final avg = (totalMinutes / daysWithReading).round();
    return '$avg 分钟';
  }

  // 最高连读天数
  String get _maxStreakLabel {
    final streak = _overallStats['streak'] ?? 0;
    if (streak > 0) return '$streak 天';
    int best = 0, cur = 0;
    for (final e in _windowedDailyStats) {
      if (((e['readingTime'] as int?) ?? 0) > 0) {
        cur++;
        if (cur > best) best = cur;
      } else {
        cur = 0;
      }
    }
    return '$best 天';
  }

  // 阅读专注度（相对60分钟目标的达成度）
  String get _focusScoreLabel {
    final data = _windowedDailyStats;
    if (data.isEmpty) return '0%';
    final totalMinutes = data.fold<int>(
      0,
      (sum, e) => sum + ((e['readingTime'] as int?) ?? 0),
    );
    final avg = data.isEmpty ? 0.0 : totalMinutes / data.length;
    final score = (avg / 60.0).clamp(0.0, 1.0) * 100.0;
    return '${score.round()}%';
  }

  String _inferBestReadingPeriod() {
    // TODO: 当有小时粒度数据时，统计分布后给出时间段；当前返回占位
    return '--';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _pageController = PageController();

    // 监听TabController变化，同步PageController
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _pageController.animateToPage(
          _tabController.index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });

    _loadAllStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAllStats() async {
    setState(() => _isLoading = true);
    try {
      // 并行加载所有统计数据
      await Future.wait([
        _loadOverallStats(),
        _loadDailyStats(),
        // _loadWeeklyStats(),
        // _loadMonthlyStats(),
        _loadBookStats(),
        _loadRecentBooks(),
        _loadHourlyDistribution(),
        _loadHeatmapData(),
      ]);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHourlyDistribution() async {
    final distribution = await _statsDao.getHourlyReadingDistribution();
    setState(() => _hourlyDistribution = distribution);
  }

  Future<void> _loadHeatmapData() async {
    final heatmap = await _statsDao.getReadingIntensityHeatmap();
    setState(() => _heatmapData = heatmap);
  }

  Future<void> _loadOverallStats() async {
    // 使用真实的数据库查询
    final summaryStats = await _statsDao.getSummaryStats();
    final achievementStats = await _statsDao.getAchievementStats();
    final bookCount = await _bookDao.getBooksCount();

    final totalMinutes = (summaryStats['total'] ?? 0) ~/ 60;

    // 计算总页数 - 基于所有书籍的currentPage总和
    final books = await _bookDao.getAllBooks();
    final totalPages = books.fold<int>(
      0,
      (sum, book) => sum + book.currentPage,
    );

    setState(
      () => _overallStats = {
        'totalReadingTime': totalMinutes,
        'totalPages': totalPages, // 真实数据：所有书籍已读页数总和
        'totalBooks': bookCount, // 真实数据：书架中的书籍总数
        'streak': achievementStats['consecutiveDays'] ?? 0, // 真实数据：连续阅读天数
      },
    );
  }

  Future<void> _loadDailyStats() async {
    // 使用真实的每日统计数据
    final endDate = DateTime.now();
    // 统一加载最近一年数据，便于切换窗口
    final startDate = endDate.subtract(const Duration(days: 365));

    final realDailyStats = await _statsDao.getDailyStatsRange(
      startDate,
      endDate,
    );

    // 构建完整的日期数据，没有数据的日期填充为0
    final dailyStatsMap = <String, Map<String, dynamic>>{};

    // 先填充真实数据
    for (final stat in realDailyStats) {
      final dateStr = stat['date'] as String;
      dailyStatsMap[dateStr] = {
        'date': dateStr,
        'readingTime': (stat['duration'] ?? 0) ~/ 60, // 转换为分钟
        'pagesRead': stat['pages'] ?? 0,
        'booksRead': stat['books_read'] ?? 0,
      };
    }

    // 填充空白日期（最近一年）
    final completeStats = <Map<String, dynamic>>[];
    for (int i = 364; i >= 0; i--) {
      final date = endDate.subtract(Duration(days: i));
      final dateStr = date.toIso8601String().split('T').first;

      completeStats.add(
        dailyStatsMap[dateStr] ??
            {'date': dateStr, 'readingTime': 0, 'pagesRead': 0, 'booksRead': 0},
      );
    }

    setState(() => _dailyStats = completeStats);
  }

  /*
  Future<void> _loadWeeklyStats() async {
    // 使用模拟数据
    setState(() => _weeklyStats = List.generate(12, (index) => {
      'week': index + 1,
      'readingTime': 30 + (index * 5),
      'pagesRead': 50 + (index * 10),
    }));
  }

  Future<void> _loadMonthlyStats() async {
    // 使用模拟数据
    setState(() => _monthlyStats = List.generate(12, (index) => {
      'month': index + 1,
      'readingTime': 120 + (index * 20),
      'pagesRead': 200 + (index * 30),
    }));
  }
  */

  Future<void> _loadBookStats() async {
    final books = await _bookDao.getAllBooks();
    final bookStats = <Map<String, dynamic>>[];

    for (final book in books) {
      // 基于真实阅读进度计算统计数据
      final progress =
          book.totalPages > 0 ? book.currentPage / book.totalPages : 0.0;

      // 根据书籍阅读进度和估算阅读速度计算阅读时间
      // 假设平均阅读速度为每页2分钟，根据已读页数计算
      final estimatedReadingTime = book.currentPage * 2; // 每页2分钟

      bookStats.add({
        'book': book,
        'readingTime': estimatedReadingTime, // 基于已读页数的估算时间
        'progress': progress,
        'pagesRead': book.currentPage, // 真实已读页数
        'totalPages': book.totalPages, // 真实总页数
      });
    }

    // 按阅读时间排序
    bookStats.sort(
      (a, b) => (b['readingTime'] as int).compareTo(a['readingTime'] as int),
    );
    setState(() => _bookStats = bookStats);
  }

  Future<void> _loadRecentBooks() async {
    final books = await _bookDao.getAllBooks();
    // 取前5本书作为最近阅读
    setState(() => _recentBooks = books.take(5).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0, // 设置高度为0，让毛玻璃标题栏在body中实现
      ),
      // 渐变背景
      body: Stack(
        children: [
          // 主内容区域
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.1),
                  Theme.of(
                    context,
                  ).colorScheme.secondaryContainer.withValues(alpha: 0.1),
                  Theme.of(
                    context,
                  ).colorScheme.tertiaryContainer.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      _tabController.animateTo(index);
                    },
                    children: [
                      _buildOverviewTab(),
                      _buildChartsTab(),
                      _buildBooksTab(),
                      _buildAchievementsTab(),
                    ],
                  ),
          ),
          // 毛玻璃AppBar - 使用与首页相同的实现方式
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: GlassEffectConfig.appBarBlur,
                  sigmaY: GlassEffectConfig.appBarBlur,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(
                          alpha: GlassEffectConfig.appBarOpacity,
                        ),
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // 自适应高度
                    children: [
                      // 标题栏部分
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          MediaQuery.of(context).padding.top + 8,
                          16,
                          8,
                        ),
                        child: Row(
                          children: [
                            // 返回按钮
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () => Navigator.of(context).pop(),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 24,
                            ),
                            const SizedBox(width: 16),
                            // 标题
                            Expanded(
                              child: Text(
                                '阅读统计详情',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            // 时间范围选择
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    )
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      )
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: PopupMenuButton<String>(
                                    initialValue: _selectedTimeRange,
                                    onSelected: (value) {
                                      setState(
                                          () => _selectedTimeRange = value);
                                      _loadAllStats();
                                    },
                                    icon: Icon(
                                      Icons.date_range,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      size: 20,
                                    ),
                                    itemBuilder: (context) =>
                                        ['7天', '30天', '90天', '1年', '全部']
                                            .map(
                                              (range) => PopupMenuItem(
                                                  value: range,
                                                  child: Text(range)),
                                            )
                                            .toList(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // TabBar部分
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border(
                            top: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.1),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          tabs: const [
                            Tab(text: '总览'),
                            Tab(text: '图表'),
                            Tab(text: '书籍'),
                            Tab(text: '成就'),
                          ],
                          labelColor: Theme.of(context).colorScheme.primary,
                          unselectedLabelColor: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                          indicatorColor: Theme.of(context).colorScheme.primary,
                          indicatorWeight: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 总览标签页
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top +
            120, // 状态栏高度 + AppBar + TabBar + 间距
        16,
        20,
      ),
      child: Column(
        children: [
          // 核心统计卡片网格
          _buildStatsGrid(),
          const SizedBox(height: 20),

          // 今日阅读进度
          _buildTodayProgress(),
          const SizedBox(height: 20),

          // 最近阅读书籍
          _buildRecentBooks(),
          const SizedBox(height: 20),

          // 阅读习惯分析
          _buildReadingHabits(),
        ],
      ),
    );
  }

  // 核心统计网格
  Widget _buildStatsGrid() {
    final stats = [
      {
        'title': '总阅读时长',
        'value': '${_overallStats['totalReadingTime'] ?? 0}',
        'unit': '分钟',
        'icon': Icons.schedule_rounded,
        'gradient': [const Color(0xFF667EEA), const Color(0xFF764BA2)], // 紫蓝渐变
      },
      {
        'title': '总阅读页数',
        'value': '${_overallStats['totalPages'] ?? 0}',
        'unit': '页',
        'icon': Icons.auto_stories_rounded,
        'gradient': [const Color(0xFF06B6D4), const Color(0xFF3B82F6)], // 青蓝渐变
      },
      {
        'title': '阅读书籍数',
        'value': '${_overallStats['totalBooks'] ?? 0}',
        'unit': '本',
        'icon': Icons.library_books_rounded,
        'gradient': [const Color(0xFFF59E0B), const Color(0xFFEF4444)], // 橙红渐变
      },
      {
        'title': '连续阅读',
        'value': '${_overallStats['streak'] ?? 0}',
        'unit': '天',
        'icon': Icons.local_fire_department_rounded,
        'gradient': [const Color(0xFFEC4899), const Color(0xFF8B5CF6)], // 粉紫渐变
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0, // 调整为1:1比例，给卡片更多高度
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return _buildStatCard(stat);
      },
    );
  }

  // 统计卡片 - 现代化重新设计
  Widget _buildStatCard(Map<String, dynamic> stat) {
    final gradient = stat['gradient'] as List<Color>;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 图标容器 - 使用发光效果
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    stat['icon'] as IconData,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                // 数值 - 大字体显示
                Text(
                  stat['value'] as String,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.0,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // 单位和标题组合
                Row(
                  children: [
                    Text(
                      stat['unit'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        stat['title'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 今日阅读进度
  Widget _buildTodayProgress() {
    // 查找今日数据（最后一个元素应该是今天）
    final todayData = _dailyStats.isNotEmpty
        ? _dailyStats.last
        : {'readingTime': 0, 'pagesRead': 0};
    final todayTime = todayData['readingTime'] ?? 0;
    final todayPages = todayData['pagesRead'] ?? 0;
    const int targetTime = 60; // 目标60分钟
    const int targetPages = 20; // 目标20页

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassEffectConfig.cardBlur,
          sigmaY: GlassEffectConfig.cardBlur,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(
                  alpha: GlassEffectConfig.cardOpacity,
                ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.1),
                Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withValues(alpha: 0.1),
              ],
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF667EEA).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.today_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '今日阅读进度',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 时间进度
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '阅读时长',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              '$todayTime / $targetTime 分钟',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (todayTime / targetTime).clamp(0.0, 1.0),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 页数进度
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '阅读页数',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              '$todayPages / $targetPages 页',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (todayPages / targetPages).clamp(0.0, 1.0),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation(
                            Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 最近阅读书籍
  Widget _buildRecentBooks() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassEffectConfig.cardBlur,
          sigmaY: GlassEffectConfig.cardBlur,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(
                  alpha: GlassEffectConfig.cardOpacity,
                ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '最近阅读',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._recentBooks.map((book) {
                final progress = book.totalPages > 0
                    ? book.currentPage / book.totalPages
                    : 0.0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      // 显示真实封面或默认图标
                      _buildBookCoverWidget(book, 40, 56),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // 阅读习惯分析
  Widget _buildReadingHabits() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassEffectConfig.cardBlur,
          sigmaY: GlassEffectConfig.cardBlur,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(
                  alpha: GlassEffectConfig.cardOpacity,
                ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '阅读习惯分析',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildHabitItem(
                '最佳阅读时段',
                _inferBestReadingPeriod(),
                Icons.access_time,
              ),
              _buildHabitItem('平均单次阅读', _avgSessionDurationLabel, Icons.timer),
              _buildHabitItem(
                '最高连读天数',
                _maxStreakLabel,
                Icons.local_fire_department,
              ),
              _buildHabitItem(
                '阅读专注度',
                _focusScoreLabel,
                Icons.center_focus_strong,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHabitItem(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }

  // 图表标签页
  Widget _buildChartsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top +
            120, // 状态栏高度 + AppBar + TabBar + 间距
        16,
        20,
      ),
      child: Column(
        children: [
          // 统计类型选择
          _buildStatTypeSelector(),
          const SizedBox(height: 20),

          // 趋势图表
          _buildTrendChart(),
          const SizedBox(height: 20),

          // 时间分布图
          _buildTimeDistributionChart(),
          const SizedBox(height: 20),

          // 书籍类型分布
          _buildGenreDistributionChart(),
          const SizedBox(height: 20),

          // 阅读目标进度
          _buildReadingGoalChart(),
          const SizedBox(height: 20),

          // 阅读速度分析
          _buildReadingSpeedChart(),
          const SizedBox(height: 20),

          // 阅读连续性热力图
          _buildReadingStreakHeatmap(),
        ],
      ),
    );
  }

  // 统计类型选择器
  Widget _buildStatTypeSelector() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _buildTypeButton('阅读时长', 0),
              _buildTypeButton('阅读页数', 1),
              _buildTypeButton('书籍数量', 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String title, int index) {
    final isSelected = _selectedStatType == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedStatType = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
          ),
        ),
      ),
    );
  }

  // 趋势图表
  Widget _buildTrendChart() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassEffectConfig.cardBlur,
          sigmaY: GlassEffectConfig.cardBlur,
        ),
        child: Container(
          height: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(
                  alpha: GlassEffectConfig.cardOpacity,
                ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '阅读趋势分析',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              Expanded(child: LineChart(_buildLineChartData())),
            ],
          ),
        ),
      ),
    );
  }

  LineChartData _buildLineChartData() {
    // 使用窗口化的每日数据
    final windowedData = _windowedDailyStats;

    if (windowedData.isEmpty) {
      return LineChartData(
        lineBarsData: [],
        titlesData: const FlTitlesData(show: false),
      );
    }

    final spots = windowedData.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final data = entry.value;
      double value = 0;
      switch (_selectedStatType) {
        case 0:
          value = (data['duration'] ?? 0).toDouble() / 60; // 转换为分钟
          break;
        case 1:
          value = (data['pages'] ?? 0).toDouble();
          break;
        case 2:
          value = (data['books_read'] ?? 0).toDouble();
          break;
      }
      return FlSpot(index, value);
    }).toList();

    // 计算最大值和合适的间隔
    final maxValue = spots.isNotEmpty
        ? spots.map((e) => e.y).reduce((a, b) => a > b ? a : b)
        : 10.0;
    final roundedMax = (maxValue * 1.2).ceilToDouble();

    // 计算Y轴间隔
    double yInterval;
    if (roundedMax <= 10) {
      yInterval = 2;
    } else if (roundedMax <= 50) {
      yInterval = 10;
    } else if (roundedMax <= 100) {
      yInterval = 20;
    } else if (roundedMax <= 500) {
      yInterval = 50;
    } else {
      yInterval = 100;
    }

    // 计算X轴间隔 - 根据数据点数量
    int xInterval;
    if (windowedData.length <= 7) {
      xInterval = 1;
    } else if (windowedData.length <= 30) {
      xInterval = 5;
    } else if (windowedData.length <= 90) {
      xInterval = 15;
    } else {
      xInterval = 30;
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: yInterval,
        verticalInterval: xInterval.toDouble(),
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
            strokeWidth: 1,
            dashArray: [5, 5],
          );
        },
        getDrawingVerticalLine: (value) {
          return FlLine(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            strokeWidth: 1,
            dashArray: [5, 5],
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        // 底部横轴 - 显示日期
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 35,
            interval: xInterval.toDouble(),
            getTitlesWidget: (double value, TitleMeta meta) {
              final index = value.toInt();
              if (index < 0 || index >= windowedData.length) {
                return const SizedBox.shrink();
              }

              // 从日期字符串提取月/日
              final dateStr = windowedData[index]['date'] as String;
              final parts = dateStr.split('-');
              if (parts.length >= 3) {
                final month = int.parse(parts[1]);
                final day = int.parse(parts[2]);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '$month/$day',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        // 左侧纵轴 - 显示数值
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: yInterval,
            getTitlesWidget: (double value, TitleMeta meta) {
              if (value == meta.max || value == meta.min) {
                return const SizedBox.shrink();
              }

              String label;
              if (_selectedStatType == 0) {
                // 阅读时长 - 分钟
                label = '${value.toInt()}分';
              } else if (_selectedStatType == 1) {
                // 阅读页数
                label = '${value.toInt()}页';
              } else {
                // 书籍数量
                label = '${value.toInt()}本';
              }

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                  textAlign: TextAlign.right,
                ),
              );
            },
            reservedSize: 48,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
          left: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      minX: 0,
      maxX: (windowedData.length - 1).toDouble(),
      minY: 0,
      maxY: roundedMax,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          gradient: const LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 3,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: const Color(0xFF667EEA),
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                const Color(0xFF667EEA).withValues(alpha: 0.3),
                const Color(0xFF764BA2).withValues(alpha: 0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }

  // 时间分布图
  Widget _buildTimeDistributionChart() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassEffectConfig.cardBlur,
          sigmaY: GlassEffectConfig.cardBlur,
        ),
        child: Container(
          height: 250,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(
                  alpha: GlassEffectConfig.cardOpacity,
                ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '阅读时间分布',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              Expanded(child: BarChart(_buildBarChartData())),
            ],
          ),
        ),
      ),
    );
  }

  BarChartData _buildBarChartData() {
    // 使用真实的每小时阅读分布数据
    final hourlyData = List.generate(24, (hour) {
      return (_hourlyDistribution[hour] ?? 0).toDouble();
    });

    // 计算最大值和合适的Y轴范围
    final maxValue = hourlyData.reduce((a, b) => a > b ? a : b);
    final roundedMax = maxValue > 0 ? (maxValue * 1.3).ceilToDouble() : 10.0;

    // 计算Y轴间隔
    double yInterval;
    if (roundedMax <= 10) {
      yInterval = 2;
    } else if (roundedMax <= 50) {
      yInterval = 10;
    } else if (roundedMax <= 100) {
      yInterval = 20;
    } else {
      yInterval = 50;
    }

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: roundedMax,
      minY: 0,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (group) =>
              const Color(0xFF667EEA).withValues(alpha: 0.9),
          tooltipRoundedRadius: 8,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            return BarTooltipItem(
              '${group.x}:00\n${rod.toY.toInt()}分钟',
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            );
          },
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: yInterval,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
            strokeWidth: 1,
            dashArray: [5, 5],
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        // 底部横轴 - 显示时间
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (double value, TitleMeta meta) {
              final hour = value.toInt();
              // 每3小时显示一次标签
              if (hour % 3 != 0) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '$hour时',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
              );
            },
            reservedSize: 32,
            interval: 1,
          ),
        ),
        // 左侧纵轴 - 显示分钟数
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: yInterval,
            getTitlesWidget: (double value, TitleMeta meta) {
              if (value == meta.max || value == 0) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  '${value.toInt()}分',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                  textAlign: TextAlign.right,
                ),
              );
            },
            reservedSize: 42,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
          left: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      barGroups: hourlyData.asMap().entries.map((entry) {
        final hour = entry.key;
        final value = entry.value;

        // 根据时间段选择不同的渐变色
        List<Color> gradient;
        if (hour >= 6 && hour < 12) {
          // 早晨 - 橙黄色
          gradient = [const Color(0xFFFBBF24), const Color(0xFFF59E0B)];
        } else if (hour >= 12 && hour < 18) {
          // 下午 - 蓝色
          gradient = [const Color(0xFF3B82F6), const Color(0xFF2563EB)];
        } else if (hour >= 18 && hour < 24) {
          // 晚上 - 紫色
          gradient = [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)];
        } else {
          // 深夜 - 深蓝色
          gradient = [const Color(0xFF1E3A8A), const Color(0xFF1E40AF)];
        }

        return BarChartGroupData(
          x: hour,
          barRods: [
            BarChartRodData(
              toY: value > 0 ? value : 0,
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              width: 10,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  // 类型分布图
  Widget _buildGenreDistributionChart() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassEffectConfig.cardBlur,
          sigmaY: GlassEffectConfig.cardBlur,
        ),
        child: Container(
          height: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(
                  alpha: GlassEffectConfig.cardOpacity,
                ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '书籍格式分布',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              Expanded(child: PieChart(_buildPieChartData())),
            ],
          ),
        ),
      ),
    );
  }

  PieChartData _buildPieChartData() {
    // 统计各种格式的书籍数量
    final formatCounts = <String, int>{};
    for (final bookStat in _bookStats) {
      final book = bookStat['book'] as Book;
      final format = book.format.toUpperCase();
      formatCounts[format] = (formatCounts[format] ?? 0) + 1;
    }

    // 如果没有数据，显示空状态
    if (formatCounts.isEmpty) {
      return PieChartData(
        sections: [
          PieChartSectionData(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            value: 1,
            title: '暂无数据',
            radius: 80,
            titleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ],
      );
    }

    // 计算总数
    final total = formatCounts.values.fold<int>(0, (sum, count) => sum + count);

    // 颜色列表
    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    // 创建饼图数据
    final sections = <PieChartSectionData>[];
    int colorIndex = 0;

    formatCounts.forEach((format, count) {
      final percentage = (count / total * 100).round();
      sections.add(
        PieChartSectionData(
          color: colors[colorIndex % colors.length],
          value: count.toDouble(),
          title: '$format\n$percentage%',
          radius: 80,
          titleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
        ),
      );
      colorIndex++;
    });

    return PieChartData(
      pieTouchData: PieTouchData(enabled: false),
      borderData: FlBorderData(show: false),
      sectionsSpace: 2,
      centerSpaceRadius: 60,
      sections: sections,
    );
  }

  // 书籍标签页
  Widget _buildBooksTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top +
            120, // 状态栏高度 + AppBar + TabBar + 间距
        16,
        20,
      ),
      child: Column(
        children: [
          // 书籍统计摘要
          _buildBooksSummary(),
          const SizedBox(height: 20),

          // 书籍排行榜
          _buildBooksRanking(),
        ],
      ),
    );
  }

  // 书籍统计摘要
  Widget _buildBooksSummary() {
    final completedBooks =
        _bookStats.where((book) => (book['progress'] as double) >= 1.0).length;
    final inProgressBooks = _bookStats
        .where(
          (book) =>
              (book['progress'] as double) > 0.0 &&
              (book['progress'] as double) < 1.0,
        )
        .length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassEffectConfig.cardBlur,
          sigmaY: GlassEffectConfig.cardBlur,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(
                  alpha: GlassEffectConfig.cardOpacity,
                ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              _buildSummaryItem(
                '已完成',
                completedBooks,
                Icons.check_circle,
                Colors.green,
              ),
              _buildSummaryItem(
                '阅读中',
                inProgressBooks,
                Icons.schedule,
                Colors.orange,
              ),
              _buildSummaryItem(
                '总计',
                _bookStats.length,
                Icons.library_books,
                Colors.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String title,
    int value,
    IconData icon,
    Color color,
  ) {
    // 根据颜色生成渐变
    final gradient = color == Colors.green
        ? [const Color(0xFF10B981), const Color(0xFF059669)]
        : color == Colors.orange
            ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
            : [const Color(0xFF3B82F6), const Color(0xFF2563EB)];

    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: gradient[0],
                ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  // 书籍排行榜
  Widget _buildBooksRanking() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassEffectConfig.cardBlur,
          sigmaY: GlassEffectConfig.cardBlur,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(
                  alpha: GlassEffectConfig.cardOpacity,
                ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '阅读时长排行',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              ..._bookStats.take(10).map((bookStat) {
                final book = bookStat['book'] as Book;
                final readingTime = bookStat['readingTime'] as int;
                final progress = bookStat['progress'] as double;
                final index = _bookStats.indexOf(bookStat) + 1;

                return _buildBookRankingItem(
                  book,
                  readingTime,
                  progress,
                  index,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookRankingItem(
    Book book,
    int readingTime,
    double progress,
    int rank,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // 排名
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: rank <= 3
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 书籍封面或图标
          _buildBookCoverWidget(book, 40, 56),
          const SizedBox(width: 12),

          // 书籍信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  book.author,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 阅读时间
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$readingTime分钟',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 成就标签页
  Widget _buildAchievementsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top +
            120, // 状态栏高度 + AppBar + TabBar + 间距
        16,
        20,
      ),
      child: Column(
        children: [
          // 成就总览
          _buildAchievementsOverview(),
          const SizedBox(height: 20),

          // 成就列表
          _buildAchievementsList(),
        ],
      ),
    );
  }

  // 成就总览
  Widget _buildAchievementsOverview() {
    // 计算已获得的成就数量（基于真实数据）
    final achievements = _getAchievementsList();
    final achievedCount =
        achievements.where((a) => a['achieved'] as bool).length;
    final totalCount = achievements.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassEffectConfig.cardBlur,
          sigmaY: GlassEffectConfig.cardBlur,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(
                  alpha: GlassEffectConfig.cardOpacity,
                ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.1),
                Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withValues(alpha: 0.1),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEC4899).withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '阅读成就',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '已获得 $achievedCount 个成就，还有 ${totalCount - achievedCount} 个等待解锁',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: achievedCount / totalCount,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 根据真实统计数据生成成就列表
  List<Map<String, dynamic>> _getAchievementsList() {
    final totalReadingMinutes = _overallStats['totalReadingTime'] ?? 0;
    final totalPages = _overallStats['totalPages'] ?? 0;
    final totalBooks = _overallStats['totalBooks'] ?? 0;
    final streak = _overallStats['streak'] ?? 0;

    return [
      {
        'title': '初次阅读',
        'description': '完成第一次阅读记录',
        'icon': Icons.auto_stories_rounded,
        'gradient': [const Color(0xFF3B82F6), const Color(0xFF2563EB)], // 蓝色
        'achieved': totalReadingMinutes > 0,
        'progress': totalReadingMinutes > 0 ? 1.0 : 0.0,
      },
      {
        'title': '阅读新手',
        'description': '累计阅读时长达到10小时',
        'icon': Icons.timer_rounded,
        'gradient': [const Color(0xFF10B981), const Color(0xFF059669)], // 绿色
        'achieved': totalReadingMinutes >= 600,
        'progress': (totalReadingMinutes / 600).clamp(0.0, 1.0),
      },
      {
        'title': '书虫',
        'description': '累计阅读时长达到100小时',
        'icon': Icons.local_fire_department_rounded,
        'gradient': [const Color(0xFFF59E0B), const Color(0xFFD97706)], // 橙色
        'achieved': totalReadingMinutes >= 6000,
        'progress': (totalReadingMinutes / 6000).clamp(0.0, 1.0),
      },
      {
        'title': '阅读达人',
        'description': '连续阅读7天',
        'icon': Icons.calendar_month_rounded,
        'gradient': [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)], // 紫色
        'achieved': streak >= 7,
        'progress': (streak / 7).clamp(0.0, 1.0),
      },
      {
        'title': '知识海洋',
        'description': '阅读页数达到10000页',
        'icon': Icons.waves_rounded,
        'gradient': [const Color(0xFF06B6D4), const Color(0xFF0891B2)], // 青色
        'achieved': totalPages >= 10000,
        'progress': (totalPages / 10000).clamp(0.0, 1.0),
      },
      {
        'title': '博学者',
        'description': '阅读10本不同的书籍',
        'icon': Icons.school_rounded,
        'gradient': [const Color(0xFF78716C), const Color(0xFF57534E)], // 棕色
        'achieved': totalBooks >= 10,
        'progress': (totalBooks / 10).clamp(0.0, 1.0),
      },
      {
        'title': '阅读马拉松',
        'description': '连续阅读30天',
        'icon': Icons.trending_up_rounded,
        'gradient': [const Color(0xFF6366F1), const Color(0xFF4F46E5)], // 靛蓝
        'achieved': streak >= 30,
        'progress': (streak / 30).clamp(0.0, 1.0),
      },
      {
        'title': '专注达人',
        'description': '累计阅读时长达到500小时',
        'icon': Icons.center_focus_strong_rounded,
        'gradient': [const Color(0xFFEF4444), const Color(0xFFDC2626)], // 红色
        'achieved': totalReadingMinutes >= 30000,
        'progress': (totalReadingMinutes / 30000).clamp(0.0, 1.0),
      },
    ];
  }

  // 成就列表
  Widget _buildAchievementsList() {
    final achievements = _getAchievementsList();

    return Column(
      children: achievements.map((achievement) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: achievement['achieved'] as bool
                        ? (achievement['gradient'] as List<Color>)[0]
                            .withValues(alpha: 0.3)
                        : Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: achievement['gradient'] as List<Color>,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: achievement['achieved'] as bool
                            ? [
                                BoxShadow(
                                  color: (achievement['gradient']
                                          as List<Color>)[0]
                                      .withValues(alpha: 0.5),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : [],
                      ),
                      child: Icon(
                        achievement['icon'] as IconData,
                        color: achievement['achieved'] as bool
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                achievement['title'] as String,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: achievement['achieved'] as bool
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onSurface
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.7),
                                    ),
                              ),
                              if (achievement['achieved'] as bool) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: achievement['gradient']
                                          as List<Color>,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            achievement['description'] as String,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                          ),
                          if (!(achievement['achieved'] as bool)) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: achievement['progress'] as double,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.2),
                                valueColor: AlwaysStoppedAnimation(
                                  (achievement['gradient'] as List<Color>)[0],
                                ),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '进度: ${((achievement['progress'] as double) * 100).toInt()}%',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: (achievement['gradient']
                                        as List<Color>)[0],
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // 阅读目标进度图表
  Widget _buildReadingGoalChart() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassEffectConfig.cardBlur,
          sigmaY: GlassEffectConfig.cardBlur,
        ),
        child: Container(
          height: 280,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(
                  alpha: GlassEffectConfig.cardOpacity,
                ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '阅读目标进度',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),

              // 月度目标
              _buildGoalProgress('本月阅读目标', '12本书', 8, 12, Colors.blue),
              const SizedBox(height: 16),

              // 时间目标
              _buildGoalProgress('每周阅读时长', '10小时', 7.5, 10, Colors.orange),
              const SizedBox(height: 16),

              // 页数目标
              _buildGoalProgress('每日阅读页数', '50页', 38, 50, Colors.green),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalProgress(
    String title,
    String target,
    double current,
    double max,
    Color color,
  ) {
    final progress = (current / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            Text(
              '${current.toInt()} / $target',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              height: 8,
              width: MediaQuery.of(context).size.width *
                  progress *
                  0.8, // 考虑padding
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.6), color],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 阅读速度分析图表
  Widget _buildReadingSpeedChart() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassEffectConfig.cardBlur,
          sigmaY: GlassEffectConfig.cardBlur,
        ),
        child: Container(
          height: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(
                  alpha: GlassEffectConfig.cardOpacity,
                ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '阅读速度趋势',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '平均: ${_averagePagesPerMinute.toStringAsFixed(1)}页/分钟',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(child: LineChart(_buildReadingSpeedChartData())),
            ],
          ),
        ),
      ),
    );
  }

  LineChartData _buildReadingSpeedChartData() {
    // 模拟阅读速度数据（页/分钟）
    final speedData = List.generate(14, (index) {
      return FlSpot(
        index.toDouble(),
        1.8 + (index % 7) * 0.2 + (index / 14) * 0.5,
      );
    });

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 0.5,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 2,
            getTitlesWidget: (double value, TitleMeta meta) {
              return Text(
                '第${(value.toInt() + 1)}天',
                style: Theme.of(context).textTheme.bodySmall,
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 0.5,
            getTitlesWidget: (double value, TitleMeta meta) {
              return Text(
                '${value.toStringAsFixed(1)}页/分',
                style: Theme.of(context).textTheme.bodySmall,
              );
            },
            reservedSize: 50,
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: 13,
      minY: 1.0,
      maxY: 3.5,
      lineBarsData: [
        LineChartBarData(
          spots: speedData,
          isCurved: true,
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
              Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.8),
            ],
          ),
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: Theme.of(context).colorScheme.secondary,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.05),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }

  // 阅读连续性热力图
  Widget _buildReadingStreakHeatmap() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassEffectConfig.cardBlur,
          sigmaY: GlassEffectConfig.cardBlur,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(
                  alpha: GlassEffectConfig.cardOpacity,
                ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '阅读连续性',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.tertiary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '当前连读: 12天',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.tertiary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 热力图网格 (最近90天)
              _buildHeatmapGrid(),

              const SizedBox(height: 16),

              // 图例
              Row(
                children: [
                  Text(
                    '少',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                  ),
                  const SizedBox(width: 8),
                  ...List.generate(5, (index) {
                    final opacity = (index + 1) * 0.2;
                    return Container(
                      margin: const EdgeInsets.only(right: 4),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  Text(
                    '多',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeatmapGrid() {
    // const int totalDays = 91; // 13周 x 7天 (备用)
    const int weeksToShow = 13;
    final List<String> weekDays = ['日', '一', '二', '三', '四', '五', '六'];

    return Column(
      children: [
        // 周标题
        Row(
          children: [
            const SizedBox(width: 20), // 为左侧日期标签留空间
            ...List.generate(weeksToShow, (weekIndex) {
              if (weekIndex % 2 == 0) {
                return Expanded(
                  child: Text(
                    '第${weekIndex + 1}周',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return const Expanded(child: SizedBox());
            }),
          ],
        ),
        const SizedBox(height: 8),

        // 热力图主体
        Column(
          children: List.generate(7, (dayOfWeek) {
            return Row(
              children: [
                // 左侧星期标签
                SizedBox(
                  width: 20,
                  child: Text(
                    weekDays[dayOfWeek],
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // 热力图方格
                ...List.generate(weeksToShow, (weekIndex) {
                  // 模拟阅读强度数据 (0-1)
                  final intensity = _generateReadingIntensity(
                    weekIndex,
                    dayOfWeek,
                  );

                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(1),
                      height: 12,
                      decoration: BoxDecoration(
                        color: intensity > 0
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: intensity)
                            : Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.1),
                          width: 0.5,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
        ),
      ],
    );
  }

  double _generateReadingIntensity(int weekIndex, int dayOfWeek) {
    // 使用真实的热力图数据
    final now = DateTime.now();
    // 计算具体日期（从最近的周日开始算起）
    final currentWeekday = now.weekday % 7; // 转换为0=周日的格式
    final daysFromStart = 90 - (weekIndex * 7 + (6 - dayOfWeek));
    final targetDate =
        now.subtract(Duration(days: daysFromStart + currentWeekday));
    final dateStr = targetDate.toIso8601String().split('T').first;

    return _heatmapData[dateStr] ?? 0.0;
  }

  /// 构建书籍封面组件，优先显示真实封面，否则显示默认图标
  Widget _buildBookCoverWidget(Book book, double width, double height) {
    if (book.coverImagePath != null &&
        book.coverImagePath!.isNotEmpty &&
        book.coverImagePath != 'null') {
      // 尝试显示真实封面
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(book.coverImagePath!),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // 如果加载失败，显示默认图标
            return _buildDefaultBookIcon(width, height);
          },
        ),
      );
    } else {
      // 没有封面路径，显示默认图标
      return _buildDefaultBookIcon(width, height);
    }
  }

  /// 构建默认的书籍图标
  Widget _buildDefaultBookIcon(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.menu_book,
        color: Theme.of(context).colorScheme.primary,
        size: width * 0.5,
      ),
    );
  }
}
