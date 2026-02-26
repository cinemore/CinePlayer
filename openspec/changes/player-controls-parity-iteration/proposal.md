## Why

当前 CinePlayer 的播放器控件虽已从 cinemore-apple 移植，但控件布局、快捷键/手势、Toast 与加载错误反馈、系统能力（PiP、Now Playing 等）与参考实现尚未完全一致。需要在保持「纯播放器」边界、明确排除业务功能的前提下，将各平台体验对齐到 Cinemore 参考实现，并补充轻量多集能力与项目 README 说明。

## What Changes

- 明确「做/不做」清单：保留并补齐与 Cinemore 一致的布局、手势、Toast、系统能力；显式排除字幕下载、云盘多线路、详情页/历史、Anime4K 等业务或重度功能。
- 按平台（iPhone 竖/横、iPad、macOS、tvOS、visionOS）建立控件与手势的对照矩阵，并据此重构各平台 ControllerPanel 与 PlayerControlView 结构，使按钮布局、渐变背景、显隐节奏与参考一致。
- 补齐 SiderView 与 PlayerMaskModel 的联动（遮罩点击关闭、按设备/方向决定侧边或底部弹出），保持仅音轨/视频轨/倍速三类面板，不引入业务侧边栏。
- 统一手势与快捷键：iOS/tvOS 以参考为准并固化为可配置默认值；macOS 增加键盘控制（空格、方向键、Esc）与鼠标移动唤起控制层。
- 扩展 PlayerToast 类型并接回网络/缓冲回调，使加载与错误反馈达到与 Cinemore 等价的级别。
- 在纯播放器中接入 PiP 按钮、iOS 横竖屏锁定按钮、系统 Now Playing 与 Remote Command Center（无业务依赖的抽象）。
- 引入轻量 PlayerPlaylist 模型（仅当前列表与 index），支撑 tvOS 上一集/下一集及后续简单多集 UI。
- 根据当前已实现功能更新 README-zh.md 中的特性列表与使用说明。

## Capabilities

### New Capabilities

- `control-layout-parity`: 各平台控件布局与分平台 ControllerPanel 与 Cinemore 参考对齐，无业务依赖。
- `gesture-shortcut-parity`: 手势与快捷键与参考一致（含 iOS/tvOS 手势、macOS 键盘与鼠标移动、可配置默认值）。
- `toast-loading-parity`: Toast 类型与加载/错误界面与 Cinemore 等价，仅依赖 SDK 状态。
- `system-capabilities`: PiP、iOS 横竖屏按钮、Now Playing / Remote Command Center 的纯播放器版接入。
- `light-playlist`: 轻量 PlayerPlaylist 模型与 tvOS 上一集/下一集支持，无详情页依赖。
- `readme-features`: 根据当前功能更新 README-zh.md 特性与使用说明。

### Modified Capabilities

- 无（本变更仅新增能力与实现层面的对齐，不修改既有 spec 的 REQUIREMENTS）。

## Impact

- 影响 `CinePlayer/Player/` 下视图、模型与手势层：新增或调整 ControllerPanel 分平台视图、PlayerControlView 结构、SiderView 行为、GestureController 与 macOS 键盘/鼠标逻辑。
- 扩展 `PlayerToastModel` / `PlayerToast` 及 PlayerControlView 中的网络/缓冲回调绑定。
- 新增轻量 `PlayerPlaylist` 及与 SessionStore 的集成；新增无业务依赖的 Remote Command / Now Playing 服务。
- 更新 `README-zh.md` 以反映当前功能特性与多平台支持。
