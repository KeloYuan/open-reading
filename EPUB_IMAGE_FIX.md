# EPUB图片显示修复方案

## 🔍 问题诊断

### 现象
EPUB书籍中的图片显示为HTML标签路径，如：
```
<img src="/data/user/0/com.niki.xread/app_flutter/book_images/8c7a7a4a0ae2a15e43ad673845​12e87c.jpeg"/>
```

### 根本原因
**页面渲染器不支持图片元素**

1. **图片提取正常** ✅
   - [epub_image_extractor.dart:74-107](lib/services/epub_image_extractor.dart#L74-L107) 正确提取并保存图片
   - 图片路径映射正确存储

2. **分页器支持图片** ✅
   - [fast_text_paginator.dart:136-138](lib/services/fast_text_paginator.dart#L136-L138) 返回 `pageElements`
   - 包含文本和图片元素

3. **渲染器未处理图片** ❌
   - [reader_page.dart:2033-2041](lib/pages/reader_page.dart#L2033-L2041) `_HighlightedText` 只渲染纯文本
   - **问题代码**：
     ```dart
     _HighlightedText(
       text: pageContent, // ❌ pageContent是字符串，包含HTML标签
       style: currentSettings.textStyle,
       // ... 没有处理pageElements
     )
     ```

---

## ✅ 修复方案

### 方案1：修改 `_buildPageContent` 支持图片渲染（推荐）

**修改文件：** [lib/pages/reader_page.dart:2008-2051](lib/pages/reader_page.dart#L2008-L2051)

#### 步骤1：获取 pageElements

```dart
Widget _buildPageContent(BuildContext context, String pageContent, int index) {
  return RepaintBoundary(
    child: LayoutBuilder(
      builder: (context, constraints) {
        return Consumer(
          builder: (context, ref, child) {
            final currentSettings = ref.watch(readerSettingsProvider);
            final ttsState = ref.watch(readerTtsProvider);
            final paginationState = ref.watch(readerPaginationProvider); // ⭐ 获取分页状态

            // ⭐ 获取当前页的图片元素
            final pageElements = paginationState.result?.pageElements?[index];
            final hasImages = pageElements?.any((e) => e.type == PageElementType.image) ?? false;

            return Container(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              padding: currentSettings.padding,
              color: currentSettings.backgroundColor,
              child: ClipRect(
                clipBehavior: Clip.hardEdge,
                child: hasImages
                    ? _buildPageWithImages(pageElements!, currentSettings, ttsState)
                    : _buildTextOnlyPage(pageContent, currentSettings, ttsState),
              ),
            );
          },
        );
      },
    ),
  );
}
```

#### 步骤2：添加图片渲染方法

```dart
/// 渲染带图片的页面
Widget _buildPageWithImages(
  List<PageElement> elements,
  ReaderSettings settings,
  ReaderTtsState ttsState,
) {
  return SingleChildScrollView(
    physics: const NeverScrollableScrollPhysics(), // 禁止滚动
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: elements.map((element) {
        if (element.type == PageElementType.text) {
          // 渲染文本
          return _HighlightedText(
            text: element.content,
            style: settings.textStyle,
            highlightedSentenceIndex: ttsState.highlightedSentenceIndex,
            enableSelection: settings.enableTextSelection,
            onTextSelection: widget.onTextSelection,
          );
        } else {
          // 渲染图片
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: _buildImage(element.content, element.width, element.height),
          );
        }
      }).toList(),
    ),
  );
}

/// 渲染纯文本页面
Widget _buildTextOnlyPage(
  String pageContent,
  ReaderSettings settings,
  ReaderTtsState ttsState,
) {
  return _HighlightedText(
    text: pageContent,
    style: settings.textStyle,
    highlightedSentenceIndex: ttsState.highlightedSentenceIndex,
    enableSelection: settings.enableTextSelection,
    onTextSelection: widget.onTextSelection,
  );
}

/// 渲染图片
Widget _buildImage(String imagePath, double? width, double? height) {
  // 从路径提取文件名
  final file = File(imagePath);

  if (!file.existsSync()) {
    debugPrint('⚠️ 图片文件不存在: $imagePath');
    return const SizedBox.shrink();
  }

  return Center(
    child: Image.file(
      file,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('❌ 图片加载失败: $imagePath, $error');
        return Container(
          width: width ?? 100,
          height: height ?? 100,
          color: Colors.grey.withOpacity(0.2),
          child: const Icon(Icons.broken_image, color: Colors.grey),
        );
      },
    ),
  );
}
```

#### 步骤3：修改 PageView.builder 传递索引

```dart
@override
Widget build(BuildContext context) {
  return PageView.builder(
    controller: widget.controller,
    onPageChanged: widget.onPageChanged,
    itemCount: widget.pages.length,
    physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
    itemBuilder: (context, index) {
      return _buildPageContent(context, widget.pages[index], index); // ⭐ 传递index
    },
  );
}
```

---

### 方案2：修改分页器输出（备选）

如果方案1复杂，可以简化为：让分页器直接将图片标签替换为占位符。

**修改文件：** [lib/services/fast_text_paginator.dart](lib/services/fast_text_paginator.dart)

```dart
// 在分页时，将 <img> 标签替换为占位符
final imgPattern = RegExp(r'<img\s+src=["\']([^"\']+)["\'][^>]*>');
text = text.replaceAllMapped(imgPattern, (match) {
  final src = match.group(1);
  return '[图片: ${path.basename(src)}]'; // 显示占位文本
});
```

---

## 🎯 推荐方案

**方案1** - 完整支持图片渲染，用户体验最佳

### 实施步骤

1. ✅ **修改 ReaderPaginationState 存储 pageElements**
   ```dart
   // lib/providers/reader_providers.dart
   class ReaderPaginationState {
     final FastPaginationResult? result; // ⭐ 存储完整分页结果
     // ...
   }
   ```

2. ✅ **修改 _buildPageContent 获取 pageElements**
   - 从 `paginationState.result.pageElements` 获取当前页图片
   - 判断是否有图片，选择渲染方法

3. ✅ **添加图片渲染逻辑**
   - `_buildPageWithImages()` - 混合渲染文本+图片
   - `_buildImage()` - 图片加载和错误处理

---

## 🔧 快速调试

### 1. 验证图片文件存在

```dart
// 在 _buildImage() 中添加日志
debugPrint('📷 尝试加载图片: $imagePath');
debugPrint('   文件存在: ${file.existsSync()}');
```

### 2. 检查 pageElements 数据

```dart
// 在 _buildPageContent() 中添加日志
debugPrint('📄 第 $index 页元素:');
for (var element in pageElements ?? []) {
  debugPrint('   ${element.type}: ${element.content.substring(0, 50)}...');
}
```

### 3. 测试示例

```dart
// 创建测试EPUB，验证图片加载
final testElements = [
  PageElement.text('这是一段文本。'),
  PageElement.image('/data/.../test.jpg', width: 300, height: 400),
  PageElement.text('图片后的文本。'),
];
```

---

## 📦 相关文件

- ✅ **图片提取器**: [lib/services/epub_image_extractor.dart](lib/services/epub_image_extractor.dart)
- ✅ **分页器**: [lib/services/fast_text_paginator.dart](lib/services/fast_text_paginator.dart)
- ❌ **渲染器**: [lib/pages/reader_page.dart:2008-2051](lib/pages/reader_page.dart#L2008-2051) **需要修改**
- ⭐ **状态管理**: [lib/providers/reader_providers.dart](lib/providers/reader_providers.dart)

---

## 🎉 预期效果

修复后：
- ✅ 图片正确显示在文本中
- ✅ 图片尺寸自适应
- ✅ 图片加载错误有友好提示
- ✅ 不影响纯文本书籍性能

---

生成时间：2025-10-10
