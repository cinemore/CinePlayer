## 1. macOS 控制面板分组对齐

- [x] 1.1 重构 `ControllerPanelViewMacOS` 顶部控制区：补齐 PiP、画面填充、信息、增强、设置入口，并保留全屏按钮
- [x] 1.2 重构 `ControllerPanelViewMacOS` 底部控制区：补齐 倍速、字幕、音轨、视频轨 业务组

## 2. 播放控制与容器联动

- [x] 2.1 将 macOS 播放控制统一为 快退/播放暂停/快进（按 `PlayerControlConfig` 秒数）
- [x] 2.2 将字幕/设置/增强/音轨/视频轨/倍速入口统一走 `PlayerControlModel.hideContainer()` + 单容器激活逻辑
- [x] 2.3 确认媒体信息卡片入口与遮罩显隐节奏与 iOS 一致

## 3. 验证与回归

- [x] 3.1 执行 AGENTS.md 要求的 7 平台 `xcodebuild` 构建验证
- [ ] 3.2 在 macOS 对照 iOS 交互回归：按钮可见性、点击响应、容器弹出方向与关闭行为
