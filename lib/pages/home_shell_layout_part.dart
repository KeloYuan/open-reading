part of 'home_shell_page.dart';

/// 首页壳层的大块布局方法拆分到这里：
/// - 系统栏沉浸式设置
/// - Rail 布局
/// - 手机底部导航布局
/// - 页面包装与导入跳转
extension _HomeShellLayoutPart on _HomeShellPageState {
  bool _shouldApplySystemUI() {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  // 页面级沉浸式设置
  void _setupPageImmersiveMode() {
    if (!_shouldApplySystemUI()) {
      return;
    }
    // 强制启用边到边模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // 初始样式跟随当前主题亮度
    final overlayStyle = SystemUiHelper.overlayStyleForBrightness(
      Theme.of(context).brightness,
    );
    SystemChrome.setSystemUIOverlayStyle(overlayStyle);
  }

  // 基于主题的沉浸式设置 (在didChangeDependencies中调用)
  void _setupThemeBasedImmersiveMode() {
    if (!_shouldApplySystemUI()) {
      return;
    }
    final overlayStyle = SystemUiHelper.overlayStyleForBrightness(
      Theme.of(context).brightness,
    );

    // 使用 microtask 确保在当前帧渲染后执行
    Future.microtask(() {
      if (!mounted) return;
      SystemChrome.setSystemUIOverlayStyle(overlayStyle);
    });
  }

  /// 平板/桌面布局：左侧 NavigationRail + 右侧页面内容。
  ///
  /// 说明：
  /// - 这里不走 PageView，因为宽屏更适合“立刻切页”的应用范式。
  /// - 右侧直接渲染当前 index 对应页面，结构更直观。
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
                  width: LayoutHelper.getValue(
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
                    onDestinationSelected: _updateSelectedIndex,
                    extended: LayoutHelper.getValue(
                      context,
                      mobile: false,
                      tablet: true, // 平板显示扩展导航，方便使用
                      desktop: true, // 桌面也显示扩展导航
                    ),
                    labelType: LayoutHelper.getValue(
                      context,
                      mobile: NavigationRailLabelType.all,
                      tablet: NavigationRailLabelType.none, // 平板使用扩展模式，不需要额外标签
                      desktop: NavigationRailLabelType.none, // 桌面同样
                    ),
                    leading: LayoutHelper.isWideScreen(context)
                        ? _buildNavigationHeader()
                        : null,
                    minWidth: 60,
                    minExtendedWidth: LayoutHelper.getValue(
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
            Expanded(
              child: NavigationContext(
                useRailNavigation: true,
                child: _resolveRailPage(_navigationItems[_selectedIndex].page),
              ),
            ),
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
                    label: Text(context.l10n.importBooks),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  /// 手机布局：PageView + 底部悬浮药丸导航。
  ///
  /// 说明：
  /// - PageView 负责横向切页手势。
  /// - 药丸导航负责显式点击切页。
  /// - 两者通过 `_selectedIndex` + `_pageController` 保持同步。
  Widget _buildBottomNavigation() {
    final mediaQuery = MediaQuery.of(context);
    final metrics = _computeBottomNavMetrics(mediaQuery);
    final navigationCount = _navigationItems.length;
    const desiredItemWidth = 72.0;
    final desiredNavWidth = navigationCount * desiredItemWidth + 28;
    final maxNavWidth = mediaQuery.size.width - 44;
    final minNavWidth = navigationCount >= 4 ? 228.0 : 200.0;
    final navWidth = maxNavWidth <= minNavWidth
        ? maxNavWidth
        : desiredNavWidth.clamp(minNavWidth, maxNavWidth).toDouble();

    return Scaffold(
      extendBody: true, // 让body延伸到底部导航栏后面
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // 使用与书库页面完全相同的设置 - 完全透明且高度为0
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0, // 设置高度为0，让毛玻璃标题栏在body中实现
        systemOverlayStyle: SystemUiHelper.overlayStyleForBrightness(
          Theme.of(context).brightness,
        ),
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
                  _updateSelectedIndex(index);
                });
              }
            },
            // 优化滚动物理效果，减少过度滚动
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            // 禁用页面捕捉以减少卡顿
            pageSnapping: true,
            children: _navigationItems.map((item) {
              // 使用RepaintBoundary和AutomaticKeepAliveClientMixin优化重绘和内存管理
              return RepaintBoundary(child: _buildPageWrapper(item.page));
            }).toList(),
          ),
          _buildMobileTopBarOverlay(mediaQuery),
          // 悬浮药丸导航栏
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: metrics.navContainerHeight,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: metrics.navBottomInset),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: GlassEffectConfig.navigationBarBlur,
                        sigmaY: GlassEffectConfig.navigationBarBlur,
                      ),
                      child: Container(
                        width: navWidth,
                        height: kHomeMobileFloatingNavHeight,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(
                                alpha: GlassEffectConfig.navigationBarOpacity,
                              ),
                          borderRadius: BorderRadius.circular(60),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.15),
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 30,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 60,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children:
                              _navigationItems.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final isSelected = _selectedIndex == index;

                            return Expanded(
                              child: HomeBounceNavigationItem(
                                item: item,
                                isSelected: isSelected,
                                onTap: () => _switchToTab(index),
                              ),
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

  Widget _buildMobileTopBarOverlay(MediaQueryData mediaQuery) {
    if (_navigationItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentItem = _navigationItems[_selectedIndex];
    final currentPage = currentItem.page;
    final title = currentItem.label;
    Widget? trailing;

    if (currentPage is HomeDashboardPage) {
      final settingsIndex = _navigationItems.indexWhere(
        (item) => item.page is SettingsPage,
      );
      if (settingsIndex >= 0) {
        trailing = _buildTopBarActionButton(
          icon: Icons.settings_outlined,
          onTap: () => _switchToTab(settingsIndex),
        );
      }
    } else if (currentPage is LibraryPage) {
      trailing = _buildTopBarActionButton(
        icon: Icons.add_rounded,
        onTap: _navigateToImport,
      );
    } else if (currentPage is BookSourcePage) {
      trailing = _buildBookSourceTopBarActions();
    } else if (currentPage is SettingsPage) {
      trailing = null;
    } else {
      // 其他自定义页不强行覆盖标题，避免和页面自身顶部冲突。
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: HomeMobileTopBarWidget(
        title: title,
        trailing: trailing,
      ),
    );
  }

  Widget _buildTopBarActionButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final button = InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
            width: 0.5,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78),
        ),
      ),
    );
    if (tooltip == null || tooltip.isEmpty) {
      return button;
    }
    return Tooltip(message: tooltip, child: button);
  }

  Widget _buildBookSourceTopBarActions() {
    final sourceState = _bookSourcePageKey.currentState;
    final isFiltersOpen = sourceState?.isFiltersPanelVisible ?? false;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTopBarActionButton(
          icon: Icons.add_rounded,
          tooltip: '添加书源',
          onTap: () => sourceState?.handleTopBarAdd(),
        ),
        const SizedBox(width: 8),
        _buildTopBarActionButton(
          icon: Icons.tune_rounded,
          tooltip: isFiltersOpen ? '收起筛选' : '展开筛选',
          onTap: () {
            sourceState?.handleTopBarToggleFilters();
            _updateSelectedIndex(_selectedIndex);
          },
        ),
        const SizedBox(width: 8),
        _buildTopBarActionButton(
          icon: Icons.more_horiz_rounded,
          tooltip: '更多选项',
          onTap: () => sourceState?.handleTopBarMore(),
        ),
      ],
    );
  }

  void _switchToTab(int index) {
    if (index < 0 || index >= _navigationItems.length) return;
    if (_selectedIndex == index) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSelectedIndex(index);
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// 统一计算手机底部导航相关尺寸，避免多处重复公式导致错位。
  _BottomNavMetrics _computeBottomNavMetrics(MediaQueryData mediaQuery) {
    final safeBottom = mediaQuery.padding.bottom.clamp(
      0.0,
      kHomeMobileSafeBottomMax,
    );
    final navBottomInset = safeBottom + kHomeMobileFloatingNavBottomGap;
    final navContainerHeight = kHomeMobileFloatingNavHeight + navBottomInset;
    return _BottomNavMetrics(
      safeBottom: safeBottom,
      navBottomInset: navBottomInset,
      navContainerHeight: navContainerHeight,
    );
  }

  /// 宽屏下的页面解析：
  /// 让首页和手机端保持一致视觉来源，避免“改了首页但宽屏不生效”。
  Widget _resolveRailPage(Widget page) {
    if (page is HomeDashboardPage) {
      return const HomeMobileDashboardPage();
    }
    return page;
  }

  Widget _buildPageWrapper(Widget page) {
    // 这里是“页面装配中心”：
    // 不同页面统一在这里包壳（顶栏、背景、系统UI处理）。
    // 这样以后你要替换某个页面的外壳，只改这里。
    Widget wrappedPage;

    // 手机端针对不同页面应用不同包装策略。
    if (page is HomeDashboardPage) {
      wrappedPage = const HomeMobileDashboardPage();
    } else {
      // 其余页面统一背景包装。
      wrappedPage = HomeGenericPageWrapper(child: page);
    }

    // KeepAlive 能让 tab 切换时保留页面状态（滚动位置/已加载数据）。
    return HomeKeepAlivePageWrapper(child: wrappedPage);
  }

  void _navigateToImport() {
    // 导入页使用标准 Material 路由，避免透明叠加时出现黑底观感。
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ImportBookPage()),
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
            child: const AppBrandIcon(
              size: 40,
              borderRadius: 12,
            ),
          ),
          if (LayoutHelper.getValue(
            context,
            mobile: false,
            tablet: true,
            desktop: true,
          )) ...[
            const SizedBox(height: 12),
            Text(
              context.l10n.appTitle,
              style: TextStyle(
                fontSize: LayoutHelper.getValue(
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
              context.l10n.homeTagline,
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
