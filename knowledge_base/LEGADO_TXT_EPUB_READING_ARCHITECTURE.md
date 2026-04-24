# Legado TXT / EPUB 阅读实现技术解析

## 文档目的

本文面向需要理解或复刻 Legado 阅读内核的开发者，重点回答两个问题：

1. Legado 是如何实现 TXT 阅读的。
2. Legado 是如何实现 EPUB 阅读的。

文档基于以下源码目录分析：

- `legado/app/src/main/java/io/legado/app/ui/book/read`
- `legado/app/src/main/java/io/legado/app/model`
- `legado/app/src/main/java/io/legado/app/model/localBook`
- `legado/app/src/main/java/io/legado/app/help/book`
- `legado/app/src/main/java/io/legado/app/ui/book/read/page`

本文不关注 UI 交互细节，而聚焦于阅读技术链路本身：文件识别、目录生成、正文获取、正文清洗、分页排版、图片加载、缓存策略与增量更新。

---

## 一、整体架构概览

Legado 的 TXT 与 EPUB 虽然输入格式不同，但进入阅读器后的后半段链路是统一的。

### 1.1 总体分层

可以把阅读内核拆成四层：

1. 入口层
   - 负责打开书籍、初始化阅读状态、触发目录加载与正文加载。
2. 格式解析层
   - TXT 走 `TextFile`
   - EPUB 走 `EpubFile`
   - 共同入口是 `LocalBook`
3. 内容处理层
   - 负责去重标题、重分段、简繁转换、替换规则。
4. 分页排版层
   - 负责把“段落数组 + 图片标记”转换成 Legado 自己的 `TextPage`。

### 1.2 打开一本本地书的主链路

本地书阅读的主入口大致是：

`ReadBookViewModel.initBook()`
-> 检查本地文件存在
-> 必要时重新生成目录
-> `ReadBook.loadContent()`
-> `BookHelp.getContent()`
-> `ContentProcessor.getContent()`
-> `ChapterProvider.getTextChapterAsync()`
-> `TextChapterLayout`
-> 阅读页渲染

这条链路说明一个关键事实：

Legado 不是“格式文件直接交给某个现成阅读控件渲染”，而是：

- 前半段把 TXT / EPUB 解析成自己的章节与正文模型；
- 后半段再交给自研原生分页引擎。

---

## 二、入口层：从打开书籍到进入阅读状态

### 2.1 初始化阅读对象

`ReadBookViewModel.initBook()` 会根据是否为同一本书调用：

- `ReadBook.resetData(book)`：首次打开或切书。
- `ReadBook.upData(book)`：同一本书刷新状态。

这里会完成：

- 当前书籍对象挂载；
- 当前章节索引、章节总数、阅读进度恢复；
- `ContentProcessor` 初始化；
- 清空上一章 / 当前章 / 下一章的排版缓存。

### 2.2 本地书的目录加载时机

本地书满足以下条件之一时会重新生成目录：

- 当前数据库里没有章节；
- 本地文件被修改过。

文件是否修改由 `Book.isLocalModified()` 判断，底层比较的是：

- 当前文件的 `lastModified`
- 书籍表里记录的 `latestChapterTime`

因此，Legado 对本地 TXT / EPUB 都有“文件变更 -> 目录失效 -> 重建目录”的能力。

### 2.3 本地目录写回数据库

本地目录生成后，`ReadBookViewModel.loadChapterListAwait()` 会：

1. 调用 `LocalBook.getChapterList(book)`。
2. 清空数据库中该书原有章节。
3. 写入新章节列表。
4. 更新 `book` 自身字段，例如章节数、最新章节标题、更新时间等。

所以 Legado 的阅读目录不是临时内存结构，而是持久化到数据库中的。

---

## 三、格式分发层：TXT 与 EPUB 的共同入口

### 3.1 `LocalBook` 的职责

`LocalBook` 是本地格式分发器。

它根据文件后缀判断格式：

- `.txt` -> `TextFile`
- `.epub` -> `EpubFile`
- `.umd` -> `UmdFile`
- `.pdf` -> `PdfFile`
- `.mobi/.azw3/.azw` -> `MobiFile`

对于本文关注的两种格式：

- `LocalBook.getChapterList(book)` 会转发到 `TextFile.getChapterList()` 或 `EpubFile.getChapterList()`
- `LocalBook.getContent(book, chapter)` 会转发到 `TextFile.getContent()` 或 `EpubFile.getContent()`

### 3.2 统一抽象的意义

这层统一抽象让后续阅读流程不用关心源文件是 TXT 还是 EPUB。

后续链路只要求上游提供两样东西：

1. `BookChapter` 列表
2. 当前章节对应的正文字符串

一旦这两样东西准备好，后面的内容处理和分页完全可以复用。

---

## 四、TXT 阅读实现

TXT 阅读的核心在于两个难点：

1. 目录通常不存在，需要推导。
2. 文件可能很大，不能每次整本读入内存。

Legado 的实现针对这两个点都做了专门设计。

### 4.1 TXT 解析器对象模型

TXT 由 `TextFile` 负责。

它内部维护了几个关键状态：

- `charset`
  - 当前文件实际编码。
- `txtBuffer`
  - 章节读取时使用的字节缓存。
- `bufferStart` / `bufferEnd`
  - 当前缓存对应的文件字节范围。

同时它通过单例缓存 `textFile` 复用解析器，减少重复初始化；但如果检测到文件已修改，会强制重建对象。

### 4.2 编码探测

首次解析 TXT 目录时，Legado 不会立即扫描整本，而是先读取一小段头部字节：

1. 读取文件前 `bufferSize` 大小的数据。
2. 如果 `book.charset` 为空或文件已修改，则调用 `EncodingDetect.getEncode(...)` 识别编码。
3. 将编码回写到 `book.charset`。

这意味着：

- 编码探测不是每次阅读都重新做。
- 编码结果会持久化在书籍对象里。

### 4.3 目录规则自动选择

TXT 没有标准目录，所以 Legado 会自动从一组启用的 `TxtTocRule` 中挑选最合适的一条。

选择逻辑是：

1. 读取文件头部内容为字符串。
2. 遍历所有启用的目录正则。
3. 用每条规则在头部内容中做匹配。
4. 统计“疑似章节标题”的命中次数。
5. 选择命中效果最好的规则作为 `book.tocUrl`。

这一步做的不是全文精确分析，而是快速选规则。

后续真正的目录生成，才会用选中的规则扫描整本文件。

### 4.4 基于正则的全文目录扫描

如果找到了目录规则，Legado 就进入“有规则分章”模式。

这一模式的实现特点是：

- 按块读取文件，不一次性全量载入。
- 在字节层面记住每一章的 `start` / `end` 偏移。
- 用正则在当前 block 中匹配章节标题。
- 根据匹配结果切出章节边界。

每个 `BookChapter` 至少会记录：

- `title`
- `start`
- `end`
- `wordCount`

这样后面取正文时，就不需要重新推导章节位置。

### 4.5 序章、前言与 block 边界处理

TXT 分章的难点不只是“匹配章节标题”，还包括边界正确性。

Legado 对几种情况都有处理：

1. 文件开头在第一个目录命中之前还有内容
   - 会将其视为“前言”。

2. 一个 block 的尾巴和下一个 block 的开头属于同一章
   - 会把这部分内容并回上一章。

3. 命中的标题实际上是卷名或空白内容
   - 会标记 `isVolume`。

这使得它的分章逻辑不仅仅是简单的正则切割，而是“带上下文的流式目录构建”。

### 4.6 长章节自动拆分

如果开启 `book.getSplitLongChapter()`，Legado 会对超长章节做二次切分。

阈值有两套：

- 有目录规则时：`maxLengthWithToc = 102400`
- 无目录规则时：`maxLengthWithNoToc = 10 * 1024`

当某一章太长时：

1. 原章节会先截断。
2. 再对其内容区间递归执行无目录拆分。
3. 子章节会以 `原标题(1) / 原标题(2)` 形式命名。

这是为了避免单章过大导致分页和跳转体验变差。

### 4.7 无规则分章兜底

如果自动规则选择失败，或者规则为空，Legado 进入“无规则分章”模式。

这时它不再尝试理解语义目录，而是：

1. 按固定最大长度切分。
2. 尽量在换行处断开。
3. 生成形如 `第X章(Y)` 的占位标题。

这种模式的目标不是完美目录，而是保证任何 TXT 都能被打开并顺利阅读。

### 4.8 TXT 正文读取：按字节偏移定位

TXT 的正文读取完全基于章节的 `start/end` 字节偏移。

读取当前章时：

1. 取出该章的 `start` 与 `end`。
2. 检查章节字节区间是否落在当前 `txtBuffer` 缓冲区中。
3. 如果不在，则重新定位并加载一个大块缓存。
4. 从缓存中切出目标字节区间。
5. 用已识别的 `charset` 转成字符串。

这里的关键设计是：

- 目录阶段记录字节偏移；
- 正文阶段按偏移随机访问；
- 通过 `txtBuffer` 避免频繁小 IO。

### 4.9 TXT 正文后处理

TXT 原始正文转成字符串后，会先做很轻量的处理：

- 去掉开头重复标题 `substringAfter(chapter.title)`
- 将开头空白与换行折叠为段首缩进 `replace(padRegex, "　　")`

注意这里的处理很克制。

TXT 更复杂的规范化步骤并不在 `TextFile` 中完成，而是在下游 `ContentProcessor` 中统一完成。

### 4.10 TXT 章节内容缓存策略

TXT 和 EPUB 的缓存策略不同。

TXT 不会像 EPUB 那样把每章提取后的正文单独写入磁盘缓存，而是：

- 通过章节 `start/end` 实时回源读取文件；
- 依赖大块 `txtBuffer` 做短期内存复用。

这样做的优点是：

- 不需要为每章再生成一份文本副本；
- 对超大 TXT 更省磁盘空间；
- 文件修改后也更容易重新计算。

缺点是：

- 每次打开某章仍然要做一次字节切片与解码；
- 目录精度强依赖编码和偏移计算正确性。

---

## 五、EPUB 阅读实现

EPUB 的核心难点和 TXT 不同：

1. 它是 zip 容器，内部有多个 XHTML/图片/样式资源。
2. 目录不一定可靠。
3. 一个 XHTML 资源里可能包含多个章节片段。

Legado 的 EPUB 实现，本质上是“解析 EPUB 资源图，然后把章节正文抽取成适合自家分页器的字符串”。

### 5.1 EPUB 解析器对象模型

EPUB 由 `EpubFile` 负责。

它内部维护了：

- `epubBook`
  - `epublib` 解析出的书籍对象。
- `epubBookContents`
  - EPUB 中的内容资源列表。
- `fileDescriptor`
  - 打开的 `ParcelFileDescriptor`，用于保证底层文件句柄不被释放。

它同样使用单例缓存 `eFile`，同一时间主要服务一本书。

### 5.2 为什么使用懒加载解析

Legado 不是把 EPUB 完整解压到临时目录再读，而是：

1. 通过 `BookHelp.getBookPFD(book)` 获取文件描述符。
2. 构造 `AndroidZipFile`。
3. 调用 `EpubReader().readEpubLazy(zipFile, "utf-8")`。

这里的重点是 `readEpubLazy`。

说明其设计目标是：

- 延迟加载资源；
- 减少一次性解压和内存占用；
- 遇到格式脏数据时，仍可以逐资源修复和容错。

### 5.3 EPUB 元信息与封面提取

在 `upBookInfo()` 中，Legado 会从 EPUB metadata 提取：

- 书名
- 作者
- 简介

封面则通过 `coverImage.inputStream` 解码为 bitmap，再保存为本地图像文件。

这意味着：

- 封面不是运行时每次实时从 EPUB 里取；
- 而是首次解析后落地为普通图片文件。

### 5.4 EPUB 目录生成：优先 TOC，失败则退回 spine

EPUB 目录生成逻辑分两路：

1. 正常路径：读取 `tableOfContents.tocReferences`
2. 兜底路径：如果 TOC 为空，则遍历 `spine.spineReferences`

这种兜底很重要，因为现实中的 EPUB 经常存在：

- NCX / nav 文档损坏
- 目录不完整
- manifest / spine 存在但 toc 缺失

在兜底模式下，Legado 会尝试用资源自身标题或 XHTML `<title>` 生成章节名。

### 5.5 处理“第一章前内容”

很多 EPUB 在正式第一章前还有：

- 封面
- 扉页
- 引言
- 版权页

Legado 在 `parseFirstPage()` 中会：

1. 找到 TOC 的第一条有效章节。
2. 从 contents 开头向后扫描。
3. 在遇到第一章前，把所有 HTML 资源也转成 `BookChapter`。

因此它不会简单丢弃前置内容，而是把这些内容也纳入阅读目录。

### 5.6 处理 fragment 级章节切分

EPUB 的一个常见问题是：

一个 XHTML 资源里可能放了多个章节，而目录只通过 `href#fragmentId` 指到其中一段。

Legado 的做法是：

1. `BookChapter` 记录：
   - 当前章节 `url`
   - `startFragmentId`
   - 上一章回填的 `endFragmentId`
   - `nextUrl`

2. 读取正文时，以：
   - 当前章节首个资源 href
   - 下一章节首个资源 href
   - `startFragmentId`
   - `endFragmentId`
   共同决定正文截取范围。

也就是说，Legado 的章节模型不是“一个章节 = 一个 XHTML 文件”，而是“一个章节 = 资源区间 + fragment 边界”。

### 5.7 EPUB 正文抽取

读取某章内容时，`EpubFile.getContent(chapter)` 会：

1. 找到当前章节起始资源。
2. 从当前资源开始向后遍历 `epubBookContents`。
3. 把属于当前章的 body 片段收集到 `Elements`。
4. 遇到下一章起始资源后停止。
5. 如果下一章开始点在同一资源内，则用 `endFragmentId` 截断。

因此一个 EPUB 章节的正文，可能由多个 XHTML body 拼接而成。

### 5.8 XHTML 清洗与修复

每个资源片段都会经过 `getBody(...)` 处理，核心步骤包括：

1. 特判封面页
   - `titlepage.xhtml` 或含 `cover` 的资源直接替换成 `<img src="cover.jpeg" />`

2. 用 Jsoup 解析 body
   - 这一步顺带修复不规范 XHTML。

3. 移除无关标签
   - `script`
   - `style`
   - 后续还会移除 `title`
   - `display:none` 内容

4. 根据 `startFragmentId` / `endFragmentId` 做正文截断

5. 将 SVG 风格的 `<image xlink:href="...">` 转成 `<img src="...">`

6. 解析相对图片路径
   - 以当前资源 `href` 作为 base URI
   - 生成 EPUB 内部资源的绝对 href

这一步是 EPUB 能正常显示插图的基础。

### 5.9 为什么要把 HTML 转成“保留图片的纯文本”

提取完 body 后，Legado 并不会把这段 HTML 直接交给 WebView。

相反，它调用 `HtmlFormatter.formatKeepImg(html)`：

- 大多数 HTML 标签都会被清掉；
- 块级标签会变成换行；
- 图片标签 `<img>` 会被保留；
- 图片地址会被标准化。

最终得到的是一种“接近纯文本，但允许夹杂 `<img src="...">` 标记”的中间格式。

这个设计的意义非常大：

- 避免 WebView 排版不可控；
- 让 EPUB 与 TXT 都能走统一分页器；
- 保留图片混排能力。

所以可以把 EPUB 正文看作：

`XHTML`
-> `Jsoup 修复/裁剪`
-> `纯文本化，但保留 img 标记`
-> `交给统一分页引擎`

### 5.10 EPUB 图片读取

EPUB 图片不是通过网页 URL 加载，而是通过资源 href 直接回 EPUB 容器中取流。

调用链是：

- 排版阶段识别 `<img src="...">`
- `ImageProvider.cacheImage()`
- 若 `book.isEpub`，则调用 `EpubFile.getImage(book, src)`
- `epubBook.resources.getByHref(abHref)?.inputStream`

随后图片会：

1. 写入 Legado 自己的图片缓存目录；
2. 通过 `BitmapFactory` / `SvgUtils` 获取尺寸；
3. 排版时根据尺寸决定占位方式；
4. 显示时走 LruCache bitmap 缓存。

### 5.11 EPUB 文本缓存策略

EPUB 与 TXT 最大的缓存差异在这里：

对于 EPUB，`BookHelp.getContent()` 在首次读到本地章节内容后，会把正文文本写入章节缓存文件。

也就是说：

- 第一次打开某章：从 EPUB 容器提取 XHTML 并清洗；
- 后续再打开同一章：优先直接读磁盘缓存文本。

这种策略的优点是：

- 避免重复做 XHTML 解析与 fragment 裁切；
- 重开章节速度更稳定；
- 对复杂 EPUB 更友好。

---

## 六、TXT 与 EPUB 共用的正文处理层

TXT 和 EPUB 在拿到原始章节字符串后，会汇合到统一的 `ContentProcessor`。

### 6.1 `ContentProcessor` 的职责

`ContentProcessor.getContent(...)` 主要做以下事情：

1. 去重标题
   - 如果正文开头重复出现章节标题，则去掉。

2. 重新分段
   - 当 `book.getReSegment()` 开启时，调用 `ContentHelp.reSegment(...)`。

3. 简繁转换
   - 根据全局配置执行繁转简或简转繁。

4. 替换净化
   - 运行用户或规则库配置的替换规则。

5. 构造段落数组
   - 按 `\n` 切段；
   - 去除每段首尾空白；
   - 给正文段加上 `ReadBookConfig.paragraphIndent`。

输出结果不是单一字符串，而是 `BookContent`：

- `textList`
- `sameTitleRemoved`
- `effectiveReplaceRules`

### 6.2 为什么重分段放在共享层

TXT 非常依赖重分段，但 EPUB 也可能受益。

Legado 的设计不是为 TXT 写一套、为 EPUB 写一套，而是把“章节正文规范化”抽象为统一层。

这样做有几个好处：

- 阅读页不关心源格式；
- 搜索、朗读、分页面对的是统一结构；
- 规则替换、段落缩进、简繁转换只实现一次。

---

## 七、统一分页排版层

TXT 和 EPUB 真正进入“阅读体验一致”的关键在这里。

### 7.1 异步排版入口

正文字符串经过 `ContentProcessor` 后，会进入：

- `ReadBook.contentLoadFinish()`
- `ChapterProvider.getTextChapterAsync()`
- `TextChapter.createLayout()`
- `TextChapterLayout`

这里采用的是异步流式排版。

`TextChapterLayout` 会一页一页地产生 `TextPage`，并通过 `Channel<TextPage>` 向上游推送。

这意味着：

- 不必等整章排完才显示；
- 当前阅读位置所在页一旦排出来，就可以先显示；
- 后续页面继续后台生成。

### 7.2 段落输入结构

分页器接收的不是原始全文，而是：

- 标题 `displayTitle`
- 正文段落数组 `bookContent.textList`

每个段落可能是：

- 纯文本
- 文本中夹杂 `<img>`

因此分页器天然支持：

- 普通文字阅读
- 插图混排
- 图文分离样式

### 7.3 文字排版策略

文字排版时，Legado 使用：

- `StaticLayout`
- 或自定义 `ZhLayout`

排版会考虑：

- 可见区域宽高
- 行间距
- 标题位置模式
- 段首缩进
- 是否两端对齐
- 中文布局优化

文本最终会拆成 `TextLine`，再归入 `TextPage`。

### 7.4 图片排版策略

分页器识别 `<img>` 后会调用 `setTypeImage(...)`。

它会：

1. 先通过 `ImageProvider.getImageSize()` 拿到真实尺寸。
2. 根据图片样式计算缩放。
3. 生成 `ImageColumn` 插入页中。

图片样式至少包括：

- `full`
  - 按可见宽度铺开。
- `single`
  - 单图独占页并尽量居中。
- `text`
  - 以占位字符方式嵌入文字流。

因此 Legado 的图片不是简单地“下一行显示图片”，而是带布局策略的原生排版对象。

### 7.5 页对象与阅读进度

每个 `TextPage` 都会记录：

- 所属章节索引
- 页内行集合
- 当前页在章节中的字符起点 `chapterPosition`
- 页内容文本

这使得 Legado 可以做到：

- 按字符位置恢复阅读进度；
- 根据字符偏移跳页；
- 朗读与搜索结果定位；
- 阅读进度百分比计算。

---

## 八、TXT 与 EPUB 的实现差异总结

### 8.1 目录来源

TXT：

- 目录通常不存在；
- 通过正则规则推导；
- 规则失败时走固定长度切章兜底。

EPUB：

- 优先使用 TOC；
- TOC 缺失时退回 spine；
- 还会吸收第一章前的前置资源。

### 8.2 正文来源

TXT：

- 直接从原文件按字节偏移切片读取；
- 解码后得到纯文本。

EPUB：

- 从多个 XHTML 资源拼接正文；
- 按 fragment 裁切；
- 清洗为“纯文本 + img 标记”。

### 8.3 缓存策略

TXT：

- 不按章节落盘缓存正文；
- 主要依赖章节起止偏移和大块内存缓冲。

EPUB：

- 首次提取后按章节缓存正文；
- 图片也会落盘缓存。

### 8.4 图片能力

TXT：

- 原生不包含 EPUB 那样的内部资源系统；
- 主要面向纯文本。

EPUB：

- 保留 `<img>`；
- 通过资源 href 读取内嵌图片；
- 支持图文混排和单图页。

### 8.5 共同点

两者最终都会进入：

- `ContentProcessor`
- `ChapterProvider`
- `TextChapterLayout`

因此在用户视角下：

- 翻页动画
- 字体和间距
- 段首缩进
- 阅读进度恢复
- 搜索和朗读

都能表现出一致的阅读体验。

---

## 九、关键设计取舍

### 9.1 为什么不用 WebView 直接读 EPUB

如果直接用 WebView 渲染 EPUB XHTML，会遇到：

- 字体和分页不可控；
- 不同设备排版差异大；
- 阅读进度难以精确映射到章节字符位置；
- TXT 与 EPUB 无法统一阅读内核。

Legado 选择“解析成自己的正文模型 + 自己分页”，本质上是为了控制力。

### 9.2 为什么 TXT 不做章节正文缓存

TXT 正文本身已经是线性纯文本。

相比再生成每章缓存文件，Legado 更倾向于：

- 保存章节边界；
- 读取时按偏移切片。

这是更节省磁盘的方案。

### 9.3 为什么 EPUB 要做章节缓存

EPUB 每章正文读取成本更高，因为它涉及：

- zip 资源访问
- XHTML 解析
- fragment 裁切
- 标签清洗
- 图片 href 规范化

所以 Legado 才会选择把提取结果缓存下来。

### 9.4 为什么分页器接收“段落数组”而不是整章字符串

因为阅读体验里很多特性本质上是段落级的：

- 段首缩进
- 段间距
- 标题单独布局
- 图文混排

如果只传一个大字符串，后续分页器就得重新猜段落，复杂度更高。

---

## 十、如果要在 iOS / Flutter 中复刻，需要抓住什么

如果目标不是逐行照搬源码，而是复刻 Legado 的核心体验，那么最值得保留的是下面这些机制。

### 10.1 TXT 侧必须保留

1. 编码探测
2. 自动目录规则选择
3. 基于字节偏移的章节边界
4. 无规则兜底切章
5. 长章节二次拆分

### 10.2 EPUB 侧必须保留

1. TOC + spine 双通道目录生成
2. 章节前置内容保留
3. fragment 级正文切割
4. XHTML 清洗后只保留文本与图片标记
5. EPUB 内部图片资源解析

### 10.3 统一阅读层必须保留

1. 共享的内容处理层
2. 统一的段落模型
3. 原生分页与异步逐页产出
4. 按字符偏移保存阅读进度

如果只复刻其中一半，比如：

- TXT 用自研分页，
- EPUB 用现成阅读控件，

那么最终阅读行为会明显割裂，难以达到 Legado 这种“一套阅读器吃多种格式”的一致体验。

---

## 十一、结论

Legado 的 TXT 与 EPUB 阅读虽然输入层完全不同，但最终都被转换成同一种中间阅读模型，再交给统一分页器。

可以把它概括为两条链路：

### TXT

`TXT 文件`
-> 编码探测
-> 目录规则选择 / 兜底切章
-> 基于字节偏移读取章节正文
-> `ContentProcessor`
-> `TextChapterLayout`
-> 阅读页

### EPUB

`EPUB(zip)`
-> `epublib` 懒加载解析
-> TOC / spine 目录生成
-> 资源区间 + fragment 裁切正文
-> HTML 清洗并保留 `<img>`
-> `ContentProcessor`
-> `TextChapterLayout`
-> 阅读页

因此，从工程视角看，Legado 的核心价值不在于“支持 TXT 和 EPUB”，而在于：

它把不同格式都收敛到了同一套可控、可分页、可缓存、可定位的阅读内核上。
