## Context

纯播放器已经接入 Apple 字幕翻译基础链路，但当前实现与 `cinemore-apple` 存在三个关键差异：
1. 语言包下载弹窗没有沿用参考工程的尺寸策略。
2. 字幕面板保留了“下载/管理”入口，不符合当前产品要求。
3. Apple 翻译路由吞掉错误并返回原文，导致会话未就绪时被误判为“翻译成功”，播放中翻译命中率低。

## Goals / Non-Goals

**Goals:**
- 让语言包检测与弹窗在播放中自动触发，行为与 `cinemore-apple` 一致。
- 修复弹窗尺寸问题，尤其 macOS 下使用明确的最小宽高。
- 去掉字幕面板中的语言包入口按钮。
- 修复路由错误处理，避免把失败结果当成功翻译缓存。

**Non-Goals:**
- 不接入 Google 翻译或新增翻译提供方选择。
- 不改动 SDK 内部字幕翻译实现。
- 不扩展为完整设置页语言包管理能力。

## Decisions

### Decision 1: 语言包入口统一迁移到播放中自动检测弹窗
- 方案：在 `PlayerControlView` 通过 `translationRuntime.desiredApplePair` + 播放状态触发检测，未安装时暂停并弹窗。
- 原因：与 `cinemore-apple` 一致，避免用户在字幕面板手动找入口。
- 备选：保留字幕面板手动入口。被拒绝，和需求冲突。

### Decision 2: 弹窗尺寸按参考实现固定最小值
- 方案：抽出 `LanguagePackSheetContent`，在 macOS 下设置最小尺寸（下载页 420x480，提示页 420x280）。
- 原因：可直接消除当前弹窗尺寸异常，且与参考工程一致。
- 备选：依赖系统自适应尺寸。被拒绝，当前已有明显 UI 问题。

### Decision 3: Apple 翻译错误向上抛出，不在路由层降级为原文
- 方案：`SubtitleTranslationRouter.translate` 中 Apple 路径移除 `catch { return text }`。
- 原因：让 SDK 的超时/失败路径正确识别“翻译失败”，避免错误缓存成“翻译成功原文”。
- 备选：继续吞错并返回原文。被拒绝，是当前不生效问题根因。

### Decision 4: 下载页在 translationTask 执行期间避免重置关键状态
- 方案：`AppleSubtitleTranslationLanguagePage` 在 `.translationTask` 结束后不立即清空 `lockedTaskConfig`。
- 原因：避免系统下载弹窗期间视图重建导致体验不稳定。
- 备选：完成后立即重置状态。被拒绝，已验证会引入不稳定。

## Risks / Trade-offs

- [Risk] 自动检测会在每次进入播放时更积极弹窗。
  -> Mitigation：仅在翻译模式开启且检测到未安装时触发，并在播放状态变化时才重新检查。

- [Risk] Apple 路由不再吞错后，短期会暴露更多“翻译失败”日志。
  -> Mitigation：失败由 SDK 统一回退原文，不影响播放连续性。

- [Risk] 弹窗尺寸固定可能在极小屏幕下可用空间紧张。
  -> Mitigation：仅设置 min 尺寸，仍由系统处理最终布局和滚动。
