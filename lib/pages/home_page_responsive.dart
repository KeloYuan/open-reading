import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_content_enhanced.dart';
import 'library_page.dart';
import 'settings_page.dart';
import 'import_book_page.dart';
import 'detailed_stats_page.dart';
import '../utils/responsive_helper.dart';
import '../utils/glass_config.dart';
import '../utils/color_extensions.dart';
import '../services/book_dao.dart';
import '../services/reading_stats_dao.dart';
import '../main.dart';

class HomePageResponsive extends StatefulWidget {
  const HomePageResponsive({super.key});

  @override
  State<HomePageResponsive> createState() => _HomePageResponsiveState();
}

class _HomePageResponsiveState extends State<HomePageResponsive> {
  int _selectedIndex = 0;
  late PageController _pageController;

  final List<NavigationItem> _navigationItems = [
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
    NavigationItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: '设置',
      page: const SettingsPage(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _setupPageImmersiveMode();
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
        statusBarIconBrightness: isDarkMode
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDarkMode
            ? Brightness.light
            : Brightness.dark,
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
            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
            colors: [
              Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.12),
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
              Theme.of(
                context,
              ).colorScheme.secondaryContainer.withValues(alpha: 0.08),
              Theme.of(
                context,
              ).colorScheme.tertiaryContainer.withValues(alpha: 0.10),
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
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
          // 主内容 - 使用PageView添加滑动动画
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _selectedIndex = index);
            },
            children: _navigationItems
                .map((item) => _buildPageWrapper(item.page))
                .toList(),
          ),
          // 悬浮药丸导航栏
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height:
                  120 + MediaQuery.of(context).padding.bottom, // 动态高度适配底部安全区域
              color: Colors.transparent, // 完全透明，让内容透过
              child: Center(
                child: Container(
                  margin: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 25,
                  ), // 动态适配底部安全区域
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(45), // 增大圆角半径，更Q弹
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: GlassEffectConfig.navigationBarBlur,
                        sigmaY: GlassEffectConfig.navigationBarBlur,
                      ),
                      child: Container(
                        height: 75, // 从70增加到75
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                        ), // 从32增加到36
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface
                              .withOpacityValues(
                                GlassEffectConfig.navigationBarOpacity,
                              ),
                          borderRadius: BorderRadius.circular(45), // 更大的圆角半径
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
                                setState(() => _selectedIndex = index);
                                _pageController.animateToPage(
                                  index,
                                  duration: const Duration(
                                    milliseconds: 500,
                                  ), // 增加到500ms，更缓慢
                                  curve: Curves.easeInOutCubic, // 使用更优雅的缓动曲线
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
    // 对于手机端，为首页和设置页添加毛玻璃AppBar
    if (page is HomeContentEnhanced) {
      return const _HomeContentWrapper();
    } else if (page is SettingsPage) {
      return const _SettingsPageWrapper();
    }
    return page;
  }

  void _navigateToImport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ImportBookPage()),
    );
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
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _pressController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _pressAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 400), // 减少持续时间
      vsync: this,
    );

    _pressController = AnimationController(
      duration: const Duration(milliseconds: 200), // 稍微增加按压时间
      vsync: this,
    );

    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      // 减少弹跳幅度
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.easeOutCubic,
      ), // 使用更平滑的曲线
    );

    _pressAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      // 减少按压幅度
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      // 减少缩放幅度
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.easeOutCubic,
      ), // 使用更平滑的曲线
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) => _pressController.reverse(),
      onTapCancel: () => _pressController.reverse(),
      onTap: () {
        widget.onTap();
        // 触发Q弹效果
        _bounceController.forward().then((_) {
          _bounceController.reverse();
        });
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_bounceController, _pressController]),
        builder: (context, child) {
          return Transform.scale(
            scale: _pressAnimation.value * _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(28), // 更大的圆角
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.scale(
                      scale: widget.isSelected ? _bounceAnimation.value : 1.0,
                      child: Icon(
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
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        style: TextStyle(
                          fontSize: widget.isSelected ? 12.5 : 12,
                          fontWeight: widget.isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
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
                    ),
                  ],
                ),
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DetailedStatsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
          colors: [
            Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.15),
            Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: 0.08),
            Theme.of(
              context,
            ).colorScheme.tertiaryContainer.withValues(alpha: 0.12),
            Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.06),
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
          ],
        ),
      ),
      child: Stack(
        children: [
          // 添加背景图案让毛玻璃效果更明显
          ...List.generate(15, (index) {
            return Positioned(
              left: (index * 89.0) % MediaQuery.of(context).size.width,
              top: (index * 143.0) % MediaQuery.of(context).size.height,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
          // 主内容
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadAllStats,
                  strokeWidth: 2.5, // 减细刷新指示器线条
                  displacement: 60, // 增加下拉距离
                  color: Theme.of(context).colorScheme.primary, // 主题色
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.9), // 半透明背景
                  edgeOffset:
                      MediaQuery.of(context).padding.top +
                      40, // 下拉刷新UI往下移，避开状态栏和AppBar
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      MediaQuery.of(context).padding.top + 60,
                      16,
                      MediaQuery.of(context).padding.bottom + 90,
                    ), // 沉浸式padding：顶部=状态栏+AppBar，底部=导航栏+额外间距
                    children: [
                      _buildWelcomeCard(),
                      const SizedBox(height: 20),
                      _buildSummaryCards(),
                      const SizedBox(height: 24),
                      _buildWeeklyChartCard(),
                      const SizedBox(height: 24),
                      _buildRecentActivity(),
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
                  height:
                      MediaQuery.of(context).padding.top +
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
                      MediaQuery.of(context).padding.top + 16,
                      16,
                      16,
                    ), // 沉浸式：状态栏高度 + 16px间距
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '首页',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
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

  // 复制HomeContentEnhanced中的方法
  Widget _buildWelcomeCard() {
    final totalMinutes = (_summaryStats['total'] ?? 0) ~/ 60;
    final todayMinutes = (_summaryStats['today'] ?? 0) ~/ 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
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
                                  color: Theme.of(context).colorScheme.onSurface
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
                          Theme.of(context).colorScheme.secondaryContainer
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
                          style: Theme.of(context).textTheme.bodySmall
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
            const SizedBox(width: 12),
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
        const SizedBox(height: 12),
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
            const SizedBox(width: 12),
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
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
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
      meta: meta,
      space: 4.0,
      child: Text(text, style: style),
    );
  }
}

// 设置页面包装器
class _SettingsPageWrapper extends StatefulWidget {
  const _SettingsPageWrapper();

  @override
  State<_SettingsPageWrapper> createState() => _SettingsPageWrapperState();
}

class _SettingsPageWrapperState extends State<_SettingsPageWrapper> {
  double _fontSize = 18.0;
  double _lineSpacing = 1.8;
  double _letterSpacing = 0.2;
  double _pageMargin = 16.0;
  bool _enableAnimations = true;
  bool _enableAutoSave = true;
  bool _keepScreenOn = false;
  String _fontFamily = 'System';
  int _autoSaveInterval = 30;

  final List<String> _fontFamilies = [
    'System',
    'Serif',
    'Sans-serif',
    'Monospace',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = prefs.getDouble('fontSize') ?? 18.0;
      _lineSpacing = prefs.getDouble('lineSpacing') ?? 1.8;
      _letterSpacing = prefs.getDouble('letterSpacing') ?? 0.2;
      _pageMargin = prefs.getDouble('pageMargin') ?? 16.0;
      _enableAnimations = prefs.getBool('enableAnimations') ?? true;
      _enableAutoSave = prefs.getBool('enableAutoSave') ?? true;
      _keepScreenOn = prefs.getBool('keepScreenOn') ?? false;
      _fontFamily = prefs.getString('fontFamily') ?? 'System';
      _autoSaveInterval = prefs.getInt('autoSaveInterval') ?? 30;
    });
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setDouble('lineSpacing', _lineSpacing);
    await prefs.setDouble('letterSpacing', _letterSpacing);
    await prefs.setDouble('pageMargin', _pageMargin);
    await prefs.setBool('enableAnimations', _enableAnimations);
    await prefs.setBool('enableAutoSave', _enableAutoSave);
    await prefs.setBool('keepScreenOn', _keepScreenOn);
    await prefs.setString('fontFamily', _fontFamily);
    await prefs.setInt('autoSaveInterval', _autoSaveInterval);
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.3, 0.7, 1.0],
          colors: [
            Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.12),
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
            Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: 0.08),
            Theme.of(
              context,
            ).colorScheme.tertiaryContainer.withValues(alpha: 0.15),
          ],
        ),
      ),
      child: Stack(
        children: [
          // 添加背景图案让毛玻璃效果更明显
          ...List.generate(12, (index) {
            return Positioned(
              left: (index * 97.0) % MediaQuery.of(context).size.width,
              top: (index * 157.0) % MediaQuery.of(context).size.height,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            );
          }),
          // 主内容
          ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 60,
              16,
              MediaQuery.of(context).padding.bottom + 90,
            ), // 沉浸式padding
            children: [
              _buildSectionCard(
                title: '外观设置',
                icon: Icons.palette_outlined,
                children: [
                  _buildThemeToggle(themeNotifier, isDarkMode),
                  _buildAnimationToggle(),
                ],
              ),
              const SizedBox(height: 20),
              _buildSectionCard(
                title: '阅读设置',
                icon: Icons.auto_stories_outlined,
                children: [
                  _buildSliderSetting(
                    title: '字体大小',
                    subtitle: '${_fontSize.round()} pt',
                    value: _fontSize,
                    min: 12.0,
                    max: 32.0,
                    divisions: 20,
                    onChanged: (value) => setState(() => _fontSize = value),
                    icon: Icons.format_size,
                  ),
                  _buildSliderSetting(
                    title: '行间距',
                    subtitle: _lineSpacing.toStringAsFixed(1),
                    value: _lineSpacing,
                    min: 1.0,
                    max: 3.0,
                    divisions: 20,
                    onChanged: (value) => setState(() => _lineSpacing = value),
                    icon: Icons.format_line_spacing,
                  ),
                  _buildSliderSetting(
                    title: '字符间距',
                    subtitle: _letterSpacing.toStringAsFixed(1),
                    value: _letterSpacing,
                    min: 0.0,
                    max: 2.0,
                    divisions: 20,
                    onChanged: (value) =>
                        setState(() => _letterSpacing = value),
                    icon: Icons.text_fields,
                  ),
                  _buildSliderSetting(
                    title: '页面边距',
                    subtitle: '${_pageMargin.round()} px',
                    value: _pageMargin,
                    min: 8.0,
                    max: 32.0,
                    divisions: 24,
                    onChanged: (value) => setState(() => _pageMargin = value),
                    icon: Icons.format_indent_increase,
                  ),
                  _buildFontFamilySelector(),
                ],
              ),
              const SizedBox(height: 20),
              _buildSectionCard(
                title: '系统设置',
                icon: Icons.settings_outlined,
                children: [
                  _buildSwitchSetting(
                    title: '保持屏幕常亮',
                    subtitle: '阅读时防止屏幕自动关闭',
                    value: _keepScreenOn,
                    onChanged: (value) => setState(() => _keepScreenOn = value),
                    icon: Icons.stay_current_portrait,
                  ),
                  _buildSwitchSetting(
                    title: '自动保存',
                    subtitle: '自动保存阅读进度',
                    value: _enableAutoSave,
                    onChanged: (value) =>
                        setState(() => _enableAutoSave = value),
                    icon: Icons.save_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildAboutCard(),
            ],
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
                  height:
                      MediaQuery.of(context).padding.top +
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
                      MediaQuery.of(context).padding.top + 16,
                      16,
                      16,
                    ), // 沉浸式：状态栏高度 + 16px间距
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '设置',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
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

  // 复制SettingsPage中的所有方法...
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
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
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(ThemeNotifier themeNotifier, bool isDarkMode) {
    return _buildSwitchSetting(
      title: '夜间模式',
      subtitle: isDarkMode ? '当前为夜间模式' : '当前为日间模式',
      value: isDarkMode,
      onChanged: (value) => themeNotifier.toggleTheme(value),
      icon: isDarkMode ? Icons.dark_mode : Icons.light_mode,
    );
  }

  Widget _buildAnimationToggle() {
    return _buildSwitchSetting(
      title: '动画效果',
      subtitle: '开启页面切换动画',
      value: _enableAnimations,
      onChanged: (value) => setState(() => _enableAnimations = value),
      icon: Icons.animation,
    );
  }

  Widget _buildSwitchSetting({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onChanged(!value);
            _saveSettings();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: (newValue) {
                    onChanged(newValue);
                    _saveSettings();
                  },
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  thumbColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderSetting({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Function(double) onChanged,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.tertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: Theme.of(context).colorScheme.primary,
              inactiveTrackColor: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.3),
              thumbColor: Theme.of(context).colorScheme.primary,
              overlayColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              onChangeEnd: (value) => _saveSettings(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontFamilySelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.font_download,
                  size: 16,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '字体样式',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _fontFamily,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _fontFamilies.map((font) {
              final isSelected = _fontFamily == font;
              return GestureDetector(
                onTap: () {
                  setState(() => _fontFamily = font);
                  _saveSettings();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    font,
                    style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
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
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.tertiary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '关于应用',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      Theme.of(
                        context,
                      ).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
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
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '小元读书',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'v1.0.0',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '优雅的Flutter电子书阅读器',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.8),
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
          padding: const EdgeInsets.all(12.0),
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
              const SizedBox(height: 8),
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
                                  color: Theme.of(context).colorScheme.onSurface
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
