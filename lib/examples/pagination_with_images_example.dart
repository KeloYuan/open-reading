/// 精确分页与图片支持 - 集成示例
///
/// 本文件展示如何将新的分页功能集成到现有项目中

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/text_page_data.dart';
import '../services/book_image_manager.dart';
import '../services/epub_image_extractor.dart';
import '../services/precise_paginator_with_images.dart';

/// 示例1: 初始化服务
///
/// 在应用启动时调用
Future<void> initializeImageServices() async {
  final appDocDir = await getApplicationDocumentsDirectory();
  await BookImageManager().initialize(appDocDir.path);

  debugPrint('✅ 图片服务已初始化');
}

/// 示例2: 在书籍导入时提取图片
///
/// 集成到你的 BookImportService 中
class BookImportWithImages {
  final extractor = EpubImageExtractor();

  Future<Map<String, String>> importEpubWithImages(
    String epubFilePath,
    String bookId,
  ) async {
    // 提取图片
    final images = await extractor.extractImages(epubFilePath, bookId);

    debugPrint('📚 书籍导入完成');
    debugPrint('🖼️ 提取图片: ${images.length} 张');

    // 返回图片映射供后续使用
    return images;
  }

  /// 获取图片统计信息
  Future<void> showImageStats(String epubFilePath) async {
    final stats = await extractor.getImageStats(epubFilePath);

    debugPrint('📊 图片统计:');
    debugPrint('   总数: ${stats['count']}');
    debugPrint('   大小: ${stats['totalSizeMB']} MB');
    debugPrint('   类型: ${stats['types']}');
  }
}

/// 示例3: 使用精确分页器
///
/// 可以替换或补充你现有的 AdvancedTextPaginator
class PaginationExample {
  final paginator = PrecisePaginatorWithImages();

  Future<List<TextPageData>> paginateChapter({
    required String chapterText,
    required Map<String, String> chapterImages,
    required BuildContext context,
  }) async {
    final screenSize = MediaQuery.of(context).size;
    final padding = EdgeInsets.fromLTRB(20, 40, 20, 60);

    final pages = await paginator.paginate(
      content: chapterText,
      images: chapterImages,
      screenSize: screenSize,
      padding: padding,
      fontSize: 18,
      lineHeight: 1.5,
      letterSpacing: 0.5,
      paragraphSpacing: 10,
      fontFamily: 'System',
      imageStyle: ImageDisplayStyle.auto,
    );

    debugPrint('📄 分页完成: ${pages.length} 页');
    return pages;
  }
}

/// 示例4: 页面渲染组件
///
/// 集成到你的 ReaderTextView 中
class PageWithImagesRenderer extends CustomPainter {
  final TextPageData page;
  final TextStyle textStyle;
  final imageManager = BookImageManager();

  PageWithImagesRenderer({
    required this.page,
    required this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制所有行
    for (var line in page.lines) {
      // 绘制每个字符
      for (var column in line.columns) {
        column.draw(canvas, Paint(), textStyle);
      }
    }
  }

  @override
  bool shouldRepaint(PageWithImagesRenderer oldDelegate) {
    return oldDelegate.page != page;
  }
}

/// 示例5: 完整的阅读器集成
///
/// 展示如何在 ReaderPage 中使用
class ReaderPageWithImages extends StatefulWidget {
  final String bookId;
  final String chapterText;

  const ReaderPageWithImages({
    super.key,
    required this.bookId,
    required this.chapterText,
  });

  @override
  State<ReaderPageWithImages> createState() => _ReaderPageWithImagesState();
}

class _ReaderPageWithImagesState extends State<ReaderPageWithImages> {
  List<TextPageData>? pages;
  int currentPageIndex = 0;
  Map<String, String> chapterImages = {};

  final paginator = PrecisePaginatorWithImages();
  final imageManager = BookImageManager();

  @override
  void initState() {
    super.initState();
    _loadChapter();
  }

  Future<void> _loadChapter() async {
    // 1. 获取章节图片（从数据库或缓存）
    chapterImages = await _getChapterImages();

    // 2. 预加载图片
    if (chapterImages.isNotEmpty) {
      await imageManager.preloadImages(chapterImages.values.toList());
    }

    // 3. 分页
    final screenSize = MediaQuery.of(context).size;
    final paginatedPages = await paginator.paginate(
      content: widget.chapterText,
      images: chapterImages,
      screenSize: screenSize,
      padding: const EdgeInsets.all(20),
      fontSize: 18,
      lineHeight: 1.5,
      letterSpacing: 0.5,
      paragraphSpacing: 10,
      imageStyle: ImageDisplayStyle.auto,
    );

    setState(() {
      pages = paginatedPages;
    });
  }

  Future<Map<String, String>> _getChapterImages() async {
    // TODO: 从数据库或缓存获取章节图片
    // 示例返回空映射
    return {};
  }

  @override
  Widget build(BuildContext context) {
    if (pages == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final currentPage = pages![currentPageIndex];

    return Scaffold(
      body: GestureDetector(
        onTapUp: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.localPosition.dx < screenWidth / 3) {
            // 上一页
            if (currentPageIndex > 0) {
              setState(() => currentPageIndex--);
            }
          } else if (details.localPosition.dx > screenWidth * 2 / 3) {
            // 下一页
            if (currentPageIndex < pages!.length - 1) {
              setState(() => currentPageIndex++);
            }
          }
        },
        child: Container(
          color: Colors.white,
          child: CustomPaint(
            painter: PageWithImagesRenderer(
              page: currentPage,
              textStyle: const TextStyle(
                fontSize: 18,
                height: 1.5,
                letterSpacing: 0.5,
              ),
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // 清理内存缓存
    imageManager.clearMemoryCache();
    super.dispose();
  }
}

/// 示例6: 与现有 AdvancedTextPaginator 的对比使用
///
/// 根据书籍类型选择合适的分页器
class AdaptivePagination {
  final precisePaginator = PrecisePaginatorWithImages();

  /// 智能选择分页器
  Future<List<TextPageData>> smartPaginate({
    required String content,
    required Map<String, String> images,
    required Size screenSize,
    required EdgeInsets padding,
    required double fontSize,
    required double lineHeight,
    required double letterSpacing,
    required double paragraphSpacing,
  }) async {
    // 如果有图片，使用精确分页器
    if (images.isNotEmpty) {
      debugPrint('📖 使用精确分页器（支持图片）');
      return await precisePaginator.paginate(
        content: content,
        images: images,
        screenSize: screenSize,
        padding: padding,
        fontSize: fontSize,
        lineHeight: lineHeight,
        letterSpacing: letterSpacing,
        paragraphSpacing: paragraphSpacing,
        imageStyle: ImageDisplayStyle.auto,
      );
    }

    // 否则可以使用现有的分页器
    debugPrint('📖 使用标准分页器（纯文本）');
    // return AdvancedTextPaginator.paginateText(...);

    // 临时返回空列表
    return [];
  }
}

/// 示例7: 图片缓存管理
class ImageCacheManagement {
  final imageManager = BookImageManager();

  /// 检查缓存大小并清理
  Future<void> manageCacheSize() async {
    final stats = await imageManager.getCacheStats();

    debugPrint('📊 缓存统计:');
    debugPrint('   内存缓存: ${stats['memory_cached']} 张');
    debugPrint('   磁盘缓存: ${stats['disk_cached']} 张');
    debugPrint('   磁盘大小: ${stats['disk_size_mb']} MB');

    // 如果超过100MB，清理磁盘缓存
    final diskSizeMB = double.parse(stats['disk_size_mb']);
    if (diskSizeMB > 100) {
      debugPrint('🗑️ 缓存过大，开始清理...');
      await imageManager.clearDiskCache();
      debugPrint('✅ 清理完成');
    }
  }

  /// 预加载下几页的图片
  Future<void> preloadNextPagesImages(
    List<TextPageData> allPages,
    int currentPageIndex,
  ) async {
    final nextPageCount = 3; // 预加载接下来3页
    final imagePaths = <String>[];

    for (var i = currentPageIndex + 1;
        i < currentPageIndex + nextPageCount && i < allPages.length;
        i++) {
      // TODO: 提取页面中的图片路径
      // imagePaths.addAll(_extractImagePaths(allPages[i]));
    }

    if (imagePaths.isNotEmpty) {
      await imageManager.preloadImages(imagePaths);
      debugPrint('✅ 预加载 ${imagePaths.length} 张图片');
    }
  }
}
