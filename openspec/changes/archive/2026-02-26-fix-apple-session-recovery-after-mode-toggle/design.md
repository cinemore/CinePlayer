## Context

纯播放器只有 Apple 翻译通道，没有 provider 切换。近期增加了语言包不可用时自动 `off` 策略后，用户会更频繁经历 `off -> translated/bilingual` 切换。若继续复用旧 translator，可能陷入持续 `CancellationError`。

## Decisions

### Decision 1: 用 mode 过渡模拟 cinemore 的 provider 过渡重建策略
记录 `wasNeedsTranslation`，当 `!wasNeedsTranslation && mode.needsTranslation` 时清理 `appleTranslatorBox`，确保下一次 translate/run 使用新实例。

### Decision 2: 重建仅发生在“关闭 -> 开启”
单语/双语互切都属于 `needsTranslation == true`，不触发重建，避免会话抖动。

### Decision 3: 增加调试日志
记录重建触发时机，帮助验证“失败后切换可恢复”。

### Decision 4: 对可恢复错误执行一次受控重建
当 `translate` 返回 `CancellationError` 或 `sessionUnavailable` 时，执行以下恢复序列：

1. 节流检查（避免每条字幕都触发重建）。
2. 失效旧 translator 并清空 `appleTranslatorBox`。
3. 将 `runtime.desiredApplePair` 置空后恢复为当前语言对，强制 SwiftUI `.translationTask` 重新创建 session。

该策略用于覆盖“模式仍处于翻译开启态，但底层 session 已失效”的场景。
