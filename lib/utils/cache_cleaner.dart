import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// 缓存清理工具
///
/// 用于清理无主图片文件（没有对应书籍的图片）
class CacheCleaner {
  /// 清理无主图片文件
  ///
  /// 扫描所有图片文件和映射文件，删除没有对应映射的图片
  static Future<Map<String, dynamic>> cleanOrphanedImages() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imageDir = Directory(path.join(appDir.path, 'book_images'));

      if (!await imageDir.exists()) {
        debugPrint('📂 图片目录不存在，无需清理');
        return {'deleted': 0, 'kept': 0, 'freed_mb': 0.0};
      }

      // 1. 收集所有映射文件中的图片路径
      final validImagePaths = <String>{};
      final files = await imageDir.list().toList();

      for (var file in files) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final content = await file.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            final imageMap = json['imageMap'] as Map<String, dynamic>?;
            if (imageMap != null) {
              for (var imagePath in imageMap.values) {
                validImagePaths.add(path.basename(imagePath.toString()));
              }
            }
          } catch (e) {
            debugPrint('⚠️ 读取映射文件失败: ${file.path}, $e');
          }
        }
      }

      debugPrint('📊 有效图片数量: ${validImagePaths.length}');

      // 2. 扫描所有图片文件，删除无主图片
      int deletedCount = 0;
      int keptCount = 0;
      int freedBytes = 0;

      for (var file in files) {
        if (file is File &&
            !file.path.endsWith('.json') &&
            (file.path.endsWith('.jpeg') ||
                file.path.endsWith('.jpg') ||
                file.path.endsWith('.png'))) {
          final fileName = path.basename(file.path);

          if (!validImagePaths.contains(fileName)) {
            // 无主图片，删除
            try {
              final size = await file.length();
              await file.delete();
              deletedCount++;
              freedBytes += size;
              debugPrint(
                  '🗑️ 删除无主图片: $fileName (${(size / 1024).toStringAsFixed(2)} KB)');
            } catch (e) {
              debugPrint('❌ 删除失败: $fileName, $e');
            }
          } else {
            keptCount++;
          }
        }
      }

      final freedMB = freedBytes / (1024 * 1024);
      debugPrint('✅ 清理完成:');
      debugPrint('   删除: $deletedCount 张无主图片');
      debugPrint('   保留: $keptCount 张有效图片');
      debugPrint('   释放: ${freedMB.toStringAsFixed(2)} MB 空间');

      return {
        'deleted': deletedCount,
        'kept': keptCount,
        'freed_mb': freedMB,
      };
    } catch (e) {
      debugPrint('❌ 清理失败: $e');
      return {'deleted': 0, 'kept': 0, 'freed_mb': 0.0, 'error': e.toString()};
    }
  }

  /// 清理所有旧的分页缓存
  ///
  /// 删除所有分页缓存文件，下次打开书籍时会重新生成
  static Future<int> cleanAllPaginationCaches() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(path.join(appDir.path, 'pagination_cache'));

      if (!await cacheDir.exists()) {
        debugPrint('📂 缓存目录不存在，无需清理');
        return 0;
      }

      final files = await cacheDir.list().toList();
      int deletedCount = 0;

      for (var file in files) {
        if (file is File) {
          try {
            await file.delete();
            deletedCount++;
            debugPrint('🗑️ 删除缓存: ${path.basename(file.path)}');
          } catch (e) {
            debugPrint('❌ 删除失败: ${file.path}, $e');
          }
        }
      }

      debugPrint('✅ 清理完成: 删除 $deletedCount 个缓存文件');
      return deletedCount;
    } catch (e) {
      debugPrint('❌ 清理失败: $e');
      return 0;
    }
  }
}
