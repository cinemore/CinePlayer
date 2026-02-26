## Why

当前纯播放器里的 Apple 字幕翻译实现是“最小可用版”，与 `cinemore-apple` 在弹窗行为和会话时序上存在偏差：语言包弹窗尺寸异常、字幕面板显示了不需要的“下载/管理”入口、且翻译链路会把失败当成功返回原文，导致播放中翻译经常不生效。

## What Changes

- 对齐 `cinemore-apple` 的播放中语言包检测流程：根据当前翻译语言对自动检测语言包状态，未安装时暂停并弹出下载页。
- 统一语言包弹窗内容与尺寸策略（尤其 macOS 下最小宽高），修复弹窗尺寸不合理问题。
- 从字幕面板移除“语言包下载/管理”入口，仅保留翻译模式选择。
- 修复 Apple 翻译路由：不再吞掉会话错误并返回原文，避免错误结果被当作成功翻译缓存。
- 调整语言包下载页会话状态更新时机，避免下载流程中视图重建干扰系统弹窗。

## Capabilities

### New Capabilities
- `apple-translation-playback-parity`: 播放中自动检测 Apple 语言包、弹窗下载与翻译链路稳定性对齐 `cinemore-apple`。

### Modified Capabilities
- `apple-subtitle-translation`: 调整错误处理与 UI 触发时机，保证 Apple 翻译在播放中可持续生效。
- `apple-translation-language-pack`: 移除字幕面板中的手动入口，改为播放中自动触发下载弹窗。

## Impact

- 影响播放器主视图翻译与弹窗流程：`CinePlayer/Player/Views/PlayerControlView.swift`
- 影响字幕面板 UI：`CinePlayer/Player/Subtitle/EmbeddedSubtitle/EmbeddedSubtitleView.swift`
- 影响翻译路由与错误语义：`CinePlayer/Player/Subtitle/Translation/SubtitleTranslationRouter.swift`
- 影响语言包下载页的状态管理：`CinePlayer/Player/Subtitle/Translation/AppleSubtitleTranslationLanguagePage.swift`
