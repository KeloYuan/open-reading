import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/text_page_data.dart';

/// 触摸交互管理器
/// 处理复杂的触摸手势，包括文字选择、双击、长按等
class TouchInteractionManager {
  /// 选择状态
  SelectionState _selectionState = SelectionState.none;
  
  /// 选择范围
  TextSelection? _selection;
  
  /// 选择的字符数据
  List<TextColumnData> _selectedChars = [];
  
  /// 当前页面数据
  TextPageData? _currentPageData;
  
  /// 触摸开始位置
  Offset? _touchStartPosition;
  
  /// 触摸开始时间
  DateTime? _touchStartTime;
  
  /// 是否在拖拽选择中（暂未使用，为未来功能预留）
  // bool _isDraggingSelection = false;
  
  /// 选择手柄位置
  Offset? _startHandlePosition;
  Offset? _endHandlePosition;
  
  /// 回调函数
  VoidCallback? onSelectionChanged;
  Function(String selectedText, TextSelection selection)? onTextSelected;
  Function(Offset position)? onTap;
  Function(Offset position)? onDoubleTap;
  Function(Offset position)? onLongPress;

  /// 设置当前页面数据
  void setCurrentPageData(TextPageData pageData) {
    _currentPageData = pageData;
    // 如果页面变化，清除选择状态
    if (_selectionState != SelectionState.none) {
      clearSelection();
    }
  }

  /// 处理指针按下事件
  void handlePointerDown(PointerDownEvent event) {
    _touchStartPosition = event.localPosition;
    _touchStartTime = DateTime.now();
    
    // 检查是否点击在选择手柄上
    if (_selectionState == SelectionState.selected) {
      if (_isPositionOnHandle(event.localPosition, _startHandlePosition)) {
        _selectionState = SelectionState.draggingStartHandle;
        // _isDraggingSelection = true;
        return;
      }
      
      if (_isPositionOnHandle(event.localPosition, _endHandlePosition)) {
        _selectionState = SelectionState.draggingEndHandle;
        // _isDraggingSelection = true;
        return;
      }
    }
  }

  /// 处理指针移动事件
  void handlePointerMove(PointerMoveEvent event) {
    if (_currentPageData == null) return;
    
    switch (_selectionState) {
      case SelectionState.selecting:
        _updateSelectionEnd(event.localPosition);
        break;
      case SelectionState.draggingStartHandle:
        _updateSelectionStart(event.localPosition);
        break;
      case SelectionState.draggingEndHandle:
        _updateSelectionEnd(event.localPosition);
        break;
      default:
        break;
    }
  }

  /// 处理指针抬起事件
  void handlePointerUp(PointerUpEvent event) {
    if (_touchStartPosition == null || _touchStartTime == null) return;
    
    final touchDuration = DateTime.now().difference(_touchStartTime!);
    final touchDistance = (event.localPosition - _touchStartPosition!).distance;
    
    // 判断手势类型
    if (touchDistance < 10.0) { // 点击
      if (touchDuration.inMilliseconds < 300) {
        _handleTap(event.localPosition);
      } else if (touchDuration.inMilliseconds > 500) {
        _handleLongPress(event.localPosition);
      }
    }
    
    // 重置状态
    if (_selectionState == SelectionState.draggingStartHandle ||
        _selectionState == SelectionState.draggingEndHandle) {
      _selectionState = SelectionState.selected;
      _updateHandlePositions();
    }
    
    // _isDraggingSelection = false;
    _touchStartPosition = null;
    _touchStartTime = null;
  }

  /// 处理双击事件
  void handleDoubleTap(TapDownDetails details) {
    if (_currentPageData == null) return;
    
    _selectWordAtPosition(details.localPosition);
    onDoubleTap?.call(details.localPosition);
  }

  /// 处理长按事件
  void handleLongPress(LongPressStartDetails details) {
    if (_currentPageData == null) return;
    
    _startSelectionAtPosition(details.localPosition);
    onLongPress?.call(details.localPosition);
  }

  /// 开始文字选择
  void _startSelectionAtPosition(Offset position) {
    final charData = _getCharacterAtPosition(position);
    if (charData == null) return;
    
    _selectionState = SelectionState.selecting;
    _selection = TextSelection(
      baseOffset: charData.charIndex,
      extentOffset: charData.charIndex + 1,
    );
    
    _updateSelectedChars();
    _updateHandlePositions();
    
    HapticFeedback.mediumImpact();
    onSelectionChanged?.call();
  }

  /// 选择位置处的单词
  void _selectWordAtPosition(Offset position) {
    final charData = _getCharacterAtPosition(position);
    if (charData == null) return;
    
    // 查找单词边界
    final wordBounds = _findWordBounds(charData.charIndex);
    if (wordBounds == null) return;
    
    _selectionState = SelectionState.selected;
    _selection = TextSelection(
      baseOffset: wordBounds.start,
      extentOffset: wordBounds.end,
    );
    
    _updateSelectedChars();
    _updateHandlePositions();
    
    HapticFeedback.selectionClick();
    onSelectionChanged?.call();
  }

  /// 更新选择的开始位置
  void _updateSelectionStart(Offset position) {
    if (_selection == null) return;
    
    final charData = _getCharacterAtPosition(position);
    if (charData == null) return;
    
    final newStart = charData.charIndex.clamp(0, _selection!.extentOffset - 1);
    _selection = _selection!.copyWith(baseOffset: newStart);
    
    _updateSelectedChars();
    _updateHandlePositions();
    onSelectionChanged?.call();
  }

  /// 更新选择的结束位置
  void _updateSelectionEnd(Offset position) {
    if (_selection == null) return;
    
    final charData = _getCharacterAtPosition(position);
    if (charData == null) return;
    
    final newEnd = (charData.charIndex + 1).clamp(
      _selection!.baseOffset + 1,
      _currentPageData!.characterCount,
    );
    _selection = _selection!.copyWith(extentOffset: newEnd);
    
    _updateSelectedChars();
    _updateHandlePositions();
    onSelectionChanged?.call();
  }

  /// 处理点击事件
  void _handleTap(Offset position) {
    if (_selectionState != SelectionState.none) {
      clearSelection();
    } else {
      onTap?.call(position);
    }
  }

  /// 处理长按事件
  void _handleLongPress(Offset position) {
    _startSelectionAtPosition(position);
  }

  /// 获取位置处的字符数据
  TextColumnData? _getCharacterAtPosition(Offset position) {
    return _currentPageData?.getCharAtPosition(position);
  }

  /// 查找单词边界
  TextRange? _findWordBounds(int charIndex) {
    if (_currentPageData == null) return null;
    
    final content = _currentPageData!.textContent;
    if (charIndex >= content.length) return null;
    
    // 简化的单词边界查找
    int start = charIndex;
    int end = charIndex + 1;
    
    // 向前查找单词开始
    while (start > 0 && _isWordCharacter(content[start - 1])) {
      start--;
    }
    
    // 向后查找单词结束
    while (end < content.length && _isWordCharacter(content[end])) {
      end++;
    }
    
    return TextRange(start: start, end: end);
  }

  /// 判断是否为单词字符
  bool _isWordCharacter(String char) {
    return char.contains(RegExp(r'[\w\u4e00-\u9fff]'));
  }

  /// 更新选中的字符数据
  void _updateSelectedChars() {
    if (_selection == null || _currentPageData == null) {
      _selectedChars.clear();
      return;
    }
    
    _selectedChars = _currentPageData!.getSelectionChars(
      _selection!.start,
      _selection!.end,
    );
    
    // 通知文字选择回调
    if (_selectedChars.isNotEmpty) {
      final selectedText = _selectedChars.map((char) => char.char).join();
      onTextSelected?.call(selectedText, _selection!);
    }
  }

  /// 更新手柄位置
  void _updateHandlePositions() {
    if (_selectedChars.isEmpty) {
      _startHandlePosition = null;
      _endHandlePosition = null;
      return;
    }
    
    final startChar = _selectedChars.first;
    final endChar = _selectedChars.last;
    
    _startHandlePosition = Offset(
      startChar.bounds.left,
      startChar.bounds.bottom + 8, // 手柄高度偏移
    );
    
    _endHandlePosition = Offset(
      endChar.bounds.right,
      endChar.bounds.bottom + 8,
    );
  }

  /// 检查位置是否在手柄上
  bool _isPositionOnHandle(Offset position, Offset? handlePosition) {
    if (handlePosition == null) return false;
    
    const handleSize = 24.0; // 手柄触摸区域大小
    final handleRect = Rect.fromCenter(
      center: handlePosition,
      width: handleSize,
      height: handleSize,
    );
    
    return handleRect.contains(position);
  }

  /// 清除选择状态
  void clearSelection() {
    _selectionState = SelectionState.none;
    _selection = null;
    _selectedChars.clear();
    _startHandlePosition = null;
    _endHandlePosition = null;
    onSelectionChanged?.call();
  }

  /// 复制选中的文本
  void copySelection() {
    if (_selectedChars.isNotEmpty) {
      final selectedText = _selectedChars.map((char) => char.char).join();
      Clipboard.setData(ClipboardData(text: selectedText));
    }
  }

  /// 获取当前选择状态
  SelectionState get selectionState => _selectionState;

  /// 获取选中的字符数据
  List<TextColumnData> get selectedChars => List.unmodifiable(_selectedChars);

  /// 获取选择的文本
  String get selectedText => _selectedChars.map((char) => char.char).join();

  /// 获取手柄位置
  Offset? get startHandlePosition => _startHandlePosition;
  Offset? get endHandlePosition => _endHandlePosition;

  /// 是否有选择
  bool get hasSelection => _selectionState != SelectionState.none && _selectedChars.isNotEmpty;

  /// 绘制选择高亮和手柄
  void paintSelection(Canvas canvas, Paint paint) {
    // 绘制选择高亮
    paint.color = Colors.blue.withValues(alpha: 0.3);
    for (final char in _selectedChars) {
      canvas.drawRect(char.bounds, paint);
    }
    
    // 绘制选择手柄
    if (_selectionState == SelectionState.selected) {
      _drawSelectionHandle(canvas, paint, _startHandlePosition, true);
      _drawSelectionHandle(canvas, paint, _endHandlePosition, false);
    }
  }

  /// 绘制选择手柄
  void _drawSelectionHandle(Canvas canvas, Paint paint, Offset? position, bool isStart) {
    if (position == null) return;
    
    const handleRadius = 8.0;
    const handleHeight = 20.0;
    
    // 绘制手柄圆形
    paint.color = Colors.blue;
    canvas.drawCircle(position, handleRadius, paint);
    
    // 绘制手柄线条
    final lineStart = Offset(position.dx, position.dy - handleHeight);
    final lineEnd = position;
    paint.strokeWidth = 2.0;
    canvas.drawLine(lineStart, lineEnd, paint);
  }
}

/// 选择状态枚举
enum SelectionState {
  none,           // 无选择
  selecting,      // 选择中
  selected,       // 已选择
  draggingStartHandle,  // 拖拽开始手柄
  draggingEndHandle,    // 拖拽结束手柄
}

/// 文本范围
class TextRange {
  final int start;
  final int end;

  const TextRange({required this.start, required this.end});

  int get length => end - start;
  bool get isEmpty => start == end;
  bool get isNotEmpty => !isEmpty;

  bool contains(int position) => position >= start && position < end;

  @override
  String toString() => 'TextRange($start, $end)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextRange && runtimeType == other.runtimeType && start == other.start && end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}
