import 'package:flutter/material.dart'; 
import 'package:flutter/services.dart';
import '../models/book_note.dart';
import '../services/book_note_dao.dart';
import 'package:url_launcher/url_launcher.dart';

/// 增强的文字选择工具栏
/// 参考 anx-reader 设计，支持：
/// - 多种高亮颜色选择
/// - 注释类型选择（高亮/下划线/笔记）
/// - 快速操作：复制、搜索、翻译、分享
/// - 笔记编辑和管理
class EnhancedTextSelectionToolbar extends StatefulWidget {
  final String selectedText;
  final int bookId;
  final int pageNumber;
  final String chapterTitle;
  final String cfi;
  final int? existingNoteId;
  final Function(BookNote)? onNoteCreated;
  final Function(BookNote)? onNoteUpdated;
  final VoidCallback? onClose;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? textColor;

  const EnhancedTextSelectionToolbar({
    super.key,
    required this.selectedText,
    required this.bookId,
    required this.pageNumber,
    required this.chapterTitle,
    required this.cfi,
    this.existingNoteId,
    this.onNoteCreated,
    this.onNoteUpdated,
    this.onClose,
    this.backgroundColor,
    this.iconColor,
    this.textColor,
  });

  @override
  State<EnhancedTextSelectionToolbar> createState() =>
      _EnhancedTextSelectionToolbarState();
}

class _EnhancedTextSelectionToolbarState
    extends State<EnhancedTextSelectionToolbar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  final BookNoteDao _noteDao = BookNoteDao();
  final TextEditingController _noteController = TextEditingController();

  // 当前选择的注释类型和颜色
  String _selectedType = 'highlight';
  String _selectedColor = '66CCFF';

  // UI状态
  bool _showColorPicker = false;
  bool _showNoteEditor = false;
  bool _showTranslation = false;
  bool _deleteConfirm = false;

  BookNote? _existingNote;
  int? _currentNoteId;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
    _loadExistingNote();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// 加载现有笔记
  Future<void> _loadExistingNote() async {
    if (widget.existingNoteId != null) {
      try {
        _existingNote = await _noteDao.selectBookNoteById(
          widget.existingNoteId!,
        );
        _currentNoteId = _existingNote!.id;
        _selectedType = _existingNote!.type;
        _selectedColor = _existingNote!.color;

        if (_existingNote!.hasNote) {
          _noteController.text = _existingNote!.readerNote!;
        }

        if (mounted) setState(() {});
      } catch (e) {
        debugPrint('Failed to load existing note: $e');
      }
    }
  }

  void _handleCopy() {
    Clipboard.setData(ClipboardData(text: widget.selectedText));
    _showFeedback('已复制到剪贴板');
    _close();
  }

  void _handleWebSearch() {
    final url =
        'https://www.bing.com/search?q=${Uri.encodeComponent(widget.selectedText)}';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    _showFeedback('已在浏览器中搜索');
    _close();
  }

  void _handleTranslate() {
    setState(() {
      _showTranslation = !_showTranslation;
    });
  }

  void _handleShare() {
    final bookNote = BookNote(
      bookId: widget.bookId,
      content: widget.selectedText,
      cfi: widget.cfi,
      chapter: widget.chapterTitle,
      type: _selectedType,
      color: _selectedColor,
      pageNumber: widget.pageNumber,
    );

    final shareText = bookNote.toShareText('当前阅读', '作者');
    Clipboard.setData(ClipboardData(text: shareText));
    _showFeedback('摘录已复制，可分享到其他平台');
    _close();
  }

  void _handleDelete() {
    if (_deleteConfirm) {
      if (_currentNoteId != null) {
        _noteDao.deleteBookNoteById(_currentNoteId!);
        _showFeedback('已删除注释');
      }
      _close();
    } else {
      setState(() {
        _deleteConfirm = true;
      });
    }
  }

  /// 选择颜色
  Future<void> _onColorSelected(String color) async {
    setState(() {
      _selectedColor = color;
    });
    await _saveOrUpdateNote();
  }

  /// 选择类型
  Future<void> _onTypeSelected(String type) async {
    setState(() {
      _selectedType = type;
    });
    await _saveOrUpdateNote();
  }

  /// 保存或更新笔记
  Future<void> _saveOrUpdateNote() async {
    try {
      final bookNote = BookNote(
        id: _currentNoteId,
        bookId: widget.bookId,
        content: widget.selectedText,
        cfi: widget.cfi,
        chapter: widget.chapterTitle,
        type: _selectedType,
        color: _selectedColor,
        readerNote: _noteController.text.isNotEmpty
            ? _noteController.text
            : null,
        pageNumber: widget.pageNumber,
        createTime: _existingNote?.createTime,
      );

      _currentNoteId = await _noteDao.insertBookNote(bookNote);

      final updatedNote = bookNote.copyWith(id: _currentNoteId);

      if (_existingNote == null) {
        widget.onNoteCreated?.call(updatedNote);
      } else {
        widget.onNoteUpdated?.call(updatedNote);
      }

      _existingNote = updatedNote;

      if (mounted) setState(() {});
    } catch (e) {
      _showFeedback('保存失败: $e');
    }
  }

  void _handleNoteEdit() {
    setState(() {
      _showNoteEditor = !_showNoteEditor;
    });
  }

  void _saveNote() async {
    await _saveOrUpdateNote();
    _showFeedback('笔记已保存');
  }

  void _showFeedback(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              widget.backgroundColor?.withOpacity(0.9) ??
              Theme.of(context).primaryColor.withOpacity(0.9),
        ),
      );
    }
  }

  void _close() {
    _animationController.reverse().then((_) {
      widget.onClose?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor =
        widget.backgroundColor ??
        (theme.brightness == Brightness.dark
            ? Colors.grey[900]!.withOpacity(0.95)
            : Colors.white.withOpacity(0.95));
    final iconColor = widget.iconColor ?? theme.colorScheme.primary;
    final textColor = widget.textColor ?? theme.colorScheme.onSurface;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              width: 370,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 主操作菜单
                  _buildMainMenu(backgroundColor, iconColor, textColor),

                  const SizedBox(height: 10),

                  // 注释菜单（颜色和类型选择）
                  if (_showColorPicker)
                    _buildAnnotationMenu(backgroundColor, iconColor, textColor),

                  const SizedBox(height: 10),

                  // 笔记编辑器
                  if (_showNoteEditor)
                    _buildNoteEditor(backgroundColor, iconColor, textColor),

                  const SizedBox(height: 10),

                  // 翻译面板（模拟，实际需要集成翻译服务）
                  if (_showTranslation)
                    _buildTranslationPanel(
                      backgroundColor,
                      iconColor,
                      textColor,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建主操作菜单
  Widget _buildMainMenu(
    Color backgroundColor,
    Color iconColor,
    Color textColor,
  ) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: Colors.transparent,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: iconColor.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 删除按钮（如果存在现有笔记）
              if (_currentNoteId != null)
                _buildIconButton(
                  icon: _deleteConfirm ? Icons.cancel : Icons.delete,
                  color: _deleteConfirm ? Colors.red : iconColor,
                  onTap: _handleDelete,
                ),

              // 复制
              _buildIconButton(
                icon: Icons.content_copy,
                color: iconColor,
                onTap: _handleCopy,
              ),

              // 搜索
              _buildIconButton(
                icon: Icons.search,
                color: iconColor,
                onTap: _handleWebSearch,
              ),

              // 翻译
              _buildIconButton(
                icon: Icons.translate,
                color: iconColor,
                onTap: _handleTranslate,
              ),

              // 显示颜色选择器
              _buildIconButton(
                icon: Icons.palette,
                color: _showColorPicker ? Colors.blue : iconColor,
                onTap: () =>
                    setState(() => _showColorPicker = !_showColorPicker),
              ),

              // 笔记编辑
              _buildIconButton(
                icon: Icons.note_add,
                color: _showNoteEditor ? Colors.blue : iconColor,
                onTap: _handleNoteEdit,
              ),

              // 分享
              _buildIconButton(
                icon: Icons.share,
                color: iconColor,
                onTap: _handleShare,
              ),

              // 关闭
              _buildIconButton(
                icon: Icons.close,
                color: iconColor.withOpacity(0.7),
                onTap: _close,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建注释菜单（类型和颜色选择）
  Widget _buildAnnotationMenu(
    Color backgroundColor,
    Color iconColor,
    Color textColor,
  ) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: Colors.transparent,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: iconColor.withOpacity(0.2), width: 1),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 类型选择
              for (final type in BookNote.noteTypes)
                _buildTypeButton(type['type'], type['icon'], iconColor),

              // 分隔线
              Container(
                width: 1,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: iconColor.withOpacity(0.2),
              ),

              // 颜色选择
              for (final color in BookNote.noteColors) _buildColorButton(color),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建笔记编辑器
  Widget _buildNoteEditor(
    Color backgroundColor,
    Color iconColor,
    Color textColor,
  ) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 200),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: iconColor.withOpacity(0.2), width: 1),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '添加笔记...',
                hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
              ),
              style: TextStyle(color: textColor),
              maxLines: 5,
              minLines: 2,
              onChanged: (value) => setState(() {}),
            ),
            if (_noteController.text.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: _saveNote, child: const Text('保存')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// 构建翻译面板
  Widget _buildTranslationPanel(
    Color backgroundColor,
    Color iconColor,
    Color textColor,
  ) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: iconColor.withOpacity(0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '翻译结果',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '翻译功能需要集成翻译服务',
              style: TextStyle(
                color: textColor.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建图标按钮
  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return IconButton(
      padding: const EdgeInsets.all(2),
      constraints: const BoxConstraints(),
      style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      icon: Icon(icon, color: color, size: 20),
      onPressed: onTap,
    );
  }

  /// 构建颜色按钮
  Widget _buildColorButton(String color) {
    return _buildIconButton(
      icon: Icons.circle,
      color: Color(int.parse('0xFF$color')),
      onTap: () => _onColorSelected(color),
    );
  }

  /// 构建类型按钮
  Widget _buildTypeButton(String type, IconData icon, Color iconColor) {
    return _buildIconButton(
      icon: icon,
      color: _selectedType == type
          ? Color(int.parse('0xFF$_selectedColor'))
          : iconColor,
      onTap: () => _onTypeSelected(type),
    );
  }
}
