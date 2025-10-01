import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../models/bookmark.dart';

/// 目录和书签组件 - 参考anx-reader的双Tab设计
class TocWidget extends StatefulWidget {
  final Book book;
  final List<Chapter> chapters;
  final List<Bookmark> bookmarks;
  final Function(int pageIndex) onPageTap;
  final Function(Bookmark bookmark) onBookmarkTap;
  final int currentPageIndex;

  const TocWidget({
    super.key,
    required this.book,
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.5),
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
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery != null && _searchQuery!.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _updateSearchResults('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
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
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.toc, size: 18),
                    const SizedBox(width: 8),
                    Text('目录 (${_filteredChapters.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bookmark, size: 18),
                    const SizedBox(width: 8),
                    Text('书签 (${_filteredBookmarks.length})'),
                  ],
                ),
              ),
            ],
          ),

          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索章节或书签...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: _onSearchChanged,
            ),
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

    return Column(
      children: [
        // 主章节
        Card(
          margin: EdgeInsets.only(
            bottom: 8,
            left: depth * 16.0, // 根据层级缩进
          ),
          elevation: isCurrentChapter ? 2 : 0,
          color: isCurrentChapter
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : null,
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
                          color: Theme.of(context).primaryColor,
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
                                  color: Colors.blue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.book,
                                  size: 12,
                                  color: Colors.blue[700],
                                ),
                              )
                            else if (chapter.isPossibleTableOfContents)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.list,
                                  size: 12,
                                  color: Colors.orange[700],
                                ),
                              )
                            else if (chapter.isPreface)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.start,
                                  size: 12,
                                  color: Colors.green[700],
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
                                      ? Theme.of(context).primaryColor
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
                                color: Colors.grey[600],
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
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${chapter.subChapters.length}节',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).primaryColor,
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
                        color: Theme.of(context).primaryColor,
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isCurrentPage ? 2 : 0,
      color: isCurrentPage
          ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
          : null,
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
                  color: isCurrentPage
                      ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.bookmark,
                  size: 20,
                  color: isCurrentPage
                      ? Theme.of(context).primaryColor
                      : Colors.grey[600],
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
                            ? Theme.of(context).primaryColor
                            : null,
                      ),
                    ),
                    if (bookmark.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        bookmark.note,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(bookmark.createDate),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
                    color: Theme.of(context).primaryColor,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  bool _isCurrentChapter(Chapter chapter) {
    return widget.currentPageIndex >= chapter.startPage &&
        (chapter.endPage == 0 || widget.currentPageIndex <= chapter.endPage);
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.isEmpty ? null : query;

      if (_searchQuery == null) {
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

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
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
    if (isCurrentChapter) {
      return Theme.of(context).primaryColor;
    }

    switch (level) {
      case 0:
        return Theme.of(context).primaryColor.withValues(alpha: 0.7);
      case 1:
        return Colors.orange.withValues(alpha: 0.6);
      case 2:
        return Colors.green.withValues(alpha: 0.6);
      default:
        return Colors.grey.withValues(alpha: 0.5);
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
    switch (level) {
      case 0:
        return null; // 使用主题默认颜色
      case 1:
        return Colors.grey[700];
      case 2:
        return Colors.grey[600];
      default:
        return Colors.grey[500];
    }
  }
}
