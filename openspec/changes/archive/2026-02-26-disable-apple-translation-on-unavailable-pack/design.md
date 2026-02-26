## Context

播放器已经具备播放中语言包可用性检查与下载弹窗，但当前策略只负责弹窗提示，不负责在不可恢复状态下收敛翻译模式。结果是模式仍处于“需要翻译”，而实际翻译会持续失败。

## Goals / Non-Goals

**Goals:**
- `unsupported` 时立即关闭翻译模式。
- 下载弹窗关闭后，如果语言包仍未安装则关闭翻译模式。
- 为自动关闭行为补充可追踪日志。

**Non-Goals:**
- 不引入 Google provider。
- 不改动字幕渲染器缓存策略。
- 不增加新的设置入口。

## Decisions

### Decision 1: 统一在 PlayerControlView 中执行 mode 降级
通过 `PlayerLanguagePackCheckModifier -> closure` 把“关闭翻译模式”动作回调到 `PlayerControlView`，统一修改 `sessionStore.controlConfig.subtitleTranslateMode`，避免分散写状态。

### Decision 2: 弹窗关闭后做一次 LanguageAvailability 复查
仅当弹窗来自 `canDownload` 场景时，在 `onDismiss` 异步复查该语言对状态。
- 若 `installed`：保留当前翻译模式。
- 若非 `installed`：自动切 `off`。

### Decision 3: unsupported 走“即时降级 + 提示”
在检测到 `unsupported` 时立即切 `off`，并继续展示 unsupported 提示文案，确保用户知道为何翻译被关闭。

## Risks / Trade-offs

- [Risk] 弹窗关闭触发一次额外状态查询。
  -> Mitigation：只在 `canDownload` 且 mode 仍需翻译时查询，范围最小化。

- [Risk] 自动切 `off` 可能被理解为“系统擅自改设置”。
  -> Mitigation：提示文案和日志明确原因是语言包不可用/未安装。
