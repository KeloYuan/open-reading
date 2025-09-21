class Bookmark {
  final int? id;
  final int bookId;
  final int pageNumber;
  final String note;
  final DateTime createDate;
  final String? cfi;

  Bookmark({
    this.id,
    required this.bookId,
    required this.pageNumber,
    this.note = '',
    DateTime? createDate,
    this.cfi,
  }) : createDate = createDate ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'pageNumber': pageNumber,
      'note': note,
      'createDate': createDate.millisecondsSinceEpoch,
      'cfi': cfi,
    };
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'],
      bookId: map['bookId'],
      pageNumber: map['pageNumber'],
      note: map['note'] ?? '',
      createDate: DateTime.fromMillisecondsSinceEpoch(map['createDate']),
      cfi: map['cfi'],
    );
  }

  Bookmark copyWith({
    int? id,
    int? bookId,
    int? pageNumber,
    String? note,
    DateTime? createDate,
    String? cfi,
  }) {
    return Bookmark(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      pageNumber: pageNumber ?? this.pageNumber,
      note: note ?? this.note,
      createDate: createDate ?? this.createDate,
      cfi: cfi ?? this.cfi,
    );
  }
}
