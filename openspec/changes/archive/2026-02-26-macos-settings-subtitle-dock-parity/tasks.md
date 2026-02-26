## 1. 播放设置与字幕面板对齐

- [x] 1.1 按 Cinemore 结构重写 macOS 播放设置分组：仅保留左键后退/右键前进秒数选择器，移除长按倍速、字幕设置和提示文案
- [x] 1.2 对齐 iOS/macOS 字幕面板分段与行样式到 Cinemore（内封字幕、外部字幕、字幕调整）
- [x] 1.3 实现并接通“字幕调整”可操作控件，确保偏移修改可生效

## 2. macOS 文件打开链路修复

- [x] 2.1 排查并修复 Dock 拖拽打开时重复开窗问题，保证同一打开动作仅触发一次播放器窗口创建/激活
- [x] 2.2 覆盖 macOS 平台 `onOpenURL` 与 AppDelegate 打开事件路径，避免重复消费同一 URL

## 3. 回归验证

- [x] 3.1 运行 7 平台构建（iOS/iOS Simulator/tvOS/tvOS Simulator/macOS/visionOS/visionOS Simulator）
- [x] 3.2 手工回归：验证 macOS 播放设置项、字幕面板样式、字幕调整能力和 Dock 拖拽单窗口行为
