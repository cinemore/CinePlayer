## Context

日志显示在 strategy=off 时仍连续触发 `makeFrameCallbackConfiguration` 和 Anime4K reset（计数持续增长）。该模式与 `resetVideoEnhancementForNewVideoSession` 内多次属性赋值一致，且每次 didSet 都会触发 runtime 回调。  
同时，纯播放器与 cinemore 的关键差异是：纯播放器会在 URL 未就绪时先创建 `CinePlayer`，导致底层先按空 URL 打开并进入错误态。

## Goals / Non-Goals

**Goals:**
- 阻断会话初始化阶段的重复 runtime 回调。
- 保留用户主动修改增强配置时的热更新路径。
- 避免 ready 时重复重置 pipeline。
- 避免 URL 未就绪时提前创建底层播放器。

**Non-Goals:**
- 不重写增强策略模型。
- 不调整 Anime4K / VT / 光流算法实现。

## Decisions

1. 在 `resetVideoEnhancementForNewVideoSession` 内临时开启 `suppressRuntimeCallback`。
- 以最小改动阻断初始化批量赋值产生的回调风暴。

2. 移除 `PlayerControlView` ready 阶段的强制 frame callback 重置。
- 避免播放器刚 ready 时额外 reset pipeline，降低打开阶段不稳定性。

3. `PlayerControlView` 仅在 `config.url != nil` 时渲染 `CinePlayer`。
- 保证底层 `PlayerController` 初始化时已拿到有效 URL，消除空 URL 启动路径。

## Risks / Trade-offs

- [风险] 过度抑制导致某些初始化变更未即时同步到 active player。 → 缓解：`open()` 仍会显式 `configureFrameCallback`，用户后续修改仍经 didSet 热更新。
- [风险] 首帧前会有一个仅黑底占位状态。 → 缓解：保持现有 loading overlay，不改变交互与提示语义。
