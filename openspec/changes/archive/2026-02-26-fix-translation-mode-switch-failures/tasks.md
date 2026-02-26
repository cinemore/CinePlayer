## 1. Failure Observability

- [x] 1.1 为 Apple 翻译请求失败添加路由层日志（from/to + error）
- [x] 1.2 为 Apple TranslationSession prepare/会话不可用添加会话层日志

## 2. Mode Switch Stability

- [x] 2.1 调整 `AppleSubtitleTranslationTaskView`，移除 mode 参与的 pairTaskId，避免翻译模式互切触发 task identity 抖动
- [x] 2.2 调整 `PlayerControlView` 的 task host 绑定，去除对 mode 参数传递

## 3. Verification

- [x] 3.1 运行并通过 7 平台构建：iOS / iOS Simulator / tvOS / tvOS Simulator / macOS / visionOS / visionOS Simulator
- [x] 3.2 自检日志与模式切换路径生效，更新任务勾选状态
