## Context

当前 iOS 控制面板实现是纯播放器精简布局，与 Cinemore iOS 的业务按钮分组和竖/横屏结构不一致。现有代码仅支持音轨/视频轨/倍速侧栏，缺少字幕/设置/增强等入口；同时缺少 iPhone 打开播放器自动横屏和关闭恢复竖屏的方向锁机制。

## Goals / Non-Goals

**Goals:**
- iOS 控制面板布局按 Cinemore 的竖/横屏结构对齐。
- 补齐业务按钮入口并接入可用交互：关闭、PiP、画面填充、旋转、快退快进、播放暂停、音轨/视频轨/倍速、字幕、设置、增强、媒体信息。
- iPhone 打开播放器自动横屏，退出恢复竖屏，旋转按钮可切换方向锁。
- 字幕面板提供内嵌字幕切换与本地文件导入，移除“从文件源导入”。

**Non-Goals:**
- 不接入 cloud/file source 的换源链路。
- 不接入剧集列表业务模型。
- 不接入外部仓库（cinemore-apple）中的业务 API、路由与详情页模型。

## Decisions

### Decision 1: 保留纯播放器边界，按 Cinemore 视觉结构重组 iOS 面板
- 选择：保留当前纯播放器数据源（`PlayerSessionStore`、`VideoPlayerModel`、`CinePlayer.Coordinator`），把 iOS 控制面板改为 Cinemore 的 portrait/landscape 双布局结构与按钮分组。
- 原因：满足“完全按 Cinemore 操作方式和布局”且避免引入业务层依赖。
- 备选：继续在现有布局上增量加按钮。结果难以达到结构级一致。

### Decision 2: 扩展 PlayerControlModel 统一托管业务侧栏状态
- 选择：在 `PlayerControlModel` 增加 `showSubtitleContainer`、`showSettingContainer`、`showEnhancementContainer`、`showMediaInfoCard` 等状态，并纳入统一关闭逻辑。
- 原因：与 Cinemore 的入口-容器联动方式一致，减少状态分散。
- 备选：各视图本地 `@State` 管理弹层。会增加跨层同步复杂度。

### Decision 3: iOS 方向锁采用 AppDelegate + PlatformServices 的组合机制
- 选择：新增 iOS AppDelegate 方向锁（类似 Cinemore 的 `orientationLock`），`PlayerControlView` 在 iPhone onAppear/onDisappear 中触发横屏/竖屏切换，旋转按钮调用同一机制切换。
- 原因：能够稳定控制“打开自动横屏 + 关闭恢复竖屏”，并支持按钮切换。
- 备选：仅依赖 `requestGeometryUpdate` 单次调用。无法表达“锁定状态”，行为不稳定。

### Decision 4: 字幕能力采用 SDK 原生接口实现最小可用闭环
- 选择：字幕面板使用 `subtitleTrackIndex`/`loadSubtitleTrack` 处理内嵌字幕，使用 `loadSubtitleFile` 支持本地导入；不提供“文件源导入”入口。
- 原因：满足用户保留/排除项且不引入业务 API。
- 备选：仅提供占位按钮。无法满足“完全一致操作方式”的最低交互要求。

## Risks / Trade-offs

- [风险] iOS 方向切换在不同系统版本行为差异较大。  
  -> Mitigation：同时支持 iOS 16+ `requestGeometryUpdate` 与旧版本方向 API，并在关闭时兜底恢复竖屏。

- [风险] 字幕本地导入文件类型与编码兼容性差异。  
  -> Mitigation：限制常见字幕格式并在导入失败时显示 toast 错误提示。

- [风险] 业务按钮增多后 iPhone 小屏横屏拥挤。  
  -> Mitigation：按 Cinemore 同款分组与间距，必要时依赖按钮组横向滚动/紧凑间距策略。

## Migration Plan

1. 扩展 OpenSpec 与模型层（PlayerControlModel、方向锁服务）。
2. 重构 iOS 控制面板布局与按钮组。
3. 扩展侧栏容器并新增字幕/设置/增强视图。
4. 接入本地字幕导入与媒体信息卡片。
5. 运行全平台构建验证与 iOS 真机/模拟器交互回归。

回滚策略：按文件分块提交，必要时可单独回退 iOS 新增组件，不影响 macOS/tvOS/visionOS 已完成能力。

## Open Questions

- 设置/增强面板在纯播放器仓库内是否需要完整配置项，还是以“可用基础项 + 后续补齐”的形式迭代。
