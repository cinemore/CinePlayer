## Why

接入帧回调热更新后，打开播放出现两类回归：  
1) 初始化阶段触发多次增强配置回调，导致反复下发 `off` 配置与引擎 reset；  
2) `CinePlayer` 在 `config.url` 仍为空时提前实例化，底层先消费空 URL 后进入错误态，随后即使补齐配置也可能无法恢复。

## What Changes

- 修复 `resetVideoEnhancementForNewVideoSession` 在会话初始化期间触发多次 runtime 回调的问题。
- 移除 `PlayerControlView` 在 `ready` 时的强制 `applyFrameCallbackConfigurationToActivePlayer(resetPipeline: true)`，避免就绪时额外 pipeline 重置。
- 调整播放器创建时机：仅在 `config.url` 就绪后创建 `CinePlayer`，避免空 URL 初始化。
- 保持增强策略切换后的热更新能力不变。

## Capabilities

### New Capabilities
- `frame-callback-open-regression-fix`: 保证接入帧回调后播放器仍可正常打开，初始化阶段不会触发回调风暴。

### Modified Capabilities
- `all-platform-build-pass`: 修复后继续满足 7 平台构建通过。

## Impact

- `CinePlayer/Player/Model/PlayerEnhancementModel.swift`
- `CinePlayer/Player/Views/PlayerControlView.swift`
- `CinePlayer/Player/Model/VideoPlayerModel.swift`
