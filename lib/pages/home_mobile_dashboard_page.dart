import 'dart:io';

import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/books/book_services.dart';
import '../services/core/core_services.dart';
import '../services/reading/reading_services.dart';
import '../utils/layout_helper.dart';
import '../utils/page_transitions.dart';
import 'detailed_stats_page.dart';
import 'home_layout_constants.dart';

class _HomeContentMetrics {
  final double refreshEdgeOffset;
  final double horizontalPadding;
  final double contentTopPadding;
  final double contentBottomPadding;
  final double sectionSpacing;

  const _HomeContentMetrics({
    required this.refreshEdgeOffset,
    required this.horizontalPadding,
    required this.contentTopPadding,
    required this.contentBottomPadding,
    required this.sectionSpacing,
  });
}

class _HomePalette {
  final Color pageGradientStart;
  final Color pageGradientMiddle;
  final Color pageGradientEnd;
  final Color cardColor;
  final Color heroColor;
  final Color topActionColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color sectionLabelColor;
  final Color accentColor;
  final Color softAccentColor;
  final Color inactiveDotColor;
  final Color coverPlaceholderColor;
  final Color refreshBackgroundColor;

  const _HomePalette({
    required this.pageGradientStart,
    required this.pageGradientMiddle,
    required this.pageGradientEnd,
    required this.cardColor,
    required this.heroColor,
    required this.topActionColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.sectionLabelColor,
    required this.accentColor,
    required this.softAccentColor,
    required this.inactiveDotColor,
    required this.coverPlaceholderColor,
    required this.refreshBackgroundColor,
  });

  factory _HomePalette.fromTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return _HomePalette(
      pageGradientStart: Color.alphaBlend(
        scheme.primary.withValues(alpha: isDark ? 0.26 : 0.10),
        scheme.surface,
      ),
      pageGradientMiddle: Color.alphaBlend(
        scheme.secondary.withValues(alpha: isDark ? 0.18 : 0.08),
        scheme.surface,
      ),
      pageGradientEnd: scheme.surface,
      cardColor: scheme.surface.withValues(alpha: isDark ? 0.72 : 0.88),
      heroColor: Color.alphaBlend(
        scheme.primary.withValues(alpha: isDark ? 0.25 : 0.14),
        scheme.primaryContainer.withValues(alpha: isDark ? 0.40 : 0.56),
      ),
      topActionColor: scheme.surface.withValues(alpha: isDark ? 0.76 : 0.84),
      primaryTextColor: scheme.onSurface,
      secondaryTextColor: scheme.onSurfaceVariant.withValues(
        alpha: isDark ? 0.92 : 0.84,
      ),
      sectionLabelColor: scheme.onSurfaceVariant.withValues(
        alpha: isDark ? 0.82 : 0.76,
      ),
      accentColor: scheme.primary,
      softAccentColor: scheme.primary.withValues(alpha: isDark ? 0.76 : 0.62),
      inactiveDotColor: scheme.outline.withValues(alpha: isDark ? 0.38 : 0.30),
      coverPlaceholderColor: scheme.primary.withValues(alpha: isDark ? 0.66 : 0.56),
      refreshBackgroundColor: scheme.surface,
    );
  }
}

class HomeMobileDashboardPage extends StatefulWidget {
  const HomeMobileDashboardPage({super.key});

  @override
  State<HomeMobileDashboardPage> createState() => _HomeMobileDashboardPageState();
}

class _HomeMobileDashboardPageState extends State<HomeMobileDashboardPage> {
  final _statsDao = ReadingStatsDao();
  final _bookDao = BookDao();
  final _appStateService = AppStateService();

  _HomePalette get _palette => _HomePalette.fromTheme(Theme.of(context));

  Map<String, int> _summaryStats = {};
  List<Map<String, dynamic>> _weeklyData = [];
  List<Book> _recentBooks = [];
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
      final recentBooks = await _loadRecentBooks();

      if (!mounted) return;
      setState(() {
        _summaryStats = summary;
        _weeklyData = weekly;
        _recentBooks = recentBooks;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<List<Book>> _loadRecentBooks() async {
    try {
      if (!_appStateService.isInitialized) {
        await _appStateService.initialize();
      }
      final appState = _appStateService.currentState;
      final recentBooksList = appState.readingState.recentBooks;
      final books = <Book>[];

      for (final recentBook in recentBooksList.take(5)) {
        final book = await _bookDao.getBookById(recentBook.bookId);
        if (book != null) {
          books.add(book);
        }
      }
      return books;
    } catch (_) {
      return [];
    }
  }

  _HomeContentMetrics _computeMetrics(
    MediaQueryData mediaQuery, {
    required bool useRailNavigation,
  }) {
    final safeBottom = mediaQuery.padding.bottom.clamp(0.0, kHomeMobileSafeBottomMax);
    final contentBottomPadding = safeBottom +
        kHomeMobileFloatingNavHeight +
        kHomeMobileFloatingNavBottomGap +
        kHomeMobileContentBottomExtra;

    return _HomeContentMetrics(
      refreshEdgeOffset: mediaQuery.padding.top,
      horizontalPadding: 16,
      contentTopPadding: useRailNavigation
          ? mediaQuery.padding.top + 8
          : mediaQuery.padding.top + kHomeMobileTopBarHeight + 8,
      contentBottomPadding: contentBottomPadding,
      sectionSpacing: 10,
    );
  }

  int get _todayMinutes => (_summaryStats['today'] ?? 0) ~/ 60;
  int get _totalMinutes => (_summaryStats['total'] ?? 0) ~/ 60;

  String get _totalHoursLabel {
    final hours = _totalMinutes / 60.0;
    return hours.toStringAsFixed(1);
  }

  String _formatThousand(int number) {
    final raw = number.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return raw.replaceAll(reg, ',');
  }

  List<double> _normalizedWeekDots() {
    if (_weeklyData.isEmpty) {
      return const [1, 1, 1, 0.6, 0, 0, 0];
    }

    final values = _weeklyData
        .take(7)
        .map((item) {
          final raw = item['readingTime'] ?? item['duration'] ?? item['minutes'] ?? item['value'] ?? 0;
          if (raw is num) return raw.toDouble();
          return double.tryParse(raw.toString()) ?? 0;
        })
        .toList(growable: false);

    while (values.length < 7) {
      values.add(0);
    }

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    if (maxValue <= 0) return const [1, 1, 1, 0.6, 0, 0, 0];

    return values.map((v) => (v / maxValue).clamp(0.0, 1.0)).toList(growable: false);
  }

  int _weekPercent(List<double> dots) {
    final active = dots.where((v) => v > 0.3).length;
    return ((active / 7) * 100).round();
  }

  int _planDoneCount() {
    final weekMinutes = (_summaryStats['week'] ?? 0) ~/ 60;
    if (weekMinutes <= 0) return 0;
    final done = (weekMinutes / 30).floor();
    return done.clamp(0, 8);
  }

  void _openStats() {
    Navigator.of(context).pushWithSlideScale(const DetailedStatsPage());
  }

  Future<void> _openBook(Book book) async {
    await ReadingRouterService.openBook(context, book);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final useRailNavigation = LayoutHelper.getNavigationType(context) == NavigationType.rail;
    final metrics = _computeMetrics(
      mediaQuery,
      useRailNavigation: useRailNavigation,
    );
    final dots = _normalizedWeekDots();
    final weekPercent = _weekPercent(dots);
    final planDone = _planDoneCount();
    final firstBook = _recentBooks.isNotEmpty ? _recentBooks.first : null;
    final palette = _palette;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.pageGradientStart,
            palette.pageGradientMiddle,
            palette.pageGradientEnd,
          ],
        ),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllStats,
              strokeWidth: 2.5,
              displacement: 40,
              color: palette.accentColor,
              backgroundColor: palette.refreshBackgroundColor,
              edgeOffset: metrics.refreshEdgeOffset,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  metrics.horizontalPadding,
                  metrics.contentTopPadding,
                  metrics.horizontalPadding,
                  metrics.contentBottomPadding,
                ),
                children: [
                  if (useRailNavigation) ...[
                    _buildTopRow(),
                    SizedBox(height: metrics.sectionSpacing),
                  ],
                  _buildSearchBar(),
                  SizedBox(height: metrics.sectionSpacing),
                  _buildHeroCard(),
                  SizedBox(height: metrics.sectionSpacing),
                  _buildSectionLabel('今日速览'),
                  SizedBox(height: metrics.sectionSpacing),
                  _buildSummaryRow(),
                  SizedBox(height: metrics.sectionSpacing),
                  _buildHeaderRow('今日阅读计划', '$planDone / 8'),
                  SizedBox(height: metrics.sectionSpacing),
                  _buildPlanCard(),
                  SizedBox(height: metrics.sectionSpacing),
                  _buildSectionLabel('阅读进度'),
                  SizedBox(height: metrics.sectionSpacing),
                  _buildWeekCard(dots, weekPercent),
                  SizedBox(height: metrics.sectionSpacing),
                  _buildHeaderRow('最近阅读', '查看全部', action: _openStats),
                  SizedBox(height: metrics.sectionSpacing),
                  _buildRecentCard(firstBook),
                ],
              ),
            ),
    );
  }

  Widget _buildTopRow() {
    final palette = _palette;
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          Text(
            '首页',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.0,
              color: palette.primaryTextColor,
            ),
          ),
          const Spacer(),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.topActionColor,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.settings_outlined,
              size: 20,
              color: palette.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final palette = _palette;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: palette.secondaryTextColor),
          const SizedBox(width: 8),
          Text(
            '搜索书籍、笔记、章节',
            style: TextStyle(
              fontSize: 14,
              color: palette.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    final palette = _palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.heroColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_stories_rounded,
                size: 20,
                color: palette.accentColor,
              ),
              const SizedBox(width: 10),
              Text(
                '今日阅读时光',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: palette.primaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '已阅读 $_todayMinutes 分钟，继续保持',
            style: TextStyle(
              fontSize: 14,
              color: palette.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '累计 $_totalHoursLabel 小时',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: palette.accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    final palette = _palette;
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: palette.sectionLabelColor,
      ),
    );
  }

  Widget _buildSummaryRow() {
    final palette = _palette;
    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _openStats,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.cardColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_todayMinutes',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      color: palette.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '今日阅读（分钟）',
                    style: TextStyle(
                      fontSize: 14,
                      color: palette.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _openStats,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.cardColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatThousand(_totalMinutes),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      color: palette.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '累计阅读（分钟）',
                    style: TextStyle(
                      fontSize: 14,
                      color: palette.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(String title, String trailing, {VoidCallback? action}) {
    final palette = _palette;
    final trailingColor =
        action == null ? palette.secondaryTextColor : palette.accentColor;

    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: palette.primaryTextColor,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: action,
          child: Text(
            trailing,
            style: TextStyle(
              fontSize: 14,
              fontWeight: action == null ? FontWeight.w400 : FontWeight.w600,
              color: trailingColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard() {
    final palette = _palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '✓ 阅读 30 分钟',
            style: TextStyle(
              fontSize: 14,
              color: palette.primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '• 早读复盘',
            style: TextStyle(
              fontSize: 14,
              color: palette.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekCard(List<double> dots, int weekPercent) {
    final palette = _palette;
    final colors = dots.asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value;
      if (value <= 0.15) return palette.inactiveDotColor;
      if (index <= 2) return palette.accentColor;
      return palette.softAccentColor;
    }).toList(growable: false);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _openStats,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  '本周阅读趋势',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: palette.primaryTextColor,
                    height: 0.95,
                  ),
                ),
                const Spacer(),
                Text(
                  '$weekPercent%',
                  style: TextStyle(
                    fontSize: 14,
                    color: palette.secondaryTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(7, (index) {
                return Container(
                  width: 24,
                  height: 24,
                  margin: EdgeInsets.only(right: index == 6 ? 0 : 10),
                  decoration: BoxDecoration(
                    color: colors[index],
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentCard(Book? book) {
    final palette = _palette;
    final title = book?.title.isNotEmpty == true ? book!.title : '掌控习惯';
    final progress = (book != null && book.totalPages > 0)
        ? ((book.currentPage / book.totalPages) * 100).clamp(0, 100).toStringAsFixed(0)
        : '62';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: book == null ? null : () => _openBook(book),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: palette.cardColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 60,
                decoration: BoxDecoration(
                  color: palette.coverPlaceholderColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: (book != null && book.coverImagePath != null && book.coverImagePath!.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(book.coverImagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox.shrink();
                          },
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: palette.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '阅读进度 $progress%',
                      style: TextStyle(
                        fontSize: 14,
                        color: palette.secondaryTextColor,
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
}
