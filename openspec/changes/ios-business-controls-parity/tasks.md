## 1. OpenSpec 与状态模型

- [x] 1.1 扩展 `PlayerControlModel`：增加字幕/设置/增强/媒体信息显示状态，并纳入 `isSiderContainerShow` 与 `hideContainer()`
- [x] 1.2 增加 iOS 方向锁能力（AppDelegate + PlatformServices 封装），支持横竖切换与状态读取

## 2. iOS 控制面板对齐

- [x] 2.1 重构 `ControllerPanelViewIOS` 为 Cinemore 风格 portrait/landscape 双布局（标题行、顶部操作区、底部操作区）
- [x] 2.2 增加 iOS 业务按钮组：PiP、画面填充、旋转、字幕、设置、增强、媒体信息，并去掉换源/剧集列表入口
- [x] 2.3 维持快退/快进、播放暂停、音轨/视频轨/倍速的 Cinemore 风格分组与交互

## 3. 侧栏与字幕能力

- [x] 3.1 扩展 `SiderView`：新增字幕/设置/增强容器，保留音轨/视频轨/倍速容器
- [x] 3.2 实现 `SiderSubtitleView`（内嵌字幕开关/轨道选择 + 本地字幕导入）
- [x] 3.3 确保字幕外部导入不出现“从文件源导入”入口

## 4. 播放器方向与回归

- [x] 4.1 在 iPhone 打开播放器时自动横屏、关闭时恢复竖屏，并与旋转按钮联动
- [x] 4.2 按 AGENTS.md 执行 7 平台 `xcodebuild` 构建验证
- [ ] 4.3 在 iOS（iPhone 竖/横、iPad）做与 Cinemore 的 UI 布局与交互对照回归
