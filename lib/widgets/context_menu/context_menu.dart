// 文件说明：阅读器上下文菜单，基于 OverlayEntry 实现智能定位的选中文本/注释操作面板。
// 技术要点：OverlayEntry、智能定位、WidgetsBindingObserver。

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:xxread/models/book_note.dart';
import 'package:xxread/widgets/context_menu/excerpt_menu.dart';
import 'package:xxread/widgets/context_menu/reader_note_menu.dart';

/// EpubPlayer 状态的接口抽象，避免直接耦合 widget。
abstract class EpubPlayerContract {
  String get chapterTitle;
  int? get bookId;
  void addAnnotation(BookNote bookNote);
  void removeAnnotation(String cfi);
  void clearWebViewSelection();
  void setSelectionClearLocked(bool locked);
  OverlayEntry? get contextMenuEntry;
  set contextMenuEntry(OverlayEntry? entry);
  void removeOverlay();
}

/// 在 Overlay 上显示上下文菜单。
void showContextMenu({
  required BuildContext context,
  required EpubPlayerContract player,
  required double left,
  required double top,
  required double right,
  required double bottom,
  required String content,
  required String cfi,
  int? id,
  bool footnote = false,
}) {
  player.removeOverlay();

  final mediaQuery = MediaQuery.of(context);
  final double screenHeight = mediaQuery.size.height;
  final double screenWidth = mediaQuery.size.width;
  final double keyboardInset = mediaQuery.viewInsets.bottom;

  final selectionRect = Rect.fromLTRB(
    left * screenWidth,
    top * screenHeight,
    right * screenWidth,
    bottom * screenHeight,
  );

  const double gap = 12;
  const double horizontalMargin = 16;
  const double verticalMargin = 60;

  final double maxMenuWidth =
      math.min(360, math.max(120, screenWidth - horizontalMargin * 2));
  final double effectiveHeight = math.max(0, screenHeight - keyboardInset);
  final double maxMenuHeight = math.max(
    0,
    math.min(footnote ? 350 : 480, effectiveHeight - verticalMargin * 2),
  );

  final placement = _resolvePlacement(
    selectionRect: selectionRect,
    viewportHeight: screenHeight,
    menuWidth: maxMenuWidth,
    menuHeight: maxMenuHeight,
    gap: gap,
    verticalMargin: verticalMargin,
    keyboardInset: keyboardInset,
  );

  void onClose() {
    player.clearWebViewSelection();
    player.removeOverlay();
  }

  final decoration = BoxDecoration(
    color: Theme.of(context).colorScheme.secondaryContainer,
    borderRadius: BorderRadius.circular(10),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.12),
        spreadRadius: 2,
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ],
  );

  player.contextMenuEntry = OverlayEntry(
    builder: (_) => _ContextMenuOverlay(
      position: placement.offset,
      selectionRect: selectionRect,
      content: content,
      cfi: cfi,
      id: id,
      footnote: footnote,
      player: player,
      decoration: decoration,
      onClose: onClose,
      maxWidth: maxMenuWidth,
      maxHeight: maxMenuHeight,
    ),
  );

  Overlay.of(context).insert(player.contextMenuEntry!);
}

class _MenuPlacement {
  const _MenuPlacement({required this.offset});
  final Offset offset;
}

_MenuPlacement _resolvePlacement({
  required Rect selectionRect,
  required double viewportHeight,
  required double menuWidth,
  required double menuHeight,
  required double gap,
  required double verticalMargin,
  required double keyboardInset,
}) {
  final double clampedBottom =
      math.max(0, viewportHeight - keyboardInset);

  final double spaceAbove = selectionRect.top;
  final double spaceBelow = clampedBottom - selectionRect.bottom;
  final bool placeBelow =
      (spaceBelow >= menuHeight + gap) || (spaceBelow >= spaceAbove);

  double top;
  if (placeBelow) {
    top = selectionRect.bottom + gap;
  } else {
    top = selectionRect.top - menuHeight - gap;
  }
  top = top.clamp(verticalMargin, clampedBottom - menuHeight - verticalMargin);

  double left =
      (selectionRect.center.dx - menuWidth / 2).clamp(8.0, viewportHeight - menuWidth - 8.0);

  return _MenuPlacement(offset: Offset(left, top));
}

class _ContextMenuOverlay extends StatefulWidget {
  const _ContextMenuOverlay({
    required this.position,
    required this.selectionRect,
    required this.content,
    required this.cfi,
    this.id,
    required this.footnote,
    required this.player,
    required this.decoration,
    required this.onClose,
    required this.maxWidth,
    required this.maxHeight,
  });

  final Offset position;
  final Rect selectionRect;
  final String content;
  final String cfi;
  final int? id;
  final bool footnote;
  final EpubPlayerContract player;
  final BoxDecoration decoration;
  final VoidCallback onClose;
  final double maxWidth;
  final double maxHeight;

  @override
  State<_ContextMenuOverlay> createState() => _ContextMenuOverlayState();
}

class _ContextMenuOverlayState extends State<_ContextMenuOverlay>
    with WidgetsBindingObserver {
  late Offset _position;
  bool _showReaderNote = false;
  int? _noteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _position = widget.position;
    _noteId = widget.id;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.player.setSelectionClearLocked(false);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mediaQuery = MediaQuery.of(context);
      final keyboardInset = mediaQuery.viewInsets.bottom;
      final screenHeight = mediaQuery.size.height;
      final clampedBottom = screenHeight - keyboardInset;

      double top;
      final spaceAbove = widget.selectionRect.top;
      final spaceBelow = clampedBottom - widget.selectionRect.bottom;
      final bool placeBelow = spaceBelow >= spaceAbove;
      if (placeBelow) {
        top = widget.selectionRect.bottom + 12;
      } else {
        top = widget.selectionRect.top - widget.maxHeight - 12;
      }
      top = top.clamp(60.0, clampedBottom - widget.maxHeight - 16);

      setState(() {
        _position = Offset(_position.dx, top);
      });
    });
  }

  void _toggleReaderNote({bool? show}) {
    final target = show ?? !_showReaderNote;
    widget.player.setSelectionClearLocked(target);
    setState(() => _showReaderNote = target);
  }

  void _handleNoteCreated(int noteId) {
    if (_noteId == noteId) return;
    setState(() => _noteId = noteId);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onTap: widget.onClose,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: widget.maxWidth,
            maxHeight: widget.maxHeight,
          ),
          decoration: widget.decoration,
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcerptMenu(
                content: widget.content,
                cfi: widget.cfi,
                id: _noteId,
                footnote: widget.footnote,
                player: widget.player,
                decoration: widget.decoration,
                onClose: widget.onClose,
                onNoteCreated: _handleNoteCreated,
                onOpenReaderNote: () => _toggleReaderNote(show: true),
              ),
              if (_showReaderNote) ...[
                const SizedBox(height: 8),
                ReaderNoteMenu(
                  noteId: _noteId,
                  onClose: () => _toggleReaderNote(show: false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
