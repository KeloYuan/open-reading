import '../models/book.dart';
import 'database_service.dart';

class BookDao {
  final _dbService = DatabaseService();

  Future<int> insertBook(Book book) async {
    try {
      final db = await _dbService.database;
      return await db.insert('books', book.toMap());
    } catch (e) {
      throw Exception('添加书籍失败: $e');
    }
  }

  Future<List<Book>> getAllBooks() async {
    try {
      final db = await _dbService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'books',
        columns: [
          'id',
          'title',
          'author',
          'filePath',
          'format',
          'currentPage',
          'totalPages',
          'importDate',
          'file_modified_time',
          'content_hash',
        ],
        orderBy: 'importDate DESC',
      );
      return List.generate(maps.length, (i) => Book.fromMap(maps[i]));
    } catch (e) {
      throw Exception('获取书籍列表失败: $e');
    }
  }

  Future<void> updateBookProgress(int bookId, int currentPage) async {
    try {
      final db = await _dbService.database;
      final result = await db.update(
        'books',
        {'currentPage': currentPage},
        where: 'id = ?',
        whereArgs: [bookId],
      );
      if (result == 0) {
        throw Exception('书籍不存在');
      }
    } catch (e) {
      throw Exception('更新阅读进度失败: $e');
    }
  }

  Future<int> getBooksCount() async {
    try {
      final db = await _dbService.database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM books');
      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      throw Exception('获取书籍数量失败: $e');
    }
  }

  Future<Book?> getBookById(int bookId) async {
    try {
      final db = await _dbService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'books',
        where: 'id = ?',
        whereArgs: [bookId],
      );
      if (maps.isNotEmpty) {
        return Book.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      throw Exception('获取书籍详情失败: $e');
    }
  }

  Future<void> updateBookTotalPages(int bookId, int totalPages) async {
    final db = await _dbService.database;
    await db.update(
      'books',
      {'totalPages': totalPages},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> updateBook(Book book) async {
    try {
      final db = await _dbService.database;
      final result = await db.update(
        'books',
        book.toMap(),
        where: 'id = ?',
        whereArgs: [book.id],
      );
      if (result == 0) {
        throw Exception('书籍不存在');
      }
    } catch (e) {
      throw Exception('更新书籍信息失败: $e');
    }
  }

  Future<void> deleteBook(int bookId) async {
    try {
      final db = await _dbService.database;
      final result = await db.delete(
        'books',
        where: 'id = ?',
        whereArgs: [bookId],
      );
      if (result == 0) {
        throw Exception('书籍不存在或已被删除');
      }
    } catch (e) {
      throw Exception('删除书籍失败: $e');
    }
  }

  // 更新书籍文件路径 - 用于处理iOS沙盒路径变更
  Future<void> updateBookFilePath(int bookId, String newFilePath) async {
    try {
      final db = await _dbService.database;
      final result = await db.update(
        'books',
        {'filePath': newFilePath},
        where: 'id = ?',
        whereArgs: [bookId],
      );
      if (result == 0) {
        throw Exception('书籍不存在');
      }
    } catch (e) {
      throw Exception('更新书籍文件路径失败: $e');
    }
  }

  // We can add other DAOs (e.g., BookmarkDao) in separate files
  // for better organization.
}
