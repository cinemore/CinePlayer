## 1. Playback Language-Pack Flow Parity

- [x] 1.1 在 `PlayerControlView` 增加播放中语言包状态检测（基于 runtime 语言对 + 播放状态），缺失时暂停并弹窗
- [x] 1.2 新增语言包弹窗内容容器并对齐 `cinemore-apple` 尺寸策略（macOS: 420x480 / 420x280）
- [x] 1.3 将语言包下载弹窗入口从字幕面板迁移为播放器自动触发，移除字幕面板“下载/管理”按钮与相关 sheet

## 2. Translation Reliability Fix

- [x] 2.1 修复 `SubtitleTranslationRouter` 的 Apple 分支错误处理，移除吞错返回原文逻辑
- [x] 2.2 调整 `AppleSubtitleTranslationLanguagePage` 的 translationTask 状态更新时机，避免任务期间重建导致不稳定

## 3. Verification

- [x] 3.1 运行并通过 7 平台构建：iOS / iOS Simulator / tvOS / tvOS Simulator / macOS / visionOS / visionOS Simulator
- [x] 3.2 自检改动与 OpenSpec 任务一致并勾选完成项
