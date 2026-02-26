## Why

当前 iOS 与 macOS 的侧边面板样式仍与 Cinemore 参考实现不一致，尤其在媒体信息、增强、设置、字幕四个面板上差异明显。用户已将该对齐作为硬性要求，需确保两端使用与 Cinemore 一致的 UI 结构与交互节奏。

## What Changes

- 对齐 iOS + macOS 的媒体信息卡片样式到 Cinemore：分轨道分组展示、卡片化信息块、统一关闭入口。
- 对齐增强面板样式到 Cinemore：使用分组 Form 样式与实验能力区块，并移除“画面填充”项。
- 对齐设置面板样式到 Cinemore：采用“播放设置”结构与分段配置行视觉。
- 对齐字幕面板样式到 Cinemore：改为“内封字幕 / 外部字幕 / 字幕调整”分段布局。
- 保持纯播放器边界：不接入 Cinemore 业务 API，不提供“从文件源导入”等外部业务入口。

## Capabilities

### New Capabilities
- `ios-macos-media-info-card-style-parity`: iOS 与 macOS 媒体信息卡片使用 Cinemore 同款分组与卡片式布局。
- `ios-macos-enhancement-panel-style-parity`: iOS 与 macOS 增强面板使用 Cinemore Form 风格，且不显示画面填充项。
- `ios-macos-setting-panel-style-parity`: iOS 与 macOS 设置面板使用 Cinemore 播放设置样式结构。
- `ios-macos-subtitle-panel-style-parity`: iOS 与 macOS 字幕面板使用 Cinemore 分段样式（内封/外部/调整）。

### Modified Capabilities
- 无

## Impact

- 主要影响文件：
  - `CinePlayer/Player/Components/PlayerMediaInfoCardView.swift`
  - `CinePlayer/Player/SiderView/SiderEnhancementView.swift`
  - `CinePlayer/Player/SiderView/SiderSettingView.swift`
  - `CinePlayer/Player/SiderView/SiderSubtitleView.swift`
- 可能新增字幕面板子视图组件以匹配 Cinemore 分段结构。
- 需执行 7 平台 `xcodebuild` 验证，确保样式重构不引入跨平台编译回归。
