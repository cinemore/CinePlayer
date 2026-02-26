## 1. Enhancement Model And State Migration

- [x] 1.1 迁移并适配增强策略/参数模型（策略枚举、Anime4K 预设、系统 VT 参数、光流开关）到 `CinePlayer/Player/Model`
- [x] 1.2 在播放器会话生命周期中接入“每视频独立重置”与分辨率/能力门禁更新逻辑

## 2. Enhancement UI Migration

- [x] 2.1 将 `SiderEnhancementView` 从占位实现替换为可交互实现，并绑定迁移后的增强模型
- [x] 2.2 保持 iOS/macOS 侧边栏行为一致并验证增强入口与关闭逻辑

## 3. Anime4K Runtime Migration

- [x] 3.1 迁移 Anime4K runtime 与 shader 资源到 `CinePlayer/Player/Enhancement/Anime4K`
- [x] 3.2 适配运行时依赖（日志、命名空间、路径）并保证编译通过

## 4. System VT And Optical Flow Migration

- [x] 4.1 迁移系统 VT 增强适配层到 `CinePlayer/Player/Enhancement/SystemVideoEnhancement`
- [x] 4.2 迁移光流补帧适配层与 Metal shader 到 `CinePlayer/Player/Enhancement/OpticalFlowInterpolation`

## 5. Frame Callback Pipeline Integration

- [x] 5.1 将增强策略接入 `VideoPlayerModel` 帧回调配置构建逻辑（off/anime4k/systemML/opticalFlow）
- [x] 5.2 实现播放中热更新入口并在增强参数变化时应用到活动播放器

## 6. Verification

- [x] 6.1 运行 `iphoneos` 构建验证
- [x] 6.2 运行 `iphonesimulator` 构建验证
- [x] 6.3 运行 `appletvos` 构建验证
- [x] 6.4 运行 `appletvsimulator` 构建验证
- [x] 6.5 运行 `macosx` 构建验证
- [x] 6.6 运行 `xros` 构建验证
- [x] 6.7 运行 `xrsimulator` 构建验证
