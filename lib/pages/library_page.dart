import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/book.dart';
import '../services/book_dao.dart';
import '../services/reading_router_service.dart';
import '../services/pagination_cache_service.dart';
import '../services/reading_progress_service.dart';
import '../services/library_event_bus.dart';
import '../widgets/side_toast.dart';
import 'import_book_page.dart';
import 'home_page_responsive.dart';
import '../utils/responsive_helper.dart';
import '../widgets/scrolling_text.dart';
// import '../utils/glass_config.dart';

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

  @override
  void initState() {
    super.initState();
    _loadBooks();
    _setupPageImmersiveMode();
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
    super.dispose();
  }

  bool _shouldApplySystemUI() {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  // 与首页一致的沉浸式处理，确保安卓手势提示线“干净”
  void _setupPageImmersiveMode() {
    if (!_shouldApplySystemUI()) {
      return;
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
    );
  }

  void _setupThemeBasedImmersiveMode() {
    if (!_shouldApplySystemUI()) {
      return;
    }
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
      return _buildContent(context);
    }

    // 手机模式：显示完整的 Scaffold + AppBar
    return Scaffold(
      extendBody: true, // 让内容延伸到导航区，配合手势小白条
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          '书库',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.8),
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _buildContent(context),
      // 悬浮添加书籍按钮 - 适配平板侧边导航栏
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  // 提取页面内容部分，在两种模式下共用
  Widget _buildContent(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.3, 0.6, 1.0],
            colors: [
              Theme.of(
                context,
              ).colorScheme.secondaryContainer.withValues(alpha: 0.12),
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
              Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.08),
              Theme.of(
                context,
              ).colorScheme.tertiaryContainer.withValues(alpha: 0.10),
            ],
          ),
        ),
        child: Stack(
          children: [
            // 主内容
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _books.isEmpty
                    ? _buildEmptyLibrary()
                    : RefreshIndicator(
                        onRefresh: _loadBooks,
                        strokeWidth: 2.5,
                        displacement: 60,
                        color: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: 0.9),
                        child: _buildBooksGrid(),
                      ),
            // 顶部自定义 Positioned 已移除，沿用 AppBar 的 flexibleSpace
          ],
        ),
      );
  }

  Widget _buildFloatingActionButton() {
    final isTablet = ResponsiveHelper.isTablet(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);
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
            ).colorScheme.primary.withValues(alpha: 0.9),
            foregroundColor: Colors.white,
            elevation: 0,
            heroTag: "add_book_fab", // 添加唯一标识避免冲突
            child: const Icon(Icons.add, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyLibrary() {
    final topInset = MediaQuery.of(context).padding.top;
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(40, topInset + 60 + 40, 40, 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          // 毛玻璃效果 - 空书架提示卡片
          // ClipRRect + BackdropFilter 组合：圆角 + 模糊背景
          // 适合用于卡片、弹窗等需要突出显示的元素
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // 中等模糊强度
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.8),
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
                    child: Icon(
                      Icons.auto_stories,
                      size: 60,
                      color: Theme.of(context).colorScheme.primary,
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

  Widget _buildBooksGrid() {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final topInset = MediaQuery.of(context).padding.top;

    // 毛玻璃效果增强 - 网格容器背景
    // 为整个书籍网格添加细微的毛玻璃背景层

    // 使用 ResponsiveHelper 获取响应式列数和纵横比
    int crossAxisCount = ResponsiveHelper.getBookGridColumns(context);

    // 根据屏幕类型调整间距
    double spacing;
    if (isDesktop) {
      spacing = 16;
    } else if (isTablet) {
      spacing = 14;
    } else {
      spacing = 12;
    }

    final gap = isTablet ? 4.0 : 6.0;
    final textHeight = isTablet ? 26.0 : 36.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 让网格高度为 3:4 封面 + 文本区域预留高度
        final horizontalPadding = 16.0 * 2;
        final totalSpacing = spacing * (crossAxisCount - 1);
        final availableWidth = math.max(
          0.0,
          constraints.maxWidth - horizontalPadding - totalSpacing,
        );
        final itemWidth = availableWidth / crossAxisCount;
        final itemHeight = (itemWidth * 4 / 3) + textHeight + gap;
        final childAspectRatio =
            itemWidth > 0 ? itemWidth / itemHeight : 0.75;

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
            padding: EdgeInsets.fromLTRB(
              16,
              topInset + 60 + 16,
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
            itemCount: _books.length,
            itemBuilder: (context, index) {
              final book = _books[index];
              return _BookCoverItem(
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
              );
            },
          ),
        );
      },
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
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
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
                                  File(book.coverImagePath!).existsSync()
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(book.coverImagePath!),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(
                                  Icons.menu_book,
                                  color: Colors.white,
                                  size: 24,
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
                                  Icon(
                                    Icons.auto_stories,
                                    size: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.7),
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
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), // 高强度模糊突出对话框
            child: AlertDialog(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.95),
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

                      // 关闭进度对话框
                      Navigator.of(context).pop();

                      _loadBooks();
                      showSideToast(toastContext, '《${book.title}》已删除');
                    } catch (e) {
                      // 关闭进度对话框
                      Navigator.of(context).pop();

                      // Handle error
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
  final VoidCallback onTap;
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
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = ResponsiveHelper.isTablet(context);
          final gap = isTablet ? 4.0 : 6.0;
          final textHeight = isTablet ? 26.0 : 36.0;
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;
          final targetCoverHeight = maxWidth * 4 / 3;
          final availableCoverHeight =
              math.max(0.0, maxHeight - textHeight - gap);
          final coverHeight =
              math.min(availableCoverHeight, targetCoverHeight);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 书籍封面区域 - 3:4比例，但不超过可用高度
              SizedBox(
                width: double.infinity,
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
                                  color: Theme.of(context).colorScheme.primary,
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
                                color: Theme.of(context).colorScheme.onPrimary,
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
              SizedBox(height: gap),
              // 书籍信息区域 - 固定高度
              SizedBox(
                height: textHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 书名 - 使用滚动文本
                      Expanded(
                        child: ScrollingText(
                          text: book.title,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                          duration: const Duration(seconds: 4),
                          pauseDuration: const Duration(milliseconds: 1500),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // 作者信息
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                      ),
                    ],
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
    if (book.coverImagePath != null &&
        File(book.coverImagePath!).existsSync()) {
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
          Icon(Icons.menu_book, size: 48, color: Colors.white),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              book.title,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
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
