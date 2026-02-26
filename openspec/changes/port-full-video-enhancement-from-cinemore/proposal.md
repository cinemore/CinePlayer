## Why

当前 `CinePlayer` 的增强面板仅有样式占位，没有实际视频增强能力。用户希望把 `cinemore-apple` 已验证的全量增强能力（Anime4K、系统 VT、光流补帧）迁入纯播放器，降低实现风险并保持行为一致。

## What Changes

- 将 `cinemore-apple` 的视频增强实现迁移到 `CinePlayer/Player` 范围内，包括：
  - Anime4K 单帧增强（含预设、输出分辨率、A/B 对比）
  - 系统 VT 增强（超分、插帧、参数配置与可用性门禁）
  - 光流补帧（时域帧插值）
- 将增强配置与状态管理从占位实现升级为可运行实现，并与当前播放器生命周期对齐（每视频独立、切源重置）。
- 将增强面板从占位文案升级为可交互控制面板，行为与 `cinemore-apple` 保持一致。
- 将增强策略接入 `CinePlayerSDK` 的 `frameCallback` 管线，并支持播放中热更新配置。
- 引入增强所需的本地 Metal Shader/资源与纯播放器内适配层，不引入业务侧数据模型或接口。

## Capabilities

### New Capabilities
- `video-enhancement-controls`: 提供完整增强设置 UI 与状态模型，覆盖 Anime4K、系统 VT、光流补帧及其参数。
- `video-enhancement-frame-callback-pipeline`: 将增强策略接入并驱动 `frameCallback`（`asyncSingle`/`temporal`）与运行时热更新。
- `video-enhancement-engines`: 在纯播放器目录内提供 Anime4K、系统 VT、光流补帧适配实现与运行时资源。

### Modified Capabilities
- None.

## Impact

- 主要影响目录：`CinePlayer/Player/Model`、`CinePlayer/Player/SiderView`、`CinePlayer/Player/Views`、新增 `CinePlayer/Player/Enhancement`。
- 需要新增/迁移 Metal shader 与增强运行时代码，并在多平台编译下保持条件编译正确。
- 播放器运行时将新增 frame callback 配置切换路径与增强状态同步逻辑。
