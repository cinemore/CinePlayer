## Context

纯播放器仓库已接入 `CinePlayerSDK`，SDK 本身保留了 `subtitleTranslateMode` 与 `subtitleTranslate` 闭包扩展点，但应用层在剥离时移除了翻译路由与 UI。当前需要在不引入业务 API、不引入 Google 翻译的前提下恢复 Apple 字幕翻译，并保持 iOS/macOS/visionOS/tvOS 全平台可编译。

## Goals / Non-Goals

**Goals:**
- 恢复 Apple 字幕翻译链路：模式选择 -> 配置同步 -> 翻译回调执行。
- 用 SwiftUI `.translationTask` 安全托管 `TranslationSession`，避免会话逃逸。
- 增加语言包下载入口与状态反馈，降低首次翻译失败概率。
- 在不支持 Translation 的平台或系统版本上优雅降级。

**Non-Goals:**
- 不接入 Google 翻译接口或任何后端翻译服务。
- 不扩展为业务端字幕下载、远程字幕管理等能力。
- 不修改 SDK 二进制实现，仅改应用层接入代码。

## Decisions

### Decision 1: 复用 SDK 原生翻译模式与闭包扩展点
- 选择：在 `VideoPlayerModel` 统一配置 `config.subtitleTranslateMode` 与 `config.subtitleTranslate`，并在模式变化时热更新。
- 原因：最小侵入，避免复制 SDK 内部翻译处理逻辑。
- 备选：在字幕视图层直接注入翻译逻辑。会导致生命周期分散，难以维护。

### Decision 2: 使用 Router + Runtime + TaskHost 三段式结构承接 Apple Translation
- 选择：
  - `SubtitleTranslationRouter` 负责模式状态和翻译路由。
  - `SubtitleTranslationRuntime` 仅存储当前语言对，供 UI 驱动 `.translationTask`。
  - `AppleSubtitleTranslationTaskHostView` 在 SwiftUI 视图树内托管 `TranslationSession`。
- 原因：符合 Apple TranslationSession 生命周期约束，且与 `cinemore-apple` 方案一致。
- 备选：在闭包中直接创建或持有 `TranslationSession`。会违反会话生命周期约束并导致不稳定行为。

### Decision 3: 字幕面板内直接暴露翻译模式与语言包入口
- 选择：在 `EmbeddedSubtitleView` 增加翻译模式 Picker 和语言包页面入口。
- 原因：用户操作路径最短，且与字幕功能语义聚合。
- 备选：放入播放设置页。入口层级更深且与字幕上下文割裂。

### Decision 4: 不支持场景统一回退为原文
- 选择：系统版本不足、会话未就绪或翻译失败时返回原文，不中断播放。
- 原因：保证播放稳定性优先。
- 备选：抛出错误并停止字幕渲染。用户体验和鲁棒性更差。

## Risks / Trade-offs

- [Risk] 语言包未安装时用户可能误判为“翻译无效”。
  -> Mitigation：提供语言包下载页与状态提示；仅在支持系统触发下载流程。

- [Risk] 模式切换期间字幕重载可能产生短暂闪烁。
  -> Mitigation：仅在模式变化时执行一次轻量刷新，并回退小幅 seek 触发后续字幕重新渲染。

- [Risk] Translation API 平台可用性差异导致条件编译复杂。
  -> Mitigation：严格使用 `#if !os(tvOS) && !os(visionOS)` 与 `@available(iOS 18.0, macOS 15.0, *)` 双层保护。

## Migration Plan

1. 增加字幕翻译基础设施文件（runtime/router/apple translator/task host/language page）。
2. 扩展播放器模型，接入 `subtitleTranslateMode` 和翻译闭包。
3. 在字幕面板加入模式与语言包入口，并将模式写回会话配置。
4. 在播放器主视图挂载 Apple translation task host 并监听模式变更。
5. 执行 7 平台构建验证；若失败优先修复条件编译或可用性声明。

回滚策略：本次改动集中在字幕翻译相关文件与少量模型/视图变更，可按文件粒度回退，不影响其他播放能力。

## Open Questions

- 语言包页面默认是否应仅展示“当前字幕语言 -> 系统语言”预设对，或持续保留自定义语言对下载能力（本次先保留自定义与预设兼容）。
