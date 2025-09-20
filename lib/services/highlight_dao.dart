import '../models/highlight.dart';
import 'book_note_dao.dart';

/// 高亮数据访问对象 - BookNoteDao的兼容层
/// 为了保持向后兼容，提供HighlightDao类作为BookNoteDao的包装
class HighlightDao {
  final BookNoteDao _bookNoteDao = BookNoteDao();

  /// 插入高亮
  Future<int> insertHighlight(Highlight highlight) async {
    final bookNote = highlight.toBookNote();
    return await _bookNoteDao.insertBookNote(bookNote);
  }

  /// 更新高亮
  Future<void> updateHighlight(Highlight highlight) async {
    if (highlight.id == null) {
      throw ArgumentError('Highlight id cannot be null for update operation');
    }
    final bookNote = highlight.toBookNote();
    await _bookNoteDao.updateBookNoteById(bookNote);
  }

  /// 删除高亮
  Future<void> deleteHighlight(int id) async {
    await _bookNoteDao.deleteBookNoteById(id);
  }

  /// 根据书籍ID获取所有高亮
  Future<List<Highlight>> getHighlightsByBook(int bookId) async {
    final bookNotes = await _bookNoteDao.selectBookNotesByBookId(bookId);
    return bookNotes
        .where((note) => note.type == 'highlight')
        .map((note) => Highlight.fromBookNote(note))
        .toList();
  }

  /// 根据ID获取高亮
  Future<Highlight?> getHighlightById(int id) async {
    try {
      final bookNote = await _bookNoteDao.selectBookNoteById(id);
      if (bookNote.type == 'highlight') {
        return Highlight.fromBookNote(bookNote);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 根据CFI获取高亮
  Future<List<Highlight>> getHighlightsByCfi(String cfi, int bookId) async {
    final bookNotes = await _bookNoteDao.selectBookNoteByCfiAndBookId(
      cfi,
      bookId,
    );
    return bookNotes
        .where((note) => note.type == 'highlight')
        .map((note) => Highlight.fromBookNote(note))
        .toList();
  }

  /// 搜索高亮文本
  Future<List<Highlight>> searchHighlights(int bookId, String query) async {
    final bookNotes = await _bookNoteDao.searchBookNotes(bookId, query);
    return bookNotes
        .where((note) => note.type == 'highlight')
        .map((note) => Highlight.fromBookNote(note))
        .toList();
  }

  /// 获取书籍的高亮统计
  Future<Map<String, int>> getHighlightStatsByBook(int bookId) async {
    final highlights = await getHighlightsByBook(bookId);
    return {
      'total': highlights.length,
      'thisMonth': highlights
          .where(
            (h) =>
                h.createTime != null &&
                h.createTime!.isAfter(
                  DateTime.now().subtract(const Duration(days: 30)),
                ),
          )
          .length,
    };
  }

  /// 根据章节获取高亮
  Future<List<Highlight>> getHighlightsByChapter(
    int bookId,
    String chapter,
  ) async {
    final bookNotes = await _bookNoteDao.selectBookNotesByChapter(
      bookId,
      chapter,
    );
    return bookNotes
        .where((note) => note.type == 'highlight')
        .map((note) => Highlight.fromBookNote(note))
        .toList();
  }

  /// 批量插入高亮
  Future<List<int>> insertHighlights(List<Highlight> highlights) async {
    final List<int> ids = [];
    for (final highlight in highlights) {
      final id = await insertHighlight(highlight);
      ids.add(id);
    }
    return ids;
  }

  /// 检查是否存在高亮
  Future<bool> hasHighlight(int bookId, String cfi) async {
    final highlights = await getHighlightsByCfi(cfi, bookId);
    return highlights.isNotEmpty;
  }
}
