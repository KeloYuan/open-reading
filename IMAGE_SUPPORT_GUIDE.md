# 图片支持完全指南

## 📋 概述

分页引擎现已全面支持图片！参照 legado 的实现，图片可以与文本完美混排，自动参与分页计算。

## ✨ 核心特性

### 1. **三种图片样式**

- **Auto（自适应）** - 默认模式
  - 如果图片宽度超过页面，自动缩放以适应宽度
  - 如果图片高度超过页面，自动缩放以适应高度
  - 如果当前页无法容纳图片，自动翻页
  - 图片水平居中显示

- **Full（铺满宽度）**
  - 图片始终铺满页面宽度
  - 高度按比例缩放
  - 适合横版图片和漫画

- **Single（单独一页）**
  - 图片独占一页
  - 图片垂直和水平均居中
  - 如果图片高度超过页面，自动缩放
  - 适合重要的插图和封面

### 2. **支持的图片格式**

- **网络图片**：`http://...` 或 `https://...`
- **本地文件**：`file:///...` 或直接文件路径
- **Asset资源**：`assets/...`
- **Base64编码**：`data:image/...`

### 3. **支持的标记格式**

- **HTML标签**：`<img src="图片URL"/>`
- **Markdown语法**：`![alt](图片URL)`

### 4. **自动化处理**

- 自动从文本中提取图片URL
- 自动获取图片尺寸
- 自动参与分页计算
- 自动处理缓存和优化

## 🎯 使用方法

### 方法1：自动提取（推荐）

文本中包含图片标记，分页器会自动提取和处理：

```dart
final text = '''
第一章 开始

这是一段文字。

<img src="https://example.com/image1.jpg"/>

这是图片后的文字。

![图片2](https://example.com/image2.png)

更多文字内容...
''';

// 自动提取和处理图片
await UltraPrecisePaginator.paginate(
  content: text,
  imageStyle: ImageStyle.auto, // 可选：auto/full/single
);
```

### 方法2：手动指定图片

如果图片信息已知，可以手动提供：

```dart
// 准备图片信息
final images = [
  ImageInfo(
    src: 'https://example.com/image1.jpg',
    width: 800,
    height: 600,
  ),
  ImageInfo(
    src: 'assets/images/cover.png',
    width: 1080,
    height: 1920,
  ),
];

// 执行分页
await UltraPrecisePaginator.paginate(
  content: text,
  images: images,
  imageStyle: ImageStyle.single, // 单图模式
);
```

### 方法3：使用图片服务

利用`ImageSizeService`获取图片尺寸：

```dart
// 提取图片URL
final imageUrls = ImageSizeService.extractImageUrls(text);
print('找到 ${imageUrls.length} 张图片');

// 批量获取图片尺寸
final images = await ImageSizeService.getImageSizes(imageUrls);

// 执行分页
await UltraPrecisePaginator.paginate(
  content: text,
  images: images,
  imageStyle: ImageStyle.full, // 铺满模式
);
```

## 📊 图片样式对比

| 样式 | 宽度处理 | 高度处理 | 分页行为 | 适用场景 |
|------|---------|---------|---------|---------|
| **Auto** | 超宽缩放 | 超高缩放 | 智能翻页 | 通用场景 |
| **Full** | 铺满宽度 | 比例缩放 | 智能翻页 | 漫画/横图 |
| **Single** | 铺满宽度 | 比例缩放 | 独占一页 | 封面/插图 |

## 🎨 实际效果示例

### 示例1：小说配图（Auto模式）

```
[第1页]
第一章 奇遇

　　那是一个宁静的夜晚...
　　月光洒在湖面上...

[第2页]
　　突然，远处传来...

[图片：风景.jpg - 800x600]
（图片居中显示，自适应大小）

[第3页]
　　他惊讶地发现...
　　原来这里是...
```

### 示例2：漫画书（Full模式）

```
[第1页]
[图片：封面.jpg]
（铺满整页宽度）

[第2页]
[图片：第1话-01.jpg]
（铺满整页宽度）

[第3页]
[图片：第1话-02.jpg]
（铺满整页宽度）
```

### 示例3：图文混排（Auto模式）

```
[第1页]
标题：美食指南

　　首先准备食材...
　　然后清洗干净...

[第2页]
[图片：食材.jpg - 600x400]
（居中显示）

　　接下来开始烹饪...

[第3页]
　　第一步：热锅...
　　第二步：倒油...
```

## 🔧 高级配置

### 配置图片样式

在阅读设置中可以选择图片样式（计划中的功能）：

```dart
// 在ReaderSettings中添加
class ReaderSettings {
  final ImageStyle imageStyle;
  
  const ReaderSettings({
    // ... 其他参数
    this.imageStyle = ImageStyle.auto,
  });
}
```

### 自定义图片处理

可以预处理图片URL：

```dart
// 自定义URL转换
String processImageUrl(String url) {
  if (url.startsWith('//')) {
    return 'https:$url'; // 补全协议
  }
  if (!url.startsWith('http') && !url.startsWith('/')) {
    return 'https://cdn.example.com/$url'; // 添加CDN前缀
  }
  return url;
}

// 处理所有图片URL
final processedUrls = imageUrls.map(processImageUrl).toList();
```

## 📝 代码示例

### 完整示例：带图片的小说分页

```dart
import 'package:xxread/services/ultra_precise_paginator.dart';
import 'package:xxread/services/image_size_service.dart';

Future<void> paginateNovelWithImages() async {
  // 1. 准备内容
  final content = '''
第一章 开始

　　这是一个故事...

<img src="https://example.com/scene1.jpg"/>

　　故事继续...

![插图](assets/images/illustration.png)

　　最后...
''';

  // 2. 初始化分页器
  await UltraPrecisePaginator.initialize(
    screenSize: Size(1080, 2400),
    pixelRatio: 3.0,
    fontSize: 18.0,
    lineHeight: 1.8,
    letterSpacing: 0.2,
    padding: EdgeInsets.all(20),
    statusBarHeight: 44,
    firstLineIndent: 2,
  );

  // 3. 执行分页（自动提取图片）
  final result = await UltraPrecisePaginator.paginate(
    content: content,
    title: '第一章',
    imageStyle: ImageStyle.auto,
  );

  // 4. 使用结果
  print('总页数: ${result.pages.length}');
  for (var i = 0; i < result.pages.length; i++) {
    final page = result.pages[i];
    print('第${i + 1}页:');
    print(page.lines.join('\n'));
    if (page.hasImages) {
      print('[包含图片]');
    }
    print('---');
  }
}
```

## ⚡ 性能优化

### 1. 图片缓存

图片尺寸会被自动缓存，避免重复获取：

```dart
// 首次获取（需要网络请求）
final info1 = await ImageSizeService.getImageSize('https://example.com/image.jpg');

// 再次获取（使用缓存，瞬间完成）
final info2 = await ImageSizeService.getImageSize('https://example.com/image.jpg');
```

### 2. 批量处理

批量获取图片尺寸更高效：

```dart
// ❌ 不推荐：逐个获取
for (final url in urls) {
  final info = await ImageSizeService.getImageSize(url);
}

// ✅ 推荐：批量获取
final images = await ImageSizeService.getImageSizes(urls);
```

### 3. 预加载

提前获取图片尺寸：

```dart
// 在后台预加载
Future.microtask(() async {
  final urls = ImageSizeService.extractImageUrls(content);
  await ImageSizeService.getImageSizes(urls);
  print('图片尺寸已预加载');
});
```

## 🐛 常见问题

### Q1: 图片无法显示？

**A**: 检查以下几点：
1. 图片URL是否正确
2. 网络图片是否可访问
3. 本地图片路径是否正确
4. Asset图片是否已在pubspec.yaml中声明

### Q2: 图片尺寸不对？

**A**: `ImageSizeService`会获取图片的实际尺寸。如果显示不对，检查：
1. 图片文件是否损坏
2. 图片格式是否支持（支持PNG、JPEG、GIF、WebP等）

### Q3: 分页速度慢？

**A**: 图片尺寸获取可能需要时间，优化方法：
1. 使用本地缓存
2. 预加载图片尺寸
3. 使用CDN加速图片访问

### Q4: 如何禁用图片？

**A**: 不提供图片信息即可：

```dart
// 纯文本分页（不处理图片）
await UltraPrecisePaginator.paginate(
  content: text,
  // 不指定images参数
);
```

## 📖 参考

### 图片标记语法

**HTML格式**：
```html
<img src="图片URL"/>
<img src="图片URL" alt="描述"/>
<img src='图片URL'/>
```

**Markdown格式**：
```markdown
![](图片URL)
![描述](图片URL)
```

### ImageStyle枚举

```dart
enum ImageStyle {
  full,    // 铺满宽度
  single,  // 单独一页（图片居中）
  auto,    // 自适应（默认）
}
```

### ImageInfo类

```dart
class ImageInfo {
  final String src;      // 图片URL
  final int width;       // 图片宽度（像素）
  final int height;      // 图片高度（像素）
}
```

## 🎉 总结

现在你的阅读器已支持：

- ✅ 三种图片样式（Auto/Full/Single）
- ✅ 多种图片来源（网络/本地/Asset/Base64）
- ✅ 自动提取图片URL
- ✅ 图文完美混排
- ✅ 智能分页计算
- ✅ 性能优化和缓存

**图片支持已生产就绪！** 🎊

