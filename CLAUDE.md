# Claude AI 协作指南

## 重要原则：决策前必须询问

**在做出任何重要决定之前，Claude AI 必须先向用户询问并获得确认。**

### 需要询问的决策类型

1. **架构变更**
   - 添加或删除核心功能模块
   - 修改项目结构
   - 更换技术方案或第三方库

2. **功能实现方案**
   - 多种实现方式的选择
   - 性能优化策略的选择
   - UI/UX 设计方案

3. **文件操作**
   - 删除现有代码文件（除非明确是临时测试文件）
   - 重命名核心文件
   - 大规模重构

4. **配置修改**
   - 修改构建配置
   - 更改依赖版本
   - 调整环境配置

### 可以直接执行的操作

1. **明确的 Bug 修复**
   - 修复编译错误
   - 修复运行时错误
   - 修复逻辑错误

2. **代码优化**
   - 性能优化（在不改变功能的前提下）
   - 代码格式化
   - 添加注释和文档

3. **测试相关**
   - 编写单元测试
   - 修复失败的测试

## 项目核心架构

### 分页系统

**当前使用的分页器：**
- `lib/services/optimized_stable_paginator.dart` - 主要分页器
- `lib/services/pagination_cache_service.dart` - 分页缓存服务

**分页器特性：**
- 字符级精确分页，可在任意位置断开
- 支持图片（通过 `<img src="path" />` 标签）
- 图片默认独占一页
- 支持分页结果缓存

**已删除的分页器（不再使用）：**
- fast_text_paginator.dart
- precise_paginator_with_images.dart
- stable_text_paginator.dart
- streaming_paginator.dart
- 等其他测试性质的分页器

### 图片支持

**当前状态：**
- 分页器层面：支持解析 `<img src="path" />` 标签
- 渲染层面：`reader_page.dart` 中已实现图片渲染逻辑
- 存储层面：使用 `BookImageManager` 管理图片

**图片处理流程：**
1. 导入书籍时，提取图片并保存到应用目录
2. 在内容中使用 `<img src="绝对路径" />` 标记
3. 分页时，图片独占一页
4. 渲染时，使用 `Image.file()` 加载本地图片

## 开发约定

### 代码风格

- 使用中文注释
- 关键操作添加 emoji 标记（📖 📄 ✅ ❌ 等）
- 重要的状态变化使用 debugPrint 输出日志

### Git 提交

- 提交前必须询问用户
- 提交信息使用中文
- 提交信息末尾添加：
  ```
  🤖 Generated with [Claude Code](https://claude.com/claude-code)

  Co-Authored-By: Claude <noreply@anthropic.com>
  ```

### 文档管理

- 有意义的技术方案、问题解决方法要记录到 `knowledge_base/` 目录
- 临时性的开发文档不要保留在根目录
- README 和主要文档保持最新

## 常见问题处理

### 分页相关问题

1. **分页结果不准确**
   - 检查 TextPainter 配置是否与 Text Widget 一致
   - 确认行高、字间距等参数正确传递

2. **图片显示异常**
   - 验证图片文件路径是否存在
   - 检查图片文件权限
   - 确认图片格式支持

3. **性能问题**
   - 启用分页缓存
   - 检查是否有重复分页计算
   - 考虑优化大文件处理

### 常用命令

```bash
# 运行应用
flutter run

# 分析代码
flutter analyze --no-fatal-infos

# 清理构建缓存
flutter clean

# 更新依赖
flutter pub get
```

## 更新记录

### 2025-01-19
- 清理了8个未使用的分页器文件
- 清理了测试和调试文件
- 修复了编译错误
- 创建本文档

---

**记住：遇到不确定的决策时，先询问，再执行！**
