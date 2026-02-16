import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/book.dart';
import '../services/books/book_services.dart';
import '../services/library/library_services.dart';
import '../services/pagination/pagination_services.dart';
import '../services/reading/reading_services.dart';
import '../widgets/side_toast.dart';
import 'import_book_page.dart';
import 'home_layout_constants.dart';
import 'home_shell_page.dart';
import '../utils/layout_helper.dart';
import '../widgets/scrolling_text.dart';
import '../utils/glass_config.dart';
import '../utils/localization_extension.dart';
import '../utils/page_style_helper.dart';
import '../utils/system_ui_helper.dart';
import '../widgets/app_brand_icon.dart';

enum _LibraryFilter {
  all,
  reading,
  finished,
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<Book> _books = [];
  bool _isLoading = true;
  final _bookDao = BookDao();
  StreamSubscription<void>? _librarySubscription;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  _LibraryFilter _selectedFilter = _LibraryFilter.all;

  @override
  void initState() {
    super.initState();
    _loadBooks();
    _librarySubscription = LibraryEventBus().stream.listen((_) {
      if (mounted) {
        _loadBooks();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupThemeBasedImmersiveMode();
  }

  @override
  void dispose() {
    _librarySubscription?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      if (_searchQuery == value) return;
      setState(() => _searchQuery = value);
    });
  }

  bool _shouldApplySystemUI() {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  void _setupThemeBasedImmersiveMode() {
    if (!_shouldApplySystemUI()) {
      return;
    }
    final overlayStyle = SystemUiHelper.overlayStyleForBrightness(
      Theme.of(context).brightness,
    );
    SystemChrome.setSystemUIOverlayStyle(overlayStyle);
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
    try {
      final books = await _bookDao.getAllBooks();
      if (mounted) {
        setState(() {
          _books = books;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    // 检查是否在侧边导航栏模式下
    final navContext = NavigationContext.of(context);
    final useRailNavigation = navContext?.useRailNavigation ?? false;

    // 在侧边导航栏模式下，不显示 Scaffold 和 AppBar
    if (useRailNavigation) {
      return _buildContent(context, useRailNavigation: useRailNavigation);
    }

    // 手机模式：显示完整的 Scaffold + AppBar
    return Scaffold(
      extendBody: true, // 让内容延伸到导航区，配合手势小白条
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiHelper.overlayStyleForBrightness(
          Theme.of(context).brightness,
        ),
      ),
      body: _buildContent(context, useRailNavigation: useRailNavigation),
      // 手机端改为顶部“+”按钮入口，宽屏继续保留FAB
      floatingActionButton:
          LayoutHelper.getNavigationType(context) == NavigationType.rail
              ? _buildFloatingActionButton()
              : null,
    );
  }

  // 提取页面内容部分，在两种模式下共用
  Widget _buildContent(BuildContext context,
      {required bool useRailNavigation}) {
    final books = _visibleBooks;
    final palette = PageStyleHelper.palette(context);
    return Container(
      decoration: BoxDecoration(
        gradient: PageStyleHelper.backgroundGradient(context),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (useRailNavigation) ...[
              _buildTopBar(),
              const SizedBox(height: 10),
            ] else ...[
              const SizedBox(height: kHomeMobileTopBarHeight + 8),
            ],
            _buildSearchBar(),
            const SizedBox(height: 10),
            _buildShelfSummaryCard(),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _books.isEmpty
                      ? _buildEmptyLibrary(compactTop: true)
                      : books.isEmpty
                          ? _buildNoSearchResult()
                          : RefreshIndicator(
                              onRefresh: _loadBooks,
                              strokeWidth: 2.5,
                              displacement: 48,
                              color: Theme.of(context).colorScheme.primary,
                              backgroundColor: palette.cardStrong,
                              child: _buildBooksGrid(books),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  List<Book> get _visibleBooks {
    final filteredByStatus =
        _books.where((book) => _matchesSelectedFilter(book)).toList();
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return filteredByStatus;
    return filteredByStatus.where((book) {
      return book.title.toLowerCase().contains(query) ||
          book.author.toLowerCase().contains(query);
    }).toList();
  }

  bool _matchesSelectedFilter(Book book) {
    switch (_selectedFilter) {
      case _LibraryFilter.all:
        return true;
      case _LibraryFilter.reading:
        return _isReadingBook(book);
      case _LibraryFilter.finished:
        return _isFinishedBook(book);
    }
  }

  bool _isFinishedBook(Book book) {
    if (book.totalPages <= 0) {
      return false;
    }
    return book.currentPage >= book.totalPages;
  }

  bool _isReadingBook(Book book) {
    return book.currentPage > 0 && !_isFinishedBook(book);
  }

  Widget _buildTopBar() {
    final palette = PageStyleHelper.palette(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Text(
            context.l10n.library,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.05,
            ),
          ),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ImportBookPage()),
              );
              if (result == true && mounted) {
                _loadBooks();
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.add_rounded,
                color: palette.iconMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final palette = PageStyleHelper.palette(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: palette.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 18,
              color: palette.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: '搜索书名、作者',
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              InkWell(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: palette.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShelfSummaryCard() {
    final palette = PageStyleHelper.palette(context);
    final total = _books.length;
    final inReading = _books.where(_isReadingBook).length;
    final finished = _books.where(_isFinishedBook).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.hero,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatChip(
              label: '全部 $total',
              active: _selectedFilter == _LibraryFilter.all,
              onTap: () => setState(() => _selectedFilter = _LibraryFilter.all),
            ),
            _buildStatChip(
              label: '在读 $inReading',
              active: _selectedFilter == _LibraryFilter.reading,
              onTap: () =>
                  setState(() => _selectedFilter = _LibraryFilter.reading),
            ),
            _buildStatChip(
              label: '已读 $finished',
              active: _selectedFilter == _LibraryFilter.finished,
              onTap: () =>
                  setState(() => _selectedFilter = _LibraryFilter.finished),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final palette = PageStyleHelper.palette(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.16)
                : palette.cardStrong,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : palette.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    final isTablet = LayoutHelper.isTablet(context);
    final isDesktop = LayoutHelper.isDesktop(context);
    final useRailNav = isTablet || isDesktop;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // 侧边导航栏模式：FAB 在右下角，边距较小
    // 底部导航栏模式：FAB 需要避开导航栏
    final double bottomMargin = useRailNav
        ? bottomPadding + 16 // 侧边导航：只需避开安全区域
        : 68 + 25 + bottomPadding.clamp(0.0, 50.0) + 15; // 底部导航：避开悬浮导航栏

    return Container(
      margin: EdgeInsets.only(bottom: bottomMargin),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          enabled: !GlassEffectConfig.shouldDisableBlur,
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: FloatingActionButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ImportBookPage(),
                ),
              );
              // 导入完成后刷新书籍列表
              if (result == true && mounted) {
                _loadBooks();
              }
            },
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(
                  alpha: GlassEffectConfig.effectiveOpacity(0.9),
                ),
            foregroundColor: Colors.white,
            elevation: 0,
            heroTag: "add_book_fab", // 添加唯一标识避免冲突
            child: const Icon(Icons.add, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyLibrary({bool compactTop = false}) {
    final topInset =
        compactTop ? 20.0 : MediaQuery.of(context).padding.top + 100;
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(40, topInset, 40, 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          // 毛玻璃效果 - 空书架提示卡片
          // ClipRRect + BackdropFilter 组合：圆角 + 模糊背景
          // 适合用于卡片、弹窗等需要突出显示的元素
          child: BackdropFilter(
            enabled: !GlassEffectConfig.shouldDisableBlur,
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // 中等模糊强度
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: GlassEffectConfig.surfaceColor(context, opacity: 0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: AppBrandIcon(
                      size: 60,
                      borderRadius: 16,
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '开启阅读之旅',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '你的书架还是空的\n点击右上角的 "+" 按钮\n添加你的第一本书吧',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ImportBookPage(),
                        ),
                      );
                      _loadBooks();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('导入书籍'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoSearchResult() {
    final hasSearch = _searchQuery.trim().isNotEmpty;
    final message = hasSearch
        ? '没有匹配的书籍'
        : switch (_selectedFilter) {
            _LibraryFilter.reading => '当前没有在读书籍',
            _LibraryFilter.finished => '当前没有已读书籍',
            _LibraryFilter.all => '暂无书籍',
          };

    return Center(
      child: Text(
        message,
        style: TextStyle(
          fontSize: 16,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildBooksGrid(List<Book> books) {
    final useRail =
        LayoutHelper.getNavigationType(context) == NavigationType.rail;
    if (!useRail) {
      return _buildBooksList(books);
    }

    final isDesktop = LayoutHelper.isDesktop(context);
    final isTablet = LayoutHelper.isTablet(context);
    final media = MediaQuery.of(context);
    final isTabletLandscape = isTablet && media.size.width > media.size.height;

    // 毛玻璃效果增强 - 网格容器背景
    // 为整个书籍网格添加细微的毛玻璃背景层

    // 使用 LayoutHelper 获取响应式列数和纵横比
    int crossAxisCount = LayoutHelper.getBookGridColumns(context);

    // 根据屏幕类型调整间距
    double spacing;
    if (isDesktop) {
      spacing = 16;
    } else if (isTablet) {
      spacing = 14;
    } else {
      spacing = 12;
    }

    final gap = isTabletLandscape
        ? 6.0
        : isTablet
            ? 5.0
            : 6.0;
    final textHeight = isTabletLandscape
        ? 50.0
        : isTablet
            ? 40.0
            : 36.0;
    final coverWidthScale = isTabletLandscape ? 0.75 : 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 让网格高度为 3:4 封面 + 文本区域预留高度
        const double horizontalPadding = 32.0;
        final totalSpacing = spacing * (crossAxisCount - 1);
        final availableWidth = math.max(
          0.0,
          constraints.maxWidth - horizontalPadding - totalSpacing,
        );
        final itemWidth = availableWidth / crossAxisCount;
        final itemHeight =
            ((itemWidth * coverWidthScale) * 4 / 3) + textHeight + gap;
        final childAspectRatio = itemWidth > 0 ? itemWidth / itemHeight : 0.75;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.3, 0.7, 1.0],
              colors: [
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
                Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.03),
                Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withValues(alpha: 0.03),
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: GridView.builder(
            cacheExtent: 720,
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              // 精确计算悬浮导航栏占用空间：导航栏68px + 边距25px + 底部安全区域(限制最大值) + 10px缓冲
              68 +
                  25 +
                  (MediaQuery.of(context).padding.bottom).clamp(0.0, 50.0) +
                  10,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing + 8,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return RepaintBoundary(
                child: _BookCoverItem(
                  book: book,
                  onTap: () async {
                    final fullBook = await _bookDao.getBookById(book.id!);
                    if (fullBook != null && mounted && context.mounted) {
                      // 直接打开沉浸式阅读器
                      await ReadingRouterService.openBook(context, fullBook);
                      _loadBooks();
                    }
                  },
                  onLongPress: () => _showBookOptions(book),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBooksList(List<Book> books) {
    return ListView.builder(
      cacheExtent: 720,
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        68 + 25 + MediaQuery.of(context).padding.bottom.clamp(0.0, 50.0) + 12,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        final progress = book.totalPages > 0
            ? (book.currentPage / book.totalPages).clamp(0.0, 1.0)
            : 0.0;
        final progressText = '${(progress * 100).round()}% · 继续阅读';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Material(
            color:
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final fullBook = await _bookDao.getBookById(book.id!);
                if (fullBook != null && mounted && context.mounted) {
                  await ReadingRouterService.openBook(context, fullBook);
                  _loadBooks();
                }
              },
              onLongPress: () => _showBookOptions(book),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 64,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _buildListCover(context, book),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            progressText,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.58),
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 5,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.12),
                              valueColor: AlwaysStoppedAnimation(
                                  Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.35),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListCover(BuildContext context, Book book) {
    if (book.coverImagePath != null && book.coverImagePath!.isNotEmpty) {
      return Image.file(
        File(book.coverImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildListDefaultCover(context, book),
      );
    }
    return _buildListDefaultCover(context, book);
  }

  Widget _buildListDefaultCover(BuildContext context, Book book) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: const Center(
        child: AppBrandIcon(
          size: 32,
          borderRadius: 8,
        ),
      ),
    );
  }

  void _showBookOptions(Book book) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          enabled: !GlassEffectConfig.shouldDisableBlur,
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            decoration: BoxDecoration(
              color: GlassEffectConfig.surfaceColor(context, opacity: 0.95),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 拖拽指示条
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // 书籍信息头部
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        // 书籍封面缩略图
                        Container(
                          width: 50,
                          height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.8),
                                Theme.of(context)
                                    .colorScheme
                                    .secondary
                                    .withValues(alpha: 0.6),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: book.coverImagePath != null &&
                                  book.coverImagePath!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(book.coverImagePath!),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Center(
                                  child: AppBrandIcon(
                                    size: 24,
                                    borderRadius: 6,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 16),
                        // 书籍信息
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                book.author,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              // 阅读进度
                              Row(
                                children: [
                                  AppBrandIcon(
                                    size: 14,
                                    borderRadius: 4,
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.22),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${((book.currentPage / (book.totalPages > 0 ? book.totalPages : 1)) * 100).toStringAsFixed(1)}%',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 分隔线
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.15),
                  ),

                  // 操作选项
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      children: [
                        // 继续阅读
                        _buildOptionItem(
                          context: context,
                          icon: Icons.play_circle_outline,
                          iconColor: Theme.of(context).colorScheme.primary,
                          title: '继续阅读',
                          subtitle: book.currentPage > 0
                              ? '第 ${book.currentPage} 页'
                              : '从头开始',
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.15),
                          onTap: () async {
                            Navigator.pop(context);
                            final fullBook =
                                await _bookDao.getBookById(book.id!);
                            if (fullBook != null && context.mounted) {
                              await ReadingRouterService.openBook(
                                  context, fullBook);
                              _loadBooks();
                            }
                          },
                        ),
                        const SizedBox(height: 8),

                        // 书籍信息
                        _buildOptionItem(
                          context: context,
                          icon: Icons.info_outline,
                          iconColor: Theme.of(context).colorScheme.tertiary,
                          title: '书籍信息',
                          subtitle:
                              '${book.format.toUpperCase()} · ${book.totalPages} 页',
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .tertiaryContainer
                              .withValues(alpha: 0.15),
                          onTap: () {
                            Navigator.pop(context);
                            _showBookInfo(book);
                          },
                        ),
                        const SizedBox(height: 8),

                        // 删除书籍
                        _buildOptionItem(
                          context: context,
                          icon: Icons.delete_outline_rounded,
                          iconColor: Theme.of(context).colorScheme.error,
                          title: '删除书籍',
                          subtitle: '将永久删除此书籍',
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .errorContainer
                              .withValues(alpha: 0.15),
                          onTap: () {
                            Navigator.pop(context);
                            _confirmDeleteBook(book);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建操作选项项
  Widget _buildOptionItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示书籍详细信息
  void _showBookInfo(Book book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('书籍信息'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('书名', book.title),
            const SizedBox(height: 12),
            _buildInfoRow('作者', book.author),
            const SizedBox(height: 12),
            _buildInfoRow('格式', book.format.toUpperCase()),
            const SizedBox(height: 12),
            _buildInfoRow('总页数', '${book.totalPages} 页'),
            const SizedBox(height: 12),
            _buildInfoRow('当前页', '${book.currentPage} 页'),
            const SizedBox(height: 12),
            _buildInfoRow(
              '阅读进度',
              '${((book.currentPage / (book.totalPages > 0 ? book.totalPages : 1)) * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteBook(Book book) {
    showDialog(
      context: context,
      builder: (context) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          // 毛玻璃效果 - 确认对话框
          // 为删除确认对话框添加精美的毛玻璃背景
          child: BackdropFilter(
            enabled: !GlassEffectConfig.shouldDisableBlur,
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), // 高强度模糊突出对话框
            child: AlertDialog(
              backgroundColor: GlassEffectConfig.surfaceColor(
                context,
                opacity: 0.95,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                '确认删除',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              content: Text('确定要删除《${book.title}》吗？文件将从设备中永久移除。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () async {
                    // Store the Navigator and toast context before the async gap.
                    final navigator = Navigator.of(context);
                    final toastContext = this.context;

                    // 关闭确认对话框
                    navigator.pop();

                    // 显示删除进度对话框
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => PopScope(
                        canPop: false,
                        child: AlertDialog(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.95),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          content: Row(
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Text(
                                  '正在删除《${book.title}》...',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );

                    try {
                      // 在后台执行删除操作
                      await _performBookDeletion(book);
                      if (!mounted) return;

                      // 关闭进度对话框
                      navigator.pop();

                      _loadBooks();
                      if (!toastContext.mounted) return;
                      showSideToast(toastContext, '《${book.title}》已删除');
                    } catch (e) {
                      if (!mounted) return;
                      // 关闭进度对话框
                      navigator.pop();

                      // Handle error
                      if (!toastContext.mounted) return;
                      showSideToast(toastContext, '删除失败: $e');
                    }
                  },
                  child: Text(
                    '删除',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 执行书籍删除操作（在后台执行）
  ///
  /// 彻底删除书籍及其所有相关文件和缓存：
  /// 1. 删除书籍原文件
  /// 2. 删除封面图片文件
  /// 3. 删除分页缓存文件
  /// 4. 删除数据库记录（会级联删除笔记、书签等）
  ///
  /// 参数 [onProgress] 进度回调，用于更新UI提示信息
  Future<void> _performBookDeletion(
    Book book, {
    void Function(String message)? onProgress,
  }) async {
    debugPrint('🗑️ 开始删除书籍: ${book.title}');
    final startTime = DateTime.now();

    try {
      // 1. 删除书籍文件
      onProgress?.call('删除书籍文件...');
      final file = File(book.filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('✅ 已删除书籍文件: ${book.filePath}');
      } else {
        debugPrint('⚠️ 书籍文件不存在: ${book.filePath}');
      }

      // 2. 删除封面图片文件
      onProgress?.call('删除封面图片...');
      if (book.coverImagePath != null && book.coverImagePath!.isNotEmpty) {
        final coverFile = File(book.coverImagePath!);
        if (await coverFile.exists()) {
          await coverFile.delete();
          debugPrint('✅ 已删除封面图片: ${book.coverImagePath}');
        }
      }

      // 3. 删除书籍的分页缓存（优化后的超高性能版本）
      onProgress?.call('清理分页缓存...');
      if (book.contentHash != null && book.contentHash!.isNotEmpty) {
        await PaginationCacheService.deleteCacheForBookFast(
          book.contentHash!,
        );
        debugPrint('✅ 已删除分页缓存');
      }

      // 4. 清理阅读进度缓存
      onProgress?.call('清理阅读进度...');
      final progressService = ReadingProgressService();
      await progressService.clearProgress(book.id!.toString());
      debugPrint('✅ 已删除阅读进度缓存');

      // 5. 删除数据库记录（会级联删除笔记、书签等）
      onProgress?.call('清理数据库记录...');
      await _bookDao.deleteBook(book.id!);
      debugPrint('✅ 已删除数据库记录');

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('🎉 书籍删除完成: ${book.title} (总耗时: ${duration}ms)');
      onProgress?.call('删除完成');
    } catch (e, stackTrace) {
      debugPrint('❌ 删除书籍失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
      rethrow;
    }
  }
}

class _BookCoverItem extends StatelessWidget {
  final Book book;
  final Future<void> Function() onTap;
  final VoidCallback onLongPress;

  const _BookCoverItem({
    required this.book,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        book.currentPage / (book.totalPages > 0 ? book.totalPages : 1);

    return InkWell(
      onTap: () => unawaited(onTap()),
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = LayoutHelper.isTablet(context);
          final media = MediaQuery.of(context);
          final isTabletLandscape =
              isTablet && media.size.width > media.size.height;
          final gap = isTabletLandscape
              ? 6.0
              : isTablet
                  ? 5.0
                  : 6.0;
          final textHeight = isTabletLandscape
              ? 50.0
              : isTablet
                  ? 40.0
                  : 36.0;
          final coverWidthScale = isTabletLandscape ? 0.75 : 1.0;
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;
          final coverWidth = maxWidth * coverWidthScale;
          final targetCoverHeight = coverWidth * 4 / 3;
          final availableCoverHeight =
              math.max(0.0, maxHeight - textHeight - gap);
          final coverHeight = math.min(availableCoverHeight, targetCoverHeight);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 书籍封面区域 - 3:4比例，但不超过可用高度
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: coverWidth,
                  height: coverHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // 封面图片或默认图标
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildCoverImage(context, book),
                        ),
                        // 阅读进度指示器（仅在有进度时显示）
                        if (progress > 0)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progress.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(12),
                                      bottomRight: Radius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // "在读"标签
                        if (book.currentPage > 0)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                '在读',
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: gap),
              // 书籍信息区域 - 固定高度
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: coverWidth,
                  height: textHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 书名：超长时自动滚动
                        Expanded(
                          child: ScrollingText(
                            text: book.title,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      height: 1.15,
                                    ),
                            duration: const Duration(seconds: 5),
                            pauseDuration: const Duration(milliseconds: 1200),
                          ),
                        ),
                        SizedBox(height: isTabletLandscape ? 1.5 : 2),
                        // 作者信息
                        Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withValues(
                                          alpha: 0.6,
                                        ),
                                    fontSize: 11,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context, Book book) {
    if (book.coverImagePath != null && book.coverImagePath!.isNotEmpty) {
      // 有封面图片时，直接显示真实的书籍封面
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Image.file(
          File(book.coverImagePath!),
          fit: BoxFit.cover, // 填充整个容器，保持图片比例
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultCover(context);
          },
        ),
      );
    } else {
      // 没有封面图片时，显示默认封面设计
      return _buildDefaultCover(context);
    }
  }

  /// 构建默认封面设计
  Widget _buildDefaultCover(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppBrandIcon(
            size: 48,
            borderRadius: 12,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              book.title,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
