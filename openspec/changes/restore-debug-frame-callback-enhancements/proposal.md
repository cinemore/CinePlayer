## Why

当前纯播放器仓库虽然已包含 Anime4K / System VT / 光流补帧相关代码文件，但帧回调主链路（策略映射、播放器热更新、分辨率可用性同步）在 `VideoPlayerModel` 中缺失，导致除 Anime4K 外的增强能力不可用。需要把 `cinemore-apple` 已验证实现迁回，并保持仅 Debug 可见。

## What Changes

- 迁移并接入 `VideoPlayerModel` 的帧回调配置构建逻辑：
  - `off` -> `disabled`
  - `anime4k` -> `asyncSingle`
  - `systemML` -> `asyncSingle/temporal`
  - `opticalFlow` -> `temporal`
- 接入运行时热更新：增强配置变化时，更新 active player 的 frame callback（可选 reset pipeline）。
- 在播放器 ready 阶段根据视频分辨率更新增强可用性（Anime4K/System VT/Optical Flow）。
- 用 `#if DEBUG` 对 System VT 与 Optical Flow 的入口进行门禁：
  - Debug 构建可见并可切换。
  - Release 构建默认回退为 `off`，不启用 VT/光流帧回调路径。

## Capabilities

### New Capabilities
- `debug-video-enhancement-frame-callback`: 在纯播放器中恢复并稳定接入增强策略到帧回调管线，并限制 VT/光流为 Debug 可见可用。

### Modified Capabilities
- `all-platform-build-pass`: 增强接线变更后，继续满足 iOS/tvOS/macOS/visionOS 全平台构建通过要求。

## Impact

- 主要影响文件：
  - `CinePlayer/Player/Model/VideoPlayerModel.swift`
  - `CinePlayer/Player/Views/PlayerControlView.swift`
  - `CinePlayer/Player/Model/PlayerEnhancementModel.swift`
- 运行时影响：新增 frame callback 热更新路径；增强策略切换时会触发播放器 frame callback 配置更新。
- 平台影响：非 tvOS 路径新增/恢复增强接线；Release 下屏蔽 VT/光流能力入口。
