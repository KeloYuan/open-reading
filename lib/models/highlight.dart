import 'package:flutter/material.dart';
import 'book_note.dart';

/// 高亮注释模型 - BookNote的兼容层
/// 为了保持向后兼容，提供Highlight类作为BookNote的包装
class Highlight {
  final int? id;
  final int bookId;
  final int pageNumber;
  final String selectedText;
  final int startOffset;
  final int endOffset;
  final Color color;
  final String? cfi;
  final String chapter;
  final DateTime? createTime;

  const Highlight({
    this.id,
    required this.bookId,
    required this.pageNumber,
    required this.selectedText,
    required this.startOffset,
    required this.endOffset,
    required this.color,
    this.cfi,
    required this.chapter,
    this.createTime,
  });

  /// 从BookNote创建Highlight
  factory Highlight.fromBookNote(BookNote note) {
    if (note.type != 'highlight') {
      throw ArgumentError('BookNote type must be "highlight"');
    }

    return Highlight(
      id: note.id,
      bookId: note.bookId,
      pageNumber: note.pageNumber ?? 0,
      selectedText: note.content,
      startOffset: note.startOffset ?? 0,
      endOffset: note.endOffset ?? note.content.length,
      color: note.colorValue,
      cfi: note.cfi,
      chapter: note.chapter,
      createTime: note.createTime,
    );
  }

  /// 转换为BookNote
  BookNote toBookNote() {
    return BookNote(
      id: id,
      bookId: bookId,
      content: selectedText,
      cfi: cfi ?? '',
      chapter: chapter,
      type: 'highlight',
      color: color.toARGB32().toRadixString(16).substring(2).toUpperCase(),
      pageNumber: pageNumber,
      startOffset: startOffset,
      endOffset: endOffset,
      createTime: createTime,
    );
  }

  /// 创建副本
  Highlight copyWith({
    int? id,
    int? bookId,
    int? pageNumber,
    String? selectedText,
    int? startOffset,
    int? endOffset,
    Color? color,
    String? cfi,
    String? chapter,
    DateTime? createTime,
  }) {
    return Highlight(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      pageNumber: pageNumber ?? this.pageNumber,
      selectedText: selectedText ?? this.selectedText,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      color: color ?? this.color,
      cfi: cfi ?? this.cfi,
      chapter: chapter ?? this.chapter,
      createTime: createTime ?? this.createTime,
    );
  }

  /// 转换为Map（用于数据库）
  Map<String, dynamic> toMap() {
    return toBookNote().toMap();
  }

  /// 从Map创建实例
  factory Highlight.fromMap(Map<String, dynamic> map) {
    final bookNote = BookNote.fromMap(map);
    return Highlight.fromBookNote(bookNote);
  }

  @override
  String toString() {
    return 'Highlight{id: $id, bookId: $bookId, pageNumber: $pageNumber, selectedText: ${selectedText.length > 30 ? '${selectedText.substring(0, 30)}...' : selectedText}}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Highlight && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  // ===== 缺失方法的补充实现 =====

  /// 获取颜色名称
  String getColorName() {
    return BookNote.getColorName(
      color.toARGB32().toRadixString(16).substring(2).toUpperCase(),
    );
  }

  /// 静态方法：获取颜色名称（用于与服务类兼容）
  static String getColorNameStatic(Color color) {
    return BookNote.getColorName(
      color.toARGB32().toRadixString(16).substring(2).toUpperCase(),
    );
  }

  /// 获取笔记文本（兼容性属性）
  String? get noteText => null; // Highlight没有笔记，返回null

  /// 创建日期（兼容性属性）
  DateTime? get createDate => createTime;

  /// 更新日期（兼容性属性）
  DateTime? get updateDate => createTime; // Highlight使用单一时间

  /// 高亮颜色列表（静态属性）
  static List<Color> get highlightColors => BookNote.noteColors
      .map((colorHex) => Color(int.parse('0xFF$colorHex')))
      .toList();

  /// 转换为导出映射
  Map<String, dynamic> toExportMap() {
    return {
      'content': selectedText,
      'type': 'highlight',
      'color': getColorName(),
      'chapter': chapter,
      'page': pageNumber,
      'createTime': createTime?.toIso8601String(),
      'updateTime': createTime?.toIso8601String(),
    };
  }
}
