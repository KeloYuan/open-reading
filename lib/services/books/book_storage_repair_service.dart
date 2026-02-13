import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_dao.dart';

/// 书籍存储路径修复服务
///
/// 场景：
/// - 版本升级/重装后，数据库里还保留旧的绝对路径
/// - 书籍文件和封面实际还在，但因为沙盒路径前缀变化导致无法打开
///
/// 策略（尽量保守）：
/// 1) 文件/封面路径可用 -> 不改
/// 2) 不可用 -> 在当前 documents/books 与 documents/covers 按文件名尝试恢复
/// 3) 找到后只更新数据库路径，不改业务数据
class BookStorageRepairService {
  final BookDao _bookDao = BookDao();

  Future<int> repairAllBooksIfNeeded() async {
    final books = await _bookDao.getAllBooks();
    int repairedCount = 0;

    for (final book in books) {
      final repaired = await repairSingleBookIfNeeded(book);
      if (repaired.filePath != book.filePath ||
          repaired.coverImagePath != book.coverImagePath) {
        repairedCount++;
      }
    }

    if (repairedCount > 0) {
      debugPrint('🔧 已修复 $repairedCount 本书的存储路径');
    } else {
      debugPrint('✅ 书籍存储路径检查完成，无需修复');
    }

    return repairedCount;
  }

  Future<Book> repairSingleBookIfNeeded(Book book) async {
    // 没有数据库ID时无法回写，只做读取校验
    if (book.id == null) {
      return book;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(docsDir.path, 'books'));
    final coversDir = Directory(p.join(docsDir.path, 'covers'));

    String filePath = book.filePath;
    String? coverPath = book.coverImagePath;
    bool changed = false;

    // 1) 修复正文文件路径
    final repairedFilePath = await _repairFilePath(
      currentPath: filePath,
      targetDir: booksDir,
    );
    if (repairedFilePath != null && repairedFilePath != filePath) {
      filePath = repairedFilePath;
      await _bookDao.updateBookFilePath(book.id!, filePath);
      changed = true;
      debugPrint('🔧 修复书籍文件路径: ${book.title} -> $filePath');
    }

    // 2) 修复封面路径
    final repairedCoverPath = await _repairFilePath(
      currentPath: coverPath,
      targetDir: coversDir,
    );
    if (repairedCoverPath != coverPath) {
      coverPath = repairedCoverPath;
      await _bookDao.updateBookCoverPath(book.id!, coverPath);
      changed = true;
      if (coverPath != null) {
        debugPrint('🖼️ 修复封面路径: ${book.title} -> $coverPath');
      } else {
        debugPrint('🖼️ 清理失效封面路径: ${book.title}');
      }
    }

    if (!changed) {
      return book;
    }

    return book.copyWith(filePath: filePath, coverImagePath: coverPath);
  }

  Future<String?> _repairFilePath({
    required String? currentPath,
    required Directory targetDir,
  }) async {
    if (currentPath == null || currentPath.isEmpty) {
      return null;
    }

    // 当前路径可用，直接返回
    final currentFile = File(currentPath);
    if (await currentFile.exists()) {
      return currentPath;
    }

    // 目录不存在，无法恢复
    if (!await targetDir.exists()) {
      return null;
    }

    // 先按文件名精确匹配（最稳妥）
    final fileName = p.basename(currentPath);
    final exactPath = p.join(targetDir.path, fileName);
    if (await File(exactPath).exists()) {
      return exactPath;
    }

    // 再按去扩展名模糊匹配，兼容重命名后缀 _1/_2 的情况
    final oldStem = p.basenameWithoutExtension(fileName);
    final oldExt = p.extension(fileName).toLowerCase();
    try {
      final candidates = targetDir.listSync().whereType<File>();
      for (final file in candidates) {
        final stem = p.basenameWithoutExtension(file.path);
        final ext = p.extension(file.path).toLowerCase();
        if (ext == oldExt && (stem == oldStem || stem.startsWith('${oldStem}_'))) {
          return file.path;
        }
      }
    } catch (e) {
      debugPrint('⚠️ 扫描目录失败: ${targetDir.path}, $e');
    }

    // 找不到时返回 null，调用方可清理无效路径
    return null;
  }
}
