## 1. About 页面实现

- [x] 1.1 新增跨平台 `AboutPage` 视图，填充与 cinemore 一致的版本/联系方式/法律链接/版权备案信息，去除 IMDb/TMDB 相关内容。
- [x] 1.2 将关于页顶部图标替换为 `CinePlayerIcon`，并处理外链点击能力（macOS 使用 `NSWorkspace`，其他平台使用 `openURL`）。

## 2. macOS 菜单入口对齐

- [x] 2.1 在 `CinePlayerApp` 中增加 `CommandGroup(replacing: .appInfo)` 的“关于”菜单项。
- [x] 2.2 实现 macOS 独立关于窗口打开逻辑，并将 `AboutPage` 挂载到窗口内容。

## 3. 验证与收尾

- [x] 3.1 运行并通过 7 个平台构建（iOS、iOS Simulator、tvOS、tvOS Simulator、macOS、visionOS、visionOS Simulator）。
- [x] 3.2 更新任务勾选并确认 OpenSpec 状态可用于归档。
