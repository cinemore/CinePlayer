## 1. Remove Test Hook

- [x] 1.1 删除 `VideoPlayerModel` 中 `CINEMORE_DEBUG_TEMPORAL_INSERTER` 相关分支
- [x] 1.2 删除 `DebugTemporalRGBFrameInserter` 测试辅助实现与相关依赖
- [x] 1.3 保持现有增强策略的 `#if DEBUG` 编译门禁逻辑不变

## 2. Verification

- [x] 2.1 执行 `iphoneos` 与 `iphonesimulator` 构建并通过
- [x] 2.2 执行 `appletvos` 与 `appletvsimulator` 构建并通过
- [x] 2.3 执行 `macosx`、`xros`、`xrsimulator` 构建并通过
