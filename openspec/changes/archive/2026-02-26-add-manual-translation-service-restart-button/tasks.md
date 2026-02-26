## 1. Router Manual Restart

- [x] 1.1 在 `SubtitleTranslationRouter` 增加手动重启 API
- [x] 1.2 手动重启复用会话重建序列（invalidate + 清理 box + pair 抖动）
- [x] 1.3 为手动重启增加日志（含忽略路径）

## 2. UI Wiring

- [x] 2.1 在 `VideoPlayerModel` 暴露手动重启翻译服务方法
- [x] 2.2 在 `EmbeddedSubtitleView` 增加“重启翻译服务”按钮并接入模型方法

## 3. Verification

- [x] 3.1 构建验证：iOS / iOS Simulator / tvOS / tvOS Simulator / macOS / visionOS / visionOS Simulator
- [x] 3.2 自检路径：翻译开启点击按钮可重建；翻译关闭点击按钮安全忽略
