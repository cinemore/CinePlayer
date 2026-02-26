## Why

当前仓库无法满足“7 个平台目的地全部可编译”的基线要求，tvOS 与 tvOS Simulator 构建失败，阻断了发布与回归验证流程。该问题需要立即修复并形成可重复验证证据。

## What Changes

- 修复 tvOS 手势控制器中的编译错误（缺失环境对象引用）。
- 修复字幕视图中的控件样式可用性问题，避免低版本 tvOS 目标编译失败。
- 保持现有功能行为不变，仅做最小编译兼容调整。
- 重新执行并记录 7 平台构建矩阵结果。

## Capabilities

### New Capabilities
- `all-platform-build-pass`: 项目在 `iphoneos`、`iphonesimulator`、`appletvos`、`appletvsimulator`、`macosx`、`xros`、`xrsimulator` 上可成功构建。

### Modified Capabilities
- 无。

## Impact

- 影响代码：`GestureControllerTVOS.swift`、`EmbeddedSubtitleView.swift`、`ExternalSubtitleView.swift`。
- 不涉及 API 协议、持久化数据结构、外部依赖变更。
- 影响范围限定在编译兼容与平台可用性标注。
