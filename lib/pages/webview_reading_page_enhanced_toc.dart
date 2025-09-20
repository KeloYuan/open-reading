import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/chapter.dart';
import '../models/bookmark.dart';

/// 增强版目录模态框 - 借鉴anx-reader设计
class EnhancedTocModal extends StatefulWidget {
  final List<Chapter> chapters;
  final List<Bookmark> bookmarks;
  final dynamic currentTheme;
  final Function(Chapter) onChapterTap;
  final Function(Bookmark) onBookmarkTap;

  const EnhancedTocModal({
    super.key,
    required this.chapters,
    required this.bookmarks,
    required this.currentTheme,
    required this.onChapterTap,
    required this.onBookmarkTap,
  });

  @override
  State<EnhancedTocModal> createState() => _EnhancedTocModalState();
}

class _EnhancedTocModalState extends State<EnhancedTocModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _searchQuery;
  final TextEditingController _searchController = TextEditingController();
  List<Chapter> _filteredChapters = [];
  List<Bookmark> _filteredBookmarks = [];
  final Map<String, bool> _expandedChapters = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _filteredChapters = widget.chapters;
    _filteredBookmarks = widget.bookmarks;

    // 默认展开包含当前章节的章节
    for (final chapter in widget.chapters) {
      _expandedChapters[chapter.title] = _hasCurrentChapter(chapter);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _hasCurrentChapter(Chapter chapter) {
    // TODO: 实现当前章节检测逻辑
    return false;
  }

  void _updateSearch(String query) {
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

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: MediaQuery.of(context).size.height * 0.75,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: widget.currentTheme.backgroundColor.withValues(alpha: 0.45),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: widget.currentTheme.sliderActiveColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // 拖拽指示器
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: widget.currentTheme.controlBarTextColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),

                // 搜索栏
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _updateSearch,
                    style: TextStyle(color: widget.currentTheme.textColor),
                    decoration: InputDecoration(
                      hintText: '搜索章节或书签...',
                      hintStyle: TextStyle(
                        color: widget.currentTheme.textColor.withValues(alpha: 0.5),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: widget.currentTheme.sliderActiveColor,
                      ),
                      suffixIcon: _searchQuery != null
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: widget.currentTheme.textColor.withValues(alpha: 0.7),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _updateSearch('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: widget.currentTheme.sliderActiveColor.withValues(alpha: 0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: widget.currentTheme.sliderActiveColor.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: widget.currentTheme.sliderActiveColor,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: widget.currentTheme.backgroundColor.withValues(alpha: 0.3),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),

                // Tab栏
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: widget.currentTheme.backgroundColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: widget.currentTheme.sliderActiveColor,
                    unselectedLabelColor: widget.currentTheme.textColor.withValues(alpha: 0.6),
                    indicatorColor: widget.currentTheme.sliderActiveColor,
                    indicatorWeight: 3,
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.format_list_bulleted_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text('目录 (${_filteredChapters.length})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bookmark_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text('书签 (${_filteredBookmarks.length})'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 内容区域
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildChapterList(),
                      _buildBookmarkList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChapterList() {
    if (_filteredChapters.isEmpty) {
      return _buildEmptyState('暂无章节信息', Icons.format_list_bulleted_rounded);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _filteredChapters.length,
      itemBuilder: (context, index) {
        final chapter = _filteredChapters[index];
        return _buildChapterItem(chapter, index);
      },
    );
  }

  Widget _buildChapterItem(Chapter chapter, int index) {
    final isExpanded = _expandedChapters[chapter.title] ?? false;
    final hasSubChapters = chapter.subChapters.isNotEmpty;
    final isCurrentChapter = false; // TODO: 实现当前章节检测

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrentChapter
            ? widget.currentTheme.sliderActiveColor.withValues(alpha: 0.1)
            : widget.currentTheme.backgroundColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: isCurrentChapter
            ? Border.all(
                color: widget.currentTheme.sliderActiveColor.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
      ),
      child: Column(
        children: [
          // 主章节
          InkWell(
            onTap: () => widget.onChapterTap(chapter),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.only(
                left: (chapter.level * 16.0) + 16.0,
                right: 16.0,
                top: 12.0,
                bottom: hasSubChapters ? 8.0 : 12.0,
              ),
              child: Row(
                children: [
                  // 章节层级指示器
                  if (chapter.level > 0)
                    Container(
                      width: 3,
                      height: 24,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: _getChapterLevelColor(chapter.level),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),

                  // 展开/收起按钮
                  if (hasSubChapters)
                    Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(right: 12),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _expandedChapters[chapter.title] = !isExpanded;
                          });
                        },
                        icon: Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: widget.currentTheme.sliderActiveColor,
                          size: 20,
                        ),
                      ),
                    )
                  else
                    // 章节类型图标
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: Icon(
                        chapter.level == 0 ? Icons.book_rounded : Icons.article_rounded,
                        color: isCurrentChapter
                            ? widget.currentTheme.sliderActiveColor
                            : widget.currentTheme.textColor.withValues(alpha: 0.6),
                        size: chapter.level == 0 ? 20 : 16,
                      ),
                    ),

                  // 章节信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chapter.title.isEmpty ? '第${index + 1}章' : chapter.title,
                          style: TextStyle(
                            color: isCurrentChapter
                                ? widget.currentTheme.sliderActiveColor
                                : widget.currentTheme.textColor,
                            fontSize: _getChapterFontSize(chapter.level),
                            fontWeight: isCurrentChapter || chapter.level == 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (chapter.startPage > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '第${chapter.startPage + 1}页',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.currentTheme.textColor.withValues(alpha: 0.6),
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
                                    color: widget.currentTheme.sliderActiveColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${chapter.subChapters.length}节',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: widget.currentTheme.sliderActiveColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
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
                        color: widget.currentTheme.sliderActiveColor,
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

          // 子章节
          if (hasSubChapters && isExpanded)
            ...chapter.subChapters.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: _buildChapterItem(entry.value, entry.key),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBookmarkList() {
    if (_filteredBookmarks.isEmpty) {
      return _buildEmptyState('暂无书签', Icons.bookmark_border_rounded);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _filteredBookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = _filteredBookmarks[index];
        return _buildBookmarkItem(bookmark);
      },
    );
  }

  Widget _buildBookmarkItem(Bookmark bookmark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.currentTheme.backgroundColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => widget.onBookmarkTap(bookmark),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 书签图标
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.currentTheme.sliderActiveColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.bookmark_rounded,
                  size: 20,
                  color: widget.currentTheme.sliderActiveColor,
                ),
              ),
              const SizedBox(width: 12),

              // 书签信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '第${bookmark.pageNumber}页',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: widget.currentTheme.textColor,
                      ),
                    ),
                    if (bookmark.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        bookmark.note,
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.currentTheme.textColor.withValues(alpha: 0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(bookmark.createDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.currentTheme.textColor.withValues(alpha: 0.5),
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

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: widget.currentTheme.textColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: widget.currentTheme.textColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Color _getChapterLevelColor(int level) {
    switch (level) {
      case 0:
        return widget.currentTheme.sliderActiveColor;
      case 1:
        return Colors.orange.withValues(alpha: 0.8);
      case 2:
        return Colors.green.withValues(alpha: 0.8);
      default:
        return widget.currentTheme.textColor.withValues(alpha: 0.5);
    }
  }

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
}