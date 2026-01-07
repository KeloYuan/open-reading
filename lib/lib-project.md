# lib/ 结构总览

> 更新：2025-01-07
> 说明：本文件聚焦 `lib/` 目录结构，完整索引请看 `CODEBASE_DOCUMENTATION.md`

## 快速入口

- `lib/main.dart`：应用入口
- `lib/pages/reader_page.dart`：阅读器核心页面（最大文件）
- `lib/providers/reader_providers.dart`：阅读器核心状态
- `lib/services/enhanced_paginator.dart`：分页核心算法
- `lib/services/book_import_service.dart`：书籍导入入口

## 目录概览

```
lib/
├── main.dart
├── l10n/
├── models/        # 书籍、章节、笔记、书源、翻页配置
├── providers/     # Riverpod 状态管理
├── pages/         # 页面（reader/home/library/settings...）
├── services/      # 业务服务（导入、分页、同步、DAO、TTS...）
├── utils/         # 工具类（主题、响应式、转场...）
└── widgets/       # 复用组件（TTS 面板、目录、选择工具栏...）
```

## 说明与建议

- `reader_page.dart` 体量较大，后续可考虑拆分成独立子组件与 feature 模块。
- `services/` 中包含多个领域能力：导入、分页、数据库、同步、TTS、图片处理等。
- `models/` 里 `highlight.dart`/`note.dart` 为兼容层，核心统一使用 `book_note.dart`。

