import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/book.dart';
import '../services/book_dao.dart';
import 'import_book_page.dart';
import 'reading_mode_selector.dart';
import '../utils/responsive_helper.dart';
import '../utils/page_transitions.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<Book> _books = [];
  bool _isLoading = true;
  final _bookDao = BookDao();

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
    try {
      final books = await _bookDao.getAllBooks();
      setState(() {
        _books = books;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
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
          surfaceTintColor: Colors.transparent, // 添加这个属性移除Material 3的色调
          scrolledUnderElevation: 0, // 滚动时也保持透明
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.8),
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
                      strokeWidth: 2.5, // 减细刷新指示器线条
                      displacement: 60, // 增加下拉距离
                      color: Theme.of(context).colorScheme.primary, // 主题色
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.9), // 半透明背景
                      child: _buildBooksGrid(),
                    ),
              // 移除顶部自定义 Positioned 毛玻璃，改用 AppBar 的 flexibleSpace
            ],
          ),
        ),
        // 悬浮添加书籍按钮
        floatingActionButton: Container(
          margin: const EdgeInsets.only(bottom: 80), // 向上移动80px
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
                  if (result == true || mounted) {
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
        ),
      ),
    );
  }

  Widget _buildEmptyLibrary() {
    final topInset = MediaQuery.of(context).padding.top;
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          40,
          topInset + kToolbarHeight + 40,
          40,
          40,
        ),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final topInset = MediaQuery.of(context).padding.top;

    // 毛玻璃效果增强 - 网格容器背景
    // 为整个书籍网格添加细微的毛玻璃背景层

    int crossAxisCount;
    double childAspectRatio;
    double spacing;

    if (isDesktop) {
      crossAxisCount = 5; // 桌面增加到5列，显示更多书籍
      childAspectRatio = 0.55; // 更长的书籍比例，稍微加长
      spacing = 16;
    } else if (isTablet) {
      crossAxisCount = 4; // 平板4列
      childAspectRatio = 0.55; // 更长的书籍比例，稍微加长
      spacing = 14;
    } else {
      // 根据屏幕宽度动态调整列数
      if (screenWidth > 360) {
        crossAxisCount = 3; // 手机增加到3列
        childAspectRatio = 0.55; // 更长的书籍比例，稍微加长
      } else {
        crossAxisCount = 2; // 小屏幕保持2列
        childAspectRatio = 0.6; // 小屏幕稍微调整比例
      }
      spacing = 12;
    }

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
          topInset + kToolbarHeight + 16,
          16,
          MediaQuery.of(context).padding.bottom + 20,
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
              if (fullBook != null && mounted) {
                if (context.mounted) {
                  // 使用优化的阅读页面过渡动画，减少卡顿
                  await Navigator.of(context).pushReaderPage(
                    ReadingModeSelector(
                      book: fullBook,
                      initialChapterIndex: 0,
                      initialProgress:
                          fullBook.currentPage /
                          (fullBook.totalPages > 0 ? fullBook.totalPages : 1),
                    ),
                  );
                }
              }
              _loadBooks();
            },
            onLongPress: () => _showBookOptions(book),
          );
        },
      ),
    );
  }

  void _showBookOptions(Book book) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // 设置背景透明以支持毛玻璃效果
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        // 毛玻璃效果 - 底部弹窗
        // 为操作选项弹窗创建高级的毛玻璃效果
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25), // 较强模糊创造深度感
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Wrap(
              children: [
                // 手势拖拽指示条（仅保留白条本体，无额外纯色背景）
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                ),
                Container(
                  // 毛玻璃效果 - 列表项容器
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.errorContainer.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      '删除书籍',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context); // 先关闭底部弹窗
                      _confirmDeleteBook(book);
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
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
                    // Store the Navigator and ScaffoldMessenger before the async gap.
                    final navigator = Navigator.of(context);
                    final scaffoldMessenger = ScaffoldMessenger.of(context);

                    try {
                      final file = File(book.filePath);
                      if (await file.exists()) {
                        await file.delete();
                      }
                      await _bookDao.deleteBook(book.id!);

                      navigator.pop();
                      _loadBooks();
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text('《${book.title}》已删除')),
                      );
                    } catch (e) {
                      // Handle error
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 书籍封面区域 - 占据主要空间
          Expanded(
            flex: 8, // 给封面最多空间
            child: Container(
              width: double.infinity,
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
          // 书籍信息区域 - 紧凑显示
          Expanded(
            flex: 2, // 给文本信息适当空间
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 书名
                  Flexible(
                    flex: 2,
                    child: Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // 作者信息
                  Flexible(
                    flex: 1,
                    child: Text(
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
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context, Book book) {
    if (book.coverImagePath != null &&
        File(book.coverImagePath!).existsSync()) {
      // 有封面图片时，直接显示真实的书籍封面
      return Container(
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
