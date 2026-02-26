## 1. Subtitle Translation Runtime

- [x] 1.1 新增 Apple 字幕翻译基础设施文件（runtime/router/apple translator/task host），并完成条件编译与可用性声明
- [x] 1.2 在 `VideoPlayerModel` 接入 `subtitleTranslateMode` 与 `subtitleTranslate` 闭包配置，并在关闭播放器时清理翻译运行时

## 2. Player UI Integration

- [x] 2.1 在 `EmbeddedSubtitleView` 增加翻译模式选择（off/translated/bilingual），并写回会话配置
- [x] 2.2 在字幕面板增加 Apple 语言包页面入口与展示逻辑（支持系统版本降级提示）
- [x] 2.3 在 `PlayerControlView` 挂载 Apple translation task host，并在翻译模式变更时更新播放器配置与字幕刷新

## 3. Verification

- [x] 3.1 运行并通过 7 平台构建：iOS / iOS Simulator / tvOS / tvOS Simulator / macOS / visionOS / visionOS Simulator
- [x] 3.2 自检 OpenSpec 任务与代码改动一致，更新任务勾选状态
