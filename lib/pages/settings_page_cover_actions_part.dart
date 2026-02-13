part of 'settings_page.dart';

extension _SettingsPageCoverActions on _SettingsPageState {
  // 重新提取所有书籍封面
  Future<void> _refreshAllCovers() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('重新提取封面'),
          content: const Text('此操作将为所有书籍重新提取封面，可能需要较长时间。确定继续吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确定'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        showSideToast(context, '开始重新生成封面...');
        final books = await _bookDao.getAllBooks();
        int successCount = 0;
        int failedCount = 0;

        for (final book in books) {
          final bookId = book.id;
          if (bookId == null) {
            failedCount++;
            continue;
          }

          try {
            final bytes = await CoverGenerator.generateTextCover(
              title: book.title,
              author: book.author.isEmpty ? '未知' : book.author,
              format: book.format,
            );
            final newCoverPath = await CoverGenerator.saveCover(
              bytes,
              book.filePath.isNotEmpty ? book.filePath : book.title,
            );
            await _bookDao.updateBookCoverPath(bookId, newCoverPath);

            final oldCoverPath = book.coverImagePath;
            if (oldCoverPath != null &&
                oldCoverPath.isNotEmpty &&
                oldCoverPath != newCoverPath) {
              final oldFile = File(oldCoverPath);
              if (await oldFile.exists()) {
                await oldFile.delete();
              }
            }
            successCount++;
          } catch (e) {
            failedCount++;
            debugPrint('重新生成封面失败(${book.title}): $e');
          }
        }

        if (mounted) {
          showSideToast(context, '封面重建完成：成功 $successCount，本失败 $failedCount');
        }
      }
    } catch (e) {
      if (mounted) {
        showSideToast(context, '操作失败: $e');
      }
    }
  }

  // 清理封面缓存
  Future<void> _cleanCoverCache() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory('${docsDir.path}/covers');
      final imageCacheDir = Directory('${docsDir.path}/book_images');
      int deletedFileCount = 0;

      Future<void> deleteDirFiles(Directory dir) async {
        if (!await dir.exists()) return;
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            deletedFileCount++;
          }
        }
        await dir.delete(recursive: true);
      }

      await deleteDirFiles(coversDir);
      await deleteDirFiles(imageCacheDir);

      // 清理数据库中的封面路径引用，避免悬挂路径。
      final books = await _bookDao.getAllBooks();
      for (final book in books) {
        final bookId = book.id;
        if (bookId != null && (book.coverImagePath?.isNotEmpty ?? false)) {
          await _bookDao.updateBookCoverPath(bookId, null);
        }
      }

      if (!mounted) return;
      showSideToast(context, '已清理封面缓存文件 $deletedFileCount 个');
    } catch (e) {
      if (!mounted) return;
      showSideToast(context, '清理失败: $e');
    }
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restart_alt, color: Colors.orange),
            SizedBox(width: 8),
            Text('需要重启应用'),
          ],
        ),
        content: const Text('书源功能的开启/关闭需要重启应用才能生效。\n\n是否现在重启应用？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Flutter 在 iOS 上不推荐主动退出应用，统一提示用户手动重启。
              _showInfoSnackBar('请手动重启应用以应用设置');
            },
            child: const Text('重启'),
          ),
        ],
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    showSideToast(context, message);
  }
}
