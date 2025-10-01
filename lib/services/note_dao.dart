import '../models/note.dart';
import 'book_note_dao.dart';

/// 笔记数据访问对象 - BookNoteDao的兼容层
/// 为了保持向后兼容，提供NoteDao类作为BookNoteDao的包装
class NoteDao {
  final BookNoteDao _bookNoteDao = BookNoteDao();

  /// 插入笔记
  Future<int> insertNote(Note note) async {
    final bookNote = note.toBookNote();
    return await _bookNoteDao.insertBookNote(bookNote);
  }

  /// 更新笔记
  Future<void> updateNote(Note note) async {
    if (note.id == null) {
      throw ArgumentError('Note id cannot be null for update operation');
    }
    final bookNote = note.toBookNote();
    await _bookNoteDao.updateBookNoteById(bookNote);
  }

  /// 删除笔记
  Future<void> deleteNote(int id) async {
    await _bookNoteDao.deleteBookNoteById(id);
  }

  /// 根据书籍ID获取所有笔记
  Future<List<Note>> getNotesByBook(int bookId) async {
    final bookNotes = await _bookNoteDao.selectBookNotesByBookId(bookId);
    return bookNotes
        .where(
          (bookNote) =>
              bookNote.type == 'note' ||
              (bookNote.readerNote != null && bookNote.readerNote!.isNotEmpty),
        )
        .map((bookNote) => Note.fromBookNote(bookNote))
        .toList();
  }

  /// 根据ID获取笔记
  Future<Note?> getNoteById(int id) async {
    try {
      final bookNote = await _bookNoteDao.selectBookNoteById(id);
      if (bookNote.type == 'note' ||
          (bookNote.readerNote != null && bookNote.readerNote!.isNotEmpty)) {
        return Note.fromBookNote(bookNote);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 根据CFI获取笔记
  Future<List<Note>> getNotesByCfi(String cfi, int bookId) async {
    final bookNotes = await _bookNoteDao.selectBookNoteByCfiAndBookId(
      cfi,
      bookId,
    );
    return bookNotes
        .where(
          (bookNote) =>
              bookNote.type == 'note' ||
              (bookNote.readerNote != null && bookNote.readerNote!.isNotEmpty),
        )
        .map((bookNote) => Note.fromBookNote(bookNote))
        .toList();
  }

  /// 搜索笔记内容
  Future<List<Note>> searchNotes(int bookId, String query) async {
    final bookNotes = await _bookNoteDao.searchBookNotes(bookId, query);
    return bookNotes
        .where(
          (bookNote) =>
              bookNote.type == 'note' ||
              (bookNote.readerNote != null && bookNote.readerNote!.isNotEmpty),
        )
        .map((bookNote) => Note.fromBookNote(bookNote))
        .toList();
  }

  /// 获取书籍的笔记统计
  Future<Map<String, int>> getNoteStatsByBook(int bookId) async {
    final notes = await getNotesByBook(bookId);
    return {
      'total': notes.length,
      'thisMonth': notes
          .where(
            (n) =>
                n.createTime != null &&
                n.createTime!.isAfter(
                  DateTime.now().subtract(const Duration(days: 30)),
                ),
          )
          .length,
    };
  }

  /// 根据章节获取笔记
  Future<List<Note>> getNotesByChapter(int bookId, String chapter) async {
    final bookNotes = await _bookNoteDao.selectBookNotesByChapter(
      bookId,
      chapter,
    );
    return bookNotes
        .where(
          (bookNote) =>
              bookNote.type == 'note' ||
              (bookNote.readerNote != null && bookNote.readerNote!.isNotEmpty),
        )
        .map((bookNote) => Note.fromBookNote(bookNote))
        .toList();
  }

  /// 批量插入笔记
  Future<List<int>> insertNotes(List<Note> notes) async {
    final List<int> ids = [];
    for (final note in notes) {
      final id = await insertNote(note);
      ids.add(id);
    }
    return ids;
  }

  /// 检查是否存在笔记
  Future<bool> hasNote(int bookId, String cfi) async {
    final notes = await getNotesByCfi(cfi, bookId);
    return notes.isNotEmpty;
  }

  /// 获取最近的笔记
  Future<List<Note>> getRecentNotes(int bookId, {int limit = 10}) async {
    final bookNotes = await _bookNoteDao.selectRecentBookNotes(
      bookId,
      limit: limit,
    );
    return bookNotes
        .where(
          (bookNote) =>
              bookNote.type == 'note' ||
              (bookNote.readerNote != null && bookNote.readerNote!.isNotEmpty),
        )
        .map((bookNote) => Note.fromBookNote(bookNote))
        .toList();
  }
}
