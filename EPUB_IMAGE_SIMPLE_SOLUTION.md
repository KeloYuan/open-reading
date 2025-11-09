# EPUB图片显示 - 简化方案（参考开源阅读器）

## 📚 参考的开源项目

### Legado（阅读）
- **GitHub**: gedoor/legado
- **语言**: Kotlin (Android)
- **关键特性**: 高性能、低内存占用、支持多种格式

---

## 🎯 Legado 的EPUB图片处理策略

### 核心思想：**按需提取** 而不是 **预先提取**

#### 1. 图片路径处理 (EpubFile.kt)

```kotlin
// 将相对路径转换为绝对路径
bodyElement.select("img").forEach {
    val src = it.attr("src").trim().encodeURI()
    val href = res.href.encodeURI()
    val resolvedHref = URLDecoder.decode(
        URI(href).resolve(src).toString(), "UTF-8"
    )
    it.attr("src", resolvedHref)  // 替换为绝对路径
}
```

**关键点**：
- 使用 `URI.resolve()` 解析相对路径
- 在解析章节内容时就替换好路径
- 路径指向EPUB内部资源，不是文件系统路径

---

#### 2. 图片获取 (EpubFile.kt)

```kotlin
private fun getImage(href: String): InputStream? {
    if (href == "cover.jpeg") {
        return epubBook?.coverImage?.inputStream
    }
    val abHref = URLDecoder.decode(href, "UTF-8")
    return epubBook?.resources?.getByHref(abHref)?.inputStream
}
```

**关键点**：
- **不预先提取图片**
- 直接从EPUB资源中读取 InputStream
- 按需访问，减少内存占用

---

#### 3. 图片缓存 (ImageProvider.kt + BookHelp.kt)

```kotlin
// 缓存图片到文件
fun getImage(book: Book, src: String): File {
    return File(
        "cache/${book.name}/images/${MD5(src)}.jpg"
    )
}

suspend fun cacheImage(book: Book, src: String): File {
    val vFile = getImage(book, src)
    if (!vFile.exists()) {
        // 按需从EPUB中提取
        val inputStream = EpubFile.getImage(book, src)
        inputStream?.use { input ->
            FileOutputStream(vFile).use { output ->
                input.copyTo(output)
            }
        }
    }
    return vFile
}

// 获取图片Bitmap（使用LruCache）
fun getImage(book: Book, src: String, width: Int, height: Int): Bitmap {
    val vFile = getImage(book, src)
    
    // 1. 检查内存缓存
    val cacheBitmap = lruCache[vFile.absolutePath]
    if (cacheBitmap != null) return cacheBitmap
    
    // 2. 按需提取并解码
    val bitmap = BitmapFactory.decodeFile(vFile.absolutePath)
    lruCache.put(vFile.absolutePath, bitmap)
    return bitmap
}
```

**关键点**：
- 图片文件命名：`MD5(src).jpg`（固定，不会变化）
- 按需提取：只在渲染时提取需要的图片
- LruCache：内存缓存 Bitmap，快速访问

---

## 💡 对比我们当前的方案

### ❌ 当前方案的问题

1. **预先提取所有图片**
   - 导入时提取43张图片
   - 阻塞导入流程5-15秒
   - 文件名基于图片内容MD5，每次导入都不同

2. **复杂的映射系统**
   - 需要保存映射表（临时ID → 文件路径）
   - 需要修复键名（临时ID → 真实ID）
   - 需要清理路径（移除换行符）
   - 容易出现同步问题

3. **缓存同步问题**
   - 图片文件名变化 → 映射更新 → 旧缓存失效
   - 需要在重新导入时清除旧缓存

---

### ✅ Legado的优势

1. **按需提取**
   - 只在渲染时提取图片
   - 不阻塞导入流程
   - 减少内存占用

2. **简单的路径解析**
   - 使用 `URI.resolve()` 解析相对路径
   - 不需要映射表
   - 路径固定（MD5(src)），不会变化

3. **无缓存同步问题**
   - 图片文件名固定（基于src的MD5）
   - 重新导入也是同样的文件名
   - 分页缓存永远有效

---

## 🚀 改进方案（参考Legado）

### 方案A：直接从EPUB读取（最佳）

**不保存图片文件，直接从EPUB资源读取**

```dart
class EpubImageProvider {
  final EpubBook epubBook;
  
  // 获取图片数据（直接从EPUB）
  Uint8List? getImage(String src) {
    // 解析相对路径
    final resolvedSrc = _resolvePath(src);
    
    // 从EPUB资源获取
    for (var entry in epubBook.Content?.Images?.entries ?? []) {
      if (entry.key == resolvedSrc) {
        return Uint8List.fromList(entry.value.Content ?? []);
      }
    }
    return null;
  }
  
  String _resolvePath(String src) {
    // 使用 package:path 解析相对路径
    return path.normalize(src);
  }
}
```

**优点**：
- ✅ 不需要预先提取
- ✅ 不需要映射表
- ✅ 不会有路径同步问题
- ✅ 导入超快

**缺点**：
- 需要保持 EpubBook 对象在内存中

---

### 方案B：按需缓存（推荐）

**使用固定文件名（基于图片内容MD5）**

```dart
class ImageCacheService {
  // 获取图片缓存路径（固定文件名）
  String getImagePath(int bookId, String imageSrc) {
    final fileName = md5.convert(utf8.encode(imageSrc)).toString();
    return '/app_flutter/book_images/${bookId}_$fileName.jpeg';
  }
  
  // 按需提取图片
  Future<File?> getImage(int bookId, String imageSrc) async {
    final imagePath = getImagePath(bookId, imageSrc);
    final file = File(imagePath);
    
    // 如果已缓存，直接返回
    if (await file.exists()) {
      return file;
    }
    
    // 否则从EPUB提取
    final imageData = await _extractFromEpub(bookId, imageSrc);
    if (imageData != null) {
      await file.writeAsBytes(imageData);
      return file;
    }
    
    return null;
  }
}
```

**优点**：
- ✅ 文件名固定（基于图片src的MD5）
- ✅ 重新导入文件名不变
- ✅ 分页缓存永远有效
- ✅ 按需提取，不阻塞导入

---

## 📊 性能对比

| 方案 | 导入速度 | 内存占用 | 缓存同步 | 实现复杂度 |
|-----|---------|---------|---------|-----------|
| **当前方案** | 慢（预先提取） | 中 | 复杂（易出错） | 高 |
| **方案A（直接读取）** | 快 | 高（保持EpubBook） | 简单 | 中 |
| **方案B（按需缓存）** | 快 | 低 | 简单 | 中 |
| **Legado** | 快 | 低 | 简单 | 低 |

---

## 🎯 建议

### 短期（修复当前问题）

已完成的修复可以使用，但需要确保：
1. ✅ 路径清理（移除换行符）
2. ✅ 删除书籍时清理缓存
3. ✅ 重新导入时清除旧缓存

### 长期（重构为Legado方案）

参考Legado，改为**按需缓存**方案：

1. **导入时**：不提取图片，只解析元数据
2. **渲染时**：检测到图片标签 → 检查缓存 → 提取并缓存
3. **文件命名**：使用 `MD5(src)` 固定文件名

这样就**彻底消除**映射同步问题！

---

## 📝 参考资料

- **Legado**: https://github.com/gedoor/legado
  - `app/src/main/java/io/legado/app/model/localBook/EpubFile.kt`
  - `app/src/main/java/io/legado/app/model/ImageProvider.kt`
  - `app/src/main/java/io/legado/app/help/book/BookHelp.kt`

- **其他开源阅读器**:
  - Readest (跨平台，TypeScript)
  - Koodo Reader (桌面端，Electron)
  - FBReader (老牌阅读器)

---

**要不要现在重构为简化方案？** 🤔

