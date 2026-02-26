## Context

模式切换后翻译失败的主要风险在于会话重建与字幕刷新并发：若首批翻译请求在会话未就绪时失败，渲染器会缓存原文，造成后续同内容不再重试。当前实现还缺少失败日志，无法快速判断是 session 不可用、prepare 失败还是翻译调用失败。

## Goals / Non-Goals

**Goals:**
- 为 Apple 翻译失败提供可定位日志。
- 避免双语/单语互切时无意义的 task/session 抖动。
- 降低模式切换后的首批翻译失败概率。

**Non-Goals:**
- 不改 SDK 内部字幕缓存策略。
- 不引入新的翻译 provider。

## Decisions

### Decision 1: 日志放在路由与 translator 两层
- 在 router 记录“请求级失败”（from/to + 错误）。
- 在 translator 记录“会话级失败”（prepare 失败、session 不可用）。

### Decision 2: TaskHost 去除对 mode 的硬绑定
- TaskHost 仅由 `runtime.desiredApplePair` 驱动 language-pair 检查与 `translationTask` 配置。
- 避免双语/单语切换导致 pairTaskId 变化，减少 session 取消重建。

### Decision 3: PlayerControlView 不再向 TaskHost 传 mode
- 模式变化仍通过 config + 字幕刷新生效。
- session 生命周期与 mode 切换解耦，减少临界窗口。

## Risks / Trade-offs

- [Risk] 日志量增加。
  -> Mitigation：限制为 DEBUG 输出，记录必要字段并截断文本样本。

- [Risk] 仍存在极端网络/系统层失败。
  -> Mitigation：保留现有 fallback，确保播放不中断。
