## Why

当前纯播放器在翻译失败后会进入难以恢复状态，用户即使切换翻译模式也可能持续收到 `CancellationError`。`cinemore` 在切回 Apple 翻译路径时会重建 translator 实例以避免复用失效会话，而当前项目缺少对应策略。

## What Changes

- 在字幕翻译模式从 `off` 切回翻译开启状态时，重建 Apple translator 实例。
- 保持翻译开启模式之间（单语/双语）不重建，避免无谓抖动。
- 当 Apple 翻译出现可恢复失败（如 `CancellationError` / `sessionUnavailable`）时，触发一次受控 session 重建。
- 增加重建路径日志，便于定位“失败后恢复”行为。

## Capabilities

### New Capabilities
- `apple-session-recovery`: 支持 mode 切换回翻译开启状态时的 Apple 会话重建，并在可恢复失败后自动恢复 session。

## Impact

- `CinePlayer/Player/Subtitle/Translation/SubtitleTranslationRouter.swift`
