## Context

CinePlayer 已完成首轮 SDK 接入与控件迁移（setup-sdk-and-port-player-controls），但当前 PlayerControlView 为精简版：控件布局、分平台面板结构、手势/快捷键细节、Toast 与加载错误反馈、系统能力（PiP、Now Playing 等）与 cinemore-apple 参考实现仍有差距。用户要求在各平台上与 Cinemore 体验一致，同时保持纯播放器边界（不引入字幕下载、云盘、详情页等业务功能），并增加轻量多集能力与 README 更新。

约束：
- 仅使用 PlayerSessionStore、VideoPlayerModel、PlayerMaskModel、精简 PlayerControlModel，不依赖 DetailPageModel、PlayerParams、业务 API。
- 参考实现为 cinemore-apple 的 PlayerControlView、ControllerPanelView*、GestureController*、SiderView、PlayerToast*。
- 显式排除：详情页/历史、云盘多线路、字幕下载与导入、Anime4K/系统 ML 增强等。

## Goals / Non-Goals

**Goals:**
- 控件布局与 Cinemore 对齐：分平台 ControllerPanel、按钮分组、渐变背景、显隐节奏一致。
- 手势与快捷键对齐：iOS/tvOS 手势与参考一致并固化为可配置默认值；macOS 键盘与鼠标移动唤起控制层。
- Toast 与加载/错误体验达到与 Cinemore 等价级别（网络状态、错误文案、大卡片样式）。
- 接入 PiP、iOS 横竖屏按钮、Now Playing / Remote Command Center（无业务依赖的抽象）。
- 引入轻量 PlayerPlaylist，支撑 tvOS 上一集/下一集及后续简单多集 UI。
- 根据实现更新 README-zh.md 特性与使用说明。

**Non-Goals:**
- 不引入字幕下载、文件源导入字幕、翻译服务、语言包检测。
- 不引入云盘换源、多线路、会员/付费逻辑。
- 不引入详情页、剧集数据模型、观看历史上报、推荐。
- 不引入 Anime4K、系统 ML 超分/补帧、光流补帧、AB 对比等增强及设置面板。

## Decisions

### Decision 1: 分平台 ControllerPanel 与参考布局严格对照
- 选择：新建 ControllerPanelViewIOS / MacOS / TvOS / Vision，按参考实现的竖屏/横屏、iPad、macOS 等布局与渐变实现，PlayerControlView 只负责承载 CinePlayer、遮罩、手势层、Toast 与各平台面板的挂载。
- 原因：用户要求按钮布局和快捷键等控制与 Cinemore 完全一致。
- 备选：保持当前单一体 controlOverlay。无法满足分平台与参考的逐项对齐。

### Decision 2: 手势/快捷键配置用轻量 PlayerControlConfig
- 选择：引入 PlayerControlConfig（skipForwardSeconds、skipBackwardSeconds、longPressSpeedUpEnabled 等），由 SessionStore 或 View 层提供默认值；GestureController 与 macOS 键盘逻辑读取该配置，不依赖 PlaySettingModel。
- 原因：与参考行为一致的同时保持无业务依赖，且为将来设置页预留扩展点。
- 备选：继续写死 10s 与长按 2x。无法满足“与 Cinemore 一致”的可配置体验。

### Decision 3: SiderView 仅保留音轨/视频轨/倍速，补齐联动与方向
- 选择：保持三类面板，不新增设置/增强/换源/字幕面板；补齐点击遮罩关闭时调用 PlayerMaskModel、按设备与方向决定侧边或底部弹出。
- 原因：proposal 明确排除业务侧边栏，但交互细节（遮罩、弹出方向）需与参考一致。
- 备选：新增“纯播放器设置”面板。暂不纳入，避免范围蔓延。

### Decision 4: 网络/缓冲反馈仅依赖 CinePlayerSDK 回调
- 选择：扩展 PlayerToast 枚举与 UI，在 PlayerControlView 中绑定 onNetworkStatusChanged、onNetworkError、onBufferingStatusChanged，不依赖 Cinemore 网络层或业务错误码。
- 原因：Toast 与加载/错误体验为必做项，且 SDK 已提供足够状态。
- 备选：仅保留简单“播放错误”文案。不符合“等价级别”目标。

### Decision 5: Remote Command / Now Playing 抽象为纯播放器服务
- 选择：从参考实现提炼与 MPRemoteCommandCenter、Now Playing Info Center 交互的部分，新建 PurePlayerRemoteCommandService；标题/封面从 PlayerSessionStore.currentSource 与 VideoPlayerModel 推导。
- 原因：用户将系统能力列为必做，且需与 Cinemore 一致的耳机/控制中心体验。
- 备选：不接入。与用户确认的必做项冲突。

### Decision 6: PlayerPlaylist 仅承载列表与 index
- 选择：PlayerPlaylist 仅包含当前源列表（如 [PlayerSource]）与 currentIndex，提供 hasPrevious/hasNext 与切换方法；tvOS 上一集/下一集与手势 pageUp/pageDown 绑定到此模型。
- 原因：支持轻量多集与 tvOS 上一集/下一集，且不依赖详情页或业务 API。
- 备选：不做多集。与用户选择的“轻量播放列表”冲突。

## Risks / Trade-offs

- [风险] 分平台面板与参考逐项对照工作量大，易遗漏细节。
  -> Mitigation：先建立平台×区域对照矩阵，再按矩阵逐项实现并回归。

- [风险] 参考实现依赖 AppDelegate/Device 等全局状态，纯播放器需用替代方式（如 Environment 或 Config）实现旋转/横竖屏锁定。
  -> Mitigation：iOS 横竖屏按钮仅控制当前播放器展示方向或系统方向锁定，使用平台推荐 API，不复制业务全局锁。

- [风险] Remote Command 与 Now Playing 在无剧集/海报时展示较简陋。
  -> Mitigation：标题用 currentSource.displayName 或 URL 文件名，封面可选留空或占位，文档中说明为纯播放器行为。

## Migration Plan

1. 完成 OpenSpec 全部产物（proposal/design/specs/tasks），冻结范围。
2. 建立对照矩阵与显式排除清单，作为实现与验收依据。
3. 实现 control-layout-parity（分平台 ControllerPanel、PlayerControlView 重组）。
4. 实现 gesture-shortcut-parity（含 macOS 键盘与 MouseTrackingView）。
5. 实现 light-playlist 与 tvOS 上一集/下一集绑定。
6. 实现 toast-loading-parity（Toast 类型扩展与网络/缓冲回调）。
7. 实现 system-capabilities（PiP、横竖屏按钮、PurePlayerRemoteCommandService）。
8. 实现 readme-features（更新 README-zh.md）。
9. 全平台构建与体验回归，按 AGENTS.md 执行 xcodebuild。

回滚：按任务或能力块提交，必要时可回退单块；未全部验收前不归档变更。

## Open Questions

- 窗口锁定（macOS WindowLevelButton）是否在本变更中实现，或留作后续增强。
- 轻量播放列表的入口（如从打开多个文件生成列表）是否在本变更中提供 UI，或仅提供模型与 tvOS 遥控绑定。
