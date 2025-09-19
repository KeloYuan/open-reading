import 'package:flutter/material.dart';

class Highlight {
  final int? id;
  final int bookId;
  final int pageNumber;
  final String selectedText;
  final int startOffset;
  final int endOffset;
  final Color color;
  final String? cfi; // CanonicalFragmentIdentifier for EPUB positioning
  final String? chapter; // Chapter title or identifier
  final String? noteText; // Optional note attached to highlight
  final DateTime createDate;
  final DateTime? updateDate;

  Highlight({
    this.id,
    required this.bookId,
    required this.pageNumber,
    required this.selectedText,
    required this.startOffset,
    required this.endOffset,
    required this.color,
    this.cfi,
    this.chapter,
    this.noteText,
    DateTime? createDate,
    this.updateDate,
  }) : createDate = createDate ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'pageNumber': pageNumber,
      'selectedText': selectedText,
      'startOffset': startOffset,
      'endOffset': endOffset,
      'colorValue': color.toARGB32(),
      'cfi': cfi,
      'chapter': chapter,
      'noteText': noteText,
      'createDate': createDate.millisecondsSinceEpoch,
      'updateDate': updateDate?.millisecondsSinceEpoch,
    };
  }

  factory Highlight.fromMap(Map<String, dynamic> map) {
    return Highlight(
      id: map['id'],
      bookId: map['bookId'],
      pageNumber: map['pageNumber'],
      selectedText: map['selectedText'],
      startOffset: map['startOffset'],
      endOffset: map['endOffset'],
      color: Color(map['colorValue']),
      cfi: map['cfi'],
      chapter: map['chapter'],
      noteText: map['noteText'],
      createDate: DateTime.fromMillisecondsSinceEpoch(map['createDate']),
      updateDate: map['updateDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updateDate'])
          : null,
    );
  }

  // 预定义的荧光笔颜色
  static const List<Color> highlightColors = [
    Color(0xFFFFEB3B), // 黄色
    Color(0xFF4CAF50), // 绿色
    Color(0xFF2196F3), // 蓝色
    Color(0xFFF44336), // 红色
    Color(0xFF9C27B0), // 紫色
    Color(0xFFFF9800), // 橙色
  ];

  static String getColorName(Color color) {
    switch (color.toARGB32()) {
      case 0xFFFFEB3B:
        return '黄色';
      case 0xFF4CAF50:
        return '绿色';
      case 0xFF2196F3:
        return '蓝色';
      case 0xFFF44336:
        return '红色';
      case 0xFF9C27B0:
        return '紫色';
      case 0xFFFF9800:
        return '橙色';
      default:
        return '自定义';
    }
  }

  /// 创建带笔记的高亮副本
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
    String? noteText,
    DateTime? createDate,
    DateTime? updateDate,
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
      noteText: noteText ?? this.noteText,
      createDate: createDate ?? this.createDate,
      updateDate: updateDate ?? this.updateDate,
    );
  }

  /// 转换为导出格式
  Map<String, dynamic> toExportMap() {
    return {
      'text': selectedText,
      'note': noteText,
      'color': getColorName(color),
      'chapter': chapter,
      'page': pageNumber,
      'createDate': createDate.toIso8601String(),
      'updateDate': updateDate?.toIso8601String(),
    };
  }
}
