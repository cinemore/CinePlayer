## Context

当前 `CinePlayer` 已存在 Anime4K / System VT / 光流补帧适配器与增强设置模型，但 `VideoPlayerModel` 缺失帧回调装配逻辑，导致策略切换无法实际驱动 `frameCallbackPolicy` 与 `onVideoFrame`。同时 `PlayerControlView` 未在 ready 阶段同步视频分辨率到增强模型，System VT 与光流可用性无法正确更新。需求是从 `cinemore-apple` 迁回该链路，并将 VT/光流限制为 Debug 可见。

## Goals / Non-Goals

**Goals:**
- 恢复增强策略到帧回调的完整映射与运行时热更新能力。
- 在播放器 ready 时按真实视频尺寸更新 Anime4K/System VT/光流可用性。
- 用编译期门禁确保 VT/光流只在 Debug 可见与可执行。
- 保持现有字幕翻译与播放器主流程不回归。

**Non-Goals:**
- 不重写 Anime4K/System VT/光流适配器内部算法。
- 不新增业务能力（历史、云盘、字幕下载等）。
- 不变更非增强相关 UI/手势行为。

## Decisions

1. 决策：在 `VideoPlayerModel` 中恢复 `makeFrameCallbackConfiguration`、`configureFrameCallback`、`applyFrameCallbackConfigurationToActivePlayer`。
- 原因：增强策略与 `CinePlayerConfig` 的绑定点就在播放器模型层，最小改动可复用源仓库稳定行为。
- 备选方案：在 `PlayerControlView` 直接拼接 `CinePlayerConfig` 回调。
- 不选原因：会让 UI 层承担运行时策略分发，增加状态耦合与维护成本。

2. 决策：通过 `PlayerEnhancementModel.onRuntimeConfigChanged` 触发活跃播放器热更新。
- 原因：模型已具备统一配置变更出口，集中触发可避免在多个 `onChange` 分散更新。
- 备选方案：在 `PlayerControlView` 对每个增强字段分别 `onChange` 调用 reset。
- 不选原因：重复监听点多，易遗漏且与现有架构方向不一致。

3. 决策：VT/光流采用“双层 Debug 门禁”。
- 原因：仅 UI 隐藏不足以阻止 Release 因持久化值误触发；运行时仍需在策略钳制和回调分发处回落 `off`。
- 备选方案：仅 `SiderEnhancementView` 使用 `#if DEBUG`。
- 不选原因：Release 仍可能通过已有设置值进入 System VT/光流路径。

4. 决策：播放器 ready 时由 `PlayerControlView` 拉取轨道分辨率并调用 `updateAvailabilityForCurrentVideo`。
- 原因：轨道 naturalSize 只在控制层可直接获取；沿用已有事件时机与源实现一致。
- 备选方案：在 `VideoPlayerModel` 轮询 controller 状态。
- 不选原因：增加异步复杂度且难保证时序。

## Risks / Trade-offs

- [风险] 回调热更新时机不当导致短时黑帧或回调抖动。 → 缓解：仅在增强配置变更时触发，并保留 `resetPipeline` 参数精细控制。
- [风险] Debug 门禁与用户持久化值冲突（历史存储为 `.systemML/.opticalFlow`）。 → 缓解：Release 下策略钳制为 `.off`，并在分发处兜底。
- [风险] 多平台编译差异导致条件编译分支报错。 → 缓解：按仓库要求执行 7 目标平台构建矩阵验证。

## Migration Plan

1. 迁回并适配 `VideoPlayerModel` 帧回调逻辑，保留当前字幕翻译能力。
2. 在 `PlayerControlView` ready 阶段接入分辨率可用性同步。
3. 对 `PlayerEnhancementModel` 和 `VideoPlayerModel` 增加 Release 回落逻辑。
4. 执行全平台构建矩阵验证并修正编译问题。
5. 更新 OpenSpec tasks 完成状态。

## Open Questions

- 无阻塞项；默认按“Debug 可见 + Release 强制关闭 VT/光流”执行。
