import '../models/bookmark.dart';
import 'database_service.dart';

class BookmarkDao {
  final DatabaseService _databaseService = DatabaseService();

  // 添加书签
  Future<int> insertBookmark(Bookmark bookmark) async {
    final db = await _databaseService.database;
    return await db.insert('bookmarks', bookmark.toMap());
  }

  // 获取指定书籍的所有书签
  Future<List<Bookmark>> getBookmarksForBook(int bookId) async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bookmarks',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'pageNumber ASC',
    );

    return List.generate(maps.length, (i) {
      return Bookmark.fromMap(maps[i]);
    });
  }

  // 检查指定页面是否已有书签
  Future<bool> hasBookmarkOnPage(int bookId, int pageNumber) async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> result = await db.query(
      'bookmarks',
      where: 'bookId = ? AND pageNumber = ?',
      whereArgs: [bookId, pageNumber],
    );
    return result.isNotEmpty;
  }

  // 获取指定页面的书签
  Future<Bookmark?> getBookmarkOnPage(int bookId, int pageNumber) async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bookmarks',
      where: 'bookId = ? AND pageNumber = ?',
      whereArgs: [bookId, pageNumber],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Bookmark.fromMap(maps.first);
    }
    return null;
  }

  // 删除书签
  Future<int> deleteBookmark(int id) async {
    final db = await _databaseService.database;
    return await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  // 删除指定页面的书签
  Future<int> deleteBookmarkOnPage(int bookId, int pageNumber) async {
    final db = await _databaseService.database;
    return await db.delete(
      'bookmarks',
      where: 'bookId = ? AND pageNumber = ?',
      whereArgs: [bookId, pageNumber],
    );
  }

  // 更新书签备注
  Future<int> updateBookmarkNote(int id, String note) async {
    final db = await _databaseService.database;
    return await db.update(
      'bookmarks',
      {'note': note},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 更新整个书签对象
  Future<int> updateBookmark(Bookmark bookmark) async {
    final db = await _databaseService.database;
    return await db.update(
      'bookmarks',
      bookmark.toMap(),
      where: 'id = ?',
      whereArgs: [bookmark.id],
    );
  }

  // 获取所有书签数量
  Future<int> getBookmarkCount(int bookId) async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM bookmarks WHERE bookId = ?',
      [bookId],
    );
    return result.first['count'] ?? 0;
  }

  // 删除指定书籍的所有书签
  Future<int> deleteAllBookmarksForBook(int bookId) async {
    final db = await _databaseService.database;
    return await db.delete(
      'bookmarks',
      where: 'bookId = ?',
      whereArgs: [bookId],
    );
  }
}
