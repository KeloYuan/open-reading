import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/book.dart';
import '../services/book_dao.dart';
import 'import_book_page.dart';
import 'reading_page_enhanced.dart';
import '../utils/responsive_helper.dart';
import '../utils/color_extensions.dart';

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
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.3, 0.6, 1.0],
              colors: [
                Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withOpacityValues(0.12),
                Theme.of(context).colorScheme.surface.withOpacityValues(0.98),
                Theme.of(
                  context,
                ).colorScheme.primaryContainer.withOpacityValues(0.08),
                Theme.of(
                  context,
                ).colorScheme.tertiaryContainer.withOpacityValues(0.10),
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
                      ).colorScheme.primary.withOpacityValues(0.06),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
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
                ).colorScheme.primary.withOpacityValues(0.3),
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
                ).colorScheme.primary.withOpacityValues(0.9),
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
                ).colorScheme.surface.withOpacityValues(0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withOpacityValues(0.2),
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
                      ).colorScheme.primary.withOpacityValues(0.1),
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
                      ).colorScheme.onSurface.withOpacityValues(0.7),
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
      crossAxisCount = 4; // 桌面4列
      childAspectRatio = 0.65; // 调整比例，防止溢出
      spacing = 20;
    } else if (isTablet) {
      crossAxisCount = 3; // 平板3列
      childAspectRatio = 0.6; // 调整比例
      spacing = 16;
    } else {
      // 根据屏幕宽度动态调整列数
      if (screenWidth > 360) {
        crossAxisCount = 2;
        childAspectRatio = 0.65; // 给文本更多空间
      } else {
        crossAxisCount = 2;
        childAspectRatio = 0.6; // 小屏幕进一步调整
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
            Theme.of(context).colorScheme.surface.withOpacityValues(0.0),
            Theme.of(
              context,
            ).colorScheme.primaryContainer.withOpacityValues(0.03),
            Theme.of(
              context,
            ).colorScheme.secondaryContainer.withOpacityValues(0.03),
            Theme.of(context).colorScheme.surface.withOpacityValues(0.0),
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
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReadingPageEnhanced(book: fullBook),
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
              ).colorScheme.surface.withOpacityValues(0.9),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withOpacityValues(0.2),
                  width: 1,
                ),
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
                    ).colorScheme.errorContainer.withOpacityValues(0.1),
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
              ).colorScheme.surface.withOpacityValues(0.95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withOpacityValues(0.2),
                  width: 1,
                ),
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
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7, // 给封面更多空间
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacityValues(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    // 毛玻璃效果 - 书籍封面卡片
                    // 为每本书的封面创建磨砂玻璃效果
                    // 结合渐变色和透明度创造层次感
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 20,
                        sigmaY: 20,
                      ), // 封面模糊效果
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withOpacityValues(0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withOpacityValues(0.2),
                            width: 1,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.primaryContainer
                                  .withOpacityValues(0.3),
                              Theme.of(context).colorScheme.secondaryContainer
                                  .withOpacityValues(0.3),
                            ],
                          ),
                        ),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // 毛玻璃效果 - 书籍图标容器
                                          // 为书籍图标添加细腻的毛玻璃背景效果
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(
                                                sigmaX: 8,
                                                sigmaY: 8,
                                              ), // 微妙模糊
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withOpacityValues(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .withOpacityValues(0.2),
                                                    width: 0.5,
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.menu_book,
                                                  size: 24,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Flexible(
                                            child: Text(
                                              book.title,
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.2,
                                                    fontSize: 13,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (progress > 0) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withOpacityValues(0.2),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: progress.clamp(0.0, 1.0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${(progress * 100).toInt()}%',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 10,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (book.currentPage > 0)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '在读',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                      fontSize: 8,
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
                ),
              ),
              Expanded(
                flex: 3, // 给文本信息预留适当空间
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                                fontSize: 12,
                              ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Flexible(
                        child: Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacityValues(0.7),
                                fontSize: 10,
                              ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '共 ${book.totalPages} 页',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacityValues(0.5),
                          fontSize: 9,
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
}
