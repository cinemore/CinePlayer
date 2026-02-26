## Context

当前 `ContentView` 在所有平台直接渲染 `PlayerRootView`。此前已新增 `AboutPage`，但 iOS 缺少主入口切换机制。需求要求 iOS 使用原生 TabBar 在播放器与关于页切换，且 macOS 不受影响。

## Goals / Non-Goals

**Goals:**
- iOS 根视图使用原生 `TabView` 展示两个 tab：播放器、关于。
- 默认进入播放器 tab，保留现有播放器环境对象注入路径。
- 关于 tab 复用现有 `AboutPage`。
- macOS 与其他平台保持现状。

**Non-Goals:**
- 不改动 macOS 关于窗口入口。
- 不改动播放器逻辑、手势、控制栏。
- 不引入自定义 TabBar 样式或额外路由框架。

## Decisions

1. 在 `ContentView` 中通过 `#if os(iOS)` 分支引入 `TabView`。
- 原因：改动范围最小，不影响 `CinePlayerApp` 现有跨平台场景结构。
- 备选：在 `CinePlayerApp` 改 Scene 结构；会增加平台分支复杂度，不必要。

2. 关于页 tab 使用 `NavigationStack { AboutPage() }`。
- 原因：保持 `AboutPage` 的标题导航能力，兼容当前 `navigationTitle` 设计。
- 备选：直接放置 `AboutPage`；标题展示与导航行为不一致。

3. 非 iOS 平台继续返回现有 `PlayerRootView`。
- 原因：完全满足“macOS 不需要”且避免对 tvOS/visionOS 引入未请求变更。

## Risks / Trade-offs

- [iOS 下 tab 切换可能重建视图状态] → 使用稳定的根 `TabView` 结构并保持 `PlayerRootView` 作为独立 tab 内容。
- [关于页在 tab 内导航表现差异] → 使用 `NavigationStack` 包裹关于页，保持一致的标题显示。
