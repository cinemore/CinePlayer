## ADDED Requirements

### Requirement: Debug temporal test hook SHALL be removed from playback path
系统 MUST 不再通过 `CINEMORE_DEBUG_TEMPORAL_INSERTER` 环境变量切换帧回调测试分支，播放流程应仅走正式增强策略路径。

#### Scenario: Build and run in Debug without test hook
- **WHEN** Debug 构建运行播放器
- **THEN** 系统 MUST 不读取 `CINEMORE_DEBUG_TEMPORAL_INSERTER` 作为帧回调行为切换条件
- **AND** 系统 MUST 按当前增强策略（off/anime4k/systemML/opticalFlow）构建帧回调
