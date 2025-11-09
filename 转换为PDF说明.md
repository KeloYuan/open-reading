# Markdown转PDF说明

## 推荐方法

### 方法1：使用Typora（最简单，推荐）

1. **下载安装Typora**
   - 官网：https://typora.io/
   - 支持Windows/macOS/Linux

2. **转换步骤**
   ```
   1. 用Typora打开 "软著-用户使用手册.md"
   2. 点击菜单：文件 → 导出 → PDF
   3. 选择保存位置
   4. 等待转换完成
   ```

3. **优势**
   - ✅ 所见即所得
   - ✅ 完美支持SVG
   - ✅ 中文支持好
   - ✅ 操作简单

---

### 方法2：使用Pandoc + WPS/Word（适合需要精细调整）

1. **安装Pandoc**
   - Windows: 从 https://pandoc.org/installing.html 下载安装包
   - 或使用Chocolatey: `choco install pandoc`

2. **转为Word**
   ```bash
   pandoc 软著-用户使用手册.md -o 软著-用户使用手册.docx
   ```

3. **Word转PDF**
   - 用Word/WPS打开生成的docx文件
   - 调整格式（页边距、字体等）
   - 另存为PDF

4. **优势**
   - ✅ 可以精细调整格式
   - ✅ 方便添加页眉页脚
   - ✅ 可以调整页码

---

### 方法3：使用VS Code + Markdown PDF插件

1. **安装VS Code**
   - 官网：https://code.visualstudio.com/

2. **安装插件**
   - 在VS Code中搜索并安装 "Markdown PDF" 插件

3. **转换步骤**
   ```
   1. 用VS Code打开 "软著-用户使用手册.md"
   2. 按 Ctrl+Shift+P (macOS: Cmd+Shift+P)
   3. 输入 "markdown pdf"
   4. 选择 "Markdown PDF: Export (pdf)"
   5. 等待转换完成
   ```

4. **配置（可选）**
   在VS Code设置中搜索 "markdown-pdf"，可调整：
   - 页边距
   - 页眉页脚
   - 纸张大小
   - 字体

---

### 方法4：使用Pandoc + XeLaTeX（专业，但复杂）

1. **安装依赖**
   - Pandoc: https://pandoc.org/installing.html
   - TeXLive (Windows): https://tug.org/texlive/
   - MacTeX (macOS): https://tug.org/mactex/

2. **转换命令**
   ```bash
   pandoc 软著-用户使用手册.md -o 软著-用户使用手册.pdf \
     --pdf-engine=xelatex \
     -V mainfont="SimSun" \
     -V geometry:"top=2cm, bottom=2cm, left=2.5cm, right=2cm" \
     -V fontsize=11pt \
     --toc \
     --number-sections
   ```

3. **Windows PowerShell版本**
   ```powershell
   pandoc "软著-用户使用手册.md" -o "软著-用户使用手册.pdf" `
     --pdf-engine=xelatex `
     -V mainfont="SimSun" `
     -V geometry:"top=2cm, bottom=2cm, left=2.5cm, right=2cm" `
     -V fontsize=11pt `
     --toc `
     --number-sections
   ```

4. **参数说明**
   - `--pdf-engine=xelatex`: 使用XeLaTeX引擎（支持中文）
   - `-V mainfont="SimSun"`: 设置主字体为宋体
   - `-V geometry`: 设置页边距
   - `-V fontsize`: 设置字体大小
   - `--toc`: 生成目录
   - `--number-sections`: 章节编号

---

### 方法5：在线转换（快速但功能有限）

1. **推荐网站**
   - Markdown to PDF: https://www.markdowntopdf.com/
   - CloudConvert: https://cloudconvert.com/md-to-pdf
   - Dillinger: https://dillinger.io/ (支持导出PDF)

2. **使用步骤**
   ```
   1. 打开网站
   2. 上传或粘贴Markdown内容
   3. 点击转换
   4. 下载PDF文件
   ```

3. **注意**
   - ⚠️  需要将截图一起上传
   - ⚠️  SVG可能显示不正常
   - ⚠️  格式可能需要调整

---

## 格式要求（软著申请）

根据软件著作权申请要求：

### 页面设置
- **纸张大小**：A4 (210mm × 297mm)
- **页边距**：
  - 上：2.5cm
  - 下：2.5cm
  - 左：3cm
  - 右：2cm
- **页眉页脚**：建议添加页码

### 字体要求
- **标题字体**：黑体或微软雅黑
  - 一级标题：18-22号
  - 二级标题：16-18号
  - 三级标题：14-16号
- **正文字体**：宋体或仿宋
  - 字号：11-12号（小四）
  - 行距：1.5倍

### 内容要求
- **总页数**：40-60页（含截图）
- **图片要求**：
  - 清晰可读
  - 加注图片说明
  - 建议居中对齐
- **目录要求**：
  - 自动生成目录
  - 显示页码
  - 最多3级目录

---

## 常见问题

### Q1：PDF中SVG不显示？
**A：** 
- Typora可以正常显示SVG
- Pandoc需要使用 `--embed-resources` 参数
- 或者将SVG转为PNG再嵌入

### Q2：中文显示乱码？
**A：**
- 使用XeLaTeX引擎：`--pdf-engine=xelatex`
- 指定中文字体：`-V mainfont="SimSun"`
- 或使用支持中文的在线工具

### Q3：图片太大导致PDF文件过大？
**A：**
- 压缩图片：使用TinyPNG或ImageOptim
- 调整图片尺寸：建议宽度不超过800px
- 转换为JPEG格式（适度降低质量）

### Q4：表格格式错乱？
**A：**
- 使用简单表格格式
- 避免过宽的表格
- Typora可以手动调整表格样式

### Q5：代码块显示不完整？
**A：**
- 缩小代码字体
- 减少每行字符数
- 使用横向布局（landscape）

---

## 转换后检查清单

转换完成后，请检查以下内容：

- [ ] PDF可以正常打开
- [ ] 所有截图正确显示
- [ ] SVG图片清晰可见
- [ ] 目录正确生成且可点击跳转
- [ ] 中文正常显示无乱码
- [ ] 页码连续正确
- [ ] 表格格式正常
- [ ] 文件大小合理（10-50MB）
- [ ] 总页数符合要求（40-60页）
- [ ] 图片说明文字清晰

---

## 最终提交建议

### 文件命名
- 用户手册：`XX软件用户使用手册V1.0.pdf`
- 或按要求格式：`软件名称-用户手册.pdf`

### 打印要求（如需纸质版）
- 单面打印
- 使用A4纸
- 不要装订（使用文件夹）
- 每页右下角注明页码

### 电子版要求
- PDF格式
- 文件大小不超过50MB
- 不要加密或设置密码
- 确保可以正常打开和查看

---

## 推荐配置（Typora自定义CSS）

如果使用Typora，可以创建自定义CSS以符合软著格式要求：

```css
/* 保存为 softcopy.css，放在Typora主题目录 */

/* 页面设置 */
@media print {
  @page {
    size: A4;
    margin: 2.5cm 2cm 2.5cm 3cm;
  }
}

/* 标题样式 */
h1 {
  font-size: 22pt;
  font-weight: bold;
  page-break-before: always;
  margin-top: 0;
}

h2 {
  font-size: 18pt;
  font-weight: bold;
  margin-top: 20pt;
}

h3 {
  font-size: 14pt;
  font-weight: bold;
  margin-top: 15pt;
}

/* 正文样式 */
body {
  font-family: "SimSun", "宋体", serif;
  font-size: 11pt;
  line-height: 1.5;
}

/* 图片样式 */
img {
  max-width: 100%;
  display: block;
  margin: 10pt auto;
  page-break-inside: avoid;
}

/* 表格样式 */
table {
  font-size: 10pt;
  border-collapse: collapse;
  margin: 10pt auto;
  page-break-inside: avoid;
}

/* 代码样式 */
code {
  font-family: "Courier New", monospace;
  font-size: 9pt;
}
```

使用方法：
1. 在Typora中选择 "文件 → 偏好设置 → 外观 → 打开主题文件夹"
2. 将上述CSS保存为 `softcopy.css`
3. 重启Typora
4. 选择 "主题 → softcopy"
5. 导出PDF

---

**提示：** 建议先用小文档测试转换效果，确认格式无误后再转换完整文档。

