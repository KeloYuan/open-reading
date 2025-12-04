# 如何运行 NativeiOS 项目 (How to Run)

代码已迁移至您创建的 `xxread-ios` 项目中。

## 运行步骤
1.  打开 **Xcode**。
2.  点击 **Open a project or file**。
3.  选择 `xxread-ios/xxread/xxread.xcodeproj` 文件。
4.  等待 Xcode 索引文件。
5.  **重要**：您需要手动将我生成的文件夹添加到 Xcode 项目视图中（如果它们没有自动显示）：
    *   在 Xcode 左侧项目导航栏，右键点击 `xxread` 文件夹。
    *   选择 **Add Files to "xxread"...**
    *   选择 `Core`, `Features`, `Common`, `Resources` 文件夹。
    *   确保勾选 **Create groups**。
    *   点击 **Add**。
6.  选择模拟器，点击 ▶️ **Run**。

## 常见问题
*   **报错 "No such module 'SwiftData'"**：请检查项目的 Deployment Target 是否为 iOS 17.0+。
