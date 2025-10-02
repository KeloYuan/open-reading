import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

/// 分页缓存数据
class PaginationCacheData {
  final List<String> pages;
  final String cacheKey;
  final DateTime createdAt;

  const PaginationCacheData({
    required this.pages,
    required this.cacheKey,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'pages': pages,
      'cacheKey': cacheKey,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PaginationCacheData.fromJson(Map<String, dynamic> json) {
    return PaginationCacheData(
      pages: List<String>.from(json['pages'] as List),
      cacheKey: json['cacheKey'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// 分页缓存服务
///
/// 将分页结果持久化到文件系统，避免每次打开都重新计算
class PaginationCacheService {
  static const String _cacheDirName = 'pagination_cache';
  static const int _maxCacheAgeDays = 30; // 缓存最大保留时间

  /// 生成缓存键
  ///
  /// 基于内容哈希和排版参数生成唯一的缓存键
  static String generateCacheKey({
    required String contentHash,
    required double screenWidth,
    required double screenHeight,
    required double fontSize,
    required double lineSpacing,
    required double letterSpacing,
    required double paddingLeft,
    required double paddingRight,
    required double paddingTop,
    required double paddingBottom,
    required double firstLineIndent,
    required double devicePixelRatio,
  }) {
    final params = '${screenWidth.toStringAsFixed(0)}_'
        '${screenHeight.toStringAsFixed(0)}_'
        '${fontSize.toStringAsFixed(1)}_'
        '${lineSpacing.toStringAsFixed(2)}_'
        '${letterSpacing.toStringAsFixed(2)}_'
        '${paddingLeft.toStringAsFixed(0)}_${paddingRight.toStringAsFixed(0)}_'
        '${paddingTop.toStringAsFixed(0)}_${paddingBottom.toStringAsFixed(0)}_'
        '${firstLineIndent.toStringAsFixed(1)}_'
        '${devicePixelRatio.toStringAsFixed(2)}';

    return '${contentHash}_$params';
  }

  /// 获取缓存目录
  static Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheDirName');

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    return cacheDir;
  }

  /// 获取缓存文件路径
  static Future<String> _getCacheFilePath(String cacheKey) async {
    final cacheDir = await _getCacheDirectory();
    // 对缓存键进行MD5哈希，避免文件名过长
    final keyHash = md5.convert(utf8.encode(cacheKey)).toString();
    return '${cacheDir.path}/$keyHash.json';
  }

  /// 保存分页缓存
  ///
  /// 将分页结果保存到文件系统
  static Future<void> saveCache({
    required List<String> pages,
    required String cacheKey,
  }) async {
    try {
      final filePath = await _getCacheFilePath(cacheKey);
      final file = File(filePath);

      final cacheData = PaginationCacheData(
        pages: pages,
        cacheKey: cacheKey,
        createdAt: DateTime.now(),
      );

      final json = jsonEncode(cacheData.toJson());
      await file.writeAsString(json);

      debugPrint('✅ 分页缓存已保存: ${pages.length}页');
      debugPrint('   缓存文件: $filePath');
      debugPrint('   文件大小: ${(await file.length()) / 1024 / 1024} MB');
    } catch (e) {
      debugPrint('❌ 保存分页缓存失败: $e');
    }
  }

  /// 加载分页缓存
  ///
  /// 从文件系统加载分页结果
  static Future<PaginationCacheData?> loadCache({
    required String cacheKey,
  }) async {
    try {
      final filePath = await _getCacheFilePath(cacheKey);
      final file = File(filePath);

      if (!await file.exists()) {
        debugPrint('⚠️ 缓存文件不存在');
        return null;
      }

      // 检查缓存是否过期
      final lastModified = await file.lastModified();
      final age = DateTime.now().difference(lastModified).inDays;

      if (age > _maxCacheAgeDays) {
        debugPrint('⚠️ 缓存已过期（${age}天），删除旧缓存');
        await file.delete();
        return null;
      }

      final json = await file.readAsString();
      final data = jsonDecode(json) as Map<String, dynamic>;
      final cacheData = PaginationCacheData.fromJson(data);

      // 验证缓存键是否匹配
      if (cacheData.cacheKey != cacheKey) {
        debugPrint('⚠️ 缓存键不匹配，删除旧缓存');
        await file.delete();
        return null;
      }

      debugPrint('✅ 加载分页缓存成功: ${cacheData.pages.length}页');
      debugPrint('   缓存时间: ${cacheData.createdAt}');

      return cacheData;
    } catch (e) {
      debugPrint('❌ 加载分页缓存失败: $e');
      return null;
    }
  }

  /// 清理所有缓存
  static Future<void> clearAllCache() async {
    try {
      final cacheDir = await _getCacheDirectory();

      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        debugPrint('✅ 已清理所有分页缓存');
      }
    } catch (e) {
      debugPrint('❌ 清理缓存失败: $e');
    }
  }

  /// 清理过期缓存
  static Future<void> clearExpiredCache() async {
    try {
      final cacheDir = await _getCacheDirectory();

      if (!await cacheDir.exists()) {
        return;
      }

      final files = cacheDir.listSync();
      int deletedCount = 0;

      for (var file in files) {
        if (file is File) {
          final lastModified = await file.lastModified();
          final age = DateTime.now().difference(lastModified).inDays;

          if (age > _maxCacheAgeDays) {
            await file.delete();
            deletedCount++;
          }
        }
      }

      if (deletedCount > 0) {
        debugPrint('✅ 已清理${deletedCount}个过期缓存文件');
      }
    } catch (e) {
      debugPrint('❌ 清理过期缓存失败: $e');
    }
  }

  /// 删除特定书籍的所有缓存
  ///
  /// 根据书籍的内容哈希删除所有相关的分页缓存
  /// 参数 [contentHash] 书籍的内容哈希值
  static Future<void> deleteCacheForBook(String contentHash) async {
    try {
      final cacheDir = await _getCacheDirectory();

      if (!await cacheDir.exists()) {
        return;
      }

      final files = cacheDir.listSync().whereType<File>().toList();
      int deletedCount = 0;

      for (var file in files) {
        // 读取缓存文件内容以检查是否属于该书籍
        try {
          final json = await file.readAsString();
          final data = jsonDecode(json) as Map<String, dynamic>;
          final cacheKey = data['cacheKey'] as String;

          // 检查缓存键是否包含该书籍的哈希值
          if (cacheKey.startsWith(contentHash)) {
            await file.delete();
            deletedCount++;
            debugPrint('🗑️ 删除书籍缓存: ${file.path}');
          }
        } catch (e) {
          // 如果文件读取失败，跳过该文件
          debugPrint('⚠️ 读取缓存文件失败: ${file.path}, $e');
        }
      }

      if (deletedCount > 0) {
        debugPrint('✅ 已删除该书籍的${deletedCount}个缓存文件');
      } else {
        debugPrint('ℹ️ 未找到该书籍的缓存文件');
      }
    } catch (e) {
      debugPrint('❌ 删除书籍缓存失败: $e');
    }
  }

  /// 获取缓存统计信息
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final cacheDir = await _getCacheDirectory();

      if (!await cacheDir.exists()) {
        return {
          'count': 0,
          'totalSize': 0,
          'oldestCache': null,
          'newestCache': null,
        };
      }

      final files = cacheDir.listSync().whereType<File>().toList();
      int totalSize = 0;
      DateTime? oldest;
      DateTime? newest;

      for (var file in files) {
        final size = await file.length();
        totalSize += size;

        final modified = await file.lastModified();
        if (oldest == null || modified.isBefore(oldest)) {
          oldest = modified;
        }
        if (newest == null || modified.isAfter(newest)) {
          newest = modified;
        }
      }

      return {
        'count': files.length,
        'totalSize': totalSize,
        'totalSizeMB': (totalSize / 1024 / 1024).toStringAsFixed(2),
        'oldestCache': oldest?.toIso8601String(),
        'newestCache': newest?.toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ 获取缓存统计失败: $e');
      return {'error': e.toString()};
    }
  }
}
