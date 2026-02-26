## 1. iOS 根导航改造

- [x] 1.1 在 `ContentView` 中为 iOS 添加原生 `TabView`，提供“播放器/关于”两个 tab。
- [x] 1.2 将“播放器”tab 绑定到 `PlayerRootView`，将“关于”tab 绑定到 `AboutPage`（使用 `NavigationStack` 承载）。

## 2. 平台边界保持

- [x] 2.1 确保 macOS 与其他非 iOS 平台继续使用原有 `PlayerRootView` 根视图，不引入 TabBar。

## 3. 验证

- [x] 3.1 运行并通过 7 平台构建验证（iOS、iOS Simulator、tvOS、tvOS Simulator、macOS、visionOS、visionOS Simulator）。
- [x] 3.2 更新任务勾选并确认 OpenSpec 状态完成。
