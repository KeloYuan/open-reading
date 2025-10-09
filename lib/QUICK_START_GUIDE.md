# 🚀 快速开始指南 - 5分钟集成精确分页与图片支持

## 第一步：初始化（30秒）

在你的 `main.dart` 中添加：

```dart
import 'package:path_provider/path_provider.dart';
import 'services/book_image_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化图片服务
  final appDocDir = await getApplicationDocumentsDirectory();
  await BookImageManager().initialize(appDocDir.path);
  
  runApp(MyApp());
}
```

✅ 完成！图片缓存服务已就绪。

---

## 第二步：导入时提取图片（2分钟）

在你的 `BookImportService` 或导入逻辑中添加：

```dart
import 'services/epub_image_extractor.dart';

// 在导入EPUB时
Future<void> importEpubBook(String filePath) async {
  // ... 你现有的导入代码 ...
  
  // 新增：提取图片
  final extractor = EpubImageExtractor();
  final images = await extractor.extractImages(filePath, book.id.toString());
  
  print('✅ 提取了 ${images.length} 张图片');
  
  // 可选：保存图片路径到数据库
  // await saveBookImages(book.id, images);
}
```

✅ 完成！现在导入EPUB时会自动提取图片。

---

## 第三步：使用新分页器（2分钟）

找到你现有的分页代码，添加新选项：

```dart
import 'services/precise_paginator_with_images.dart';

// 方案A: 简单替换（推荐）
final paginator = PrecisePaginatorWithImages();
final pages = await paginator.paginate(
  content: chapterText,
  images: {}, // 如果没有图片传空Map
  screenSize: MediaQuery.of(context).size,
  padding: EdgeInsets.all(20),
  fontSize: 18,
  lineHeight: 1.5,
  letterSpacing: 0.5,
  paragraphSpacing: 10,
  imageStyle: ImageDisplayStyle.auto,
);

// 方案B: 智能选择（按需使用）
final hasImages = chapterImages.isNotEmpty;
final pages = hasImages
    ? await PrecisePaginatorWithImages().paginate(...)
    : AdvancedTextPaginator.paginateText(...); // 你现有的分页器
```

✅ 完成！分页器已集成。

---

## 完整示例（复制即用）

```dart
// lib/services/my_book_reader.dart
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'services/book_image_manager.dart';
import 'services/epub_image_extractor.dart';
import 'services/precise_paginator_with_images.dart';
import 'models/text_page_data.dart';

class MyBookReader {
  // 1. 初始化（应用启动时调用一次）
  static Future<void> initialize() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    await BookImageManager().initialize(appDocDir.path);
  }

  // 2. 导入书籍
  Future<Map<String, String>> importBook(String epubPath, String bookId) async {
    final extractor = EpubImageExtractor();
    return await extractor.extractImages(epubPath, bookId);
  }

  // 3. 分页章节
  Future<List<TextPageData>> paginateChapter({
    required String chapterText,
    required Map<String, String> images,
    required BuildContext context,
  }) async {
    final paginator = PrecisePaginatorWithImages();
    return await paginator.paginate(
      content: chapterText,
      images: images,
      screenSize: MediaQuery.of(context).size,
      padding: EdgeInsets.all(20),
      fontSize: 18,
      lineHeight: 1.5,
      letterSpacing: 0.5,
      paragraphSpacing: 10,
      imageStyle: ImageDisplayStyle.auto,
    );
  }
}

// 使用方法：
// 1. 在main.dart中: await MyBookReader.initialize();
// 2. 导入书籍: final images = await reader.importBook(path, id);
// 3. 分页: final pages = await reader.paginateChapter(...);
```

---

## 图片占位符格式

在你的EPUB或TXT内容中，图片会自动转换为：

```
这是一段文字。

{{img:chapter1_image.jpg}}

这是图片后的文字。
```

不需要手动处理，提取器会自动转换！

---

## 图片样式选择

```dart
enum ImageDisplayStyle {
  auto,       // 自动缩放（默认，推荐）
  fullWidth,  // 填充宽度
  fullPage,   // 独占一页（适合大图）
  inline,     // 嵌入文字（未来支持）
}
```

---

## 性能优化技巧

### 预加载下一页图片
```dart
// 在翻页前调用
final nextPageImages = ['path/to/next/image.jpg'];
await BookImageManager().preloadImages(nextPageImages);
```

### 定期清理缓存
```dart
// 退出阅读器时
@override
void dispose() {
  BookImageManager().clearMemoryCache();
  super.dispose();
}
```

---

## 常见问题（30秒解决）

### Q: 导入的EPUB没有图片？
```dart
// 检查图片统计
final extractor = EpubImageExtractor();
final stats = await extractor.getImageStats(epubPath);
print('图片数量: ${stats['count']}');
```

### Q: 图片不显示？
```dart
// 测试图片加载
final image = await BookImageManager().loadImage(imagePath);
if (image == null) {
  print('图片加载失败，检查路径: $imagePath');
}
```

### Q: 分页太慢？
```dart
// 使用你现有的高效分页器
final pages = AdvancedTextPaginator.paginateText(...);
// 只在有图片时使用新分页器
```

---

## 下一步

### 查看完整文档
- 📖 `README_PAGINATION_WITH_IMAGES.md` - 详细说明
- 💡 `examples/pagination_with_images_example.dart` - 7个实用示例
- 📊 `FEATURES_SUMMARY.md` - 功能总结

### 高级功能（可选）
1. 在设置中添加图片样式选项
2. 添加图片点击放大功能
3. 支持图片长按保存

---

## ✅ 检查清单

- [ ] 在 `main.dart` 中初始化图片服务
- [ ] 在导入流程中添加图片提取
- [ ] 集成新分页器到阅读器
- [ ] 测试导入一本EPUB查看效果
- [ ] （可选）添加图片样式配置

---

**恭喜！** 🎉 你已经成功集成了精确分页与图片支持功能！

现在你的阅读器可以：
- ✨ 精确分页，每页填满文字
- 🖼️ 完美显示EPUB中的图片
- ⚡ 高性能缓存和加载
- 🎨 保持你原有的UI风格

有问题随时查看文档或示例代码！

