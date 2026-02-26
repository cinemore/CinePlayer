## Why

当前 iOS 版本只能直接进入播放器视图，无法在主界面快速切换到关于页；用户希望使用系统原生 TabBar 在播放器与关于页之间切换，同时保持 macOS 现有入口不变。

## What Changes

- 在 iOS 上引入原生 `TabView`，提供“播放器”“关于”两个 tab。
- “播放器”tab 承载现有 `PlayerRootView`。
- “关于”tab 承载现有 `AboutPage`。
- macOS 及其他平台保持当前行为，不增加 tabbar。

## Capabilities

### New Capabilities
- `ios-tabbar-root-navigation`: iOS 根界面支持通过 TabBar 在播放器与关于页之间切换。

### Modified Capabilities
- None.

## Impact

- `CinePlayer/ContentView.swift`
- `CinePlayer` iOS 入口视图层级（仅根视图组织）
