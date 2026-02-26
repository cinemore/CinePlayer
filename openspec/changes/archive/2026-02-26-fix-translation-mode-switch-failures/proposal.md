## Why

当前 Apple 字幕翻译在切换翻译模式（如双语 -> 单语）时存在较高概率失败，且失败原因缺少可见日志，导致排障困难。失败后字幕会按原文缓存，放大了模式切换时的体验问题。

## What Changes

- 为 Apple 翻译失败路径补充明确日志（语言对、错误类型、触发阶段）。
- 对齐 `cinemore-apple` 的任务宿主策略，避免翻译模式切换触发不必要的 TranslationSession 重建。
- 降低模式切换过程中的会话不可用窗口，减少首次字幕行翻译失败并被原文缓存的概率。

## Capabilities

### New Capabilities
- `apple-translation-mode-switch-stability`: 提升翻译模式切换过程中的 Apple 翻译稳定性并提供失败可观测性。

### Modified Capabilities
- `apple-subtitle-translation`: 增强失败日志与模式切换时会话生命周期稳定性。

## Impact

- `CinePlayer/Player/Subtitle/Translation/AppleSubtitleTranslationTaskView.swift`
- `CinePlayer/Player/Subtitle/Translation/SubtitleTranslationRouter.swift`
- `CinePlayer/Player/Subtitle/Translation/AppleSubtitleTranslator.swift`
- `CinePlayer/Player/Views/PlayerControlView.swift`
