## Context

纯播放器仅保留 Apple 翻译通道。当前翻译会话恢复主要依赖模式切换和错误路径自动重建，用户没有手动触发入口。需要在不引入新 provider、不改变字幕模式语义的前提下，增加一个可重复触发的“重启翻译服务”操作。

## Goals / Non-Goals

**Goals:**
- 在字幕设置中提供明确的手动重启入口。
- 手动重启时强制废弃旧 translator / session 路径。
- 与现有自动恢复兼容，不引入新的状态分叉。

**Non-Goals:**
- 不新增 Google 或其他翻译 provider。
- 不改变现有语言包检测策略与弹窗流程。
- 不新增持久化配置项。

## Decisions

### Decision 1: 重启入口放在内封字幕“翻译”配置旁
用户在调节翻译模式时最容易找到恢复操作，避免将“重启服务”分散到其他页面。

### Decision 2: Router 提供单一手动重启 API
由 `SubtitleTranslationRouter` 统一实现重建顺序（invalidate -> 清理 box -> pair 抖动 -> 日志），避免 UI 层重复会话细节。

### Decision 3: 通过 VideoPlayerModel 桥接视图调用
`EmbeddedSubtitleView` 只调用模型方法，不直接操作 actor 状态，保持 UI 和翻译基础设施解耦。

## Risks / Trade-offs

- [Risk] 在翻译关闭状态点按钮可能造成无效操作噪音  
  → Mitigation: Router 内部检查 `mode.needsTranslation`，无效时仅 debug 日志并返回。
- [Risk] 手动重启与自动恢复同时发生可能造成重复重建  
  → Mitigation: 复用 Router 内已有并发/节流保护，保持幂等。
- [Risk] 重启瞬间可能丢失一两条字幕翻译  
  → Mitigation: 属于可接受短暂恢复窗口，日志明确标注手动触发来源。
