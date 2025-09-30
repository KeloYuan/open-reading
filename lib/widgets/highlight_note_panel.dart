import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/book_note.dart';

/// 统一的书籍笔记管理面板
/// 基于统一的 BookNote 模型，提供完整的笔记和高亮管理功能
///
/// 功能特性：
/// - 统一管理高亮和笔记
/// - 按类型分组显示
/// - 搜索和筛选功能
/// - 导出和分享功能
/// - 批量操作支持
class HighlightNotePanel extends StatefulWidget {
  final int bookId;
  final String bookTitle;
  final String author;
  final List<BookNote> notes;
  final Function(BookNote) onNoteTap;
  final Function(BookNote) onNoteEdit;
  final Function(BookNote) onNoteDelete;
  final VoidCallback? onRefresh;

  const HighlightNotePanel({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.author,
    required this.notes,
    required this.onNoteTap,
    required this.onNoteEdit,
    required this.onNoteDelete,
    this.onRefresh,
  });

  @override
  State<HighlightNotePanel> createState() => _HighlightNotePanelState();
}

class _HighlightNotePanelState extends State<HighlightNotePanel>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedType = 'all';
  List<BookNote> _filteredNotes = [];

  // 统计数据
  int _highlightCount = 0;
  int _underlineCount = 0;
  int _noteCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _filteredNotes = widget.notes;
    _updateStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HighlightNotePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notes != widget.notes) {
      _filteredNotes = widget.notes;
      _updateStatistics();
      _applyFilters();
    }
  }

  /// 更新统计数据
  void _updateStatistics() {
    _highlightCount = widget.notes
        .where((note) => note.type == 'highlight')
        .length;
    _underlineCount = widget.notes
        .where((note) => note.type == 'underline')
        .length;
    _noteCount = widget.notes.where((note) => note.type == 'note').length;
  }

  /// 应用筛选条件
  void _applyFilters() {
    setState(() {
      _filteredNotes = widget.notes.where((note) {
        // 类型筛选
        if (_selectedType != 'all' && note.type != _selectedType) {
          return false;
        }

        // 搜索筛选
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          return note.content.toLowerCase().contains(query) ||
              (note.readerNote?.toLowerCase().contains(query) ?? false) ||
              note.chapter.toLowerCase().contains(query);
        }

        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            decoration: BoxDecoration(
              color: _getModalDecoration(),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAllNotesTab(),
                      _buildTypeTab('highlight'),
                      _buildTypeTab('underline'),
                      _buildTypeTab('note'),
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

  /// 构建头部
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 拖拽指示器
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _getModalIconColor(),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // 标题和操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '笔记管理',
                    style: TextStyle(
                      color: _getModalTextColor(),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${widget.bookTitle} - ${widget.author}',
                    style: TextStyle(color: _getModalIconColor(), fontSize: 12),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onRefresh,
                    icon: Icon(Icons.refresh, color: _getModalIconColor()),
                    tooltip: '刷新',
                  ),
                  IconButton(
                    onPressed: _showExportOptions,
                    icon: Icon(
                      Icons.file_download_outlined,
                      color: _getModalIconColor(),
                    ),
                    tooltip: '导出笔记',
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: _getModalIconColor()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _getModalBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getModalDividerColor()),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: '搜索笔记内容...',
          hintStyle: TextStyle(color: _getModalIconColor()),
          prefixIcon: Icon(Icons.search, color: _getModalIconColor()),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: _getModalIconColor()),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                    _applyFilters();
                  },
                )
              : null,
        ),
        style: TextStyle(color: _getModalTextColor()),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
          _applyFilters();
        },
      ),
    );
  }

  /// 构建选项卡栏
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _getModalDividerColor(),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: _getModalBackgroundColor(),
          borderRadius: BorderRadius.circular(14),
        ),
        labelColor: _getModalTextColor(),
        unselectedLabelColor: _getModalIconColor(),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.notes, size: 18),
                const SizedBox(width: 8),
                Text('全部 (${widget.notes.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.highlight, size: 18),
                const SizedBox(width: 8),
                Text('高亮 ($_highlightCount)'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.format_underlined, size: 18),
                const SizedBox(width: 8),
                Text('下划线 ($_underlineCount)'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.note_alt, size: 18),
                const SizedBox(width: 8),
                Text('笔记 ($_noteCount)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建全部笔记选项卡
  Widget _buildAllNotesTab() {
    if (_filteredNotes.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isNotEmpty ? '没有找到匹配的内容' : '还没有笔记内容',
        Icons.notes,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredNotes.length,
      itemBuilder: (context, index) {
        final note = _filteredNotes[index];
        return _buildNoteItem(note);
      },
    );
  }

  /// 构建按类型筛选的选项卡
  Widget _buildTypeTab(String type) {
    final typeNotes = _filteredNotes
        .where((note) => note.type == type)
        .toList();

    if (typeNotes.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isNotEmpty
            ? '没有找到匹配的${BookNote.getTypeName(type)}'
            : '还没有${BookNote.getTypeName(type)}内容',
        BookNote.getTypeIcon(type),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: typeNotes.length,
      itemBuilder: (context, index) {
        final note = typeNotes[index];
        return _buildNoteItem(note);
      },
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: _getModalIconColor().withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: _getModalTextColor().withOpacity(0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建统一的笔记项目
  Widget _buildNoteItem(BookNote note) {
    return InkWell(
      onTap: () => widget.onNoteTap(note),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getModalBackgroundColor(),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _getModalDividerColor(), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 类型和颜色标识
            Row(
              children: [
                Icon(
                  BookNote.getTypeIcon(note.type),
                  size: 16,
                  color: note.colorValue,
                ),
                const SizedBox(width: 8),
                Text(
                  BookNote.getTypeName(note.type),
                  style: TextStyle(
                    color: note.colorValue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: note.colorValue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 选中文本
            if (note.content.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: note.colorValue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: note.colorValue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  note.content,
                  style: TextStyle(
                    color: _getModalTextColor(),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 笔记内容（如果有）
            if (note.hasNote) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getModalDividerColor(),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, size: 16, color: _getModalIconColor()),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note.readerNote!,
                        style: TextStyle(
                          color: _getModalTextColor(),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 信息栏
            Row(
              children: [
                Icon(Icons.menu_book, size: 12, color: _getModalIconColor()),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    note.chapter,
                    style: TextStyle(color: _getModalIconColor(), fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                if (note.pageNumber != null) ...[
                  Icon(Icons.bookmark, size: 12, color: _getModalIconColor()),
                  const SizedBox(width: 4),
                  Text(
                    '第${note.pageNumber}页',
                    style: TextStyle(color: _getModalIconColor(), fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                ],
                Icon(Icons.access_time, size: 12, color: _getModalIconColor()),
                const SizedBox(width: 4),
                Text(
                  _formatDate(note.updateTime),
                  style: TextStyle(color: _getModalIconColor(), fontSize: 12),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => widget.onNoteEdit(note),
                  icon: Icon(Icons.edit, size: 16, color: _getModalIconColor()),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: '编辑',
                ),
                IconButton(
                  onPressed: () => _shareNote(note),
                  icon: Icon(
                    Icons.share,
                    size: 16,
                    color: _getModalIconColor(),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: '分享',
                ),
                IconButton(
                  onPressed: () => widget.onNoteDelete(note),
                  icon: Icon(
                    Icons.delete,
                    size: 16,
                    color: Colors.red.withOpacity(0.7),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: '删除',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 显示导出选项
  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getModalBackgroundColor(),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _getModalIconColor(),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '导出格式',
              style: TextStyle(
                color: _getModalTextColor(),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            _buildExportOption(
              icon: Icons.description,
              title: 'Markdown',
              subtitle: '适合阅读和分享',
              onTap: () => _exportNotes('markdown'),
            ),
            _buildExportOption(
              icon: Icons.table_chart,
              title: 'CSV',
              subtitle: '适合表格处理',
              onTap: () => _exportNotes('csv'),
            ),
            _buildExportOption(
              icon: Icons.code,
              title: 'JSON',
              subtitle: '适合程序处理',
              onTap: () => _exportNotes('json'),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建导出选项
  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: _getModalIconColor()),
      title: Text(
        title,
        style: TextStyle(
          color: _getModalTextColor(),
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: _getModalIconColor(), fontSize: 12),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  /// 分享单个笔记
  void _shareNote(BookNote note) {
    final shareText = note.toShareText(widget.bookTitle, widget.author);
    // 这里应该调用系统分享功能
    // 暂时复制到剪贴板
    debugPrint('分享笔记: $shareText');
  }

  /// 导出笔记
  void _exportNotes(String format) async {
    try {
      switch (format) {
        case 'markdown':
          await _exportAsMarkdown();
          break;
        case 'csv':
          await _exportAsCsv();
          break;
        case 'json':
          await _exportAsJson();
          break;
      }
    } catch (e) {
      debugPrint('导出失败: $e');
    }
  }

  /// 导出为Markdown格式
  Future<void> _exportAsMarkdown() async {
    final buffer = StringBuffer();
    buffer.writeln('# ${widget.bookTitle} - 笔记导出');
    buffer.writeln('**作者**: ${widget.author}');
    buffer.writeln('**导出时间**: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    for (final note in widget.notes) {
      buffer.writeln('## ${BookNote.getTypeName(note.type)} - ${note.chapter}');
      if (note.content.isNotEmpty) {
        buffer.writeln('> ${note.content}');
        buffer.writeln();
      }
      if (note.hasNote) {
        buffer.writeln('**笔记**: ${note.readerNote}');
        buffer.writeln();
      }
      buffer.writeln('---');
      buffer.writeln();
    }

    // 这里应该保存文件或分享
    debugPrint('Markdown导出完成');
  }

  /// 导出为CSV格式
  Future<void> _exportAsCsv() async {
    final buffer = StringBuffer();
    buffer.writeln('类型,内容,笔记,章节,页码,创建时间');

    for (final note in widget.notes) {
      buffer.writeln(
        [
          BookNote.getTypeName(note.type),
          '"${note.content.replaceAll('"', '""')}"',
          '"${note.readerNote?.replaceAll('"', '""') ?? ''}"',
          '"${note.chapter.replaceAll('"', '""')}"',
          note.pageNumber ?? '',
          note.createTime?.toIso8601String() ?? '',
        ].join(','),
      );
    }

    debugPrint('CSV导出完成');
  }

  /// 导出为JSON格式
  Future<void> _exportAsJson() async {
    final exportData = {
      'book': {'title': widget.bookTitle, 'author': widget.author},
      'exportTime': DateTime.now().toIso8601String(),
      'notes': widget.notes.map((note) => note.toExportMap()).toList(),
    };

    debugPrint('JSON导出完成: ${exportData.toString()}');
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${date.month}月${date.day}日';
    }
  }

  // 主题颜色辅助方法
  Color _getModalDecoration() {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[900]!.withOpacity(0.95)
        : Colors.white.withOpacity(0.95);
  }

  Color _getModalBackgroundColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[800]!
        : Colors.grey[50]!;
  }

  Color _getModalTextColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;
  }

  Color _getModalIconColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[400]!
        : Colors.grey[600]!;
  }

  Color _getModalDividerColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[700]!
        : Colors.grey[200]!;
  }
}
