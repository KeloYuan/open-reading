import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_content_enhanced.dart';
import 'library_page.dart';
import 'settings_page.dart';
import 'import_book_page.dart';
import 'detailed_stats_page.dart';
import 'book_source_page.dart';
import '../utils/responsive_helper.dart';
import '../utils/glass_config.dart';
import '../utils/page_transitions.dart';
import '../services/book_dao.dart';
import '../services/reading_stats_dao.dart';

class HomePageResponsive extends StatefulWidget {
  const HomePageResponsive({super.key});

  @override
  State<HomePageResponsive> createState() => _HomePageResponsiveState();
}

class _HomePageResponsiveState extends State<HomePageResponsive> {
  int _selectedIndex = 0;
  late PageController _pageController;
  bool _booksourceEnabled = false;

  List<NavigationItem> _navigationItems = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initializeNavigationItems();
    // 优化PageController，设置合适的视窗比例
    _pageController = PageController(
      viewportFraction: 1.0, // 保持全屏显示
      keepPage: true, // 保持页面状态
    );
    _setupPageImmersiveMode();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _booksourceEnabled = prefs.getBool('enable_booksource') ?? false;
    });
    _initializeNavigationItems();
  }

  void _initializeNavigationItems() {
    final baseItems = [
      NavigationItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: '首页',
        page: const HomeContentEnhanced(),
      ),
      NavigationItem(
        icon: Icons.library_books_outlined,
        selectedIcon: Icons.library_books,
        label: '书库',
        page: const LibraryPage(),
      ),
    ];

    final conditionalItems = <NavigationItem>[];

    // 条件添加书源选项
    if (_booksourceEnabled) {
      conditionalItems.add(
        NavigationItem(
          icon: Icons.source_outlined,
          selectedIcon: Icons.source,
          label: '书源',
          page: const BookSourcePage(),
        ),
      );
    }

    // 设置选项总是最后
    conditionalItems.add(
      NavigationItem(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: '设置',
        page: const SettingsPage(),
      ),
    );

    setState(() {
      _navigationItems = [...baseItems, ...conditionalItems];
      // 如果当前选中的索引超出范围，重置为首页
      if (_selectedIndex >= _navigationItems.length) {
        _selectedIndex = 0;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 每次依赖变化时重新应用沉浸式设置
    _setupPageImmersiveMode();
    // 应用基于主题的设置
    _setupThemeBasedImmersiveMode();
  }

  // 页面级沉浸式设置
  void _setupPageImmersiveMode() {
    // 强制启用边到边模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // 应用基本的沉浸式样式，不依赖context
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // 默认深色图标
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
    );
  }

  // 基于主题的沉浸式设置 (在didChangeDependencies中调用)
  void _setupThemeBasedImmersiveMode() {
    // 获取当前主题状态
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 应用基于主题的沉浸式样式
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navigationType = ResponsiveHelper.getNavigationType(context);

    switch (navigationType) {
      case NavigationType.rail:
        return _buildNavigationRail();
      case NavigationType.bottom:
        return _buildBottomNavigation();
    }
  }

  // 桌面端：侧边导航栏
  Widget _buildNavigationRail() {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
            colors: [
              // 使用主题的主色调创建更丰富的渐变
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.10),
              Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.04),
              Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.12),
              Theme.of(
                context,
              ).colorScheme.secondaryContainer.withValues(alpha: 0.08),
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
            ],
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: ResponsiveHelper.getValue(
                    context,
                    mobile: 80, // 不会用到，但保持一致性
                    tablet: 200, // 平板使用中等宽度
                    desktop: 250, // 桌面使用最大宽度
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.8),
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    extended: ResponsiveHelper.getValue(
                      context,
                      mobile: false,
                      tablet: true, // 平板显示扩展导航，方便使用
                      desktop: true, // 桌面也显示扩展导航
                    ),
                    labelType: ResponsiveHelper.getValue(
                      context,
                      mobile: NavigationRailLabelType.all,
                      tablet: NavigationRailLabelType.none, // 平板使用扩展模式，不需要额外标签
                      desktop: NavigationRailLabelType.none, // 桌面同样
                    ),
                    leading: ResponsiveHelper.isWideScreen(context)
                        ? _buildNavigationHeader()
                        : null,
                    minWidth: 60,
                    minExtendedWidth: ResponsiveHelper.getValue(
                      context,
                      mobile: 200,
                      tablet: 200,
                      desktop: 250,
                    ),
                    backgroundColor: Colors.transparent,
                    indicatorColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                    selectedIconTheme: IconThemeData(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    unselectedIconTheme: IconThemeData(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    selectedLabelTextStyle: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelTextStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                    destinations: _navigationItems
                        .map(
                          (item) => NavigationRailDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(item.selectedIcon),
                            label: Text(item.label),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
            Expanded(child: _navigationItems[_selectedIndex].page),
          ],
        ),
      ),
      floatingActionButton: _selectedIndex < 2
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: FloatingActionButton.extended(
                    onPressed: () => _navigateToImport(),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.9),
                    icon: const Icon(Icons.add),
                    label: const Text('导入书籍'),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  // 手机端：底部导航栏
  Widget _buildBottomNavigation() {
    return Scaffold(
      extendBody: true, // 让body延伸到底部导航栏后面
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // 使用与书库页面完全相同的设置 - 完全透明且高度为0
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0, // 设置高度为0，让毛玻璃标题栏在body中实现
      ),
      body: Stack(
        children: [
          // 主内容 - 优化的PageView，减少卡顿
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              // 使用更稳定的方式避免在build过程中调用setState
              if (mounted && _selectedIndex != index) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() => _selectedIndex = index);
                  }
                });
              }
            },
            // 优化滚动物理效果，减少过度滚动
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            children: _navigationItems.map((item) {
              // 使用RepaintBoundary和AutomaticKeepAliveClientMixin优化重绘和内存管理
              return RepaintBoundary(child: _buildPageWrapper(item.page));
            }).toList(),
            // 禁用页面捕捉以减少卡顿
            pageSnapping: true,
          ),
          // 悬浮药丸导航栏
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 68 +
                  25 +
                  (MediaQuery.of(context).padding.bottom).clamp(
                    0.0,
                    50.0,
                  ), // 大幅减少高度：实际导航栏68px + 边距25px + 安全区域
              child: Center(
                child: Container(
                  margin: EdgeInsets.only(
                    bottom: (MediaQuery.of(
                          context,
                        ).padding.bottom)
                            .clamp(0.0, 50.0) +
                        25,
                  ), // 动态适配底部安全区域，限制最大值
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(60), // 增大圆角半径，更Q弹
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: GlassEffectConfig.navigationBarBlur,
                        sigmaY: GlassEffectConfig.navigationBarBlur,
                      ),
                      child: Container(
                        height: 68, // 从70增加到75
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20, // 进一步减少到20px，让背景更紧凑
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(
                                alpha: GlassEffectConfig.navigationBarOpacity,
                              ),
                          borderRadius: BorderRadius.circular(60), // 更大的圆角半径
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.15),
                            width: 0.5,
                          ),
                          boxShadow: [
                            // 增强阴影效果，让悬浮感更强
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 30,
                              offset: const Offset(0, 8),
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 60,
                              offset: const Offset(0, 16),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _navigationItems.asMap().entries.map((
                            entry,
                          ) {
                            final index = entry.key;
                            final item = entry.value;
                            final isSelected = _selectedIndex == index;

                            return _BounceNavigationItem(
                              index: index,
                              item: item,
                              isSelected: isSelected,
                              onTap: () {
                                // 优化导航响应性能
                                if (_selectedIndex == index) return; // 避免重复点击

                                // 使用addPostFrameCallback避免在build过程中调用setState
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted) {
                                    setState(() => _selectedIndex = index);
                                  }
                                });

                                // 使用更流畅的动画参数
                                _pageController.animateToPage(
                                  index,
                                  duration: const Duration(
                                    milliseconds: 300, // 适当增加时长，让动画更流畅
                                  ),
                                  curve: Curves.easeOutCubic, // 使用更自然的缓动曲线
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageWrapper(Widget page) {
    // 使用RepaintBoundary和缓存优化
    Widget wrappedPage;

    // 对于手机端，为不同页面添加统一的毛玻璃顶栏包装
    if (page is HomeContentEnhanced) {
      wrappedPage = const _HomeContentWrapper();
    } else if (page is SettingsPage) {
      // 设置页面使用特殊包装器，确保状态栏正确处理
      wrappedPage = _SettingsPageWrapper(child: page);
    } else {
      // 其他页面使用通用包装
      wrappedPage = _GenericPageWrapper(child: page);
    }

    // 添加AutomaticKeepAliveClientMixin包装以保持页面状态
    return _KeepAlivePage(child: wrappedPage);
  }

  void _navigateToImport() {
    // 使用淡入缩放动画，适合模态页面
    Navigator.of(context).pushWithFadeScale(const ImportBookPage());
  }

  // 导航头部组件 - 专为平板和桌面优化
  Widget _buildNavigationHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.auto_stories_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          if (ResponsiveHelper.getValue(
            context,
            mobile: false,
            tablet: true,
            desktop: true,
          )) ...[
            const SizedBox(height: 12),
            Text(
              '小元读书',
              style: TextStyle(
                fontSize: ResponsiveHelper.getValue(
                  context,
                  mobile: 16.0,
                  tablet: 18.0,
                  desktop: 20.0,
                ),
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '优雅阅读',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                letterSpacing: 0.3,
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget page;

  NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.page,
  });
}

// Q弹导航项目组件
class _BounceNavigationItem extends StatefulWidget {
  final int index;
  final NavigationItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _BounceNavigationItem({
    required this.index,
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_BounceNavigationItem> createState() => _BounceNavigationItemState();
}

class _BounceNavigationItemState extends State<_BounceNavigationItem>
    with SingleTickerProviderStateMixin {
  // 只使用一个ticker
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 优化动画控制器性能
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 120), // 进一步减少持续时间，提升响应性
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutQuint, // 使用更快速的缓动曲线
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150), // 进一步减少动画时间
              curve: Curves.easeOutCirc, // 使用更快的缓动曲线
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isSelected
                        ? widget.item.selectedIcon
                        : widget.item.icon,
                    color: widget.isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 150), // 与容器动画同步
                    curve: Curves.easeOutCirc, // 保持一致的缓动曲线
                    style: TextStyle(
                      fontSize: widget.isSelected ? 12.5 : 12,
                      fontWeight:
                          widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: widget.isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    child: Text(
                      widget.item.label,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// 首页内容包装器 - 移除AppBar和Scaffold，调整padding
class _HomeContentWrapper extends StatefulWidget {
  const _HomeContentWrapper();

  @override
  State<_HomeContentWrapper> createState() => _HomeContentWrapperState();
}

class _HomeContentWrapperState extends State<_HomeContentWrapper> {
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
      debugPrint('Error loading stats: $e');
    }
  }

  void _navigateToDetailedStats() {
    // 使用滑动缩放动画，适合详情页面
    Navigator.of(context).pushWithSlideScale(const DetailedStatsPage());
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bool isCupertino = !kIsWeb && Platform.isIOS;
    final double appBarHeight = 60;
    final double screenWidth = mediaQuery.size.width;
    final double refreshEdgeOffset = mediaQuery.padding.top + appBarHeight;

    const double topContentInset = 16;
    const double baseSpacingAfterWelcome = 24;
    const double baseSectionSpacing = 28;

    double summaryTargetSpacing = baseSpacingAfterWelcome;
    double weeklyTargetSpacing = baseSectionSpacing;
    double recentTargetSpacing = baseSectionSpacing;

    if (isCupertino) {
      if (screenWidth >= 428) {
        summaryTargetSpacing = 12;
        weeklyTargetSpacing = 14;
        recentTargetSpacing = 14;
      } else if (screenWidth >= 414) {
        summaryTargetSpacing = 16;
        weeklyTargetSpacing = 18;
        recentTargetSpacing = 18;
      } else if (screenWidth >= 390) {
        summaryTargetSpacing = 18;
        weeklyTargetSpacing = 20;
        recentTargetSpacing = 20;
      } else {
        summaryTargetSpacing = 20;
        weeklyTargetSpacing = 22;
        recentTargetSpacing = 20;
      }
    }

    summaryTargetSpacing =
        summaryTargetSpacing.clamp(12, baseSpacingAfterWelcome).toDouble();
    weeklyTargetSpacing =
        weeklyTargetSpacing.clamp(12, baseSectionSpacing).toDouble();
    recentTargetSpacing =
        recentTargetSpacing.clamp(12, baseSectionSpacing).toDouble();

    final double summaryLift =
        isCupertino ? baseSpacingAfterWelcome - summaryTargetSpacing : 0;
    final double weeklyLift =
        isCupertino ? baseSectionSpacing - weeklyTargetSpacing : 0;
    final double recentLift =
        isCupertino ? baseSectionSpacing - recentTargetSpacing : 0;

    final double contentTopPadding =
        mediaQuery.padding.top + appBarHeight + topContentInset;
    const double spacingAfterWelcome = baseSpacingAfterWelcome;
    const double sectionSpacing = baseSectionSpacing;
    final double contentBottomPadding = mediaQuery.padding.bottom + 60;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
          colors: [
            // 使用主题的主色调创建更丰富的渐变
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
            Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.06),
            Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.15),
            Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: 0.10),
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
          ],
        ),
      ),
      child: Stack(
        children: [
          // 主内容
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadAllStats,
                  strokeWidth: 2.5, // 减细刷新指示器线条
                  displacement: 40, // 优化下拉距离，避免与AppBar冲突
                  color: Theme.of(context).colorScheme.primary, // 主题色
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.9), // 半透明背景
                  edgeOffset: refreshEdgeOffset,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      contentTopPadding,
                      16,
                      contentBottomPadding,
                    ),
                    children: [
                      _buildWelcomeCard(),
                      SizedBox(height: spacingAfterWelcome),
                      Transform.translate(
                        offset: Offset(0, -summaryLift),
                        transformHitTests: false,
                        child: _buildSummaryCards(),
                      ),
                      SizedBox(height: sectionSpacing),
                      Transform.translate(
                        offset: Offset(0, -weeklyLift),
                        transformHitTests: false,
                        child: _buildWeeklyChartCard(),
                      ),
                      SizedBox(height: sectionSpacing),
                      Transform.translate(
                        offset: Offset(0, -recentLift),
                        transformHitTests: false,
                        child: _buildRecentActivity(),
                      ),
                    ],
                  ),
                ),
          // 毛玻璃AppBar - 使用与书库页面相同的实现方式
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
                  height: MediaQuery.of(context).padding.top +
                      60, // 状态栏高度 + AppBar高度
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
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      MediaQuery.of(context).padding.top + 8, // 减少AppBar内间距
                      16,
                      8, // 减少底部间距
                    ), // 沉浸式：状态栏高度 + 8px间距
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '首页',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 复制HomeContentEnhanced中的方法
  Widget _buildWelcomeCard() {
    final totalMinutes = (_summaryStats['total'] ?? 0) ~/ 60;
    final todayMinutes = (_summaryStats['today'] ?? 0) ~/ 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
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
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
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
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            todayMinutes > 0
                                ? '已阅读 $todayMinutes 分钟，继续保持！'
                                : '开始今天的阅读之旅吧',
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
                          ).colorScheme.primaryContainer.withValues(alpha: 0.4),
                          Theme.of(context)
                              .colorScheme
                              .secondaryContainer
                              .withValues(alpha: 0.3),
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
                            ).colorScheme.primary.withValues(alpha: 0.2),
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
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
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
              child: GestureDetector(
                onTap: () => _navigateToDetailedStats(),
                child: _StatCard(
                  title: '今日阅读',
                  value: '$todayMinutes',
                  unit: '分钟',
                  icon: Icons.today,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => _navigateToDetailedStats(),
                child: _StatCard(
                  title: '本周阅读',
                  value: '$weekMinutes',
                  unit: '分钟',
                  icon: Icons.calendar_view_week,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _navigateToDetailedStats(),
                child: _StatCard(
                  title: '累计阅读',
                  value: '$totalMinutes',
                  unit: '分钟',
                  icon: Icons.history,
                  color: Colors.green,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                title: '书架藏书',
                value: '$_bookCount',
                unit: '本',
                icon: Icons.book,
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWideLayout(int todayMinutes, int weekMinutes, int totalMinutes) {
    // 获取iOS设备优化的GridView间距和纵横比
    final screenWidth = MediaQuery.of(context).size.width;

    // 根据iOS设备屏幕尺寸优化间距和纵横比
    double gridSpacing, aspectRatio;

    if (screenWidth >= 428) {
      // iPhone Pro Max等大屏设备
      gridSpacing = 12.0;
      aspectRatio = 1.4;
    } else if (screenWidth >= 414) {
      // iPhone Plus等设备
      gridSpacing = 12.0;
      aspectRatio = 1.3;
    } else if (screenWidth >= 390) {
      // iPhone Pro等设备
      gridSpacing = 10.0;
      aspectRatio = 1.3;
    } else {
      // iPhone SE, Mini等小屏设备
      gridSpacing = 10.0;
      aspectRatio = 1.2;
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: gridSpacing,
      mainAxisSpacing: gridSpacing,
      childAspectRatio: aspectRatio,
      children: [
        GestureDetector(
          onTap: () => _navigateToDetailedStats(),
          child: _StatCard(
            title: '今日阅读',
            value: '$todayMinutes',
            unit: '分钟',
            icon: Icons.today,
            color: Colors.blue,
          ),
        ),
        GestureDetector(
          onTap: () => _navigateToDetailedStats(),
          child: _StatCard(
            title: '本周阅读',
            value: '$weekMinutes',
            unit: '分钟',
            icon: Icons.calendar_view_week,
            color: Colors.orange,
          ),
        ),
        GestureDetector(
          onTap: () => _navigateToDetailedStats(),
          child: _StatCard(
            title: '累计阅读',
            value: '$totalMinutes',
            unit: '分钟',
            icon: Icons.history,
            color: Colors.green,
          ),
        ),
        _StatCard(
          title: '书架藏书',
          value: '$_bookCount',
          unit: '本',
          icon: Icons.book,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildWeeklyChartCard() {
    if (_weeklyData.isEmpty) {
      return Container();
    }

    final maxY = (_weeklyData
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
                          ).colorScheme.outline.withValues(alpha: 0.1),
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

  Widget _buildRecentActivity() {
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
      axisSide: AxisSide.bottom,
      space: 4.0,
      child: Text(text, style: style),
    );
  }

  // iOS设备优化的统计卡片 - 根据不同设备尺寸动态调整偏移量
}

// 通用页面包装器 - 为其他页面提供一致的布局
class _GenericPageWrapper extends StatelessWidget {
  final Widget child;

  const _GenericPageWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
          colors: [
            // 使用主题的主色调创建更丰富的渐变
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
            Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.06),
            Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.15),
            Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: 0.10),
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          0,
          0,
          0,
          0, // 移除底部padding，避免遮挡
        ),
        child: child,
      ),
    );
  }
}

// 统计卡片组件
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 6),
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
                            ).colorScheme.onSurface.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
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
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            unit,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
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
    );
  }
}

// 设置页面专用包装器 - 确保状态栏正确处理
class _SettingsPageWrapper extends StatefulWidget {
  final Widget child;

  const _SettingsPageWrapper({required this.child});

  @override
  State<_SettingsPageWrapper> createState() => _SettingsPageWrapperState();
}

class _SettingsPageWrapperState extends State<_SettingsPageWrapper> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 确保设置页在PageView中也能正确设置状态栏
    _applySettingsPageSystemUI();
  }

  void _applySettingsPageSystemUI() {
    // 强制启用边到边模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // 获取当前主题状态
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 应用基于主题的沉浸式样式 - 减少延迟
    Future.microtask(() {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDarkMode ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              isDarkMode ? Brightness.light : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // 在每次构建后重新应用状态栏设置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _applySettingsPageSystemUI();
      }
    });

    return Stack(
      children: [
        // 设置页面内容
        widget.child,
        // 毛玻璃AppBar - 与首页保持一致
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
                height:
                    MediaQuery.of(context).padding.top + 60, // 状态栏高度 + AppBar高度
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
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    MediaQuery.of(context).padding.top + 8, // 减少AppBar内间距
                    16,
                    8, // 减少底部间距
                  ), // 沉浸式：状态栏高度 + 8px间距
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '设置',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// 保持页面状态的包装器，避免页面重建
class _KeepAlivePage extends StatefulWidget {
  final Widget child;

  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用以保持状态
    return widget.child;
  }
}
