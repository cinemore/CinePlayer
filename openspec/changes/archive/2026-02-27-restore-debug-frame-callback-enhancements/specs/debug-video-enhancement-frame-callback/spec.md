## ADDED Requirements

### Requirement: Player SHALL map enhancement strategy to frame callback policy
播放器运行时 MUST 将增强策略映射为对应的 `FrameCallbackPolicy` 与视频帧回调处理器。

#### Scenario: Strategy is switched during playback
- **WHEN** 用户在播放中切换增强策略（`off/anime4k/systemML/opticalFlow`）
- **THEN** 播放器 MUST 将策略映射到对应回调模式（`disabled/asyncSingle/temporal`）并应用到 active controller

### Requirement: Enhancement config changes SHALL hot-update active player callback settings
增强参数变更（包含 Anime4K、System VT、光流相关字段）后，运行时 MUST 热更新 active player 的 frame callback 配置。

#### Scenario: Runtime enhancement parameter changes
- **WHEN** 用户修改增强配置（如 preset、scale、插帧参数、A/B 对比）
- **THEN** 系统 MUST 调用 active controller 的 frame callback 配置更新接口，并对后续帧生效

### Requirement: System VT and optical-flow enhancement SHALL be debug-gated
System VT 与光流补帧在 pure player 中 MUST 仅在 Debug 构建可见可用；Release MUST 回落为关闭状态。

#### Scenario: Release build loads stored non-off strategy
- **WHEN** Release 构建启动时读取到持久化增强策略为 `systemML` 或 `opticalFlow`
- **THEN** 运行时 MUST 将策略钳制回 `off`，且不得启用对应 frame callback 路径

#### Scenario: Debug build opens enhancement panel
- **WHEN** Debug 构建打开增强设置面板
- **THEN** 界面 MUST 显示并允许切换 System VT 与光流补帧配置
