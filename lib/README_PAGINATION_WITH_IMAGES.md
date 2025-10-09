# 📖 精确分页与图片支持功能文档

## 概述

本文档介绍如何在现有阅读器中集成**精确分页**和**图片显示**功能。

新增功能特点：
- ✅ 精确逐行分页，确保每页都填满文字
- ✅ 支持文本和图片混合排版
- ✅ EPUB图片自动提取和缓存
- ✅ 多种图片显示样式
- ✅ 所有排版参数可动态调整

## 核心组件

### 1. BookImageManager （图片缓存管理）

负责图片的提取、缓存和加载。

```dart
// 初始化
final imageManager = BookImageManager();
await imageManager.initialize(appDocumentsPath);

// 加载图片
final image = await imageManager.loadImage(imagePath);

// 获取图片尺寸
final size = await imageManager.getImageSize(imagePath);

// 清理缓存
await imageManager.clearMemoryCache();
```

### 2. EpubImageExtractor （EPUB图片提取器）

从EPUB文件中提取图片。

```dart
final extractor = EpubImageExtractor();

// 从EPUB文件提取图片
final images = await extractor.extractImages(epubFilePath, bookId);
// 返回: {imageKey: filePath}

// 获取图片统计
final stats = await extractor.getImageStats(epubFilePath);
// 返回: {count: 10, totalSizeMB: '2.5', types: {'.jpg': 8, '.png': 2}}
```

### 3. PrecisePaginatorWithImages （精确分页器）

支持文本和图片混排的精确分页。

```dart
final paginator = PrecisePaginatorWithImages();

// 分页
final pages = await paginator.paginate(
  content: chapterText,
  images: chapterImages,  // {imageFileName: imagePath}
  screenSize: MediaQuery.of(context).size,
  padding: EdgeInsets.all(20),
  fontSize: 18,
  lineHeight: 1.5,
  letterSpacing: 0.5,
  paragraphSpacing: 10,
  fontFamily: 'System',
  imageStyle: ImageDisplayStyle.auto,
);

// pages 是 List<TextPageData>
```

## 集成步骤

### 步骤1: 初始化服务

在应用启动时初始化图片管理器：

```dart
// main.dart 或 app启动代码中
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final appDocDir = await getApplicationDocumentsDirectory();
  await BookImageManager().initialize(appDocDir.path);
  
  runApp(MyApp());
}
```

### 步骤2: 在书籍导入时提取图片

修改你现有的 `BookImportService`：

```dart
// 在导入EPUB时
Future<Book> importEpubBook(String filePath) async {
  // ... 现有的导入逻辑 ...
  
  // 提取图片
  final extractor = EpubImageExtractor();
  final bookImages = await extractor.extractImages(
    filePath,
    bookId.toString(),
  );
  
  debugPrint('提取到 ${bookImages.length} 张图片');
  
  // 保存图片路径到数据库（可选）
  // await _saveBookImages(bookId, bookImages);
  
  return book;
}
```

### 步骤3: 在分页时使用新的分页器

在你的 `AdvancedTextPaginator` 或阅读器中集成：

```dart
// 方案A: 替换现有分页器
final paginator = PrecisePaginatorWithImages();
final pages = await paginator.paginate(
  content: content,
  images: images,
  // ... 其他参数
);

// 方案B: 作为可选功能，用户可选择
final useImageSupport = await _checkIfBookHasImages(bookId);
if (useImageSupport) {
  // 使用新分页器
  final pages = await precisePaginator.paginate(...);
} else {
  // 使用现有分页器
  final pages = AdvancedTextPaginator.paginateText(...);
}
```

### 步骤4: 渲染页面时显示图片

在 `ReaderTextView` 或渲染组件中：

```dart
class ReaderTextView extends StatelessWidget {
  final TextPageData page;
  
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: PagePainter(page),
    );
  }
}

class PagePainter extends CustomPainter {
  final TextPageData page;
  
  PagePainter(this.page);
  
  @override
  void paint(Canvas canvas, Size size) {
    for (var line in page.lines) {
      // 绘制文本
      for (var column in line.columns) {
        column.draw(canvas, Paint(), textStyle);
      }
    }
  }
  
  @override
  bool shouldRepaint(PagePainter oldDelegate) => oldDelegate.page != page;
}
```

## 图片占位符格式

在文本内容中，使用以下格式表示图片：

```
{{img:image_filename.jpg}}
```

示例：
```
第一章 开始

这是第一段文字。

{{img:chapter1_pic1.jpg}}

这是图片后的文字。
```

## 图片显示样式

```dart
enum ImageDisplayStyle {
  auto,       // 自动缩放（保持比例）
  fullWidth,  // 填充宽度
  fullPage,   // 独占一页
  inline,     // 嵌入文字中
}
```

使用示例：
```dart
final pages = await paginator.paginate(
  // ... 其他参数
  imageStyle: ImageDisplayStyle.fullWidth,  // 图片填充宽度
);
```

## 性能优化建议

### 1. 图片预加载
```dart
// 在翻页前预加载下一页的图片
final nextPageImages = _getNextPageImages();
await imageManager.preloadImages(nextPageImages);
```

### 2. 缓存管理
```dart
// 定期检查缓存大小
final stats = await imageManager.getCacheStats();
if (stats['disk_size_mb'] > 100) {  // 超过100MB
  await imageManager.clearDiskCache();
}
```

### 3. 内存优化
```dart
// 离开阅读器时清理内存缓存
@override
void dispose() {
  imageManager.clearMemoryCache();
  super.dispose();
}
```

## 完整示例

```dart
// 完整的导入和阅读流程
class BookReader {
  final imageManager = BookImageManager();
  final extractor = EpubImageExtractor();
  final paginator = PrecisePaginatorWithImages();
  
  // 1. 导入书籍
  Future<void> importBook(String epubPath) async {
    // 提取图片
    final images = await extractor.extractImages(
      epubPath,
      'book_123',
    );
    
    print('提取了 ${images.length} 张图片');
  }
  
  // 2. 分页章节
  Future<List<TextPageData>> paginateChapter(
    String chapterText,
    Map<String, String> chapterImages,
    Size screenSize,
  ) async {
    return await paginator.paginate(
      content: chapterText,
      images: chapterImages,
      screenSize: screenSize,
      padding: EdgeInsets.all(20),
      fontSize: 18,
      lineHeight: 1.5,
      letterSpacing: 0.5,
      paragraphSpacing: 10,
      imageStyle: ImageDisplayStyle.auto,
    );
  }
  
  // 3. 渲染页面
  Widget buildPage(TextPageData page) {
    return CustomPaint(
      painter: PagePainter(page, imageManager),
    );
  }
}
```

## 与现有系统的兼容性

新功能**完全兼容**你现有的系统：

1. **不破坏现有分页** - 可以与 `AdvancedTextPaginator` 并存
2. **保留UI风格** - 使用你现有的 `TextPageData` 模型
3. **可选功能** - 只在需要时启用图片支持
4. **性能优化** - 使用缓存机制，不影响现有性能

## 问题排查

### Q: 图片不显示？
A: 检查图片路径是否正确，使用 `imageManager.loadImage()` 测试加载。

### Q: 分页不准确？
A: 确保传入正确的 `screenSize` 和 `padding`，与阅读器实际显示区域一致。

### Q: 内存占用过高？
A: 调用 `imageManager.clearMemoryCache()` 定期清理内存缓存。

## 下一步

1. 在你的 `reader_page.dart` 中集成新分页器
2. 在书籍导入流程中添加图片提取
3. 测试不同屏幕尺寸和配置
4. 根据需要调整图片显示样式

---

**注意**: 所有新功能都设计为**增强**现有系统，不会影响你现有的功能和UI风格。

