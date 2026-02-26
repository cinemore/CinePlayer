## Why

当前纯播放器在 Apple 翻译会话偶发异常时，虽然具备自动恢复路径，但用户缺少一个“立即手动重启翻译服务”的显式入口，排障和恢复体验不够直接。

## What Changes

- 在字幕设置的翻译区域新增“重启翻译服务”按钮。
- 新增 `SubtitleTranslationRouter` 的手动重启 API，用于重建 Apple 翻译会话。
- 通过 `VideoPlayerModel` 暴露 UI 可调用的重启方法，保持视图层与翻译路由解耦。
- 增加手动重启日志，便于追踪用户触发的恢复行为。

## Capabilities

### New Capabilities
- `manual-translation-service-restart`: 用户可在播放器 UI 中手动触发 Apple 字幕翻译服务重启，并让后续翻译请求使用新会话路径。

### Modified Capabilities
- 无

## Impact

- `CinePlayer/Player/Subtitle/EmbeddedSubtitle/EmbeddedSubtitleView.swift`
- `CinePlayer/Player/Model/VideoPlayerModel.swift`
- `CinePlayer/Player/Subtitle/Translation/SubtitleTranslationRouter.swift`
