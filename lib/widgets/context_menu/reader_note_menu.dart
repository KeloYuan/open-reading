// 文件说明：笔记文本编辑面板，用于在高亮/下划线上添加或编辑用户笔记。
// 技术要点：StatefulWidget、BookNoteDao。

import 'package:flutter/material.dart';

import 'package:xxread/services/books/book_note_dao.dart';
import 'package:xxread/widgets/side_toast.dart';

class ReaderNoteMenu extends StatefulWidget {
  final int? noteId;
  final VoidCallback onClose;

  const ReaderNoteMenu({
    super.key,
    this.noteId,
    required this.onClose,
  });

  @override
  State<ReaderNoteMenu> createState() => ReaderNoteMenuState();
}

class ReaderNoteMenuState extends State<ReaderNoteMenu> {
  final _bookNoteDao = BookNoteDao();
  final _controller = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.noteId != null) {
      _loadNote();
    } else {
      _loaded = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadNote() async {
    try {
      final note = await _bookNoteDao.selectBookNoteById(widget.noteId!);
      if (!mounted) return;
      _controller.text = note.readerNote ?? '';
      setState(() => _loaded = true);
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _save() async {
    if (widget.noteId == null) return;
    final text = _controller.text.trim();
    try {
      final existing = await _bookNoteDao.selectBookNoteById(widget.noteId!);
      final updated = existing.copyWith(readerNote: text.isEmpty ? null : text);
      await _bookNoteDao.updateBookNoteById(updated);
      if (mounted) {
        showSideToast(context, '笔记已保存', icon: Icons.check);
        widget.onClose();
      }
    } catch (_) {
      if (mounted) {
        showSideToast(context, '保存失败', icon: Icons.error_outline);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('笔记', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        if (!_loaded)
          const SizedBox(height: 32, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))))
        else
          TextField(
            controller: _controller,
            autofocus: widget.noteId == null,
            maxLines: 3,
            minLines: 1,
            style: theme.textTheme.bodySmall,
            decoration: InputDecoration(
              hintText: '写点什么…',
              hintStyle: TextStyle(color: theme.hintColor, fontSize: 13),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
            ),
          ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onClose,
              child: const Text('取消', style: TextStyle(fontSize: 12)),
            ),
            TextButton(
              onPressed: _save,
              child: const Text('保存', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }
}
