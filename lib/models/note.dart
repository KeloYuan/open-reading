import 'book_note.dart';

/// 笔记模型 - BookNote的兼容层
/// 为了保持向后兼容，提供Note类作为BookNote的包装
class Note {
  final int? id;
  final int bookId;
  final int pageNumber;
  final String content;
  final String note;
  final String? cfi;
  final String chapter;
  final DateTime? createTime;

  const Note({
    this.id,
    required this.bookId,
    required this.pageNumber,
    required this.content,
    required this.note,
    this.cfi,
    required this.chapter,
    this.createTime,
  });

  /// 从BookNote创建Note
  factory Note.fromBookNote(BookNote bookNote) {
    // 可以接受 note 类型或带有 readerNote 的高亮
    return Note(
      id: bookNote.id,
      bookId: bookNote.bookId,
      pageNumber: bookNote.pageNumber ?? 0,
      content: bookNote.content,
      note: bookNote.readerNote ?? '',
      cfi: bookNote.cfi,
      chapter: bookNote.chapter,
      createTime: bookNote.createTime,
    );
  }

  /// 转换为BookNote
  BookNote toBookNote() {
    return BookNote(
      id: id,
      bookId: bookId,
      content: content,
      cfi: cfi ?? '',
      chapter: chapter,
      type: 'note',
      color: 'FFEB3B', // 默认黄色
      readerNote: note,
      pageNumber: pageNumber,
      createTime: createTime,
    );
  }

  /// 创建副本
  Note copyWith({
    int? id,
    int? bookId,
    int? pageNumber,
    String? content,
    String? note,
    String? cfi,
    String? chapter,
    DateTime? createTime,
  }) {
    return Note(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      pageNumber: pageNumber ?? this.pageNumber,
      content: content ?? this.content,
      note: note ?? this.note,
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
  factory Note.fromMap(Map<String, dynamic> map) {
    final bookNote = BookNote.fromMap(map);
    return Note.fromBookNote(bookNote);
  }

  @override
  String toString() {
    return 'Note{id: $id, bookId: $bookId, pageNumber: $pageNumber, content: ${content.length > 30 ? content.substring(0, 30) + '...' : content}, note: ${note.length > 30 ? note.substring(0, 30) + '...' : note}}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
