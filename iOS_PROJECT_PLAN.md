# iOS 原生项目开发规划 (iOS Project Plan)

## 1. 项目概述
本项目旨在将现有的 Flutter 应用迁移为原生的 iOS 应用 (Swift)。
目标是在项目根目录下创建一个名为 `NativeiOS` 的新项目，并采用现代化的 iOS 开发架构。

## 2. 推荐架构 (Architecture)
采用 **MVVM (Model-View-ViewModel)** 架构，配合 **Coordinator** 模式进行页面跳转管理。
- **Model**: 数据模型，与 Flutter 的 `models` 对应。
- **View**: UI 视图 (UIKit 或 SwiftUI)。建议使用 **SwiftUI** 以提高开发效率，若需兼容旧版本或复杂交互可结合 UIKit。
- **ViewModel**: 业务逻辑，负责处理数据并驱动 View 更新，对应 Flutter 的 `providers` 或 `bloc`。
- **Coordinator**: 负责导航逻辑，解耦 View 之间的跳转。

## 3. 目录结构 (Directory Structure)
将在根目录下创建 `NativeiOS` 文件夹，内部结构建议如下：

```
NativeiOS/
├── App/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   └── NativeiOSApp.swift (如果使用 SwiftUI App lifecycle)
├── Core/ (核心层)
│   ├── Network/ (网络请求，对应 services)
│   ├── Database/ (本地数据库)
│   ├── Constants/ (常量，配置)
│   └── Utils/ (工具类，对应 utils)
├── Features/ (功能模块，对应 pages)
│   ├── Home/ (首页)
│   │   ├── View/
│   │   ├── ViewModel/
│   │   └── Model/
│   ├── Reader/ (阅读器核心)
│   ├── User/ (用户中心)
│   └── Settings/ (设置)
├── Common/ (通用组件)
│   ├── Extensions/ (Swift 扩展)
│   ├── UI/ (通用 UI 组件，对应 widgets)
│   └── Base/ (基类)
├── Resources/ (资源文件)
│   ├── Assets.xcassets (图片，颜色)
│   ├── Localization/ (多语言，对应 l10n)
│   └── Fonts/
└── NativeiOS.xcodeproj
```

## 4. 迁移路线图 (Migration Roadmap)

### 第一阶段：基础建设 (Infrastructure)
1.  **项目初始化**：创建 Xcode 项目，配置 Bundle ID，签名等。
2.  **核心库搭建**：
    -   网络层 (使用 Alamofire 或 URLSession)。
    -   数据持久化 (使用 CoreData, Realm 或 SwiftData)。
    -   日志与工具类迁移。

### 第二阶段：数据与业务逻辑 (Data & Logic)
1.  **Model 迁移**：将 Dart Model 转换为 Swift Struct/Class (Codable)。
2.  **Service 迁移**：将 Flutter 的 API 请求逻辑迁移到 Swift 网络层。
3.  **Provider/State 迁移**：将状态管理逻辑转换为 ViewModel (ObservableObject)。

### 第三阶段：UI 与功能实现 (UI & Features)
1.  **通用组件**：迁移 `widgets` 目录下的通用控件。
2.  **核心页面**：
    -   首页 (Home)
    -   阅读器 (Reader) - *这是最复杂的部分，需要重写渲染逻辑*。
    -   个人中心 (User)
3.  **导航流程**：实现页面跳转逻辑。

### 第四阶段：测试与优化 (Testing & Polish)
1.  **功能测试**：确保所有功能与 Flutter 版本一致。
2.  **性能优化**：利用原生优势优化启动速度和渲染性能。
3.  **UI 细节调整**：适配 iOS 设计规范。

## 5. 关键技术选型
-   **语言**: Swift 5+
-   **UI 框架**: SwiftUI (推荐) 或 UIKit
-   **网络**: Alamofire + Moya (可选)
-   **图片加载**: Kingfisher
-   **数据库**: SwiftData (iOS 17+) 或 CoreData

## 6. 下一步行动
1.  确认此规划文档。
2.  执行项目创建脚本，生成目录结构。
3.  开始编写基础代码。
