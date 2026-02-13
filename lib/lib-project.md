# lib/ 结构总览

> 更新：2026-02-13
> 说明：本文件聚焦 `lib/` 目录结构，完整索引请看 `CODEBASE_DOCUMENTATION.md`

## 快速入口

- `lib/main.dart`：应用入口
- `lib/pages/reader_page.dart`：阅读器核心页面（主结构）
- `lib/pages/reader_page_toolbar_actions_part.dart`：阅读页工具栏动作拆分
- `lib/providers/reader_providers.dart`：阅读器核心状态
- `lib/services/pagination/pagination_services.dart`：分页域入口
- `lib/services/books/book_services.dart`：书籍域入口
- `lib/services/reading/reading_services.dart`：阅读域入口
- `lib/pages/home_shell_page.dart`：首页壳层（导航）
- `lib/pages/home_shell_layout_part.dart`：首页壳层布局/系统栏拆分
- `lib/pages/home_mobile_dashboard_page.dart`：手机首页内容（UI）
- `lib/pages/home_dashboard_sections_part.dart`：首页统计区块拆分（卡片/图表/成就）
- `lib/services/sync/sync_services.dart`：同步域入口（WebDAV）
- `lib/services/sync/ios_cloud_sync_service.dart`：iOS 文件/iCloud Drive 分类快照同步

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

- `reader_page.dart` 已拆分工具栏动作到 `reader_page_toolbar_actions_part.dart`，后续可继续按 feature 拆分。
- `services/` 中包含多个领域能力：导入、分页、数据库、同步、TTS、图片处理等。
- 服务层新增域入口：`core/`、`books/`、`pagination/`、`reading/`、`library/`（统一导入更直观）。
- `models/` 里 `highlight.dart`/`note.dart` 为兼容层，核心统一使用 `book_note.dart`。
- 首页优先按职责阅读：`home_shell_page.dart`（壳层）→ `home_mobile_dashboard_page.dart`（手机内容）→ `home_layout_constants.dart`（布局常量）。
- 首页统计旧大文件已拆分为 `home_dashboard_page.dart`（入口）+ `home_dashboard_sections_part.dart`（UI区块方法），方便新手分段阅读。
- 首页壳层已拆分为 `home_shell_page.dart`（状态/路由）+ `home_shell_layout_part.dart`（布局/系统栏），排查导航问题更聚焦。
- 首页可视化区块拆分在 `lib/pages/home_widgets/`，每个文件对应一个 UI 区块，便于新手按模块改。
- 设置页封面操作已拆分到 `lib/pages/settings_page_cover_actions_part.dart`，避免单文件过大。
- 壳层相关拆分文件：`home_navigation_item.dart`、`home_bounce_navigation_item.dart`、`home_page_wrappers.dart`。
- WebDAV 同步路径规范集中在 `lib/services/sync/webdav_sync_path_helper.dart`。
- WebDAV 同步清单模型在 `lib/services/sync/webdav_sync_manifest_model.dart`，用于描述书籍/进度/笔记/高亮/批注的数据覆盖范围。
- iOS 可通过设置页触发“iCloud/文件夹同步”，直接在 iCloud Documents / 文件目录下按分类保存副本（books/progress/notes/...）。
