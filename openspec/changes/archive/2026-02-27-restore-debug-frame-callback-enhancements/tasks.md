## 1. Frame Callback Wiring Recovery

- [x] 1.1 迁回并适配 `VideoPlayerModel` 的增强策略到 `FrameCallbackPolicy/onVideoFrame` 映射逻辑（off/anime4k/systemML/opticalFlow）
- [x] 1.2 恢复 active player 帧回调热更新接口，并将增强模型变更回调绑定到该接口
- [x] 1.3 保留并回归验证字幕翻译配置路径，避免迁移帧回调时引入字幕行为回归

## 2. Runtime Availability And Debug Gating

- [x] 2.1 在 `PlayerControlView` 的 ready 时按视频分辨率同步增强可用性（Anime4K/System VT/Optical Flow）
- [x] 2.2 对 System VT / Optical Flow 增强入口添加 `#if DEBUG` 门禁，Release 下策略钳制为 `off`
- [x] 2.3 校准策略持久化与默认行为，确保 Debug 可见可切换、Release 不可见且不执行 VT/光流路径

## 3. Verification

- [x] 3.1 本地执行 `iphoneos` 与 `iphonesimulator` 目标构建并通过
- [x] 3.2 本地执行 `appletvos` 与 `appletvsimulator` 目标构建并通过
- [x] 3.3 本地执行 `macosx`、`xros`、`xrsimulator` 目标构建并通过
