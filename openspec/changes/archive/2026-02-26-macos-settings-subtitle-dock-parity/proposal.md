## Why

当前播放器在 macOS 的播放设置、字幕面板和文件打开行为上与 Cinemore 参考实现不一致，导致用户操作路径和预期不匹配。该偏差已经在真实测试中复现，必须立即收敛到一致行为。

## What Changes

- 对齐 macOS `播放设置` 面板到 Cinemore：移除“长按倍速”项，保留“左键后退/右键前进”选择器，并移除不该出现的字幕设置与提示文案。
- 对齐 iOS/macOS 字幕面板结构与样式到 Cinemore，包括分段、行样式与交互层级。
- 将“字幕调整”做为硬性可用功能，确保提供可操作的字幕偏移调整能力而非占位。
- 修复 macOS 从 Dock 图标拖入媒体文件打开时重复创建播放器窗口的问题，保证单次打开只激活一个播放器窗口。

## Capabilities

### New Capabilities
- `settings-and-subtitle-parity`: 统一 iOS/macOS 播放设置与字幕面板为 Cinemore 一致业务布局和交互。
- `macos-single-window-file-open`: 规范 macOS 文件打开事件处理链，避免拖拽打开触发重复窗口。

### Modified Capabilities
- None

## Impact

- 受影响代码：播放器侧边面板（设置/字幕）、播放器控制模型、macOS App 启动与 URL/file open 路径。
- 不引入新三方依赖，仅调整现有 SwiftUI 视图与事件分发逻辑。
- 需要回归验证 iOS/macOS UI 一致性与 macOS Dock 拖拽打开行为。
