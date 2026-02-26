## 1. Router Recovery

- [x] 1.1 在 `SubtitleTranslationRouter.applySettings` 增加 `wasNeedsTranslation` 过渡判断
- [x] 1.2 当 `off -> needsTranslation` 时丢弃 `appleTranslatorBox`
- [x] 1.3 为重建路径增加调试日志

## 2. Failure Recovery

- [x] 2.1 在 `translate` 失败路径识别可恢复错误（`CancellationError` / `sessionUnavailable`）
- [x] 2.2 触发受控重建：失效旧 translator、清空 `appleTranslatorBox`、抖动 `desiredApplePair` 重启 session
- [x] 2.3 增加恢复节流，避免连续失败下每行字幕都重建 session

## 3. Verification

- [x] 3.1 构建验证：iOS / iOS Simulator / tvOS / tvOS Simulator / macOS / visionOS / visionOS Simulator
- [x] 3.2 自检代码路径：单语/双语互切不重建，off->on 重建；失败后自动触发一次重建恢复
