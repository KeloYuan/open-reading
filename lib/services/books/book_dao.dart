// 文件说明：书籍 DAO，负责书籍元数据、进度和分页缓存字段的数据库读写。
// 技术要点：服务层、Flutter。

import 'package:flutter/material.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/services/core/database_service.dart';
import 'package:xxread/services/books/book_image_map_service.dart';
import 'package:xxread/services/pagination/pagination_cache_service.dart';

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
          'cover_image_path',
          'text_encoding',
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

      // 🗑️ 删除相关缓存
      await _deleteBookCaches(bookId);

      // 删除数据库记录
      final result = await db.delete(
        'books',
        where: 'id = ?',
        whereArgs: [bookId],
      );
      if (result == 0) {
        throw Exception('书籍不存在或已被删除');
      }

      debugPrint('✅ 书籍已删除: $bookId（包括所有相关缓存）');
    } catch (e) {
      throw Exception('删除书籍失败: $e');
    }
  }

  /// 删除书籍相关的所有缓存
  ///
  /// 包括：
  /// - 分页缓存（所有排版参数组合）
  /// - 图片映射文件
  Future<void> _deleteBookCaches(int bookId) async {
    debugPrint('🗑️ 开始清除书籍缓存: $bookId');

    try {
      // 1. 删除图片映射
      final imageMapService = BookImageMapService();
      await imageMapService.deleteImageMap(bookId);
      debugPrint('  ✅ 图片映射已删除');
    } catch (e) {
      debugPrint('  ⚠️ 删除图片映射失败: $e');
    }

    try {
      // 2. 删除分页缓存（使用高性能方法）
      final book = await getBookById(bookId);
      if (book != null && book.contentHash != null) {
        // 🚀 使用 PaginationCacheService 的高性能删除方法
        // 只读取文件头部 512 字节，批量并行处理
        await PaginationCacheService.deleteCacheForBookFast(book.contentHash!);
        debugPrint('  ✅ 分页缓存已删除');
      }
    } catch (e) {
      debugPrint('  ⚠️ 删除分页缓存失败: $e');
    }

    debugPrint('🗑️ 缓存清除完成');
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

  // 更新书籍封面图片路径
  Future<void> updateBookCoverPath(int bookId, String? coverImagePath) async {
    try {
      final db = await _dbService.database;
      final result = await db.update(
        'books',
        {'cover_image_path': coverImagePath},
        where: 'id = ?',
        whereArgs: [bookId],
      );
      if (result == 0) {
        throw Exception('书籍不存在');
      }
    } catch (e) {
      throw Exception('更新书籍封面失败: $e');
    }
  }

  // 更新书籍编码
  Future<void> updateBookTextEncoding(int bookId, String? textEncoding) async {
    try {
      final db = await _dbService.database;
      final result = await db.update(
        'books',
        {'text_encoding': textEncoding},
        where: 'id = ?',
        whereArgs: [bookId],
      );
      if (result == 0) {
        throw Exception('书籍不存在');
      }
    } catch (e) {
      throw Exception('更新书籍编码失败: $e');
    }
  }

  /// 通过内容哈希值查找书籍
  ///
  /// 用于检查是否已导入相同内容的书籍
  /// 参数 [contentHash] 书籍文件的MD5哈希值
  /// 返回找到的书籍，如果不存在则返回null
  Future<Book?> getBookByHash(String contentHash) async {
    try {
      final db = await _dbService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'books',
        where: 'content_hash = ?',
        whereArgs: [contentHash],
      );
      if (maps.isNotEmpty) {
        return Book.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      throw Exception('通过哈希值查找书籍失败: $e');
    }
  }

  // We can add other DAOs (e.g., BookmarkDao) in separate files
  // for better organization.
}
