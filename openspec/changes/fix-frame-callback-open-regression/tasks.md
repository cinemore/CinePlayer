## 1. Root Cause Containment

- [x] 1.1 在 `resetVideoEnhancementForNewVideoSession` 内抑制 runtime 回调，阻断初始化回调风暴
- [x] 1.2 移除 ready 阶段强制 `resetPipeline` 的 frame callback 重配
- [x] 1.3 调整 `PlayerControlView`：仅在 `config.url` 就绪后创建 `CinePlayer`，避免空 URL 初始化

## 2. Verification

- [x] 2.1 执行 `iphoneos` 与 `iphonesimulator` 构建并通过
- [x] 2.2 执行 `appletvos` 与 `appletvsimulator` 构建并通过
- [x] 2.3 执行 `macosx`、`xros`、`xrsimulator` 构建并通过
