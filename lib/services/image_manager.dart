import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 图片布局结果
class ImageLayoutResult {
  /// 是否能放入当前页
  final bool canFit;

  /// 图片显示宽度
  final double displayWidth;

  /// 图片显示高度
  final double displayHeight;

  /// 图片在页面中的位置（相对于文本）
  final ImagePosition position;

  const ImageLayoutResult({
    required this.canFit,
    required this.displayWidth,
    required this.displayHeight,
    required this.position,
  });
}

/// 图片位置枚举
enum ImagePosition {
  /// 与文字混排（嵌入文本中）
  inline,

  /// 独占一页
  fullPage,

  /// 在当前页底部
  bottomOfPage,
}

/// 图片元素信息
class ImageInfo {
  /// 图片路径
  final String path;

  /// 原始宽度
  final double? originalWidth;

  /// 原始高度
  final double? originalHeight;

  /// 是否已加载尺寸
  bool get hasDimensions => originalWidth != null && originalHeight != null;

  ImageInfo({
    required this.path,
    this.originalWidth,
    this.originalHeight,
  });

  ImageInfo copyWith({
    String? path,
    double? originalWidth,
    double? originalHeight,
  }) {
    return ImageInfo(
      path: path ?? this.path,
      originalWidth: originalWidth ?? this.originalWidth,
      originalHeight: originalHeight ?? this.originalHeight,
    );
  }
}

/// 图片管理器
///
/// 负责：
/// 1. 异步加载图片尺寸
/// 2. 计算图片布局（是否能放入当前页）
/// 3. 决定图片显示位置（混排/独占）
class ImageManager {
  /// 图片尺寸缓存（路径 -> 尺寸）
  final Map<String, ui.Size> _sizeCache = {};

  /// 异步加载图片尺寸
  ///
  /// 参数：
  /// - imagePath: 图片文件路径
  ///
  /// 返回：
  /// - 图片尺寸（宽度x高度），加载失败返回null
  Future<ui.Size?> loadImageSize(String imagePath) async {
    // 检查缓存
    if (_sizeCache.containsKey(imagePath)) {
      return _sizeCache[imagePath];
    }

    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('⚠️ 图片文件不存在: $imagePath');
        return null;
      }

      // 读取图片字节
      final bytes = await file.readAsBytes();

      // 解码图片获取尺寸
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final size = ui.Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      // 缓存尺寸
      _sizeCache[imagePath] = size;

      debugPrint('✅ 图片尺寸加载成功: $imagePath (${size.width}x${size.height})');

      // 释放资源
      image.dispose();

      return size;
    } catch (e, stackTrace) {
      debugPrint('❌ 加载图片尺寸失败: $imagePath');
      debugPrint('错误: $e');
      debugPrint('堆栈: $stackTrace');
      return null;
    }
  }

  /// 批量加载图片尺寸
  ///
  /// 参数：
  /// - imagePaths: 图片路径列表
  ///
  /// 返回：
  /// - 路径到尺寸的映射表
  Future<Map<String, ui.Size>> loadImageSizesBatch(
    List<String> imagePaths,
  ) async {
    final results = <String, ui.Size>{};

    // 并发加载所有图片尺寸
    final futures = imagePaths.map((path) async {
      final size = await loadImageSize(path);
      if (size != null) {
        results[path] = size;
      }
    });

    await Future.wait(futures);

    return results;
  }

  /// 计算图片布局
  ///
  /// 判断图片是否能放入当前页，以及如何显示
  ///
  /// 参数：
  /// - imageInfo: 图片信息（包含原始尺寸）
  /// - pageWidth: 页面宽度
  /// - pageHeight: 页面高度
  /// - remainingHeight: 当前页剩余高度
  /// - minFitRatio: 最小适配比例（图片高度 < 剩余高度 * minFitRatio 才混排，默认0.8）
  ///
  /// 返回：
  /// - 图片布局结果
  ImageLayoutResult calculateLayout({
    required ImageInfo imageInfo,
    required double pageWidth,
    required double pageHeight,
    required double remainingHeight,
    double minFitRatio = 0.8,
  }) {
    if (!imageInfo.hasDimensions) {
      debugPrint('⚠️ 图片尺寸未加载，无法计算布局: ${imageInfo.path}');
      // 默认独占一页
      return ImageLayoutResult(
        canFit: false,
        displayWidth: pageWidth,
        displayHeight: pageHeight,
        position: ImagePosition.fullPage,
      );
    }

    final originalWidth = imageInfo.originalWidth!;
    final originalHeight = imageInfo.originalHeight!;

    // 计算缩放比例（不超过页面宽度）
    double scale = 1.0;
    if (originalWidth > pageWidth) {
      scale = pageWidth / originalWidth;
    }

    final displayWidth = originalWidth * scale;
    final displayHeight = originalHeight * scale;

    debugPrint('📐 图片布局计算:');
    debugPrint('   - 原始尺寸: ${originalWidth.toInt()}x${originalHeight.toInt()}');
    debugPrint('   - 显示尺寸: ${displayWidth.toInt()}x${displayHeight.toInt()}');
    debugPrint('   - 剩余高度: ${remainingHeight.toInt()}');
    debugPrint('   - 阈值: ${(remainingHeight * minFitRatio).toInt()}');

    // 判断是否能放入当前页
    if (displayHeight <= remainingHeight * minFitRatio) {
      // 可以混排
      debugPrint('   ✅ 可以与文字混排');
      return ImageLayoutResult(
        canFit: true,
        displayWidth: displayWidth,
        displayHeight: displayHeight,
        position: ImagePosition.inline,
      );
    } else if (displayHeight <= pageHeight) {
      // 图片不能混排，但可以单独成页
      debugPrint('   ⚠️ 需要独占一页');
      return ImageLayoutResult(
        canFit: false,
        displayWidth: displayWidth,
        displayHeight: displayHeight,
        position: ImagePosition.fullPage,
      );
    } else {
      // 图片太大，需要缩放到页面高度
      debugPrint('   ⚠️ 图片过大，需要缩放到页面高度');
      final heightScale = pageHeight / originalHeight;
      final scaledWidth = originalWidth * heightScale;
      final scaledHeight = pageHeight;

      return ImageLayoutResult(
        canFit: false,
        displayWidth: scaledWidth,
        displayHeight: scaledHeight,
        position: ImagePosition.fullPage,
      );
    }
  }

  /// 清除图片尺寸缓存
  void clearCache() {
    _sizeCache.clear();
    debugPrint('🗑️ 图片尺寸缓存已清除');
  }

  /// 获取缓存大小
  int get cacheSize => _sizeCache.length;
}
