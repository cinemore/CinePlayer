## Why

当前 iOS 播放器控制层与 Cinemore iOS 参考实现在布局、按钮分组和操作节奏上仍不一致，且未在进入播放器时自动横屏。用户已要求按 Cinemore 的方式完成 iOS 控制 UI 与交互对齐，并明确了保留与排除项。

## What Changes

- 重构 iOS 控制面板为与 Cinemore 一致的竖屏/横屏双布局与按钮分组结构。
- 增加业务按钮组并接入对应交互：关闭、PiP、画面填充、旋转、快退/快进、播放/暂停、音轨、视频轨、倍速、字幕、设置、增强、媒体信息入口。
- 新增字幕侧栏（含内嵌字幕轨道选择与本地字幕导入能力），并显式移除“从文件源导入”入口。
- 显式不提供“换源”和“剧集列表”按钮与对应侧栏。
- iPhone 在进入播放器时自动横屏，退出播放器时恢复竖屏；旋转按钮保持与参考一致的横竖切换行为。

## Capabilities

### New Capabilities
- `ios-control-layout-business-parity`: iOS 控制面板布局与按钮分组对齐 Cinemore，按保留/排除项实现业务按钮行为。
- `ios-player-orientation-parity`: iPhone 打开播放器自动横屏、关闭恢复竖屏，且支持控制面板内旋转切换。
- `ios-subtitle-panel-parity`: iOS 字幕面板提供内嵌轨道切换与本地字幕导入，移除“从文件源导入”入口。

### Modified Capabilities
- 无

## Impact

- 影响 iOS 控制层视图与按钮组件：`CinePlayer/Player/Components/ControllerPanelViewIOS.swift` 及相关 UI 组件。
- 扩展侧栏容器与状态模型：`CinePlayer/Player/SiderView/*`、`CinePlayer/Player/Model/PlayerControlModel.swift`。
- 增加 iOS 方向锁控制能力：`CinePlayer/CinePlayerApp.swift` 与 `CinePlayer/Player/UICommon/PlatformServices.swift`。
- 新增字幕侧栏与本地字幕导入相关视图。
