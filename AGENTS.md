# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## 项目概述

**小元读书 (xxread)** 是当前 Monorepo 中的主 Flutter 工程，负责跨平台书库、导入、同步、TTS 与阅读器实现。

- 位置：`OpenReading/`
- 主要技术：Flutter 3.35.3 / Dart 3.9.2 / SQLite / Riverpod / Provider / WebView
- 代码入口：`lib/main.dart`
- 代码索引：`CODEBASE_DOCUMENTATION.md`
- 快速索引：`lib/lib-project.md`

## 2026-04 阅读平台策略覆盖说明

本文件后续若与仓库根目录 `AGENTS.md`、`app/iOS/AGENTS.md` 或 `docs/reading-platform/` 冲突，以较新的阅读平台策略为准。

1. 新的 TXT 阅读能力应优先对齐 `Rust Core + Native Paginator + Native Reader`，不要再把“临时 EPUB + Readium”当作长期演进方向。
2. 阅读进度、书签、高亮、笔记、TTS 恢复必须绑定 locator / canonical text anchor，而不是数据库里的 `page_index` 一类旧字段。
3. 当前设备上的页码必须视为派生结果；换字号、换设备、换边距后允许页码变化，但必须仍能恢复到同一文本位置。
4. 分页缓存必须绑定 `layoutSignature`，任何影响排版的设置变化后都应失效重算。
5. 新实现优先保证一致性和恢复能力，再考虑分页速度与局部兼容。

## 当前真相源

1. 当前默认阅读入口是 `lib/services/reading/reading_router_service.dart`。
2. 当前默认阅读页面是 `lib/pages/foliate_reader_page.dart`，也就是 Web/Foliate 阅读链路。
3. `lib/reader_core/` 当前主要承担解析、文档模型和阅读支撑能力，不再作为独立阅读页面入口存在。
4. `lib/services/pagination/` 是旧分页链路，当前仍承担兼容职责，阅读代码时需要和 `reader_core/parser`、`reader_core/document` 对照理解。
5. `lib/l10n/app_localizations*.dart` 是生成文件，只需要知道作用，不建议直接手改。

## 建议阅读顺序

1. `lib/main.dart`
2. `lib/pages/home_shell_page.dart`
3. `lib/pages/home_mobile_dashboard_page.dart`
4. `lib/services/books/book_import_service.dart`
5. `lib/services/books/book_dao.dart`
6. `lib/services/reading/reading_router_service.dart`
7. `lib/pages/foliate_reader_page.dart`
8. `lib/reader_core/`
9. `lib/services/sync/`、`lib/services/tts_service.dart`、`lib/services/core/`

如果需要逐文件理解，请直接打开 `CODEBASE_DOCUMENTATION.md`。

## 当前目录地图

```text
lib/
├── main.dart                    # 应用入口
├── l10n/                        # 国际化生成代码
├── models/                      # 书籍、章节、书签等模型
├── pages/                       # 页面层与首页子组件
├── reader_core/                 # 阅读支撑层（模型、解析、文档转换）
├── services/                    # 业务服务（导入、DAO、同步、阅读、TTS、基础设施）
├── utils/                       # 主题、布局、系统 UI、编码等工具
└── widgets/                     # 通用组件
```

## 常用命令

```bash
flutter pub get
flutter run
flutter analyze --no-fatal-infos
dart format .
flutter test
flutter build apk
flutter build ios
flutter build windows
flutter build macos
flutter clean
```

## 问题解决原则

1. 所有代码修改都要以根本解决问题为目标，避免只做表面性的补丁式修复。
2. 拒绝为了快速交差而叠加脆弱的新代码；方案应优先保证清晰性、可维护性与一致性。
3. 引入新代码时，要同步清理无用、冗余、过时代码，避免旧实现和新实现长期并存。
4. 不要钻牛角尖；如果某个问题持续无法解决，应及时上网搜索可靠方案，必要时参考成熟开源项目的实现思路，再结合本项目架构做干净落地。

## 维护约定

1. 更新代码结构时，优先同步更新 `CODEBASE_DOCUMENTATION.md` 和 `lib/lib-project.md`。
2. 新增可维护的 Dart 源码时，在文件顶部补充两行简介，说明“文件说明”和“技术要点”。
3. 生成文件、第三方依赖和平台生成代码不要混进主链路索引。
4. 涉及阅读平台链路变更时，先确认是改当前 Web/Foliate 主链路，还是改 `reader_core/` 新内核链路。
