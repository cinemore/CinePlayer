## ADDED Requirements

### Requirement: Session reset SHALL not trigger frame callback reconfiguration storm
播放器在新会话初始化重置增强设置时，MUST 不得触发多次 runtime frame callback 下发。

#### Scenario: Open playback after session reset
- **WHEN** 打开新视频并执行增强配置会话重置
- **THEN** 系统 MUST 不发生连续的 `off` 回调重配/引擎 reset 风暴，且播放可正常进入 ready/playing

### Requirement: Ready state SHALL not force pipeline reset for enhancement off path
当策略为 `off` 时，播放器 ready 阶段 MUST 不强制触发额外 `resetPipeline` 重配。

#### Scenario: Player enters ready with enhancement off
- **WHEN** 播放器进入 ready 且增强策略为 off
- **THEN** 系统 MUST 不额外执行强制 frame callback reset pipeline

### Requirement: Player surface SHALL not instantiate CinePlayer before URL is ready
播放器界面 MUST 在 `config.url` 可用后再创建 `CinePlayer`，避免空 URL 初始化底层播放器。

#### Scenario: Enter player page with initial empty config URL
- **WHEN** 用户进入播放页且 `config.url == nil`
- **THEN** 系统 MUST 不创建 `CinePlayer` 实例
- **AND** 在 `open()` 完成并写入有效 URL 后，系统 MUST 正常创建并启动播放器
