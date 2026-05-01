// 文件说明：选中文本/注释的操作面板——高亮、下划线、复制、搜索、写笔记。
// 技术要点：StatefulWidget、BookNoteDao。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:xxread/models/book_note.dart';
import 'package:xxread/services/books/book_note_dao.dart';
import 'package:xxread/widgets/side_toast.dart';
import 'package:xxread/widgets/context_menu/context_menu.dart';

const List<_AnnoColor> _annoColors = [
  _AnnoColor(name: '蓝', hex: '66CCFF'),
  _AnnoColor(name: '红', hex: 'FF0000'),
  _AnnoColor(name: '绿', hex: '4CAF50'),
  _AnnoColor(name: '紫', hex: 'EB3BFF'),
  _AnnoColor(name: '黄', hex: 'FFEB3B'),
];

const List<_AnnoType> _annoTypes = [
  _AnnoType(type: 'highlight', icon: Icons.highlight_alt, label: '高亮'),
  _AnnoType(type: 'underline', icon: Icons.format_underlined, label: '下划线'),
];

class ExcerptMenu extends StatefulWidget {
  final String content;
  final String cfi;
  final int? id;
  final bool footnote;
  final EpubPlayerContract player;
  final BoxDecoration decoration;
  final VoidCallback onClose;
  final void Function(int noteId) onNoteCreated;
  final VoidCallback onOpenReaderNote;

  const ExcerptMenu({
    super.key,
    required this.content,
    required this.cfi,
    this.id,
    required this.footnote,
    required this.player,
    required this.decoration,
    required this.onClose,
    required this.onNoteCreated,
    required this.onOpenReaderNote,
  });

  @override
  State<ExcerptMenu> createState() => _ExcerptMenuState();
}

class _ExcerptMenuState extends State<ExcerptMenu> {
  final _bookNoteDao = BookNoteDao();
  bool _deleteConfirm = false;
  int? _noteId;
  BookNote? _currentNote;
  late String _annoType;
  late String _annoColor;

  @override
  void initState() {
    super.initState();
    _annoType = 'highlight';
    _annoColor = _annoColors.first.hex;
    _noteId = widget.id;
    _loadExistingNote();
  }

  Future<void> _loadExistingNote() async {
    if (widget.id == null) return;
    try {
      final note = await _bookNoteDao.selectBookNoteById(widget.id!);
      if (!mounted) return;
      setState(() {
        _currentNote = note;
        _noteId = note.id;
        _annoType = note.type;
        _annoColor = note.color;
      });
    } catch (_) {}
  }

  Future<BookNote?> _fetchLatestNote() async {
    final existingId = _noteId ?? widget.id;
    if (existingId == null) return null;
    try {
      return await _bookNoteDao.selectBookNoteById(existingId);
    } catch (_) {
      return _currentNote;
    }
  }

  Future<BookNote> _persistNote({String? color, String? type}) async {
    final existing = await _fetchLatestNote() ?? _currentNote;
    final now = DateTime.now();
    final bookId = widget.player.bookId ?? existing?.bookId ?? 0;

    final resolvedType = type ?? existing?.type ?? _annoType;
    final resolvedColor = color ?? existing?.color ?? _annoColor;

    final bookNote = BookNote(
      id: existing?.id ?? widget.id,
      bookId: bookId,
      content: existing?.content ?? widget.content,
      cfi: existing?.cfi ?? widget.cfi,
      chapter: existing?.chapter ?? widget.player.chapterTitle,
      type: resolvedType,
      color: resolvedColor,
      readerNote: existing?.readerNote,
      pageNumber: existing?.pageNumber,
      createTime: existing?.createTime ?? now,
      updateTime: now,
    );

    final id = await _bookNoteDao.insertBookNote(bookNote);
    widget.onNoteCreated(id);

    if (mounted) {
      setState(() {
        _currentNote = bookNote;
        _noteId = id;
        _annoType = resolvedType;
        _annoColor = resolvedColor;
      });
    } else {
      _currentNote = bookNote;
      _noteId = id;
      _annoType = resolvedType;
      _annoColor = resolvedColor;
    }

    return bookNote;
  }

  Future<void> _onColorSelected(String color) async {
    _annoColor = color;
    final note = await _persistNote(color: color);
    widget.player.addAnnotation(note);
  }

  Future<void> _onTypeSelected(String type) async {
    _annoType = type;
    final note = await _persistNote(type: type);
    widget.player.addAnnotation(note);
  }

  void _deleteHandler() {
    if (_deleteConfirm) {
      if (_noteId != null) {
        _bookNoteDao.deleteBookNoteById(_noteId!);
        widget.player.removeAnnotation(widget.cfi);
      }
      widget.onClose();
    } else {
      setState(() => _deleteConfirm = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 标注区：删除 + 类型切换 + 颜色选择
    final annotationRow = Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: WrapAlignment.start,
      children: [
        if (_noteId != null)
          IconButton(
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            icon: Icon(
              _deleteConfirm ? Icons.close : Icons.delete_outline,
              color: _deleteConfirm ? Colors.red : null,
              size: 20,
            ),
            onPressed: _deleteHandler,
          ),
        for (final t in _annoTypes)
          IconButton(
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            icon: Icon(
              t.icon,
              size: 20,
              color: _annoType == t.type
                  ? Color(int.parse('0xFF$_annoColor'))
                  : null,
            ),
            tooltip: t.label,
            onPressed: () => _onTypeSelected(t.type),
          ),
        for (final c in _annoColors)
          GestureDetector(
            onTap: () => _onColorSelected(c.hex),
            child: Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Color(int.parse('0xFF${c.hex}')),
                shape: BoxShape.circle,
                border: _annoColor == c.hex
                    ? Border.all(color: theme.colorScheme.onSurface, width: 2)
                    : Border.all(color: theme.dividerColor, width: 0.5),
              ),
            ),
          ),
      ],
    );

    // 操作区：复制 / 搜索 / 写笔记
    final operatorRow = Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _actionChip(Icons.copy, '复制', () {
          Clipboard.setData(ClipboardData(text: widget.content));
          showSideToast(context, '已复制', icon: Icons.check);
          widget.onClose();
        }),
        _actionChip(Icons.search, '搜索', () {
          widget.onClose();
          launchUrl(
            Uri.parse('https://www.bing.com/search?q=${Uri.encodeComponent(widget.content)}'),
            mode: LaunchMode.externalApplication,
          );
        }),
        if (!widget.footnote)
          _actionChip(Icons.edit_note, '笔记', () async {
            widget.player.setSelectionClearLocked(true);
            await _onColorSelected(_annoColor);
            widget.onOpenReaderNote();
          }),
        _actionChip(Icons.share, '分享', () {
          widget.onClose();
          // TODO: 分享功能
        }),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.footnote) annotationRow,
        const SizedBox(height: 6),
        operatorRow,
      ],
    );
  }

  Widget _actionChip(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _AnnoColor {
  final String name;
  final String hex;
  const _AnnoColor({required this.name, required this.hex});
}

class _AnnoType {
  final String type;
  final IconData icon;
  final String label;
  const _AnnoType({required this.type, required this.icon, required this.label});
}
