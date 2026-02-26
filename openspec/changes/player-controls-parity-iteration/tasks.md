## 1. 范围与对照

- [x] 1.1 编写显式排除清单（字幕下载、云盘、详情页、Anime4K 等）并确认与 proposal/design 一致
- [x] 1.2 建立平台×区域对照矩阵（iOS 竖/横、iPad、macOS、tvOS、visionOS × 顶部/底部/侧边/手势/Toast），标出保留/删除/需重构项

## 2. 控件布局与分平台面板

- [x] 2.1 引入轻量 PlayerControlConfig（skip 秒数、长按加速开关等）并由 SessionStore 或等效处提供默认值
- [x] 2.2 新建 ControllerPanelViewIOS，对照参考实现实现竖屏/横屏布局、渐变背景与按钮分组，仅依赖 PlayerSessionStore/VideoPlayerModel/PlayerMaskModel/PlayerControlModel
- [x] 2.3 新建 ControllerPanelViewMacOS，对照参考实现实现布局与按钮分组
- [x] 2.4 新建 ControllerPanelViewTvOS 与 ControllerPanelViewVision，对照参考实现实现布局
- [x] 2.5 重构 PlayerControlView：承载 CinePlayer、遮罩、手势层、Toast，将控制面板委托给各平台 ControllerPanelView

## 3. 侧边面板与手势/快捷键

- [x] 3.1 补齐 SiderView：点击遮罩关闭时调用 PlayerMaskModel，按设备与方向决定侧边或底部弹出
- [x] 3.2 对齐 GestureControllerIOS 与参考行为，使用 PlayerControlConfig 默认值
- [x] 3.3 对齐 GestureControllerTVOS 与参考行为，使用 PlayerControlConfig 默认值
- [x] 3.4 在 macOS 上实现键盘控制（空格、方向键、Esc）与 MouseTrackingView，使用 PlayerControlConfig

## 4. 轻量播放列表

- [x] 4.1 定义 PlayerPlaylist 模型（当前源列表、currentIndex、hasPrevious/hasNext、切换方法），无业务依赖
- [x] 4.2 将 PlayerPlaylist 与 PlayerSessionStore 或播放入口集成，支持从多源打开时生成列表
- [x] 4.3 在 tvOS 上将遥控器上一集/下一集（如 pageUp/pageDown）绑定到 PlayerPlaylist

## 5. Toast 与加载/错误体验

- [x] 5.1 扩展 PlayerToast 枚举与 PlayerToastModel（networkConnecting、networkRetrying、networkSwitchingURL、networkError、networkStable 等）
- [x] 5.2 在 PlayerToastView 中实现上述网络与错误状态的 UI，风格与参考一致
- [x] 5.3 在 PlayerControlView 中绑定 onNetworkStatusChanged、onNetworkError、onBufferingStatusChanged，驱动 Toast 与加载/错误大卡片

## 6. 系统能力

- [x] 6.1 在控制面板中增加 PiP 按钮（iOS/macOS），行为与参考一致
- [x] 6.2 在控制面板中增加 iOS 横竖屏/旋转锁定按钮，不依赖业务全局状态
- [x] 6.3 从参考实现提炼并实现 PurePlayerRemoteCommandService（MPRemoteCommandCenter、Now Playing），标题/封面仅从 PlayerSessionStore 与 VideoPlayerModel 推导
- [x] 6.4 在 PlayerControlView 的 onAppear/onDisappear 及进度/速率/状态变化时激活与刷新 Remote Command 与 Now Playing

## 7. README 与验证

- [x] 7.1 根据当前实现更新 README-zh.md：特性列表、多平台支持、构建与运行说明
- [x] 7.2 按 AGENTS.md 执行全平台 xcodebuild 构建验证
- [ ] 7.3 在各平台上与 Cinemore App 做控件布局、手势/快捷键、Toast 与加载/错误体验的对照回归
