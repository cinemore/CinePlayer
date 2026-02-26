## Why

当前纯播放器仓库在从 `cinemore-apple` 剥离时移除了字幕翻译接入，导致 `CinePlayerSDK` 已提供的 `subtitleTranslateMode/subtitleTranslate` 能力在应用层不可用。用户明确要求恢复 Apple 字幕翻译（不接入 Google），并保留纯播放器边界。

## What Changes

- 恢复播放器配置层对 `subtitleTranslateMode` 和 `subtitleTranslate` 闭包的接入。
- 引入 Apple Translation 会话运行时（`TranslationSession`）与字幕翻译路由，仅支持 Apple 翻译。
- 在字幕面板恢复翻译模式切换（关闭/单语/双语），并将设置实时同步到播放器。
- 新增 Apple 翻译语言包下载页面，支持语言包状态检测与下载触发。
- 在不支持 Apple Translation 的系统版本上提供降级行为（保持原字幕，不触发崩溃）。

## Capabilities

### New Capabilities
- `apple-subtitle-translation`: 纯播放器支持 Apple 字幕翻译模式并在播放过程中应用翻译结果。
- `apple-translation-language-pack`: 纯播放器提供 Apple 翻译语言包下载入口与状态展示。

### Modified Capabilities
- 无

## Impact

- 影响播放器模型与配置同步：`CinePlayer/Player/Model/VideoPlayerModel.swift`、`CinePlayer/Player/Model/PlayerControlConfig.swift`。
- 影响播放器主视图生命周期与翻译任务挂载：`CinePlayer/Player/Views/PlayerControlView.swift`。
- 影响字幕面板交互：`CinePlayer/Player/Subtitle/EmbeddedSubtitle/EmbeddedSubtitleView.swift`。
- 新增字幕翻译运行时/路由/任务宿主/语言包页面文件（位于 `CinePlayer/Player/Subtitle/Translation/`）。
