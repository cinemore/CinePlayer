## Why

当前 macOS 控制面板与 iOS 版本在业务按钮和交互路径上不一致，导致跨端操作心智不统一。用户要求 macOS 除移动端横竖屏切换外，功能与 iOS 对齐。

## What Changes

- 重构 macOS 控制面板按钮分组，补齐与 iOS 对齐的业务入口与交互。
- 新增并接入按钮：关闭、PiP、画面填充、快退/快进、播放/暂停、音轨、视频轨、倍速、字幕、设置、增强、媒体信息。
- 移除 macOS 面板里与“功能对齐”目标冲突的播放列表上一集/下一集入口，统一为快退/快进。
- 保留 macOS 特有能力（全屏切换），但不引入 iOS 横竖屏切换按钮。
- 复用现有侧栏体系：字幕/设置/增强/音轨/视频轨/倍速容器保持同一数据状态模型。

## Capabilities

### New Capabilities
- `macos-control-layout-business-parity`: macOS 控制面板按 iOS 业务分组提供一致的顶部/底部控制区域与按钮排序。
- `macos-business-button-parity`: macOS 提供与 iOS 一致的业务按钮集合（不含移动端旋转能力），并接入对应行为。
- `macos-playback-interaction-parity`: macOS 底部播放控制统一为快退/快进+播放暂停，并保持与侧栏容器联动。

### Modified Capabilities
- 无

## Impact

- 主要影响文件：`CinePlayer/Player/Components/ControllerPanelViewMacOS.swift`。
- 影响状态联动：`PlayerControlModel`（已具备相关状态，主要复用）。
- 影响 UI 验证范围：macOS 控制面板、SiderView 容器联动与媒体信息卡片展示。
- 按仓库要求执行 7 平台 `xcodebuild` 验证，确保跨平台编译不回归。
