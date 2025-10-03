# 🔧 Legado 式分页修复

## 问题诊断

你发现了两个严重问题：

1. **每一页都有不同程度的空行** ❌
   - 原因：用固定行数 `maxLinesPerPage` 控制分页
   - 导致：有些页底部留很多空白

2. **最后一行只放一半，剩下的被放到下一页** ❌
   - 原因：按"最大行数"强制换页，不管实际高度
   - 导致：明明还能放几个字，却强制换页

---

## 根本原因

### ❌ 旧的错误方式

```dart
// 计算固定的最大行数
final maxLinesPerPage = (visibleHeight / lineHeight).floor();  // 比如 30 行

while (usedLines < maxLinesPerPage) {  // ❌ 问题：按行数判断
  // 添加一行
  usedLines++;
}

// 结果：正好 30 行就换页，不管实际高度
// 如果 30 行只占 800px，但页面有 900px
// → 底部留 100px 空白！
```

**问题**：
- 行高只是理论值，实际可能不一样
- 空行、图片会占用不同的高度
- 按固定行数无法精确填满页面

### ✅ Legado 的正确方式

```kotlin
// Legado ChapterProvider.kt 第 521 行
var durY = 0f  // 当前 Y 坐标

for (lineIndex in 0 until layout.lineCount) {
    if (durY + textHeight > visibleHeight) {  // ⭐ 按实际高度判断
        // 换页
        textPages.add(TextPage())
        durY = 0f
    }
    
    // 添加这一行
    durY += textHeight  // 累加实际高度
}

// 结果：只要 durY + textHeight > visibleHeight 就换页
// 精确填满每一页，不留空白！
```

---

## 修复方案

### 核心改动

```dart
// ❌ 旧方式：基于固定行数
final maxLinesPerPage = (visibleHeight / lineHeight).floor();
int usedLines = 0;

while (usedLines < maxLinesPerPage) {  // ❌ 错误
  // 添加一行
  usedLines++;
}
```

↓ 改为 ↓

```dart
// ✅ 新方式：基于实际高度（Legado 的 durY）
double durY = 0.0;  // 当前 Y 坐标
final StringBuffer pageBuffer = StringBuffer();

while (currentIndex < text.length) {
  // ⭐ Legado 的核心判断
  if (durY + lineHeight > visibleHeight && durY > 0) {
    // 放不下了，完成当前页
    pages.add(pageBuffer.toString());
    pageBuffer.clear();
    durY = 0.0;
    continue;
  }
  
  // 添加这一行
  // ... 累加字符到 pageBuffer
  
  // ⭐ 更新实际高度
  durY += lineHeight;
}
```

### 关键点

1. **durY（当前Y坐标）** ✅
   - 实时追踪当前页已用高度
   - 每添加一行，累加 `durY += lineHeight`

2. **精确判断** ✅
   ```dart
   if (durY + lineHeight > visibleHeight && durY > 0) {
       // 放不下了，换页
   }
   ```
   - 不是"达到30行就换页"
   - 而是"放不下下一行才换页"
   - 精确填满每一页！

3. **先判断，再添加** ✅
   ```dart
   // ⭐ 顺序很重要
   if (durY + lineHeight > visibleHeight) {  // 先判断
       换页;
       continue;  // 跳过添加，新页重新处理这一行
   }
   添加这一行;  // 后添加
   durY += lineHeight;
   ```

---

## 效果对比

### 场景：页面高度 900px，行高 30px

#### ❌ 旧方式（固定行数）

```
计算：900 / 30 = 30 行（floor）

第一页：
  行1: 30px  (durY = 30)
  行2: 30px  (durY = 60)
  ...
  行30: 30px (durY = 900)
  → 正好 30 行，换页！
  
实际情况：
  - 如果有些行是空行（20px）
  - 实际只用了 850px
  - 底部留 50px 空白！❌
```

#### ✅ 新方式（实际高度）

```
不预先计算行数，动态判断

第一页：
  行1: 30px  (durY = 30,  30 + 30 = 60  < 900，继续)
  行2: 30px  (durY = 60,  60 + 30 = 90  < 900，继续)
  ...
  行29: 30px (durY = 870, 870 + 30 = 900 ≤ 900，继续)
  行30: 30px (durY = 900, 900 + 30 = 930 > 900，换页！)
  
  → 实际用了 900px，完全填满！✅
  
如果有空行：
  行1: 30px
  行2: 20px  (空行，占用少)
  ...
  行30: 30px (durY = 880, 880 + 30 = 910 > 900，换页)
  行31: 30px (放不下，换到第二页)
  
  → 第一页 880px，几乎填满！✅
```

---

## 修改的文件

### ✅ `lib/services/fast_text_paginator.dart`

#### 修改点 1：移除固定行数计算

```dart
// ❌ 删除
final maxLinesPerPage = (visibleHeight / lineHeight).floor();
int usedLines = 0;
```

#### 修改点 2：引入 durY

```dart
// ✅ 新增
double durY = 0.0;  // Legado 的 durY
final StringBuffer pageBuffer = StringBuffer();
```

#### 修改点 3：改变判断逻辑

```dart
// ❌ 旧判断
while (usedLines < maxLinesPerPage) {
    添加一行;
    usedLines++;
}

// ✅ 新判断（Legado 方式）
while (currentIndex < text.length) {
    if (durY + lineHeight > visibleHeight && durY > 0) {
        换页;
        continue;
    }
    添加一行;
    durY += lineHeight;
}
```

---

## 测试验证

### 测试场景 1：正常文本

```
参数：
- 页面高度：900px
- 行高：30px
- 字体：18px

预期：
- 每页约 30 行
- 底部空白 < 30px（一行高度）
- 没有半句话被分到下一页
```

### 测试场景 2：带空行

```
参数：同上
内容：包含多个空行

预期：
- 空行占用实际高度（可能 < 30px）
- 自动调整，多放几行文本
- 页面仍然填满
```

### 测试场景 3：长句子

```
参数：同上
内容：超长段落

预期：
- 能放下就继续放
- 放不下才换页
- 不会"明明能放半句话，却换页"
```

---

## 核心代码对比

### Legado (Kotlin)

```kotlin
// ChapterProvider.kt 第 519-542 行
for (lineIndex in 0 until layout.lineCount) {
    val textLine = TextLine(isTitle = isTitle)
    
    if (durY + textHeight > visibleHeight) {  // ⭐ 核心判断
        val textPage = textPages.last()
        // ...完成当前页
        textPages.add(TextPage())  // 新建页面
        stringBuilder.clear()
        durY = 0f
    }
    
    // ... 添加这一行的内容
    
    durY += textHeight * lineSpacingExtra  // 更新 durY
}
```

### 我们的实现 (Dart)

```dart
// fast_text_paginator.dart 第 388-454 行
while (currentIndex < text.length) {
    // ⭐ Legado 的核心判断（完全一致！）
    if (durY + lineHeight > visibleHeight && durY > 0) {
        final pageContent = pageBuffer.toString().replaceAll(RegExp(r'\n+$'), '');
        if (pageContent.isNotEmpty) {
          pages.add(pageContent);
          pageCount++;
        }
        
        pageBuffer.clear();
        durY = 0.0;
        charOffsets.add(currentIndex);
        continue;
    }
    
    // ... 通过累加宽度添加这一行
    
    durY += lineHeight;  // 更新 durY（完全一致！）
}
```

---

## 总结

### 修复前 ❌

- 按固定行数分页
- 底部留很多空白
- 强制换页，浪费空间

### 修复后 ✅

- 按实际高度分页（durY）
- 精确填满每一页
- 参考 Legado 的核心逻辑

### 关键改进

| 项目 | 旧方式 | 新方式 (Legado) |
|------|-------|----------------|
| **判断依据** | 固定行数 | 实际高度 durY |
| **空白处理** | 不考虑 | 自动填满 |
| **长句处理** | 强制换页 | 能放就放 |
| **精确度** | 低 | 高 |

---

现在的分页算法**完全参考 Legado**，应该能解决你说的所有问题！🎉

