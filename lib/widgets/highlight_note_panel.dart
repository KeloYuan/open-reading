import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/highlight.dart';
import '../models/note.dart';

/// 高亮笔记管理面板
/// 提供高亮和笔记的查看、编辑、导出功能
class HighlightNotePanel extends StatefulWidget {
  final List<Highlight> highlights;
  final List<Note> notes;
  final Function(Highlight) onHighlightTap;
  final Function(Note) onNoteTap;
  final Function(Highlight) onHighlightEdit;
  final Function(Note) onNoteEdit;
  final Function(Highlight) onHighlightDelete;
  final Function(Note) onNoteDelete;

  const HighlightNotePanel({
    super.key,
    required this.highlights,
    required this.notes,
    required this.onHighlightTap,
    required this.onNoteTap,
    required this.onHighlightEdit,
    required this.onNoteEdit,
    required this.onHighlightDelete,
    required this.onNoteDelete,
  });

  @override
  State<HighlightNotePanel> createState() => _HighlightNotePanelState();
}

class _HighlightNotePanelState extends State<HighlightNotePanel>
    with TickerProviderStateMixin {
  late TabController _tabController;
  // final NoteExportService _exportService = NoteExportService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildHighlightsTab(), _buildNotesTab()],
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
              Text(
                '笔记管理',
                style: TextStyle(
                  color: _getModalTextColor(),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
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
                const Icon(Icons.highlight, size: 18),
                const SizedBox(width: 8),
                Text('高亮 (${widget.highlights.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.note, size: 18),
                const SizedBox(width: 8),
                Text('笔记 (${widget.notes.length})'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建高亮选项卡
  Widget _buildHighlightsTab() {
    if (widget.highlights.isEmpty) {
      return _buildEmptyState('还没有高亮内容', Icons.highlight);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.highlights.length,
      itemBuilder: (context, index) {
        final highlight = widget.highlights[index];
        return _buildHighlightItem(highlight);
      },
    );
  }

  /// 构建笔记选项卡
  Widget _buildNotesTab() {
    if (widget.notes.isEmpty) {
      return _buildEmptyState('还没有笔记内容', Icons.note);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.notes.length,
      itemBuilder: (context, index) {
        final note = widget.notes[index];
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
            color: _getModalIconColor().withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: _getModalTextColor().withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建高亮项目
  Widget _buildHighlightItem(Highlight highlight) {
    return Container(
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
          // 高亮文本
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: highlight.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: highlight.color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              highlight.selectedText,
              style: TextStyle(
                color: _getModalTextColor(),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),

          // 笔记内容（如果有）
          if (highlight.noteText?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
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
                      highlight.noteText!,
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
          ],

          const SizedBox(height: 12),

          // 信息栏
          Row(
            children: [
              // 颜色标识
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: highlight.color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Highlight.getColorName(highlight.color),
                style: TextStyle(color: _getModalIconColor(), fontSize: 12),
              ),
              const SizedBox(width: 16),
              Icon(Icons.book, size: 12, color: _getModalIconColor()),
              const SizedBox(width: 4),
              Text(
                '第${highlight.pageNumber}页',
                style: TextStyle(color: _getModalIconColor(), fontSize: 12),
              ),
              const Spacer(),
              // 操作按钮
              IconButton(
                onPressed: () => widget.onHighlightEdit(highlight),
                icon: Icon(Icons.edit, size: 16, color: _getModalIconColor()),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                onPressed: () => widget.onHighlightDelete(highlight),
                icon: Icon(
                  Icons.delete,
                  size: 16,
                  color: Colors.red.withValues(alpha: 0.7),
                ),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建笔记项目
  Widget _buildNoteItem(Note note) {
    return Container(
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
          // 选中文本（如果有）
          if (note.selectedText.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getModalDividerColor(),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                note.selectedText,
                style: TextStyle(
                  color: _getModalTextColor().withValues(alpha: 0.8),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 笔记内容
          Text(
            note.noteText,
            style: TextStyle(
              color: _getModalTextColor(),
              fontSize: 14,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 12),

          // 信息栏
          Row(
            children: [
              Icon(Icons.book, size: 12, color: _getModalIconColor()),
              const SizedBox(width: 4),
              Text(
                '第${note.pageNumber}页',
                style: TextStyle(color: _getModalIconColor(), fontSize: 12),
              ),
              const SizedBox(width: 16),
              Icon(Icons.access_time, size: 12, color: _getModalIconColor()),
              const SizedBox(width: 4),
              Text(
                _formatDate(note.createDate),
                style: TextStyle(color: _getModalIconColor(), fontSize: 12),
              ),
              const Spacer(),
              // 操作按钮
              IconButton(
                onPressed: () => widget.onNoteEdit(note),
                icon: Icon(Icons.edit, size: 16, color: _getModalIconColor()),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                onPressed: () => widget.onNoteDelete(note),
                icon: Icon(
                  Icons.delete,
                  size: 16,
                  color: Colors.red.withValues(alpha: 0.7),
                ),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
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

  /// 导出笔记
  void _exportNotes(String format) async {
    // TODO: 实现导出功能，需要传入Book对象
    // await _exportService.shareNotes(
    //   book: widget.book,
    //   highlights: widget.highlights,
    //   notes: widget.notes,
    //   format: format,
    // );
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
        ? Colors.grey[900]!.withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.95);
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
