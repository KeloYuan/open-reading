import 'package:flutter/material.dart';
import '../models/chapter.dart';
import '../models/bookmark.dart';

/// 目录和书签组件 - 参考anx-reader的双Tab设计
class TocWidget extends StatefulWidget {
  final List<Chapter> chapters;
  final List<Bookmark> bookmarks;
  final Function(int pageIndex) onPageTap;
  final Function(Bookmark bookmark) onBookmarkTap;
  final int currentPageIndex;

  const TocWidget({
    super.key,
    required this.chapters,
    required this.bookmarks,
    required this.onPageTap,
    required this.onBookmarkTap,
    required this.currentPageIndex,
  });

  @override
  State<TocWidget> createState() => _TocWidgetState();
}

class _TocWidgetState extends State<TocWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _searchQuery;
  final TextEditingController _searchController = TextEditingController();
  List<Chapter> _filteredChapters = [];
  List<Bookmark> _filteredBookmarks = [];

  // 用于追踪展开状态的Map
  final Map<String, bool> _expandedChapters = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _filteredChapters = widget.chapters;
    _filteredBookmarks = widget.bookmarks;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _updateSearchResults(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredChapters = widget.chapters;
        _filteredBookmarks = widget.bookmarks;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredChapters = widget.chapters.where((chapter) {
          return chapter.title.toLowerCase().contains(lowerQuery);
        }).toList();
        _filteredBookmarks = widget.bookmarks.where((bookmark) {
          return bookmark.note.toLowerCase().contains(lowerQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surface = scheme.surface;
    final onSurface = scheme.onSurface;
    final primary = scheme.primary;
    final muted = onSurface.withValues(alpha: 0.55);
    final divider = scheme.outline.withValues(alpha: 0.2);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 拖拽指示器
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: muted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // 搜索框
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索章节或书签...',
                prefixIcon: Icon(Icons.search_rounded, color: muted),
                suffixIcon: _searchQuery != null && _searchQuery!.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: muted),
                        onPressed: () {
                          _searchController.clear();
                          _updateSearchResults('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: divider),
                ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: _updateSearchResults,
            ),
          ),

          // Tab栏
          TabBar(
            controller: _tabController,
            labelColor: primary,
            unselectedLabelColor: muted,
            indicatorColor: primary,
            indicatorWeight: 3,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.toc, size: 18, color: primary),
                    const SizedBox(width: 8),
                    Text('目录 (${_filteredChapters.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bookmark, size: 18, color: primary),
                    const SizedBox(width: 8),
                    Text('书签 (${_filteredBookmarks.length})'),
                  ],
                ),
              ),
            ],
          ),

          // 内容区域
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildChapterList(), _buildBookmarkList()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterList() {
    if (_filteredChapters.isEmpty) {
      return _buildEmptyState('暂无章节信息', Icons.toc);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredChapters.length,
      itemBuilder: (context, index) {
        final chapter = _filteredChapters[index];
        return _buildChapterItem(chapter);
      },
    );
  }

  Widget _buildChapterItem(Chapter chapter, {int depth = 0}) {
    final isCurrentChapter = _isCurrentChapter(chapter);
    final hasSubChapters = chapter.subChapters.isNotEmpty;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final primary = scheme.primary;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final cardBase = scheme.surfaceContainerLow;

    return Column(
      children: [
        // 主章节
        Card(
          margin: EdgeInsets.only(
            bottom: 8,
            left: depth * 16.0, // 根据层级缩进
          ),
          elevation: 0,
          color: cardBase,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: scheme.outline.withValues(alpha: 0.12),
              width: 0.8,
            ),
          ),
          child: InkWell(
            onTap: () => widget.onPageTap(chapter.startPage),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 层级指示器和展开按钮
                  if (hasSubChapters)
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _expandedChapters[chapter.title] =
                                !(_expandedChapters[chapter.title] ?? false);
                          });
                        },
                        icon: Icon(
                          (_expandedChapters[chapter.title] ?? false)
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 18,
                          color: primary,
                        ),
                      ),
                    )
                  else
                    // 层级指示线
                    Container(
                      width: depth > 0 ? 2 : 4,
                      height: 24,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: _getChapterLevelColor(
                          chapter.level,
                          isCurrentChapter,
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),

                  // 章节信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // 章节类型图标
                            if (chapter.isMainChapter)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.book,
                                  size: 12,
                                  color: primary,
                                ),
                              )
                            else if (chapter.isPossibleTableOfContents)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: scheme.tertiary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.list,
                                  size: 12,
                                  color: scheme.tertiary,
                                ),
                              )
                            else if (chapter.isPreface)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: scheme.secondary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.start,
                                  size: 12,
                                  color: scheme.secondary,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                chapter.title,
                                style: TextStyle(
                                  fontSize: _getChapterFontSize(chapter.level),
                                  fontWeight: isCurrentChapter
                                      ? FontWeight.w600
                                      : _getChapterFontWeight(chapter.level),
                                  color: isCurrentChapter
                                      ? primary
                                      : _getChapterTextColor(chapter.level),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '第 ${chapter.startPage + 1} 页',
                              style: TextStyle(
                                fontSize: 12,
                                color: muted,
                              ),
                            ),
                            if (hasSubChapters) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${chapter.subChapters.length}节',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 当前章节指示器
                  if (isCurrentChapter)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '当前',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // 子章节 - 递归显示
        if (hasSubChapters && (_expandedChapters[chapter.title] ?? false))
          ...chapter.subChapters.map(
            (subChapter) => _buildChapterItem(subChapter, depth: depth + 1),
          ),
      ],
    );
  }

  Widget _buildBookmarkList() {
    if (_filteredBookmarks.isEmpty) {
      return _buildEmptyState('暂无书签', Icons.bookmark_border);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredBookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = _filteredBookmarks[index];
        return _buildBookmarkItem(bookmark);
      },
    );
  }

  Widget _buildBookmarkItem(Bookmark bookmark) {
    final isCurrentPage = bookmark.pageNumber - 1 == widget.currentPageIndex;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final primary = scheme.primary;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final cardBase = scheme.surfaceContainerLow;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: cardBase,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: scheme.outline.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: InkWell(
        onTap: () => widget.onBookmarkTap(bookmark),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 书签图标
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.bookmark,
                  size: 20,
                  color: isCurrentPage
                      ? primary
                      : muted,
                ),
              ),
              const SizedBox(width: 12),

              // 书签信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '第 ${bookmark.pageNumber} 页',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isCurrentPage
                            ? primary
                            : null,
                      ),
                    ),
                    if (bookmark.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        bookmark.note,
                        style: TextStyle(fontSize: 14, color: muted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(bookmark.createDate),
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),

              // 当前页面指示器
              if (isCurrentPage)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '当前',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: scheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  bool _isCurrentChapter(Chapter chapter) {
    return widget.currentPageIndex >= chapter.startPage &&
        (chapter.endPage == 0 || widget.currentPageIndex <= chapter.endPage);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '昨天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${date.month}/${date.day}';
    }
  }

  // 根据章节层级获取颜色
  Color _getChapterLevelColor(int level, bool isCurrentChapter) {
    final scheme = Theme.of(context).colorScheme;
    if (isCurrentChapter) {
      return scheme.primary;
    }

    switch (level) {
      case 0:
        return scheme.primary.withValues(alpha: 0.7);
      case 1:
        return scheme.tertiary.withValues(alpha: 0.6);
      case 2:
        return scheme.secondary.withValues(alpha: 0.6);
      default:
        return scheme.onSurface.withValues(alpha: 0.3);
    }
  }

  // 根据章节层级获取字体大小
  double _getChapterFontSize(int level) {
    switch (level) {
      case 0:
        return 16.0;
      case 1:
        return 15.0;
      case 2:
        return 14.0;
      default:
        return 13.0;
    }
  }

  // 根据章节层级获取字体权重
  FontWeight _getChapterFontWeight(int level) {
    switch (level) {
      case 0:
        return FontWeight.w600;
      case 1:
        return FontWeight.w500;
      default:
        return FontWeight.w400;
    }
  }

  // 根据章节层级获取文本颜色
  Color? _getChapterTextColor(int level) {
    final scheme = Theme.of(context).colorScheme;
    switch (level) {
      case 0:
        return null; // 使用主题默认颜色
      case 1:
        return scheme.onSurface.withValues(alpha: 0.8);
      case 2:
        return scheme.onSurface.withValues(alpha: 0.65);
      default:
        return scheme.onSurface.withValues(alpha: 0.5);
    }
  }
}
