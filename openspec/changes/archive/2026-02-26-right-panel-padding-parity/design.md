## Context

当前右侧弹出容器（trailing）在底部留白与顶部、右侧不一致，用户在“播放设置”面板中可明显感知。该容器被设置、字幕、增强、音轨、视频轨等右侧面板复用；倍速面板使用 bottom 方向并有独立底部留白策略。

## Goals / Non-Goals

**Goals:**
- 让 trailing 方向容器上、右、下三边距保持一致。
- 仅做最小改动，不改变右侧面板功能与交互。
- 明确排除对倍速面板底部留白的影响。

**Non-Goals:**
- 不重构设置页 `Form` 结构。
- 不调整 bottom 方向容器动画、尺寸与间距。
- 不改动播放器控制逻辑或业务状态模型。

## Decisions

- 决策 1：在 `SiderContanierView` 中仅调整 trailing 方向容器高度/边距计算，避免在 `SiderSettingView` 做页面级补丁。
  - 原因：问题表现出现在设置页，但来源是右侧容器通用布局；在容器层修正可一次性保证所有右侧弹层边距一致。
  - 备选：只改 `SiderSettingView` 的内部 `Form`/`frame`。该方案只能修一个面板，且容易引入与其他面板样式不一致，因此不采用。
- 决策 2：保留 `SiderPlaybackSpeedView` 现有底部大留白。
  - 原因：倍速面板属于 bottom 方向，用户明确要求保持现状；实现上通过不修改 bottom 分支与 `SiderPlaybackSpeedView` 达成。

## Risks / Trade-offs

- [Risk] 不同平台 safe area 行为差异可能导致 trailing 面板高度轻微变化。→ Mitigation：改动限制在 trailing 分支，并通过多平台构建验证回归风险。
- [Trade-off] 选择容器级统一修复会同时影响所有右侧面板，而非仅设置页。→ Mitigation：该影响符合“右侧弹出面板边距统一”的目标，且是可预期的一致性修复。
