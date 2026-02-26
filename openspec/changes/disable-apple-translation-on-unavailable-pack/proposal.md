## Why

当前纯播放器在 Apple 语言对 `unsupported` 或用户关闭语言包下载弹窗后，翻译模式可能仍保持单语/双语，导致后续播放持续走失败路径，用户感知为“翻译开着但不生效”。

## What Changes

- Apple 语言对 `unsupported` 时，自动将字幕翻译模式切到 `off`，并记录策略日志。
- 语言包下载弹窗关闭后，若语言包仍未安装，则自动将字幕翻译模式切到 `off`，并记录策略日志。
- 更新 unsupported 提示文案，明确已自动关闭翻译。

## Capabilities

### New Capabilities
- `apple-translation-unavailable-pack-policy`: 当 Apple 语言包不可用或未完成安装时，自动关闭字幕翻译模式，避免“开着但失败”。

### Modified Capabilities
- `apple-translation-playback-parity`: 补充不可用语言包下的翻译模式降级策略。

## Impact

- `CinePlayer/Player/Views/PlayerControlView.swift`
- `openspec/changes/disable-apple-translation-on-unavailable-pack/specs/apple-translation-unavailable-pack-policy/spec.md`
