## Why

`DebugTemporalRGBFrameInserter` 与 `CINEMORE_DEBUG_TEMPORAL_INSERTER` 仅用于临时调试，不属于纯播放器的目标能力。继续保留该测试分支会增加维护成本，并与“仅通过 `#if DEBUG` 控制增强可见性”的约束不一致。

## What Changes

- 删除 `VideoPlayerModel` 中 `CINEMORE_DEBUG_TEMPORAL_INSERTER` 相关运行时开关分支。
- 删除 `DebugTemporalRGBFrameInserter` 测试辅助实现。
- 保留现有增强链路（Anime4K/System VT/光流）与 `#if DEBUG` 编译门禁逻辑。

## Capabilities

### New Capabilities
- `remove-debug-temporal-inserter-test-hook`: 移除帧回调调试测试钩子，保持增强能力由正式策略路径驱动。

### Modified Capabilities
- `all-platform-build-pass`: 删除测试分支后继续满足 7 平台构建通过。

## Impact

- `CinePlayer/Player/Model/VideoPlayerModel.swift`
- `openspec/changes/complete-frame-callback-parity-tail/specs/remove-debug-temporal-inserter-test-hook/spec.md`
- `openspec/changes/complete-frame-callback-parity-tail/specs/all-platform-build-pass/spec.md`
